import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/dio_client.dart';

// ── Events ────────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthCheckStarted extends AuthEvent {}

class AuthSendOtpRequested extends AuthEvent {
  final String phoneNumber;
  final String deviceUuid;
  final String deviceType;
  final String countryCode;
  AuthSendOtpRequested({
    required this.phoneNumber,
    required this.deviceUuid,
    required this.deviceType,
    required this.countryCode,
  });
  @override
  List<Object?> get props => [phoneNumber];
}

class AuthVerifyOtpRequested extends AuthEvent {
  final String sessionId;
  final String otpCode;
  final String phoneNumber;
  AuthVerifyOtpRequested({
    required this.sessionId,
    required this.otpCode,
    required this.phoneNumber,
  });
  @override
  List<Object?> get props => [sessionId, otpCode];
}

class AuthLogoutRequested extends AuthEvent {}

// ── States ────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthOtpSent extends AuthState {
  final String sessionId;
  final String phoneNumber;
  final bool isExistingUser;
  AuthOtpSent({required this.sessionId, required this.phoneNumber, required this.isExistingUser});
  @override
  List<Object?> get props => [sessionId];
}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String phoneNumber;
  final bool isNewUser;
  AuthAuthenticated({required this.userId, required this.phoneNumber, required this.isNewUser});
  @override
  List<Object?> get props => [userId];
}

class AuthUnauthenticated extends AuthState {
  final String? prefillPhone;
  AuthUnauthenticated({this.prefillPhone});
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final _storage = const FlutterSecureStorage();

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckStarted>(_onCheckStarted);
    on<AuthSendOtpRequested>(_onSendOtp);
    on<AuthVerifyOtpRequested>(_onVerifyOtp);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheckStarted(AuthCheckStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final accessToken = await _storage.read(key: 'access_token');
      final refreshToken = await _storage.read(key: 'refresh_token');
      final savedPhone = await _storage.read(key: 'phone_number');

      if (accessToken == null) {
        emit(AuthUnauthenticated(prefillPhone: savedPhone));
        return;
      }

      // Attempt silent refresh
      final refreshed = await _refreshToken(refreshToken ?? '');
      if (refreshed) {
        final userId = await _storage.read(key: 'user_id') ?? '';
        emit(AuthAuthenticated(
          userId: userId,
          phoneNumber: savedPhone ?? '',
          isNewUser: false,
        ));
      } else {
        emit(AuthUnauthenticated(prefillPhone: savedPhone));
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSendOtp(AuthSendOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final resp = await apiClient.post('/auth/register', data: {
        'phone_number': event.phoneNumber,
        'device_uuid': event.deviceUuid,
        'device_type': event.deviceType,
        'country_code': event.countryCode,
        'app_version': '2.0.0',
      });

      final data = resp.data;
      final isExisting = data['status'] == 'error' && data['code'] == 'USER_EXISTS' ||
                         resp.statusCode == 409;
      final sessionId = data['session_id'] as String? ?? '';

      await _storage.write(key: 'phone_number', value: event.phoneNumber);

      emit(AuthOtpSent(
        sessionId: sessionId,
        phoneNumber: event.phoneNumber,
        isExistingUser: isExisting,
      ));
    } catch (e) {
      emit(AuthError('Failed to send OTP. Please check your number and try again.'));
    }
  }

  Future<void> _onVerifyOtp(AuthVerifyOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final resp = await apiClient.post('/auth/verify-otp', data: {
        'session_id': event.sessionId,
        'otp_code': event.otpCode,
        'phone_number': event.phoneNumber,
      });

      final data = resp.data;
      await _storage.write(key: 'access_token', value: data['access_token']);
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
      await _storage.write(key: 'user_id', value: data['user']['id']);

      // Check if profile is complete
      bool isNewUser = true;
      try {
        final profileResp = await apiClient.get('/users/profile');
        isNewUser = profileResp.data['display_name'] == null;
      } catch (_) {}

      emit(AuthAuthenticated(
        userId: data['user']['id'],
        phoneNumber: event.phoneNumber,
        isNewUser: isNewUser,
      ));
    } catch (e) {
      emit(AuthError('Invalid OTP. Please try again.'));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _storage.deleteAll();
    emit(AuthUnauthenticated());
  }

  Future<bool> _refreshToken(String refreshToken) async {
    if (refreshToken.isEmpty) return false;
    try {
      final resp = await apiClient.post('/auth/refresh-token', data: {
        'refresh_token': refreshToken,
      });
      await _storage.write(key: 'access_token', value: resp.data['access_token']);
      await _storage.write(key: 'refresh_token', value: resp.data['refresh_token']);
      return true;
    } catch (_) {
      return false;
    }
  }
}

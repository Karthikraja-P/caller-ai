import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../core/models/voicemail.dart';
import '../../core/network/voicemail_repository.dart';
import '../../core/services/audio_player_service.dart';

// ── Events ────────────────────────────────────────────────────

abstract class VoicemailEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class VoicemailFetchRequested extends VoicemailEvent {
  final bool unreadOnly;
  VoicemailFetchRequested({this.unreadOnly = false});

  @override
  List<Object?> get props => [unreadOnly];
}

class VoicemailMarkReadRequested extends VoicemailEvent {
  final String id;
  final bool isRead;
  VoicemailMarkReadRequested({required this.id, required this.isRead});

  @override
  List<Object?> get props => [id, isRead];
}

class VoicemailDeleteRequested extends VoicemailEvent {
  final String id;
  VoicemailDeleteRequested({required this.id});

  @override
  List<Object?> get props => [id];
}

class VoicemailPlayRequested extends VoicemailEvent {
  final Voicemail voicemail;
  VoicemailPlayRequested({required this.voicemail});

  @override
  List<Object?> get props => [voicemail];
}

class VoicemailPauseRequested extends VoicemailEvent {}

class VoicemailResumeRequested extends VoicemailEvent {}

class VoicemailStopRequested extends VoicemailEvent {}

class VoicemailSeekRequested extends VoicemailEvent {
  final Duration position;
  VoicemailSeekRequested({required this.position});

  @override
  List<Object?> get props => [position];
}

class _VoicemailPositionUpdated extends VoicemailEvent {
  final Duration position;
  _VoicemailPositionUpdated(this.position);

  @override
  List<Object?> get props => [position];
}

class _VoicemailDurationUpdated extends VoicemailEvent {
  final Duration duration;
  _VoicemailDurationUpdated(this.duration);

  @override
  List<Object?> get props => [duration];
}

class _VoicemailPlayingUpdated extends VoicemailEvent {
  final bool isPlaying;
  _VoicemailPlayingUpdated(this.isPlaying);

  @override
  List<Object?> get props => [isPlaying];
}

// ── States ────────────────────────────────────────────────────

abstract class VoicemailState extends Equatable {
  @override
  List<Object?> get props => [];
}

class VoicemailInitial extends VoicemailState {}

class VoicemailLoading extends VoicemailState {}

class VoicemailLoaded extends VoicemailState {
  final List<Voicemail> messages;
  final Voicemail? currentlyPlaying;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? operationError;
  final String? deletingId;

  VoicemailLoaded({
    required this.messages,
    this.currentlyPlaying,
    this.isPlaying = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.operationError,
    this.deletingId,
  });

  VoicemailLoaded copyWith({
    List<Voicemail>? messages,
    Voicemail? Function()? currentlyPlaying,
    bool? isPlaying,
    Duration? currentPosition,
    Duration? totalDuration,
    String? Function()? operationError,
    String? Function()? deletingId,
  }) {
    return VoicemailLoaded(
      messages: messages ?? this.messages,
      currentlyPlaying: currentlyPlaying != null ? currentlyPlaying() : this.currentlyPlaying,
      isPlaying: isPlaying ?? this.isPlaying,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      operationError: operationError != null ? operationError() : this.operationError,
      deletingId: deletingId != null ? deletingId() : this.deletingId,
    );
  }

  @override
  List<Object?> get props => [
    messages,
    currentlyPlaying,
    isPlaying,
    currentPosition,
    totalDuration,
    operationError,
    deletingId,
  ];
}

class VoicemailError extends VoicemailState {
  final String message;
  VoicemailError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────

class VoicemailBloc extends Bloc<VoicemailEvent, VoicemailState> {
  final VoicemailRepository _repository;
  final AudioPlayerAdapter _audioPlayer;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  VoicemailBloc({
    VoicemailRepository? repository,
    AudioPlayerAdapter? audioPlayer,
  })  : _repository = repository ?? VoicemailRepository(),
        _audioPlayer = audioPlayer ?? JustAudioPlayerAdapter(),
        super(VoicemailInitial()) {
    on<VoicemailFetchRequested>(_onFetchRequested);
    on<VoicemailMarkReadRequested>(_onMarkReadRequested);
    on<VoicemailDeleteRequested>(_onDeleteRequested);
    on<VoicemailPlayRequested>(_onPlayRequested);
    on<VoicemailPauseRequested>(_onPauseRequested);
    on<VoicemailResumeRequested>(_onResumeRequested);
    on<VoicemailStopRequested>(_onStopRequested);
    on<VoicemailSeekRequested>(_onSeekRequested);
    on<_VoicemailPositionUpdated>(_onPositionUpdated);
    on<_VoicemailDurationUpdated>(_onDurationUpdated);
    on<_VoicemailPlayingUpdated>(_onPlayingUpdated);

    _listenToAudioPlayer();
  }

  void _listenToAudioPlayer() {
    _positionSub = _audioPlayer.positionStream.listen((pos) {
      add(_VoicemailPositionUpdated(pos));
    });
    _durationSub = _audioPlayer.durationStream.listen((dur) {
      if (dur != null) add(_VoicemailDurationUpdated(dur));
    });
    _playingSub = _audioPlayer.playingStream.listen((playing) {
      add(_VoicemailPlayingUpdated(playing));
    });
  }

  Future<void> _onFetchRequested(
    VoicemailFetchRequested event,
    Emitter<VoicemailState> emit,
  ) async {
    emit(VoicemailLoading());
    try {
      final messages = await _repository.getMessages(unreadOnly: event.unreadOnly);
      emit(VoicemailLoaded(messages: messages));
    } catch (e) {
      emit(VoicemailError(message: 'Unable to load voicemails. Please check your connection.'));
    }
  }

  Future<void> _onMarkReadRequested(
    VoicemailMarkReadRequested event,
    Emitter<VoicemailState> emit,
  ) async {
    if (state is! VoicemailLoaded) return;
    final currentState = state as VoicemailLoaded;

    final updated = currentState.messages.map((m) {
      if (m.id == event.id) return m.copyWith(isRead: event.isRead);
      return m;
    }).toList();

    emit(currentState.copyWith(messages: updated));

    try {
      await _repository.markAsRead(event.id, isRead: event.isRead);
    } catch (_) {
      // Non-critical, local state already optimistic
    }
  }

  Future<void> _onDeleteRequested(
    VoicemailDeleteRequested event,
    Emitter<VoicemailState> emit,
  ) async {
    if (state is! VoicemailLoaded) return;
    final currentState = state as VoicemailLoaded;

    // Stop playback if deleting currently playing voicemail
    if (currentState.currentlyPlaying?.id == event.id) {
      await _audioPlayer.stop();
    }

    emit(currentState.copyWith(
      deletingId: () => event.id,
      operationError: () => null,
    ));

    try {
      await _repository.deleteVoicemail(event.id);
      final remaining = currentState.messages.where((m) => m.id != event.id).toList();
      emit(currentState.copyWith(
        messages: remaining,
        currentlyPlaying: currentState.currentlyPlaying?.id == event.id ? () => null : null,
        isPlaying: currentState.currentlyPlaying?.id == event.id ? false : null,
        deletingId: () => null,
        operationError: () => null,
      ));
    } catch (e) {
      // Keep local metadata intact on provider failure, notify user with retry
      emit(currentState.copyWith(
        deletingId: () => null,
        operationError: () => 'Telephony provider failed to delete recording. Metadata preserved. Please retry.',
      ));
    }
  }

  Future<void> _onPlayRequested(
    VoicemailPlayRequested event,
    Emitter<VoicemailState> emit,
  ) async {
    if (state is! VoicemailLoaded) return;
    final currentState = state as VoicemailLoaded;

    final vm = event.voicemail;

    // Mark as read optimistically
    final updatedList = currentState.messages.map((m) {
      if (m.id == vm.id) return m.copyWith(isRead: true);
      return m;
    }).toList();

    emit(currentState.copyWith(
      messages: updatedList,
      currentlyPlaying: () => vm,
      isPlaying: true,
      currentPosition: Duration.zero,
      totalDuration: Duration(seconds: vm.durationSeconds),
      operationError: () => null,
    ));

    _repository.markAsRead(vm.id, isRead: true).ignore();

    try {
      final token = await _repository.getAuthToken();
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      final url = _repository.getAudioPlaybackUrl(vm.id);
      await _audioPlayer.playUrl(url, headers: headers);
    } catch (e) {
      emit(currentState.copyWith(
        isPlaying: false,
        operationError: () => 'Failed to play voicemail recording. Provider audio unavailable.',
      ));
    }
  }

  Future<void> _onPauseRequested(
    VoicemailPauseRequested event,
    Emitter<VoicemailState> emit,
  ) async {
    await _audioPlayer.pause();
    if (state is VoicemailLoaded) {
      emit((state as VoicemailLoaded).copyWith(isPlaying: false));
    }
  }

  Future<void> _onResumeRequested(
    VoicemailResumeRequested event,
    Emitter<VoicemailState> emit,
  ) async {
    await _audioPlayer.resume();
    if (state is VoicemailLoaded) {
      emit((state as VoicemailLoaded).copyWith(isPlaying: true));
    }
  }

  Future<void> _onStopRequested(
    VoicemailStopRequested event,
    Emitter<VoicemailState> emit,
  ) async {
    await _audioPlayer.stop();
    if (state is VoicemailLoaded) {
      emit((state as VoicemailLoaded).copyWith(
        isPlaying: false,
        currentPosition: Duration.zero,
        currentlyPlaying: () => null,
      ));
    }
  }

  Future<void> _onSeekRequested(
    VoicemailSeekRequested event,
    Emitter<VoicemailState> emit,
  ) async {
    await _audioPlayer.seek(event.position);
    if (state is VoicemailLoaded) {
      emit((state as VoicemailLoaded).copyWith(currentPosition: event.position));
    }
  }

  void _onPositionUpdated(_VoicemailPositionUpdated event, Emitter<VoicemailState> emit) {
    if (state is VoicemailLoaded) {
      emit((state as VoicemailLoaded).copyWith(currentPosition: event.position));
    }
  }

  void _onDurationUpdated(_VoicemailDurationUpdated event, Emitter<VoicemailState> emit) {
    if (state is VoicemailLoaded) {
      emit((state as VoicemailLoaded).copyWith(totalDuration: event.duration));
    }
  }

  void _onPlayingUpdated(_VoicemailPlayingUpdated event, Emitter<VoicemailState> emit) {
    if (state is VoicemailLoaded) {
      emit((state as VoicemailLoaded).copyWith(isPlaying: event.isPlaying));
    }
  }

  @override
  Future<void> close() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}

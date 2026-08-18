import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/auth_bloc.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String? prefillPhone;
  const OtpVerificationScreen({super.key, this.prefillPhone});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String _countryCode = '+91';
  String _countryIso = 'IN';
  String? _sessionId;
  bool _otpSent = false;
  bool _isExistingUser = false;
  int _resendCountdown = 60;
  Timer? _timer;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.prefillPhone != null) {
      _phoneController.text = widget.prefillPhone!.replaceAll(_countryCode, '');
    }

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _fullPhone => '$_countryCode${_phoneController.text.trim()}';

  void _sendOtp() {
    context.read<AuthBloc>().add(AuthSendOtpRequested(
      phoneNumber: _fullPhone,
      deviceUuid: 'device-uuid-placeholder',
      deviceType: 'android',
      countryCode: _countryIso,
    ));
  }

  void _verifyOtp() {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6 || _sessionId == null) return;
    context.read<AuthBloc>().add(AuthVerifyOtpRequested(
      sessionId: _sessionId!,
      otpCode: code,
      phoneNumber: _fullPhone,
    ));
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          setState(() {
            _otpSent = true;
            _sessionId = state.sessionId;
            _isExistingUser = state.isExistingUser;
          });
          _startCountdown();
          if (_isExistingUser) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Account found! Verify OTP to log in.'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else if (state is AuthAuthenticated) {
          if (state.isNewUser) {
            Navigator.pushReplacementNamed(context, '/profile-creation');
          } else {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        } else if (state is AuthError) {
          _shakeController.forward(from: 0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(_isExistingUser ? 'Welcome Back!' : 'Verify Your Number'),
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    _isExistingUser
                        ? 'Verify your number to continue where you left off'
                        : "We'll send you a 6-digit code to verify your phone number",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  // Phone input row
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CountryCodePicker(
                          onChanged: (cc) => setState(() {
                            _countryCode = cc.dialCode ?? '+91';
                            _countryIso = cc.code ?? 'IN';
                          }),
                          initialSelection: _countryIso,
                          favorite: const ['+91', '+1', '+44'],
                          showCountryOnly: false,
                          showOnlyCountryWhenClosed: false,
                          alignLeft: false,
                          textStyle: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          readOnly: widget.prefillPhone != null,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Enter mobile number',
                            suffixIcon: widget.prefillPhone != null
                                ? const Icon(Icons.check_circle, color: Color(0xFF22C55E))
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (!_otpSent)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _sendOtp,
                        child: isLoading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(widget.prefillPhone != null
                                ? 'Send Verification Code'
                                : 'Send OTP'),
                      ),
                    ),

                  // OTP input section
                  if (_otpSent) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Enter 6-digit OTP',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (i) => _buildOtpBox(i)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: _resendCountdown > 0
                          ? Text(
                              'Resend OTP in 00:${_resendCountdown.toString().padLeft(2, '0')}',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            )
                          : GestureDetector(
                              onTap: _sendOtp,
                              child: Text(
                                'Resend OTP',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (isLoading || _otpValue.length != 6) ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _otpValue.length == 6
                              ? AppColors.primary
                              : AppColors.bgCard,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Verify'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          'By continuing, you agree to our ',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            'Terms of Service',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primary,
                            ),
                          ),
                        ),
                        Text(
                          ' and ',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focusNodes[index].hasFocus ? AppColors.primary : AppColors.bgCard,
          width: 2,
        ),
        boxShadow: _focusNodes[index].hasFocus
            ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8)]
            : null,
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }
}

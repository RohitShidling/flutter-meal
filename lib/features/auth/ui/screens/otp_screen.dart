import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _otpFocusNode = FocusNode();
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_otpFocusNode);
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final provider = context.read<AuthProvider>();
      if (provider.resendCooldownSeconds > 0) {
        provider.tickResendCooldown();
      }
    });
  }

  @override
  void dispose() {
    if (mounted) FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _resendTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_otpController.text.trim().length < 6) {
      ErrorHandler.showError(context, 'Please enter the 6-digit OTP');
      return;
    }

    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    final provider = Provider.of<AuthProvider>(context, listen: false);
    final code = _otpController.text.trim();

    bool success;
    if (provider.authMode == AuthMode.register) {
      success = await provider.registerVerifyOtp(code);
    } else {
      success = await provider.loginVerifyOtp(code);
    }

    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (mounted) {
      ErrorHandler.showError(context, provider.errorMessage);
    }
  }

  Future<void> _resendOtp() async {
    final provider = context.read<AuthProvider>();
    if (provider.resendCooldownSeconds > 0) return;

    final success = await provider.resendOtp();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new OTP has been sent to your WhatsApp.')),
      );
    } else {
      ErrorHandler.showError(context, provider.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();
    final isLoading = provider.state == AuthState.loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRegister = provider.authMode == AuthMode.register;
    final remaining = provider.remainingAttempts;
    final canResend = provider.resendCooldownSeconds <= 0 && !isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: AppTheme.backgroundDark,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        body: GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          child: Container(
            color: Colors.white,
            child: SafeArea(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              SystemChannels.textInput.invokeMethod('TextInput.hide');
                              context.read<AuthProvider>().clearTransientState();
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            label: const Text(
                              'Back',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Spacer(),
                          const Padding(
                            padding: EdgeInsets.only(right: 52),
                            child: Text(
                              'Buuttii',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F234A),
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verify WhatsApp',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF102348),
                                  ),
                            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
                            const SizedBox(height: 10),
                            Text(
                              'Code sent to ${provider.phoneNumber}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ).animate().fadeIn(delay: 120.ms),
                            if (remaining != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                '$remaining of ${provider.maxVerifyAttempts} verification attempts remaining',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: remaining <= 2 ? Colors.red.shade400 : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 64),
                            Opacity(
                              opacity: 0,
                              child: TextFormField(
                                controller: _otpController,
                                focusNode: _otpFocusNode,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autocorrect: false,
                                enableSuggestions: true,
                                onFieldSubmitted: (_) => _submit(),
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                maxLength: 6,
                                onChanged: (_) => setState(() {}),
                                enableInteractiveSelection: true,
                                showCursor: true,
                                style: const TextStyle(color: Colors.transparent),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  counterText: '',
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                FocusScope.of(context).requestFocus(_otpFocusNode);
                                Future.delayed(const Duration(milliseconds: 120), () {
                                  if (!mounted) return;
                                  SystemChannels.textInput.invokeMethod('TextInput.show');
                                });
                              },
                              onLongPress: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (!mounted || data?.text == null) return;
                                final digits = data!.text!.replaceAll(RegExp(r'\D'), '');
                                final pasted = digits.substring(0, digits.length < 6 ? digits.length : 6);
                                if (pasted.isNotEmpty) {
                                  _otpController.text = pasted;
                                  setState(() {});
                                  FocusScope.of(context).requestFocus(_otpFocusNode);
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(6, (index) {
                                  final text = _otpController.text;
                                  final char = index < text.length ? text[index] : '';
                                  final active = text.length == index && text.length < 6;
                                  return Container(
                                    width: 48,
                                    height: 68,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppTheme.primaryColor,
                                        width: active ? 2.6 : 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.18),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      char,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.05, end: 0),
                            const SizedBox(height: 26),
                            Center(
                              child: TextButton(
                                onPressed: canResend ? _resendOtp : null,
                                child: Text(
                                  canResend
                                      ? "Didn't receive code? Resend now"
                                      : "Didn't receive code? Resend in 00:${provider.resendCooldownSeconds.toString().padLeft(2, '0')}",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: canResend ? const Color(0xFF102348) : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 150),
                            SizedBox(
                              width: double.infinity,
                              height: 62,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        isRegister ? 'Verify & Register' : 'Verify',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ).animate().fadeIn(delay: 320.ms),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

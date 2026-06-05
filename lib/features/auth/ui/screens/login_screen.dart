import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/auth/ui/screens/otp_screen.dart';
import 'package:meal_app/features/profile/ui/screens/legal_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _consentAccepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().clearTransientState();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _goToOtp() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const OtpScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _submitLogin() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      final provider = Provider.of<AuthProvider>(context, listen: false);
      final completePhoneNumber = '+91${_phoneController.text.trim()}';
      final success = await provider.loginSendOtp(completePhoneNumber);

      if (success && mounted) {
        _goToOtp();
      } else if (mounted) {
        ErrorHandler.showError(context, provider.errorMessage);
      }
    }
  }

  void _submitRegister() async {
    if (!_consentAccepted) {
      ErrorHandler.showError(
        context,
        'You must accept the Terms & Conditions and Privacy Policy to register.',
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      final provider = Provider.of<AuthProvider>(context, listen: false);
      final completePhoneNumber = '+91${_phoneController.text.trim()}';
      final username = _usernameController.text.trim();
      final success = await provider.registerSendOtp(
        completePhoneNumber,
        username,
        _consentAccepted,
      );

      if (success && mounted) {
        _goToOtp();
      } else if (mounted) {
        ErrorHandler.showError(context, provider.errorMessage);
      }
    }
  }

  void _setMode(AuthMode mode) {
    context.read<AuthProvider>().setAuthMode(mode);
    setState(() => _consentAccepted = false);
    _formKey.currentState?.reset();
  }

  Widget _buildFoodOutline(IconData icon) {
    return Icon(
      icon,
      size: 54,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.state == AuthState.loading;
    final isRegisterMode = authProvider.authMode == AuthMode.register;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        body: Container(
          color: const Color(0xFFF7F4EF),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF7A1A), Color(0xFFFFC47A)],
                        ),
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF7A1A).withValues(alpha: 0.20),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 250,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  left: 18,
                                  right: 18,
                                  bottom: 18,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildFoodOutline(CupertinoIcons.square_favorites),
                                        const SizedBox(width: 14),
                                        _buildFoodOutline(CupertinoIcons.heart_fill),
                                        const SizedBox(width: 14),
                                        _buildFoodOutline(CupertinoIcons.circle_grid_3x3_fill),
                                        const SizedBox(width: 14),
                                        _buildFoodOutline(CupertinoIcons.leaf_arrow_circlepath),
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  'Buuttii',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                        color: Colors.white,
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  isRegisterMode
                                      ? 'Create your Buuttii account'
                                      : 'Welcome to Buuttii',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF57534E),
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isRegisterMode
                                      ? 'Enter your WhatsApp number and username to get started.'
                                      : 'Enter your WhatsApp number to continue.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                if (isRegisterMode) ...[
                                  TextFormField(
                                    controller: _usernameController,
                                    keyboardType: TextInputType.name,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization: TextCapitalization.words,
                                    autocorrect: true,
                                    enableSuggestions: true,
                                    autofillHints: const [AutofillHints.username, AutofillHints.name],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Username',
                                      prefixIcon: const Icon(Icons.person_outline),
                                      filled: true,
                                      fillColor: const Color(0xFFF8F7F4),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (isRegisterMode &&
                                          (value == null || value.trim().isEmpty)) {
                                        return 'Please enter your username';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  enableSuggestions: true,
                                  autofillHints: const [AutofillHints.telephoneNumber],
                                  onFieldSubmitted: (_) =>
                                      isRegisterMode ? _submitRegister() : _submitLogin(),
                                  maxLength: 10,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'WhatsApp Number',
                                    counterText: '',
                                    filled: true,
                                    fillColor: const Color(0xFFF8F7F4),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('🇮🇳', style: TextStyle(fontSize: 22)),
                                          const SizedBox(width: 8),
                                          const Text(
                                            '+91',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            height: 24,
                                            width: 1,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your WhatsApp number';
                                    }
                                    if (value.length != 10 ||
                                        !RegExp(r'^[0-9]+$').hasMatch(value)) {
                                      return 'Please enter a valid 10-digit WhatsApp number';
                                    }
                                    return null;
                                  },
                                ),
                                if (isRegisterMode) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: _consentAccepted,
                                        onChanged: (val) {
                                          setState(() {
                                            _consentAccepted = val ?? false;
                                          });
                                        },
                                        activeColor: AppTheme.primaryColor,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: RichText(
                                            text: TextSpan(
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12.5,
                                                    height: 1.35,
                                                  ),
                                              children: [
                                                const TextSpan(text: 'I agree to the '),
                                                TextSpan(
                                                  text: 'Terms & Conditions',
                                                  style: const TextStyle(
                                                    color: AppTheme.primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                  recognizer: TapGestureRecognizer()
                                                    ..onTap = () {
                                                      Navigator.push(
                                                        context,
                                                        CupertinoPageRoute(
                                                          builder: (_) =>
                                                              const LegalScreen(initialTabIndex: 0),
                                                        ),
                                                      );
                                                    },
                                                ),
                                                const TextSpan(text: ' and '),
                                                TextSpan(
                                                  text: 'Privacy Policy',
                                                  style: const TextStyle(
                                                    color: AppTheme.primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                  recognizer: TapGestureRecognizer()
                                                    ..onTap = () {
                                                      Navigator.push(
                                                        context,
                                                        CupertinoPageRoute(
                                                          builder: (_) =>
                                                              const LegalScreen(initialTabIndex: 1),
                                                        ),
                                                      );
                                                    },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: 58,
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : (isRegisterMode ? _submitRegister : _submitLogin),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            isRegisterMode
                                                ? 'Create Account'
                                                : 'Login / Register',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'By continuing you agree to our Terms & Conditions and Privacy Policy',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isRegisterMode
                                          ? 'Already have an account? '
                                          : "Don't have an account? ",
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _setMode(
                                        isRegisterMode ? AuthMode.login : AuthMode.register,
                                      ),
                                      child: Text(
                                        isRegisterMode ? 'Login' : 'Register',
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 120.ms, duration: 450.ms)
                        .slideY(begin: 0.06, end: 0),
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

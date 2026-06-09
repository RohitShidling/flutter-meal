import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/widgets/app_logo.dart';
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
  final _referralController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _phoneFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  bool _consentAccepted = false;
  bool _showReferralField = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().clearTransientState();
    });
    _phoneFocusNode.addListener(() => _scrollToFocused(_phoneFocusNode));
    _usernameFocusNode.addListener(() => _scrollToFocused(_usernameFocusNode));
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  bool get _isPhoneComplete => _phoneController.text.trim().length == 10;

  bool get _canSubmit {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.state == AuthState.loading) return false;
    if (!_isPhoneComplete) return false;
    if (authProvider.authMode == AuthMode.register) {
      return _usernameController.text.trim().isNotEmpty && _consentAccepted;
    }
    return true;
  }

  void _scrollToFocused(FocusNode node) {
    if (!node.hasFocus) return;
    // Only auto-scroll on the registration page
    final isRegister = context.read<AuthProvider>().authMode == AuthMode.register;
    if (!isRegister) return;
    // Short delay to let the keyboard animation start
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || node.context == null) return;
      Scrollable.ensureVisible(
        node.context!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        alignment: 0.5, // Position the field at ~30% from the top
      );
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    _referralController.dispose();
    _scrollController.dispose();
    _phoneFocusNode.dispose();
    _usernameFocusNode.dispose();
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
      final referralCode = _showReferralField ? _referralController.text.trim() : null;
      final success = await provider.registerSendOtp(
        completePhoneNumber,
        username,
        _consentAccepted,
        referralCode: referralCode,
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
    setState(() {
      _consentAccepted = false;
      _showReferralField = false;
    });
    _referralController.clear();
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.state == AuthState.loading;
    final isRegisterMode = authProvider.authMode == AuthMode.register;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pageBg = isDark ? AppTheme.backgroundDark : Colors.white;
    final statusBarBg = isDark ? pageBg : const Color(0xFFFF7A00);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(background: statusBarBg, isDark: isDark),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: pageBg,
        body: SingleChildScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Column(
                children: [
                  SizedBox(
                    height: 160 + MediaQuery.paddingOf(context).top,
                    width: double.infinity,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ClipPath(
                            clipper: _HeroClipper(),
                            child: const ColoredBox(color: Color(0xFFFF7A00)),
                          ),
                        ),
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 28,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              const AppLogo(height: 68),
                              const SizedBox(height: 8),
                              const Text(
                                'Buuttii',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),
                        // Heading
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRegisterMode ? 'Create account' : 'Welcome back',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textPrimaryDark : const Color(0xFF1B1C1C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isRegisterMode
                                  ? 'Enter your WhatsApp number and username to continue with your healthy meal journey.'
                                  : 'Enter your WhatsApp number to continue with your healthy meal journey.',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppTheme.textSecondaryDark : const Color(0xFF584235),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Username Field (Register Mode)
                        if (isRegisterMode) ...[
                          _buildMaterialInput(
                            controller: _usernameController,
                            label: 'Username',
                            icon: Icons.person_outline,
                            focusNode: _usernameFocusNode,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Phone Input
                        _buildPhoneInput(),
                        const SizedBox(height: 16),
                        // Referral Code (Register Mode)
                        if (isRegisterMode) ...[
                          if (!_showReferralField)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showReferralField = true;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(Icons.redeem, size: 16, color: isDark ? AppTheme.primaryColor : const Color(0xFF994700)),
                                label: Text(
                                  'Have a referral code?',
                                  style: TextStyle(
                                    color: isDark ? AppTheme.primaryColor : const Color(0xFF994700),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            _buildMaterialInput(
                              controller: _referralController,
                              label: 'Referral Code',
                              icon: Icons.card_giftcard,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(15),
                                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                              ],
                              validator: (value) {
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                        // Terms Checkbox (Register Mode)
                        if (isRegisterMode) ...[
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
                                activeColor: const Color(0xFFFF7A00),
                                visualDensity: VisualDensity.compact,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: isDark ? AppTheme.textSecondaryDark : const Color(0xFF584235),
                                        fontSize: 12.5,
                                        height: 1.35,
                                      ),
                                      children: [
                                        const TextSpan(text: 'I agree to the '),
                                        TextSpan(
                                          text: 'Terms & Conditions',
                                          style: TextStyle(
                                            color: isDark ? AppTheme.primaryColor : const Color(0xFF994700),
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
                                          style: TextStyle(
                                            color: isDark ? AppTheme.primaryColor : const Color(0xFF994700),
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
                          const SizedBox(height: 16),
                        ],
                        // Get OTP Button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _canSubmit
                                ? (isRegisterMode ? _submitRegister : _submitLogin)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF7A00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: const Color(0xFFFF7A00).withOpacity(0.3),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isRegisterMode ? 'Create Account' : 'Get OTP',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Footer
                        Column(
                          children: [
                            Text.rich(
                              TextSpan(
                                text: isRegisterMode
                                    ? 'Already have an account? '
                                    : 'New to Buuttii? ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppTheme.textSecondaryDark : const Color(0xFF584235),
                                ),
                                children: [
                                  TextSpan(
                                    text: isRegisterMode ? 'Login' : 'Register',
                                    style: TextStyle(
                                      color: isDark ? AppTheme.primaryColor : const Color(0xFF994700),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _setMode(
                                            isRegisterMode ? AuthMode.login : AuthMode.register,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ), // Column
            ), // ConstrainedBox
            ),
          ),
      ),
    );
  }

  Widget _buildMaterialInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF6F3F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFF8C7263)),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        validator: validator,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: isDark ? AppTheme.textPrimaryDark : const Color(0xFF1B1C1C),
        ),
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: isDark ? AppTheme.textSecondaryDark : const Color(0xFF584235)),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: TextStyle(
            color: isDark ? AppTheme.textSecondaryDark.withOpacity(0.6) : const Color(0xFF584235),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF6F3F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFF8C7263)),
      ),
      child: Row(
        children: [
          // Country Code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: isDark ? AppTheme.borderDark : const Color(0xFFE0C0AF)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.textPrimaryDark : const Color(0xFF1B1C1C),
                  ),
                ),
              ],
            ),
          ),
          // Phone Input
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onFieldSubmitted: (_) => _submitLogin(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your WhatsApp number';
                }
                if (value.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return 'Please enter a valid 10-digit WhatsApp number';
                }
                return null;
              },
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isDark ? AppTheme.textPrimaryDark : const Color(0xFF1B1C1C),
              ),
              decoration: InputDecoration(
                hintText: 'Phone Number',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                counterText: '',
                hintStyle: TextStyle(
                  color: isDark ? AppTheme.textSecondaryDark.withOpacity(0.6) : const Color(0xFF584235),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width / 2,
      size.height * 1.2,
      size.width,
      size.height * 0.7,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_HeroClipper oldClipper) => false;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/auth/ui/screens/otp_screen.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      final provider = Provider.of<AuthProvider>(context, listen: false);
      final completePhoneNumber = '+91${_phoneController.text.trim()}';
      final success = await provider.sendOtp(completePhoneNumber);

      if (success && mounted) {
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
      } else if (mounted) {
        ErrorHandler.showError(context, provider.errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().state == AuthState.loading;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withOpacity(isDark ? 0.2 : 0.05),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // App Branding
                  Text(
                    'Buuttii Pro',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppTheme.primaryColor,
                      fontSize: 40,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0),
                  
                  // Removed the icon as requested
                  
                  Text(
                    'Welcome',
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    'Enter your phone number to continue',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 32),
                  
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    maxLength: 10,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      counterText: '',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🇮🇳',
                              style: TextStyle(fontSize: 24),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '+91',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              height: 24,
                              width: 1,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 8),
                          ],
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (value.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
                        return 'Please enter a valid 10-digit number';
                      }
                      return null;
                    },
                  ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideX(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 32),
                  
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Login or Register'),
                  ).animate().fadeIn(delay: 600.ms, duration: 500.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

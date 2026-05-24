import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/theme/app_theme.dart';

class LegalScreen extends StatelessWidget {
  final int initialTabIndex;

  const LegalScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Legal Information',
            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
          ),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: const [
              Tab(text: 'Terms & Conditions'),
              Tab(text: 'Privacy Policy'),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withValues(alpha: isDark ? 0.05 : 0.01),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
          child: TabBarView(
            children: [
              _buildTermsTab(context, isDark),
              _buildPrivacyTab(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildDocumentHeader(
          title: 'Terms & Conditions',
          lastUpdated: 'May 2026',
          version: 'v1.0',
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: '1. Welcome & Agreement',
          content: 'Welcome to Buuttii! These Terms & Conditions ("Terms") govern your use of the Buuttii mobile application, website, and related meal subscription services. By registering an account, purchasing a subscription, or using the app, you explicitly agree to be bound by these Terms. If you do not agree, please do not use the app.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '2. User Accounts & Registration',
          content: 'To access our meal subscription services, you must register using a valid WhatsApp phone number. You agree to provide accurate and complete information (e.g., username, profile information). You are entirely responsible for all activities that occur under your account and for maintaining the confidentiality of your registration details.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '3. Subscriptions & Payments',
          content: 'Buuttii offers various recurring meal subscription plans (e.g., parent plan, professional plan, teacher plan). Fees are charged in advance for the selected billing cycle. Payments are processed securely via third-party integrated payment gateways. Subscriptions entitle you to receive meals as described in your chosen plan.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '4. Meal Skips & Customization',
          content: 'Our app supports temporary subscription pauses ("Meal Skips") for planned absences. Skip requests must comply with the minimum consecutive day rules and advance-notice cutoff times configured in the application settings. Standard meal sizes and delivery preferences can be upgraded within the app, subject to additional pricing tiers.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '5. Pricing & Standard Bulk Orders',
          content: 'Bulk orders are subject to specialized tier pricing. Day-of-week custom bulk pricing is specified per daily menu and cannot be modified post-submission. The final checkout summary will display the exact billing details. All pricing figures represent the final agreed amount at the time of purchase.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '6. Limitation of Liability',
          content: 'Buuttii makes every reasonable effort to prepare nutritious meals in hygienic environments. However, to the maximum extent permitted by law, Buuttii is not liable for any indirect, incidental, or consequential damages, including allergic reactions or dietary issues not pre-reported in writing to our official team.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '7. Contact & Support',
          content: 'For questions, requests, or queries regarding these Terms, please reach out to us:\n\n'
              '• Email: contact@buuttii.com\n'
              '• Website: https://buuttii.com/\n'
              '• Address: Buuttii Headquarters, India',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPrivacyTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildDocumentHeader(
          title: 'Privacy Policy',
          lastUpdated: 'May 2026',
          version: 'v1.0',
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: '1. Information We Collect',
          content: 'To deliver a seamless meal delivery experience, we collect and process the following information:\n\n'
              '• Phone Number: Used for authentication via WhatsApp OTP.\n'
              '• Profile Information: Username and role (e.g., parent, teacher, professional).\n'
              '• Delivery Details: Child names, school names, class standard, delivery addresses, corporate location coordinates, and delivery timings.\n'
              '• Device & Tech Data: IP address, device specifications, and user-agent logs recorded at signup for legal consent logs.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '2. How We Use Your Data',
          content: 'Your data is strictly processed to support app services, specifically to:\n\n'
              '• Verify your identity and secure logins via OTP.\n'
              '• Coordinate precise daily meal preparation and route deliveries to classrooms, schools, and offices.\n'
              '• Compute analytics, transaction logs, and total revenue metrics for the administrator panel.\n'
              '• Deliver push alerts and WhatsApp reminders regarding low meal balances or subscription status.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '3. Data Retention & Sharing',
          content: 'We share necessary delivery metrics only with our official kitchen operators and delivery personnel. Payment transactions are processed directly by our secure, PCI-DSS compliant third-party payment gateway. We do not sell or lease your personal information under any circumstances.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '4. Security Safeguards',
          content: 'We employ production-grade physical, technical, and administrative safeguards to protect your personal details against unauthorized access, loss, or manipulation. Access tokens are stored locally on your device using hardware-backed secure storage.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '5. Your Rights & Options',
          content: 'You retain full access rights to your account. You can modify your profile details (e.g., student name, roll number, time preference) using the settings page inside the app. To permanently delete your profile or request data retrieval, contact us via email.',
          isDark: isDark,
        ),
        _buildSectionCard(
          title: '6. Support & Inquiries',
          content: 'For privacy requests, data deletion requests, or other information, please contact us:\n\n'
              '• Email: contact@buuttii.com\n'
              '• Website: https://buuttii.com/\n'
              '• Brand Owner: Buuttii Meal Services',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDocumentHeader({
    required String title,
    required String lastUpdated,
    required String version,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.doc_text_viewfinder,
                color: AppTheme.primaryColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Version: $version',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last Updated: $lastUpdated',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

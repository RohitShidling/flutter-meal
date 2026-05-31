import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/models/lookup_models.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  ContactUsModel? _contactInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContactInfo();
  }

  Future<void> _fetchContactInfo() async {
    try {
      final info = await context.read<LookupProvider>().fetchContactUsInfo();
      if (mounted) {
        setState(() {
          _contactInfo = info;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _copyText(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ErrorHandler.showSuccess(context, '$label copied');
  }

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    // Strip everything except digits
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ErrorHandler.showError(context, 'Could not open WhatsApp');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use default values as fallback
    final title = _contactInfo?.title ?? 'We are here to help.';
    final subtitle = _contactInfo?.subtitle ?? 'For support, contact us at the email below.';
    final email = _contactInfo?.email ?? 'contact@buuttii.com';
    final phone = _contactInfo?.phone ?? '';
    final footer = _contactInfo?.footer ?? 'Tap Copy to use this email anywhere you want.';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Contact Us',
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (email.isNotEmpty) ...[
                  _contactTile(
                    context,
                    icon: CupertinoIcons.mail_solid,
                    title: 'Email',
                    value: email,
                    isDark: isDark,
                    onCopy: () => _copyText(context, 'Email', email),
                  ),
                  const SizedBox(height: 18),
                ],
                if (phone.isNotEmpty) ...[
                  _contactTile(
                    context,
                    icon: CupertinoIcons.phone_fill,
                    title: 'Phone',
                    value: phone,
                    isDark: isDark,
                    onCopy: () => _copyText(context, 'Phone', phone),
                    extraAction: TextButton.icon(
                      onPressed: () => _openWhatsApp(context, phone),
                      icon: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (footer.isNotEmpty)
                  Text(
                    footer,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _contactTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
    required VoidCallback onCopy,
    Widget? extraAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          if (extraAction != null) extraAction,
          TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(CupertinoIcons.doc_on_doc, size: 16),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}

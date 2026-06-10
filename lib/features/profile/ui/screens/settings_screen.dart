import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/theme_provider.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/subscription_management_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/cart_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/meal_size_upgrade_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/wallet_screen.dart';
import 'package:meal_app/features/profile/ui/screens/profile_details_screen.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/profile/ui/screens/contact_us_screen.dart';
import 'package:meal_app/features/profile/ui/screens/legal_screen.dart';
import 'package:meal_app/features/home/ui/widgets/bottom_footer_nav.dart';
import 'package:meal_app/core/navigation/app_routes.dart';
import 'package:meal_app/features/announcements/ui/screens/announcements_screen.dart';
import 'package:meal_app/features/profile/ui/screens/refer_earn_screen.dart';
import 'package:meal_app/features/profile/providers/referral_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ContactUsModel? _contactInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PaymentProvider>().fetchWallet(silent: true);
      context.read<ReferralProvider>().fetchRewards();
      _loadAboutConfig();
    });
  }

  Future<void> _loadAboutConfig() async {
    try {
      final info = await context.read<LookupProvider>().fetchContactUsInfo();
      if (mounted) setState(() => _contactInfo = info);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.read<AuthProvider>();
    final pay = context.watch<PaymentProvider>();
    final referralProvider = context.watch<ReferralProvider>();
    final walletBalance = pay.walletBalance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showReferralBadge = referralProvider.hasUnclaimedRewards;

    final pageBg = isDark ? AppTheme.backgroundDark : const Color(0xFFFAF8F5);
    final navBarColor = isDark ? AppTheme.surfaceDark : Colors.white;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayFor(background: pageBg, isDark: isDark, navigationBarColor: navBarColor),
        child: Scaffold(
          backgroundColor: pageBg,
        appBar: AppBar(
          title: Text(
            'Settings',
            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
          ),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionHeader('Profile Details', isDark),
            _buildNavigationTile(
              context,
              CupertinoIcons.person_crop_circle_fill,
              'My Profile',
              isDark,
              () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (context) => const ProfileDetailsScreen()),
                );
              },
            ),
            if (authProvider.isReferEarnActive) ...[
              const SizedBox(height: 8),
              _buildNavigationTile(
                context,
                CupertinoIcons.gift_fill,
                'Refer & Earn',
                isDark,
                () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const ReferEarnScreen()),
                  );
                },
                showBadge: showReferralBadge,
              ),
            ],
            const SizedBox(height: 8),
            _buildNavigationTile(
              context,
              CupertinoIcons.creditcard_fill, 
              'Subscriptions & Payments', 
              isDark,
              () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (context) => const SubscriptionManagementScreen()),
                );
              }
            ),
            const SizedBox(height: 8),
            _buildNavigationTile(
              context,
              CupertinoIcons.money_dollar_circle_fill,
              walletBalance != null && walletBalance.isNotEmpty
                  ? 'My Wallet — ₹$walletBalance'
                  : 'My Wallet',
              isDark,
              () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const WalletScreen())),
            ),
            const SizedBox(height: 30),

            _buildSectionHeader('Meal Management', isDark),
            _buildNavigationTile(
              context,
              CupertinoIcons.calendar_badge_minus,
              'Meal Skips',
              isDark,
              () => Navigator.of(context).pushReplacementNamed(AppRoutes.mealSkip),
            ),
            const SizedBox(height: 8),
            _buildNavigationTile(
              context,
              CupertinoIcons.arrow_up_down_circle_fill,
              'Resize your meal pack',
              isDark,
              () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const MealSizeUpgradeScreen())),
            ),
            const SizedBox(height: 8),
            _buildNavigationTile(
              context,
              CupertinoIcons.cart_fill,
              'Cart',
              isDark,
              () async {
                await context.read<CartProvider>().fetchCart(force: true);
                if (!context.mounted) return;
                Navigator.push(context, CupertinoPageRoute(builder: (_) => const CartScreen()));
              },
            ),
            const SizedBox(height: 30),

            _buildSectionHeader('App Customization', isDark),
            _buildThemeTile(context, themeProvider, isDark),
            const SizedBox(height: 8),
            _buildNavigationTile(
              context,
              CupertinoIcons.bell_fill,
              'Announcements',
              isDark,
              () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const AnnouncementsScreen()),
              ),
            ),
            const SizedBox(height: 30),

            _buildSectionHeader('Help & Support', isDark),
            _buildNavigationTile(
              context,
              CupertinoIcons.mail_solid,
              'Contact Us',
              isDark,
              () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const ContactUsScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _buildNavigationTile(
              context,
              CupertinoIcons.globe,
              'Visit Website',
              isDark,
              () => _launchUrl(context, _contactInfo?.websiteUrl ?? 'https://buuttii.com/'),
            ),
            const SizedBox(height: 30),

            _buildSectionHeader('Legal & Compliance', isDark),
            _buildNavigationTile(
              context,
              CupertinoIcons.doc_text_fill,
              'Terms & Conditions',
              isDark,
              () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const LegalScreen(initialTabIndex: 0)),
              ),
            ),
            const SizedBox(height: 8),
            _buildNavigationTile(
              context,
              CupertinoIcons.shield_fill,
              'Privacy Policy',
              isDark,
              () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const LegalScreen(initialTabIndex: 1)),
              ),
            ),
            const SizedBox(height: 30),
            
            _buildSectionHeader('About', isDark),
            _buildNavigationTile(
              context,
              CupertinoIcons.info_circle_fill,
              (() {
                final contactInfo = _contactInfo;
                final aboutTitle = contactInfo == null ? null : contactInfo.aboutTitle?.trim();
                if (aboutTitle != null && aboutTitle.isNotEmpty) return aboutTitle;
                final appName = contactInfo == null ? null : contactInfo.appName?.trim();
                return appName != null && appName.isNotEmpty ? 'About $appName' : 'About Us';
              })(),
              isDark,
              () => _showAboutDialog(context, isDark),
            ),
            const SizedBox(height: 50),
            
            _buildLogoutButton(context, authProvider),
          ],
        ),
        bottomNavigationBar: BuuttiiFooterNav(
          currentIndex: 3,
          onHomeTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          onWeekMenuTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.weeklyMenu),
          onMealSkipTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.mealSkip),
          onSettingsTap: () {},
        ),
       ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context, ThemeProvider themeProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF7F4EF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            themeProvider.isDarkMode ? CupertinoIcons.moon_stars_fill : CupertinoIcons.sun_max_fill, 
            color: Colors.orange, 
            size: 20
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Dark Mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
          ),
          CupertinoSwitch(
            value: themeProvider.isDarkMode,
            onChanged: (value) => themeProvider.toggleTheme(value),
            activeTrackColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile(BuildContext context, IconData icon, String title, bool isDark, VoidCallback onTap, {bool showBadge = false}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppTheme.primaryColor, size: 20),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          if (showBadge) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(CupertinoIcons.layers_alt_fill, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 10),
              Text(
                (() {
                  final contactInfo = _contactInfo;
                  final aboutTitle = contactInfo == null ? null : contactInfo.aboutTitle?.trim();
                  if (aboutTitle != null && aboutTitle.isNotEmpty) return aboutTitle;
                  final appName = contactInfo == null ? null : contactInfo.appName?.trim();
                  return appName != null && appName.isNotEmpty ? 'About $appName' : 'About Us';
                })(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                (() {
                  final contactInfo = _contactInfo;
                  final aboutDescription = contactInfo == null ? null : contactInfo.aboutDescription?.trim();
                  return aboutDescription != null && aboutDescription.isNotEmpty
                      ? aboutDescription
                      : 'This app helps you manage meal subscriptions, menus, and skips in one place.';
                })(),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'When one of your active plans reaches four meals left, the app shows a gentle in-app reminder (once per day) so you can renew in time.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _showLicenseDialog(dialogContext, isDark),
              child: const Text('License'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showLicenseDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '${_contactInfo?.appName ?? 'This App'} License',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              (() {
                final contactInfo = _contactInfo;
                final licenseText = contactInfo == null ? null : contactInfo.licenseText?.trim();
                if (licenseText != null && licenseText.isNotEmpty) return licenseText;
                final appName = contactInfo == null ? null : contactInfo.appName?.trim();
                final brand = appName != null && appName.isNotEmpty ? appName : 'This App';
                return 'Copyright (c) ${DateTime.now().year} $brand.\n\n'
                    'This mobile application and its content are proprietary to $brand and intended for authorized meal subscription use only.\n\n'
                    'Unauthorized copying, redistribution, reverse engineering, or commercial reuse of app content, branding, or data is prohibited.\n\n'
                    'Use of this app is subject to $brand policies and applicable local laws.';
              })(),
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    return ElevatedButton(
      onPressed: () {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () async {
                  Navigator.of(context).pop();
                  await authProvider.logout();
                  if (!mounted) return;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
        foregroundColor: AppTheme.accentColor,
        elevation: 0,
      ),
      child: const Text('Logout Account'),
    );
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
      if (!context.mounted) return;
      final isEmail = url.scheme == 'mailto';
      ErrorHandler.showError(
        context,
        isEmail
            ? 'No email app is available on this device.'
            : 'Could not open this link right now.',
      );
    } catch (_) {
      if (!context.mounted) return;
      final isEmail = url.scheme == 'mailto';
      ErrorHandler.showError(
        context,
        isEmail
            ? 'No email app is available on this device.'
            : 'Could not open this link right now.',
      );
    }
  }
}

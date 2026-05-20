import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/theme_provider.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/subscription_management_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/meal_skip_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/cart_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/meal_size_upgrade_screen.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_delivery_address_settings_screen.dart';
import 'package:meal_app/core/providers/cart_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Profile Details', isDark),
          _buildNavigationTile(
            context,
            CupertinoIcons.person_crop_circle_fill,
            'My Details',
            isDark,
            () => _showDetailsSheet(context, authProvider, isDark),
          ),
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
          const SizedBox(height: 30),
          
          const SizedBox(height: 30),

          _buildSectionHeader('Meal Management', isDark),
          _buildNavigationTile(
            context,
            CupertinoIcons.calendar_badge_minus,
            'Meal Skips',
            isDark,
            () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const MealSkipScreen())),
          ),
          const SizedBox(height: 8),
          _buildNavigationTile(
            context,
            CupertinoIcons.arrow_up_circle_fill,
            'Upgrade your meal size',
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
          const SizedBox(height: 8),
          _buildNavigationTile(
            context,
            CupertinoIcons.location_fill,
            'Bulk delivery address',
            isDark,
            () => Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const BulkDeliveryAddressSettingsScreen()),
            ),
          ),
          const SizedBox(height: 30),

          _buildSectionHeader('App Customization', isDark),
          _buildThemeTile(context, themeProvider, isDark),
          const SizedBox(height: 30),
          
          _buildSectionHeader('About', isDark),
          _buildNavigationTile(
            context,
            CupertinoIcons.info_circle_fill, 
            'About Buuttii',
            isDark,
            () => _showAboutDialog(context, isDark),
          ),
          const SizedBox(height: 50),
          
          _buildLogoutButton(context, authProvider),
        ],
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

  void _showDetailsSheet(BuildContext context, AuthProvider authProvider, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoTile(CupertinoIcons.person_fill, 'Username', authProvider.username.isNotEmpty ? authProvider.username : 'User', isDark),
            _buildInfoTile(CupertinoIcons.phone_fill, 'Phone Number', authProvider.phoneNumber, isDark),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Close'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context, ThemeProvider themeProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
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

  Widget _buildNavigationTile(BuildContext context, IconData icon, String title, bool isDark, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppTheme.primaryColor, size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
        ),
      ),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
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
                'About Buuttii',
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
                'Buuttii helps parents, teachers, and professionals manage daily meal subscriptions, menus, and skips in one place.',
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
            'Buuttii License',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              'Copyright (c) ${DateTime.now().year} Buuttii.\n\n'
              'This mobile application and its content are proprietary to Buuttii and intended for authorized meal subscription use only.\n\n'
              'Unauthorized copying, redistribution, reverse engineering, or commercial reuse of app content, branding, or data is prohibited.\n\n'
              'Use of this app is subject to Buuttii policies and applicable local laws.',
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
                onPressed: () {
                  Navigator.pop(context);
                  authProvider.logout();
                  Navigator.pop(context); // Go back to home/login
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
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/children/ui/screens/children_management_screen.dart';
import 'package:meal_app/features/profile/ui/screens/teacher_profile_screen.dart';
import 'package:meal_app/features/profile/ui/screens/professional_profile_screen.dart';
import 'package:meal_app/features/profile/ui/screens/settings_screen.dart';
import 'package:meal_app/features/home/ui/screens/subscription_screen.dart';
import 'package:meal_app/features/home/providers/homepage_provider.dart';
import 'package:meal_app/features/home/data/models/homepage_entry.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/features/home/ui/screens/weekly_menu_screen.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/meal_skip_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/cart_screen.dart';
import 'package:meal_app/core/widgets/image_preview_dialog.dart';
import 'package:meal_app/features/subscription/ui/screens/subscription_management_screen.dart';
import 'package:meal_app/core/services/connectivity_service.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _displayName = '';
  ConnectivityService? _connectivityService;
  bool _wasOnline = true;

  @override
  void initState() {
    super.initState();
    NetworkStatusService.instance.addBecameOnlineListener(_onBecameOnline);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapHome());
  }

  @override
  void dispose() {
    NetworkStatusService.instance.removeBecameOnlineListener(_onBecameOnline);
    super.dispose();
  }

  /// Refresh home-critical data when connectivity returns (realtime UX).
  void _onBecameOnline() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.wait([
        context.read<HomepageProvider>().fetchHomepageEntries(force: true, silent: true),
        context.read<MenuProvider>().fetchTodayMenu(silent: true),
        context.read<CartProvider>().fetchCart(force: true, silent: true),
        context.read<AuthProvider>().refreshMeProfile(silent: true),
      ]);
      if (!mounted) return;
      await _refreshMealDataBundle();
      if (mounted) _syncDisplayNameFromAuth();
    });
  }

  /// Cold start / return-to-home: cache-first essentials, then meal bundle only when online.
  Future<void> _bootstrapHome() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final forceFresh = auth.consumePendingDashboardRefresh();

    if (forceFresh) {
      await Future.wait([
        context.read<HomepageProvider>().fetchHomepageEntries(force: true, silent: true),
        context.read<MenuProvider>().fetchTodayMenu(silent: true),
        context.read<CartProvider>().fetchCart(force: true, silent: true),
        context.read<AuthProvider>().refreshMeProfile(silent: true, forceNetwork: true),
        context.read<SubscriptionProvider>().fetchSubscriptions(force: true, silent: true),
      ]);
    } else {
      await _loadAllData();
    }
    if (!mounted) return;
    _syncDisplayNameFromAuth();
    await _refreshMealDataBundle();
    if (mounted) _syncDisplayNameFromAuth();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    await Future.wait([
      context.read<HomepageProvider>().fetchHomepageEntries(silent: true),
      context.read<MenuProvider>().fetchTodayMenu(silent: true),
      context.read<CartProvider>().fetchCart(silent: true),
      context.read<AuthProvider>().refreshMeProfile(silent: true),
    ]);
  }

  Future<void> _refreshMealDataBundle() async {
    if (!mounted || !NetworkStatusService.instance.isOnline) return;
    final meal = context.read<MealProvider>();
    await Future.wait([
      meal.fetchAlerts(silent: true),
      meal.fetchMealStatus(silent: true),
      meal.fetchSubscriptionStatus(silent: true),
    ]);
  }

  void _syncDisplayNameFromAuth() {
    if (!mounted) return;
    final name = context.read<AuthProvider>().username.trim();
    setState(() {
      _displayName = name.isNotEmpty ? name : 'User';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          if (!mounted) return;
          await Future.wait([
            context.read<HomepageProvider>().fetchHomepageEntries(force: true, silent: true),
            context.read<MenuProvider>().fetchTodayMenu(silent: true),
            context.read<CartProvider>().fetchCart(force: true, silent: true),
            context.read<AuthProvider>().refreshMeProfile(
              silent: true,
              forceNetwork: NetworkStatusService.instance.isOnline,
            ),
          ]);
          if (!mounted) return;
          await _refreshMealDataBundle();
          if (mounted) _syncDisplayNameFromAuth();
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: SafeArea(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(context),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildWelcomeSection(isDark),
                      // Today's meal section — only visible for subscribed users
                      _buildTodayMealCard(context, isDark),
                      _buildAlertsBanner(context, isDark),
                      _buildFeatureCards(context),
                      const SizedBox(height: 20),
                      _buildQuickStatus(context),
                      const SizedBox(height: 30),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final itemCount = context.watch<CartProvider>().itemCount;
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: const Text(
        'Buuttii',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
        ),
      ),
      actions: [
        // Always show upgrade button
        _buildSubscribeButton(context),
        const SizedBox(width: 6),
        // Show cart icon only when cart has items
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, axis: Axis.horizontal, child: child),
            );
          },
          child: itemCount > 0
              ? Row(
                  key: const ValueKey('cart-visible'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCartActionButton(context),
                    const SizedBox(width: 6),
                  ],
                )
              : const SizedBox(key: ValueKey('cart-hidden')),
        ),
        IconButton(
          icon: const Icon(CupertinoIcons.settings_solid, size: 24),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildCartActionButton(BuildContext context) {
    final itemCount = context.watch<CartProvider>().itemCount;
    final badgeColor = Theme.of(context).colorScheme.error;

    return IconButton(
      onPressed: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const CartScreen()),
        );
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            CupertinoIcons.cart_fill,
            size: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          if (itemCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      tooltip: itemCount > 0 ? 'Cart ($itemCount)' : 'Cart',
    );
  }

  Widget _buildSubscribeButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) => const SubscriptionScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4D00), Color(0xFFFF8533)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D00).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 14),
              const SizedBox(width: 5),
              const Text(
                'UPGRADE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    )
    .animate(onPlay: (controller) => controller.repeat())
    .shimmer(duration: 2500.ms, color: Colors.white.withOpacity(0.4))
    .scale(duration: 2000.ms, begin: const Offset(1, 1), end: const Offset(1.02, 1.02), curve: Curves.easeInOut);
  }

  Widget _buildWelcomeSection(bool isDark) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final name = _displayName.isNotEmpty ? _displayName.trim() : 'User';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [AppTheme.primaryColor.withOpacity(0.2), Colors.transparent]
            : [AppTheme.primaryColor.withOpacity(0.05), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Text(
            'Welcome Back ',
            style: textTheme.titleMedium?.copyWith(
              fontSize: 18,
              color: colorScheme.onSurface.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              softWrap: true,
              style: textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  /// Today's meal card — ONLY shown when user has active subscription.
  /// Shows today's meal image and a "One Week Meal" button.
  /// If not subscribed, returns SizedBox.shrink() (no gap).
  Widget _buildTodayMealCard(BuildContext context, bool isDark) {
    final menuProvider = context.watch<MenuProvider>();

    // If loading or not subscribed or no menu, show nothing (no gap)
    if (menuProvider.isLoading) return const SizedBox.shrink();
    if (!menuProvider.isSubscribed) return const SizedBox.shrink();
    if (menuProvider.todayMenu == null) return const SizedBox.shrink();

    final menu = menuProvider.todayMenu!;
    final imageUrl = menu['image_url']?.toString();
    final items = menu['items']?.toString() ?? menu['item_name']?.toString() ?? 'Today\'s Meal';
    final menuDate = menu['menu_date']?.toString() ?? '';
    final nutritionPoints = (menu['nutrition_points'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [Colors.white, const Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Meal image — tappable for preview
            GestureDetector(
              onTap: () {
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  ImagePreviewDialog.show(context, imageUrl, title: items);
                }
              },
              child: _buildMealImage(imageUrl, 140),
            ),

            // Meal info row + button — compact
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Meal name + TODAY badge — compact single row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          items,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          menuDate.isNotEmpty ? 'TODAY' : 'MEAL',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (nutritionPoints.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: nutritionPoints.map((point) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.leaf_arrow_circlepath, size: 14, color: AppTheme.primaryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    point,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (_) => const WeeklyMenuScreen()),
                        );
                      },
                      icon: const Icon(CupertinoIcons.calendar, size: 18),
                      label: const Text(
                        'One Week Meal',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
    );
  }

  /// Builds the meal image with placeholder fallback (reusable).
  Widget _buildMealImage(String? imageUrl, double height) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          height: height,
          width: double.infinity,
          fit: BoxFit.contain,
          placeholder: (_, __) => _buildMealPlaceholder(height),
          errorWidget: (_, __, ___) => _buildMealPlaceholder(height),
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: _buildMealPlaceholder(height),
    );
  }

  Widget _buildMealPlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.15),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.flame_fill, size: 40, color: AppTheme.primaryColor.withOpacity(0.5)),
            const SizedBox(height: 6),
            Text(
              'Today\'s Meal',
              style: TextStyle(
                color: AppTheme.primaryColor.withOpacity(0.6),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsBanner(BuildContext context, bool isDark) {
    final mealProvider = context.watch<MealProvider>();
    final alerts = mealProvider.alerts;
    
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
      children: alerts.map<Widget>((alert) {
        final message = alert['message']?.toString() ?? 'Subscription expiring soon';
        final remainingDays = alert['remaining_days'];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    if (remainingDays != null)
                      Text(
                        '$remainingDays day(s) remaining',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const SubscriptionScreen())),
                child: const Text('Renew', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
        ).animate().fadeIn().slideX(begin: -0.1, end: 0);
      }).toList(),
      ),
    );
  }

  /// Quick actions — conditionally shown:
  /// - Meal Skips: only when user has active subscription
  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final mealProvider = context.watch<MealProvider>();
    final isSubscribed = mealProvider.isSubscribed;

    if (!isSubscribed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionTile(
              context,
              'Meal Skips',
              CupertinoIcons.calendar_badge_minus,
              Colors.orange,
              isDark,
              () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const MealSkipScreen())),
            ),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms),
    );
  }

  Widget _buildQuickActionTile(BuildContext context, String label, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: isDark ? Colors.white38 : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCards(BuildContext context) {
    final homepageProvider = context.watch<HomepageProvider>();

    // Show cached data immediately; only show spinner if truly empty and loading.
    if (homepageProvider.entries.isEmpty && homepageProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (homepageProvider.entries.isEmpty) {
      return const Center(child: Text('No features available'));
    }

    return Column(
      children: homepageProvider.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildFeatureCard(
            context,
            entry.name,
            entry.description,
            _getIconForEntry(entry),
            _getColorForEntry(entry),
            () => _handleCardTap(context, entry),
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconForEntry(HomepageEntry entry) {
    switch (entry.entityId) {
      case 'ENT-1':
        return CupertinoIcons.person_3_fill;
      case 'ENT-2':
        return CupertinoIcons.book_fill;
      case 'ENT-3':
        return CupertinoIcons.briefcase_fill;
      default:
        return CupertinoIcons.square_grid_2x2_fill;
    }
  }

  Color _getColorForEntry(HomepageEntry entry) {
    switch (entry.entityId) {
      case 'ENT-1':
        return Colors.blue;
      case 'ENT-2':
        return Colors.green;
      case 'ENT-3':
        return Colors.orange;
      default:
        return AppTheme.primaryColor;
    }
  }

  /// Stable, entity-id–based routing (no more fuzzy name matching).
  /// Backend returns `entity_id` like `ENT-1` (child), `ENT-2` (teacher),
  /// `ENT-3` (professional). Anything else is treated as not-yet-supported.
  void _handleCardTap(BuildContext context, HomepageEntry entry) {
    switch (entry.entityId) {
      case 'ENT-1':
        context.read<ChildrenProvider>().fetchChildren().whenComplete(() {
          if (!context.mounted) return;
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const ChildrenManagementScreen()),
          );
        });
        return;
      case 'ENT-2':
        context.read<ProfileProvider>().fetchProfiles().whenComplete(() {
          if (!context.mounted) return;
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const TeacherProfileScreen()),
          );
        });
        return;
      case 'ENT-3':
        context.read<ProfileProvider>().fetchProfiles().whenComplete(() {
          if (!context.mounted) return;
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const ProfessionalProfileScreen()),
          );
        });
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This feature is coming soon.')),
        );
    }
  }

  Widget _buildFeatureCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppleCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(vertical: 2), // Tighter margin
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 4,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                    style: TextStyle(
                      fontSize: 12,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const Icon(CupertinoIcons.chevron_right, color: Colors.grey, size: 18),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _buildQuickStatus(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mealProvider = context.watch<MealProvider>();
    final isActive = mealProvider.subscriptionStatusData?['has_active_subscription'] == true;
    final childrenCount = context.watch<ChildrenProvider>().children.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 12),
        // Compact, production-grade activity row — children count + plan status pill.
        _buildActivitySummary(context, isDark, childrenCount: childrenCount, isActive: isActive),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  /// Compact single-card activity summary: children + plan status side by side.
  /// Tapping the plan-status side navigates to subscription management when
  /// active, or opens upgrade flow when inactive — never blocks the user.
  Widget _buildActivitySummary(
    BuildContext context,
    bool isDark, {
    required int childrenCount,
    required bool isActive,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: Children
            Expanded(
              child: InkWell(
                onTap: () {
                  context.read<ChildrenProvider>().fetchChildren(silent: true).whenComplete(() {
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const ChildrenManagementScreen()),
                    );
                  });
                },
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.person_3_fill, color: Colors.blue, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$childrenCount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                              ),
                            ),
                            Text(
                              'Children',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Vertical divider
            Container(width: 1, color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.12)),
            // Right: Plan status pill — compact + tappable
            Expanded(
              child: _buildPlanStatusPill(context, isDark, isActive: isActive),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanStatusPill(BuildContext context, bool isDark, {required bool isActive}) {
    final color = isActive ? Colors.green : Colors.red;
    final icon = isActive ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.exclamationmark_circle_fill;
    final title = 'My Subscription';
    final subtitle = isActive ? 'Active Plan' : 'No Active Plan';

    return InkWell(
      onTap: () {
        if (isActive) {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const SubscriptionManagementScreen()),
          );
        } else {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const SubscriptionScreen()),
          );
        }
      },
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: isDark ? Colors.white38 : Colors.grey),
          ],
        ),
      ),
    );
  }
}

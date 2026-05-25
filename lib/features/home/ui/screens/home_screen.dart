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
import 'package:meal_app/features/home/providers/homepage_provider.dart';
import 'package:meal_app/features/home/data/models/homepage_entry.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/features/home/ui/screens/weekly_menu_screen.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/view_all_plans_screen.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_cart_screen.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/meal_skip_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/cart_screen.dart';
import 'package:meal_app/core/widgets/image_preview_dialog.dart';
import 'package:meal_app/features/subscription/ui/screens/subscription_management_screen.dart';


import 'package:meal_app/core/services/network_status_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/utils/subscription_status_normalize.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/core/services/offline_cache_bootstrap.dart';
import 'package:meal_app/core/widgets/app_skeleton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.home);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapHome());
  }

  @override
  void dispose() {
    AppRouteTracker.instance.clearIfCurrent(AppScreen.home);
    super.dispose();
  }


  /// Cold start / return-to-home: cache-first essentials, then meal bundle only when online.
  Future<void> _bootstrapHome() async {
    if (!mounted) return;
    await OfflineCacheBootstrap.warmIfNeeded(context);
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final forceFresh = auth.consumePendingDashboardRefresh();

    if (forceFresh) {
      await Future.wait([
        context.read<HomepageProvider>().fetchHomepageEntries(force: true, silent: true),
        context.read<MenuProvider>().fetchTodayMenu(silent: true),
        context.read<CartProvider>().fetchCart(force: true, silent: true),
        context.read<AuthProvider>().refreshMeProfile(silent: true, forceNetwork: true),
      ]);
    } else {
      await _loadAllData();
    }
    if (!mounted) return;
    _syncDisplayNameFromAuth();
    await _refreshMealDataBundle();
    if (!mounted) return;
    await _maybePromptFourMealsLeftDialog();
    if (!mounted) return;
    if (NetworkStatusService.instance.isOnline) {
      await context.read<MenuProvider>().fetchTodayMenu(
        silent: true,
      );
    }

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

  static const _prefFourMealsDialogDay = 'four_meals_left_dialog_shown_ymd';

  /// In-app renewal nudge when any active line has exactly four meals left (once per session day).
  Future<void> _maybePromptFourMealsLeftDialog() async {
    if (!mounted || !NetworkStatusService.instance.isOnline) return;
    final meal = context.read<MealProvider>();
    final hasFourRow = meal.mealStatus.where((row) {
      if (row is! Map) return false;
      final r = row['remaining_meals'] ?? row['remainingMeals'];
      final n = int.tryParse('$r');
      return n == 4;
    }).firstOrNull;
    if (hasFourRow == null) return;

    final ymd = MealDate.sessionTodayYmd();
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefFourMealsDialogDay$ymd';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);

    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('4 meals remaining'),
        content: const Text(
          'You have only four meals left on one of your active plans. Renew now so deliveries are not interrupted.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not now'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              final entityType = hasFourRow['entity_type']?.toString();
              final entityId = hasFourRow['entity_id']?.toString();
              if (entityType == 'child') {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => ChildrenManagementScreen(renewChildId: entityId),
                  ),
                );
              } else if (entityType == 'teacher') {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const TeacherProfileScreen(renew: true),
                  ),
                );
              } else if (entityType == 'professional') {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const ProfessionalProfileScreen(renew: true),
                  ),
                );
              } else {
                _openUpgradeWithFirstProfile(context);
              }
            },
            child: const Text('View plans'),
          ),
        ],
      ),
    );
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
        systemNavigationBarColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
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
          if (!mounted) return;
          await _maybePromptFourMealsLeftDialog();
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
                      _buildWelcomeSection(context, isDark),
                      _buildUpcomingPlanCard(context, isDark),
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
        _buildPlansButton(context),
        if (context.watch<BulkOrderProvider>().hasBulkCartItems) ...[
          const SizedBox(width: 6),
          _buildBulkCartActionButton(context),
        ],
        if (context.watch<CartProvider>().itemCount > 0) ...[
          const SizedBox(width: 6),
          _buildCartActionButton(context),
        ],
        const SizedBox(width: 4),
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
              right: -8,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  itemCount > 99 ? '99+' : '$itemCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      tooltip: itemCount > 0 ? 'Cart ($itemCount)' : 'Cart',
    );
  }

  Widget _buildBulkCartActionButton(BuildContext context) {
    final count = context.watch<BulkOrderProvider>().bulkCartTotalMeals;
    final badgeColor = Theme.of(context).colorScheme.secondary;

    return IconButton(
      onPressed: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const BulkOrderCartScreen()),
        );
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            CupertinoIcons.bag_fill,
            size: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          if (count > 0)
            Positioned(
              right: -8,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      tooltip: 'Bulk cart ($count)',
    );
  }

  void _navigateToChildrenManage(BuildContext context) {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => const ChildrenManagementScreen()));
  }

  void _navigateToTeacherProfile(BuildContext context) {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => const TeacherProfileScreen()));
  }

  void _navigateToProfessionalProfile(BuildContext context) {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => const ProfessionalProfileScreen()));
  }

  Future<void> _openFirstAvailableManageScreen(BuildContext context) async {
    await Future.wait([
      context.read<ChildrenProvider>().fetchChildren(silent: true),
      context.read<ProfileProvider>().fetchProfiles(silent: true),
    ]);
    if (!context.mounted) return;
    final children = context.read<ChildrenProvider>().children.where((c) => (c.id ?? '').toString().isNotEmpty).toList();
    if (children.isNotEmpty) {
      _navigateToChildrenManage(context);
      return;
    }
    final teacher = context.read<ProfileProvider>().teacherProfile;
    if (teacher != null && (teacher.id ?? '').toString().isNotEmpty) {
      _navigateToTeacherProfile(context);
      return;
    }
    final professional = context.read<ProfileProvider>().professionalProfile;
    if (professional != null && (professional.id ?? '').toString().isNotEmpty) {
      _navigateToProfessionalProfile(context);
      return;
    }
    _navigateToChildrenManage(context);
  }

  Future<void> _openUpgradeWithFirstProfile(BuildContext context) async {
    await _openFirstAvailableManageScreen(context);
  }

  Widget _buildPlansButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: GestureDetector(
        onTap: () {
          context.read<SubscriptionProvider>().fetchSubscriptions(silent: true);
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const ViewAllPlansScreen()),

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
                color: const Color(0xFFFF4D00).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.square_list_fill, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Text(
                'Plans',
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
    .shimmer(duration: 2500.ms, color: Colors.white.withValues(alpha: 0.4))
    .scale(duration: 2000.ms, begin: const Offset(1, 1), end: const Offset(1.02, 1.02), curve: Curves.easeInOut);

  }

  Widget _buildWelcomeSection(BuildContext context, bool isDark) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final name = _displayName.isNotEmpty ? _displayName.trim() : 'User';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [AppTheme.primaryColor.withValues(alpha: 0.2), Colors.transparent]
            : [AppTheme.primaryColor.withValues(alpha: 0.05), Colors.transparent],

        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Text(
            'Welcome Back, ',
            style: textTheme.titleMedium?.copyWith(
              fontSize: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
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

  /// Separate card below welcome — upcoming plan start date (industry-style status card).
  Widget _buildUpcomingPlanCard(BuildContext context, bool isDark) {
    final statusData = context.watch<MealProvider>().subscriptionStatusData;
    if (!SubscriptionStatusNormalizer.accountHasOnlyUpcoming(statusData)) {
      return const SizedBox.shrink();
    }

    final upcomingStart = SubscriptionStatusNormalizer.earliestUpcomingStartYmd(statusData);
    final upcomingLabel = upcomingStart != null ? MealDate.formatDisplay(upcomingStart) : null;
    if (upcomingLabel == null) return const SizedBox.shrink();
    final upcomingMessage = _upcomingPlanMessage(statusData, upcomingStart, upcomingLabel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppleCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.calendar_badge_plus, color: Color(0xFFEAB308), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Upcoming plan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        upcomingMessage,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0);
  }

  String _upcomingPlanMessage(
    Map<String, dynamic>? statusData,
    String? upcomingStart,
    String upcomingLabel,
  ) {
    final groups = _upcomingPlanGroups(statusData);
    if (groups.isEmpty) {
      if (upcomingStart == null) return 'Your plan starts receiving meals soon';
      return 'Your plan starts receiving meals from $upcomingLabel';
    }

    final parts = <String>[];
    for (final group in groups.take(2)) {
      final names = List<String>.from(group['names'] as List);
      final label = group['label'] as String;
      final profileLabel = _formatUpcomingNames(names);
      final isPlural = names.length > 1;
      parts.add(
        isPlural
            ? '$profileLabel start receiving meals from $label'
            : '$profileLabel starts receiving meals from $label',
      );
    }

    if (groups.length > 2) {
      parts.add('${groups.length - 2} more upcoming plan(s) scheduled after that');
    }

    return parts.join('. ');
  }

  List<Map<String, dynamic>> _upcomingPlanGroups(Map<String, dynamic>? statusData) {
    if (statusData == null) return const [];
    final rows = statusData['entities'] is List
        ? statusData['entities'] as List
        : (statusData['data'] is List ? statusData['data'] as List : const []);
    final today = MealDate.sessionTodayYmd();
    final grouped = <String, List<String>>{};

    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if (!SubscriptionStatusNormalizer.rowIsUpcoming(map, today)) continue;
      final start = map['start_date']?.toString();
      final startYmd = (start != null && start.length >= 10) ? start.substring(0, 10) : null;
      if (startYmd == null) continue;
      final name = map['entity_name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        final names = grouped.putIfAbsent(startYmd, () => <String>[]);
        if (!names.contains(name)) {
          names.add(name);
        }
      }
    }

    final sortedKeys = grouped.keys.toList()..sort();
    return sortedKeys
        .map((ymd) => {
              'start': ymd,
              'label': MealDate.formatDisplay(ymd),
              'names': grouped[ymd]!,
            })
        .toList();
  }

  String _formatUpcomingNames(List<String> names) {
    if (names.isEmpty) return 'Your plan';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names[0]} +${names.length - 1} more';
  }

  /// Today's meal card — ONLY shown when user has active subscription.
  /// Shows today's meal image and a "One Week Meal" button.
  /// If not subscribed, returns SizedBox.shrink() (no gap).
  Widget _buildTodayMealCard(BuildContext context, bool isDark) {
    final menuProvider = context.watch<MenuProvider>();
    final mealProvider = context.watch<MealProvider>();

    if (!mealProvider.isSubscribed) return const SizedBox.shrink();

    final msg = menuProvider.homeMealMessage?.trim() ?? '';
    if (menuProvider.isLoading && menuProvider.todayMenu == null && msg.isEmpty) {
      return TodayMealCardSkeleton(isDark: isDark);
    }

    if (msg.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppleCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(CupertinoIcons.info_circle_fill, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      msg,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.35,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
    }

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
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.1),
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
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
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
        child: ColoredBox(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.surfaceDark
              : AppTheme.primaryColor.withValues(alpha: 0.05),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: double.infinity,
            height: height,
            fit: BoxFit.contain,
            placeholder: (_, __) => _buildMealPlaceholder(height),
            errorWidget: (_, __, ___) => _buildMealPlaceholder(height),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: _buildMealPlaceholder(height),
    );
  }

  Widget _buildMealPlaceholder(double height) {
    return SkeletonBone(
      height: height,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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
                onPressed: () {
                  final entityType = alert['entity_type']?.toString();
                  final entityId = alert['entity_id']?.toString();
                  if (entityType == 'child') {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => ChildrenManagementScreen(renewChildId: entityId),
                      ),
                    );
                  } else if (entityType == 'teacher') {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => const TeacherProfileScreen(renew: true),
                      ),
                    );
                  } else if (entityType == 'professional') {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => const ProfessionalProfileScreen(renew: true),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const SubscriptionManagementScreen()),
                    );
                  }
                },
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
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
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

    final profileProvider = context.watch<ProfileProvider>();
    return Column(
      children: homepageProvider.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildFeatureCard(
            context,
            entry.name,
            _featureSubtitle(entry, profileProvider),
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
    if ((entry.entityName ?? '').trim().toLowerCase() == 'bulk') {
      Navigator.push(context, CupertinoPageRoute(builder: (_) => const BulkOrderHubScreen()));
      return;
    }
    switch (entry.entityId) {
      case 'ENT-1':
        Navigator.push(context, CupertinoPageRoute(builder: (_) => const ChildrenManagementScreen()));
        if (NetworkStatusService.instance.isOnline) context.read<ChildrenProvider>().fetchChildren(silent: true);
        return;
      case 'ENT-2':
        Navigator.push(context, CupertinoPageRoute(builder: (_) => const TeacherProfileScreen()));
        if (NetworkStatusService.instance.isOnline) context.read<ProfileProvider>().fetchProfiles(silent: true);
        return;
      case 'ENT-3':
        Navigator.push(context, CupertinoPageRoute(builder: (_) => const ProfessionalProfileScreen()));
        if (NetworkStatusService.instance.isOnline) context.read<ProfileProvider>().fetchProfiles(silent: true);
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This feature is coming soon.')),
        );
    }
  }

  Future<void> _openSubscribeCartForHomeEntry(BuildContext context, HomepageEntry entry) async {
    await Future.wait([
      context.read<ChildrenProvider>().fetchChildren(silent: true),
      context.read<ProfileProvider>().fetchProfiles(silent: true),
    ]);
    if (!context.mounted) return;
    switch (entry.entityId) {
      case 'ENT-1':
        _navigateToChildrenManage(context);
        return;
      case 'ENT-2':
        _navigateToTeacherProfile(context);
        return;
      case 'ENT-3':
        _navigateToProfessionalProfile(context);
        return;
      default:
        await _openFirstAvailableManageScreen(context);
    }
  }

  String _featureSubtitle(HomepageEntry entry, ProfileProvider profiles) {
    switch (entry.entityId) {
      case 'ENT-2':
        final teacher = profiles.teacherProfile;
        if (teacher != null && (teacher.id ?? '').toString().isNotEmpty) {
          return 'Registered • ${teacher.name}';
        }
        return entry.description;
      case 'ENT-3':
        final pro = profiles.professionalProfile;
        if (pro != null && (pro.id ?? '').toString().isNotEmpty) {
          return 'Registered • ${pro.name}';
        }
        return entry.description;
      default:
        return entry.description;
    }
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
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
              color: color.withValues(alpha: 0.15),
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
          if (trailing != null) trailing,
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
        _buildActivitySummary(
          context,
          isDark,
          childrenCount: childrenCount,
          childrenCountLoading: context.watch<ChildrenProvider>().isLoading,
          hasActive: isActive,
          hasUpcoming: mealProvider.subscriptionStatusData?['has_upcoming_subscription'] == true,
          statusData: mealProvider.subscriptionStatusData,
        ),

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
    required bool childrenCountLoading,
    required bool hasActive,
    required bool hasUpcoming,
    Map<String, dynamic>? statusData,

  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const ChildrenManagementScreen()),
                  );
                  context.read<ChildrenProvider>().fetchChildren(silent: true);
                },
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
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
            Container(width: 1, color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.12)),
            // Right: Plan status pill — compact + tappable
            Expanded(
              child: _buildPlanStatusPill(
                context,
                isDark,
                hasActive: hasActive,
                hasUpcoming: hasUpcoming,
                statusData: statusData,
              ),

            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanStatusPill(
    BuildContext context,
    bool isDark, {
    required bool hasActive,
    required bool hasUpcoming,
    Map<String, dynamic>? statusData,
  }) {
    final Color color;
    final IconData icon;
    final String subtitle;
    final upcomingStart = SubscriptionStatusNormalizer.earliestUpcomingStartYmd(statusData);
    final upcomingLabel = upcomingStart != null ? MealDate.formatDisplay(upcomingStart) : null;
    
    if (hasActive) {
      color = Colors.green;
      icon = CupertinoIcons.checkmark_seal_fill;
      subtitle = 'Active plan';
    } else if (hasUpcoming) {
      color = const Color(0xFFEAB308);
      icon = CupertinoIcons.clock_fill;
      subtitle = upcomingLabel != null ? 'Starts $upcomingLabel' : 'Upcoming plan';
    } else {
      color = Colors.red;
      icon = CupertinoIcons.exclamationmark_circle_fill;
      subtitle = 'No active plan';
    }

    final title = 'My Subscription';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const SubscriptionManagementScreen()),
        );
      },
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
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

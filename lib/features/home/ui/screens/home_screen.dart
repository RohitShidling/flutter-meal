import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/children/ui/screens/children_management_screen.dart';
import 'package:meal_app/features/profile/ui/screens/teacher_profile_screen.dart';
import 'package:meal_app/features/profile/ui/screens/professional_profile_screen.dart';
import 'package:meal_app/features/home/providers/homepage_provider.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/view_all_plans_screen.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_cart_screen.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_hub_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/cart_screen.dart';
import 'package:meal_app/core/widgets/image_preview_dialog.dart';
import 'package:meal_app/features/subscription/ui/screens/subscription_management_screen.dart';
import 'package:meal_app/features/home/ui/widgets/bottom_footer_nav.dart';
import 'package:meal_app/core/navigation/app_routes.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapHome();
      context.read<LookupProvider>().fetchContactUsInfo();
    });
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
        systemNavigationBarColor: AppTheme.backgroundDark,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
      bottomNavigationBar: BuuttiiFooterNav(
        currentIndex: 0,
        onHomeTap: () {},
        onWeekMenuTap: () {
          Navigator.of(context).pushReplacementNamed(AppRoutes.weeklyMenu);
        },
        onMealSkipTap: () {
          Navigator.of(context).pushReplacementNamed(AppRoutes.mealSkip);
        },
        onSettingsTap: () {
          Navigator.of(context).pushReplacementNamed(AppRoutes.settings);
        },
      ),
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
            color: isDark ? AppTheme.backgroundDark : const Color(0xFFFAF8F5),
          ),
          child: SafeArea(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildWelcomeHeader(context, isDark),
                      const SizedBox(height: 12),
                      _buildUpcomingPlanCard(context, isDark),
                      _buildTodayMealCard(context, isDark),
                      _buildAlertsBanner(context, isDark),
                      _buildFeatureQuickLinks(context, isDark),
                      const SizedBox(height: 10),
                      _buildQuickStatus(context),
                      const SizedBox(height: 18),
                      _buildAboutBuuttiiCard(context, isDark),
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

  Widget _buildWelcomeHeader(BuildContext context, bool isDark) {
    final name = _displayName.isNotEmpty ? _displayName.trim() : 'User';
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $name!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF5A4D42),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (context.watch<BulkOrderProvider>().hasBulkCartItems) ...[
                _buildBulkCartActionButton(context),
                const SizedBox(width: 4),
              ],
              if (context.watch<CartProvider>().itemCount > 0) ...[
                _buildCartActionButton(context),
                const SizedBox(width: 4),
              ],
              _buildPlansButton(context),
            ],
          ),
        ],
      ),
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
        onTap: () async {
          try {
            await context.read<SubscriptionProvider>().fetchSubscriptions(silent: true);
            if (!mounted) return;
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const ViewAllPlansScreen()),
            );
          } catch (e) {
            // Silently handle navigation errors
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.14),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.18)),
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

  Widget _buildUpcomingPlanCard(BuildContext context, bool isDark) {
    final statusData = context.watch<MealProvider>().subscriptionStatusData;
    if (statusData == null) return const SizedBox.shrink();

    final list = statusData['entities'] is List
        ? statusData['entities'] as List
        : (statusData['data'] is List ? statusData['data'] as List : const []);

    final today = MealDate.sessionTodayYmd();
    final upcomingRows = list.whereType<Map<String, dynamic>>().where((row) {
      return SubscriptionStatusNormalizer.rowIsUpcoming(row, today);
    }).toList();

    if (upcomingRows.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort upcoming rows by start date so the earliest shows first
    upcomingRows.sort((a, b) {
      final aStart = a['start_date']?.toString() ?? '';
      final bStart = b['start_date']?.toString() ?? '';
      return aStart.compareTo(bStart);
    });

    final widgets = <Widget>[];
    for (final row in upcomingRows) {
      final startYmd = row['start_date']?.toString();
      if (startYmd == null) continue;

      final formattedDate = MealDate.formatDisplay(startYmd);

      // Determine name
      String name = '';
      final rawName = row['entity_name'] ?? row['name'] ?? row['child_name'];
      if (rawName != null && rawName.toString().trim().isNotEmpty) {
        name = rawName.toString().trim();
      } else {
        final entityType = row['entity_type']?.toString();
        final entityId = row['entity_id']?.toString();
        if (entityType == 'child' && entityId != null) {
          final child = context.read<ChildrenProvider>().children.where((c) => c.id?.toString() == entityId).firstOrNull;
          if (child != null) name = child.name;
        } else if (entityType == 'teacher') {
          final tp = context.read<ProfileProvider>().teacherProfile;
          if (tp != null) name = tp.name;
        } else if (entityType == 'professional') {
          final pp = context.read<ProfileProvider>().professionalProfile;
          if (pp != null) name = pp.name;
        }
      }

      if (name.isEmpty) {
        name = 'Profile';
      }

      final message = "$name will start receiving meals from $formattedDate";

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFFFF4EC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.calendar_today, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF5A4D42),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildTodayMealCard(BuildContext context, bool isDark) {
    final menuProvider = context.watch<MenuProvider>();
    final msg = menuProvider.homeMealMessage?.trim() ?? '';
    if (menuProvider.isLoading && menuProvider.todayMenu == null && msg.isEmpty) {
      return TodayMealCardSkeleton(isDark: isDark);
    }

    if (msg.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
          ),
          child: Row(
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
        ),
      );
    }

    if (menuProvider.todayMenu == null) return const SizedBox.shrink();

    final menu = menuProvider.todayMenu!;
    final imageUrl = menu['image_url']?.toString();
    final items = menu['items']?.toString() ?? menu['item_name']?.toString() ?? 'Today\'s Meal';
    final nutritionPoints = (menu['nutrition_points'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Meal",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF5A4D42),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (imageUrl != null && imageUrl.isNotEmpty) {
                          ImagePreviewDialog.show(context, imageUrl, title: items);
                        }
                      },
                      child: _buildMealImage(imageUrl, 180),
                    ),
                    if (nutritionPoints.isNotEmpty)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Wrap(
                          spacing: 6,
                          children: nutritionPoints.take(3).map((point) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                point,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Freshly prepared daily for our subscribers',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealImage(String? imageUrl, double height) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ColoredBox(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.surfaceDark
              : const Color(0xFFF7F2EA),
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: _buildMealPlaceholder(height),
    );
  }

  Widget _buildMealPlaceholder(double height) {
    return SkeletonBone(
      height: height,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            color: isDark ? const Color(0xFF2E2008) : const Color(0xFFFFF5E6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF5C4010) : const Color(0xFFFFDFA6)),
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

  Widget _buildFeatureQuickLinks(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore Plans',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF5A4D42),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildQuickLinkCard(
                      context: context,
                      title: 'Manage Child',
                      icon: CupertinoIcons.person_3_fill,
                      bgColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                      iconColor: const Color(0xFF3B82F6),
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(context, CupertinoPageRoute(builder: (_) => const ChildrenManagementScreen()));
                        if (NetworkStatusService.instance.isOnline) context.read<ChildrenProvider>().fetchChildren(silent: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickLinkCard(
                      context: context,
                      title: 'Teacher Plan',
                      icon: CupertinoIcons.book_fill,
                      bgColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
                      iconColor: const Color(0xFFD97706),
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(context, CupertinoPageRoute(builder: (_) => const TeacherProfileScreen()));
                        if (NetworkStatusService.instance.isOnline) context.read<ProfileProvider>().fetchProfiles(silent: true);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickLinkCard(
                      context: context,
                      title: 'Professional Plan',
                      icon: CupertinoIcons.briefcase_fill,
                      bgColor: isDark ? const Color(0xFF4C1D95) : const Color(0xFFE9D5FF),
                      iconColor: const Color(0xFF8B5CF6),
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(context, CupertinoPageRoute(builder: (_) => const ProfessionalProfileScreen()));
                        if (NetworkStatusService.instance.isOnline) context.read<ProfileProvider>().fetchProfiles(silent: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickLinkCard(
                      context: context,
                      title: 'Bulk Order',
                      icon: CupertinoIcons.square_stack_3d_up_fill,
                      bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                      iconColor: const Color(0xFF10B981),
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(context, CupertinoPageRoute(builder: (_) => const BulkOrderHubScreen()));
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinkCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _buildAboutBuuttiiCard(BuildContext context, bool isDark) {
    final provider = context.watch<LookupProvider>();
    final contactInfo = provider.contactUsInfo;
    final aboutTitle = contactInfo == null ? null : contactInfo.aboutTitle!.trim();
    final aboutDescription = contactInfo == null ? null : contactInfo.aboutDescription!.trim();
    final title = aboutTitle != null && aboutTitle.isNotEmpty ? aboutTitle : 'About Us';
    final description = aboutDescription != null && aboutDescription.isNotEmpty
        ? aboutDescription
        : "We're committed to healthy, joyful eating for all.";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.heart_fill,
                color: AppTheme.primaryColor,
                size: 36,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF5A4D42),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? Colors.white70 : const Color(0xFF8B7A66),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                                  color: isDark ? Colors.white : AppTheme.textPrimaryLight),
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
            Container(width: 1, color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.12)),
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

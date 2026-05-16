import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/home/providers/homepage_provider.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';

/// Refreshes only the APIs relevant to the screen the user is currently viewing.
class ReconnectRefreshCoordinator extends StatefulWidget {
  final Widget child;

  const ReconnectRefreshCoordinator({super.key, required this.child});

  @override
  State<ReconnectRefreshCoordinator> createState() => _ReconnectRefreshCoordinatorState();
}

class _ReconnectRefreshCoordinatorState extends State<ReconnectRefreshCoordinator> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    NetworkStatusService.instance.addBecameOnlineListener(_onBecameOnline);
  }

  @override
  void dispose() {
    NetworkStatusService.instance.removeBecameOnlineListener(_onBecameOnline);
    super.dispose();
  }

  void _onBecameOnline() {
    if (!mounted || _refreshing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshForCurrentScreen());
  }

  Future<void> _refreshForCurrentScreen() async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    try {
      await NetworkStatusService.instance.refreshNow();
      if (!mounted) return;
      if (!NetworkStatusService.instance.isBackendReachable) return;

      await context.read<CartProvider>().syncOfflineItemsIfAny();

      final screen = AppRouteTracker.instance.current;
      final meal = context.read<MealProvider>();
      final menu = context.read<MenuProvider>();

      switch (screen) {
        case AppScreen.home:
          await context.read<AuthProvider>().refreshMeProfile(silent: true);
          await meal.fetchSubscriptionStatus(silent: true);
          await Future.wait([
            context.read<HomepageProvider>().fetchHomepageEntries(force: true, silent: true),
            context.read<CartProvider>().fetchCart(force: true, silent: true),
            context.read<ChildrenProvider>().fetchChildren(force: true),
            meal.fetchMealStatus(),
            meal.fetchAlerts(),
          ]);
          if (meal.isSubscribed) {
            await menu.fetchTodayMenu(silent: true);
          }
          break;

        case AppScreen.subscriptionManagement:
          await meal.fetchSubscriptionStatus(silent: true);
          await Future.wait([
            context.read<PaymentProvider>().fetchActiveSubscriptions(),
            context.read<PaymentProvider>().fetchPaymentHistory(),
            context.read<ChildrenProvider>().fetchChildren(force: true),
            context.read<ProfileProvider>().fetchProfiles(force: true),
          ]);
          break;

        case AppScreen.cart:
          await context.read<CartProvider>().fetchCart(force: true);
          await meal.fetchSubscriptionStatus(silent: true);
          break;

        case AppScreen.children:
          await Future.wait([
            context.read<ChildrenProvider>().fetchChildren(force: true),
            context.read<LookupProvider>().fetchInitialData(force: true),
            meal.fetchSubscriptionStatus(silent: true),
          ]);
          break;

        case AppScreen.teacherProfile:
        case AppScreen.professionalProfile:
          await Future.wait([
            context.read<ProfileProvider>().fetchProfiles(force: true),
            context.read<LookupProvider>().fetchInitialData(force: true),
            meal.fetchSubscriptionStatus(silent: true),
            context.read<CartProvider>().fetchCart(force: true, silent: true),
          ]);
          break;

        case AppScreen.mealSkip:
          await Future.wait([
            meal.fetchSubscriptionStatus(silent: true),
            meal.fetchSkips(),
            meal.fetchMealStatus(),
          ]);
          break;

        case AppScreen.weeklyMenu:
          await meal.fetchSubscriptionStatus(silent: true);
          await menu.fetchWeeklyMenu();
          break;

        case AppScreen.settings:
        case AppScreen.other:
          await meal.fetchSubscriptionStatus(silent: true);
          break;
      }
    } catch (_) {
      // Best-effort per-screen refresh.
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

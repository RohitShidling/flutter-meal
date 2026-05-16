import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/home/providers/homepage_provider.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/core/services/network_status_service.dart';

/// Warms all major providers from network (and persists cache) after login / cold start.
class OfflineCacheBootstrap {
  OfflineCacheBootstrap._();

  static bool _ranThisSession = false;

  static Future<void> warmIfNeeded(BuildContext context) async {
    if (_ranThisSession) return;
    if (!NetworkStatusService.instance.canAttemptApi) return;

    _ranThisSession = true;
    try {
      final meal = context.read<MealProvider>();
      final menu = context.read<MenuProvider>();

      await context.read<AuthProvider>().refreshMeProfile(silent: true);

      await Future.wait([
        context.read<LookupProvider>().fetchInitialData(force: true),
        meal.fetchSubscriptionStatus(silent: true),
        context.read<PaymentProvider>().fetchPaymentHistory(),
        context.read<PaymentProvider>().fetchActiveSubscriptions(),
        context.read<CartProvider>().fetchCart(silent: true),
        context.read<ChildrenProvider>().fetchChildren(silent: true),
        context.read<ProfileProvider>().fetchProfiles(force: true, silent: true),
        context.read<SubscriptionProvider>().fetchSubscriptions(force: true),
        context.read<HomepageProvider>().fetchHomepageEntries(force: true, silent: true),
        meal.fetchMealStatus(),
        meal.fetchAlerts(),
        meal.fetchSkips(),
      ]);

      if (meal.isSubscribed) {
        await menu.fetchTodayMenu(silent: true);
        await menu.fetchWeeklyMenu();
      }
    } catch (_) {
      _ranThisSession = false;
    }
  }

  static void resetSession() {
    _ranThisSession = false;
  }
}

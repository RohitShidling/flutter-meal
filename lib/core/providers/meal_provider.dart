import 'package:flutter/material.dart';
import 'package:meal_app/core/network/meal_repository.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/core/storage/local_cache.dart';
import 'package:meal_app/core/utils/error_handler.dart';

/// Centralized provider for meals, skips, subscription alerts,
/// and remaining-meal status tracking.
class MealProvider with ChangeNotifier {
  final MealRepository _repository;
  final LocalCache _cache;
  static const _statusCacheKey = 'cache_subscription_status_v1';
  static const _mealStatusCacheKey = 'cache_meal_status_v1';
  static const _skipHistoryCacheKey = 'cache_meal_skips_v1';

  MealProvider(this._repository, this._cache) {
    _loadCachedData();
  }

  // ─── State ────────────────────────────────────────────────────────────────

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  // Today's menu
  Map<String, dynamic>? _todayMenu;
  Map<String, dynamic>? get todayMenu => _todayMenu;

  // Weekly menu
  List<dynamic> _weeklyMenu = [];
  List<dynamic> get weeklyMenu => _weeklyMenu;

  // Subscription summaries from meal APIs
  List<dynamic> _subscriptionSummary = [];
  List<dynamic> get subscriptionSummary => _subscriptionSummary;

  // Meal remaining status (per entity)
  List<dynamic> _mealStatus = [];
  List<dynamic> get mealStatus => _mealStatus;

  // Meal skips
  List<dynamic> _skips = [];
  List<dynamic> get skips => _skips;
  Map<String, dynamic> _skipPolicy = const {'min_skip_days': 3, 'min_notice_days': 1};
  Map<String, dynamic> get skipPolicy => _skipPolicy;

  // Subscription alerts (expiry warnings)
  List<dynamic> _alerts = [];
  List<dynamic> get alerts => _alerts;

  // Full subscription status
  Map<String, dynamic>? _subscriptionStatusData;
  Map<String, dynamic>? get subscriptionStatusData => _subscriptionStatusData;

  bool _hasInitiallyLoaded = false;
  bool get hasInitiallyLoaded => _hasInitiallyLoaded;

  Future<void> _loadCachedData() async {
    try {
      final alertsCache = await CacheStore.getJson('meal_alerts');
      if (alertsCache is List) {
        _alerts = alertsCache;
      }
      final statusCache = await CacheStore.getJson('meal_status');
      if (statusCache is List) {
        _mealStatus = statusCache;
      }
      final subStatusCache = await CacheStore.getJson('subscription_status');
      if (subStatusCache is Map<String, dynamic>) {
        _subscriptionStatusData = subStatusCache;
        _syncSubscribedFromStatusMap(subStatusCache);
      }
      _hasInitiallyLoaded = true;
      notifyListeners();
    } catch (_) {
      // ignore cache errors
    }
  }

  void _syncSubscribedFromStatusMap(Map<String, dynamic> raw) {
    _isSubscribed = false;
    final direct = raw['has_active_subscription'];
    if (direct == true) {
      _isSubscribed = true;
      return;
    }
    final nested = raw['data'];
    if (nested is Map && nested['has_active_subscription'] == true) {
      _isSubscribed = true;
      return;
    }
    if (nested is List && nested.isNotEmpty) {
      for (final row in nested) {
        if (row is Map && row['subscription_status'] == true) {
          _isSubscribed = true;
          return;
        }
      }
    }
  }

  // ─── Today's Menu ─────────────────────────────────────────────────────────

  Future<void> fetchTodayMenu({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final data = await _repository.fetchTodayMenu();
      _isSubscribed = data['is_subscribed'] ?? false;
      if (_isSubscribed) {
        _todayMenu = data['menu'];
        _subscriptionSummary = data['subscription_summary'] ?? [];
      } else {
        _todayMenu = null;
      }
    } catch (e) {
      if (e.toString().contains('403')) {
        _isSubscribed = false;
        _todayMenu = null;
      } else if (!silent || (_todayMenu == null)) {
        _error = ErrorHandler.getErrorMessage(e);
      }
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ─── Weekly Menu ──────────────────────────────────────────────────────────

  Future<void> fetchWeeklyMenu({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final data = await _repository.fetchWeeklyMenu();
      _isSubscribed = data['is_subscribed'] ?? false;
      if (_isSubscribed) {
        _weeklyMenu = data['menu'] ?? [];
        _subscriptionSummary = data['subscription_summary'] ?? [];
      }
    } catch (e) {
      if (e.toString().contains('403')) {
        _isSubscribed = false;
      } else if (!silent || _weeklyMenu.isEmpty) {
        _error = ErrorHandler.getErrorMessage(e);
      }
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ─── Meal Remaining Status ────────────────────────────────────────────────

  Future<void> fetchMealStatus({bool silent = false}) async {
    if (!silent) {
      if (_mealStatus.isEmpty) {
        _isLoading = true;
        notifyListeners();
      }
    }
    try {
      _mealStatus = await _repository.fetchMealStatus();
      await CacheStore.setJson('meal_status', _mealStatus, ttl: const Duration(hours: 6));
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  // ─── Skip Management ─────────────────────────────────────────────────────

  Future<bool> skipMeal({
    required String entityType,
    required String entityId,
    required String startDate,
    required String endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.skipMeal(
        entityType: entityType,
        entityId: entityId,
        startDate: startDate,
        endDate: endDate,
      );
      await fetchSkips(); // refresh list
      return true;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSkips() async {
    final cached = await _cache.loadJson(_skipHistoryCacheKey);
    if (cached != null && _skips.isEmpty) {
      _skips = (cached['items'] as List? ?? const []).toList();
      notifyListeners();
    }
    try {
      _skips = await _repository.fetchMealSkips();
      await _cache.saveJson(_skipHistoryCacheKey, {'items': _skips});
      notifyListeners();
    } catch (e) {
      // If cached skips are present, keep showing them offline without erroring out.
      _error = _skips.isNotEmpty ? null : ErrorHandler.getErrorMessage(e);
    }
  }

  Future<void> fetchSkipPolicy() async {
    try {
      final data = await _repository.fetchMealSkipPolicy();
      if (data.isNotEmpty) {
        _skipPolicy = data;
        notifyListeners();
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    }
  }

  Future<bool> cancelSkip(int skipId) async {
    try {
      final success = await _repository.cancelSkip(skipId);
      if (success) await fetchSkips();
      return success;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return false;
    }
  }

  Future<bool> deleteSkip(int skipId) async {
    try {
      final success = await _repository.deleteSkip(skipId);
      if (success) await fetchSkips();
      return success;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return false;
    }
  }

  // ─── Subscription Status & Alerts ────────────────────────────────────────

  Future<void> fetchSubscriptionStatus({bool silent = false}) async {
    if (!silent && _subscriptionStatusData == null) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _subscriptionStatusData = await _repository.fetchSubscriptionStatus();
      final statusMap = _subscriptionStatusData;
      if (statusMap is Map<String, dynamic>) {
        _syncSubscribedFromStatusMap(statusMap);
      }
      await CacheStore.setJson('subscription_status', _subscriptionStatusData, ttl: const Duration(hours: 6));
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> fetchAlerts({bool silent = false}) async {
    try {
      _alerts = await _repository.fetchSubscriptionAlerts();
      await CacheStore.setJson('meal_alerts', _alerts, ttl: const Duration(hours: 6));
      notifyListeners();
    } catch (e) {
      // Silently fail — alerts are non-critical
    }
  }

  // ─── Update Start Date ───────────────────────────────────────────────────

  Future<bool> updateStartDate({
    required String entityType,
    required String entityId,
    required String startDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.updateStartDate(
        entityType: entityType,
        entityId: entityId,
        startDate: startDate,
      );
      return true;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

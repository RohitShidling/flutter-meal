import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/core/storage/local_cache.dart';
import 'package:meal_app/core/utils/error_handler.dart';

class MenuProvider with ChangeNotifier {
  final DioClient _dioClient;
  final LocalCache _cache;
  static const _todayCacheKey = 'cache_today_menu_v1';
  static const _weeklyCacheKey = 'cache_weekly_menu_v1';

  MenuProvider(this._dioClient, this._cache) {
    _loadCachedTodayMenu();
  }

  String? _homeMealMessage;
  String? get homeMealMessage => _homeMealMessage;

  String _displayMode = 'menu';
  String get displayMode => _displayMode;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  Map<String, dynamic>? _todayMenu;
  Map<String, dynamic>? get todayMenu => _todayMenu;

  List<dynamic> _weeklyMenu = [];
  List<dynamic> get weeklyMenu => _weeklyMenu;

  List<dynamic> _subscriptionSummary = [];
  List<dynamic> get subscriptionSummary => _subscriptionSummary;

  String? _error;
  String? get error => _error;

  bool _hasInitiallyLoaded = false;
  bool get hasInitiallyLoaded => _hasInitiallyLoaded;

  String _normalizeDateKey(dynamic raw) {
    final value = raw?.toString() ?? '';
    if (value.isEmpty) return '';
    return value.contains('T') ? value.split('T').first : value;
  }

  List<String> _extractNutrition(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return [];
  }

  Future<void> _prefetchWeeklyMenuImages(List<dynamic> menus) async {
    final manager = DefaultCacheManager();
    for (final entry in menus) {
      if (entry is! Map) continue;
      final url = entry['image_url']?.toString();
      if (url == null || url.isEmpty) continue;
      try {
        await manager.downloadFile(url);
      } catch (_) {}
    }
  }

  Future<void> _loadCachedTodayMenu() async {
    try {
      final cached = await CacheStore.getJson('today_menu');
      if (cached is Map<String, dynamic>) {
        _isSubscribed = cached['is_subscribed'] ?? false;
        _homeMealMessage = cached['home_meal_message']?.toString();
        _displayMode = cached['display_mode']?.toString() ?? 'menu';
        if (_isSubscribed) {
          _todayMenu = cached['menu'] != null ? Map<String, dynamic>.from(cached['menu']) : null;
          _subscriptionSummary = cached['subscription_summary'] ?? [];
        }
        _hasInitiallyLoaded = true;
        notifyListeners();
      }
    } catch (_) {
      // ignore
    }
  }

  /// When [onlyIfSubscribed] is true, skips the network call if the user is not subscribed
  /// (uses [mealIsSubscribed] from [MealProvider] after `fetchSubscriptionStatus`).
  Future<void> fetchTodayMenu({
    bool silent = false,
    bool onlyIfSubscribed = false,
    bool mealIsSubscribed = false,
  }) async {
    if (onlyIfSubscribed && !mealIsSubscribed) {
      _isSubscribed = false;
      _todayMenu = null;
      _homeMealMessage = null;
      _displayMode = 'menu';
      _subscriptionSummary = [];
      _hasInitiallyLoaded = true;
      await CacheStore.remove('today_menu');
      if (!silent) {
        _isLoading = false;
        _error = null;
      }
      notifyListeners();
      return;
    }

    if (!silent) {
      if (_todayMenu == null) _isLoading = true;
      _error = null;
      notifyListeners();
    } else if (_isSubscribed && _todayMenu == null) {
      // Silent refresh (e.g. pull-to-refresh) while subscribed but menu not yet loaded — drive skeletons on home.
      _isLoading = true;
      notifyListeners();
    }

    try {
      final mealResponse = await _dioClient.dio.get('/api/client/meals/today');
      final data = mealResponse.data;
      _isSubscribed = data['is_subscribed'] ?? false;
      _homeMealMessage = data['home_meal_message']?.toString();
      _displayMode = data['display_mode']?.toString() ?? 'menu';
      if ((_homeMealMessage ?? '').trim().isEmpty && data['menu'] == null) {
        _homeMealMessage = data['message']?.toString();
      }
      if (_isSubscribed) {
        final showMenuCard = _displayMode == 'menu';
        if (showMenuCard && data['menu'] is Map<String, dynamic>) {
          final menu = Map<String, dynamic>.from(data['menu']);
          List<String> nutritionPoints = [];
          try {
            final nutritionResponse = await _dioClient.dio.get(ApiEndpoints.clientMenuNutritionToday);
            final nutritionData = nutritionResponse.data;
            nutritionPoints = _extractNutrition(nutritionData['data']?['nutrition_points']);
          } catch (_) {
            // Keep menu working even if nutrition endpoint fails temporarily.
          }
          menu['nutrition_points'] = nutritionPoints;
          _todayMenu = menu;
        } else {
          _todayMenu = null;
        }
        _subscriptionSummary = data['subscription_summary'] ?? [];
        await _cache.saveJson(_todayCacheKey, {
          'is_subscribed': _isSubscribed,
          'menu': _todayMenu,
          'subscription_summary': _subscriptionSummary,
          'home_meal_message': _homeMealMessage,
          'display_mode': _displayMode,
        });
      } else {
        _todayMenu = null;
        _homeMealMessage = null;
        _displayMode = 'menu';
        _subscriptionSummary = [];
      }
      // Cache the response structure
      await CacheStore.setJson('today_menu', {
        'is_subscribed': _isSubscribed,
        'menu': _todayMenu,
        'subscription_summary': _subscriptionSummary,
        'home_meal_message': _homeMealMessage,
        'display_mode': _displayMode,
      }, ttl: const Duration(hours: 6));
      _hasInitiallyLoaded = true;
    } catch (e) {
      if (e.toString().contains('403')) {
        _isSubscribed = false;
        _todayMenu = null;
        _homeMealMessage = null;
        _displayMode = 'menu';
        _subscriptionSummary = [];
        await CacheStore.remove('today_menu');
      } else {
        _error = ErrorHandler.getErrorMessage(e);
        // Keep cached data on network error
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchWeeklyMenu() async {
    final cached = await _cache.loadJson(_weeklyCacheKey);
    if (cached != null && _weeklyMenu.isEmpty) {
      _isSubscribed = cached['is_subscribed'] == true;
      _weeklyMenu = (cached['menu'] as List? ?? const []).toList();
      _subscriptionSummary = (cached['subscription_summary'] as List? ?? const []).toList();
      notifyListeners();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final mealResponse = await _dioClient.dio.get('/api/client/meals/weekly');
      final data = mealResponse.data;
      _isSubscribed = data['is_subscribed'] ?? false;
      if (_isSubscribed) {
        final weeklyMenus = (data['menu'] as List?) ?? [];
        final nutritionByDate = <String, List<String>>{};
        try {
          final nutritionResponse = await _dioClient.dio.get(ApiEndpoints.clientMenuNutritionWeekly);
          final nutritionData = nutritionResponse.data;
          final nutritionRows = (nutritionData['data'] as List?) ?? [];
          for (final row in nutritionRows) {
            if (row is Map<String, dynamic>) {
              final menuDate = _normalizeDateKey(row['menu_date']);
              if (menuDate.isNotEmpty) {
                nutritionByDate[menuDate] = _extractNutrition(row['nutrition_points']);
              }
            }
          }
        } catch (_) {
          // Keep weekly menu working even if nutrition endpoint fails temporarily.
        }

        _weeklyMenu = weeklyMenus.map((entry) {
          if (entry is Map<String, dynamic>) {
            final menu = Map<String, dynamic>.from(entry);
            final menuDate = _normalizeDateKey(menu['menu_date']);
            menu['nutrition_points'] = nutritionByDate[menuDate] ?? <String>[];
            return menu;
          }
          return entry;
        }).toList();
        _subscriptionSummary = data['subscription_summary'] ?? [];
        await _cache.saveJson(_weeklyCacheKey, {
          'is_subscribed': _isSubscribed,
          'menu': _weeklyMenu,
          'subscription_summary': _subscriptionSummary,
        });
        // Warm disk cache so weekly images still appear offline later.
        await _prefetchWeeklyMenuImages(_weeklyMenu);
      } else {
        _weeklyMenu = [];
      }
    } catch (e) {
      if (e.toString().contains('403')) {
        _isSubscribed = false;
        _weeklyMenu = [];
      } else {
        // Keep showing cached weekly menu when offline / flaky network.
        _error = _weeklyMenu.isEmpty ? ErrorHandler.getErrorMessage(e) : null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

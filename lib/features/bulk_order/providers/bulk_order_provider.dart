import 'package:flutter/material.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/services/phonepe_service.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_delivery_address.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_variety_category.dart';
import 'package:meal_app/features/bulk_order/data/repositories/bulk_order_repository.dart';

class BulkOrderProvider with ChangeNotifier {
  final BulkOrderRepository _repository;

  BulkOrderProvider(this._repository);

  bool _loading = false;
  bool get isLoading => _loading;

  String? _error;
  String? get error => _error;

  BulkOrderConfig? _config;
  BulkOrderConfig? get config => _config;

  BulkMenuOption? _deliveryMenu;
  BulkMenuOption? get deliveryMenu => _deliveryMenu;

  List<BulkMenuOption> _varietyMenus = [];
  List<BulkMenuOption> get varietyMenus => _varietyMenus;

  List<BulkVarietyCategory> _varietyCategories = [];
  List<BulkVarietyCategory> get varietyCategories => _varietyCategories;

  List<BulkMenuOption> _categoryMeals = [];
  List<BulkMenuOption> get categoryMeals => _categoryMeals;

  final Map<String, int> _varietyQty = {};
  final Map<String, BulkMenuOption> _varietyMealCatalog = {};
  BulkDeliveryAddress? _deliveryAddress;
  BulkDeliveryAddress? get deliveryAddress => _deliveryAddress;
  Map<String, int> get varietyQty => Map.unmodifiable(_varietyQty);

  int get varietyLineSum => _varietyQty.values.fold(0, (a, b) => a + b);

  Map<String, dynamic>? _lastQuote;
  Map<String, dynamic>? get lastQuote => _lastQuote;

  Future<void> loadConfig() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _config = await _repository.fetchConfig();
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearVarietyCart() {
    _varietyQty.clear();
    _varietyMealCatalog.clear();
    notifyListeners();
  }

  void setDeliveryAddress(BulkDeliveryAddress? address) {
    _deliveryAddress = address;
    notifyListeners();
  }

  String? validateDeliveryAddress() {
    final a = _deliveryAddress;
    if (a == null || !a.isComplete) {
      return 'Select state, city, and enter delivery address (min 5 characters).';
    }
    final pin = a.pincode?.trim() ?? '';
    if (pin.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(pin)) {
      return 'Pincode must be 6 digits.';
    }
    return null;
  }

  BulkMenuOption? mealById(String id) => _varietyMealCatalog[id];

  int get varietyMealTypeCount =>
      _varietyQty.entries.where((e) => e.value > 0).length;

  static const int varietyCartMaxTotal = 5000;

  int _mealMin(String mealId) {
    final min = mealById(mealId)?.minOrderQuantity ?? 1;
    return min < 1 ? 1 : min;
  }

  /// Per-line rules only (not the order-wide tier minimum). Use when adding/updating cart lines.
  String? validateVarietyLineUpdate(BulkOrderConfig cfg, String mealId, int qty) {
    if (qty < 0) return 'Invalid quantity.';
    if (qty == 0) return null;

    if (!cfg.allowMultipleVarietyMeals) {
      if (qty < cfg.tierThreshold) {
        return 'This meal needs at least ${cfg.tierThreshold} portions.';
      }
      return null;
    }

    final wasInCart = varietyQtyFor(mealId) > 0;
    if (!wasInCart && varietyMealTypeCount >= cfg.maxVarietyTypes) {
      return 'You can pick at most ${cfg.maxVarietyTypes} different meal types.';
    }

    final simulated = Map<String, int>.from(_varietyQty);
    if (qty <= 0) {
      simulated.remove(mealId);
    } else {
      simulated[mealId] = qty;
    }
    final active = simulated.entries.where((e) => e.value > 0).toList();
    final typeCount = active.length;

    if (typeCount > cfg.maxVarietyTypes) {
      return 'You can pick at most ${cfg.maxVarietyTypes} different meal types.';
    }

    if (typeCount > 1) {
      var minSum = 0;
      for (final e in active) {
        final meal = mealById(e.key);
        if (meal == null) {
          return 'Re-open this category to refresh meal details, then try again.';
        }
        final min = _mealMin(e.key);
        minSum += min;
        if (e.value < min) {
          return '${meal.items} needs at least $min portions when you order multiple meal types.';
        }
      }
      final sum = active.fold<int>(0, (s, e) => s + e.value);
      if (minSum > sum) {
        return 'Combined minimum for these meals is $minSum portions (you have $sum).';
      }
    }
    return null;
  }

  /// Full cart validation including order minimum (${cfg.tierThreshold}+ total).
  String? validateVarietyCartForCheckout(BulkOrderConfig cfg) {
    final lineSum = varietyLineSum;
    if (lineSum == 0) return 'Add at least one meal from the categories below.';
    if (lineSum < cfg.tierThreshold) {
      return 'Order at least ${cfg.tierThreshold} meals in total (you have $lineSum).';
    }
    if (lineSum > varietyCartMaxTotal) {
      return 'Total cannot exceed $varietyCartMaxTotal meals.';
    }

    final typeCount = varietyMealTypeCount;
    if (!cfg.allowMultipleVarietyMeals) {
      if (typeCount != 1) return 'Select exactly one meal type for this order.';
      return validateVarietyLineUpdate(cfg, _varietyQty.keys.first, varietyQtyFor(_varietyQty.keys.first));
    }
    if (typeCount > cfg.maxVarietyTypes) {
      return 'You can select at most ${cfg.maxVarietyTypes} different meal types.';
    }
    if (typeCount > 1) {
      for (final e in _varietyQty.entries.where((e) => e.value > 0)) {
        final err = validateVarietyLineUpdate(cfg, e.key, e.value);
        if (err != null) return err;
      }
    }
    return null;
  }

  /// @deprecated Use [validateVarietyCartForCheckout].
  String? validateVarietyCart(BulkOrderConfig cfg) => validateVarietyCartForCheckout(cfg);

  bool varietyCartCanCheckout(BulkOrderConfig cfg) =>
      validateVarietyCartForCheckout(cfg) == null;

  /// Footer copy while browsing (does not block adding lines below tier total).
  String varietyCartStatusMessage(BulkOrderConfig cfg) {
    final sum = varietyLineSum;
    if (sum == 0) return 'Cart is empty — pick a category to add meals';
    final checkoutErr = validateVarietyCartForCheckout(cfg);
    if (checkoutErr == null) return '$sum meals in cart — ready to pay';
    if (sum < cfg.tierThreshold) {
      return '$sum in cart · need ${cfg.tierThreshold - sum} more meals (min ${cfg.tierThreshold} total)';
    }
    return checkoutErr;
  }

  List<MapEntry<String, int>> get varietyCartLines =>
      _varietyQty.entries.where((e) => e.value > 0).toList();

  void setVarietyQty(String mealId, int qty) {
    if (qty <= 0) {
      _varietyQty.remove(mealId);
    } else {
      _varietyQty[mealId] = qty;
    }
    notifyListeners();
  }

  int varietyQtyFor(String mealId) => _varietyQty[mealId] ?? 0;

  Future<void> loadVarietyCategories() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _varietyCategories = await _repository.fetchVarietyCategories();
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMealsForCategory(String categoryId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _categoryMeals = await _repository.fetchMealsByCategory(categoryId);
      for (final m in _categoryMeals) {
        _varietyMealCatalog[m.id] = m;
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMenusForDate(String deliveryDate) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _repository.fetchMenusForDelivery(deliveryDate);
      final dm = data['delivery_menu'];
      _deliveryMenu = dm != null
          ? BulkMenuOption.fromJson(Map<String, dynamic>.from(dm as Map))
          : null;
      final list = data['variety_categories'] ?? data['variety_menus'];
      if (list is List && list.isNotEmpty && list.first is Map) {
        final first = list.first as Map;
        if (first.containsKey('meal_count')) {
          _varietyCategories = list
              .map((e) => BulkVarietyCategory.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        } else {
          _varietyMenus = list
              .map((e) => BulkMenuOption.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } else {
        _varietyMenus = [];
      }
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchQuote({
    required String deliveryDate,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _lastQuote = await _repository.quote(
        deliveryDate: deliveryDate,
        items: items,
        deliveryAddress: deliveryAddress,
      );
      return _lastQuote;
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> checkout({
    required String deliveryDate,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryAddress,
    bool isSandbox = true,
  }) async {
    if (!NetworkStatusService.instance.canAttemptApi) {
      _error = 'No internet connection. Connect to complete payment.';
      notifyListeners();
      return null;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final paymentData = await _repository.initiatePayment(
        deliveryDate: deliveryDate,
        items: items,
        deliveryAddress: deliveryAddress,
        redirectUrl: ApiEndpoints.paymentStatusPage,
      );
      final paymentUrl = paymentData['paymentUrl']?.toString();
      final orderId = paymentData['orderId']?.toString() ?? '';
      final merchantTransactionId = paymentData['merchantTransactionId']?.toString() ?? '';
      final backendToken = paymentData['token']?.toString() ?? paymentData['orderToken']?.toString();
      final backendMerchantId = paymentData['merchantId']?.toString();

      if ((paymentUrl == null || paymentUrl.isEmpty) && backendToken == null) {
        throw Exception('Payment information not received from gateway');
      }

      final sdkResult = await PhonePeService.pay(
        orderId: orderId,
        paymentUrl: paymentUrl,
        backendToken: backendToken,
        backendMerchantId: backendMerchantId,
        isSandbox: isSandbox,
      );

      return {
        ...paymentData,
        'sdkStatus': sdkResult['status'] ?? 'FAILURE',
        'sdkError': sdkResult['error'],
        'merchantTransactionId': merchantTransactionId,
      };
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

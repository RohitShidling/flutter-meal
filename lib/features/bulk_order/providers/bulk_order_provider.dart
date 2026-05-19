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

  /// Returns null when the variety cart can proceed to quote/pay.
  String? validateVarietyCart(BulkOrderConfig cfg) {
    final lineSum = varietyLineSum;
    if (lineSum == 0) return 'Add portions for at least one meal.';
    if (lineSum < cfg.tierThreshold) {
      return 'Minimum order for large bulk is ${cfg.tierThreshold} meals (you have $lineSum).';
    }
    if (lineSum > varietyCartMaxTotal) {
      return 'Total cannot exceed $varietyCartMaxTotal meals.';
    }

    final typeCount = varietyMealTypeCount;
    if (!cfg.allowMultipleVarietyMeals) {
      if (typeCount != 1) return 'Select exactly one meal type for this order.';
      return null;
    }
    if (typeCount > cfg.maxVarietyTypes) {
      return 'You can select at most ${cfg.maxVarietyTypes} different meal types.';
    }
    if (typeCount > 1) {
      var minSum = 0;
      for (final e in _varietyQty.entries.where((e) => e.value > 0)) {
        final meal = mealById(e.key);
        if (meal == null) {
          return 'Some selected meals need to be refreshed. Re-open each category, then try again.';
        }
        final min = meal.minOrderQuantity < 1 ? 1 : meal.minOrderQuantity;
        minSum += min;
        if (e.value < min) {
          return '${meal.items} needs at least $min portions when ordering multiple meals.';
        }
      }
      if (minSum > lineSum) {
        return 'Your meal minimums require at least $minSum portions total for the types selected.';
      }
    }
    return null;
  }

  bool varietyCartCanPay(BulkOrderConfig cfg) => validateVarietyCart(cfg) == null;

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

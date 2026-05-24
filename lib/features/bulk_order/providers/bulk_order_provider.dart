import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/services/phonepe_service.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/bulk_order/core/bulk_address_storage.dart';
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
  final Map<String, String> _mealCategoryNames = {};
  BulkDeliveryAddress? _deliveryAddress;
  BulkDeliveryAddress? get deliveryAddress => _deliveryAddress;
  Map<String, int> get varietyQty => Map.unmodifiable(_varietyQty);

  int? _standardQty;
  int? get standardQty => _standardQty;

  String? _standardDeliveryDate;
  String? get standardDeliveryDate => _standardDeliveryDate;

  int get varietyLineSum => _varietyQty.values.fold(0, (a, b) => a + b);

  int get bulkCartTotalMeals => varietyLineSum + (_standardQty ?? 0);

  bool get hasBulkCartItems => bulkCartTotalMeals > 0;

  Map<String, dynamic>? _lastQuote;
  Map<String, dynamic>? get lastQuote => _lastQuote;

  DateTime? _lastConfigFetchTime;
  DateTime? _lastCategoriesFetchTime;
  final Map<String, DateTime> _lastMealsFetchTime = {};

  bool _isCacheValid(DateTime? lastFetchTime) {
    if (lastFetchTime == null) return false;
    return DateTime.now().difference(lastFetchTime).inMinutes < 5;
  }

  Future<void> loadConfig() async {
    if (_config != null && _isCacheValid(_lastConfigFetchTime)) {
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _config = await _repository.fetchConfig();
      _lastConfigFetchTime = DateTime.now();
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
    _mealCategoryNames.clear();
    notifyListeners();
    _scheduleCartSync();
  }

  void clearStandardDraft() {
    _standardQty = null;
    _standardDeliveryDate = null;
    notifyListeners();
    _scheduleCartSync();
  }

  void clearBulkCart() {
    clearVarietyCart();
    clearStandardDraft();
  }

  void setStandardDraft(int qty, {String? deliveryDate}) {
    if (qty <= 0) {
      _standardQty = null;
      _standardDeliveryDate = null;
    } else {
      _standardQty = qty;
      if (deliveryDate != null && deliveryDate.length >= 10) {
        _standardDeliveryDate = deliveryDate;
      }
    }
    notifyListeners();
    _scheduleCartSync();
  }

  void setStandardDeliveryDate(String? ymd) {
    _standardDeliveryDate = ymd;
    notifyListeners();
  }

  Future<void> loadSavedDeliveryAddress() async {
    final saved = await BulkAddressStorage.load();
    if (saved != null) {
      _deliveryAddress = saved;
      notifyListeners();
    }
  }

  void setDeliveryAddress(BulkDeliveryAddress? address) {
    _deliveryAddress = address;
    notifyListeners();
    if (address != null && address.isComplete) {
      BulkAddressStorage.save(address);
    }
  }

  String? validateDeliveryAddress({bool requireTime = false}) {
    final a = _deliveryAddress;
    if (a == null || !a.isComplete) {
      return 'Select state, city, and enter delivery address (min 5 characters).';
    }
    final pin = a.pincode?.trim() ?? '';
    if (pin.isEmpty || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      return 'Pincode is required and must be exactly 6 digits.';
    }
    if (requireTime && !a.hasDeliveryTime) {
      return 'Select a delivery time.';
    }
    return null;
  }

  BulkMenuOption? mealById(String id) => _varietyMealCatalog[id];

  String? categoryNameForMeal(String mealId) => _mealCategoryNames[mealId];

  int get varietyMealTypeCount =>
      _varietyQty.entries.where((e) => e.value > 0).length;

  static const int varietyCartMaxTotal = 5000;

  String? validateStandardDraft(BulkOrderConfig cfg) {
    final qty = _standardQty ?? 0;
    if (qty <= 0) return 'Enter how many meals you need.';
    if (qty < cfg.minQuantity) {
      return 'Minimum order is ${cfg.minQuantity} meals.';
    }
    if (_deliveryMenu == null) {
      return 'Menu preview is not available yet. Try again shortly.';
    }
    return null;
  }

  /// Validates a single line quantity update (used in multi-meal mode).
  String? validateVarietyLineUpdate(BulkOrderConfig cfg, String mealId, int qty) {
    if (qty <= 0) return null;
    final meal = mealById(mealId);
    if (meal == null) return 'Meal not found.';
    final minQty = meal.minOrderQuantity;
    if (qty < minQty) {
      return '${meal.items} requires at least $minQty portions.';
    }
    return null;
  }

  /// Returns null when the variety cart can proceed to quote/pay.
  String? validateVarietyCart(BulkOrderConfig cfg, {bool forPayment = false}) {
    final lineSum = varietyLineSum;
    if (lineSum == 0) {
      return forPayment ? 'Add portions for at least one meal.' : null;
    }
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

  bool varietyCartCanCheckout(BulkOrderConfig cfg) =>
      validateVarietyCart(cfg, forPayment: true) == null;

  /// Footer copy while browsing (does not block adding lines below tier total).
  String varietyCartStatusMessage(BulkOrderConfig cfg) {
    final sum = varietyLineSum;
    if (sum == 0) return 'Cart is empty — pick a category to add meals';
    final checkoutErr = validateVarietyCart(cfg, forPayment: true);
    if (checkoutErr == null) return '$sum meals in cart — ready to pay';
    if (sum < cfg.tierThreshold) {
      return '$sum in cart · need ${cfg.tierThreshold - sum} more meals (min ${cfg.tierThreshold} total)';
    }
    return checkoutErr;
  }

  List<MapEntry<String, int>> get varietyCartLines =>
      _varietyQty.entries.where((e) => e.value > 0).toList();

  void setVarietyQty(String mealId, int qty, {String? categoryName}) {
    if (qty <= 0) {
      _varietyQty.remove(mealId);
    } else {
      _varietyQty[mealId] = qty;
      if (categoryName != null && categoryName.isNotEmpty) {
        _mealCategoryNames[mealId] = categoryName;
      }
    }
    notifyListeners();
    _scheduleCartSync();
  }

  Timer? _cartSyncTimer;

  void _scheduleCartSync() {
    _cartSyncTimer?.cancel();
    _cartSyncTimer = Timer(const Duration(milliseconds: 600), () {
      syncCartToServer();
    });
  }

  Map<String, dynamic> _cartPayload() => {
        'standard': _standardQty != null && _standardQty! > 0
            ? {
                'quantity': _standardQty,
                'deliveryDate': _standardDeliveryDate,
                'dailyMenuId': _deliveryMenu?.id,
              }
            : null,
        'variety': _varietyQty.entries
            .where((e) => e.value > 0)
            .map(
              (e) => {
                'bulkMealId': e.key,
                'quantity': e.value,
                'categoryName': _mealCategoryNames[e.key],
              },
            )
            .toList(),
        'deliveryAddress': _deliveryAddress?.toApiPayload(),
      };

  void _applyCartPayload(Map<String, dynamic> payload) {
    clearBulkCart();
    final standard = payload['standard'];
    if (standard is Map) {
      final qty = int.tryParse('${standard['quantity']}') ?? 0;
      final date = standard['deliveryDate']?.toString();
      if (qty > 0) {
        _standardQty = qty;
        if (date != null && date.length >= 10) _standardDeliveryDate = date;
      }
    }
    final variety = payload['variety'];
    if (variety is List) {
      for (final row in variety) {
        if (row is! Map) continue;
        final mealId = row['bulkMealId']?.toString() ?? '';
        final qty = int.tryParse('${row['quantity']}') ?? 0;
        if (mealId.isEmpty || qty <= 0) continue;
        _varietyQty[mealId] = qty;
        final cat = row['categoryName']?.toString();
        if (cat != null && cat.isNotEmpty) _mealCategoryNames[mealId] = cat;
      }
    }
    final addr = payload['deliveryAddress'];
    if (addr is Map) {
      try {
        _deliveryAddress = BulkDeliveryAddress(
          stateId: int.tryParse('${addr['stateId'] ?? addr['state_id']}') ?? 0,
          cityId: int.tryParse('${addr['cityId'] ?? addr['city_id']}') ?? 0,
          addressLine: addr['address']?.toString() ?? addr['addressLine']?.toString() ?? '',
          pincode: addr['pincode']?.toString(),
          stateName: addr['stateName']?.toString(),
          cityName: addr['cityName']?.toString(),
          deliveryTime: addr['deliveryTime']?.toString(),
        );
      } catch (_) {}
    }
  }

  Future<void> syncCartToServer() async {
    if (!hasBulkCartItems) {
      try {
        await _repository.deleteCartDraft();
      } catch (_) {}
      return;
    }
    try {
      await _repository.saveCartDraft(_cartPayload());
    } catch (_) {}
  }

  Future<void> loadCartFromServer() async {
    try {
      final payload = await _repository.getCartDraft();
      if (payload == null || payload.isEmpty) return;
      _applyCartPayload(payload);
      final date = _standardDeliveryDate;
      if (date != null && date.length >= 10) {
        await loadMenusForDate(date);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearServerCart() async {
    try {
      await _repository.deleteCartDraft();
    } catch (_) {}
  }

  int varietyQtyFor(String mealId) => _varietyQty[mealId] ?? 0;

  Future<void> loadVarietyCategories() async {
    if (_varietyCategories.isNotEmpty && _isCacheValid(_lastCategoriesFetchTime)) {
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _varietyCategories = await _repository.fetchVarietyCategories();
      _lastCategoriesFetchTime = DateTime.now();
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMealsForCategory(String categoryId, {String? categoryName}) async {
    if (_categoryMeals.isNotEmpty && _isCacheValid(_lastMealsFetchTime[categoryId])) {
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _categoryMeals = await _repository.fetchMealsByCategory(categoryId);
      _lastMealsFetchTime[categoryId] = DateTime.now();
      for (final m in _categoryMeals) {
        _varietyMealCatalog[m.id] = m;
        if (categoryName != null && categoryName.isNotEmpty) {
          _mealCategoryNames[m.id] = categoryName;
        }
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

  Future<Map<String, dynamic>?> checkoutBundle({
    required String deliveryDate,
    required Map<String, dynamic> deliveryAddress,
    bool isSandbox = true,
  }) async {
    if (!NetworkStatusService.instance.hasDeviceConnectivity) {
      _error = 'No internet connection. Connect to complete payment.';
      notifyListeners();
      return null;
    }
    if (!NetworkStatusService.instance.isBackendReachable) {
      _error = 'Cannot reach the server right now. Please try again in a moment.';
      notifyListeners();
      return null;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      Map<String, dynamic>? standard;
      if ((_standardQty ?? 0) > 0 && _deliveryMenu != null) {
        standard = {
          'dailyMenuId': _deliveryMenu!.id,
          'quantity': _standardQty,
        };
      }
      final variety = _varietyQty.entries
          .where((e) => e.value > 0)
          .map((e) => {'bulkMealId': e.key, 'quantity': e.value})
          .toList();

      final paymentData = await _repository.initiateBundlePayment(
        deliveryDate: deliveryDate,
        deliveryAddress: deliveryAddress,
        standard: standard,
        variety: variety,
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

      String status = 'FAILURE';
      String? sdkError;
      try {
        final sdkResult = await PhonePeService.pay(
          orderId: orderId,
          paymentUrl: paymentUrl,
          backendToken: backendToken,
          backendMerchantId: backendMerchantId,
          isSandbox: isSandbox,
        );
        status = sdkResult['status'] ?? 'FAILURE';
        sdkError = sdkResult['error'];
      } catch (sdkEx) {
        sdkError = sdkEx.toString();
      }

      return {
        ...paymentData,
        'sdkStatus': status,
        'sdkError': sdkError,
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

  Future<Map<String, dynamic>?> checkout({
    required String deliveryDate,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryAddress,
    bool isSandbox = true,
  }) async {
    if (!NetworkStatusService.instance.hasDeviceConnectivity) {
      _error = 'No internet connection. Connect to complete payment.';
      notifyListeners();
      return null;
    }
    if (!NetworkStatusService.instance.isBackendReachable) {
      _error = 'Cannot reach the server right now. Please try again in a moment.';
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

      String status = 'FAILURE';
      String? sdkError;
      try {
        final sdkResult = await PhonePeService.pay(
          orderId: orderId,
          paymentUrl: paymentUrl,
          backendToken: backendToken,
          backendMerchantId: backendMerchantId,
          isSandbox: isSandbox,
        );
        status = sdkResult['status'] ?? 'FAILURE';
        sdkError = sdkResult['error'];
      } catch (sdkEx) {
        sdkError = sdkEx.toString();
      }

      return {
        ...paymentData,
        'sdkStatus': status,
        'sdkError': sdkError,
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

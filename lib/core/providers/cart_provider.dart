import 'package:flutter/material.dart';
import 'package:meal_app/core/network/cart_repository.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/services/offline_queue.dart';
import 'package:meal_app/core/services/phonepe_service.dart';
import 'package:meal_app/core/storage/cache_store.dart';
import 'package:meal_app/core/utils/meal_date.dart';

/// Server-side cart item — mirrors the backend response.
class CartItem {
  final int id; // server-side cart item id (for delete)
  final String entityName;
  final String entityType;
  final String planName;
  final double unitPrice;
  final String? startDate;
  final String? entityId;
  final String? subscriptionId;
  final bool includeSaturday;
  final int? mealSizeId;
  final String? mealSizeName;
  final String? mealTiming;

  CartItem({
    required this.id,
    required this.entityName,
    required this.entityType,
    required this.planName,
    required this.unitPrice,
    this.startDate,
    this.entityId,
    this.subscriptionId,
    this.includeSaturday = true,
    this.mealSizeId,
    this.mealSizeName,
    this.mealTiming,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? 0,
      entityName: json['entity_name']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      startDate: json['start_date']?.toString(),
      entityId: json['entity_id']?.toString(),
      subscriptionId: json['subscription_id']?.toString(),
      includeSaturday: json['include_saturday'] == null ? true : json['include_saturday'] == true,
      mealSizeId: json['meal_size_id'] is int
          ? json['meal_size_id'] as int
          : int.tryParse(json['meal_size_id']?.toString() ?? ''),
      mealSizeName: json['meal_size_name']?.toString(),
      mealTiming: json['meal_timing']?.toString(),
    );
  }
}

/// Provider managing the SERVER-SIDE cart.
/// All operations hit the backend — no local-only state.
class CartProvider with ChangeNotifier {
  final CartRepository _repository;

  CartProvider(this._repository) {
    _loadCachedCart();
  }

  List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  String? _cartId;
  String? get cartId => _cartId;

  double _totalAmount = 0;
  double get totalAmount => _totalAmount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;
  DateTime? _lastFetchedAt;
  Future<void>? _inflightFetch;

  int get itemCount => _items.length;

  Future<void> _loadCachedCart() async {
    try {
      final cached = await CacheStore.getJson('cart_data');
      if (cached is Map<String, dynamic>) {
        _cartId = cached['cart_id']?.toString();
        _totalAmount = (cached['total_amount'] as num?)?.toDouble() ?? 0;
        final itemsList = cached['items'];
        if (itemsList is List) {
          _items = itemsList.map((json) => CartItem.fromJson(json)).toList();
        }
        notifyListeners();
      }
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _persistCart() async {
    try {
      await CacheStore.setJson('cart_data', {
        'cart_id': _cartId,
        'total_amount': _totalAmount,
        'items': _items.map((i) => {
          'id': i.id,
          'entity_name': i.entityName,
          'entity_type': i.entityType,
          'plan_name': i.planName,
          'unit_price': i.unitPrice,
          'start_date': i.startDate,
          'entity_id': i.entityId,
          'subscription_id': i.subscriptionId,
          'include_saturday': i.includeSaturday,
          'meal_size_id': i.mealSizeId,
          'meal_size_name': i.mealSizeName,
          'meal_timing': i.mealTiming,
        }).toList(),
      }, ttl: const Duration(hours: 24));
    } catch (_) {
      // ignore cache errors
    }
  }

  // ─── Fetch cart from server ─────────────────────────────────────────────────

  Future<void> fetchCart({bool force = false, bool silent = false}) async {
    final isFresh = _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!).inSeconds < 90;
    if (!force && _items.isNotEmpty && isFresh) return;
    if (_inflightFetch != null) return _inflightFetch;

    final request = _doFetchCart(silent: silent);
    _inflightFetch = request;
    try {
      await request;
    } finally {
      _inflightFetch = null;
    }
  }

  Future<void> _doFetchCart({bool silent = false}) async {
    if (!silent) {
      if (_items.isEmpty) _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final data = await _repository.getCart();

      // Parse the cart response
      final cart = data['cart'];
      if (cart != null) {
        _cartId = cart['id']?.toString();
        _totalAmount = double.tryParse(cart['total_amount']?.toString() ?? '0') ?? 0;
      } else {
        _cartId = null;
        _totalAmount = 0;
      }

      // Parse items
      final List itemsList = data['items'] ?? [];
      _items = itemsList.map((json) => CartItem.fromJson(json)).toList();
      _lastFetchedAt = DateTime.now();
      await _persistCart();
    } catch (e) {
      _error = e.toString();
      // Keep cached cart data on network error instead of clearing
      if (_items.isEmpty) {
        _totalAmount = 0;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // After load, silently fix any items whose start date is missing/today/past.
    // Meal subscriptions can never start today, so we promote them to tomorrow.
    await _autoCorrectInvalidStartDates();
  }

  /// Patches any cart items that have a missing / past / today start_date,
  /// bumping them to tomorrow on the server. Runs in the background; errors
  /// are swallowed so a transient network glitch never blocks the UI.
  Future<void> _autoCorrectInvalidStartDates() async {
    if (_items.isEmpty) return;
    final invalid = _items.where((i) => !MealDate.isValidFutureStartDate(i.startDate)).toList();
    if (invalid.isEmpty) return;

    final tomorrow = MealDate.tomorrowYmd();
    bool changed = false;
    for (final item in invalid) {
      try {
        await _repository.updateCartItemStartDate(itemId: item.id, startDate: tomorrow);
        changed = true;
      } catch (_) {
        // Silent — user can still manually change date in the UI.
      }
    }
    if (changed) {
      // Re-fetch without recursion (skip auto-correct second time).
      try {
        final data = await _repository.getCart();
        final cart = data['cart'];
        if (cart != null) {
          _cartId = cart['id']?.toString();
          _totalAmount = double.tryParse(cart['total_amount']?.toString() ?? '0') ?? 0;
        }
        final List itemsList = data['items'] ?? [];
        _items = itemsList.map((json) => CartItem.fromJson(json)).toList();
        notifyListeners();
      } catch (_) {/* keep prior state */}
    }
  }

  // ─── Add item to server cart ────────────────────────────────────────────────

  Future<bool> addItem({
    required String subscriptionId,
    required String entityType,
    required String entityId,
    required bool includeSaturday,
    required String startDate,
  }) async {
    if (!NetworkStatusService.instance.isOnline) {
      final safeStart = MealDate.isValidFutureStartDate(startDate)
          ? startDate
          : MealDate.tomorrowYmd();
      await OfflineQueue.enqueue(
        method: 'POST',
        path: ApiEndpoints.addToCart,
        data: {
          'subscriptionId': subscriptionId,
          'entityType': entityType,
          'entityId': entityId,
          'includeSaturday': includeSaturday,
          'startDate': safeStart,
        },
      );
      // Optimistic UX: reflect "in cart" immediately.
      _items = [
        ..._items,
        CartItem(
          id: -DateTime.now().microsecondsSinceEpoch,
          entityName: '',
          entityType: entityType,
          planName: '',
          unitPrice: 0,
          startDate: safeStart,
          entityId: entityId,
          subscriptionId: subscriptionId,
          includeSaturday: includeSaturday,
        ),
      ];
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Defensive: never allow today / past as add-to-cart start date.
      final safeStart = MealDate.isValidFutureStartDate(startDate)
          ? startDate
          : MealDate.tomorrowYmd();

      await _repository.addToCart(
        subscriptionId: subscriptionId,
        entityType: entityType,
        entityId: entityId,
        includeSaturday: includeSaturday,
        startDate: safeStart,
      );

      // Refresh cart from server to get updated state
      await fetchCart(force: true, silent: true);
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Update cart line start date ────────────────────────────────────────────

  Future<bool> updateItemStartDate(int cartItemId, String startDate) async {
    if (!NetworkStatusService.instance.isOnline) {
      final safeStart = MealDate.isValidFutureStartDate(startDate)
          ? startDate
          : MealDate.tomorrowYmd();
      await OfflineQueue.enqueue(
        method: 'PATCH',
        path: ApiEndpoints.removeCartItem(cartItemId),
        data: {'startDate': safeStart},
      );
      _items = _items
          .map((i) => i.id == cartItemId
              ? CartItem(
                  id: i.id,
                  entityName: i.entityName,
                  entityType: i.entityType,
                  planName: i.planName,
                  unitPrice: i.unitPrice,
                  startDate: safeStart,
                  entityId: i.entityId,
                  subscriptionId: i.subscriptionId,
                  includeSaturday: i.includeSaturday,
                  mealSizeId: i.mealSizeId,
                  mealSizeName: i.mealSizeName,
                  mealTiming: i.mealTiming,
                )
              : i)
          .toList();
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Defensive: clamp to tomorrow if caller somehow passes today/past.
      final safeStart = MealDate.isValidFutureStartDate(startDate)
          ? startDate
          : MealDate.tomorrowYmd();

      await _repository.updateCartItemStartDate(
        itemId: cartItemId,
        startDate: safeStart,
      );
      await fetchCart(force: true, silent: true);
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Remove item from server cart ───────────────────────────────────────────

  Future<bool> removeItem(int cartItemId) async {
    if (!NetworkStatusService.instance.isOnline) {
      await OfflineQueue.enqueue(
        method: 'DELETE',
        path: ApiEndpoints.removeCartItem(cartItemId),
      );
      _items = _items.where((i) => i.id != cartItemId).toList();
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.removeCartItem(cartItemId);
      // Refresh cart from server
      await fetchCart(force: true, silent: true);
      return true;
    } catch (e) {
      _error = _extractErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Clear entire cart on server ────────────────────────────────────────────

  Future<bool> clearCart() async {
    if (!NetworkStatusService.instance.isOnline) {
      await OfflineQueue.enqueue(method: 'DELETE', path: ApiEndpoints.clearCart);
      _items = [];
      _totalAmount = 0;
      _cartId = null;
      _error = null;
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.clearCart();
      _items = [];
      _totalAmount = 0;
      _cartId = null;
    } catch (e) {
      _error = _extractErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _error == null;
  }

  /// Local-only reset — used after a successful payment to avoid an extra
  /// network round-trip (the backend marks the cart as `checked_out`
  /// during finalization, so it will not be returned by GET /cart anyway).
  void resetLocal() {
    _items = [];
    _totalAmount = 0;
    _cartId = null;
    _error = null;
    notifyListeners();
  }

  // ─── Check if entity is already in cart ─────────────────────────────────────

  bool hasEntity(String entityId) {
    return _items.any((i) => i.entityId == entityId);
  }

  // ─── Cart Checkout via PhonePe SDK ──────────────────────────────────────────

  Future<Map<String, dynamic>?> checkoutAll({bool isSandbox = true}) async {
    if (!NetworkStatusService.instance.isOnline) {
      _error = 'You are offline. Please reconnect to complete payment.';
      notifyListeners();
      return null;
    }

    if (_items.isEmpty) {
      _error = 'Cart is empty';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final paymentData = await _repository.checkoutCart(
        redirectUrl: ApiEndpoints.paymentStatusPage,
      );

      final String? paymentUrl = paymentData['paymentUrl'];
      final String orderId = paymentData['orderId']?.toString() ?? '';
      final String? backendToken = paymentData['token']?.toString() ?? paymentData['orderToken']?.toString();
      final String? backendMerchantId = paymentData['merchantId']?.toString();

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

      final status = sdkResult['status'] ?? 'FAILURE';

      // IMPORTANT: do NOT clear local cart here. The cart must remain intact
      // until the backend confirms the payment as SUCCESS in PaymentStatusScreen.
      // SDK SUCCESS only means the PhonePe app reported success; the order
      // is still marked `pending` in our DB until callback/webhook/polling
      // syncs the actual gateway state.

      return {
        ...paymentData,
        'sdkStatus': status,
        'sdkError': sdkResult['error'],
      };
    } catch (e) {
      _error = _extractErrorMessage(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Extracts a clean error message from exceptions.
  String _extractErrorMessage(Object e) {
    final raw = e.toString();
    // Try to extract 'message' from DioException response
    if (raw.contains('message')) {
      final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(raw);
      if (match != null) return match.group(1)!;
    }
    return raw.replaceAll('Exception:', '').trim();
  }
}

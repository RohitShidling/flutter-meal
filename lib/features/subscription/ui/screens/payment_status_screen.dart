import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String txnId;
  final String orderId;

  /// Hint from caller — `'cart'` for cart checkout, `'single'` for buy-now.
  /// Used as fallback when backend has not yet returned `orderType` during
  /// early polling so we can still apply the correct cart-clear rule.
  final String? orderType;

  const PaymentStatusScreen({
    super.key,
    required this.txnId,
    required this.orderId,
    this.orderType,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  Map<String, dynamic>? _statusData;
  bool _isPolling = true;
  int _retryCount = 0;
  final int _maxRetries = 10;
  bool _postSuccessHandled = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  Future<void> _startPolling() async {
    while (_isPolling && _retryCount < _maxRetries && mounted) {
      try {
        final data = await context.read<PaymentProvider>().checkStatus(widget.txnId);

        if (mounted) {
          setState(() {
            _statusData = data;
            if (data != null) {
              final status = _resolveStatus(data);
              if (status == 'SUCCESS' || status == 'FAILED') {
                _isPolling = false;
              }
            }
          });
        }
      } catch (_) {
        // Continue polling on error
      }

      if (_isPolling && mounted) {
        await Future.delayed(const Duration(seconds: 3));
        _retryCount++;
      }
    }

    if (mounted && _isPolling) {
      setState(() => _isPolling = false);
    }

    // After polling stops, if we resolved to SUCCESS, run the success-side effects.
    if (mounted && _currentStatus == 'SUCCESS' && !_postSuccessHandled) {
      _postSuccessHandled = true;
      // Schedule after current frame so providers have settled
      WidgetsBinding.instance.addPostFrameCallback((_) => _onPaymentConfirmedSuccess());
    }
  }

  /// Runs ONLY when the backend confirms the payment as SUCCESS.
  /// • For cart orders: clears the server-side cart (best-effort, then local).
  /// • Refreshes subscription/meal/payment providers so Home shows "Active Plan".
  Future<void> _onPaymentConfirmedSuccess() async {
    if (!mounted) return;

    final cart = context.read<CartProvider>();
    final meal = context.read<MealProvider>();
    final payment = context.read<PaymentProvider>();
    final subscriptions = context.read<SubscriptionProvider>();

    final orderType = (_statusData?['orderType']?.toString() ?? widget.orderType ?? '').toLowerCase();
    final isCartOrder = orderType == 'cart';

    if (isCartOrder) {
      // Backend marks the cart as `checked_out` during finalization, so the
      // active GET /cart will return empty. Still call clearCart server-side
      // as a defensive cleanup — but if it fails, we always reset locally.
      try {
        await cart.clearCart();
      } catch (_) {/* ignore */}
      cart.resetLocal();
    } else {
      // Even for single-entity purchases, refetch in case server state changed.
      try {
        await cart.fetchCart();
      } catch (_) {/* ignore */}
    }

    // Refresh dashboard-relevant data so Home and Subscription screens show
    // the new active plan immediately when user navigates back.
    try {
      await Future.wait([
        meal.fetchSubscriptionStatus(),
        meal.fetchMealStatus(),
        meal.fetchAlerts(),
        payment.fetchActiveSubscriptions(),
        subscriptions.fetchSubscriptions(force: true),
      ]);
    } catch (_) {/* ignore — these are best-effort refreshes */}
  }

  /// Resolve payment status from the API response.
  /// API response fields: localStatus, gatewayState, orderStatus
  String _resolveStatus(Map<String, dynamic> data) {
    final localStatus = data['localStatus']?.toString().toLowerCase() ?? '';
    final gatewayState = data['gatewayState']?.toString().toUpperCase() ?? '';
    final orderStatus = data['orderStatus']?.toString().toLowerCase() ?? '';

    if (localStatus == 'success' || gatewayState == 'COMPLETED' || orderStatus == 'completed') {
      return 'SUCCESS';
    }
    if (localStatus == 'failed' || gatewayState == 'FAILED' || orderStatus == 'failed') {
      return 'FAILED';
    }
    return 'PENDING';
  }

  String get _currentStatus {
    if (_statusData == null) return 'PENDING';
    return _resolveStatus(_statusData!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _currentStatus;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _isPolling
                      ? _buildLoadingUI(isDark)
                      : (status == 'SUCCESS')
                          ? _buildSuccessUI(isDark)
                          : (status == 'FAILED')
                              ? _buildFailureUI(isDark)
                              : _buildPendingUI(isDark),
                ),
              ),
              if (!_isPolling)
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Back to App', style: TextStyle(fontWeight: FontWeight.w800)),
                ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingUI(bool isDark) {
    return Column(
      children: [
        const CupertinoActivityIndicator(radius: 20),
        const SizedBox(height: 24),
        Text(
          'Verifying Payment Status',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
        const SizedBox(height: 8),
        Text(
          'Please do not close the app or press back.',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
        ),
        const SizedBox(height: 16),
        Text(
          'Attempt ${_retryCount + 1} of $_maxRetries',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade400),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildSuccessUI(bool isDark) {
    final data = _statusData!;
    final transactionId = data['transactionId']?.toString() ?? widget.txnId;
    final amountPaid = data['amountPaid']?.toString() ?? '0';
    final orderType = data['orderType']?.toString() ?? '';
    final entityName = data['entityName']?.toString() ?? '';
    final entityType = data['entityType']?.toString() ?? '';
    final planName = data['planName']?.toString() ?? '';
    final mealTiming = data['mealTiming']?.toString() ?? '';
    final List cartItems = data['cartItems'] ?? [];

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 40),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'Payment Successful!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
          ),
          const SizedBox(height: 12),
          if (orderType == 'cart')
            Text(
              'Your cart order is now active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 16),
            )
          else
            Text(
              entityName.isNotEmpty
                ? 'Subscription for $entityName ($planName) is now active.'
                : 'Your subscription is now active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 16),
            ),
          const SizedBox(height: 32),

          // Transaction details card
          AppleCard(
            child: Column(
              children: [
                _buildStatusRow('Transaction ID', transactionId, isDark),
                _buildStatusRow('Amount Paid', '₹$amountPaid', isDark),
                if (orderType.isNotEmpty)
                  _buildStatusRow('Order Type', orderType.toUpperCase(), isDark),
                if (orderType != 'cart' && planName.isNotEmpty)
                  _buildStatusRow('Plan', planName, isDark),
                if (orderType != 'cart' && entityName.isNotEmpty)
                  _buildStatusRow('For', '$entityName${entityType.isNotEmpty ? ' ($entityType)' : ''}', isDark),
                if (orderType != 'cart' && mealTiming.isNotEmpty)
                  _buildStatusRow('Meal Delivery Time', TimeUtils.formatToDisplay(mealTiming), isDark),
              ],
            ),
          ),

          // Show cart items if this was a cart checkout
          if (cartItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Items Purchased',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
              ),
            ),
            const SizedBox(height: 12),
            ...cartItems.map((item) => _buildCartItemCard(item, isDark)),
          ],
        ],
      ),
    ).animate().fadeIn();
  }

  /// Build a card for each cart item in the checkout response
  Widget _buildCartItemCard(Map<String, dynamic> item, bool isDark) {
    final entityName = item['entity_name']?.toString() ?? '';
    final entityType = item['entity_type']?.toString() ?? '';
    final planName = item['plan_name']?.toString() ?? '';
    final unitPrice = item['unit_price']?.toString() ?? '0';
    final startDate = item['start_date']?.toString() ?? '';
    final mealSizeName = item['meal_size_name']?.toString() ?? '';
    final mealTiming = item['meal_timing']?.toString() ?? '';

    IconData icon;
    Color color;
    switch (entityType) {
      case 'child':
        icon = CupertinoIcons.person_3_fill;
        color = Colors.blue;
        break;
      case 'teacher':
        icon = CupertinoIcons.book_fill;
        color = Colors.green;
        break;
      case 'professional':
        icon = CupertinoIcons.briefcase_fill;
        color = Colors.orange;
        break;
      default:
        icon = CupertinoIcons.person_fill;
        color = AppTheme.primaryColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entityName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                Text('$planName • ${entityType.toUpperCase()}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
                if (mealSizeName.isNotEmpty)
                  Text('Meal Size: $mealSizeName', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
                if (mealTiming.isNotEmpty)
                  Text('Delivery: ${TimeUtils.formatToDisplay(mealTiming)}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
                if (startDate.isNotEmpty)
                  Text('Start: ${MealDate.formatDisplay(startDate)}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
              ],
            ),
          ),
          Text('₹$unitPrice', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? Colors.white : AppTheme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildFailureUI(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 40),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text(
          'Payment Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
        const SizedBox(height: 12),
        Text(
          'Something went wrong with your transaction. Your cart has been kept so you can try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 16),
        ),
        if (widget.txnId.isNotEmpty) ...[
          const SizedBox(height: 24),
          AppleCard(child: _buildStatusRow('Transaction ID', widget.txnId, isDark)),
        ],
      ],
    ).animate().fadeIn();
  }

  Widget _buildPendingUI(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
          child: const Icon(CupertinoIcons.clock, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 24),
        Text(
          'Payment is Pending',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
        const SizedBox(height: 12),
        Text(
          'We are still waiting for confirmation from your bank. It should update shortly. Your cart is preserved.',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _isPolling = true;
              _retryCount = 0;
            });
            _startPolling();
          },
          icon: const Icon(CupertinoIcons.refresh, size: 16),
          label: const Text('Check Again', style: TextStyle(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: const BorderSide(color: AppTheme.primaryColor),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

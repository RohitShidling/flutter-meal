import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_webview_screen.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/widgets/wallet_checkout_section.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _useWallet = true;
  bool _loadingWalletPreview = false;
  double? _walletApplied;
  double? _gatewayAmount;
  CartProvider? _cartProvider;

  static double _parseMoney(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }

  @override
  void dispose() {
    _cartProvider?.removeListener(_scheduleWalletPreview);
    AppRouteTracker.instance.clearIfCurrent(AppScreen.cart);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.cart);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NetworkStatusService.instance.refreshNow();
      if (!mounted) return;
      final cart = context.read<CartProvider>();
      _cartProvider = cart;
      cart.addListener(_scheduleWalletPreview);
      await context.read<PaymentProvider>().fetchWallet(silent: true);
      await cart.fetchCart(force: true);
      cart.syncOfflineItemsIfAny();
      if (!mounted) return;
      context.read<SubscriptionProvider>().fetchSubscriptions(force: true, silent: true);
      _refreshWalletPreview(cart);
    });
  }

  void _scheduleWalletPreview() {
    if (!mounted || _cartProvider == null) return;
    _refreshWalletPreview(_cartProvider!);
  }

  Future<void> _refreshWalletPreview(CartProvider cart) async {
    if (!mounted) return;
    final total = cart.totalAmount;
    if (total <= 0) {
      setState(() {
        _walletApplied = 0;
        _gatewayAmount = 0;
      });
      return;
    }

    setState(() => _loadingWalletPreview = true);
    try {
      final pay = context.read<PaymentProvider>();
      final preview = await pay.previewWalletForTotal(total, useWallet: _useWallet);
      if (!mounted) return;
      setState(() {
        _walletApplied = _parseMoney(preview['walletApplied']);
        _gatewayAmount = _parseMoney(preview['gatewayAmount']);
      });
    } catch (_) {
      // Preview is optional — checkout still works without breakdown.
    } finally {
      if (mounted) setState(() => _loadingWalletPreview = false);
    }
  }

  void _onUseWalletChanged(bool value) {
    final total = _cartProvider?.totalAmount ?? 0;
    setState(() {
      _useWallet = value;
      if (!value) {
        _walletApplied = 0;
        _gatewayAmount = total;
      }
    });
    if (_cartProvider != null) _refreshWalletPreview(_cartProvider!);
  }

  double _amountDueNow(CartProvider cart) {
    if (!_useWallet) return cart.totalAmount;
    if (_gatewayAmount != null) return _gatewayAmount!;
    return cart.totalAmount;
  }

  /// Match cart line to catalog plan so we can show per-variant duration (with vs without Saturday).
  SubscriptionModel? _planForItem(CartItem item, List<SubscriptionModel> plans) {
    final sid = item.subscriptionId?.trim();
    if (sid == null || sid.isEmpty) return null;
    for (final p in plans) {
      if (p.id == sid) return p;
    }
    return null;
  }

  int? _durationDaysForCartLine(CartItem item, SubscriptionModel? plan) {
    if (plan == null) return null;
    final d = item.includeSaturday
        ? (plan.durationDaysWithSaturday ?? plan.durationDays)
        : (plan.durationDaysWithoutSaturday ?? plan.durationDays);
    if (d <= 0) return null;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final subscriptionPlans = context.watch<SubscriptionProvider>().subscriptions;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = cartProvider.items;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cart', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
        leading: IconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearCart(context, cartProvider),
              child: Text('Clear All', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: cartProvider.isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? _buildEmptyCart(isDark)
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => cartProvider.fetchCart(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return _buildCartItem(
                                  context,
                                  items[index],
                                  index,
                                  isDark,
                                  cartProvider,
                                  _planForItem(items[index], subscriptionPlans),
                                )
                                .animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
                          },
                        ),
                      ),
                    ),
                    _buildCheckoutBar(context, cartProvider, isDark),
                  ],
                ),
    );
  }

  Widget _buildEmptyCart(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.cart, size: 80, color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          Text('Your cart is empty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
          const SizedBox(height: 8),
          Text('Add subscriptions from the Resize meal pack screen', style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, int index, bool isDark, CartProvider cartProvider, SubscriptionModel? matchedPlan) {
    IconData entityIcon;
    Color entityColor;
    switch (item.entityType) {
      case 'child':
        entityIcon = CupertinoIcons.person_3_fill;
        entityColor = Colors.blue;
        break;
      case 'teacher':
        entityIcon = CupertinoIcons.book_fill;
        entityColor = Colors.green;
        break;
      case 'professional':
        entityIcon = CupertinoIcons.briefcase_fill;
        entityColor = Colors.orange;
        break;
      default:
        entityIcon = CupertinoIcons.person_fill;
        entityColor = AppTheme.primaryColor;
    }

    return Dismissible(
      key: ValueKey('cart_item_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(20)),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final success = await cartProvider.removeItem(item.id);
        if (!success && mounted) {
          ErrorHandler.showError(this.context, cartProvider.error ?? 'Could not remove item');
        }
        return false; // Don't animate dismiss — fetchCart will refresh the list
      },
      child: AppleCard(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: entityColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(entityIcon, color: entityColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.entityName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                      Text(item.entityType.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : AppTheme.textSecondaryLight, letterSpacing: 0.8)),
                    ],
                  ),
                ),
                Text('₹${item.unitPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.primaryColor)),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Plan', item.planName, isDark),
            _buildDetailRow('Variant', item.includeSaturday ? 'With Saturday' : 'Without Saturday', isDark),
            if (_durationDaysForCartLine(item, matchedPlan) != null)
              _buildDetailRow(
                'Plan length',
                '${_durationDaysForCartLine(item, matchedPlan)} days',
                isDark,
              ),
            if ((item.mealSizeName ?? '').isNotEmpty)
              _buildDetailRow('Meal Size', item.mealSizeName!, isDark),
            if ((item.mealTiming ?? '').isNotEmpty)
              _buildDetailRow('Meal Delivery Time', TimeUtils.formatToDisplay(item.mealTiming), isDark),
            _buildStartDateRow(context, item, isDark, cartProvider),
            const SizedBox(height: 8),
            // Delete button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmRemoveItem(context, item, cartProvider),
                icon: const Icon(CupertinoIcons.trash, size: 16),
                label: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDateRow(BuildContext context, CartItem item, bool isDark, CartProvider cartProvider) {
    final value = MealDate.formatDisplay(item.startDate);
    final isFlagged = !MealDate.isValidFutureStartDate(item.startDate);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meal Start Date', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : AppTheme.textSecondaryLight)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isFlagged ? Colors.orange : (isDark ? Colors.white : AppTheme.textPrimaryLight),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: cartProvider.isLoading ? null : () => _changeStartDate(context, item, cartProvider),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(88, 0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.45), width: 1.5),
              ),
            ),
            child: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStartDate(BuildContext context, CartItem item, CartProvider cartProvider) async {
    final first = MealDate.firstSelectableStartDate();
    final last = MealDate.lastSelectableStartDate();
    final initial = MealDate.parseOrTomorrow(item.startDate);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Select Meal Start Date',
      confirmText: 'SAVE',
    );
    if (selectedDate == null || !context.mounted) return;
    final dateStr = MealDate.formatYmd(selectedDate);
    final ok = await cartProvider.updateItemStartDate(item.id, dateStr);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start date updated'), behavior: SnackBarBehavior.floating));
    } else if (cartProvider.error != null) {
      ErrorHandler.showError(context, cartProvider.error);
    }
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(BuildContext context, CartProvider cartProvider, bool isDark) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final pay = context.watch<PaymentProvider>();
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding > 0 ? bottomPadding + 10 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WalletCheckoutSection(
            useWallet: _useWallet,
            onUseWalletChanged: _onUseWalletChanged,
            walletBalance: pay.walletBalance,
            walletApplied: _walletApplied,
            gatewayAmount: _gatewayAmount,
            totalAmount: cartProvider.totalAmount,
            loadingPreview: _loadingWalletPreview,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${cartProvider.itemCount} ${cartProvider.itemCount == 1 ? 'item' : 'items'}',
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_useWallet && (_walletApplied ?? 0) > 0) ...[
                    Text(
                      'Order total ₹${cartProvider.totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        color: isDark ? Colors.white38 : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    _useWallet && (_walletApplied ?? 0) > 0 ? 'You pay now' : 'Total amount',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                  ),
                  Text(
                    '₹${_amountDueNow(cartProvider).toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: cartProvider.isLoading ? null : () => _handleCheckout(context, cartProvider),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              child: Text(
                _amountDueNow(cartProvider) <= 0.009 && _useWallet
                    ? 'Complete with wallet'
                    : 'Pay ₹${_amountDueNow(cartProvider).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCheckout(BuildContext context, CartProvider cartProvider) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(20)),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [CupertinoActivityIndicator(radius: 14), SizedBox(height: 16), Text('Processing checkout...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))]),
        ),
      ),
    );

    var result = await cartProvider.checkoutAll(
      isSandbox: ApiEndpoints.isSandboxPayment,
      useWallet: _useWallet,
    );
    if (result == null && context.mounted) {
      final err = cartProvider.error ?? '';
      if (err.toLowerCase().contains('pending')) {
        await context.read<PaymentProvider>().abandonPendingPayment(cancelPendingCart: true);
        if (context.mounted) {
          await cartProvider.fetchCart(force: true);
          result = await cartProvider.checkoutAll(
            isSandbox: ApiEndpoints.isSandboxPayment,
            useWallet: _useWallet,
          );
        }
      }
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted || result == null) {
      if (context.mounted && cartProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cartProvider.error!),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final pay = context.read<PaymentProvider>();
    final sdkStatus = result['sdkStatus']?.toString() ?? 'FAILURE';
    if (sdkStatus != 'SUCCESS') {
      await pay.abandonPendingPayment(
        orderId: result['orderId']?.toString(),
        merchantTransactionId: result['merchantTransactionId']?.toString(),
      );
    } else {
      await pay.fetchWallet(silent: true);
    }

    final txnId = result['merchantTransactionId']?.toString() ?? '';
    final orderId = result['orderId']?.toString() ?? '';
    final paymentUrl = result['paymentUrl']?.toString() ?? '';

    if (sdkStatus == 'SUCCESS') {
      if (txnId.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => PaymentStatusScreen(txnId: txnId, orderId: orderId, orderType: 'cart'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Payment failed or was cancelled.'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating));
      }
    } else {
      if (paymentUrl.isNotEmpty && txnId.isNotEmpty) {
        await Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => PaymentWebViewScreen(url: paymentUrl, txnId: txnId, orderId: orderId),
          ),
        );
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(
              builder: (_) => PaymentStatusScreen(txnId: txnId, orderId: orderId, orderType: 'cart'),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                sdkStatus == 'INTERRUPTED'
                    ? 'Payment cancelled. Wallet balance has been restored.'
                    : (result['sdkError']?.toString() ?? 'Payment failed or was cancelled.'),
              ),
              backgroundColor: sdkStatus == 'INTERRUPTED' ? Colors.orange.shade800 : Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _confirmRemoveItem(BuildContext context, CartItem item, CartProvider cartProvider) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove ${item.entityName} from your cart?'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final ok = await cartProvider.removeItem(item.id);
              if (context.mounted && !ok && cartProvider.error != null) {
                ErrorHandler.showError(context, cartProvider.error);
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmClearCart(BuildContext context, CartProvider cartProvider) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final ok = await cartProvider.clearCart();
              if (context.mounted && !ok && cartProvider.error != null) {
                ErrorHandler.showError(context, cartProvider.error);
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

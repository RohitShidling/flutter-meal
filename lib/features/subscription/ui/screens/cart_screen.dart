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

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().syncOfflineItemsIfAny();
      context.read<SubscriptionProvider>().fetchSubscriptions(force: true, silent: true);
    });
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
          Icon(CupertinoIcons.cart, size: 80, color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 24),
          Text('Your cart is empty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
          const SizedBox(height: 8),
          Text('Add subscriptions from the Upgrade screen', style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
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
                  decoration: BoxDecoration(color: entityColor.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
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
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
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
          TextButton(
            onPressed: cartProvider.isLoading ? null : () => _changeStartDate(context, item, cartProvider),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(72, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerRight,
            ),
            child: const Text(
              'Change',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
              ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${cartProvider.itemCount} ${cartProvider.itemCount == 1 ? 'item' : 'items'}', style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total: ', style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
                  Text('₹${cartProvider.totalAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: cartProvider.isLoading ? null : () => _handleCheckout(context, cartProvider),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              child: cartProvider.isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.lock_fill, size: 18), SizedBox(width: 10), Text('Checkout & Pay', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))]),
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

    final result = await cartProvider.checkoutAll(isSandbox: ApiEndpoints.isSandboxPayment);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) return;

    if (result != null) {
      final sdkStatus = result['sdkStatus']?.toString() ?? 'FAILURE';
      final txnId = result['merchantTransactionId']?.toString() ?? '';
      final orderId = result['orderId']?.toString() ?? '';
      if (sdkStatus == 'SUCCESS' || sdkStatus == 'INTERRUPTED') {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => PaymentStatusScreen(
              txnId: txnId,
              orderId: orderId,
              orderType: 'cart',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Payment failed or was cancelled.'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    } else if (cartProvider.error != null) {
      ErrorHandler.showError(context, cartProvider.error);
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
              await cartProvider.removeItem(item.id);
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
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () async { Navigator.pop(context); await cartProvider.clearCart(); }, child: const Text('Clear All')),
        ],
      ),
    );
  }
}

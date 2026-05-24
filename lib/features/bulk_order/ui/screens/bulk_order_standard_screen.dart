import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_cart_screen.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';

/// Standard bulk: pick delivery date first, preview that day's menu, then quantity.
class BulkOrderStandardScreen extends StatefulWidget {
  const BulkOrderStandardScreen({super.key});

  @override
  State<BulkOrderStandardScreen> createState() => _BulkOrderStandardScreenState();
}

class _BulkOrderStandardScreenState extends State<BulkOrderStandardScreen> {
  String? _selectedDate;
  int _qty = 10;

  @override
  void initState() {
    super.initState();
    final p = context.read<BulkOrderProvider>();
    final cfg = p.config;
    if (cfg != null) _qty = cfg.minQuantity;
    _selectedDate = p.standardDeliveryDate;
    if (_selectedDate != null && _selectedDate!.length >= 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BulkOrderProvider>().loadMenusForDate(_selectedDate!);
      });
    }
  }

  int _maxQty(BulkOrderConfig cfg) => cfg.tierThreshold - 1;

  Future<void> _pickDate(BulkOrderConfig cfg) async {
    final ymd = await pickBulkDeliveryDate(context, cfg, _selectedDate);
    if (ymd == null || !mounted) return;
    setState(() => _selectedDate = ymd);
    await context.read<BulkOrderProvider>().loadMenusForDate(ymd);
  }

  void _increment(BulkOrderConfig cfg) {
    if (_selectedDate != null && _qty < _maxQty(cfg)) setState(() => _qty++);
  }

  void _decrement(BulkOrderConfig cfg) {
    if (_selectedDate != null && _qty > cfg.minQuantity) setState(() => _qty--);
  }

  void _addToCart(BulkOrderProvider p, BulkOrderConfig cfg) {
    if (_selectedDate == null || _selectedDate!.length < 10) {
      ErrorHandler.showValidationError(context, 'Select a delivery date first');
      return;
    }
    if (_qty < cfg.minQuantity) {
      ErrorHandler.showValidationError(context, 'Minimum order is ${cfg.minQuantity} meals');
      return;
    }
    if (_qty >= cfg.tierThreshold) {
      ErrorHandler.showValidationError(context, 'For ${cfg.tierThreshold}+ meals, use the large event bulk option.');
      return;
    }
    if (p.deliveryMenu == null) {
      ErrorHandler.showValidationError(context, 'No menu available for the selected date.');
      return;
    }
    p.clearVarietyCart();
    p.setStandardDraft(_qty, deliveryDate: _selectedDate);
    ErrorHandler.showSuccess(context, 'Added $_qty meals to bulk cart');
    Navigator.push(context, CupertinoPageRoute(builder: (_) => const BulkOrderCartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartTotal = p.bulkCartTotalMeals;

    if (cfg == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Standard bulk')),
        body: const Center(child: Text('Configuration unavailable')),
      );
    }

    final maxQty = _maxQty(cfg);
    final pricePerMeal = cfg.pricePerMealUnderThreshold;
    final estimatedTotal = _qty * pricePerMeal;
    final canAdd = _selectedDate != null && p.deliveryMenu != null && !p.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text('Standard Bulk', style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
      ),
      floatingActionButton: cartTotal > 0
          ? FloatingActionButton.extended(
              heroTag: 'standard_bulk_cart_fab',
              onPressed: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const BulkOrderCartScreen()),
              ),
              icon: const Icon(CupertinoIcons.cart_fill),
              label: Text('Cart ($cartTotal)', style: const TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select your delivery date first to see the meal for that day, then choose how many meals you need.',
                    style: TextStyle(fontSize: 15, height: 1.4, color: isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                  ),
                  const SizedBox(height: 16),
                  BulkDeliveryDateTile(
                    deliveryDate: _selectedDate,
                    onTap: () => _pickDate(cfg),
                  ),
                  bulkInfoBanner(
                    isDark: isDark,
                    message: 'Order ${cfg.minQuantity} or more meals. For ${cfg.tierThreshold}+ meals use large event bulk.',
                  ),
                  const SizedBox(height: 20),
                  Text('Menu for selected date', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_selectedDate == null)
                    Text('Pick a date above to load the menu.', style: TextStyle(color: Colors.orange.shade700))
                  else if (p.isLoading && p.deliveryMenu == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (p.deliveryMenu != null)
                    AppleCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bulkMenuImage(p.deliveryMenu!.imageUrl),
                          if (p.deliveryMenu!.imageUrl != null && p.deliveryMenu!.imageUrl!.isNotEmpty)
                            const SizedBox(height: 10),
                          Text(p.deliveryMenu!.menuDate, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(p.deliveryMenu!.items),
                          const SizedBox(height: 8),
                          Text(
                            '₹${pricePerMeal.toStringAsFixed(2)} per meal',
                            style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  else
                    Text('No menu available for this date.', style: TextStyle(color: Colors.red.shade700)),
                  const SizedBox(height: 20),
                  AppleCard(
                    child: Column(
                      children: [
                        Text('Number of Meals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StepperButton(
                              icon: CupertinoIcons.minus,
                              onTap: (_selectedDate != null && _qty > cfg.minQuantity) ? () => _decrement(cfg) : null,
                            ),
                            const SizedBox(width: 24),
                            Container(
                              constraints: const BoxConstraints(minWidth: 80),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedDate != null
                                    ? AppTheme.primaryColor.withValues(alpha: 0.08)
                                    : Colors.grey.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedDate != null
                                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                      : Colors.grey.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Text(
                                '$_qty',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: _selectedDate != null ? AppTheme.primaryColor : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            _StepperButton(
                              icon: CupertinoIcons.plus,
                              onTap: (_selectedDate != null && _qty < maxQty) ? () => _increment(cfg) : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_selectedDate == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Please select a delivery date first',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Text(
                            'Min ${cfg.minQuantity} · Below ${cfg.tierThreshold}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                          ),
                      ],
                    ),
                  ),
                  if (_qty > 0 && p.deliveryMenu != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_qty × ₹${pricePerMeal.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                          ),
                          Text(
                            '₹${estimatedTotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          Material(
            elevation: 12,
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: canAdd ? () => _addToCart(p, cfg) : null,
                    icon: const Icon(CupertinoIcons.cart_badge_plus, size: 20),
                    label: Text('Add $_qty Meals to Cart', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.1),
          border: Border.all(color: enabled ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: enabled ? AppTheme.primaryColor : Colors.grey, size: 22),
      ),
    );
  }
}

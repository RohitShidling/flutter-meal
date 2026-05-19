import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_checkout.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_address_section.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';

/// Orders below tier threshold: delivery date + quantity + single daily menu.
class BulkOrderStandardScreen extends StatefulWidget {
  const BulkOrderStandardScreen({super.key});

  @override
  State<BulkOrderStandardScreen> createState() => _BulkOrderStandardScreenState();
}

class _BulkOrderStandardScreenState extends State<BulkOrderStandardScreen> {
  final _qtyController = TextEditingController();
  String? _deliveryDate;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<BulkOrderProvider>().config;
    if (cfg != null) {
      _qtyController.text = '${cfg.minQuantity}';
      if (cfg.earliestDeliveryDate.length >= 10) {
        _deliveryDate = cfg.earliestDeliveryDate;
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  int get _qty => int.tryParse(_qtyController.text.trim()) ?? 0;

  int _maxQty(BulkOrderConfig cfg) => cfg.standardMaxQuantity;

  Future<void> _pickDate(BulkOrderConfig cfg) async {
    final ymd = await pickBulkDeliveryDate(context, cfg, _deliveryDate);
    if (ymd == null || !mounted) return;
    setState(() => _deliveryDate = ymd);
    await context.read<BulkOrderProvider>().loadMenusForDate(ymd);
  }

  Future<void> _pay(BulkOrderProvider p, BulkOrderConfig cfg) async {
    if (_deliveryDate == null) {
      ErrorHandler.showError(context, 'Select a delivery date');
      return;
    }
    if (_qty < cfg.minQuantity) {
      ErrorHandler.showError(context, 'Minimum order is ${cfg.minQuantity} meals');
      return;
    }
    if (_qty > cfg.standardMaxQuantity) {
      ErrorHandler.showError(
        context,
        'Maximum for standard bulk is ${cfg.standardMaxQuantity} meals.',
      );
      return;
    }
    if (_qty >= cfg.tierThreshold) {
      ErrorHandler.showError(
        context,
        'For ${cfg.tierThreshold} or more meals, use the large event bulk option.',
      );
      return;
    }
    if (p.deliveryMenu == null) {
      ErrorHandler.showError(context, 'No menu available for this delivery date');
      return;
    }
    final addrErr = p.validateDeliveryAddress();
    if (addrErr != null) {
      ErrorHandler.showError(context, addrErr);
      return;
    }

    final items = [
      {'dailyMenuId': p.deliveryMenu!.id, 'quantity': _qty},
    ];

    await BulkOrderCheckout.pay(
      context: context,
      provider: p,
      deliveryDate: _deliveryDate!,
      items: items,
      totalMeals: _qty,
      summaryLines: p.deliveryMenu!.items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cfg == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Standard bulk')),
        body: const Center(child: Text('Configuration unavailable')),
      );
    }

    final maxQty = _maxQty(cfg);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Standard bulk',
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Same meal for everyone on your chosen delivery date.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            bulkInfoBanner(
              isDark: isDark,
              message:
                  'Order between ${cfg.minQuantity} and $maxQty meals. Need ${cfg.tierThreshold}+? Go back and choose Large event bulk.',
            ),
            const SizedBox(height: 16),
            BulkDeliveryDateTile(
              deliveryDate: _deliveryDate,
              onTap: () => _pickDate(cfg),
            ),
            const SizedBox(height: 16),
            const BulkOrderAddressSection(),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of meals',
                hintText: '${cfg.minQuantity}–$maxQty',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Text(
              'Menu for your delivery date',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (p.deliveryMenu != null)
              AppleCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bulkMenuImage(p.deliveryMenu!.imageUrl),
                    if (p.deliveryMenu!.imageUrl != null &&
                        p.deliveryMenu!.imageUrl!.isNotEmpty)
                      const SizedBox(height: 10),
                    Text(
                      p.deliveryMenu!.menuDate,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(p.deliveryMenu!.items),
                    const SizedBox(height: 8),
                    Text(
                      '₹${cfg.pricePerMealUnderThreshold.toStringAsFixed(2)} per meal',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'No menu for this date yet.',
                style: TextStyle(color: Colors.orange.shade700),
              ),
            const SizedBox(height: 24),
            if (_qty > 0 && p.deliveryMenu != null)
              Text(
                'Estimated: ${_qty} × ₹${cfg.pricePerMealUnderThreshold.toStringAsFixed(2)} = '
                '₹${(_qty * cfg.pricePerMealUnderThreshold).toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: p.isLoading ? null : () => _pay(p, cfg),
              child: p.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Get quote & pay'),
            ),
          ],
        ),
      ),
    );
  }
}

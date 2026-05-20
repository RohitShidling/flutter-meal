import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_variety_meal_card.dart';

class BulkOrderCategoryMealsScreen extends StatefulWidget {
  const BulkOrderCategoryMealsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.deliveryDate,
  });

  final String categoryId;
  final String categoryName;
  final String deliveryDate;

  @override
  State<BulkOrderCategoryMealsScreen> createState() => _BulkOrderCategoryMealsScreenState();
}

class _BulkOrderCategoryMealsScreenState extends State<BulkOrderCategoryMealsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BulkOrderProvider>().loadMealsForCategory(widget.categoryId);
    });
  }

  bool _multiMode(BulkOrderConfig cfg) => cfg.allowMultipleVarietyMeals;

  bool _addToCart(String mealId, int qty, BulkOrderConfig cfg, BulkOrderProvider p) {
    if (qty <= 0) {
      p.setVarietyQty(mealId, 0);
      return true;
    }
    final err = p.validateVarietyLineUpdate(cfg, mealId, qty);
    if (err != null) {
      ErrorHandler.showError(context, err);
      return false;
    }
    p.setVarietyQty(mealId, qty);
    if (qty > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${p.mealById(mealId)?.items ?? 'Meal'} added to cart ($qty)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final threshold = cfg?.tierThreshold ?? 50;
    final sum = p.varietyLineSum;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
      ),
      body: p.isLoading && p.categoryMeals.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Set portions and tap Add to cart. Order total is combined across all categories (min $threshold meals).',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                          ),
                        ),
                        if (cfg != null && !_multiMode(cfg))
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Only one meal type for the whole order.',
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (cfg == null)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (p.categoryMeals.isEmpty)
                          Text(
                            'No meals in this category.',
                            style: TextStyle(color: Colors.orange.shade700),
                          )
                        else
                          ...p.categoryMeals.map((m) {
                            final config = cfg;
                            final perMealMin = m.minOrderQuantity < 1 ? 1 : m.minOrderQuantity;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: BulkVarietyMealCard(
                                meal: m,
                                cfg: config,
                                cartQuantity: p.varietyQtyFor(m.id),
                                isDark: isDark,
                                menuImage: bulkMenuImage(m.imageUrl),
                                perMealMin: perMealMin,
                                orderMinTotal: threshold,
                                singleMealOnly: !_multiMode(config),
                                onAddToCart: (n) => _addToCart(m.id, n, config, p),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                if (cfg != null)
                  Material(
                    elevation: 8,
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              sum > 0 ? 'Cart total: $sum meals' : 'Nothing in cart yet',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Back to categories'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_cart_screen.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_variety_meal_card.dart';

class BulkOrderCategoryMealsScreen extends StatefulWidget {
  const BulkOrderCategoryMealsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  final String categoryId;
  final String categoryName;

  @override
  State<BulkOrderCategoryMealsScreen> createState() => _BulkOrderCategoryMealsScreenState();
}

class _BulkOrderCategoryMealsScreenState extends State<BulkOrderCategoryMealsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BulkOrderProvider>().loadMealsForCategory(widget.categoryId, categoryName: widget.categoryName);
    });
  }

  bool _multiMode(BulkOrderConfig cfg) => cfg.allowMultipleVarietyMeals;

  void _commitAll({String? exceptMealId}) {
    for (final e in _cardKeys.entries) {
      if (e.key != exceptMealId) e.value.currentState?.commitNow();
    }
  }

  bool _multiMode(BulkOrderConfig? cfg) => cfg != null && cfg.allowMultipleVarietyMeals;

  int _minForMeal(BulkOrderProvider p, String id) {
    final min = p.mealById(id)?.minOrderQuantity ?? 1;
    return min < 1 ? 1 : min;
  }

  bool _setQty(String mealId, int next, BulkOrderConfig cfg, BulkOrderProvider p) {
    if (!_multiMode(cfg)) {
      if (next <= 0) {
        p.setVarietyQty(mealId, 0, categoryName: widget.categoryName);
        return true;
      }
      p.clearVarietyCart();
      p.setVarietyQty(mealId, next, categoryName: widget.categoryName);
      return true;
    }
    if (next <= 0) {
      p.setVarietyQty(mealId, 0, categoryName: widget.categoryName);
      return true;
    }
    final isNew = p.varietyQtyFor(mealId) == 0;
    if (isNew && p.varietyMealTypeCount >= cfg.maxVarietyTypes) {
      ErrorHandler.showError(context, 'You can pick at most ${cfg.maxVarietyTypes} different meal types.');
      return false;
    }
    p.setVarietyQty(mealId, next, categoryName: widget.categoryName);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sum = p.varietyLineSum;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
      ),
      floatingActionButton: sum > 0
          ? FloatingActionButton.extended(
              heroTag: 'category_cart_fab',
              onPressed: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const BulkOrderCartScreen()),
              ),
              icon: const Icon(CupertinoIcons.cart_fill),
              label: Text('Cart ($sum)', style: const TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: p.isLoading && p.categoryMeals.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add portions for meals in this category. Minimum order rules are checked when you pay.',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                    ),
                  ),
                  if (cfg != null && !_multiMode(cfg))
                    bulkInfoBanner(
                      isDark: isDark,
                      message: 'Only one meal type allowed for the full order.',
                      borderColor: Colors.orange.shade700,
                      backgroundColor: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.1),
                      icon: CupertinoIcons.exclamationmark_triangle_fill,
                    ),
                  const SizedBox(height: 12),
                  if (cfg == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (p.categoryMeals.isEmpty)
                    Text('No meals in this category.', style: TextStyle(color: Colors.orange.shade700))
                  else
                    ...p.categoryMeals.map((m) {
                      final q = p.varietyQtyFor(m.id);
                      final config = cfg;
                      final perMealMin = _multiMode(config) ? _minForMeal(p, m.id) : 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BulkVarietyMealCard(
                          key: _cardKey(m.id),
                          meal: m,
                          cfg: config,
                          quantity: q,
                          isDark: isDark,
                          menuImage: bulkMenuImage(m.imageUrl),
                          minQuantity: perMealMin,
                          singleMealOnly: !_multiMode(config),
                          onBeforeEdit: () => _commitAll(exceptMealId: m.id),
                          onQuantityChanged: (n) => _setQty(m.id, n, config, p),
                        ),
                      );
                    }),
                  // Extra bottom padding for FAB
                  if (sum > 0) const SizedBox(height: 72),
                ],
              ),
            ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_variety_category.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_category_meals_screen.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';

/// Large-event bulk: pick delivery date, browse categories, then meals per category.
class BulkOrderVarietyCategoriesScreen extends StatefulWidget {
  const BulkOrderVarietyCategoriesScreen({super.key});

  @override
  State<BulkOrderVarietyCategoriesScreen> createState() => _BulkOrderVarietyCategoriesScreenState();
}

class _BulkOrderVarietyCategoriesScreenState extends State<BulkOrderVarietyCategoriesScreen> {
  String? _deliveryDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<BulkOrderProvider>();
      p.clearVarietyCart();
      final cfg = p.config;
      if (cfg != null && cfg.earliestDeliveryDate.length >= 10) {
        setState(() => _deliveryDate = cfg.earliestDeliveryDate);
        await p.loadVarietyCategories();
      }
    });
  }

  Future<void> _pickDate() async {
    final cfg = context.read<BulkOrderProvider>().config;
    if (cfg == null) return;
    final ymd = await pickBulkDeliveryDate(context, cfg, _deliveryDate);
    if (ymd == null || !mounted) return;
    setState(() => _deliveryDate = ymd);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final threshold = cfg?.tierThreshold ?? 50;
    final sum = p.varietyLineSum;
    final validationErr = cfg != null ? p.validateVarietyCart(cfg) : null;
    final cartOk = validationErr == null && sum > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          cfg?.varietyTierTitle?.isNotEmpty == true ? cfg!.varietyTierTitle! : 'Large event bulk',
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
      ),
      body: p.isLoading && p.varietyCategories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (cfg?.varietyTierDescription?.isNotEmpty == true)
                          Text(
                            cfg!.varietyTierDescription!,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                            ),
                          ),
                        const SizedBox(height: 12),
                        BulkDeliveryDateTile(
                          deliveryDate: _deliveryDate,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a category to add meals',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (p.varietyCategories.isEmpty)
                          Text(
                            'No categories available yet.',
                            style: TextStyle(color: Colors.orange.shade700),
                          ),
                        ...p.varietyCategories.map((c) => _CategoryCard(
                              category: c,
                              isDark: isDark,
                              onTap: () {
                                if (_deliveryDate == null) return;
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => BulkOrderCategoryMealsScreen(
                                      categoryId: c.id,
                                      categoryName: c.name,
                                      deliveryDate: _deliveryDate!,
                                    ),
                                  ),
                                );
                              },
                            )),
                      ],
                    ),
                  ),
                ),
                Material(
                  elevation: 8,
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(
                        children: [
                          Icon(
                            cartOk ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_triangle_fill,
                            color: cartOk ? Colors.green : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cartOk
                                  ? 'Order total: $sum meals — ready to pay in a category'
                                  : (validationErr ??
                                      '$sum meals — need ${threshold - sum} more (min $threshold)'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cartOk ? null : Colors.orange.shade800,
                              ),
                            ),
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.isDark,
    required this.onTap,
  });

  final BulkVarietyCategory category;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (category.imageUrl != null && category.imageUrl!.isNotEmpty)
                  ColoredBox(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    child: CachedNetworkImage(
                      imageUrl: category.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Container(
                    height: 72,
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    child: Icon(CupertinoIcons.square_grid_2x2, color: AppTheme.primaryColor),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${category.mealCount} meal${category.mealCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

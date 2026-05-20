import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_variety_category.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_category_meals_screen.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_address_section.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_checkout.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_variety_cart_summary.dart';

/// Large-event bulk: delivery date, address, categories, cart, then checkout.
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

  Future<void> _checkout(BulkOrderProvider p, BulkOrderConfig cfg) async {
    if (_deliveryDate == null) {
      ErrorHandler.showError(context, 'Select a delivery date');
      return;
    }
    final addrErr = p.validateDeliveryAddress();
    if (addrErr != null) {
      ErrorHandler.showError(context, addrErr);
      return;
    }
    final err = p.validateVarietyCartForCheckout(cfg);
    if (err != null) {
      ErrorHandler.showError(context, err);
      return;
    }
    final items = p.varietyCartLines
        .map((e) => {'bulkMealId': e.key, 'quantity': e.value})
        .toList();
    final summary = p.varietyCartLines
        .map((e) => '${p.mealById(e.key)?.items ?? e.key} × ${e.value}')
        .join('\n');

    await BulkOrderCheckout.pay(
      context: context,
      provider: p,
      deliveryDate: _deliveryDate!,
      items: items,
      totalMeals: p.varietyLineSum,
      summaryLines: summary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sum = p.varietyLineSum;
    final statusMsg = cfg != null ? p.varietyCartStatusMessage(cfg) : '';
    final canCheckout = cfg != null && p.varietyCartCanCheckout(cfg);

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
                        const SizedBox(height: 16),
                        const BulkOrderAddressSection(),
                        const SizedBox(height: 16),
                        const BulkVarietyCartSummary(),
                        if (sum > 0) const SizedBox(height: 16),
                        Text(
                          'Categories',
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
                              statusMsg,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: canCheckout ? null : Colors.orange.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: (p.isLoading || !canCheckout) ? null : () => _checkout(p, cfg),
                              child: p.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Review & pay'),
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

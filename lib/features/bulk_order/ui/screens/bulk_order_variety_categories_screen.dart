import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_variety_category.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_cart_screen.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_category_meals_screen.dart';

/// Large-event bulk: browse categories and build a cart; pay from the cart screen.
class BulkOrderVarietyCategoriesScreen extends StatefulWidget {
  const BulkOrderVarietyCategoriesScreen({super.key});

  @override
  State<BulkOrderVarietyCategoriesScreen> createState() => _BulkOrderVarietyCategoriesScreenState();
}

class _BulkOrderVarietyCategoriesScreenState extends State<BulkOrderVarietyCategoriesScreen> {
  String? _filterCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BulkOrderProvider>().loadVarietyCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sum = p.varietyLineSum;
    final categories = p.varietyCategories;
    final filtered = _filterCategoryId == null
        ? categories
        : categories.where((c) => c.id == _filterCategoryId).toList();
    final titleText = cfg?.varietyTierTitle?.isNotEmpty == true ? cfg!.varietyTierTitle! : 'Large event bulk';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
      floatingActionButton: p.bulkCartTotalMeals > 0
          ? FloatingActionButton.extended(
              heroTag: 'variety_cart_fab',
              onPressed: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const BulkOrderCartScreen()),
              ),
              icon: const Icon(CupertinoIcons.cart_fill),
              label: Text('Cart (${p.bulkCartTotalMeals})', style: const TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header with rounded bottom corners
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFF3EBE0),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.back, color: Color(0xFF8B7A66)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Buuttii',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    titleText,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF5A4D42),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: p.isLoading && p.varietyCategories.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
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
                          Text(
                            'Choose categories and add meal portions. Delivery details are collected when you pay.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Categories',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                FilterChip(
                                  label: const Text('All'),
                                  selected: _filterCategoryId == null,
                                  onSelected: (_) => setState(() => _filterCategoryId = null),
                                ),
                                ...categories.map(
                                  (c) => Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: FilterChip(
                                      label: Text(c.name),
                                      selected: _filterCategoryId == c.id,
                                      onSelected: (_) => setState(() => _filterCategoryId = c.id),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (filtered.isEmpty)
                            Text(
                              'No categories available yet.',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                          ...filtered.map((c) => _CategoryCard(
                                category: c,
                                isDark: isDark,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (_) => BulkOrderCategoryMealsScreen(
                                        categoryId: c.id,
                                        categoryName: c.name,
                                      ),
                                    ),
                                  );
                                },
                              )),
                          // Extra bottom padding for FAB
                          if (sum > 0) const SizedBox(height: 72),
                        ],
                      ),
                    ),
            ),
          ],
        ),
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
              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
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

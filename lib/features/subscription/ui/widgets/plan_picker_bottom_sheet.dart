import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/utils/money_format.dart';
import 'package:meal_app/core/widgets/app_skeleton.dart';

/// Bottom-sheet plan picker: regular plans first, then trial; with/without Saturday per plan.
class PlanPickerBottomSheet {
  PlanPickerBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required String entityType,
    required String entityId,
    required String entityName,
    required int mealSizeId,
  }) async {
    await context.read<SubscriptionProvider>().fetchSubscriptions(force: true, silent: true);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlanPickerSheet(
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        mealSizeId: mealSizeId,
      ),
    );
  }
}

class _PlanPickerSheet extends StatefulWidget {
  final String entityType;
  final String entityId;
  final String entityName;
  final int mealSizeId;

  const _PlanPickerSheet({
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.mealSizeId,
  });

  @override
  State<_PlanPickerSheet> createState() => _PlanPickerSheetState();
}

class _PlanPickerSheetState extends State<_PlanPickerSheet> {
  bool _adding = false;

  List<SubscriptionModel> _plansForSize(List<SubscriptionModel> all) {
    return all
        .where((p) => p.mealSizeId == widget.mealSizeId)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  String _mealSizeLabel() {
    final sizes = context.read<LookupProvider>().mealSizes;
    final match = sizes.where((m) => m.id == widget.mealSizeId).firstOrNull;
    return match?.displayName ?? 'Meal size ${widget.mealSizeId}';
  }

  Future<void> _addPlan(SubscriptionModel plan, bool includeSaturday) async {
    if (_adding) return;
    setState(() => _adding = true);
    final cart = context.read<CartProvider>();
    final priceStr = includeSaturday ? plan.priceWithSaturday : plan.priceWithoutSaturday;
    final ok = await cart.addItem(
      subscriptionId: plan.id,
      entityType: widget.entityType,
      entityId: widget.entityId,
      includeSaturday: includeSaturday,
      startDate: MealDate.tomorrowYmd(),
      entityName: widget.entityName,
      planName: plan.planName,
      unitPrice: MoneyFormat.parseAmount(priceStr),
      mealSizeId: plan.mealSizeId,
      mealSizeName: _mealSizeLabel(),
    );
    if (!mounted) return;
    setState(() => _adding = false);
    if (ok) {
      await cart.fetchCart(silent: true);
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      ErrorHandler.showError(context, cart.error ?? 'Could not add to cart');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subProvider = context.watch<SubscriptionProvider>();
    final all = subProvider.subscriptions;
    final forSize = _plansForSize(all);
    final regular = forSize.where((p) => p.trialDays == 0).toList();
    final trial = forSize.where((p) => p.trialDays > 0).toList();
    final loading = forSize.isEmpty && subProvider.isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose a plan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.entityName} • ${_mealSizeLabel()}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark_circle_fill),
                    ),
                  ],
                ),
              ),
              if (_adding)
                const LinearProgressIndicator(minHeight: 2, color: AppTheme.primaryColor),
              Expanded(
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: PlanCatalogSkeleton(isDark: isDark),
                      )
                    : forSize.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No plans are published for this meal size yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                            children: [
                              if (regular.isNotEmpty) ...[
                                _sectionTitle('Regular plans', isDark),
                                const SizedBox(height: 10),
                                ...regular.expand((p) => _planVariants(context, p, isDark)),
                                const SizedBox(height: 20),
                              ],
                              if (trial.isNotEmpty) ...[
                                _sectionTitle('Trial plans', isDark),
                                const SizedBox(height: 10),
                                ...trial.expand((p) => _planVariants(context, p, isDark)),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
        color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.9 : 1),
      ),
    );
  }

  List<Widget> _planVariants(BuildContext context, SubscriptionModel plan, bool isDark) {
    final widgets = <Widget>[];
    if (plan.saturdayOptionEnabled) {
      widgets.add(_variantTile(
        context,
        plan: plan,
        includeSaturday: true,
        isDark: isDark,
      ));
      widgets.add(const SizedBox(height: 8));
      widgets.add(_variantTile(
        context,
        plan: plan,
        includeSaturday: false,
        isDark: isDark,
      ));
    } else {
      widgets.add(_variantTile(
        context,
        plan: plan,
        includeSaturday: true,
        isDark: isDark,
        hideSaturdayLabel: true,
      ));
    }
    widgets.add(const SizedBox(height: 12));
    return widgets;
  }

  Widget _variantTile(
    BuildContext context, {
    required SubscriptionModel plan,
    required bool includeSaturday,
    required bool isDark,
    bool hideSaturdayLabel = false,
  }) {
    final price = includeSaturday ? plan.priceWithSaturday : plan.priceWithoutSaturday;
    final duration = includeSaturday
        ? (plan.durationDaysWithSaturday ?? plan.durationDays)
        : (plan.durationDaysWithoutSaturday ?? plan.durationDays);
    final title = hideSaturdayLabel
        ? plan.planName
        : (includeSaturday ? 'With Saturday' : 'Without Saturday');
    final subtitle = hideSaturdayLabel
        ? '${plan.billingCycle} • $duration days'
        : (includeSaturday ? 'Includes Saturday deliveries' : 'Saturday meals excluded');

    final inCart = context.watch<CartProvider>().hasExactCartItem(
          entityType: widget.entityType,
          entityId: widget.entityId,
          subscriptionId: plan.id,
          includeSaturday: includeSaturday,
        );

    return Material(
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _adding || inCart ? null : () => _addPlan(plan, includeSaturday),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: inCart
                  ? Colors.green.withValues(alpha: 0.5)
                  : (isDark ? Colors.white12 : Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${MoneyFormat.display(price)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    inCart ? 'In cart' : 'Add to cart',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: inCart ? Colors.green.shade700 : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

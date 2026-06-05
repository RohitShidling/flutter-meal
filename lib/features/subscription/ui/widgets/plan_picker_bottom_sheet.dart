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
import 'package:meal_app/features/subscription/ui/widgets/plan_features_row.dart';

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

  int _durationDays(SubscriptionModel plan, bool includeSaturday) {
    if (includeSaturday) {
      return plan.durationDaysWithSaturday ?? plan.durationDays;
    }
    return plan.durationDaysWithoutSaturday ?? plan.durationDays;
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
                                ...regular.map((p) => _planCard(context, p, isDark)),
                                const SizedBox(height: 20),
                              ],
                              if (trial.isNotEmpty) ...[
                                _sectionTitle('Trial plans', isDark),
                                const SizedBox(height: 10),
                                ...trial.map((p) => _planCard(context, p, isDark, isTrial: true)),
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

  Widget _planCard(BuildContext context, SubscriptionModel plan, bool isDark, {bool isTrial = false}) {
    final variants = <_VariantSpec>[];
    if (plan.saturdayOptionEnabled) {
      variants.add(_VariantSpec(
        includeSaturday: true,
        label: 'With Saturday',
        hint: 'Includes Saturday deliveries',
      ));
      variants.add(_VariantSpec(
        includeSaturday: false,
        label: 'Without Saturday',
        hint: 'Saturday meals excluded',
      ));
    } else {
      variants.add(_VariantSpec(
        includeSaturday: true,
        label: plan.planName,
        hint: plan.billingCycle,
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      plan.planName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                  ),
                  if (isTrial)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'TRIAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                plan.billingCycle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              ...variants.map((v) => _variantRow(context, plan, v, isDark)),
              if (plan.features.isNotEmpty) ...[
                const SizedBox(height: 12),
                PlanFeaturesRow(features: plan.features, isDark: isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _variantRow(
    BuildContext context,
    SubscriptionModel plan,
    _VariantSpec variant,
    bool isDark,
  ) {
    final includeSaturday = variant.includeSaturday;
    final price = includeSaturday ? plan.priceWithSaturday : plan.priceWithoutSaturday;
    final days = _durationDays(plan, includeSaturday);
    final inCart = context.watch<CartProvider>().hasExactCartItem(
          entityType: widget.entityType,
          entityId: widget.entityId,
          subscriptionId: plan.id,
          includeSaturday: includeSaturday,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? const Color(0xFF282828) : const Color(0xFFF7F2EA),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _adding || inCart ? null : () => _addPlan(plan, includeSaturday),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variant.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        variant.hint,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                        ),
                      ),
                      if (days > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E2420) : const Color(0xFFE8E0D0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$days delivery days',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
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
                        fontSize: 15,
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
      ),
    );
  }
}

class _VariantSpec {
  final bool includeSaturday;
  final String label;
  final String hint;

  const _VariantSpec({
    required this.includeSaturday,
    required this.label,
    required this.hint,
  });
}

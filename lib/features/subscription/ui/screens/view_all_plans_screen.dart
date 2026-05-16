import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';

/// Read-only catalog of active subscription plans — pricing, duration, features.
/// Purchase from Children / Teacher / Professional manage screens.
class ViewAllPlansScreen extends StatefulWidget {
  const ViewAllPlansScreen({super.key});

  @override
  State<ViewAllPlansScreen> createState() => _ViewAllPlansScreenState();
}

class _ViewAllPlansScreenState extends State<ViewAllPlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchSubscriptions(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plans = [...context.watch<SubscriptionProvider>().subscriptions]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text(
              'All plans',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList.separated(
              itemCount: plans.isEmpty ? 1 : plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (plans.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        'Plans are unavailable right now. Pull down to retry.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ),
                  );
                }
                final p = plans[index];
                return _PlanCatalogTile(plan: p, isDark: isDark, index: index, total: plans.length);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCatalogTile extends StatelessWidget {
  final SubscriptionModel plan;
  final bool isDark;
  final int index;
  final int total;

  const _PlanCatalogTile({
    required this.plan,
    required this.isDark,
    required this.index,
    required this.total,
  });

  String? _badgeLabel() {
    if (plan.trialDays > 0) return 'Trial';
    if (total >= 3 && index == total ~/ 2) return 'Recommended';
    if (index == 0) return 'Entry';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badgeLabel();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plan.planName.trim().isEmpty ? 'Plan ${plan.id}' : plan.planName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${plan.billingCycle} • ${plan.durationDays} meals window',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _priceLine(
                  isDark,
                  'With Saturday',
                  '₹${plan.priceWithSaturday}',
                  plan.durationDaysWithSaturday ?? plan.durationDays,
                ),
              ),
              const SizedBox(width: 12),
              if (plan.saturdayOptionEnabled)
                Expanded(
                  child: _priceLine(
                    isDark,
                    'No Sat',
                    '₹${plan.priceWithoutSaturday}',
                    plan.durationDaysWithoutSaturday ?? plan.durationDays,
                  ),
                ),
            ],
          ),
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...plan.features.take(6).map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          CupertinoIcons.check_mark_circled_solid,
                          size: 16,
                          color: isDark ? Colors.greenAccent.shade400 : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: isDark ? Colors.white.withValues(alpha: 0.92) : AppTheme.textPrimaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (plan.features.length > 6)
              Text(
                '+${plan.features.length - 6} more benefits',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            'To subscribe, choose a child, teacher, or professional profile on the Subscribe screen.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceLine(bool isDark, String label, String rupee, int days) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rupee,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          Text(
            '$days meal days',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

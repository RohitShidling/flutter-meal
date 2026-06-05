import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/subscription/ui/widgets/meal_size_segmented_control.dart';

/// Read-only catalog of active subscription plans — pricing, duration, features.
/// Purchase from Children / Teacher / Professional profile management screens.
class ViewAllPlansScreen extends StatefulWidget {
  const ViewAllPlansScreen({super.key});

  @override
  State<ViewAllPlansScreen> createState() => _ViewAllPlansScreenState();
}

class _ViewAllPlansScreenState extends State<ViewAllPlansScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _sectionKeys = {};
  int _selectedSizeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchSubscriptions(force: true, silent: true);
      context.read<LookupProvider>().fetchInitialData(force: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<_MealSizeSegment> _segments(List<SubscriptionModel> plans, LookupProvider lookup) {
    final ids = <int>{};
    for (final p in plans) {
      if (p.mealSizeId != null && p.mealSizeId! > 0) ids.add(p.mealSizeId!);
    }
    if (ids.isEmpty) return const [];

    final sizes = lookup.mealSizes.where((s) => ids.contains(s.id)).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return sizes
        .map((s) => _MealSizeSegment(id: s.id, label: s.displayName.trim().isEmpty ? s.name : s.displayName))
        .toList();
  }

  GlobalKey _keyForSection(int mealSizeId) =>
      _sectionKeys.putIfAbsent(mealSizeId, GlobalKey.new);

  Future<void> _scrollToSection(int index, List<_MealSizeSegment> segments) async {
    if (index < 0 || index >= segments.length) return;
    setState(() => _selectedSizeIndex = index);
    final ctx = _keyForSection(segments[index].id).currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lookup = context.watch<LookupProvider>();
    final plans = [...context.watch<SubscriptionProvider>().subscriptions]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final segments = _segments(plans, lookup);
    if (segments.isNotEmpty && _selectedSizeIndex >= segments.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSizeIndex = 0);
      });
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF3EBE0),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.back, color: Color(0xFF8B7A66)),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All Plans',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF5A4D42),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (segments.length >= 2)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SegmentHeaderDelegate(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: MealSizeSegmentedControl(
                    options: segments.map((s) => s.label).toList(),
                    selectedIndex: _selectedSizeIndex.clamp(0, segments.length - 1),
                    onChanged: (i) => _scrollToSection(i, segments),
                  ),
                ),
                backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
              ),
            ),
          if (plans.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
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
              ),
            )
          else if (segments.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlanCatalogTile(plan: plans[index], isDark: isDark),
                  ),
                  childCount: plans.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  segments.expand((seg) {
                    final sectionPlans = plans
                        .where((p) => p.mealSizeId == seg.id)
                        .toList()
                      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
                    if (sectionPlans.isEmpty) return <Widget>[];
                    return [
                      KeyedSubtree(
                        key: _keyForSection(seg.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (seg != segments.first) const SizedBox(height: 16),
                            ...sectionPlans.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _PlanCatalogTile(plan: p, isDark: isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SegmentHeaderDelegate({required this.child, required this.backgroundColor});

  final Widget child;
  final Color backgroundColor;

  @override
  double get minExtent => 72;

  @override
  double get maxExtent => 72;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: backgroundColor, child: child);
  }

  @override
  bool shouldRebuild(covariant _SegmentHeaderDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.backgroundColor != backgroundColor;
}

class _MealSizeSegment {
  final int id;
  final String label;
  const _MealSizeSegment({required this.id, required this.label});
}

class _PlanCatalogTile extends StatelessWidget {
  final SubscriptionModel plan;
  final bool isDark;

  const _PlanCatalogTile({required this.plan, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isTrial = plan.trialDays > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.5,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 88),
                child: Text(
                  plan.planName.trim().isEmpty ? 'Plan ${plan.id}' : plan.planName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
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
                        'Without Saturday',
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
              const SizedBox(height: 10),
              Text(
                'To subscribe, choose a child, teacher, or professional profile in Profile management.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTheme.textPrimaryLight.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isTrial ? const Color(0xFFFF6B00) : const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: isTrial 
                        ? const Color(0xFFFF6B00).withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isTrial 
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
              child: Text(
                isTrial ? 'TRIAL' : 'Regular',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceLine(bool isDark, String label, String rupee, int days) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFFFF4EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark.withValues(alpha: 0.5) : AppTheme.borderLight,
          width: 1.2,
        ),
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

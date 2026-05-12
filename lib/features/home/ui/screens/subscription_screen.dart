import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/children/ui/screens/children_management_screen.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/cart_screen.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/widgets/badges/subscription_badge.dart';
import 'package:meal_app/features/subscription/ui/widgets/meal_size_segmented_control.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _step = 0;
  String? _selectedEntityType;
  String? _selectedEntityId;
  String? _selectedEntityName;
  int? _selectedMealSizeId;
  int? _selectedTrialMealSizeId;
  int? _selectedRegularMealSizeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchSubscriptions(silent: true);
      context.read<ChildrenProvider>().fetchChildren(silent: true);
      context.read<ProfileProvider>().fetchProfiles(silent: true);
      context.read<CartProvider>().fetchCart(silent: true);
    });
  }

  /// Next calendar day (local) at midnight — lower bound for start dates.
  DateTime _firstSelectableStartDate() {
    final n = DateTime.now().add(const Duration(days: 1));
    return DateTime(n.year, n.month, n.day);
  }

  /// yyyy-MM-dd — same rules as direct "Buy Now" payment.
  Future<String?> _pickStartDate(
    BuildContext context, {
    String? currentIso,
    String confirmText = 'CONFIRM',
  }) async {
    final first = _firstSelectableStartDate();
    DateTime initial = first;
    if (currentIso != null) {
      try {
        final parsed = DateTime.parse(currentIso);
        final p = DateTime(parsed.year, parsed.month, parsed.day);
        if (!p.isBefore(first)) initial = p;
      } catch (_) {}
    }
    final last = first.add(const Duration(days: 60));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Select Meal Start Date',
      confirmText: confirmText,
    );
    if (selectedDate == null) return null;
    return '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: context.watch<CartProvider>().itemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const CartScreen())),
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(CupertinoIcons.cart_fill, color: Colors.white),
              label: Text(
                'Cart (${context.watch<CartProvider>().itemCount})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<SubscriptionProvider>().fetchSubscriptions(force: true),
            context.read<ChildrenProvider>().fetchChildren(force: true),
            context.read<ProfileProvider>().fetchProfiles(force: true),
            context.read<CartProvider>().fetchCart(force: true, silent: true),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _step == 0 ? _buildEntitySelectionView() : _buildPlanSelectionView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntitySelectionView() {
    final childrenProvider = context.watch<ChildrenProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final cartProvider = context.watch<CartProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Profile to Upgrade',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 12),
        Text(
          'Who are you buying this subscription for?',
          style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedEntityType = null;
                  _selectedEntityId = null;
                  _selectedEntityName = null;
                  _selectedMealSizeId = null;
                  _step = 1;
                });
              },
              icon: const Icon(CupertinoIcons.square_grid_2x2, size: 15),
              label: const Text('View All Plans', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        if (childrenProvider.children.isNotEmpty) ...[
          const Text('CHILDREN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
          const SizedBox(height: 12),
          ...childrenProvider.children.map((child) => _buildEntityCard(
            context,
            entityType: 'child',
            entityId: child.id!,
            name: child.name,
            subtitle: 'Child • ${child.mealSizeName ?? 'Standard'}',
            icon: CupertinoIcons.person_3_fill,
            color: Colors.blue,
            isDark: isDark,
            mealSizeId: child.mealSizeId,
            isInCart: cartProvider.hasEntity(child.id!),
          )),
          const SizedBox(height: 20),
        ],

        if (profileProvider.teacherProfile != null || profileProvider.professionalProfile != null) ...[
          const Text('OTHER PROFILES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
          const SizedBox(height: 12),
        ],
        if (profileProvider.teacherProfile != null)
          _buildEntityCard(
            context,
            entityType: 'teacher',
            entityId: profileProvider.teacherProfile!.id!,
            name: profileProvider.teacherProfile!.name,
            subtitle: 'Teacher Profile • Large Pack',
            icon: CupertinoIcons.book_fill,
            color: Colors.green,
            isDark: isDark,
            mealSizeId: profileProvider.teacherProfile!.mealSizeId,
            isInCart: cartProvider.hasEntity(profileProvider.teacherProfile!.id!),
          ),
        if (profileProvider.professionalProfile != null)
          _buildEntityCard(
            context,
            entityType: 'professional',
            entityId: profileProvider.professionalProfile!.id!,
            name: profileProvider.professionalProfile!.name,
            subtitle: 'Pro Profile • Large Pack',
            icon: CupertinoIcons.briefcase_fill,
            color: Colors.orange,
            isDark: isDark,
            mealSizeId: profileProvider.professionalProfile!.mealSizeId,
            isInCart: cartProvider.hasEntity(profileProvider.professionalProfile!.id!),
          ),

        if (childrenProvider.children.isEmpty && profileProvider.teacherProfile == null && profileProvider.professionalProfile == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                const Center(child: Text('No active profiles found to upgrade.')),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const ChildrenManagementScreen())),
                  icon: const Icon(CupertinoIcons.person_add),
                  label: const Text('Add Child / Profile'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEntityCard(
    BuildContext context, {
    required String entityType,
    required String entityId,
    required String name,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    int? mealSizeId,
    bool isInCart = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 21,
                                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                              ),
                              maxLines: 3,
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          _buildSubscriptionIndicator(entityType, entityId),
                        ],
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSecondaryLight, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedEntityType = entityType;
                        _selectedEntityId = entityId;
                        _selectedEntityName = name;
                        _selectedMealSizeId = mealSizeId;
                        _step = 1;
                      });
                    },
                    icon: const Icon(CupertinoIcons.creditcard, size: 16),
                    label: const Text('View Plans', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isInCart ? null : () => _quickAddToCart(entityType, entityId, name, mealSizeId),
                    icon: Icon(isInCart ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.cart_badge_plus, size: 16),
                    label: Text(
                      isInCart ? 'In Cart' : 'Add to Cart',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isInCart ? Colors.grey : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionIndicator(String entityType, String entityId) {
    final statusData = context.watch<MealProvider>().subscriptionStatusData;
    final rows = (statusData?['data'] as List?) ?? const [];
    Map<String, dynamic>? match;
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      if (row['entity_type']?.toString() == entityType && row['entity_id']?.toString() == entityId && row['subscription_status'] == true) {
        match = row;
        break;
      }
    }
    if (match == null) {
      return const SizedBox.shrink();
    }
    return const SubscriptionBadge();
  }

  /// Quick add to cart via server API.
  void _quickAddToCart(String entityType, String entityId, String name, int? mealSizeId) {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final plans = subscriptionProvider.subscriptions.where((plan) {
      if (mealSizeId != null && plan.mealSizeId != null) {
        return plan.mealSizeId == mealSizeId;
      }
      return true;
    }).toList();

    if (plans.isEmpty) {
      ErrorHandler.showError(context, 'No plans available for this profile.');
      return;
    }

    setState(() {
      _selectedEntityType = entityType;
      _selectedEntityId = entityId;
      _selectedEntityName = name;
      _selectedMealSizeId = mealSizeId;
    });

    if (plans.length == 1) {
      _showSaturdayOptionSheet(context, plans.first, entityType, entityId);
      return;
    }

    _showPlanPickerSheet(context, plans, entityType, entityId, name);
  }

  /// Add to cart via backend API — user picks start date (same as Buy Now).
  Future<void> _addToCartViaAPI(
    SubscriptionModel plan,
    String entityType,
    String entityId,
    bool includeSaturday,
  ) async {
    // Default to tomorrow — user can change start date from the cart screen
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final startDate = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    final cartProvider = context.read<CartProvider>();
    final success = await cartProvider.addItem(
      subscriptionId: plan.id,
      entityType: entityType,
      entityId: entityId,
      includeSaturday: includeSaturday,
      startDate: startDate,
    );

    if (mounted) {
      if (success) {
        final variant = includeSaturday ? 'With Saturday' : 'Without Saturday';
        ErrorHandler.showSuccess(context, '${plan.planName} ($variant) added to cart — tap Cart to change start date');
      } else {
        ErrorHandler.showError(context, cartProvider.error ?? 'Failed to add to cart');
      }
    }
  }

  void _showPlanPickerSheet(BuildContext context, List<SubscriptionModel> plans, String entityType, String entityId, String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 36),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Plan for $name', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
            const SizedBox(height: 16),
            ...plans.map((plan) => InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _showSaturdayOptionSheet(context, plan, entityType, entityId);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.planName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                          Text(
                            '${plan.billingCycle} • ${plan.durationDays} days',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${plan.priceWithSaturday} / ₹${plan.priceWithoutSaturday}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSelectionView() {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final availablePlans = subscriptionProvider.subscriptions.where((plan) {
      if (_selectedMealSizeId != null && plan.mealSizeId != null) {
        return plan.mealSizeId == _selectedMealSizeId;
      }
      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trialPlans = availablePlans.where((p) => p.trialDays > 0).toList();
    final paidPlans = availablePlans.where((p) => p.trialDays == 0).toList();
    final hasTrial = trialPlans.isNotEmpty;
    final hasPaid = paidPlans.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Plan',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        if (_selectedEntityName != null)
          Text(
            'For $_selectedEntityName',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
          ),
        const SizedBox(height: 8),
        Text(
          'Unlock premium meal tracking.',
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 32),

        if (subscriptionProvider.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (availablePlans.isEmpty)
          const Text('No subscription plans available for this profile type.')
        else ...[
          // ─── Trial Section ─────────────────────────────────────────────
          if (hasTrial) ...[
            PlanSectionHeader(
              title: 'Trial Plan',
              subtitle: 'Start with a risk-free trial',
            ),
            const SizedBox(height: 16),
            _buildPlanSection(
              plans: trialPlans,
              selectedMealSizeId: _selectedTrialMealSizeId,
              onSelectMealSize: (value) => setState(() => _selectedTrialMealSizeId = value),
              isTrialSection: true,
            ),
            const SizedBox(height: 32),
          ],

          // ─── Regular Section ─────────────────────────────────────────
          if (hasPaid) ...[
            PlanSectionHeader(
              title: 'Regular Plan',
              subtitle: 'Full subscription plans',
            ),
            const SizedBox(height: 16),
            _buildPlanSection(
              plans: paidPlans,
              selectedMealSizeId: _selectedRegularMealSizeId,
              onSelectMealSize: (value) => setState(() => _selectedRegularMealSizeId = value),
              isTrialSection: false,
            ),
            const SizedBox(height: 32),
          ],
        ],

        _buildFAQSection(),
      ],
    );
  }

  String _mealVariantLabel(SubscriptionModel plan) {
    final raw = plan.planName.trim().toLowerCase();
    if (raw.contains('small')) return 'Small';
    if (raw.contains('medium')) return 'Medium';
    if (raw.contains('large')) return 'Large';
    return plan.planName;
  }

  Widget _buildPlanSection({
    required List<SubscriptionModel> plans,
    required int? selectedMealSizeId,
    required ValueChanged<int?> onSelectMealSize,
    required bool isTrialSection,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = [...plans]..sort((a, b) => (a.displayOrder).compareTo(b.displayOrder));

    // Extract unique meal size labels preserving order
    final mealSizeMap = <int, String>{};
    for (final plan in sorted) {
      if (plan.mealSizeId != null) {
        mealSizeMap.putIfAbsent(plan.mealSizeId!, () => _mealVariantLabel(plan));
      }
    }
    final mealSizeIds = mealSizeMap.keys.toList();
    final mealSizeLabels = mealSizeMap.values.toList();

    if (mealSizeIds.isEmpty) {
      return EmptyPlanState(
        message: isTrialSection ? 'No trial plans available for this profile.' : 'No regular plans available for this profile.',
      );
    }

    // Default selection
    if (selectedMealSizeId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSelectMealSize(mealSizeIds.first);
      });
    }

    final activeMealSizeId = selectedMealSizeId ?? mealSizeIds.first;
    final selectedPlan = sorted.firstWhere(
      (p) => p.mealSizeId == activeMealSizeId,
      orElse: () => sorted.first,
    );

    final selectedIndex = mealSizeIds.indexOf(activeMealSizeId).clamp(0, mealSizeIds.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MealSizeSegmentedControlWrap(
          options: mealSizeLabels,
          selectedIndex: selectedIndex,
          onChanged: (index) => onSelectMealSize(mealSizeIds[index]),
        ),
        const SizedBox(height: 20),
        // Two separate cards: With Saturday and Without Saturday
        _buildSaturdayVariantCard(
          context,
          plan: selectedPlan,
          includeSaturday: true,
          isDark: isDark,
          isTrialSection: isTrialSection,
        ),
        _buildSaturdayVariantCard(
          context,
          plan: selectedPlan,
          includeSaturday: false,
          isDark: isDark,
          isTrialSection: isTrialSection,
        ),
      ],
    );
  }

  Widget _buildSaturdayVariantCard(
    BuildContext context, {
    required SubscriptionModel plan,
    required bool includeSaturday,
    required bool isDark,
    required bool isTrialSection,
  }) {
    final price = includeSaturday ? plan.priceWithSaturday : plan.priceWithoutSaturday;
    final duration = includeSaturday
        ? (plan.durationDaysWithSaturday ?? plan.durationDays)
        : (plan.durationDaysWithoutSaturday ?? plan.durationDays);
    final title = includeSaturday ? 'With Saturday Meal' : 'Without Saturday Meal';
    final subtitle = includeSaturday
        ? 'Includes Saturday deliveries'
        : 'Saturday meals excluded';
    final features = <String>[
      '$duration days included',
      if (plan.trialDays > 0) '${plan.trialDays} days free trial',
      ...plan.features,
    ];
    final mealTypeLine =
        '${isTrialSection ? 'Trial' : 'Regular'} • ${_mealVariantLabel(plan)} • ${plan.billingCycle}';

    return MealVariantCard(
      title: title,
      subtitle: subtitle,
      mealTypeLine: mealTypeLine,
      price: price,
      durationDays: duration,
      features: features,
      isDark: isDark,
      onBuy: (_selectedEntityType != null && _selectedEntityId != null)
          ? () async {
              final dateStr = await _pickStartDate(context, confirmText: 'PROCEED TO PAY');
              if (!context.mounted) return;
              if (dateStr != null) {
                _handlePayment(context, plan.id, _selectedEntityType!, _selectedEntityId!, includeSaturday, dateStr);
              }
            }
          : () => ErrorHandler.showError(context, 'Select a profile first'),
      onAddToCart: (_selectedEntityType != null && _selectedEntityId != null)
          ? () => _addToCartViaAPI(plan, _selectedEntityType!, _selectedEntityId!, includeSaturday)
          : () => ErrorHandler.showError(context, 'Select a profile first'),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(CupertinoIcons.back),
        onPressed: () {
          if (_step == 1) {
            setState(() => _step = 0);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'Buuttii Premium',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildFAQSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 16),
        _buildFAQItem('Can I cancel anytime?', 'Yes, you can cancel your subscription at any time from the settings.'),
        _buildFAQItem('Is there a free trial?', 'Yes, trial plans come with a free trial period.'),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSaturdayOptionSheet(
    BuildContext context,
    SubscriptionModel plan,
    String entityType,
    String entityId, {
    bool isBuyNow = false,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Plan Variant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            _buildVariantTile(ctx, plan, includeSaturday: true, isDark: isDark, isBuyNow: isBuyNow, entityType: entityType, entityId: entityId),
            const SizedBox(height: 10),
            _buildVariantTile(ctx, plan, includeSaturday: false, isDark: isDark, isBuyNow: isBuyNow, entityType: entityType, entityId: entityId),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantTile(
    BuildContext sheetContext,
    SubscriptionModel plan, {
    required bool includeSaturday,
    required bool isDark,
    required bool isBuyNow,
    required String entityType,
    required String entityId,
  }) {
    final price = includeSaturday ? plan.priceWithSaturday : plan.priceWithoutSaturday;
    final title = includeSaturday ? 'With Saturday' : 'Without Saturday';
    final subtitle = includeSaturday
        ? 'Meals include Saturdays'
        : 'Saturday meals excluded';
    return InkWell(
      onTap: () async {
        Navigator.pop(sheetContext);
        if (isBuyNow) {
          final dateStr = await _pickStartDate(context, confirmText: 'PROCEED TO PAY');
          if (!mounted) return;
          if (dateStr != null) {
            _handlePayment(context, plan.id, entityType, entityId, includeSaturday, dateStr);
          }
          return;
        }
        _addToCartViaAPI(plan, entityType, entityId, includeSaturday);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.calendar, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
                ],
              ),
            ),
            Text('₹$price', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment(
    BuildContext context,
    String planId,
    String entityType,
    String entityId,
    bool includeSaturday,
    String startDate,
  ) async {
    final paymentProvider = context.read<PaymentProvider>();
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(20)),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [CupertinoActivityIndicator(radius: 14), SizedBox(height: 16), Text('Preparing Payment...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))]),
        ),
      ),
    );

    final result = await paymentProvider.initiateCheckout(
      subscriptionId: planId,
      entityType: entityType,
      entityId: entityId,
      includeSaturday: includeSaturday,
      startDate: startDate,
      isSandbox: true,
    );
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) return;

    if (result != null) {
      final String sdkStatus = result['sdkStatus'] as String? ?? 'FAILURE';
      final String txnId = result['merchantTransactionId'] as String? ?? '';
      final String orderId = result['orderId'] as String? ?? '';
      if (sdkStatus == 'SUCCESS' || sdkStatus == 'INTERRUPTED') {
        Navigator.push(context, CupertinoPageRoute(builder: (context) => PaymentStatusScreen(txnId: txnId, orderId: orderId)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Payment failed or was cancelled.'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    } else if (paymentProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(paymentProvider.error!), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }
}

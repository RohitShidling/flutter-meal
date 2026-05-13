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
import 'package:meal_app/features/profile/ui/screens/teacher_profile_screen.dart';
import 'package:meal_app/features/profile/ui/screens/professional_profile_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/cart_screen.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/utils/subscription_status_normalize.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/services/connectivity_service.dart';
import 'package:meal_app/core/widgets/badges/subscription_badge.dart';
import 'package:meal_app/features/subscription/ui/widgets/meal_size_segmented_control.dart';
import 'package:meal_app/core/widgets/app_skeleton.dart';

class _RecipientPick {
  final String entityType;
  final String entityId;
  final String name;

  const _RecipientPick({required this.entityType, required this.entityId, required this.name});
}

class SubscriptionScreen extends StatefulWidget {
  /// When set with [initialEntityId], pre-fills the buyer profile (and optionally opens plan step).
  final String? initialEntityType;
  final String? initialEntityId;
  final String? initialEntityName;
  final int? initialMealSizeId;
  final bool openPlansStep;

  const SubscriptionScreen({
    super.key,
    this.initialEntityType,
    this.initialEntityId,
    this.initialEntityName,
    this.initialMealSizeId,
    this.openPlansStep = false,
  });

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
  ConnectivityService? _connectivityService;
  bool _wasOnline = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final w = widget;
      setState(() {
        if ((w.initialEntityType ?? '').isNotEmpty && (w.initialEntityId ?? '').isNotEmpty) {
          _selectedEntityType = w.initialEntityType;
          _selectedEntityId = w.initialEntityId;
          _selectedEntityName = w.initialEntityName;
          _selectedMealSizeId = w.initialMealSizeId;
        }
        if (w.openPlansStep) _step = 1;
      });
      context.read<SubscriptionProvider>().fetchSubscriptions(silent: true);
      context.read<ChildrenProvider>().fetchChildren(silent: true);
      context.read<ProfileProvider>().fetchProfiles(silent: true);
      context.read<CartProvider>().fetchCart(silent: true);
      context.read<MealProvider>().fetchSubscriptionStatus(silent: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<ConnectivityService>();
    if (_connectivityService == service) return;
    _connectivityService?.removeListener(_handleConnectivityChange);
    _connectivityService = service;
    _wasOnline = _connectivityService?.isOnline ?? true;
    _connectivityService?.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    _connectivityService?.removeListener(_handleConnectivityChange);
    super.dispose();
  }

  Future<void> _handleConnectivityChange() async {
    final online = _connectivityService?.isOnline ?? true;
    if (online && !_wasOnline && mounted) {
      await Future.wait([
        context.read<SubscriptionProvider>().fetchSubscriptions(force: true),
        context.read<ChildrenProvider>().fetchChildren(),
        context.read<ProfileProvider>().fetchProfiles(force: true),
      ]);
      await context.read<CartProvider>().syncOfflineItemsIfAny();
      await context.read<MealProvider>().fetchSubscriptionStatus(silent: true);
    }
    _wasOnline = online;
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
    if (currentIso != null && currentIso.length >= 10) {
      final p = MealDate.parseOrTomorrow(currentIso.substring(0, 10));
      if (!p.isBefore(first)) initial = p;
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

    final safeChildren = childrenProvider.children.where((c) => (c.id ?? '').toString().isNotEmpty).toList();
    final teacher = profileProvider.teacherProfile;
    final professional = profileProvider.professionalProfile;
    final hasTeacher = teacher != null && (teacher.id ?? '').toString().isNotEmpty;
    final hasProfessional = professional != null && (professional.id ?? '').toString().isNotEmpty;
    final showEntitySkeleton = safeChildren.isEmpty &&
        !hasTeacher &&
        !hasProfessional &&
        (childrenProvider.isLoading || profileProvider.isLoading || profileProvider.isFetchingProfiles);

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

        if (showEntitySkeleton) ...[
          EntityUpgradeCardSkeleton(isDark: isDark),
          EntityUpgradeCardSkeleton(isDark: isDark),
        ] else ...[
          if (safeChildren.isNotEmpty) ...[
            const Text('CHILDREN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
            const SizedBox(height: 12),
            ...safeChildren.map((child) => _buildEntityCard(
              context,
              entityType: 'child',
              entityId: child.id!.toString(),
              name: child.name,
              subtitle: 'Child • ${child.mealSizeName ?? 'Standard'}',
              icon: CupertinoIcons.person_3_fill,
              color: Colors.blue,
              isDark: isDark,
              mealSizeId: child.mealSizeId,
              isInCart: cartProvider.hasItemsForEntity('child', child.id!.toString()),
            )),
            const SizedBox(height: 20),
          ],
          if (hasTeacher || hasProfessional) ...[
            const Text('OTHER PROFILES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
            const SizedBox(height: 12),
          ],
          if (hasTeacher)
            _buildEntityCard(
              context,
              entityType: 'teacher',
              entityId: teacher.id.toString(),
              name: teacher.name,
              subtitle: 'Teacher Profile • Large Pack',
              icon: CupertinoIcons.book_fill,
              color: Colors.green,
              isDark: isDark,
              mealSizeId: teacher.mealSizeId,
              isInCart: cartProvider.hasItemsForEntity('teacher', teacher.id.toString()),
            ),
          if (hasProfessional)
            _buildEntityCard(
              context,
              entityType: 'professional',
              entityId: professional.id.toString(),
              name: professional.name,
              subtitle: 'Pro Profile • Large Pack',
              icon: CupertinoIcons.briefcase_fill,
              color: Colors.orange,
              isDark: isDark,
              mealSizeId: professional.mealSizeId,
              isInCart: cartProvider.hasItemsForEntity('professional', professional.id.toString()),
            ),
          if (safeChildren.isEmpty && !hasTeacher && !hasProfessional)
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
                      backgroundColor: isInCart ? const Color(0xFF16A34A) : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF16A34A),
                      disabledForegroundColor: Colors.white,
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
    final state = SubscriptionStatusNormalizer.entityPlanState(statusData, entityType, entityId);
    if (state == 'none') return const SizedBox.shrink();
    if (state == 'upcoming') {
      return const SubscriptionBadge(
        icon: CupertinoIcons.clock_fill,
        color: Color(0xFFEAB308),
        size: 18,
      );
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
      _showSaturdayOptionSheet(context, plans.first, entityType, entityId, entityDisplayName: name);
      return;
    }

    _showPlanPickerSheet(context, plans, entityType, entityId, name);
  }

  bool _entityMealSizeMatchesPlan(SubscriptionModel plan, int? entityMealSizeId) {
    final pid = plan.mealSizeId;
    if (pid == null) return true;
    if (entityMealSizeId == null) return false;
    return entityMealSizeId == pid;
  }

  List<_RecipientPick> _recipientChoicesForPlan(SubscriptionModel plan) {
    final childrenProvider = context.read<ChildrenProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final out = <_RecipientPick>[];
    for (final c in childrenProvider.children.where((x) => (x.id ?? '').toString().isNotEmpty)) {
      if (_entityMealSizeMatchesPlan(plan, c.mealSizeId)) {
        out.add(_RecipientPick(entityType: 'child', entityId: c.id!, name: c.name));
      }
    }
    final teacher = profileProvider.teacherProfile;
    if (teacher != null && (teacher.id ?? '').toString().isNotEmpty) {
      if (_entityMealSizeMatchesPlan(plan, teacher.mealSizeId)) {
        out.add(_RecipientPick(entityType: 'teacher', entityId: teacher.id.toString(), name: teacher.name));
      }
    }
    final professional = profileProvider.professionalProfile;
    if (professional != null && (professional.id ?? '').toString().isNotEmpty) {
      if (_entityMealSizeMatchesPlan(plan, professional.mealSizeId)) {
        out.add(_RecipientPick(entityType: 'professional', entityId: professional.id.toString(), name: professional.name));
      }
    }
    return out;
  }

  Future<_RecipientPick?> _pickRecipientForPlanSheet(SubscriptionModel plan) async {
    final options = _recipientChoicesForPlan(plan);
    if (options.isEmpty) {
      final label = _mealVariantLabel(plan);
      ErrorHandler.showError(
        context,
        'No profile with the $label meal size this plan needs. Update a child, teacher, or professional profile, then try Add to cart again.',
      );
      return null;
    }
    final label = _mealVariantLabel(plan);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<_RecipientPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                ),
                const SizedBox(height: 6),
                Text(
                  'Only profiles that match this $label plan are listed.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                ),
                const SizedBox(height: 14),
                ...options.map((o) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(ctx, o),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.surfaceDark : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              o.entityType == 'child'
                                  ? CupertinoIcons.person_3_fill
                                  : o.entityType == 'teacher'
                                      ? CupertinoIcons.book_fill
                                      : CupertinoIcons.briefcase_fill,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                    ),
                                  ),
                                  Text(
                                    o.entityType.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white38 : AppTheme.textSecondaryLight,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Add to cart via backend API — user picks start date (same as Buy Now).
  Future<void> _addToCartViaAPI(
    SubscriptionModel plan,
    String entityType,
    String entityId,
    bool includeSaturday, {
    String? entityDisplayName,
  }) async {
    // Default to tomorrow — user can change start date from the cart screen
    final startDate = MealDate.tomorrowYmd();

    final cartProvider = context.read<CartProvider>();
    final success = await cartProvider.addItem(
      subscriptionId: plan.id,
      entityType: entityType,
      entityId: entityId,
      includeSaturday: includeSaturday,
      startDate: startDate,
      entityName: entityDisplayName ?? _selectedEntityName ?? entityType,
      planName: plan.planName,
      unitPrice: double.tryParse(
            includeSaturday ? plan.priceWithSaturday : plan.priceWithoutSaturday,
          ) ??
          0,
      mealSizeId: plan.mealSizeId,
      mealSizeName: _selectedMealSizeId != null ? 'Selected meal size' : null,
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
            ...plans.map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSaturdayOptionSheet(context, plan, entityType, entityId, entityDisplayName: name);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
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
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSelectionView() {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    // Show the full catalog for everyone; meal size on the profile only affects
    // which size is pre-selected in segment controls, not which plans are visible.
    final availablePlans = List<SubscriptionModel>.from(subscriptionProvider.subscriptions)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trialPlans = availablePlans.where((p) => p.trialDays > 0).toList();
    final paidPlans = availablePlans.where((p) => p.trialDays == 0).toList();
    final hasTrial = trialPlans.isNotEmpty;
    final hasPaid = paidPlans.isNotEmpty;

    final plansLoading = availablePlans.isEmpty &&
        (subscriptionProvider.isLoading || subscriptionProvider.isFetchingSubscriptions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subscription plans',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 12),
        _buildPlanRecipientSelector(isDark),
        if (_selectedEntityId != null) const SizedBox(height: 10),
        Text(
          'Pick a plan, then use Buy now or Add to cart — you will choose who it is for in the next step.',
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 24),

        if (plansLoading)
          PlanCatalogSkeleton(isDark: isDark)
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
              profileMealSizeId: _selectedMealSizeId,
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
              profileMealSizeId: _selectedMealSizeId,
            ),
            const SizedBox(height: 32),
          ],
        ],

        _buildFAQSection(),
      ],
    );
  }

  Future<void> _showChangeProfileSheet() async {
    final childrenProvider = context.read<ChildrenProvider>();
    final profileProvider = context.read<ProfileProvider>();
    await childrenProvider.fetchChildren(silent: true);
    await profileProvider.fetchProfiles(silent: true);
    if (!mounted) return;

    final safeChildren = childrenProvider.children.where((c) => (c.id ?? '').toString().isNotEmpty).toList();
    final teacher = profileProvider.teacherProfile;
    final professional = profileProvider.professionalProfile;
    final hasTeacher = teacher != null && (teacher.id ?? '').toString().isNotEmpty;
    final hasProfessional = professional != null && (professional.id ?? '').toString().isNotEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'Choose profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        if (safeChildren.isNotEmpty) ...[
                          Text('CHILDREN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.grey)),
                          const SizedBox(height: 8),
                          ...safeChildren.map((c) {
                            return ListTile(
                              leading: const Icon(CupertinoIcons.person_3_fill, color: Colors.blue),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text('Child • ${c.mealSizeName ?? 'Standard'}', style: const TextStyle(fontSize: 12)),
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedEntityType = 'child';
                                  _selectedEntityId = c.id!;
                                  _selectedEntityName = c.name;
                                  _selectedMealSizeId = c.mealSizeId;
                                });
                              },
                            );
                          }),
                          const SizedBox(height: 12),
                        ],
                        if (hasTeacher || hasProfessional) ...[
                          Text('OTHER PROFILES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.grey)),
                          const SizedBox(height: 8),
                        ],
                        if (hasTeacher)
                          ListTile(
                            leading: const Icon(CupertinoIcons.book_fill, color: Colors.green),
                            title: Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: const Text('Teacher profile', style: TextStyle(fontSize: 12)),
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedEntityType = 'teacher';
                                _selectedEntityId = teacher.id.toString();
                                _selectedEntityName = teacher.name;
                                _selectedMealSizeId = teacher.mealSizeId;
                              });
                            },
                          ),
                        if (hasProfessional)
                          ListTile(
                            leading: const Icon(CupertinoIcons.briefcase_fill, color: Colors.orange),
                            title: Text(professional.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: const Text('Professional profile', style: TextStyle(fontSize: 12)),
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedEntityType = 'professional';
                                _selectedEntityId = professional.id.toString();
                                _selectedEntityName = professional.name;
                                _selectedMealSizeId = professional.mealSizeId;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlanRecipientSelector(bool isDark) {
    if (_selectedEntityId != null && (_selectedEntityName ?? '').isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.person_crop_circle_fill, color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buying for',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                      ),
                      Text(
                        _selectedEntityName!,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _showChangeProfileSheet,
                icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
                label: const Text('Change profile', style: TextStyle(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _mealVariantLabel(SubscriptionModel plan) {
    final name = plan.planName.trim();
    if (name.isEmpty) return 'Plan';
    final raw = name.toLowerCase();
    if (raw.contains('small')) return 'Small';
    if (raw.contains('medium')) return 'Medium';
    if (raw.contains('large')) return 'Large';
    return name;
  }

  Widget _buildPlanSection({
    required List<SubscriptionModel> plans,
    required int? selectedMealSizeId,
    required ValueChanged<int?> onSelectMealSize,
    required bool isTrialSection,
    int? profileMealSizeId,
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

    // Default selection — prefer profile meal size when it matches a plan tab.
    if (selectedMealSizeId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        int? pick;
        if (profileMealSizeId != null && mealSizeIds.contains(profileMealSizeId)) {
          pick = profileMealSizeId;
        } else {
          pick = mealSizeIds.first;
        }
        onSelectMealSize(pick);
      });
    }

    final activeMealSizeId = selectedMealSizeId ?? mealSizeIds.first;
    final selectedPlan = sorted.firstWhere(
      (p) => p.mealSizeId == activeMealSizeId,
      orElse: () => sorted.first,
    );

    final selectedIndex = mealSizeIds.indexOf(activeMealSizeId).clamp(0, mealSizeIds.length - 1);

    final eligibleRecipients = _recipientChoicesForPlan(selectedPlan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MealSizeSegmentedControlWrap(
          options: mealSizeLabels,
          selectedIndex: selectedIndex,
          onChanged: (index) => onSelectMealSize(mealSizeIds[index]),
        ),
        const SizedBox(height: 20),
        if (eligibleRecipients.isEmpty)
          _buildNoMatchingProfilesForPlanBanner(isDark, selectedPlan, isTrialSection: isTrialSection)
        else ...[
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
      ],
    );
  }

  Widget _buildNoMatchingProfilesForPlanBanner(
    bool isDark,
    SubscriptionModel plan, {
    required bool isTrialSection,
  }) {
    final label = _mealVariantLabel(plan);
    final section = isTrialSection ? 'trial' : 'regular';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.person_crop_circle_badge_exclam, color: Colors.orange.shade800, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No profile for this $label plan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You do not have any saved profile with the $label meal size required for this $section plan. '
            'Update a child, teacher, or professional profile so the meal size matches — then you can use Buy now or Add to cart.',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.push(context, CupertinoPageRoute(builder: (_) => const ChildrenManagementScreen()));
                },
                child: const Text('Children', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(context, CupertinoPageRoute(builder: (_) => const TeacherProfileScreen()));
                },
                child: const Text('Teacher', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(context, CupertinoPageRoute(builder: (_) => const ProfessionalProfileScreen()));
                },
                child: const Text('Professional', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('Back to profiles', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
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
      if (plan.trialDays > 0) '${plan.trialDays} days trial window',
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
      onBuy: () => _onPlanBuyTapped(plan, includeSaturday),
      onAddToCart: () => _onPlanAddToCartTapped(plan, includeSaturday),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0);
  }

  Future<void> _onPlanBuyTapped(SubscriptionModel plan, bool includeSaturday) async {
    late final String entityType;
    late final String entityId;
    if (_selectedEntityType != null && _selectedEntityId != null) {
      entityType = _selectedEntityType!;
      entityId = _selectedEntityId!;
    } else {
      final pick = await _pickRecipientForPlanSheet(plan);
      if (!mounted || pick == null) return;
      entityType = pick.entityType;
      entityId = pick.entityId;
    }
    final dateStr = await _pickStartDate(context, confirmText: 'PROCEED TO PAY');
    if (!mounted) return;
    if (dateStr != null) {
      _handlePayment(context, plan.id, entityType, entityId, includeSaturday, dateStr);
    }
  }

  Future<void> _onPlanAddToCartTapped(SubscriptionModel plan, bool includeSaturday) async {
    late final String entityType;
    late final String entityId;
    String? displayName = _selectedEntityName;
    if (_selectedEntityType != null && _selectedEntityId != null) {
      entityType = _selectedEntityType!;
      entityId = _selectedEntityId!;
    } else {
      final pick = await _pickRecipientForPlanSheet(plan);
      if (!mounted || pick == null) return;
      entityType = pick.entityType;
      entityId = pick.entityId;
      displayName = pick.name;
    }
    await _addToCartViaAPI(plan, entityType, entityId, includeSaturday, entityDisplayName: displayName);
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
    String? entityDisplayName,
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
            _buildVariantTile(ctx, plan, includeSaturday: true, isDark: isDark, isBuyNow: isBuyNow, entityType: entityType, entityId: entityId, entityDisplayName: entityDisplayName),
            const SizedBox(height: 10),
            _buildVariantTile(ctx, plan, includeSaturday: false, isDark: isDark, isBuyNow: isBuyNow, entityType: entityType, entityId: entityId, entityDisplayName: entityDisplayName),
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
    String? entityDisplayName,
  }) {
    final price = includeSaturday ? plan.priceWithSaturday : plan.priceWithoutSaturday;
    final title = includeSaturday ? 'With Saturday' : 'Without Saturday';
    final subtitle = includeSaturday
        ? 'Meals include Saturdays'
        : 'Saturday meals excluded';
    final fill = isDark ? AppTheme.surfaceDark : Colors.grey.shade50;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
          await _addToCartViaAPI(
            plan,
            entityType,
            entityId,
            includeSaturday,
            entityDisplayName: entityDisplayName ?? _selectedEntityName,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
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
              if (!isBuyNow)
                Builder(
                  builder: (ctx) {
                    final inCart = ctx.watch<CartProvider>().hasExactCartItem(
                      entityType: entityType,
                      entityId: entityId,
                      subscriptionId: plan.id,
                      includeSaturday: includeSaturday,
                    );
                    if (!inCart) return const SizedBox(width: 6);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'In cart',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade700,
                        ),
                      ),
                    );
                  },
                ),
              Text('₹$price', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
            ],
          ),
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
      ErrorHandler.showError(context, paymentProvider.error);
    }
  }
}

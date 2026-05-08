import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/children/ui/screens/children_management_screen.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/cart_screen.dart';
import 'package:meal_app/core/utils/error_handler.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchSubscriptions(force: true);
      context.read<ChildrenProvider>().fetchChildren();
      context.read<ProfileProvider>().fetchProfiles(force: true);
      context.read<CartProvider>().fetchCart(); // Fetch server cart
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
            context.read<ChildrenProvider>().fetchChildren(),
            context.read<ProfileProvider>().fetchProfiles(force: true),
            context.read<CartProvider>().fetchCart(),
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
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 12),
        Text(
          'Who are you buying this subscription for?',
          style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
        ).animate().fadeIn(delay: 200.ms),
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
            subtitle: 'Professional Profile • Large Pack',
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
                      Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                      Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSecondaryLight, fontSize: 12)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Choose Your Plan',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          'For ${_selectedEntityName ?? 'profile'}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock premium meal tracking.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 32),
        
        if (subscriptionProvider.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (availablePlans.isEmpty)
          const Text('No subscription plans available for this profile type.')
        else
          ...availablePlans.map((plan) => _buildPlanCard(context, plan)),
        
        const SizedBox(height: 40),
        _buildFAQSection(),
      ],
    );
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

  Widget _buildPlanCard(BuildContext context, SubscriptionModel plan) {
    final isPremium = plan.planName.toLowerCase().contains('pro') || plan.planName.toLowerCase().contains('premium');
    
    return AppleCard(
      color: isPremium ? AppTheme.primaryColor : null,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('MOST POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  plan.planName,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isPremium ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimaryLight)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${plan.priceWithSaturday}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isPremium ? Colors.white : AppTheme.primaryColor),
                  ),
                  Text(
                    '₹${plan.priceWithoutSaturday} (No Sat)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPremium ? Colors.white70 : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : AppTheme.textSecondaryLight),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '${plan.billingCycle} • ${plan.durationDays} days',
            style: TextStyle(fontSize: 14, color: isPremium ? Colors.white70 : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : AppTheme.textSecondaryLight)),
          ),
          const SizedBox(height: 20),
          ...(plan.features.isNotEmpty
              ? plan.features.map((feature) => _buildFeatureRow(feature, isPremium))
              : [_buildFeatureRow('${plan.durationDays} days meal plan', isPremium)]),
          if (plan.trialDays > 0) _buildFeatureRow('${plan.trialDays} Days Free Trial', isPremium),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showSaturdayOptionSheet(context, plan, _selectedEntityType!, _selectedEntityId!, isBuyNow: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? Colors.white : AppTheme.primaryColor,
              foregroundColor: isPremium ? AppTheme.primaryColor : Colors.white,
              minimumSize: const Size(double.infinity, 56),
              elevation: 0,
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.creditcard, size: 18), SizedBox(width: 8), Text('Buy Now', style: TextStyle(fontWeight: FontWeight.w800))]),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              _showSaturdayOptionSheet(context, plan, _selectedEntityType!, _selectedEntityId!);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: isPremium ? Colors.white : AppTheme.primaryColor,
              side: BorderSide(color: isPremium ? Colors.white54 : AppTheme.primaryColor),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.cart_badge_plus, size: 18), SizedBox(width: 8), Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.w700))]),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildFeatureRow(String text, bool isPremium) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(CupertinoIcons.checkmark_circle_fill, color: isPremium ? Colors.white70 : AppTheme.primaryColor, size: 18),
          const SizedBox(width: 12),
          Flexible(
            child: Text(text, style: TextStyle(color: isPremium ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimaryLight), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Frequently Asked Questions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _buildFAQItem('Can I cancel anytime?', 'Yes, you can cancel your subscription at any time from the settings.'),
        _buildFAQItem('Is there a free trial?', 'Yes, all plans come with a free trial period.'),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimaryLight)),
          const SizedBox(height: 4),
          Text(answer, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : AppTheme.textSecondaryLight)),
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

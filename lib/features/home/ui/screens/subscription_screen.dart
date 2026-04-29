import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchSubscriptions(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<SubscriptionProvider>().fetchSubscriptions(force: true);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Choose Your Plan',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 12),
                  const Text(
                    'Unlock premium features and professional meal tracking for your family.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondaryLight,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 40),
                  
                  if (subscriptionProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (subscriptionProvider.subscriptions.isEmpty)
                    const Text('No subscription plans available.')
                  else
                    ...subscriptionProvider.subscriptions.map((plan) => _buildPlanCard(context, plan)),
                  
                  const SizedBox(height: 40),
                  _buildFAQSection(),
                ],
              ),
            ),
          ),
        ],
      ),
     ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(CupertinoIcons.back),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'Buuttii Pro Premium',
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
              child: const Text(
                'MOST POPULAR',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.planName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isPremium ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              Text(
                '₹${plan.price}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isPremium ? Colors.white : AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          Text(
            plan.billingCycle,
            style: TextStyle(
              fontSize: 14,
              color: isPremium ? Colors.white70 : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),
          _buildFeatureRow('Family Meal Tracking', isPremium),
          _buildFeatureRow('Priority Support', isPremium),
          _buildFeatureRow('${plan.trialDays} Days Free Trial', isPremium),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showSelectionSheet(context, plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? Colors.white : AppTheme.primaryColor,
              foregroundColor: isPremium ? AppTheme.primaryColor : Colors.white,
              minimumSize: const Size(double.infinity, 56),
              elevation: 0,
            ),
            child: const Text('Subscribe Now'),
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
          Icon(
            CupertinoIcons.checkmark_circle_fill, 
            color: isPremium ? Colors.white70 : AppTheme.primaryColor, 
            size: 18
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isPremium ? Colors.white : AppTheme.textPrimaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
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
          Text(question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(answer, style: const TextStyle(color: AppTheme.textSecondaryLight)),
        ],
      ),
    );
  }

  void _showSelectionSheet(BuildContext context, SubscriptionModel plan) {
    final childrenProvider = context.read<ChildrenProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Profile to Upgrade',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Upgrading for ${plan.planName} (₹${plan.price})',
                style: const TextStyle(color: AppTheme.textSecondaryLight),
              ),
              const SizedBox(height: 24),
              
              // Children List
              if (childrenProvider.children.isNotEmpty) ...[
                const Text('CHILDREN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
                const SizedBox(height: 12),
                ...childrenProvider.children.map((child) => _buildSelectionItem(
                  context, 
                  'child', 
                  child.id!, 
                  child.name, 
                  'Child - ${child.rollNumber}', 
                  plan,
                  isDark
                )),
                const SizedBox(height: 20),
              ],

              // Profiles
              const Text('OTHER PROFILES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
              const SizedBox(height: 12),
              if (profileProvider.teacherProfile != null)
                _buildSelectionItem(
                  context, 
                  'teacher', 
                  profileProvider.teacherProfile!.id!, 
                  profileProvider.teacherProfile!.name, 
                  'Teacher Profile', 
                  plan,
                  isDark
                ),
              if (profileProvider.professionalProfile != null)
                _buildSelectionItem(
                  context, 
                  'professional', 
                  profileProvider.professionalProfile!.id!, 
                  profileProvider.professionalProfile!.name, 
                  'Professional Profile', 
                  plan,
                  isDark
                ),
              
              if (childrenProvider.children.isEmpty && profileProvider.teacherProfile == null && profileProvider.professionalProfile == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No active profiles found to upgrade.')),
                ),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionItem(
    BuildContext context, 
    String entityType, 
    String entityId, 
    String name, 
    String subtitle, 
    SubscriptionModel plan,
    bool isDark
  ) {
    return AppleCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () async {
        Navigator.pop(context); // Close sheet
        _handlePayment(context, plan.id!, entityType, entityId);
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(CupertinoIcons.person_solid, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondaryLight, fontSize: 12)),
              ],
            ),
          ),
          const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Future<void> _handlePayment(
    BuildContext context,
    String planId,
    String entityType,
    String entityId,
  ) async {
    final paymentProvider = context.read<PaymentProvider>();

    // Show a loading dialog while we create the order & initialize the SDK
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(radius: 14),
              SizedBox(height: 16),
              Text(
                'Preparing Payment...',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );

    // initiateCheckout calls backend, then drives the PhonePe SDK natively.
    // The SDK opens PhonePe app / payment page and blocks until user finishes.
    final result = await paymentProvider.initiateCheckout(
      subscriptionId: planId,
      entityType: entityType,
      entityId: entityId,
      isSandbox: true, // change to false for production
    );

    // Close the loading dialog
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;

    if (result != null) {
      final String sdkStatus = result['sdkStatus'] as String? ?? 'FAILURE';
      final String txnId = result['merchantTransactionId'] as String? ?? '';
      final String orderId = result['orderId'] as String? ?? '';

      if (sdkStatus == 'SUCCESS' || sdkStatus == 'INTERRUPTED') {
        // SUCCESS: payment went through → verify with backend
        // INTERRUPTED: user may have completed on the bank page → verify too
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => PaymentStatusScreen(
              txnId: txnId,
              orderId: orderId,
            ),
          ),
        );
      } else {
        // FAILURE: show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment failed or was cancelled.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else if (paymentProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paymentProvider.error!),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

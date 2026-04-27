import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/widgets/apple_card.dart';

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
      context.read<SubscriptionProvider>().fetchSubscriptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();

    return Scaffold(
      body: CustomScrollView(
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
            onPressed: () {},
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
}

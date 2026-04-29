import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/widgets/apple_card.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().fetchActiveSubscriptions();
      context.read<PaymentProvider>().fetchPaymentHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = context.watch<PaymentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions & Payments', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Active Plans'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivePlans(paymentProvider, isDark),
          _buildHistory(paymentProvider, isDark),
        ],
      ),
    );
  }

  Widget _buildActivePlans(PaymentProvider provider, bool isDark) {
    if (provider.isLoading) return const Center(child: CupertinoActivityIndicator());
    if (provider.activeSubscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.creditcard, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('No active subscriptions found.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.activeSubscriptions.length,
      itemBuilder: (context, index) {
        final sub = provider.activeSubscriptions[index];
        final expiry = DateTime.parse(sub['expiry_date']);
        
        return AppleCard(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      sub['plan_name']?.toUpperCase() ?? 'PLAN',
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.green, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                sub['entity_name'] ?? 'Profile',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Expires on: ${DateFormat('dd MMM yyyy').format(expiry)}',
                style: const TextStyle(color: AppTheme.textSecondaryLight, fontSize: 13),
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    sub['status']?.toUpperCase() ?? 'ACTIVE',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistory(PaymentProvider provider, bool isDark) {
    if (provider.isLoading) return const Center(child: CupertinoActivityIndicator());
    if (provider.paymentHistory.isEmpty) {
      return const Center(child: Text('No payment history found.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.paymentHistory.length,
      itemBuilder: (context, index) {
        final payment = provider.paymentHistory[index];
        final date = DateTime.parse(payment['created_at']);
        final isSuccess = payment['status'] == 'COMPLETED' || payment['status'] == 'SUCCESS';

        return AppleCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSuccess ? CupertinoIcons.checkmark_alt : CupertinoIcons.xmark,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 20
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment['plan_name'] ?? 'Subscription',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(date),
                      style: const TextStyle(color: AppTheme.textSecondaryLight, fontSize: 12)
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${payment['amount']}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)
                  ),
                  Text(
                    payment['status'] ?? 'PENDING',
                    style: TextStyle(
                      color: isSuccess ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 10
                    )
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

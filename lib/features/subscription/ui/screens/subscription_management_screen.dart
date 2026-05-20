import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/core/services/connectivity_service.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/core/utils/upgrade_payment_history.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ConnectivityService? _connectivityService;
  bool _wasOnline = true;

  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.subscriptionManagement);
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.wait([
        context.read<PaymentProvider>().fetchActiveSubscriptions(),
        context.read<PaymentProvider>().fetchPaymentHistory(silent: true),
        context.read<MealProvider>().fetchSubscriptionStatus(silent: true),
      ]);
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
    AppRouteTracker.instance.clearIfCurrent(AppScreen.subscriptionManagement);
    _connectivityService?.removeListener(_handleConnectivityChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleConnectivityChange() async {
    final online = _connectivityService?.isOnline ?? true;
    if (online && !_wasOnline && mounted) {
      await Future.wait([
        context.read<PaymentProvider>().fetchActiveSubscriptions(),
        context.read<PaymentProvider>().fetchPaymentHistory(),
      ]);
    }
    _wasOnline = online;
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = context.watch<PaymentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Subscriptions & Payments',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
          ),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
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
    // Show spinner only on first load with no cached data
    if (provider.isLoading && provider.activeSubscriptions.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // If error but we have cached data, show cached data with a small banner
    if (provider.error != null && provider.activeSubscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orange.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              'Could not load subscriptions',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => provider.fetchActiveSubscriptions(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.activeSubscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.creditcard, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No active subscriptions found.',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            ),
          ],
        ),
      );
    }

    final sessionToday = MealDate.parseYmdLocal(MealDate.sessionTodayYmd());
    final sortedSubs = [...provider.activeSubscriptions];
    sortedSubs.sort((a, b) {
      final aStart = MealDate.parseYmdLocal(a['start_date']?.toString());
      final bStart = MealDate.parseYmdLocal(b['start_date']?.toString());
      final aUpcoming = sessionToday != null && aStart != null && aStart.isAfter(sessionToday);
      final bUpcoming = sessionToday != null && bStart != null && bStart.isAfter(sessionToday);
      if (aUpcoming != bUpcoming) return aUpcoming ? -1 : 1;
      final aStartStr = a['start_date']?.toString() ?? '';
      final bStartStr = b['start_date']?.toString() ?? '';
      return aStartStr.compareTo(bStartStr);
    });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: sortedSubs.length,
      itemBuilder: (context, index) {
        final sub = sortedSubs[index];
        
        // Safe type conversion for all fields
        final planName = _safeString(sub['plan_name'], 'PLAN');
        final entityName = _safeString(sub['entity_name'], 'Profile');
        final entityType = _safeString(sub['entity_type'], '');
        final amountPaid = _safeString(sub['amount_paid'], '');
        final remainingMeals = sub['remaining_meals'];
        final includeSaturday = sub['include_saturday'] == null ? true : sub['include_saturday'] == true;
        final mealSizeName = _safeString(sub['meal_size_name'], '');
        final mealTimingRaw = _safeString(sub['meal_timing'], '');
        final mealTiming = mealTimingRaw.isEmpty ? '' : TimeUtils.formatToDisplay(mealTimingRaw);
        final startDateStr = _safeString(sub['start_date'], '');
        final startDate = startDateStr.isNotEmpty ? MealDate.parseYmdLocal(startDateStr) : null;

        final expiryStr = _safeString(sub['end_date'] ?? sub['expiry_date'], '');
        final expiry = expiryStr.isNotEmpty ? MealDate.parseYmdLocal(expiryStr) : null;
        
        return AppleCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      planName.toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: Color(0xFF22C55E),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entityName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                ),
              ),
              if (entityType.isNotEmpty)
                Text(
                  entityType.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 10),
              // Meta details — compact column of label/value pairs
              if (startDate != null)
                _buildMetaRow('Start Date', DateFormat('dd MMM yyyy').format(startDate), isDark),
              if (expiry != null)
                _buildMetaRow('Expires On', DateFormat('dd MMM yyyy').format(expiry), isDark),
              if (amountPaid.isNotEmpty)
                _buildMetaRow('Amount Paid', '₹$amountPaid', isDark),
              _buildMetaRow('Variant', includeSaturday ? 'With Saturday' : 'Without Saturday', isDark),
              if (mealSizeName.isNotEmpty)
                _buildMetaRow('Meal Size', mealSizeName, isDark),
              if (mealTiming.isNotEmpty)
                _buildMetaRow('Meal Delivery Time', mealTiming, isDark),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  Row(
                    children: [
                      if (remainingMeals != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            '${remainingMeals.toString()} meals left',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Builder(
                        builder: (context) {
                          final sessionToday = MealDate.parseYmdLocal(MealDate.sessionTodayYmd());
                          final isUpcoming = startDate != null &&
                              sessionToday != null &&
                              startDate.isAfter(sessionToday);

                          return Text(
                            (isUpcoming ? 'UPCOMING' : 'ACTIVE').toUpperCase(),
                            style: TextStyle(
                              color: isUpcoming ? const Color(0xFFEAB308) : const Color(0xFF22C55E),
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        }
                      ),
                    ],
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
    if (provider.isLoading && provider.paymentHistory.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }
    
    if (provider.error != null && provider.paymentHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orange.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              'Could not load payment history',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => provider.fetchPaymentHistory(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.paymentHistory.isEmpty) {
      return Center(
        child: Text(
          'No payment history found.',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: provider.paymentHistory.length,
      itemBuilder: (context, index) {
        final payment = provider.paymentHistory[index];
        
        // Safe type conversion — prevents "type X is not a subtype of type String"
        final isUpgrade = (payment['order_type'] ?? payment['orderType'] ?? '')
            .toString()
            .toLowerCase() ==
            'meal_size_upgrade';
        final planName = isUpgrade
            ? 'Meal size upgrade'
            : _safeString(payment['plan_name'] ?? payment['entity_name'], 'Subscription');
        final entityName = _safeString(payment['entity_name'], '');
        final amount = _safeNumString(payment['amount']);
        final pStatus = _safeString(
          payment['payment_status'] ?? payment['order_status'] ?? payment['status'],
          'PENDING',
        ).toUpperCase();
        final includeSaturday = payment['include_saturday'] == null ? true : payment['include_saturday'] == true;
        final mealSizeName = _safeString(payment['meal_size_name'], '');
        final mealTimingRaw = _safeString(payment['meal_timing'], '');
        final isSuccess = pStatus == 'COMPLETED' || pStatus == 'SUCCESS';

        final dateStr = _safeString(payment['created_at'] ?? payment['payment_date'], '');
        DateTime date = DateTime.now();
        if (dateStr.isNotEmpty) {
          date = DateTime.tryParse(dateStr) ?? DateTime.now();
        }

        return AppleCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isSuccess ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSuccess ? CupertinoIcons.checkmark_alt : CupertinoIcons.clock,
                  color: isSuccess ? Colors.green : Colors.orange,
                  size: 20
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entityName.isNotEmpty)
                      Text(
                        entityName,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      [
                        includeSaturday ? 'With Saturday' : 'Without Saturday',
                        if (mealSizeName.isNotEmpty) mealSizeName,
                        if (mealTimingRaw.isNotEmpty) TimeUtils.formatToDisplay(mealTimingRaw),
                      ].join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : AppTheme.textSecondaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(date),
                      style: TextStyle(
                        color: isDark ? Colors.white38 : AppTheme.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹$amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isSuccess ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pStatus,
                      style: TextStyle(
                        color: isSuccess ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Compact label/value row used inside the active-plan card.
  Widget _buildMetaRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Safely convert any dynamic value to String, avoiding type cast errors.
  String _safeString(dynamic value, String fallback) {
    if (value == null) return fallback;
    return value.toString();
  }

  /// Safely convert numeric amount to display string.
  String _safeNumString(dynamic value) {
    if (value == null) return '0';
    if (value is num) return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    return value.toString();
  }
}

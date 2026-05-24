import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:meal_app/core/network/api_endpoints.dart';

import 'package:meal_app/core/providers/payment_provider.dart';

import 'package:meal_app/core/theme/app_theme.dart';

import 'package:meal_app/core/utils/error_handler.dart';

import 'package:meal_app/core/utils/money_format.dart';
import 'package:meal_app/core/utils/upgrade_payment_history.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';



/// Pays a configured upgrade fee to move a recipient to a larger meal size.

class MealSizeUpgradeScreen extends StatefulWidget {

  final String? initialEntityType;

  final String? initialEntityId;

  final String? initialEntityName;



  const MealSizeUpgradeScreen({

    super.key,

    this.initialEntityType,

    this.initialEntityId,

    this.initialEntityName,

  });



  @override

  State<MealSizeUpgradeScreen> createState() => _MealSizeUpgradeScreenState();

}



class _MealSizeUpgradeScreenState extends State<MealSizeUpgradeScreen> {

  List<Map<String, dynamic>> _upgradeOptions = [];

  String? _currentSizeName;

  bool _loading = true;

  bool _loadingOptions = false;

  String? _error;



  int _selectedSubIndex = 0;

  int? _toMealSizeId;



  static String _trim(dynamic v) => (v ?? '').toString().trim();



  static int? _int(dynamic v) => int.tryParse('$v');



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());

  }



  Future<void> _load() async {

    final pay = context.read<PaymentProvider>();

    setState(() {

      _loading = true;

      _error = null;

      _toMealSizeId = null;

    });

    try {

      await Future.wait([
        pay.fetchActiveSubscriptions(),
        pay.fetchPaymentHistory(),
      ]);

      if (!mounted) return;

      var pickIndex = 0;
      final et = widget.initialEntityType?.trim() ?? '';
      final eid = widget.initialEntityId?.trim() ?? '';

      if (et.isNotEmpty && eid.isNotEmpty) {
        for (var i = 0; i < pay.activeSubscriptions.length; i++) {
          final row = pay.activeSubscriptions[i];
          if (row is! Map) continue;
          final m = Map<String, dynamic>.from(row);
          if (_trim(m['entity_type']) == et && _trim(m['entity_id']) == eid) {
            pickIndex = i;
            break;
          }
        }
      }

      final n = pay.activeSubscriptions.length;
      _selectedSubIndex = n == 0 ? 0 : pickIndex.clamp(0, n - 1);

      await _loadOptionsForSelected();

    } catch (e) {

      if (!mounted) return;

      setState(() {

        _error = ErrorHandler.getErrorMessage(e);

      });

    } finally {

      if (mounted) setState(() => _loading = false);

    }

  }



  Future<void> _loadOptionsForSelected() async {
    final pay = context.read<PaymentProvider>();
    final subs = pay.activeSubscriptions;
    if (subs.isEmpty || _selectedSubIndex >= subs.length) {
      if (mounted) {
        setState(() {
          _upgradeOptions = [];
          _currentSizeName = null;
        });
      }
      return;
    }

    final sub = subs[_selectedSubIndex];
    if (sub is! Map) return;

    setState(() => _loadingOptions = true);
    try {
      final payload = await pay.fetchMealSizeUpgradeOptionsForEntity(
        entityType: _trim(sub['entity_type']),
        entityId: _trim(sub['entity_id']),
      );
      if (!mounted) return;
      final data = (payload['data'] as List?) ?? [];
      setState(() {
        _currentSizeName = _trim(payload['current_meal_size_name']);
        _upgradeOptions = [
          for (final raw in data)
            if (raw is Map) Map<String, dynamic>.from(raw),
        ];
        _toMealSizeId = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.getErrorMessage(e);
        _upgradeOptions = [];
      });
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  List<Map<String, dynamic>> _targetOptions() {
    final out = <Map<String, dynamic>>[];
    for (final m in _upgradeOptions) {
      final t = _int(m['to_meal_size_id']);
      final toName = _trim(m['to_display_name']);
      if (t == null || toName.isEmpty) continue;
      out.add({
        'to_id': t,
        'label': toName,
        'subtitle': 'One-time upgrade fee',
        'price': MoneyFormat.display(m['price']),
      });
    }
    return out;
  }



  List<Map<String, dynamic>> _upgradeHistory(PaymentProvider pay) =>
      filterMealSizeUpgradePayments(pay.paymentHistory);

  Future<void> _pickSubscriber(List<dynamic> subs, bool isDark) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Who is upgrading?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: subs.length,
                  itemBuilder: (_, i) {
                    final sub = subs[i] as Map;
                    final name = _trim(sub['entity_name']).isNotEmpty
                        ? _trim(sub['entity_name'])
                        : widget.initialEntityName ?? 'Subscriber';
                    final plan = _trim(sub['plan_name']);
                    final selected = i == _selectedSubIndex;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                        child: Icon(CupertinoIcons.person_fill, color: AppTheme.primaryColor, size: 20),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: plan.isNotEmpty ? Text(plan) : null,
                      trailing: selected
                          ? const Icon(CupertinoIcons.checkmark_circle_fill, color: AppTheme.primaryColor)
                          : null,
                      onTap: () => Navigator.pop(ctx, i),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedSubIndex = picked);
    await _loadOptionsForSelected();
  }

  Future<void> _runPayment() async {

    final pay = context.read<PaymentProvider>();

    final subs = pay.activeSubscriptions;

    if (_toMealSizeId == null || subs.isEmpty || _selectedSubIndex >= subs.length) return;



    final sub = subs[_selectedSubIndex];

    if (sub is! Map) return;



    final et = _trim(sub['entity_type']);

    final eid = _trim(sub['entity_id']);



    final res = await pay.initiateMealSizeUpgrade(

      entityType: et,

      entityId: eid,

      toMealSizeId: _toMealSizeId!,

      isSandbox: ApiEndpoints.isSandboxPayment,

    );



    if (!mounted) return;



    if (pay.error != null && res == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pay.error!)));
      return;
    }

    final sdkStatus = res?['sdkStatus']?.toString() ?? 'FAILURE';
    final txnId = res?['merchantTransactionId']?.toString() ?? pay.lastTxnId ?? '';
    final orderId = res?['orderId']?.toString() ?? '';

    if (sdkStatus == 'SUCCESS' || sdkStatus == 'INTERRUPTED') {
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (_) => PaymentStatusScreen(
            txnId: txnId,
            orderId: orderId,
            orderType: 'meal_size_upgrade',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment did not complete. You can retry when ready.')),
    );
  }



  @override

  Widget build(BuildContext context) {

    final pay = context.watch<PaymentProvider>();

    final subs = pay.activeSubscriptions;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final history = _upgradeHistory(pay);



    Map<String, dynamic>? selectedMap;

    if (subs.isNotEmpty && subs[_selectedSubIndex.clamp(0, subs.length - 1)] is Map) {

      selectedMap = Map<String, dynamic>.from(subs[_selectedSubIndex.clamp(0, subs.length - 1)] as Map);

    }



    final targets = _targetOptions();

    final currentSize = _currentSizeName ?? _trim(selectedMap?['meal_size_name']);



    return Scaffold(

      appBar: AppBar(

        title: const Text('Upgrade meal size', style: TextStyle(fontWeight: FontWeight.w800)),

        leading: IconButton(

          icon: const Icon(CupertinoIcons.back),

          onPressed: () => Navigator.pop(context),

        ),

      ),

      body: SafeArea(
        child: _loading && subs.isEmpty

            ? const Center(child: CupertinoActivityIndicator())

            : RefreshIndicator(

              onRefresh: _load,

              child: ListView(

                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(20),

                children: [

                  if (_error != null)

                    Container(

                      margin: const EdgeInsets.only(bottom: 16),

                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(

                        color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50,

                        borderRadius: BorderRadius.circular(14),

                      ),

                      child: Text(

                        _error!,

                        style: TextStyle(

                          fontWeight: FontWeight.w700,

                          color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,

                        ),

                      ),

                    ),

                  Text(

                    'Pay a one-time fee to move to a larger meal pack. Active and upcoming subscriptions qualify.',

                    style: TextStyle(

                      height: 1.4,

                      fontWeight: FontWeight.w600,

                      color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,

                    ),

                  ),

                  const SizedBox(height: 20),

                  if (subs.isEmpty)

                    Text(

                      'No active or upcoming subscriptions found. Subscribe first, then you can upgrade meal size.',

                      style: TextStyle(

                        fontWeight: FontWeight.w700,

                        color: isDark ? Colors.white54 : Colors.grey.shade700,

                      ),

                    )

                  else ...[

                    _sectionTitle(context, 'Who is upgrading?'),

                    const SizedBox(height: 8),

                    Material(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _pickSubscriber(subs, isDark),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                                child: const Icon(CupertinoIcons.person_fill, color: AppTheme.primaryColor, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _trim((subs[_selectedSubIndex.clamp(0, subs.length - 1)] as Map)['entity_name'])
                                              .isNotEmpty
                                          ? _trim((subs[_selectedSubIndex.clamp(0, subs.length - 1)] as Map)['entity_name'])
                                          : widget.initialEntityName ?? 'Subscriber',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                    if (_trim((subs[_selectedSubIndex.clamp(0, subs.length - 1)] as Map)['plan_name']).isNotEmpty)
                                      Text(
                                        _trim((subs[_selectedSubIndex.clamp(0, subs.length - 1)] as Map)['plan_name']),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(CupertinoIcons.chevron_down, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (currentSize.isNotEmpty) ...[

                      const SizedBox(height: 12),

                      Container(

                        width: double.infinity,

                        padding: const EdgeInsets.all(14),

                        decoration: BoxDecoration(

                          color: isDark ? AppTheme.surfaceDark : AppTheme.primaryColor.withValues(alpha: 0.08),

                          borderRadius: BorderRadius.circular(14),

                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),

                        ),

                        child: Row(

                          children: [

                            Icon(CupertinoIcons.square_grid_2x2, color: AppTheme.primaryColor, size: 22),

                            const SizedBox(width: 12),

                            Expanded(

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  Text(

                                    'Current meal size',

                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),

                                  ),

                                  Text(

                                    currentSize,

                                    style: TextStyle(

                                      fontSize: 17,

                                      fontWeight: FontWeight.w800,

                                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                          ],

                        ),

                      ),

                    ],

                    const SizedBox(height: 24),

                    _sectionTitle(context, 'Choose new size'),

                    const SizedBox(height: 8),

                          if (_loadingOptions)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CupertinoActivityIndicator()),
                            )
                          else if (targets.isEmpty)

                      Container(

                        width: double.infinity,

                        padding: const EdgeInsets.all(14),

                        decoration: BoxDecoration(

                          color: isDark ? AppTheme.surfaceDark : Colors.orange.shade50,

                          borderRadius: BorderRadius.circular(14),

                        ),

                        child: Text(

                          'No upgrade path is published from your current size yet. Contact support if you need a larger pack.',

                          style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : AppTheme.textPrimaryLight),

                        ),

                      )

                    else

                      ...targets.map((t) {

                        final id = _int(t['to_id']);

                        if (id == null) return const SizedBox.shrink();

                        final selected = _toMealSizeId == id;

                        return Padding(

                          padding: const EdgeInsets.only(bottom: 10),

                          child: Material(

                            color: selected

                                ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)

                                : (isDark ? AppTheme.surfaceDark : Colors.white),

                            borderRadius: BorderRadius.circular(14),

                            child: InkWell(

                              onTap: () => setState(() => _toMealSizeId = id),

                              borderRadius: BorderRadius.circular(14),

                              child: Container(

                                padding: const EdgeInsets.all(16),

                                decoration: BoxDecoration(

                                  borderRadius: BorderRadius.circular(14),

                                  border: Border.all(

                                    color: selected ? AppTheme.primaryColor : (isDark ? Colors.white12 : Colors.grey.shade300),

                                    width: selected ? 2 : 1,

                                  ),

                                ),

                                child: Row(

                                  children: [

                                    Icon(

                                      selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,

                                      color: selected ? AppTheme.primaryColor : Colors.grey,

                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(

                                      child: Column(

                                        crossAxisAlignment: CrossAxisAlignment.start,

                                        children: [

                                          Text(

                                            _trim(t['label']),

                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),

                                          ),

                                          Text(

                                            _trim(t['subtitle']),

                                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),

                                          ),

                                        ],

                                      ),

                                    ),

                                    Text(

                                      '₹${_trim(t['price'])}',

                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryColor),

                                    ),

                                  ],

                                ),

                              ),

                            ),

                          ),

                        );

                      }),

                    const SizedBox(height: 8),

                    SizedBox(

                      width: double.infinity,

                      child: ElevatedButton(

                        onPressed: pay.isLoading || _toMealSizeId == null || targets.isEmpty ? null : _runPayment,

                        style: ElevatedButton.styleFrom(

                          backgroundColor: AppTheme.primaryColor,

                          foregroundColor: Colors.white,

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

                        ),

                        child: Text(pay.isLoading ? 'Please wait…' : 'Pay'),

                      ),

                    ),

                  ],

                  if (history.isNotEmpty) ...[

                    const SizedBox(height: 32),

                    _sectionTitle(context, 'Upgrade payment history'),

                    const SizedBox(height: 8),

                    ...history.take(20).map((h) {

                      final amount = MoneyFormat.display(h['amount'] ?? h['order_amount'] ?? h['amount_paid']);

                      final status = _trim(h['order_status'] ?? h['status'] ?? h['payment_status']).toUpperCase();

                      final when = _trim(h['created_at'] ?? h['createdAt']);

                      final who = _trim(h['entity_name'] ?? h['entityName']);

                      final plan = _trim(h['plan_name'] ?? h['planName']);

                      return Card(

                        margin: const EdgeInsets.only(bottom: 8),

                        child: ListTile(

                          title: Text(who.isNotEmpty ? who : plan, style: const TextStyle(fontWeight: FontWeight.w700)),

                          subtitle: Text(when.isNotEmpty ? when : 'Meal size upgrade'),

                          trailing: Column(

                            mainAxisAlignment: MainAxisAlignment.center,

                            crossAxisAlignment: CrossAxisAlignment.end,

                            children: [

                              Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.w800)),

                              Text(status, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey)),

                            ],

                          ),

                        ),

                      );

                    }),

                  ],

                  const SizedBox(height: 24),

                ],

              ),

            ),
      ),

    );

  }



  Widget _sectionTitle(BuildContext context, String text) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(

      text,

      style: TextStyle(

        fontSize: 15,

        fontWeight: FontWeight.w900,

        color: isDark ? Colors.white : AppTheme.textPrimaryLight,

      ),

    );

  }

}


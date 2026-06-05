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
import 'package:meal_app/features/subscription/ui/screens/wallet_screen.dart';
import 'package:meal_app/core/widgets/wallet_checkout_section.dart';



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
  String? _walletBalance;
  bool _eligible = false;
  bool _useWallet = true;
  bool _loadingWalletPreview = false;
  double? _walletApplied;
  double? _gatewayAmount;

  static double _parseMoney(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }



  static String _trim(dynamic v) => (v ?? '').toString().trim();



  static int? _int(dynamic v) => int.tryParse('$v');

  String _subscriptionMealSizeLabel(Map<dynamic, dynamic> sub, {bool selected = false}) {
    if (selected && _currentSizeName != null && _currentSizeName!.isNotEmpty) {
      return _currentSizeName!;
    }
    return _trim(sub['meal_size_name']);
  }



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
        pay.fetchActiveSubscriptions(force: true),
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
    final entity = _selectedEntity(pay);
    if (entity == null) {
      if (mounted) {
        setState(() {
          _upgradeOptions = [];
          _currentSizeName = null;
        });
      }
      return;
    }

    setState(() => _loadingOptions = true);
    try {
      final payload = await pay.fetchMealSizeUpgradeOptionsForEntity(
        entityType: entity['entity_type']!,
        entityId: entity['entity_id']!,
      );
      if (!mounted) return;
      final data = (payload['data'] as List?) ?? [];
      final eligibleRaw = payload['eligible'];
      final eligible = eligibleRaw == null ? data.isNotEmpty : eligibleRaw == true;
      setState(() {
        _currentSizeName = _trim(payload['current_meal_size_name']);
        _walletBalance = _trim(payload['wallet_balance']);
        _eligible = eligible;
        if (_currentSizeName!.isNotEmpty && _selectedSubIndex < pay.activeSubscriptions.length) {
          final selected = pay.activeSubscriptions[_selectedSubIndex];
          if (selected is Map) {
            final updated = Map<String, dynamic>.from(selected);
            updated['meal_size_name'] = _currentSizeName;
            pay.activeSubscriptions[_selectedSubIndex] = updated;
          }
        }
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
        _eligible = false;
      });
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Map<String, String>? _selectedEntity(PaymentProvider pay) {
    final subs = pay.activeSubscriptions;
    if (subs.isEmpty || _selectedSubIndex >= subs.length || subs[_selectedSubIndex] is! Map) {
      return null;
    }
    final sub = Map<String, dynamic>.from(subs[_selectedSubIndex] as Map);
    final et = _trim(sub['entity_type']);
    final eid = _trim(sub['entity_id']);
    if (et.isEmpty || eid.isEmpty) return null;
    return {'entity_type': et, 'entity_id': eid};
  }

  List<Map<String, dynamic>> _optionsForDirection(String direction) {
    final out = <Map<String, dynamic>>[];
    for (final m in _upgradeOptions) {
      if (_trim(m['direction']).toLowerCase() != direction) continue;
      final t = _int(m['to_meal_size_id']);
      final toName = _trim(m['to_display_name']);
      if (t == null || toName.isEmpty) continue;
      final isDowngrade = direction == 'downgrade';
      out.add({
        'to_id': t,
        'label': toName,
        'subtitle': isDowngrade ? 'Credit to wallet' : 'One-time fee',
        'price': MoneyFormat.display(m['price']),
        'direction': direction,
      });
    }
    return out;
  }

  String? _selectedDirection() {
    if (_toMealSizeId == null) return null;
    for (final m in _upgradeOptions) {
      if (_int(m['to_meal_size_id']) == _toMealSizeId) {
        return _trim(m['direction']).toLowerCase();
      }
    }
    return null;
  }

  double? _selectedUpgradePrice() {
    if (_toMealSizeId == null || _selectedDirection() != 'upgrade') return null;
    for (final m in _upgradeOptions) {
      if (_int(m['to_meal_size_id']) != _toMealSizeId) continue;
      return _parseMoney(m['price']);
    }
    return null;
  }

  Future<void> _refreshUpgradeWalletPreview() async {
    final price = _selectedUpgradePrice();
    if (!mounted) return;
    if (price == null || price <= 0) {
      setState(() {
        _walletApplied = null;
        _gatewayAmount = null;
      });
      return;
    }

    setState(() => _loadingWalletPreview = true);
    try {
      final pay = context.read<PaymentProvider>();
      final preview = await pay.previewWalletForTotal(price, useWallet: _useWallet);
      if (!mounted) return;
      setState(() {
        _walletApplied = _parseMoney(preview['walletApplied']);
        _gatewayAmount = _parseMoney(preview['gatewayAmount']);
      });
    } catch (_) {
      // Optional breakdown — payment still works without preview.
    } finally {
      if (mounted) setState(() => _loadingWalletPreview = false);
    }
  }

  void _onUseWalletChanged(bool value) {
    setState(() => _useWallet = value);
    _refreshUpgradeWalletPreview();
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
                        'Who is resizing?',
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
                    final mealSize = _subscriptionMealSizeLabel(
                      sub,
                      selected: i == _selectedSubIndex,
                    );
                    final selected = i == _selectedSubIndex;
                    final subtitleParts = <String>[
                      if (plan.isNotEmpty) plan,
                      if (mealSize.isNotEmpty) 'Meal size: $mealSize',
                    ];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                        child: Icon(CupertinoIcons.person_fill, color: AppTheme.primaryColor, size: 20),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: subtitleParts.isNotEmpty ? Text(subtitleParts.join(' • ')) : null,
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
    setState(() {
      _selectedSubIndex = picked;
      _currentSizeName = null;
      _toMealSizeId = null;
    });
    await _loadOptionsForSelected();
  }

  Future<void> _runPayment() async {
    final pay = context.read<PaymentProvider>();
    final entity = _selectedEntity(pay);
    if (_toMealSizeId == null || entity == null) return;

    final res = await pay.initiateMealSizeUpgrade(
      entityType: entity['entity_type']!,
      entityId: entity['entity_id']!,
      toMealSizeId: _toMealSizeId!,
      isSandbox: ApiEndpoints.isSandboxPayment,
      useWallet: _useWallet,
    );



    if (!mounted) return;



    if (pay.error != null && res == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pay.error!)));
      return;
    }

    final sdkStatus = res?['sdkStatus']?.toString() ?? 'FAILURE';
    final txnId = res?['merchantTransactionId']?.toString() ?? pay.lastTxnId ?? '';
    final orderId = res?['orderId']?.toString() ?? '';

    if (sdkStatus == 'SUCCESS') {
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sdkStatus == 'INTERRUPTED'
              ? 'Payment cancelled. Wallet balance has been restored.'
              : 'Payment did not complete. You can retry when ready.',
        ),
      ),
    );
  }

  Future<void> _runDowngrade() async {
    final pay = context.read<PaymentProvider>();
    final entity = _selectedEntity(pay);
    if (_toMealSizeId == null || entity == null) return;

    final result = await pay.applyMealSizeDowngrade(
      entityType: entity['entity_type']!,
      entityId: entity['entity_id']!,
      toMealSizeId: _toMealSizeId!,
    );

    if (!mounted) return;

    if (pay.error != null && result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pay.error!)));
      return;
    }

    final message = result?['message']?.toString() ??
        'Meal pack resized. Wallet credited.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() {
      _toMealSizeId = null;
      _walletBalance = pay.walletBalance;
    });
    await _loadOptionsForSelected();
  }

  Future<void> _confirmAction() async {
    final direction = _selectedDirection();
    if (direction == 'downgrade') {
      await _runDowngrade();
    } else {
      await _runPayment();
    }
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



    final upgrades = _optionsForDirection('upgrade');
    final downgrades = _optionsForDirection('downgrade');
    final hasAnyOptions = upgrades.isNotEmpty || downgrades.isNotEmpty;
    final selectedDirection = _selectedDirection();

    final currentSize =
        (_currentSizeName != null && _currentSizeName!.isNotEmpty)
            ? _currentSizeName!
            : _trim(selectedMap?['meal_size_name']);



    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
      body: SafeArea(
        child: _loading && subs.isEmpty
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
                children: [
                  // Custom Header with rounded bottom corners
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : const Color(0xFFF3EBE0),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(CupertinoIcons.back, color: Color(0xFF8B7A66)),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Text(
                              'Buuttii',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Resize meal pack',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF5A4D42),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
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

                    'Move to a larger pack and pay a one-time fee, or downsize and receive the amount in your wallet.',

                    style: TextStyle(

                      height: 1.4,

                      fontWeight: FontWeight.w600,

                      color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,

                    ),

                  ),

                  const SizedBox(height: 20),

                  if (_walletBalance != null && _walletBalance!.isNotEmpty)
                    Material(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (_) => const WalletScreen()),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.money_dollar_circle_fill, color: AppTheme.primaryColor, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wallet balance',
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                                    ),
                                    Text(
                                      '₹${MoneyFormat.display(_walletBalance)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(CupertinoIcons.chevron_right, color: isDark ? Colors.white54 : Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_walletBalance != null && _walletBalance!.isNotEmpty)
                    const SizedBox(height: 20),

                  if (subs.isEmpty)

                    Text(

                      'No active or upcoming paid subscriptions found. Complete a subscription payment first, then you can resize the meal pack.',

                      style: TextStyle(

                        fontWeight: FontWeight.w700,

                        color: isDark ? Colors.white54 : Colors.grey.shade700,

                      ),

                    )

                  else ...[

                    _sectionTitle(context, 'Who is resizing?'),

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
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                              width: 1.5,
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
                                    if (currentSize.isNotEmpty)
                                      Text(
                                        'Meal size: $currentSize',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white60 : AppTheme.textSecondaryLight,
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
                          color: isDark ? AppTheme.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                            width: 1.5,
                          ),
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
                          else if (!hasAnyOptions)

                      Container(

                        width: double.infinity,

                        padding: const EdgeInsets.all(14),

                        decoration: BoxDecoration(

                          color: isDark ? AppTheme.surfaceDark : Colors.orange.shade50,

                          borderRadius: BorderRadius.circular(14),

                        ),

                        child: Text(

                          !_eligible
                              ? 'This profile does not have a completed subscription payment yet. Pay for a plan first, then resize options will appear here.'
                              : 'No resizing path is published from your current size yet. Contact support if you need to change your pack.',

                          style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : AppTheme.textPrimaryLight),

                        ),

                      )

                    else ...[
                      if (upgrades.isNotEmpty) ...[
                        _sectionTitle(context, 'Larger packs (pay)'),
                        const SizedBox(height: 8),
                        ..._buildOptionTiles(upgrades, isDark),
                        const SizedBox(height: 16),
                      ],
                      if (downgrades.isNotEmpty) ...[
                        _sectionTitle(context, 'Smaller packs (wallet credit)'),
                        const SizedBox(height: 8),
                        ..._buildOptionTiles(downgrades, isDark),
                      ],
                    ],

                    const SizedBox(height: 8),

                    if (selectedDirection == 'upgrade' && _selectedUpgradePrice() != null)
                      WalletCheckoutSection(
                        useWallet: _useWallet,
                        onUseWalletChanged: _onUseWalletChanged,
                        walletBalance: _walletBalance ?? pay.walletBalance,
                        walletApplied: _walletApplied,
                        gatewayAmount: _gatewayAmount,
                        totalAmount: _selectedUpgradePrice(),
                        loadingPreview: _loadingWalletPreview,
                      ),

                    if (selectedDirection == 'upgrade' && _selectedUpgradePrice() != null)
                      const SizedBox(height: 8),

                    SizedBox(

                      width: double.infinity,

                      child: ElevatedButton(

                        onPressed: pay.isLoading || _toMealSizeId == null || !hasAnyOptions || !_eligible ? null : _confirmAction,

                        style: ElevatedButton.styleFrom(

                          backgroundColor: AppTheme.primaryColor,

                          foregroundColor: Colors.white,

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

                        ),

                        child: Text(
                          pay.isLoading
                              ? 'Please wait…'
                              : selectedDirection == 'downgrade'
                                  ? 'Confirm & credit wallet'
                                  : 'Pay',
                        ),

                      ),

                    ),

                  ],

                  if (history.isNotEmpty) ...[

                    const SizedBox(height: 32),

                    _sectionTitle(context, 'Resize history'),

                    const SizedBox(height: 8),

                    ...history.take(20).map((h) {

                      final amount = MoneyFormat.display(h['amount'] ?? h['order_amount'] ?? h['amount_paid']);

                      final status = _trim(h['order_status'] ?? h['status'] ?? h['payment_status']).toUpperCase();

                      final when = _trim(h['created_at'] ?? h['createdAt']);

                      final who = _trim(h['entity_name'] ?? h['entityName']);

                      final plan = _trim(h['plan_name'] ?? h['planName']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppTheme.borderDark.withValues(alpha: 0.5) : AppTheme.borderLight,
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(

                          title: Text(who.isNotEmpty ? who : plan, style: const TextStyle(fontWeight: FontWeight.w700)),

                          subtitle: Text(when.isNotEmpty ? when : 'Meal size resize'),

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
        ],
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

  List<Widget> _buildOptionTiles(List<Map<String, dynamic>> options, bool isDark) {
    return options.map((t) {
      final id = _int(t['to_id']);
      if (id == null) return const SizedBox.shrink();
      final selected = _toMealSizeId == id;
      final isDowngrade = _trim(t['direction']) == 'downgrade';

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? AppTheme.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () {
              setState(() => _toMealSizeId = id);
              _refreshUpgradeWalletPreview();
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? AppTheme.primaryColor : (isDark ? AppTheme.borderDark.withValues(alpha: 0.5) : AppTheme.borderLight),
                  width: selected ? 2.5 : 1.5,
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
                    isDowngrade ? '+₹${_trim(t['price'])}' : '₹${_trim(t['price'])}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isDowngrade ? Colors.green : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}


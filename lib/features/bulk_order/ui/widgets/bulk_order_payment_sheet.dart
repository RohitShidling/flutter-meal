import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_delivery_address.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_address_section.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';

/// Collects delivery date, time, and address immediately before payment.
class BulkOrderPaymentSheet extends StatefulWidget {
  const BulkOrderPaymentSheet({
    super.key,
    required this.config,
    required this.onConfirm,
    this.initialDeliveryDate,
  });

  final BulkOrderConfig config;
  final Future<bool> Function(String deliveryDate) onConfirm;
  final String? initialDeliveryDate;

  static Future<bool?> show(
    BuildContext context, {
    required BulkOrderConfig config,
    required Future<bool> Function(String deliveryDate) onConfirm,
    String? initialDeliveryDate,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => BulkOrderPaymentSheet(
        config: config,
        onConfirm: onConfirm,
        initialDeliveryDate: initialDeliveryDate,
      ),
    );
  }

  @override
  State<BulkOrderPaymentSheet> createState() => _BulkOrderPaymentSheetState();
}

class _BulkOrderPaymentSheetState extends State<BulkOrderPaymentSheet> {
  String? _deliveryDate;
  TimeOfDay? _deliveryTime;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _deliveryDate = widget.initialDeliveryDate;
    final saved = context.read<BulkOrderProvider>().deliveryAddress?.deliveryTime;
    if (saved != null && saved.isNotEmpty) {
      final parsed = TimeUtils.tryParseToBackend(saved);
      if (parsed != null) {
        final parts = parsed.split(':');
        if (parts.length >= 2) {
          _deliveryTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 13,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final ymd = await pickBulkDeliveryDate(context, widget.config, _deliveryDate);
    if (ymd != null && mounted) setState(() => _deliveryDate = ymd);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _deliveryTime ?? const TimeOfDay(hour: 13, minute: 0),
    );
    if (picked != null && mounted) setState(() => _deliveryTime = picked);
  }

  void _syncDeliveryTimeToProvider() {
    final provider = context.read<BulkOrderProvider>();
    final addr = provider.deliveryAddress;
    if (addr == null || _deliveryTime == null) return;
    provider.setDeliveryAddress(
      BulkDeliveryAddress(
        stateId: addr.stateId,
        cityId: addr.cityId,
        addressLine: addr.addressLine,
        pincode: addr.pincode,
        stateName: addr.stateName,
        cityName: addr.cityName,
        deliveryTime: TimeUtils.toBackendFormat(_deliveryTime!),
      ),
    );
  }

  Future<void> _pay() async {
    if (_deliveryDate == null) {
      ErrorHandler.showError(context, 'Select a delivery date');
      return;
    }

    // Enforce next-day minimum — no same-day orders
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (_deliveryDate!.compareTo(todayStr) <= 0) {
      ErrorHandler.showError(context, 'Delivery date must be tomorrow or later. Same-day orders are not allowed.');
      return;
    }

    if (_deliveryTime == null) {
      ErrorHandler.showError(context, 'Select a delivery time');
      return;
    }
    _syncDeliveryTimeToProvider();

    final provider = context.read<BulkOrderProvider>();
    final addrErr = provider.validateDeliveryAddress(requireTime: true);
    if (addrErr != null) {
      ErrorHandler.showError(context, addrErr);
      return;
    }

    setState(() => _paying = true);
    final ok = await widget.onConfirm(_deliveryDate!);
    if (mounted) {
      setState(() => _paying = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Delivery & payment',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark_circle_fill),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(
                      'Enter where and when meals should arrive. We validate everything before payment.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BulkDeliveryDateTile(deliveryDate: _deliveryDate, onTap: _pickDate),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Delivery time'),
                      subtitle: Text(
                        _deliveryTime == null ? 'Tap to choose' : TimeUtils.toBackendFormat(_deliveryTime!),
                      ),
                      trailing: const Icon(CupertinoIcons.clock),
                      onTap: _pickTime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const BulkOrderAddressSection(),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _paying ? null : _pay,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _paying
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Proceed to Pay', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

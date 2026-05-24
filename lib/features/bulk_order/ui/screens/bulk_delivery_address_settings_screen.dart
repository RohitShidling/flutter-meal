import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_address_section.dart';

/// Edit saved bulk delivery address from Settings.
class BulkDeliveryAddressSettingsScreen extends StatelessWidget {
  const BulkDeliveryAddressSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk delivery address'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'This address is prefilled when you pay for a bulk order. You can change it here anytime.',
            ),
            const SizedBox(height: 16),
            const BulkOrderAddressSection(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final p = context.read<BulkOrderProvider>();
                final err = p.validateDeliveryAddress();
                if (err != null) {
                  ErrorHandler.showError(context, err);
                  return;
                }
                ErrorHandler.showSuccess(context, 'Delivery address saved');
                Navigator.pop(context);
              },
              child: const Text('Save address'),
            ),
          ],
        ),
      ),
    );
  }
}

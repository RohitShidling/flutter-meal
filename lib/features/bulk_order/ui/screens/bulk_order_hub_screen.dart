import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_standard_screen.dart';
import 'package:meal_app/features/bulk_order/ui/screens/bulk_order_variety_categories_screen.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';

/// Entry point: user picks standard (< threshold) or large variety (50+) flow.
class BulkOrderHubScreen extends StatefulWidget {
  const BulkOrderHubScreen({super.key});

  @override
  State<BulkOrderHubScreen> createState() => _BulkOrderHubScreenState();
}

class _BulkOrderHubScreenState extends State<BulkOrderHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<BulkOrderProvider>();
      await p.loadSavedDeliveryAddress();
      await p.loadConfig();
      await p.loadCartFromServer();
      final cfg = p.config;
      if (cfg != null && cfg.earliestDeliveryDate.length >= 10) {
        await p.loadMenusForDate(cfg.earliestDeliveryDate);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BulkOrderProvider>();
    final cfg = p.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bulk order',
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
      ),
      body: p.isLoading && cfg == null
          ? const Center(child: CircularProgressIndicator())
          : cfg == null
              ? Center(child: Text(p.error ?? 'Bulk ordering is unavailable'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        cfg.hubIntroText?.isNotEmpty == true
                            ? cfg.hubIntroText!
                            : 'Choose the type of bulk order that fits your group size.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 24),
                      BulkOrderTypeCard(
                        title: cfg.standardTierTitle?.isNotEmpty == true
                            ? cfg.standardTierTitle!
                            : 'Standard bulk',
                        subtitle: cfg.standardTierSubtitle?.isNotEmpty == true
                            ? cfg.standardTierSubtitle!
                            : '${cfg.minQuantity}–${cfg.standardMaxQuantity} meals',
                        detail: cfg.standardTierDescription?.isNotEmpty == true
                            ? cfg.standardTierDescription!
                            : 'One meal for your delivery date — the same dish for everyone.',
                        icon: CupertinoIcons.person_3_fill,
                        color: AppTheme.primaryColor,
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const BulkOrderStandardScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      BulkOrderTypeCard(
                        title: cfg.varietyTierTitle?.isNotEmpty == true
                            ? cfg.varietyTierTitle!
                            : 'Large event bulk',
                        subtitle: cfg.varietyTierSubtitle?.isNotEmpty == true
                            ? cfg.varietyTierSubtitle!
                            : '${cfg.tierThreshold}+ meals',
                        detail: cfg.varietyTierDescription?.isNotEmpty == true
                            ? cfg.varietyTierDescription!
                            : 'Browse meal categories and set portions for each dish.',
                        icon: CupertinoIcons.square_stack_3d_up_fill,
                        color: Colors.deepOrange,
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const BulkOrderVarietyCategoriesScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

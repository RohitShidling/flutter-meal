import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/meal_date.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';

Widget bulkMenuImage(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: ColoredBox(
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        height: 180,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CupertinoActivityIndicator()),
        ),
        errorWidget: (_, __, ___) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Icon(CupertinoIcons.photo, color: Colors.grey.withValues(alpha: 0.4)),
          ),
        ),
      ),
    ),
  );
}

Widget bulkInfoBanner({
  required String message,
  required bool isDark,
  Color? borderColor,
  Color? backgroundColor,
  IconData icon = CupertinoIcons.info_circle_fill,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: backgroundColor ??
          (isDark
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : AppTheme.primaryColor.withValues(alpha: 0.08)),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: borderColor ?? AppTheme.primaryColor.withValues(alpha: isDark ? 0.25 : 0.2),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: borderColor ?? AppTheme.primaryColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
            ),
          ),
        ),
      ],
    ),
  );
}

class BulkDeliveryDateTile extends StatelessWidget {
  const BulkDeliveryDateTile({
    super.key,
    required this.deliveryDate,
    required this.onTap,
    this.enabled = true,
  });

  final String? deliveryDate;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Delivery date'),
      subtitle: Text(deliveryDate ?? 'Select date'),
      trailing: enabled ? const Icon(CupertinoIcons.calendar) : null,
      onTap: enabled ? onTap : null,
    );
  }
}

Future<String?> pickBulkDeliveryDate(
  BuildContext context,
  BulkOrderConfig cfg,
  String? currentYmd,
) async {
  final earliest = MealDate.parseYmdLocal(cfg.earliestDeliveryDate) ??
      MealDate.firstSelectableStartDate();
  final last = earliest.add(const Duration(days: 365));
  final initial = currentYmd != null
      ? (MealDate.parseYmdLocal(currentYmd) ?? earliest)
      : earliest;
  final picked = await showDatePicker(
    context: context,
    initialDate: initial.isBefore(earliest) ? earliest : initial,
    firstDate: earliest,
    lastDate: last,
    helpText: 'Delivery date',
  );
  if (picked == null) return null;
  return MealDate.formatYmd(picked);
}

class BulkOrderTypeCard extends StatelessWidget {
  const BulkOrderTypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.white60 : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: isDark ? Colors.white38 : Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

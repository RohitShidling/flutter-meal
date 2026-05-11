import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';

class MealSkipScreen extends StatefulWidget {
  const MealSkipScreen({super.key});

  @override
  State<MealSkipScreen> createState() => _MealSkipScreenState();
}

class _MealSkipScreenState extends State<MealSkipScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MealProvider>().fetchSkips();
      context.read<MealProvider>().fetchMealStatus();
      context.read<MealProvider>().fetchSkipPolicy();
      context.read<ChildrenProvider>().fetchChildren();
      context.read<ProfileProvider>().fetchProfiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mealProvider = context.watch<MealProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Meal Skips',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
          ),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSkipDialog(context),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(CupertinoIcons.calendar_badge_plus, color: Colors.white),
        label: const Text('New Skip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: mealProvider.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                // Meal status section
                if (mealProvider.mealStatus.isNotEmpty)
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: mealProvider.mealStatus.length,
                      itemBuilder: (context, index) {
                        final ms = mealProvider.mealStatus[index];
                        return Container(
                          width: 180,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  ms['entity_name']?.toString() ?? 'Entity',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: Text(
                                  '${ms['remaining_meals'] ?? 0} / ${ms['total_meals'] ?? 0} meals left',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: Text(
                                  ms['plan_name']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Skip list
                Expanded(
                  child: mealProvider.skips.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.calendar, size: 64, color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No meal skips scheduled',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to schedule a skip (policy-based minimum days)',
                                style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                              ),
                            ],
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            // Approved first, Requested second, Cancelled last
                            final sortedSkips = List.from(mealProvider.skips)..sort((a, b) {
                              final statusA = a['status']?.toString().toLowerCase() ?? '';
                              final statusB = b['status']?.toString().toLowerCase() ?? '';
                              
                              int getPriority(String status) {
                                if (status == 'approved') return 0;
                                if (status == 'requested') return 1;
                                if (status == 'cancelled') return 3;
                                return 2; // Others in middle
                              }
                              
                              return getPriority(statusA).compareTo(getPriority(statusB));
                            });

                            return ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: sortedSkips.length,
                              itemBuilder: (context, index) {
                                final skip = sortedSkips[index];
                                return Dismissible(
                                  key: ValueKey('skip_${skip['id']}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.only(right: 22),
                                    alignment: Alignment.centerRight,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(CupertinoIcons.delete_solid, color: Colors.white),
                                  ),
                                  confirmDismiss: (_) async {
                                    final id = skip['id'];
                                    if (id == null) return false;
                                    final skipId = id is int ? id : int.tryParse(id.toString()) ?? 0;
                                    return _confirmDeleteSkip(context, skipId, mealProvider);
                                  },
                                  child: _buildSkipCard(context, skip, isDark, mealProvider),
                                )
                                    .animate()
                                    .fadeIn(delay: (index * 80).ms)
                                    .slideX(begin: 0.1, end: 0);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSkipCard(BuildContext context, Map<String, dynamic> skip, bool isDark, MealProvider mealProvider) {
    final entityName = skip['entity_name']?.toString() ?? 'Entity';
    final entityType = skip['entity_type']?.toString() ?? '';
    final status = skip['status']?.toString() ?? 'approved';
    final totalDays = skip['total_skip_days'] ?? 0;

    final startStr = skip['skip_start_date']?.toString() ?? '';
    final endStr = skip['skip_end_date']?.toString() ?? '';
    DateTime? start = DateTime.tryParse(startStr);
    DateTime? end = DateTime.tryParse(endStr);

    final isFuture = start != null && start.isAfter(DateTime.now());
    final isActive = status == 'approved' || status == 'active';

    return AppleCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isFuture ? Colors.orange : Colors.green).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFuture ? CupertinoIcons.clock_fill : CupertinoIcons.checkmark_circle_fill,
                  color: isFuture ? Colors.orange : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entityName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    Text(
                      '${entityType.toUpperCase()} • $totalDays days',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
                  Text(
                    start != null ? DateFormat('dd MMM yyyy').format(start) : '--',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                  ),
                ],
              ),
              const Icon(CupertinoIcons.arrow_right, size: 16, color: Colors.grey),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('To', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
                  Text(
                    end != null ? DateFormat('dd MMM yyyy').format(end) : '--',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                  ),
                ],
              ),
            ],
          ),
          if (isFuture && isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _confirmCancelSkip(context, skip, mealProvider),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Cancel This Skip', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmCancelSkip(BuildContext context, Map<String, dynamic> skip, MealProvider mealProvider) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Cancel Skip'),
        content: const Text('Are you sure you want to cancel this meal skip?'),
        actions: [
          CupertinoDialogAction(child: const Text('No'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final id = skip['id'];
              if (id != null) {
                final success = await mealProvider.cancelSkip(id is int ? id : int.tryParse(id.toString()) ?? 0);
                if (mounted) {
                  if (success) {
                    ErrorHandler.showSuccess(context, 'Skip cancelled successfully');
                  } else {
                    ErrorHandler.showError(context, mealProvider.error);
                  }
                }
              }
            },
            child: const Text('Cancel Skip'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteSkip(BuildContext context, int skipId, MealProvider mealProvider) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Skip'),
        content: const Text('Delete this skip from your history?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('No'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;
    final success = await mealProvider.deleteSkip(skipId);
    if (context.mounted) {
      if (success) {
        ErrorHandler.showSuccess(context, 'Skip deleted successfully');
      } else {
        ErrorHandler.showError(context, mealProvider.error);
      }
    }
    return success;
  }

  void _showSkipDialog(BuildContext context) {
    final childrenProvider = context.read<ChildrenProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final mealProvider = context.read<MealProvider>();
    // Save messenger BEFORE sheet opens so it works after sheet is popped
    final messenger = ScaffoldMessenger.of(context);

    // Build entity list
    final List<Map<String, String>> entities = [];
    for (final child in childrenProvider.children) {
      entities.add({'type': 'child', 'id': child.id!, 'name': child.name});
    }
    if (profileProvider.teacherProfile != null) {
      entities.add({'type': 'teacher', 'id': profileProvider.teacherProfile!.id!, 'name': profileProvider.teacherProfile!.name});
    }
    if (profileProvider.professionalProfile != null) {
      entities.add({'type': 'professional', 'id': profileProvider.professionalProfile!.id!, 'name': profileProvider.professionalProfile!.name});
    }

    if (entities.isEmpty) {
      ErrorHandler.showError(context, 'No active profiles found. Create a profile first.');
      return;
    }

    String? selectedEntity;
    DateTimeRange? selectedRange;
    String? sheetError;
    final minSkipDays = (mealProvider.skipPolicy['min_skip_days'] as num?)?.toInt() ?? 3;
    final minNoticeDays = (mealProvider.skipPolicy['min_notice_days'] as num?)?.toInt() ?? 1;

    // Helper: get subscription end_date for the selected entity from mealStatus
    DateTime? _getEntityExpiry(String entityKey) {
      final parts = entityKey.split('_');
      if (parts.length < 2) return null;
      final type = parts[0];
      final id = parts.sublist(1).join('_');
      final match = mealProvider.mealStatus.firstWhere(
        (s) => s['entity_type'] == type && s['entity_id']?.toString() == id,
        orElse: () => null,
      );
      if (match == null) return null;
      final endStr = match['end_date']?.toString();
      return endStr != null ? DateTime.tryParse(endStr) : null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(builder: (sheetCtx, setSheetState) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(sheetCtx).viewInsets.bottom + 36),
            decoration: BoxDecoration(
              color: Theme.of(sheetCtx).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  'Schedule a Meal Skip',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                ),
                const SizedBox(height: 8),
                Text(
                  'Minimum $minSkipDays consecutive day(s). Start date must be at least $minNoticeDays day(s) in advance.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                ),
                const SizedBox(height: 24),

                // Entity selection
                Text('Select Profile', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: entities.map((e) {
                    final key = '${e['type']}_${e['id']}';
                    final isSelected = selectedEntity == key;
                    return ChoiceChip(
                      label: Text(e['name']!),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white : AppTheme.textPrimaryLight),
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setSheetState(() {
                        selectedEntity = key;
                        selectedRange = null; // reset date when entity changes
                        sheetError = null;
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Date range
                Text('Skip Dates', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final tomorrow = DateTime.now().add(Duration(days: minNoticeDays));
                    // Cap lastDate to subscription expiry for the selected entity
                    final expiry = selectedEntity != null ? _getEntityExpiry(selectedEntity!) : null;
                    final lastDate = expiry != null
                        ? (expiry.isBefore(tomorrow.add(const Duration(days: 90))) ? expiry : tomorrow.add(const Duration(days: 90)))
                        : tomorrow.add(const Duration(days: 90));

                    if (expiry != null && expiry.isBefore(tomorrow)) {
                      setSheetState(() => sheetError = 'Your subscription for this profile has expired.');
                      return;
                    }

                    final range = await showDateRangePicker(
                      context: sheetCtx,
                      firstDate: tomorrow,
                      lastDate: lastDate,
                      helpText: expiry != null
                          ? 'Select skip range (max: ${DateFormat('dd MMM yyyy').format(expiry)})'
                          : 'Select skip range (min 3 days)',
                    );
                    if (range != null) {
                      final days = range.end.difference(range.start).inDays + 1;
                      if (days < minSkipDays) {
                        setSheetState(() => sheetError = 'Minimum $minSkipDays consecutive days required');
                        return;
                      }
                      setSheetState(() {
                        selectedRange = range;
                        sheetError = null;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.calendar, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Text(
                          selectedRange != null
                              ? '${DateFormat('dd MMM').format(selectedRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedRange!.end)}'
                              : (selectedEntity == null ? 'Select a profile first' : 'Tap to select date range'),
                          style: TextStyle(
                            color: selectedRange != null ? (isDark ? Colors.white : AppTheme.textPrimaryLight) : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (selectedRange != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${selectedRange!.end.difference(selectedRange!.start).inDays + 1} days selected',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
                // In-sheet error message
                if (sheetError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(sheetError!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (selectedEntity != null && selectedRange != null)
                        ? () async {
                            final parts = selectedEntity!.split('_');
                            final entityType = parts[0];
                            final entityId = parts.sublist(1).join('_');
                            final fmt = DateFormat('yyyy-MM-dd');

                            // Make API call FIRST — pop only on success
                            final success = await mealProvider.skipMeal(
                              entityType: entityType,
                              entityId: entityId,
                              startDate: fmt.format(selectedRange!.start),
                              endDate: fmt.format(selectedRange!.end),
                            );

                            if (success) {
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              messenger.showSnackBar(SnackBar(
                                content: const Text('Meal skip scheduled successfully!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ));
                            } else {
                              // Keep sheet open — show error inside it
                              setSheetState(() => sheetError = mealProvider.error ?? 'Failed to schedule skip');
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Schedule Skip', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
               ],
              ),
            ),
          );
        });
      },
    );
  }
}

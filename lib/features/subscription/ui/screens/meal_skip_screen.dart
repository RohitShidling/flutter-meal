import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/meal_provider.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';
import 'package:meal_app/features/home/ui/widgets/bottom_footer_nav.dart';
import 'package:meal_app/core/navigation/app_routes.dart';

/// Keys are `${entityType}_${entityId}` where type is child, teacher, or professional (G8).
({String type, String id})? parseMealSkipEntityKey(String key) {
  const prefixes = <String>['child_', 'teacher_', 'professional_'];
  for (final p in prefixes) {
    if (key.startsWith(p)) {
      final id = key.substring(p.length);
      if (id.isEmpty) return null;
      return (type: p.substring(0, p.length - 1), id: id);
    }
  }
  return null;
}

class MealSkipScreen extends StatefulWidget {
  const MealSkipScreen({super.key});

  @override
  State<MealSkipScreen> createState() => _MealSkipScreenState();
}

class _MealSkipScreenState extends State<MealSkipScreen> {

  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.mealSkip);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAll();
      // Re-fetch when coming back online
      NetworkStatusService.instance.addBecameOnlineListener(_fetchAll);
    });
  }

  @override
  void dispose() {
    NetworkStatusService.instance.removeBecameOnlineListener(_fetchAll);
    AppRouteTracker.instance.clearIfCurrent(AppScreen.mealSkip);
    super.dispose();
  }

  void _fetchAll() {
    if (!mounted) return;
    context.read<MealProvider>().fetchSkips();
    context.read<MealProvider>().fetchMealStatus();
    context.read<MealProvider>().fetchSkipPolicy();
    context.read<ChildrenProvider>().fetchChildren();
    context.read<ProfileProvider>().fetchProfiles();
  }

  @override
  Widget build(BuildContext context) {
    final mealProvider = context.watch<MealProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool showSpinner = mealProvider.isLoading &&
        mealProvider.mealStatus.isEmpty &&
        mealProvider.skips.isEmpty;

    final pageBg = isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5);
    final navBarColor = isDark ? AppTheme.surfaceDark : Colors.white;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayFor(background: pageBg, isDark: isDark, navigationBarColor: navBarColor),
        child: Scaffold(
          backgroundColor: pageBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSkipDialog(context),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(CupertinoIcons.calendar_badge_plus, color: Colors.white),
        label: const Text('New Skip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header with rounded bottom corners
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFF3EBE0),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.back, color: Color(0xFF8B7A66)),
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  ),
                  Expanded(
                    child: Text(
                      'Meal Skips',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF5A4D42),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: showSpinner
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
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                              width: 1.5,
                            ),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'Tap + to schedule a skip (policy-based minimum days)',
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  maxLines: 3,
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                                  ),
                                ),
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
                                final isCancelled = skip['status']?.toString().toLowerCase() == 'cancelled';
                                final card = _buildSkipCard(context, skip, isDark, mealProvider);
                                
                                Widget item = card;
                                if (isCancelled) {
                                  item = Dismissible(
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
                                    child: card,
                                  );
                                }

                                return item
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
          ),
          ],
        ),
      ),
      bottomNavigationBar: BuuttiiFooterNav(
        currentIndex: 2,
        onHomeTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
        onWeekMenuTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.weeklyMenu),
        onMealSkipTap: () {},
        onSettingsTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.settings),
      ),
     ),
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
                if (!context.mounted) return;
                if (success) {
                  ErrorHandler.showSuccess(context, 'Skip cancelled successfully');
                } else {
                  ErrorHandler.showError(context, mealProvider.error);
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
    final minSkipDays = int.tryParse(mealProvider.skipPolicy['min_skip_days']?.toString() ?? '') ?? 3;
    final minNoticeDays = int.tryParse(mealProvider.skipPolicy['min_notice_days']?.toString() ?? '') ?? 1;

    int resolveEntityRemainingMeals(String entityKey) {
      final parsed = parseMealSkipEntityKey(entityKey);
      if (parsed == null) return 0;
      final match = mealProvider.mealStatus.firstWhere(
        (s) => s['entity_type'] == parsed.type && s['entity_id']?.toString() == parsed.id,
        orElse: () => <String, dynamic>{},
      );
      if (match.isEmpty) return 0;
      final remaining = match['remaining_meals'] ?? match['remainingMeals'];
      return int.tryParse(remaining?.toString() ?? '0') ?? 0;
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
                  onTap: selectedEntity == null
                      ? null
                      : () async {
                          final tomorrow = DateTime.now().add(Duration(days: minNoticeDays));
                          final remainingMeals = resolveEntityRemainingMeals(selectedEntity!);

                          if (remainingMeals <= 0) {
                            setSheetState(() => sheetError = 'No remaining meals left for this profile. Please purchase or renew a plan.');
                            return;
                          }

                          final lastDate = tomorrow.add(const Duration(days: 90));

                          final range = await showDateRangePicker(
                            context: sheetCtx,
                            firstDate: tomorrow,
                            lastDate: lastDate,
                            helpText: 'Select skip range (min 3 days)',
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
                      color: selectedEntity == null
                          ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade100)
                          : (isDark ? AppTheme.surfaceDark : const Color(0xFFFDEEE8)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selectedEntity == null
                            ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade300)
                            : (isDark ? AppTheme.primaryColor.withValues(alpha: 0.4) : AppTheme.primaryColor.withValues(alpha: 0.3)),
                        width: selectedEntity == null ? 1.0 : 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          color: selectedEntity == null
                              ? (isDark ? Colors.white24 : Colors.grey.shade400)
                              : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          selectedRange != null
                              ? '${DateFormat('dd MMM').format(selectedRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedRange!.end)}'
                              : (selectedEntity == null ? 'Select a profile first' : 'Tap to select date range'),
                          style: TextStyle(
                            color: selectedRange != null
                                ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                                : (selectedEntity == null
                                    ? (isDark ? Colors.white24 : Colors.grey.shade400)
                                    : AppTheme.primaryColor),
                            fontWeight: FontWeight.w700,
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
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
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
                            final parsed = parseMealSkipEntityKey(selectedEntity!);
                            if (parsed == null) {
                              setSheetState(() => sheetError = 'Invalid profile selection.');
                              return;
                            }
                            final fmt = DateFormat('yyyy-MM-dd');

                            // Make API call FIRST — pop only on success
                            final success = await mealProvider.skipMeal(
                              entityType: parsed.type,
                              entityId: parsed.id,
                              startDate: fmt.format(selectedRange!.start),
                              endDate: fmt.format(selectedRange!.end),
                            );

                            if (!sheetCtx.mounted) return;
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

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meal_app/core/widgets/image_preview_dialog.dart';
import 'package:meal_app/core/services/app_route_tracker.dart';

class WeeklyMenuScreen extends StatefulWidget {
  const WeeklyMenuScreen({super.key});

  @override
  State<WeeklyMenuScreen> createState() => _WeeklyMenuScreenState();
}

class _WeeklyMenuScreenState extends State<WeeklyMenuScreen> {
  List<String> _nutritionPointsFrom(dynamic menu) {
    final raw = menu is Map ? menu['nutrition_points'] : null;
    if (raw is! List) return [];
    return raw
        .map((e) {
          if (e is Map) {
            final text = e['nutrition_text'] ?? e['text'] ?? e['point'] ?? e['label'];
            return text?.toString() ?? '';
          }
          return e.toString();
        })
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    AppRouteTracker.instance.setCurrent(AppScreen.weeklyMenu);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().fetchWeeklyMenuSilent();
    });
  }

  @override
  void dispose() {
    AppRouteTracker.instance.clearIfCurrent(AppScreen.weeklyMenu);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('One Week Meal', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<MenuProvider>().fetchWeeklyMenu(),
        child: _buildBody(context, menuProvider, isDark),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MenuProvider menuProvider, bool isDark) {
    if (menuProvider.isLoading && menuProvider.weeklyMenu.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CupertinoActivityIndicator()),
        ],
      );
    }

    if (menuProvider.error != null && menuProvider.weeklyMenu.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orange.withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  Text('Could not load menu', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.read<MenuProvider>().fetchWeeklyMenu(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (!menuProvider.isSubscribed) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.lock_fill, size: 48, color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('Subscription Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                  const SizedBox(height: 8),
                  Text('Subscribe to view the weekly meal plan.', style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (menuProvider.weeklyMenu.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.calendar, size: 48, color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No weekly menu available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: menuProvider.weeklyMenu.length,
      itemBuilder: (context, index) {
        final menu = menuProvider.weeklyMenu[index];
        return _buildWeeklyMealCard(context, menu, index, isDark);
      },
    );
  }

  Widget _buildWeeklyMealCard(BuildContext context, dynamic menu, int index, bool isDark) {
    final imageUrl = menu['image_url']?.toString();
    final items = menu['items']?.toString() ?? menu['item_name']?.toString() ?? 'Meal';
    final menuDateRaw = menu['menu_date']?.toString() ?? '';
    final nutritionPoints = _nutritionPointsFrom(menu);
    String formattedDate = menuDateRaw;

    // Parse date to get day name
    String dayLabel = 'Day ${index + 1}';
    if (menuDateRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(menuDateRaw);
      if (parsed != null) {
        dayLabel = DateFormat('EEEE').format(parsed);
        formattedDate = DateFormat('dd MMM yyyy').format(parsed);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image — tappable for preview
          if (imageUrl != null && imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => ImagePreviewDialog.show(context, imageUrl, title: '$dayLabel — $items'),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  // Use contain so the full image is visible, not cropped
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Container(
                    height: 160,
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    child: Center(child: Icon(CupertinoIcons.photo, color: Colors.grey.withValues(alpha: 0.3), size: 32)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 100,
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    child: Center(child: Icon(CupertinoIcons.photo, color: Colors.grey.withValues(alpha: 0.3), size: 32)),
                  ),
                ),
              ),
            ),
          // Info section — compact
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Day badge + date — single compact row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dayLabel.toUpperCase(),
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
                      ),
                    ),
                    const Spacer(),
                    if (formattedDate.isNotEmpty)
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : AppTheme.textSecondaryLight),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Meal name
                Text(
                  items,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (nutritionPoints.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: nutritionPoints.map((point) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.leaf_arrow_circlepath, size: 14, color: AppTheme.primaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  point,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 60).ms).slideY(begin: 0.04, end: 0);
  }
}

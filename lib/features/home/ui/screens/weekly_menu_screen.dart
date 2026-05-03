import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WeeklyMenuScreen extends StatefulWidget {
  const WeeklyMenuScreen({super.key});

  @override
  State<WeeklyMenuScreen> createState() => _WeeklyMenuScreenState();
}

class _WeeklyMenuScreenState extends State<WeeklyMenuScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().fetchWeeklyMenu();
    });
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
      body: menuProvider.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : menuProvider.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: Colors.orange.withOpacity(0.6)),
                      const SizedBox(height: 16),
                      Text('Could not load menu', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.read<MenuProvider>().fetchWeeklyMenu(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : !menuProvider.isSubscribed
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.lock_fill, size: 48, color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text('Subscription Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                          const SizedBox(height: 8),
                          Text('Subscribe to view the weekly meal plan.', style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textSecondaryLight)),
                        ],
                      ),
                    )
                  : menuProvider.weeklyMenu.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.calendar, size: 48, color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.4)),
                              const SizedBox(height: 16),
                              Text('No weekly menu available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: menuProvider.weeklyMenu.length,
                          itemBuilder: (context, index) {
                            final menu = menuProvider.weeklyMenu[index];
                            final imageUrl = menu['image_url']?.toString();
                            final items = menu['items']?.toString() ?? menu['item_name']?.toString() ?? 'Meal';
                            final menuDate = menu['menu_date']?.toString() ?? '';
                            
                            // Parse date to get day name
                            String dayLabel = 'Day ${index + 1}';
                            if (menuDate.isNotEmpty) {
                              final parsed = DateTime.tryParse(menuDate);
                              if (parsed != null) {
                                dayLabel = DateFormat('EEEE').format(parsed);
                              }
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image
                                  if (imageUrl != null && imageUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                      child: Image.network(
                                        imageUrl,
                                        width: double.infinity,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Container(
                                          height: 80,
                                          color: AppTheme.primaryColor.withOpacity(0.05),
                                          child: Center(child: Icon(CupertinoIcons.photo, color: Colors.grey.withOpacity(0.3))),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                dayLabel.toUpperCase(),
                                                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                                              ),
                                            ),
                                            if (menuDate.isNotEmpty)
                                              Text(
                                                menuDate,
                                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : AppTheme.textSecondaryLight),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          items,
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textPrimaryLight),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.05, end: 0);
                          },
                        ),
    );
  }
}

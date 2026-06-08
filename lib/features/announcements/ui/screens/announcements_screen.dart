import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/announcement_provider.dart';
import 'package:meal_app/core/models/announcement_model.dart';
import 'package:meal_app/core/theme/app_theme.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AnnouncementProvider>();
      // Force refresh so the user always sees latest announcements
      await provider.fetchAnnouncements(location: 'home', force: true);
      await provider.markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? AppTheme.backgroundDark : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Consumer<AnnouncementProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final announcements = provider.announcements;

          if (announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.bell_slash, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 14),
                  Text(
                    'No announcements',
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You are all caught up',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            itemCount: announcements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildAnnouncementCard(announcements[index], isDark);
            },
          );
        },
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(AnnouncementModel announcement, bool isDark) {
    final isActive = announcement.isActive && !DateTime.now().isBefore(announcement.startDate) && !DateTime.now().isAfter(announcement.endDate);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? const Color(0xFF16A34A).withValues(alpha: 0.35)
              : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    announcement.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1B1C1C),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(announcement),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              announcement.message,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF584235),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(CupertinoIcons.calendar, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${_formatDate(announcement.startDate)} – ${_formatDate(announcement.endDate)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AnnouncementModel announcement) {
    String label;
    Color bgColor;
    Color textColor;

    if (!announcement.isActive) {
      label = 'Inactive';
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
    } else if (DateTime.now().isBefore(announcement.startDate)) {
      label = 'Scheduled';
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
    } else if (DateTime.now().isAfter(announcement.endDate)) {
      label = 'Expired';
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade700;
    } else {
      label = 'Active';
      bgColor = const Color(0xFF16A34A);
      textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

}

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnnouncementProvider>().fetchAnnouncements();
      _markAllAsRead();
    });
  }

  Future<void> _markAllAsRead() async {
    final provider = context.read<AnnouncementProvider>();
    for (final announcement in provider.announcements) {
      await provider.markAsRead(announcement.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : const Color(0xFFFBF9F8),
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        elevation: 0,
      ),
      body: Consumer<AnnouncementProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final announcements = provider.announcements;
          
          if (announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.bell_slash,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No announcements',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for updates',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return _buildAnnouncementCard(announcement, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(AnnouncementModel announcement, bool isDark) {
    final isActive = announcement.isActive;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isActive 
              ? AppTheme.primaryColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and status badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive 
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    announcement.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1B1C1C),
                    ),
                  ),
                ),
                _buildStatusBadge(announcement),
              ],
            ),
          ),
          // Message content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              announcement.message,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : const Color(0xFF584235),
                height: 1.5,
              ),
            ),
          ),
          // Footer with dates and location
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark 
                  ? AppTheme.surfaceDark.withOpacity(0.5)
                  : const Color(0xFFF6F3F2),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.calendar,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_formatDate(announcement.startDate)} - ${_formatDate(announcement.endDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.location,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatLocation(announcement.displayLocation),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AnnouncementModel announcement) {
    String label;
    Color bgColor;
    Color textColor;

    if (!announcement.isActive) {
      label = 'Inactive';
      bgColor = Colors.grey.shade300;
      textColor = Colors.grey.shade700;
    } else if (DateTime.now().isBefore(announcement.startDate)) {
      label = 'Scheduled';
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade700;
    } else if (DateTime.now().isAfter(announcement.endDate)) {
      label = 'Expired';
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade700;
    } else {
      label = 'Active';
      bgColor = AppTheme.primaryColor.withOpacity(0.2);
      textColor = AppTheme.primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatLocation(String location) {
    switch (location.toLowerCase()) {
      case 'home':
        return 'Home';
      case 'wallet':
        return 'Wallet';
      case 'subscriptions':
        return 'Subscriptions';
      case 'all':
        return 'All Screens';
      default:
        return location;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:meal_app/core/models/announcement_model.dart';
import 'package:meal_app/core/network/announcement_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementProvider with ChangeNotifier {
  final AnnouncementRepository _repository;

  AnnouncementProvider(this._repository);

  List<AnnouncementModel> _announcements = [];
  bool _isLoading = false;
  DateTime? _lastFetchedAt;
  Set<String> _readAnnouncementIds = {};

  List<AnnouncementModel> get announcements => _announcements;
  bool get isLoading => _isLoading;

  List<AnnouncementModel> getAnnouncementsForLocation(String location) {
    return _announcements
        .where((a) => a.displayLocation == location || a.displayLocation == 'all')
        .where((a) => a.isActive)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  List<AnnouncementModel> getUnreadAnnouncementsForLocation(String location) {
    return getAnnouncementsForLocation(location)
        .where((a) => !_readAnnouncementIds.contains(a.id))
        .toList();
  }

  int getUnreadCountForLocation(String location) {
    return getUnreadAnnouncementsForLocation(location).length;
  }

  Future<void> _loadReadAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList('read_announcement_ids');
      if (readIds != null) {
        _readAnnouncementIds = readIds.toSet();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveReadAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'read_announcement_ids',
        _readAnnouncementIds.map((id) => id.toString()).toList(),
      );
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> markAsRead(String announcementId) async {
    if (!_readAnnouncementIds.contains(announcementId)) {
      _readAnnouncementIds.add(announcementId);
      await _saveReadAnnouncements();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (final announcement in _announcements) {
      _readAnnouncementIds.add(announcement.id);
    }
    await _saveReadAnnouncements();
    notifyListeners();
  }

  Future<void> fetchAnnouncements({String? location}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadReadAnnouncements();
      _announcements = await _repository.getAnnouncements(location: location);
      _lastFetchedAt = DateTime.now();
    } catch (e) {
      // Handle error silently - announcements are optional
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool shouldRefresh() {
    if (_lastFetchedAt == null) return true;
    return DateTime.now().difference(_lastFetchedAt!).inMinutes > 30;
  }
}

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Wraps Google Play's native In-App Update API (Play Core library).
///
/// Uses the same immediate / flexible update flows shown in the Android
/// documentation and most tutorial videos, but via the `in_app_update`
/// Flutter package.
class AppUpdateService {
  AppUpdateService._();

  /// Number of days an update must be available before we force an
  /// immediate (blocking) update.  Below this threshold we use a
  /// flexible (background) update instead.
  static const int _immediateStalenessDays = 5;

  /// Call once from the home screen after the widget tree is ready.
  /// Silently returns on any error — we never want the update check
  /// to crash the app or block the user.
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      // ── DEBUG: remove these prints after testing ──
      debugPrint('[AppUpdate] updateAvailability: ${info.updateAvailability}');
      debugPrint('[AppUpdate] immediateAllowed: ${info.immediateUpdateAllowed}');
      debugPrint('[AppUpdate] availableVersionCode: ${info.availableVersionCode}');
      debugPrint('[AppUpdate] stalenessDays: ${info.clientVersionStalenessDays}');
      // ── END DEBUG ──

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        debugPrint('[AppUpdate] No update available, skipping.');
        return;
      }

      // Always use immediate (mandatory) update — user must update to continue.
      if (info.immediateUpdateAllowed) {
        debugPrint('[AppUpdate] Triggering IMMEDIATE (mandatory) update.');
        await _performImmediateUpdate();
      }
    } catch (e) {
      debugPrint('[AppUpdate] ERROR: $e');
      developer.log(
        'In-app update check failed: $e',
        name: 'AppUpdateService',
      );
    }
  }

  /// Full-screen blocking update — user must update to continue.
  static Future<void> _performImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      developer.log(
        'Immediate update failed: $e',
        name: 'AppUpdateService',
      );
    }
  }

  /// Background download — user can keep using the app.
  /// Shows a SnackBar when the download completes to prompt restart.
  static Future<void> _performFlexibleUpdate(BuildContext context) async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      // Only show restart prompt if the update was actually downloaded.
      if (result != AppUpdateResult.success) {
        debugPrint('[AppUpdate] Flexible update not completed: $result');
        return;
      }
      if (!context.mounted) return;
      _showUpdateReadySnackBar(context);
    } catch (e) {
      developer.log(
        'Flexible update failed: $e',
        name: 'AppUpdateService',
      );
    }
  }

  /// Snackbar shown after a flexible update finishes downloading.
  /// Tapping "Restart" installs the update and relaunches the app.
  static void _showUpdateReadySnackBar(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Update downloaded. Restart to apply.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'RESTART',
          textColor: Colors.white,
          onPressed: () {
            InAppUpdate.completeFlexibleUpdate();
          },
        ),
      ),
    );
  }
}

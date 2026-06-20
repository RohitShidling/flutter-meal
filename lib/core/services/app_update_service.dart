import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:meal_app/core/theme/app_theme.dart';

/// Client-side native Play Store update check (no backend settings needed).
class AppUpdateService {
  AppUpdateService._();

  static StreamSubscription<InstallStatus>? _installSubscription;

  /// Call once from the home screen after the widget tree is ready.
  static Future<void> checkForUpdate(BuildContext context) async {
    if (!Platform.isAndroid) {
      debugPrint('[AppUpdate] Native update checks are only supported on Android.');
      return;
    }

    try {
      debugPrint('[AppUpdate] Querying Play Store for update availability...');
      final info = await InAppUpdate.checkForUpdate();
      if (!context.mounted) return;
      debugPrint('[AppUpdate] Play Store updateAvailability: ${info.updateAvailability}, installStatus: ${info.installStatus}');

      // If the update has already been downloaded, immediately prompt to restart and install.
      if (info.installStatus == InstallStatus.downloaded) {
        debugPrint('[AppUpdate] Update is already downloaded. Prompting restart.');
        _showRestartSnackBar(context);
        return;
      }

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        final stalenessDays = info.clientVersionStalenessDays;
        debugPrint('[AppUpdate] Update available. Staleness days: $stalenessDays');

        // Check if update is critical/stale (45 days threshold)
        if (stalenessDays != null && stalenessDays >= 45 && info.immediateUpdateAllowed) {
          debugPrint('[AppUpdate] Staleness days >= 45. Triggering immediate update.');
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          debugPrint('[AppUpdate] Triggering flexible update.');
          if (!context.mounted) return;
          _startListening(context);
          final result = await InAppUpdate.startFlexibleUpdate();
          debugPrint('[AppUpdate] Flexible update start result: $result');
          if (result != AppUpdateResult.success) {
            _installSubscription?.cancel();
            _installSubscription = null;
          }
        } else if (info.immediateUpdateAllowed) {
          debugPrint('[AppUpdate] Flexible update not allowed, falling back to immediate.');
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      debugPrint('[AppUpdate] Native check failed: $e');
      developer.log(
        'In-app update check failed: $e',
        name: 'AppUpdateService',
      );
    }
  }

  /// Check if a downloaded update is pending installation (used on app resume).
  static Future<void> checkPendingDownloadedUpdate(BuildContext context) async {
    if (!Platform.isAndroid) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!context.mounted) return;
      debugPrint('[AppUpdate] Check pending: installStatus = ${info.installStatus}');
      if (info.installStatus == InstallStatus.downloaded) {
        _showRestartSnackBar(context);
      }
    } catch (e) {
      debugPrint('[AppUpdate] Failed checking pending update: $e');
    }
  }

  static void _startListening(BuildContext context) {
    _installSubscription?.cancel();
    _installSubscription = InAppUpdate.installUpdateListener.listen((status) {
      debugPrint('[AppUpdate] Download install status updated: $status');
      if (status == InstallStatus.downloaded) {
        if (!context.mounted) return;
        _showRestartSnackBar(context);
        _installSubscription?.cancel();
        _installSubscription = null;
      }
    });
  }

  static void _showRestartSnackBar(BuildContext context) {
    if (!context.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.removeCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.system_update_alt, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'An update has been downloaded. Restart the app to apply.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
        duration: const Duration(days: 365), // Keep open until acted upon
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'RESTART',
          textColor: Colors.white,
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (e) {
              debugPrint('[AppUpdate] Failed to complete flexible update: $e');
            }
          },
        ),
      ),
    );
  }

  static void dispose() {
    _installSubscription?.cancel();
    _installSubscription = null;
  }
}

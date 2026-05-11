import 'package:flutter/material.dart';
import 'package:meal_app/core/services/network_status_service.dart';

/// Bottom, full-width safe banner when offline (no horizontal overflow).
class OfflineBanner extends StatelessWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NetworkStatusService.instance,
      builder: (context, _) {
        final isOnline = NetworkStatusService.instance.isOnline;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (!isOnline)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.black.withValues(alpha: 0.88),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Icons.wifi_off, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You are offline. Changes will sync when you are back online.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  height: 1.25,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

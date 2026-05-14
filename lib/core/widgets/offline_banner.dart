import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/services/network_status_service.dart';

/// Bottom banner that shows when offline and a "Back online!" toast when reconnecting.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

enum _BannerMode { hidden, offline, backOnline }

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  _BannerMode _mode = _BannerMode.hidden;
  Timer? _autoDismissTimer;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slide = Tween<Offset>(begin: const Offset(0, 1.12), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    NetworkStatusService.instance.addListener(_onNetworkChange);

    // Show immediately if already offline at build time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!NetworkStatusService.instance.isOnline) {
        _show(_BannerMode.offline);
      }
    });
  }

  @override
  void dispose() {
    NetworkStatusService.instance.removeListener(_onNetworkChange);
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _show(_BannerMode mode) {
    if (!mounted) return;
    setState(() => _mode = mode);
    _controller.forward();
  }

  void _hide() {
    _controller.reverse().then((_) {
      if (mounted) setState(() => _mode = _BannerMode.hidden);
    });
  }

  void _onNetworkChange() {
    if (!mounted) return;
    final isOnline = NetworkStatusService.instance.isOnline;
    _autoDismissTimer?.cancel();

    if (!isOnline) {
      // Went offline — show offline banner
      _show(_BannerMode.offline);
    } else {
      // Came back online — show "Back Online!" for 4.5 seconds, then auto-hide
      _show(_BannerMode.backOnline);
      _autoDismissTimer = Timer(const Duration(milliseconds: 4500), _hide);
    }
  }

  void _userDismiss() => _hide();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_mode == _BannerMode.hidden && !_controller.isAnimating) {
      return widget.child;
    }

    final isBackOnline = _mode == _BannerMode.backOnline;

    final bannerColor = isBackOnline
        ? Color.alphaBlend(
            Colors.green.withValues(alpha: isDark ? 0.22 : 0.14),
            theme.colorScheme.surface,
          )
        : Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.1),
            theme.colorScheme.surface,
          );

    final iconColor = isBackOnline ? Colors.green : theme.colorScheme.error;
    final iconBg = isBackOnline
        ? Colors.green.withValues(alpha: isDark ? 0.22 : 0.14)
        : theme.colorScheme.errorContainer.withValues(alpha: isDark ? 0.5 : 0.65);
    final textColor = theme.colorScheme.onSurface;

    final icon = isBackOnline ? CupertinoIcons.wifi : CupertinoIcons.wifi_slash;
    final message = isBackOnline
        ? 'Back online! Your data is refreshing.'
        : 'No internet connection. Check your Wi‑Fi or mobile data.';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SafeArea(
                top: false,
                minimum: EdgeInsets.zero,
                child: GestureDetector(
                  onVerticalDragUpdate: (d) {
                    if (d.delta.dy > 10) _userDismiss();
                  },
                  onHorizontalDragUpdate: (d) {
                    if (d.delta.dx.abs() > 12) _userDismiss();
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Material(
                      elevation: 10,
                      borderRadius: BorderRadius.circular(16),
                      color: bannerColor.withValues(alpha: 0.97),
                      shadowColor: Colors.black.withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: iconColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.94),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                                maxLines: 3,
                                softWrap: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: _userDismiss,
                              icon: Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 20,
                                color: textColor.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

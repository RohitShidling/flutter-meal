import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/services/network_status_service.dart';

/// Bottom banner when there is no network; swipe to dismiss.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> with SingleTickerProviderStateMixin {
  bool _wasOffline = false;
  bool _dismissed = false;
  Timer? _autoDismissTimer;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _wasOffline = !NetworkStatusService.instance.isOnline;
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
    _slide = Tween<Offset>(begin: const Offset(0, 1.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    NetworkStatusService.instance.addListener(_onNetworkChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!NetworkStatusService.instance.isOnline && !_dismissed) {
        _controller.forward();
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

  void _onNetworkChange() {
    if (!mounted) return;
    final isOnline = NetworkStatusService.instance.isOnline;
    final isOffline = !isOnline;

    if (isOffline && !_wasOffline) {
      _autoDismissTimer?.cancel();
      setState(() {
        _dismissed = false;
        _wasOffline = true;
      });
      _controller.forward();
    } else if (isOnline && _wasOffline) {
      _wasOffline = false;
      _autoDismissTimer?.cancel();
      // Smooth dismiss as soon as we are reachable again (no lingering “offline” copy).
      if (!_dismissed) {
        _controller.reverse();
      }
      // After a short beat, clear manual dismiss so the next offline spell shows again.
      _autoDismissTimer = Timer(const Duration(milliseconds: 2400), () {
        if (!mounted) return;
        setState(() => _dismissed = false);
      });
    }
    setState(() {/* repaint */});
  }

  void _userDismiss() {
    if (_dismissed) return;
    setState(() => _dismissed = true);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isOffline = !NetworkStatusService.instance.isOnline;
    final visible = isOffline && !_dismissed;

    final bannerColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.1),
      colorScheme.surface,
    );
    final iconBg = colorScheme.errorContainer.withValues(alpha: isDark ? 0.5 : 0.65);
    final iconColor = colorScheme.error;
    final textColor = colorScheme.onSurface;

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
              child: IgnorePointer(
                ignoring: !visible && !_controller.isAnimating,
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
                        elevation: visible ? 10 : 0,
                        borderRadius: BorderRadius.circular(16),
                        color: bannerColor.withValues(alpha: 0.97),
                        shadowColor: Colors.black.withValues(alpha: 0.12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: iconBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  CupertinoIcons.wifi_slash,
                                  color: iconColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No internet connection. Check your Wi‑Fi or mobile data.',
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
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
        ),
      ],
    );
  }
}

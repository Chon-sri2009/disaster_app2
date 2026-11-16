import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

// A big round SOS button: hold it about 1.5 s while a ring fills, with haptic feedback, to confirm.
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    super.key,
    required this.onConfirmed,
    required this.busy,
    required this.diameter,
  });

  final VoidCallback onConfirmed;
  final bool busy;
  final double diameter;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

// Drives the hold timer: forward while a finger is down, back when it lifts early.
class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  static const double _ring = 10;

  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: AppMotion.sosHold,
    reverseDuration: AppMotion.base,
  )..addStatusListener(_onStatus);

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  // When the ring completes: strong haptic, tell the screen, then reset the ring.
  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.heavyImpact();
    widget.onConfirmed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hold.value = 0;
    });
  }

  // Finger down: gentle haptic and start filling the ring.
  void _down() {
    if (widget.busy) return;
    HapticFeedback.mediumImpact();
    _hold.forward();
  }

  // Finger up or cancelled before the end: empty the ring (instantly if animations are off).
  void _release() {
    if (_hold.isCompleted || _hold.isDismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _hold.value = 0;
    } else {
      _hold.reverse();
    }
  }

  // Screen-reader users confirm with a long-press action instead of holding a finger.
  void _confirmFromScreenReader() {
    if (widget.busy) return;
    HapticFeedback.heavyImpact();
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      enabled: !widget.busy,
      label: 'SOS emergency',
      hint: 'Press and hold for 1.5 seconds to send your location',
      onLongPress: widget.busy ? null : _confirmFromScreenReader,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: SizedBox.square(
          dimension: widget.diameter,
          child: AnimatedBuilder(
            animation: _hold,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: widget.busy ? null : _hold.value,
                  strokeWidth: _ring,
                  strokeCap: StrokeCap.round,
                  color: t.ink,
                  backgroundColor: t.hairline,
                ),
                Padding(
                  padding: const EdgeInsets.all(_ring + AppSpace.sm),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.sm),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'SOS',
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: t.onDanger,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

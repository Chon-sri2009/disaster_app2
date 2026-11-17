import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme/app_tokens.dart';

// The SOS card: a rounded red card with a soft red glow. Hold it about 1.5 s while a white bar
// fills across its foot, with haptic feedback, to confirm. A short tap does nothing.
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    super.key,
    required this.onConfirmed,
    required this.busy,
    required this.height,
  });

  final VoidCallback onConfirmed;
  final bool busy;
  final double height;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

// Drives the hold timer: forward while a finger is down, back when it lifts early.
class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  static const double _bar = AppSize.sosBar;
  static final BorderRadius _pill = BorderRadius.circular(AppRadius.pill);

  Color get _track => context.tokens.onDanger.withValues(alpha: 0.3);

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

  // When the bar completes: strong haptic, tell the screen, then reset the bar.
  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.heavyImpact();
    widget.onConfirmed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hold.value = 0;
    });
  }

  // Finger down: gentle haptic and start filling the bar.
  void _down() {
    if (widget.busy) return;
    HapticFeedback.mediumImpact();
    _hold.forward();
  }

  // Finger up or cancelled before the end: empty the bar (instantly if animations are off).
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
    final hint = widget.busy
        ? context.tr(th: 'กำลังหาตำแหน่งของคุณ…', en: 'Finding your location…')
        : context.tr(
            th: 'กดค้าง 1.5 วินาทีเพื่อส่งตำแหน่ง',
            en: 'Hold 1.5 seconds to share your location',
          );
    return Semantics(
      button: true,
      enabled: !widget.busy,
      label: context.tr(th: 'SOS ฉุกเฉิน', en: 'SOS emergency'),
      hint: context.tr(
        th: 'กดค้าง 1.5 วินาทีเพื่อส่งตำแหน่งของคุณ',
        en: 'Press and hold for 1.5 seconds to send your location',
      ),
      onLongPress: widget.busy ? null : _confirmFromScreenReader,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: Container(
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: t.danger,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            // A surface ring keeps the card apart from a red header band at danger level.
            border: Border.all(color: t.surface, width: AppStroke.frame),
            boxShadow: [
              BoxShadow(
                color: t.danger.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  child: Row(
                    children: [
                      // The 48 sp word is large at any setting; holding it there leaves the
                      // instruction room to stay whole when the phone's text is enlarged.
                      MediaQuery.withNoTextScaling(
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
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          hint,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: t.onDanger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The hold bar: a white pill filling along a faint white track at the card's foot.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  0,
                  AppSpace.md,
                  AppSpace.sm + AppSpace.xs,
                ),
                child: SizedBox(
                  height: _bar,
                  child: widget.busy
                      ? LinearProgressIndicator(
                          minHeight: _bar,
                          color: t.onDanger,
                          backgroundColor: _track,
                          borderRadius: _pill,
                        )
                      : AnimatedBuilder(
                          animation: _hold,
                          builder: (context, _) => LinearProgressIndicator(
                            value: _hold.value,
                            minHeight: _bar,
                            color: t.onDanger,
                            backgroundColor: _track,
                            borderRadius: _pill,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

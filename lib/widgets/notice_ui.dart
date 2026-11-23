import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alert_level.dart';
import '../theme/app_tokens.dart';

// Posted-notice widgets: flat, square and ruled. Colour is only ever state; every state also
// carries an icon and a word. All strings come in as parameters.

// Plain screen title on the ground, with an optional trailing action (kept at 48 dp).
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(
    this.title, {
    super.key,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final Widget? trailing;

  // Short screens and large text: a smaller title with less padding, so the content under it
  // keeps its room.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 0 : AppSpace.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.tapTarget),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: compact
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpace.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// A title over a hairline rule, then plain children. Space above, no box.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.title,
    this.children = const [],
    this.ruleColor,
    this.titleColor,
  });

  final String title;
  final List<Widget> children;

  // A thick rule above the title to mark a group (Guide's first aid); the word still carries
  // the meaning. titleColor is for text on the ground, so it must be an on-ground colour.
  final Color? ruleColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ruleColor != null)
            SizedBox(
              height: AppStroke.accent,
              child: ColoredBox(
                key: const ValueKey('section-rule'),
                color: ruleColor!,
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              top: ruleColor == null ? 0 : AppSpace.sm,
              bottom: AppSpace.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: titleColor),
              ),
            ),
          ),
          Container(height: AppStroke.rule, color: t.hairline),
          ...children,
        ],
      ),
    );
  }
}

// One list row: a bare icon, title, optional subtitle and trailing, a hairline under it.
class RuledRow extends StatelessWidget {
  const RuledRow({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.selected,
    this.titleStyle,
    this.subtitleStyle,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final String title;
  final IconData? icon;

  // Replaces the icon (a step number, say). Use one or the other.
  final Widget? leading;

  // Override the default row title / subtitle styles (a big phone number, a sentence).
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  // Start for rows of running text (numbered steps), so the number sits by the first line.
  final CrossAxisAlignment crossAxisAlignment;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  // Replaces the spoken text of the whole row when the visible words alone are not enough.
  final String? semanticLabel;

  // Set for a row that is one choice of a group (language, theme): spoken as chosen or not. The
  // row itself shows the choice with its own check icon, never colour alone.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final row = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.hairline, width: AppStroke.rule),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.tapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          // The trailing mark takes only the width it needs, up to half the row (a long tag
          // wraps there), so the title keeps the rest and Thai titles wrap late.
          child: LayoutBuilder(
            builder: (context, box) => Row(
              crossAxisAlignment: crossAxisAlignment,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpace.md),
                ] else if (icon != null) ...[
                  Icon(icon, size: AppIconSize.md, color: t.mark),
                  const SizedBox(width: AppSpace.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle ?? text.titleSmall),
                      if (subtitle != null)
                        Text(subtitle!, style: subtitleStyle ?? text.bodySmall),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpace.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
                    child: trailing!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    final tappable = onTap == null
        ? row
        : InkWell(onTap: onTap, hoverColor: t.pressed, child: row);
    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      inMutuallyExclusiveGroup: selected == null ? null : true,
      label: semanticLabel,
      // Own tap action where excludeSemantics hides the InkWell's, so a screen reader can still
      // activate the row. Unlabelled rows keep the InkWell's own node (it carries the words).
      onTap: semanticLabel != null ? onTap : null,
      excludeSemantics: semanticLabel != null,
      child: tappable,
    );
  }
}

// A square-cornered label: optional icon plus a word. Outlined by default; pass onColor to fill
// it with color. Wraps rather than shrinks.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.icon, this.color, this.onColor});

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final edge = color ?? t.mark;
    final filled = onColor != null;
    final fg = onColor ?? t.ink;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? edge : edge.withValues(alpha: 0.12),
        border: Border.all(color: edge, width: AppStroke.rule),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppIconSize.sm, color: fg),
              const SizedBox(width: AppSpace.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Vertical staff gauge: four equal blocks with even gaps, danger at the top and the lowest tier at
// the bottom (water rises). It stretches to the height it is given. The current tier is filled,
// the rest are outlined. A null level (no data) leaves every block empty. The level word beside
// it carries the meaning, so screen readers skip this.
class LevelGauge extends StatelessWidget {
  const LevelGauge({
    super.key,
    required this.level,
    this.outline,
    this.fill,
    this.stretch = false,
    this.minStep = AppSize.gaugeStep,
  });

  final AlertLevel? level;

  // Overrides for use on a filled slab, where the tier colour would vanish.
  final Color? outline;
  final Color? fill;

  // True where the parent gives a finite height (the slab does): the blocks share it. False
  // keeps each block at its minimum height.
  final bool stretch;

  // Smallest height of one block.
  final double minStep;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minStep * 4 + AppSpace.xs * 3),
        child: SizedBox(
          width: AppSize.gaugeWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final step in AlertLevel.values.reversed) ...[
                if (step != AlertLevel.values.last)
                  const SizedBox(height: AppSpace.xs),
                if (stretch)
                  Expanded(child: _block(t, step))
                else
                  SizedBox(height: minStep, child: _block(t, step)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(AppTokens t, AlertLevel step) {
    final current = step == level;
    final tierRule = t.styleFor(step).rule;
    final edge = outline ?? (current ? tierRule : t.mark);
    return Container(
      key: ValueKey('gauge-${step.name}${current ? '-filled' : ''}'),
      decoration: BoxDecoration(
        color: current ? (fill ?? tierRule) : null,
        border: Border.all(color: edge, width: AppStroke.frame),
      ),
    );
  }
}

// The Home level slab, edge to edge. Quiet tiers (safe, watch, no data) sit on the ground under a
// thick rule; warning and danger fill with the tier colour. No data is neutral: never green,
// never red.
class LevelSlab extends StatelessWidget {
  const LevelSlab({
    super.key,
    required this.level,
    required this.label,
    required this.advice,
    required this.sources,
    required this.posted,
    this.step,
    this.area,
    this.compact = false,
  });

  final AlertLevel? level;
  final String label;
  final String? step;
  final String advice;
  final List<String> sources;
  final String posted;

  // Spoken only; part of the one screen-reader sentence.
  final String? area;

  // Short screens and large text: less padding above and below, so the advice stays in view.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final style = level == null ? null : t.styleFor(level!);
    final loud = level == AlertLevel.warning || level == AlertLevel.danger;
    final watch = level == AlertLevel.watch;
    final ink = loud ? style!.onColor : t.ink;
    final muted = loud ? style!.onColor : t.inkMuted;
    final wordColor = loud ? style!.onColor : (style?.onGround ?? t.ink);
    final ruleColor = style?.rule ?? t.mark;
    final icon = style?.icon ?? Icons.sensors_off;
    final iconColor = loud || watch
        ? style!.onColor
        : (style?.onGround ?? t.mark);
    final glyph = Icon(icon, size: AppIconSize.lg, color: iconColor);
    return Semantics(
      container: true,
      liveRegion: true,
      // DRAFT (Phase R, owner to approve): the spoken sentence is now area, tier word, step, advice,
      // sources (one per sentence); the posted time was dropped from it, see below.
      // The posted time is not in this label: a live region re-reads on every change, and the
      // time moves on each refresh. It is its own node below, read on focus.
      label:
          '${area == null ? '' : '$area, '}$label. ${step ?? ''} '
          '$advice. ${sources.join('. ')}',
      child: AnimatedContainer(
        duration: context.motion(AppMotion.base),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: compact ? AppSpace.sm : AppSpace.md,
        ),
        decoration: BoxDecoration(
          color: loud ? style!.color : t.ground,
          border: loud
              ? null
              : Border(
                  top: BorderSide(color: ruleColor, width: AppStroke.slab),
                ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: LevelGauge(
                  level: level,
                  outline: loud ? style!.onColor : null,
                  fill: loud ? style!.onColor : null,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (watch)
                                Container(
                                  key: const ValueKey('watch-icon-block'),
                                  padding: const EdgeInsets.all(AppSpace.xs),
                                  color: style!.color,
                                  child: glyph,
                                )
                              else
                                glyph,
                              const SizedBox(width: AppSpace.sm),
                              Expanded(
                                child: Text(
                                  label,
                                  style: text.displayMedium?.copyWith(
                                    color: wordColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (step != null)
                            Text(
                              step!,
                              style: text.bodySmall?.copyWith(color: muted),
                            ),
                          SizedBox(height: compact ? AppSpace.xs : AppSpace.sm),
                          Text(
                            advice,
                            style: text.bodyLarge?.copyWith(
                              color: ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: compact ? AppSpace.xs : AppSpace.sm),
                          for (final line in sources)
                            Text(
                              line,
                              style: text.bodySmall?.copyWith(color: muted),
                            ),
                        ],
                      ),
                    ),
                    Semantics(
                      container: true,
                      label: posted,
                      child: ExcludeSemantics(
                        child: Text(
                          posted,
                          style: text.bodySmall?.copyWith(color: muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The SOS bar: a full-width square red bar. Hold about 1.5 s while a bar fills along its base,
// with haptics, to confirm. A short tap does nothing. Screen readers confirm with long-press.
// Logic follows SosHoldButton.
class SosBar extends StatefulWidget {
  const SosBar({
    super.key,
    required this.onConfirmed,
    required this.busy,
    required this.height,
    required this.hint,
    this.semanticLabel,
    this.semanticHint,
  });

  final VoidCallback onConfirmed;
  final bool busy;

  // Minimum height; it grows if the hint needs more room at large text.
  final double height;
  final String hint;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  State<SosBar> createState() => _SosBarState();
}

class _SosBarState extends State<SosBar> with SingleTickerProviderStateMixin {
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

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.heavyImpact();
    widget.onConfirmed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hold.value = 0;
    });
  }

  // Where the finger went down. The bar is pinned in a scrolling page, so a drag that starts
  // here is a scroll, not a hold: past the touch slop the hold is cancelled.
  Offset? _downAt;

  void _down(Offset at) {
    if (widget.busy) return;
    _downAt = at;
    HapticFeedback.mediumImpact();
    _hold.forward();
  }

  void _move(Offset at) {
    final start = _downAt;
    if (start == null) return;
    if ((at - start).distance > kTouchSlop) {
      _downAt = null;
      _release();
    }
  }

  void _release() {
    if (_hold.isCompleted || _hold.isDismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _hold.value = 0;
    } else {
      _hold.reverse();
    }
  }

  void _confirmFromScreenReader() {
    if (widget.busy) return;
    HapticFeedback.heavyImpact();
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final track = t.onDanger.withValues(alpha: 0.3);
    return Semantics(
      button: true,
      enabled: !widget.busy,
      label: widget.semanticLabel ?? 'SOS',
      hint: widget.semanticHint,
      onLongPress: widget.busy ? null : _confirmFromScreenReader,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (e) => _down(e.position),
        onPointerMove: (e) => _move(e.position),
        onPointerUp: (_) {
          _downAt = null;
          _release();
        },
        onPointerCancel: (_) {
          _downAt = null;
          _release();
        },
        child: Container(
          constraints: BoxConstraints(minHeight: widget.height),
          color: t.danger,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Row(
                  children: [
                    Text(
                      'SOS',
                      style: text.displayMedium?.copyWith(color: t.onDanger),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Text(
                        widget.hint,
                        style: text.titleSmall?.copyWith(color: t.onDanger),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: AppSize.sosBar,
                child: widget.busy
                    ? LinearProgressIndicator(
                        minHeight: AppSize.sosBar,
                        color: t.onDanger,
                        backgroundColor: track,
                      )
                    : AnimatedBuilder(
                        animation: _hold,
                        builder: (context, _) => LinearProgressIndicator(
                          value: _hold.value,
                          minHeight: AppSize.sosBar,
                          color: t.onDanger,
                          backgroundColor: track,
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

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/alert_level.dart';
import '../theme/app_tokens.dart';

// The 4-step level scale as rounded segments. Steps up to the current level are solid in their
// own tier color; the rest are empty. The current step is taller and carries its word in bold.
class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.level});

  // Null when there is no live data: every cell stays empty.
  final AlertLevel? level;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final current = level?.index ?? -1;
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in AlertLevel.values) ...[
            if (step.index > 0) const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: AppSize.meterHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: step.index == current
                            ? AppSize.meterHeight
                            : AppSize.meterHeight / 2,
                        decoration: BoxDecoration(
                          color: step.index <= current
                              ? t.styleFor(step).color
                              : t.hairline,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  // Thai words must not break mid-syllable in a narrow cell: shrink instead.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.levelLabel(step),
                      maxLines: 1,
                      style: step.index == current
                          ? text.labelMedium
                          : text.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// The same segment scale for a measured value: filled segments up to the value, an ink post at
// the safe limit, and filled segments past the limit in the danger color.
class SegmentedGauge extends StatelessWidget {
  const SegmentedGauge({
    super.key,
    required this.value,
    required this.max,
    required this.limit,
    this.cells = 10,
  });

  final double value;
  final double max;
  final double limit;
  final int cells;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filled = (value / max * cells).clamp(0, cells).round();
    final limitCell = (limit / max * cells).round();
    return ExcludeSemantics(
      child: SizedBox(
        height: AppSize.meterHeight + AppSpace.sm,
        child: Row(
          children: [
            for (var i = 0; i < cells; i++) ...[
              if (i == limitCell)
                Container(
                  width: AppStroke.accent,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppStroke.frame,
                  ),
                  decoration: BoxDecoration(
                    color: t.ink,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                )
              else if (i > 0)
                const SizedBox(width: AppStroke.frame),
              Expanded(
                child: AnimatedContainer(
                  duration: context.motion(AppMotion.base),
                  height: AppSize.meterHeight,
                  decoration: BoxDecoration(
                    color: i < filled
                        ? (i >= limitCell ? t.danger : t.brand)
                        : t.hairline,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

// A block on the notice board: square, framed in ink, on raised paper unless given a field color.
class NoticeFrame extends StatelessWidget {
  const NoticeFrame({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.borderWidth = AppStroke.frame,
    this.padding = const EdgeInsets.all(AppSpace.md),
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // The frame paints over the content, so a filled header strip never hides it.
    return Container(
      color: color ?? t.surface,
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: borderColor ?? t.ink, width: borderWidth),
      ),
      padding: padding,
      child: child,
    );
  }
}

// A framed block that is also a button: ink ripple inside the frame, at least 48 dp.
class NoticeTile extends StatelessWidget {
  const NoticeTile({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.selected = false,
    this.padding = const EdgeInsets.all(AppSpace.md),
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.ground : t.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: selected ? t.ink : t.surface,
        shape: RoundedRectangleBorder(side: t.frame),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSize.tapTarget,
              minWidth: AppSize.tapTarget,
            ),
            child: Padding(
              padding: padding,
              child: IconTheme.merge(
                data: IconThemeData(color: fg),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: fg),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// The title strip at the top of a tab: heavy title, optional action, a 3 dp rule beneath.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.ink, width: AppStroke.heavy),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.sm,
          AppSpace.xs,
          AppSpace.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                // One line at any text size: a long title shrinks rather than wrapping, so the
                // pinned SOS below it keeps its place on small phones.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// A section label ruled across the board: "Label ———————". The rule runs the full width behind
// the label, which sits on a patch of the board color, so a long Thai label keeps the whole
// width and the rule never squeezes it.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.background});

  final String text;

  // The color the label sits on; defaults to the board (ground). Sheets pass their surface.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.sm),
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          Positioned.fill(
            child: Center(
              child: Container(height: AppStroke.frame, color: t.ink),
            ),
          ),
          Container(
            color: background ?? t.ground,
            padding: const EdgeInsetsDirectional.only(end: AppSpace.sm),
            child: Semantics(
              header: true,
              child: Text(text, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
        ],
      ),
    );
  }
}

// A small ink tag with ground-colored text, e.g. "nearest".
class NoticeTag extends StatelessWidget {
  const NoticeTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      color: t.ink,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppStroke.frame,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: t.ground),
      ),
    );
  }
}

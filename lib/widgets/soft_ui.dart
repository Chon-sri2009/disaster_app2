import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

// A white rounded card on the canvas with a soft shadow. An optional outline marks a state
// (selected, over a limit) on top of its icon and text, never alone.
class SoftCard extends StatelessWidget {
  const SoftCard({
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
    final outline = borderColor;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? t.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: t.cardShadow,
      ),
      foregroundDecoration: outline == null
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: outline, width: borderWidth),
            ),
      padding: padding,
      child: child,
    );
  }
}

// A rounded card that is also a button: ripple inside the card, at least 48 dp. Selected tiles
// fill with the brand tint and gain a brand outline.
class SoftTile extends StatelessWidget {
  const SoftTile({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.selected = false,
    this.flat = false,
    this.padding = const EdgeInsets.all(AppSpace.md),
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool selected;

  // Flat tiles sit inside a white card: canvas-filled, no shadow.
  final bool flat;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: selected
          ? BorderSide(color: t.brand, width: AppStroke.frame)
          : BorderSide.none,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: flat ? null : t.cardShadow,
        ),
        child: Material(
          color: selected ? t.brandSoft : (flat ? t.ground : t.surface),
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSize.tapTarget,
                minWidth: AppSize.tapTarget,
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

// The colored band at the top of a tab: an optional small line above the title (a date, an
// area), the title, and an action on the right. It paints behind the status bar. Anything in
// [below] (Home's SOS) overlaps the band's lower edge, half on the band and half on the canvas.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.below,
    this.color,
    this.onColor,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;
  final Widget? below;

  // The band and its text colors; default to the brand header. Home passes a tier's colors.
  final Color? color;
  final Color? onColor;

  static const double _overlap = AppSpace.xl;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final band = color ?? t.header;
    final fg = onColor ?? t.onHeader;
    final muted = onColor == null ? t.onHeaderMuted : fg;
    final top = MediaQuery.paddingOf(context).top;
    final light = ThemeData.estimateBrightnessForColor(band) == Brightness.dark;
    final line = eyebrow;
    final extra = below;
    final bar = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.md,
        top + AppSpace.sm,
        AppSpace.xs,
        extra == null ? AppSpace.md : AppSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line != null)
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(color: muted),
                  ),
                Semantics(
                  header: true,
                  // One line at any text size: a long title shrinks rather than wrapping.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: text.headlineSmall?.copyWith(color: fg),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Actions on the band are round buttons on a light wash of the text color.
          if (trailing != null)
            IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: fg,
                  backgroundColor: fg.withValues(alpha: 0.14),
                  minimumSize: const Size(AppSize.tapTarget, AppSize.tapTarget),
                  shape: const CircleBorder(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpace.sm),
                child: trailing!,
              ),
            ),
        ],
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: light ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: AnimatedContainer(
        duration: context.motion(AppMotion.slow),
        color: extra == null ? band : Colors.transparent,
        child: extra == null
            ? bar
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: context.motion(AppMotion.slow),
                    color: band,
                    child: bar,
                  ),
                  Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: _overlap,
                        child: AnimatedContainer(
                          duration: context.motion(AppMotion.slow),
                          color: band,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md,
                        ),
                        child: extra,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// A section heading: the title, and an optional pill or action at the end. Inside a card it
// sits flush with the card's top padding.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.inCard = false,
  });

  final String text;
  final Widget? trailing;
  final bool inCard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: inCard ? 0 : AppSpace.lg,
        bottom: AppSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// A small rounded pill: a status, a distance, "sample". Text always; icon optional.
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.icon, this.color, this.onColor});

  final String text;
  final IconData? icon;

  // Defaults to the brand tint with brand text.
  final Color? color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = onColor ?? t.brand;
    return Container(
      decoration: BoxDecoration(
        color: color ?? t.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm + AppSpace.xs,
        vertical: AppSpace.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIconSize.sm - AppSpace.xs, color: fg),
            const SizedBox(width: AppSpace.xs),
          ],
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

// One row in a card: a thin colored bar at the start, optional leading mark, a bold title over a
// muted line, and an optional trailing pill or chevron. Tappable when [onTap] is set.
class AccentRow extends StatelessWidget {
  const AccentRow({
    super.key,
    required this.title,
    this.subtitle,
    this.accent,
    this.leading,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.titleStyle,
  });

  final String title;
  final String? subtitle;

  // The bar's color; defaults to the hairline.
  final Color? accent;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final sub = subtitle;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.tapTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: AppStroke.accent,
                decoration: BoxDecoration(
                  color: accent ?? t.hairline,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(width: AppSpace.sm + AppSpace.xs),
              if (leading != null) ...[
                Center(child: leading),
                const SizedBox(width: AppSpace.sm + AppSpace.xs),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle ?? text.titleSmall),
                    if (sub != null) Text(sub, style: text.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.sm),
                Center(child: trailing),
              ],
            ],
          ),
        ),
      ),
    );
    final tap = onTap;
    final body = tap == null
        ? row
        : InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: row,
          );
    return Semantics(
      button: tap != null,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: body,
    );
  }
}

// A round icon with its label underneath, for a horizontal row of shortcuts.
class RoundChip extends StatelessWidget {
  const RoundChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.semanticLabel,
    this.color,
    this.onColor,
  });

  final IconData icon;
  final String label;

  // A second, smaller line under the label (what the number is).
  final String? caption;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? color;
  final Color? onColor;

  static const double _size = AppSize.primaryButton;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: color ?? t.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: onColor ?? t.brand),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: t.inkMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// A card that folds open: a title with a count and a chevron, then its rows.
class CollapsibleCard extends StatelessWidget {
  const CollapsibleCard({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded = true,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            0,
            AppSpace.md,
            AppSpace.sm,
          ),
          children: children,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

// The calm status kinds a notice can show: information, offline, or an error.
enum BannerKind { info, offline, error }

// A flat ruled block with an icon, the words, an optional action, and screen-reader support.
// Info is outlined in ink on the ground, offline sits on a quiet grey tint with a hairline
// (offline is normal, never an alarm), and errors take a red tint with a danger outline.
class WarningBanner extends StatelessWidget {
  const WarningBanner({
    super.key,
    required this.message,
    this.kind = BannerKind.info,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final BannerKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (background, border, width, icon) = switch (kind) {
      BannerKind.info => (t.ground, t.ink, AppStroke.frame, Icons.info_outline),
      BannerKind.offline => (
        t.offlineBg,
        t.hairline,
        AppStroke.rule,
        Icons.cloud_off,
      ),
      BannerKind.error => (
        t.errorBg,
        t.dangerInk,
        AppStroke.frame,
        Icons.error_outline,
      ),
    };
    final action = onAction;
    return Semantics(
      container: true,
      liveRegion: kind != BannerKind.info,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border, width: width),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  color: kind == BannerKind.error ? t.dangerInk : t.ink,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (action != null && actionLabel != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: action,
                          child: Text(actionLabel!),
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

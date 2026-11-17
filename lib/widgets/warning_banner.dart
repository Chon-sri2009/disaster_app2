import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

// The calm status kinds a notice can show: information, offline, or an error.
enum BannerKind { info, offline, error }

// A framed status notice with an icon, optional action, and screen-reader support.
// Info sits on plain paper, offline on a quiet grey tint with a light rule (offline is normal,
// never an alarm), and errors on a red tint with a danger frame.
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
    final (background, border, icon) = switch (kind) {
      BannerKind.info => (t.surface, t.ink, Icons.info_outline),
      BannerKind.offline => (t.offlineBg, t.hairline, Icons.cloud_off),
      BannerKind.error => (t.errorBg, t.dangerInk, Icons.error_outline),
    };
    final action = onAction;
    return Semantics(
      container: true,
      liveRegion: kind != BannerKind.info,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border, width: AppStroke.frame),
        ),
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
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
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
    );
  }
}

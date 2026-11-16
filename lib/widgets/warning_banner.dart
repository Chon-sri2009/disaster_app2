import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

// The calm status kinds a banner can show: information, offline, or an error.
enum BannerKind { info, offline, error }

// A full-width status message with an icon, optional action button, and screen-reader support.
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
    final (background, icon) = switch (kind) {
      BannerKind.info => (t.infoBg, Icons.info),
      BannerKind.offline => (t.offlineBg, Icons.cloud_off),
      BannerKind.error => (t.errorBg, Icons.error),
    };
    final action = onAction;
    return Semantics(
      container: true,
      liveRegion: kind != BannerKind.info,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, color: t.ink)),
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

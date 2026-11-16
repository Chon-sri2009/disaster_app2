import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

// Centers its child and caps the width so text lines stay readable on tablets.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
        child: child,
      ),
    );
  }
}

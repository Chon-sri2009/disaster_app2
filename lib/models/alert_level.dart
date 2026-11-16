import 'package:flutter/material.dart';

// The four alert levels shown to residents, each with a label, colour, icon and advice.
enum AlertLevel {
  safe('SAFE', Color(0xFF2E7D32), Icons.check_circle, 'No action needed.'),
  watch(
    'WATCH',
    Color(0xFFEF6C00),
    Icons.warning_amber_rounded,
    'Stay alert and get ready to move.',
  ),
  warning(
    'WARNING',
    Color(0xFFD84315),
    Icons.warning,
    'Prepare to leave. Follow official instructions.',
  ),
  danger(
    'DANGER',
    Color(0xFFC62828),
    Icons.dangerous,
    'Evacuate to a shelter now!',
  );

  const AlertLevel(this.label, this.color, this.icon, this.advice);

  final String label;
  final Color color;
  final IconData icon;
  final String advice;
}

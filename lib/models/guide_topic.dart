import 'package:flutter/material.dart';

// One first-aid or evacuation topic: a title, an icon and a short list of steps.
class GuideTopic {
  const GuideTopic({
    required this.title,
    required this.icon,
    required this.steps,
  });

  final String title;
  final IconData icon;
  final List<String> steps;
}

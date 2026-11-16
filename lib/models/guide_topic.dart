import 'package:flutter/material.dart';

// One first-aid or evacuation topic: a title, an icon and a short list of steps, in both languages.
class GuideTopic {
  const GuideTopic({
    required this.title,
    required this.titleTh,
    required this.icon,
    required this.steps,
    required this.stepsTh,
  });

  final String title;
  final String titleTh;
  final IconData icon;
  final List<String> steps;
  final List<String> stepsTh;
}

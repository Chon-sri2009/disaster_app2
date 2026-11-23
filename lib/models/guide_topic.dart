import 'package:flutter/material.dart';

// Which shelf of the guide a topic sits on.
enum GuideKind { disaster, firstAid }

// One first-aid or evacuation topic: a title, an icon and a short list of steps, in both languages.
class GuideTopic {
  const GuideTopic({
    required this.title,
    required this.titleTh,
    required this.icon,
    required this.kind,
    required this.steps,
    required this.stepsTh,
  });

  final String title;
  final String titleTh;
  final IconData icon;
  final GuideKind kind;
  final List<String> steps;
  final List<String> stepsTh;
}

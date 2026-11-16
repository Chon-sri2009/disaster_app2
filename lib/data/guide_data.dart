import 'package:flutter/material.dart';

import '../models/guide_topic.dart';

// Bundled offline guide content (not mock data; it ships inside the app).
class GuideData {
  GuideData._();

  static const List<GuideTopic> topics = [
    GuideTopic(
      title: 'Before a flood: get ready',
      icon: Icons.backpack,
      steps: [
        'Pack a go-bag: water, food, torch, radio, power bank, medicines, copies of ID.',
        'Know the nearest shelter and two routes to reach it.',
        'Agree on a family meeting point and save emergency numbers on paper.',
        'Move valuables and electronics to a high place.',
      ],
    ),
    GuideTopic(
      title: 'During a flood',
      icon: Icons.flood,
      steps: [
        'Move to higher ground immediately. Do not wait for the water to reach you.',
        'Never walk or drive through flood water: 15 cm can knock you down, 30 cm can float a car.',
        'Turn off electricity at the main switch if it is safe to reach.',
        'Stay away from fallen power lines and fast-moving water.',
      ],
    ),
    GuideTopic(
      title: 'Evacuation checklist',
      icon: Icons.directions_run,
      steps: [
        'Leave early, before roads are covered.',
        'Take your go-bag, phone, charger and any medicines.',
        'Lock the door, switch off gas and electricity.',
        'Help children, elderly and disabled neighbours.',
        'Tell someone where you are going and use the SOS button if you are stuck.',
      ],
    ),
    GuideTopic(
      title: 'Earthquake safety',
      icon: Icons.vibration,
      steps: [
        'Drop to the ground, cover your head and neck, hold on to sturdy furniture.',
        'Stay away from windows, shelves and heavy objects that can fall.',
        'If outside, move to an open area away from buildings and wires.',
        'After shaking stops, expect aftershocks and leave damaged buildings.',
      ],
    ),
    GuideTopic(
      title: 'Severe bleeding',
      icon: Icons.healing,
      steps: [
        'Press firmly on the wound with a clean cloth. Do not remove it if soaked; add more on top.',
        'Keep pressing for at least 10 minutes without checking.',
        'If possible, raise the injured limb above the heart.',
        'Call the local emergency number if bleeding does not stop.',
      ],
    ),
    GuideTopic(
      title: 'CPR basics (adult)',
      icon: Icons.favorite,
      steps: [
        'Check if the person responds and breathes. If not, call for help.',
        'Push hard and fast in the centre of the chest: about 100 to 120 times per minute, 5 to 6 cm deep.',
        'If you are trained, give 2 rescue breaths after every 30 compressions.',
        'Continue until help arrives or the person starts to breathe.',
      ],
    ),
    GuideTopic(
      title: 'Burns',
      icon: Icons.local_fire_department,
      steps: [
        'Cool the burn under cool running water for 20 minutes.',
        'Remove rings and tight clothing near the burn before it swells.',
        'Cover loosely with a clean non-fluffy cover such as cling film.',
        'Do not use ice, butter or toothpaste. Seek medical help for large or deep burns.',
      ],
    ),
    GuideTopic(
      title: 'Broken bones',
      icon: Icons.accessible,
      steps: [
        'Keep the person still and the injured part supported in the position found.',
        'Do not try to straighten the bone.',
        'Support the limb with padding or a splint, tied above and below the break.',
        'Get medical help; treat for shock by keeping the person warm.',
      ],
    ),
  ];
}

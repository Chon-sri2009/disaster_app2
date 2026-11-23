import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/l10n.dart';
import '../models/flood_history.dart';
import '../services/flood_history_service.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/notice_ui.dart';

// GISTDA's repeat-flood record for the last known position. Hidden while loading, with no
// position, or when the backend cannot answer. "No record" is never worded as "safe".
class FloodHistoryCard extends StatefulWidget {
  const FloodHistoryCard({
    super.key,
    required this.service,
    required this.storage,
  });

  final FloodHistoryService service;
  final StorageService storage;

  @override
  State<FloodHistoryCard> createState() => _FloodHistoryCardState();
}

class _FloodHistoryCardState extends State<FloodHistoryCard> {
  LatLng? _for;
  Future<FloodHistory?>? _future;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.storage,
      builder: (context, _) {
        final p = widget.storage.lastPosition;
        if (p == null) return const SizedBox.shrink();
        if (p != _for) {
          _for = p;
          _future = widget.service.at(p);
        }
        return FutureBuilder<FloodHistory?>(
          future: _future,
          builder: (context, snap) {
            final h = snap.data;
            if (h == null) return const SizedBox.shrink();
            return _Body(h);
          },
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.h);

  final FloodHistory h;

  @override
  Widget build(BuildContext context) {
    final years = h.years;
    final range = years.isEmpty ? '' : '${years.first.year}-${years.last.year}';
    final where = [
      h.district,
      h.province,
    ].whereType<String>().toSet().join(', ');
    return Section(
      title: context.tr(th: 'ประวัติน้ำท่วมซ้ำซาก', en: 'Flood history'),
      children: [
        RuledRow(
          icon: Icons.water_drop_outlined,
          crossAxisAlignment: CrossAxisAlignment.start,
          title: h.found
              ? context.tr(
                  th: 'ท่วม ${h.floodedYears} จาก ${years.length} ปี ($range)',
                  en: 'Flooded in ${h.floodedYears} of ${years.length} years ($range)',
                )
              : context.tr(
                  th: 'ไม่มีบันทึกน้ำท่วมซ้ำซากที่จุดนี้',
                  en: 'No repeat-flood record at this spot',
                ),
          subtitle: h.found && where.isNotEmpty
              ? where
              : context.tr(
                  th: 'ไม่ได้แปลว่าปลอดภัย ดูระดับน้ำและประกาศทางการ',
                  en: 'This does not mean it is safe. Check the water level and official alerts.',
                ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          context.tr(
            th: 'ที่มา: GISTDA ข้อมูลย้อนหลัง ไม่ใช่การพยากรณ์',
            en: 'Source: GISTDA, past record, not a forecast',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// GISTDA's record of repeat flooding at a spot, as relayed by our backend. found == false means
// GISTDA has no record there. That is not a statement that the place is safe.
class FloodHistory {
  const FloodHistory({
    required this.found,
    this.district,
    this.province,
    this.years = const [],
  });

  final bool found;
  final String? district;
  final String? province;
  // Oldest first: (year, number of floods that year).
  final List<({int year, int freq})> years;

  int get floodedYears => years.where((y) => y.freq > 0).length;

  factory FloodHistory.fromJson(Map<String, dynamic> json) {
    final raw = json['years'] as List? ?? const [];
    return FloodHistory(
      found: json['found'] == true,
      district: json['district'] as String?,
      province: json['province'] as String?,
      years: [
        for (final y in raw)
          (
            year: (y as Map<String, dynamic>)['year'] as int,
            freq: y['freq'] as int,
          ),
      ],
    );
  }
}

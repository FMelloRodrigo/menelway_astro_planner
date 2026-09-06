class MonthVisibilityItem {
  final int month; // 1 to 12
  final String name; // "Jan", "Feb", etc.
  final double hoursObservable;
  final double peakAltitudeDeg;
  final bool isObservable;

  const MonthVisibilityItem({
    required this.month,
    required this.name,
    required this.hoursObservable,
    required this.peakAltitudeDeg,
    required this.isObservable,
  });

  factory MonthVisibilityItem.fromJson(Map<String, dynamic> json) {
    return MonthVisibilityItem(
      month: json['month'] as int? ?? 1,
      name: json['name'] as String? ?? '',
      hoursObservable: (json['hours_observable'] as num?)?.toDouble() ?? 0.0,
      peakAltitudeDeg: (json['peak_altitude_deg'] as num?)?.toDouble() ?? 0.0,
      isObservable: json['is_observable'] as bool? ?? false,
    );
  }
}

class YearlyVisibilityModel {
  final int targetId;
  final double theoreticalMaxAltitudeDeg;
  final bool canEverReachMinAlt;
  final int peakMonth;
  final int bestWindowStart;
  final int bestWindowEnd;
  final double maxHoursInPeak;
  final String bestWindowSummary;
  final List<MonthVisibilityItem> months;

  const YearlyVisibilityModel({
    required this.targetId,
    required this.theoreticalMaxAltitudeDeg,
    required this.canEverReachMinAlt,
    required this.peakMonth,
    required this.bestWindowStart,
    required this.bestWindowEnd,
    required this.maxHoursInPeak,
    required this.bestWindowSummary,
    required this.months,
  });

  factory YearlyVisibilityModel.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['months'] as List<dynamic>? ?? [];
    return YearlyVisibilityModel(
      targetId: json['target_id'] as int? ?? 0,
      theoreticalMaxAltitudeDeg: (json['theoretical_max_altitude_deg'] as num?)?.toDouble() ?? 0.0,
      canEverReachMinAlt: json['can_ever_reach_min_alt'] as bool? ?? true,
      peakMonth: json['peak_month'] as int? ?? 1,
      bestWindowStart: json['best_window_start'] as int? ?? 1,
      bestWindowEnd: json['best_window_end'] as int? ?? 1,
      maxHoursInPeak: (json['max_hours_in_peak'] as num?)?.toDouble() ?? 0.0,
      bestWindowSummary: json['best_window_summary'] as String? ?? '',
      months: rawMonths.map((m) => MonthVisibilityItem.fromJson(m as Map<String, dynamic>)).toList(),
    );
  }
}

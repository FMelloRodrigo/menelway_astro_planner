class MonthVisibilityItem {
  final int month; // 1 to 12
  final String name; // "Jan", "Feb", etc.
  final double hoursObservable;
  final double peakAltitudeDeg;
  final bool isObservable;
  final int observableDaysCount;
  final int startDay;
  final int endDay;
  final int totalDaysInMonth;

  const MonthVisibilityItem({
    required this.month,
    required this.name,
    required this.hoursObservable,
    required this.peakAltitudeDeg,
    required this.isObservable,
    this.observableDaysCount = 0,
    this.startDay = 0,
    this.endDay = 0,
    this.totalDaysInMonth = 31,
  });

  bool get isPartialMonth => isObservable && observableDaysCount < totalDaysInMonth;

  String get dateRangeLabel {
    if (!isObservable || observableDaysCount == 0) {
      return "$name: Not observable";
    }
    if (!isPartialMonth) {
      return "$name: Full month ($totalDaysInMonth days, up to ${hoursObservable.toStringAsFixed(1)}h)";
    }
    if (startDay > 1 && endDay == totalDaysInMonth) {
      return "$name: From $name $startDay ($observableDaysCount days, up to ${hoursObservable.toStringAsFixed(1)}h)";
    }
    if (startDay == 1 && endDay < totalDaysInMonth) {
      return "$name: Until $name $endDay ($observableDaysCount days, up to ${hoursObservable.toStringAsFixed(1)}h)";
    }
    return "$name: $name $startDay–$endDay ($observableDaysCount days, up to ${hoursObservable.toStringAsFixed(1)}h)";
  }

  factory MonthVisibilityItem.fromJson(Map<String, dynamic> json) {
    final isObs = json['is_observable'] as bool? ?? false;
    final obsDays = json['observable_days_count'] as int? ?? (isObs ? 15 : 0);
    return MonthVisibilityItem(
      month: json['month'] as int? ?? 1,
      name: json['name'] as String? ?? '',
      hoursObservable: (json['hours_observable'] as num?)?.toDouble() ?? 0.0,
      peakAltitudeDeg: (json['peak_altitude_deg'] as num?)?.toDouble() ?? 0.0,
      isObservable: isObs,
      observableDaysCount: obsDays,
      startDay: json['start_day'] as int? ?? (isObs ? 1 : 0),
      endDay: json['end_day'] as int? ?? (isObs ? 28 : 0),
      totalDaysInMonth: json['total_days_in_month'] as int? ?? 31,
    );
  }
}

class YearlyVisibilityModel {
  final int targetId;
  final double theoreticalMaxAltitudeDeg;
  final bool canEverReachMinAlt;
  final int peakMonth;
  final int peakDay;
  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;
  final int bestWindowStart;
  final int bestWindowEnd;
  final int totalObservableDays;
  final double maxHoursInPeak;
  final String bestWindowSummary;
  final List<MonthVisibilityItem> months;

  const YearlyVisibilityModel({
    required this.targetId,
    required this.theoreticalMaxAltitudeDeg,
    required this.canEverReachMinAlt,
    required this.peakMonth,
    this.peakDay = 15,
    this.startMonth = 1,
    this.startDay = 1,
    this.endMonth = 1,
    this.endDay = 28,
    required this.bestWindowStart,
    required this.bestWindowEnd,
    this.totalObservableDays = 0,
    required this.maxHoursInPeak,
    required this.bestWindowSummary,
    required this.months,
  });

  bool get isCircumpolar => totalObservableDays >= 365;

  /// Checks whether the target is observable on a specific calendar date
  /// according to the simulated 12-month visibility breakdown.
  bool isDateObservable(DateTime date) {
    if (!canEverReachMinAlt || totalObservableDays == 0) return false;
    final m = date.month;
    final d = date.day;
    final monthItem = months.where((item) => item.month == m).firstOrNull;
    if (monthItem == null || !monthItem.isObservable || monthItem.observableDaysCount == 0) {
      return false;
    }
    return d >= monthItem.startDay && d <= monthItem.endDay;
  }

  factory YearlyVisibilityModel.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['months'] as List<dynamic>? ?? [];
    final startM = json['start_month'] as int? ?? json['best_window_start'] as int? ?? 1;
    final endM = json['end_month'] as int? ?? json['best_window_end'] as int? ?? 1;

    return YearlyVisibilityModel(
      targetId: json['target_id'] as int? ?? 0,
      theoreticalMaxAltitudeDeg: (json['theoretical_max_altitude_deg'] as num?)?.toDouble() ?? 0.0,
      canEverReachMinAlt: json['can_ever_reach_min_alt'] as bool? ?? true,
      peakMonth: json['peak_month'] as int? ?? 1,
      peakDay: json['peak_day'] as int? ?? 15,
      startMonth: startM,
      startDay: json['start_day'] as int? ?? 1,
      endMonth: endM,
      endDay: json['end_day'] as int? ?? 28,
      bestWindowStart: json['best_window_start'] as int? ?? startM,
      bestWindowEnd: json['best_window_end'] as int? ?? endM,
      totalObservableDays: json['total_observable_days'] as int? ?? 0,
      maxHoursInPeak: (json['max_hours_in_peak'] as num?)?.toDouble() ?? 0.0,
      bestWindowSummary: json['best_window_summary'] as String? ?? '',
      months: rawMonths.map((m) => MonthVisibilityItem.fromJson(m as Map<String, dynamic>)).toList(),
    );
  }
}

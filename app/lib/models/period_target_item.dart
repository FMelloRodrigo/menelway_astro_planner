import 'target_item.dart';

class PeriodTargetItem {
  final int id;
  final String name;
  final String? messier;
  final String? caldwell;
  final String? arp;
  final String? herschel;
  final String catalog;
  final String objectType;
  final String constellation;
  final double raHours;
  final double decDegrees;
  final double? magnitude;
  final double? majorAxisArcmin;
  final double? positionAngleDeg;
  final double? surfaceBrightness;
  final String? commonName;
  final double peakAltitudeDeg;
  final double maxHoursObservable;
  final DateTime? peakDate;
  final int observableDaysCount;
  final int totalPeriodDays;
  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;
  final bool isObservable;

  const PeriodTargetItem({
    required this.id,
    required this.name,
    this.messier,
    this.caldwell,
    this.arp,
    this.herschel,
    required this.catalog,
    required this.objectType,
    required this.constellation,
    required this.raHours,
    required this.decDegrees,
    this.magnitude,
    this.majorAxisArcmin,
    this.positionAngleDeg,
    this.surfaceBrightness,
    this.commonName,
    required this.peakAltitudeDeg,
    required this.maxHoursObservable,
    this.peakDate,
    required this.observableDaysCount,
    required this.totalPeriodDays,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
    required this.isObservable,
  });

  String get displayName {
    if (messier != null && messier!.isNotEmpty) {
      if (commonName != null && commonName!.isNotEmpty) {
        return '$messier ($commonName)';
      }
      return '$messier - $name';
    }
    if (caldwell != null && caldwell!.isNotEmpty) {
      if (commonName != null && commonName!.isNotEmpty) {
        return '$caldwell ($commonName)';
      }
      return '$caldwell - $name';
    }
    if (arp != null && arp!.isNotEmpty) {
      if (commonName != null && commonName!.isNotEmpty) {
        return '$arp ($commonName)';
      }
      return '$arp - $name';
    }
    if (herschel != null && herschel!.isNotEmpty) {
      if (commonName != null && commonName!.isNotEmpty) {
        return '$herschel ($commonName)';
      }
      return '$herschel - $name';
    }
    if (commonName != null && commonName!.isNotEmpty) {
      return '$name ($commonName)';
    }
    return name;
  }

  String get periodObservabilitySummary {
    if (!isObservable || observableDaysCount == 0) {
      return 'Not observable in this period';
    }
    final ratio = '$observableDaysCount / $totalPeriodDays days';
    if (startMonth == endMonth && startDay == endDay) {
      return '$ratio • Day $startDay only';
    }
    return '$ratio (${_monthName(startMonth)} $startDay – ${_monthName(endMonth)} $endDay)';
  }

  static String _monthName(int m) {
    const kNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (m >= 1 && m <= 12) return kNames[m - 1];
    return '';
  }

  String get formattedRa {
    final h = raHours.floor();
    final m = ((raHours - h) * 60).floor();
    final s = (raHours - h - m / 60) * 3600;
    return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m ${s.toStringAsFixed(1).padLeft(4, '0')}s';
  }

  String get formattedDec {
    final sign = decDegrees >= 0 ? '+' : '-';
    final absDec = decDegrees.abs();
    final d = absDec.floor();
    final m = ((absDec - d) * 60).floor();
    final s = (absDec - d - m / 60) * 3600;
    return '$sign${d.toString().padLeft(2, '0')}° ${m.toString().padLeft(2, '0')}\' ${s.toStringAsFixed(0).padLeft(2, '0')}"';
  }

  /// Returns whether this target is observable on a specific calendar date within
  /// its period observing window.
  bool isObservableOn(DateTime date) {
    if (!isObservable || observableDaysCount == 0) return false;
    final m = date.month;
    final d = date.day;
    if (startMonth == 0 || endMonth == 0) return false;
    if (startMonth <= endMonth) {
      if (m < startMonth || m > endMonth) return false;
      if (m == startMonth && d < startDay) return false;
      if (m == endMonth && d > endDay) return false;
      return true;
    } else {
      // Crosses year boundary (e.g. Nov to Feb)
      if (m > endMonth && m < startMonth) return false;
      if (m == startMonth && d < startDay) return false;
      if (m == endMonth && d > endDay) return false;
      return true;
    }
  }

  TargetItem toTargetItem({DateTime? date}) {
    final d = date ?? peakDate ?? DateTime.now();
    return TargetItem(
      id: id,
      name: name,
      messier: messier,
      caldwell: caldwell,
      arp: arp,
      herschel: herschel,
      catalog: catalog,
      objectType: objectType,
      constellation: constellation,
      raHours: raHours,
      decDegrees: decDegrees,
      magnitude: magnitude,
      majorAxisArcmin: majorAxisArcmin,
      positionAngleDeg: positionAngleDeg,
      surfaceBrightness: surfaceBrightness,
      commonName: commonName,
      peakAltitudeDeg: peakAltitudeDeg,
      visibleDurationHours: maxHoursObservable,
      transitTime: d,
      minMoonSepDeg: 0,
      meetsCriteria: date != null ? isObservableOn(date) : isObservable,
    );
  }
}

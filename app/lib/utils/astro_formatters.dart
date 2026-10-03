import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/period_target_item.dart';
import '../models/yearly_visibility.dart';

/// Formats astronomical coordinates and ephemeris values consistently across the application.
class AstroFormatters {
  const AstroFormatters._();

  /// Formats Right Ascension in hours into canonical `00h 00m 00.0s`.
  static String formatRa(double hours) {
    var h = (hours % 24.0);
    if (h < 0) h += 24.0;
    final intHours = h.floor();
    final remMinutes = (h - intHours) * 60.0;
    final intMinutes = remMinutes.floor();
    final seconds = (remMinutes - intMinutes) * 60.0;
    return '${intHours.toString().padLeft(2, '0')}h ${intMinutes.toString().padLeft(2, '0')}m ${seconds.toStringAsFixed(1).padLeft(4, '0')}s';
  }

  /// Formats Declination in degrees into canonical `+00° 00' 00.0"` or `-00° 00' 00.0"`.
  static String formatDec(double degrees) {
    final sign = degrees < 0 ? '-' : '+';
    final absD = degrees.abs();
    final intDeg = absD.floor();
    final remMinutes = (absD - intDeg) * 60.0;
    final intMinutes = remMinutes.floor();
    final seconds = (remMinutes - intMinutes) * 60.0;
    return "$sign${intDeg.toString().padLeft(2, '0')}° ${intMinutes.toString().padLeft(2, '0')}' ${seconds.toStringAsFixed(1).padLeft(4, '0')}\"";
  }

  /// Converts an azimuth angle (0° to 360°) to its 8-point or 16-point cardinal compass abbreviation.
  static String cardinalFromAzimuth(double az, {bool isPt = false}) {
    final normAz = (az % 360 + 360) % 360;
    const cardinalsEn = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    const cardinalsPt = ["N", "NE", "L", "SE", "S", "SO", "O", "NO"];
    final index = ((normAz + 22.5) / 45.0).floor() % 8;
    return isPt ? cardinalsPt[index] : cardinalsEn[index];
  }
}

/// Result of evaluating yearly visibility and observing season status for a target.
class TargetSeasonStatus {
  final String statusText;
  final bool isPositive;
  final bool isZeroDays;

  const TargetSeasonStatus({
    required this.statusText,
    required this.isPositive,
    required this.isZeroDays,
  });
}

/// Evaluates seasonal observability and produces localized status messages.
class SeasonStatusCalculator {
  const SeasonStatusCalculator._();

  /// Computes the seasonal status and display text for a target.
  static TargetSeasonStatus computeStatus({
    required YearlyVisibilityModel yearly,
    required bool isVisibleTonight,
    required bool showFilteredYearly,
    required AppLocalizations l10n,
    PeriodTargetItem? periodTarget,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final currentMonth = now.month;
    final currentDay = now.day;
    final y = yearly;

    String tonightStatusText;

    if (!y.canEverReachMinAlt) {
      tonightStatusText = l10n.unreachable;
    } else if (y.totalObservableDays == 0) {
      tonightStatusText = showFilteredYearly
          ? l10n.notObservableFiltered
          : l10n.notObservableBelowLimits;
    } else if (periodTarget != null) {
      final p = periodTarget;
      if (p.isObservable && p.observableDaysCount > 0) {
        final startM = localizeMonthAbbr(p.startMonth, l10n);
        final dateStr = "$startM ${p.startDay}";
        if (p.startMonth == p.endMonth && p.startDay == p.endDay) {
          tonightStatusText = l10n.visibleOnDate(dateStr);
        } else {
          tonightStatusText = l10n.visibleFromDate(dateStr);
        }
      } else {
        tonightStatusText = showFilteredYearly
            ? l10n.notObservableFiltered
            : l10n.notObservableBelowLimits;
      }
    } else if (isVisibleTonight) {
      tonightStatusText = l10n.visibleTonight;
    } else {
      final thisYear = now.year;
      DateTime seasonStart = DateTime(thisYear, y.startMonth, y.startDay);
      if (seasonStart.isBefore(now) && y.startMonth > y.endMonth && currentMonth <= y.endMonth) {
        seasonStart = DateTime(thisYear - 1, y.startMonth, y.startDay);
      }
      DateTime seasonEnd = DateTime(thisYear, y.endMonth, y.endDay);
      if (y.endMonth < y.startMonth && currentMonth >= y.startMonth) {
        seasonEnd = DateTime(thisYear + 1, y.endMonth, y.endDay);
      }

      if (now.isBefore(seasonStart)) {
        final diffDays = seasonStart.difference(DateTime(thisYear, currentMonth, currentDay)).inDays;
        final startM = localizeMonthAbbr(y.startMonth, l10n);
        if (diffDays == 1) {
          tonightStatusText = l10n.startsTomorrow("$startM ${y.startDay}");
        } else if (diffDays <= 60) {
          tonightStatusText = l10n.startsInDays(diffDays, "$startM ${y.startDay}");
        } else {
          tonightStatusText = l10n.startsOnDate("$startM ${y.startDay}");
        }
      } else if (!now.isAfter(seasonEnd)) {
        final dateStr = DateFormat('MMM d').format(now);
        tonightStatusText = periodTarget != null
            ? l10n.outsideFiltersOnDate(dateStr)
            : l10n.inSeasonBelowLimits;
      } else {
        final endM = localizeMonthAbbr(y.endMonth, l10n);
        tonightStatusText = l10n.offSeasonEnded("$endM ${y.endDay}");
      }
    }

    final isPositiveStatus = periodTarget != null
        ? (periodTarget.isObservable && periodTarget.observableDaysCount > 0)
        : isVisibleTonight;

    final isZeroDays = periodTarget != null
        ? (!periodTarget.isObservable || periodTarget.observableDaysCount == 0 || !y.canEverReachMinAlt)
        : (y.totalObservableDays == 0 || !y.canEverReachMinAlt);

    return TargetSeasonStatus(
      statusText: tonightStatusText,
      isPositive: isPositiveStatus,
      isZeroDays: isZeroDays,
    );
  }
}

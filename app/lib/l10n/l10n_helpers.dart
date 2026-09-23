import '../models/period_target_item.dart';
import '../models/yearly_visibility.dart';
import 'app_localizations.dart';

/// Helper to translate astronomical object types from canonical DB strings into the user's active language.
String localizeObjectType(String rawType, AppLocalizations? l10n) {
  if (l10n == null) return rawType;
  switch (rawType) {
    case 'Galaxy':
      return l10n.objGalaxy;
    case 'Planetary Nebula':
      return l10n.objPlanetaryNebula;
    case 'Bright Nebula':
      return l10n.objBrightNebula;
    case 'Dark Nebula':
      return l10n.objDarkNebula;
    case 'Open Cluster':
      return l10n.objOpenCluster;
    case 'Globular Cluster':
      return l10n.objGlobularCluster;
    case 'Supernova Remnant':
      return l10n.objSupernovaRemnant;
    case 'Star':
      return l10n.objStar;
    case 'Double Star':
      return l10n.objDoubleStar;
    case 'Asterism':
      return l10n.objAsterism;
    default:
      return rawType;
  }
}

/// Helper to get localized quadrant preset options for azimuth filter dropdown.
List<String> getQuadrantOptions(AppLocalizations? l10n) {
  if (l10n == null) {
    return const [
      'All Directions (0° - 360°)',
      'North (315° - 45°)',
      'East (45° - 135°)',
      'South (135° - 225°)',
      'West (225° - 315°)',
      'North-East (0° - 90°)',
      'South-East (90° - 180°)',
      'South-West (180° - 270°)',
      'North-West (270° - 360°)',
      'Custom Degree Range',
    ];
  }
  return [
    l10n.quadrantAll,
    l10n.quadrantN,
    l10n.quadrantE,
    l10n.quadrantS,
    l10n.quadrantW,
    l10n.quadrantNE,
    l10n.quadrantSE,
    l10n.quadrantSW,
    l10n.quadrantNW,
    l10n.quadrantCustom,
  ];
}

/// Helper to translate moon phases into the user's active language.
String localizeMoonPhase(String rawPhase, AppLocalizations? l10n) {
  if (l10n == null) return rawPhase;
  final clean = rawPhase.trim().toLowerCase();
  switch (clean) {
    case 'new moon':
      return l10n.moonPhaseNewMoon;
    case 'waxing crescent':
      return l10n.moonPhaseWaxingCrescent;
    case 'first quarter':
      return l10n.moonPhaseFirstQuarter;
    case 'waxing gibbous':
      return l10n.moonPhaseWaxingGibbous;
    case 'full moon':
      return l10n.moonPhaseFullMoon;
    case 'waning gibbous':
      return l10n.moonPhaseWaningGibbous;
    case 'third quarter':
    case 'last quarter':
      return l10n.moonPhaseThirdQuarter;
    case 'waning crescent':
      return l10n.moonPhaseWaningCrescent;
    default:
      return rawPhase;
  }
}

/// Helper to get localized 3-letter month abbreviation.
String localizeMonthAbbr(int month, AppLocalizations? l10n) {
  if (month < 1 || month > 12) return '';
  final isPt = l10n?.localeName.startsWith('pt') == true;
  if (isPt) {
    const ptMonths = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return ptMonths[month - 1];
  }
  const enMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return enMonths[month - 1];
}

/// Helper to localize the yearly visibility best window summary string.
String localizeBestWindowSummary(YearlyVisibilityModel y, AppLocalizations? l10n) {
  if (l10n == null) return y.bestWindowSummary;

  if (!y.canEverReachMinAlt) {
    return l10n.neverReachesLatitude(
      y.theoreticalMaxAltitudeDeg.round().toString(),
      y.theoreticalMaxAltitudeDeg.toStringAsFixed(1),
    );
  }

  if (y.isCircumpolar) {
    return l10n.yearRoundCircumpolar;
  }

  if (y.totalObservableDays == 0) {
    return l10n.notObservableWithFilters;
  }

  final startM = localizeMonthAbbr(y.startMonth, l10n);
  final endM = localizeMonthAbbr(y.endMonth, l10n);
  final peakM = localizeMonthAbbr(y.peakMonth, l10n);

  final isPt = l10n.localeName.startsWith('pt');
  final peakLabel = isPt ? "Pico Anual" : "Annual Peak";

  if (y.startMonth == y.endMonth && y.startDay == y.endDay) {
    return "$startM ${y.startDay} ($peakLabel: ${y.maxHoursInPeak.toStringAsFixed(1)}h)";
  }

  return "$startM ${y.startDay} – $endM ${y.endDay} ($peakLabel: $peakM ${y.peakDay})";
}

/// Helper to localize the period observability summary for period targets.
String localizePeriodObservabilitySummary(PeriodTargetItem target, AppLocalizations? l10n) {
  if (l10n == null) return target.periodObservabilitySummary;

  if (!target.isObservable || target.observableDaysCount == 0) {
    return l10n.periodNotObservableSummary;
  }

  final ratio = l10n.periodDaysRatio(target.observableDaysCount, target.totalPeriodDays);

  if (target.startMonth == target.endMonth && target.startDay == target.endDay) {
    return l10n.periodDaysOnlySpan(ratio, target.startDay);
  }

  final startM = localizeMonthAbbr(target.startMonth, l10n);
  final endM = localizeMonthAbbr(target.endMonth, l10n);
  return '$ratio ($startM ${target.startDay} – $endM ${target.endDay})';
}


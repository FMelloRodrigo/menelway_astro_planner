import 'dart:math' as math;

import '../models/altitude_point.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/period_target_item.dart';
import '../models/target_description.dart';
import '../models/target_item.dart';
import '../models/yearly_visibility.dart';
import 'astro_engine.dart';

/// In-memory fake implementation of [AstroEngine] for headless widget/unit testing.
/// Does not require native C++ dynamic libraries (astro_core.dll / libastro_core.so).
class FakeAstroEngine implements AstroEngine {
  bool isInitialized = false;
  String? initializedDbPath;
  String lastError = '';

  final Map<int, ObservingListModel> _observingLists = {};
  int _nextListId = 1;

  List<TargetItem>? customTargets;

  @override
  void initEngine(String dbPath) {
    isInitialized = true;
    initializedDbPath = dbPath;
  }

  @override
  void dispose() {
    isInitialized = false;
  }

  @override
  String getLastError() => lastError;

  @override
  NightSummary getNightSummary({
    required double latitude,
    required double longitude,
    required double elevation,
    required DateTime date,
  }) {
    final baseDate = DateTime(date.year, date.month, date.day);
    return NightSummary(
      sunset: baseDate.add(const Duration(hours: 18, minutes: 30)),
      civilDusk: baseDate.add(const Duration(hours: 19, minutes: 0)),
      nauticalDusk: baseDate.add(const Duration(hours: 19, minutes: 30)),
      astronomicalDusk: baseDate.add(const Duration(hours: 20, minutes: 0)),
      solarMidnight: baseDate.add(const Duration(days: 1, hours: 0, minutes: 15)),
      astronomicalDawn: baseDate.add(const Duration(days: 1, hours: 4, minutes: 30)),
      nauticalDawn: baseDate.add(const Duration(days: 1, hours: 5, minutes: 0)),
      civilDawn: baseDate.add(const Duration(days: 1, hours: 5, minutes: 30)),
      sunrise: baseDate.add(const Duration(days: 1, hours: 6, minutes: 0)),
      moonIllumination: 0.25,
      moonPhaseName: 'Waxing Crescent',
      hasAstronomicalNight: true,
    );
  }

  @override
  List<TargetItem> filterTargets({
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  }) {
    final targets = customTargets ?? defaultMockTargets;
    if (filters.searchQuery.trim().isEmpty) {
      return targets;
    }
    final q = filters.searchQuery.trim().toLowerCase();
    return targets
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.displayName.toLowerCase().contains(q) ||
            t.constellation.toLowerCase().contains(q))
        .toList();
  }

  @override
  List<TargetItem> getPlanets({
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  }) {
    return [
      TargetItem(
        id: 90005,
        name: 'Jupiter',
        catalog: 'Solar System',
        objectType: 'Planet',
        constellation: 'Tau',
        raHours: 4.85,
        decDegrees: 22.1,
        magnitude: -2.4,
        majorAxisArcmin: 0.75,
        commonName: 'Jupiter',
        peakAltitudeDeg: 68.0,
        visibleDurationHours: 6.2,
        transitTime: night.astronomicalDusk.add(const Duration(hours: 3)),
        visibleStartTime: night.astronomicalDusk,
        visibleEndTime: night.astronomicalDawn,
        minMoonSepDeg: 45.0,
        meetsCriteria: true,
      ),
      TargetItem(
        id: 90006,
        name: 'Saturn',
        catalog: 'Solar System',
        objectType: 'Planet',
        constellation: 'Aqr',
        raHours: 23.1,
        decDegrees: -7.5,
        magnitude: 0.6,
        majorAxisArcmin: 0.33,
        commonName: 'Saturn',
        peakAltitudeDeg: 54.0,
        visibleDurationHours: 5.5,
        transitTime: night.astronomicalDusk.add(const Duration(hours: 2)),
        visibleStartTime: night.astronomicalDusk,
        visibleEndTime: night.astronomicalDawn,
        minMoonSepDeg: 60.0,
        meetsCriteria: true,
      ),
      TargetItem(
        id: 90004,
        name: 'Mars',
        catalog: 'Solar System',
        objectType: 'Planet',
        constellation: 'Gem',
        raHours: 7.2,
        decDegrees: 24.5,
        magnitude: -0.8,
        majorAxisArcmin: 0.25,
        commonName: 'Mars',
        peakAltitudeDeg: 65.0,
        visibleDurationHours: 7.0,
        transitTime: night.astronomicalDusk.add(const Duration(hours: 5)),
        visibleStartTime: night.astronomicalDusk,
        visibleEndTime: night.astronomicalDawn,
        minMoonSepDeg: 75.0,
        meetsCriteria: true,
      ),
    ];
  }

  @override
  List<TargetItem> getBrightStars({
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  }) {
    return [
      TargetItem(
        id: 91001,
        name: 'Sirius',
        catalog: 'Stars',
        objectType: 'Double Star',
        constellation: 'CMa',
        raHours: 6.75,
        decDegrees: -16.72,
        magnitude: -1.46,
        commonName: 'Alpha Canis Majoris',
        peakAltitudeDeg: 72.0,
        visibleDurationHours: 7.5,
        transitTime: night.astronomicalDusk.add(const Duration(hours: 4)),
        visibleStartTime: night.astronomicalDusk,
        visibleEndTime: night.astronomicalDawn,
        minMoonSepDeg: 55.0,
        meetsCriteria: true,
      ),
      TargetItem(
        id: 91002,
        name: 'Canopus',
        catalog: 'Stars',
        objectType: 'Star',
        constellation: 'Car',
        raHours: 6.4,
        decDegrees: -52.7,
        magnitude: -0.74,
        commonName: 'Alpha Carinae',
        peakAltitudeDeg: 80.0,
        visibleDurationHours: 8.0,
        transitTime: night.astronomicalDusk.add(const Duration(hours: 4)),
        visibleStartTime: night.astronomicalDusk,
        visibleEndTime: night.astronomicalDawn,
        minMoonSepDeg: 65.0,
        meetsCriteria: true,
      ),
      TargetItem(
        id: 91004,
        name: 'Arcturus',
        catalog: 'Stars',
        objectType: 'Star',
        constellation: 'Boo',
        raHours: 14.26,
        decDegrees: 19.18,
        magnitude: -0.05,
        commonName: 'Alpha Boötis',
        peakAltitudeDeg: 55.0,
        visibleDurationHours: 5.0,
        transitTime: night.astronomicalDusk.add(const Duration(hours: 1)),
        visibleStartTime: night.astronomicalDusk,
        visibleEndTime: night.astronomicalDawn,
        minMoonSepDeg: 40.0,
        meetsCriteria: true,
      ),
      TargetItem(
        id: 91005,
        name: 'Vega',
        catalog: 'Stars',
        objectType: 'Star',
        constellation: 'Lyr',
        raHours: 18.62,
        decDegrees: 38.78,
        magnitude: 0.03,
        commonName: 'Alpha Lyrae',
        peakAltitudeDeg: 48.0,
        visibleDurationHours: 4.5,
        transitTime: night.astronomicalDusk.add(const Duration(hours: 6)),
        visibleStartTime: night.astronomicalDusk,
        visibleEndTime: night.astronomicalDawn,
        minMoonSepDeg: 50.0,
        meetsCriteria: true,
      ),
    ];
  }

  @override
  List<PeriodTargetItem> filterTargetsPeriod({
    required FilterState filters,
    required DateTime periodStart,
    required DateTime periodEnd,
    int stepMinutes = 10,
  }) {
    return [
      PeriodTargetItem(
        id: 1,
        name: 'NGC 224',
        messier: 'M 31',
        commonName: 'Andromeda Galaxy',
        catalog: 'Messier',
        objectType: 'Galaxy',
        constellation: 'And',
        raHours: 0.712,
        decDegrees: 41.27,
        magnitude: 3.44,
        majorAxisArcmin: 178.0,
        peakAltitudeDeg: 78.5,
        maxHoursObservable: 6.5,
        peakDate: periodStart.add(const Duration(days: 2)),
        observableDaysCount: 14,
        totalPeriodDays: 14,
        startMonth: periodStart.month,
        startDay: periodStart.day,
        endMonth: periodEnd.month,
        endDay: periodEnd.day,
        isObservable: true,
      ),
      PeriodTargetItem(
        id: 2,
        name: 'NGC 1976',
        messier: 'M 42',
        commonName: 'Orion Nebula',
        catalog: 'Messier',
        objectType: 'Bright Nebula',
        constellation: 'Ori',
        raHours: 5.588,
        decDegrees: -5.39,
        magnitude: 4.0,
        majorAxisArcmin: 85.0,
        peakAltitudeDeg: 62.0,
        maxHoursObservable: 4.8,
        peakDate: periodStart.add(const Duration(days: 5)),
        observableDaysCount: 12,
        totalPeriodDays: 14,
        startMonth: periodStart.month,
        startDay: periodStart.day,
        endMonth: periodEnd.month,
        endDay: periodEnd.day,
        isObservable: true,
      ),
    ];
  }

  @override
  List<AltitudePoint> generateAltitudeCurve({
    required int targetId,
    required double latitude,
    required double longitude,
    required double elevation,
    required DateTime start,
    required DateTime end,
    int stepMinutes = 5,
  }) {
    final points = <AltitudePoint>[];
    final totalDuration = end.difference(start).inMinutes;
    final totalSteps = math.max(1, totalDuration ~/ stepMinutes);

    for (var i = 0; i <= totalSteps; i++) {
      final t = start.add(Duration(minutes: i * stepMinutes));
      final progress = i / totalSteps;
      final alt = 15.0 + 55.0 * math.sin(progress * math.pi);
      final az = 90.0 + 180.0 * progress;
      points.add(AltitudePoint(
        time: t,
        altitude: alt,
        azimuth: az,
        moonSeparation: 60.0,
        meetsCriteria: true,
      ));
    }
    return points;
  }

  @override
  int createObservingList(String name, String description, String sessionDate) {
    final id = _nextListId++;
    final list = ObservingListModel(
      id: id,
      name: name,
      description: description,
      sessionDate: sessionDate,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      items: [],
    );
    _observingLists[id] = list;
    return id;
  }

  @override
  bool deleteObservingList(int listId) {
    return _observingLists.remove(listId) != null;
  }

  @override
  bool addTargetToList(int listId, int dsoId, String notes) {
    final list = _observingLists[listId];
    if (list == null) return false;

    if (list.items.any((item) => item.dsoId == dsoId)) {
      return true;
    }

    final target = (customTargets ?? defaultMockTargets).firstWhere(
      (t) => t.id == dsoId,
      orElse: () => defaultMockTargets.first,
    );

    final newItem = ObservingListItemModel(
      listId: listId,
      dsoId: dsoId,
      name: target.name,
      displayName: target.displayName,
      catalog: target.catalog,
      objectType: target.objectType,
      constellation: target.constellation,
      magnitude: target.magnitude,
      notes: notes,
      status: 'planned',
      addedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    final updatedItems = List<ObservingListItemModel>.from(list.items)..add(newItem);
    _observingLists[listId] = ObservingListModel(
      id: list.id,
      name: list.name,
      description: list.description,
      sessionDate: list.sessionDate,
      createdAt: list.createdAt,
      items: updatedItems,
    );
    return true;
  }

  @override
  bool removeTargetFromList(int listId, int dsoId) {
    final list = _observingLists[listId];
    if (list == null) return false;

    final updatedItems = list.items.where((i) => i.dsoId != dsoId).toList();
    _observingLists[listId] = ObservingListModel(
      id: list.id,
      name: list.name,
      description: list.description,
      sessionDate: list.sessionDate,
      createdAt: list.createdAt,
      items: updatedItems,
    );
    return true;
  }

  @override
  List<ObservingListModel> getObservingLists() {
    return _observingLists.values.toList();
  }

  @override
  bool clearAllObservingLists() {
    _observingLists.clear();
    return true;
  }

  @override
  YearlyVisibilityModel? getTargetYearlyVisibility({
    required int targetId,
    required double latitude,
    required double longitude,
    required double elevation,
    FilterState? filters,
    double minAltitude = 30.0,
    double minDurationHours = 2.0,
    int? year,
  }) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final months = List.generate(12, (index) {
      final monthNum = index + 1;
      final baseHours = 4.0 + 3.5 * math.sin((monthNum - 3) * math.pi / 6.0);
      return MonthVisibilityItem(
        month: monthNum,
        name: monthNames[index],
        hoursObservable: math.max(0.0, baseHours),
        peakAltitudeDeg: 60.0 + 15.0 * math.cos((monthNum - 3) * math.pi / 6.0),
        isObservable: baseHours > 0.0,
        observableDaysCount: baseHours > 0.0 ? 25 : 0,
        startDay: 1,
        endDay: 28,
        totalDaysInMonth: 30,
      );
    });

    return YearlyVisibilityModel(
      targetId: targetId,
      theoreticalMaxAltitudeDeg: 82.0,
      canEverReachMinAlt: true,
      peakMonth: 10,
      peakDay: 15,
      startMonth: 8,
      startDay: 1,
      endMonth: 12,
      endDay: 28,
      bestWindowStart: 9,
      bestWindowEnd: 12,
      totalObservableDays: 120,
      maxHoursInPeak: 7.5,
      bestWindowSummary: 'Sep to Dec',
      months: months,
    );
  }

  final Map<String, TargetDescription> _targetDescriptions = {
    'm 31': const TargetDescription(
      title: 'Andromeda Galaxy',
      description: 'Barred spiral galaxy in the Local Group',
      extract: 'The Andromeda Galaxy is a barred spiral galaxy and is the nearest major galaxy to the Milky Way.',
      pageUrl: 'https://en.wikipedia.org/wiki/Andromeda_Galaxy',
      source: 'Wikipedia',
    ),
    'ngc 224': const TargetDescription(
      title: 'Andromeda Galaxy',
      description: 'Barred spiral galaxy in the Local Group',
      extract: 'The Andromeda Galaxy is a barred spiral galaxy and is the nearest major galaxy to the Milky Way.',
      pageUrl: 'https://en.wikipedia.org/wiki/Andromeda_Galaxy',
      source: 'Wikipedia',
    ),
    'm 42': const TargetDescription(
      title: 'Orion Nebula',
      description: 'Diffuse nebula in the constellation Orion',
      extract: 'The Orion Nebula is a diffuse nebula situated south of Orion\'s Belt in the constellation of Orion.',
      pageUrl: 'https://en.wikipedia.org/wiki/Orion_Nebula',
      source: 'Wikipedia',
    ),
    'ngc 1976': const TargetDescription(
      title: 'Orion Nebula',
      description: 'Diffuse nebula in the constellation Orion',
      extract: 'The Orion Nebula is a diffuse nebula situated south of Orion\'s Belt in the constellation of Orion.',
      pageUrl: 'https://en.wikipedia.org/wiki/Orion_Nebula',
      source: 'Wikipedia',
    ),
    'sirius': const TargetDescription(
      title: 'Sirius',
      description: 'Brightest star in the night sky',
      extract: 'Sirius is the brightest star in the night sky. Its name is derived from the Greek word Seirios, meaning lit or glowing.',
      pageUrl: 'https://en.wikipedia.org/wiki/Sirius',
      source: 'Wikipedia',
    ),
    'alpha canis majoris': const TargetDescription(
      title: 'Sirius',
      description: 'Brightest star in the night sky',
      extract: 'Sirius is the brightest star in the night sky. Its name is derived from the Greek word Seirios, meaning lit or glowing.',
      pageUrl: 'https://en.wikipedia.org/wiki/Sirius',
      source: 'Wikipedia',
    ),
    'vega': const TargetDescription(
      title: 'Vega',
      description: 'Brightest star in the constellation Lyra',
      extract: 'Vega is the brightest star in the northern constellation of Lyra. It has the Bayer designation Alpha Lyrae.',
      pageUrl: 'https://en.wikipedia.org/wiki/Vega',
      source: 'Wikipedia',
    ),
    'alpha lyrae': const TargetDescription(
      title: 'Vega',
      description: 'Brightest star in the constellation Lyra',
      extract: 'Vega is the brightest star in the northern constellation of Lyra. It has the Bayer designation Alpha Lyrae.',
      pageUrl: 'https://en.wikipedia.org/wiki/Vega',
      source: 'Wikipedia',
    ),
    'jupiter': const TargetDescription(
      title: 'Jupiter',
      description: 'Fifth planet from the Sun',
      extract: 'Jupiter is the fifth planet from the Sun and the largest in the Solar System. It is a gas giant with a mass more than two and a half times that of all the other planets in the Solar System combined.',
      pageUrl: 'https://en.wikipedia.org/wiki/Jupiter',
      source: 'Wikipedia',
    ),
    'saturn': const TargetDescription(
      title: 'Saturn',
      description: 'Sixth planet from the Sun',
      extract: 'Saturn is the sixth planet from the Sun and the second-largest in the Solar System, after Jupiter. It is a gas giant with an average radius of about nine and a half times that of Earth.',
      pageUrl: 'https://en.wikipedia.org/wiki/Saturn',
      source: 'Wikipedia',
    ),
  };

  @override
  TargetDescription? getTargetDescription(String targetName) {
    return _targetDescriptions[targetName.toLowerCase().trim()];
  }

  @override
  bool saveTargetDescription(TargetDescription desc, {List<String>? aliases}) {
    _targetDescriptions[desc.title.toLowerCase().trim()] = desc;
    if (aliases != null) {
      for (final a in aliases) {
        _targetDescriptions[a.toLowerCase().trim()] = desc;
      }
    }
    return true;
  }

  static final List<TargetItem> defaultMockTargets = [
    TargetItem(
      id: 1,
      name: 'NGC 224',
      messier: 'M 31',
      commonName: 'Andromeda Galaxy',
      catalog: 'Messier',
      objectType: 'Galaxy',
      constellation: 'And',
      raHours: 0.712,
      decDegrees: 41.27,
      magnitude: 3.44,
      majorAxisArcmin: 178.0,
      peakAltitudeDeg: 78.5,
      visibleDurationHours: 6.5,
      transitTime: DateTime(2026, 9, 21, 0, 15),
      visibleStartTime: DateTime(2026, 9, 20, 21, 0),
      visibleEndTime: DateTime(2026, 9, 21, 3, 30),
      minMoonSepDeg: 65.0,
      meetsCriteria: true,
    ),
    TargetItem(
      id: 2,
      name: 'NGC 1976',
      messier: 'M 42',
      commonName: 'Orion Nebula',
      catalog: 'Messier',
      objectType: 'Bright Nebula',
      constellation: 'Ori',
      raHours: 5.588,
      decDegrees: -5.39,
      magnitude: 4.0,
      majorAxisArcmin: 85.0,
      peakAltitudeDeg: 62.0,
      visibleDurationHours: 4.8,
      transitTime: DateTime(2026, 9, 21, 3, 30),
      visibleStartTime: DateTime(2026, 9, 21, 1, 0),
      visibleEndTime: DateTime(2026, 9, 21, 5, 45),
      minMoonSepDeg: 45.0,
      meetsCriteria: true,
    ),
    TargetItem(
      id: 3,
      name: 'NGC 7000',
      commonName: 'North America Nebula',
      catalog: 'NGC',
      objectType: 'Bright Nebula',
      constellation: 'Cyg',
      raHours: 20.98,
      decDegrees: 44.53,
      magnitude: 4.0,
      majorAxisArcmin: 120.0,
      peakAltitudeDeg: 82.0,
      visibleDurationHours: 5.2,
      transitTime: DateTime(2026, 9, 20, 23, 0),
      visibleStartTime: DateTime(2026, 9, 20, 20, 30),
      visibleEndTime: DateTime(2026, 9, 21, 1, 45),
      minMoonSepDeg: 70.0,
      meetsCriteria: true,
    ),
  ];
}

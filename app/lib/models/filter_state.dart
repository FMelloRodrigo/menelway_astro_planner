class HorizonPointModel {
  final double azimuth; // 0..360 deg
  final double altitude; // 0..90 deg

  const HorizonPointModel({
    required this.azimuth,
    required this.altitude,
  });

  Map<String, dynamic> toJson() => {
    'azimuth': azimuth,
    'altitude': altitude,
  };

  factory HorizonPointModel.fromJson(Map<String, dynamic> json) {
    return HorizonPointModel(
      azimuth: (json['azimuth'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  HorizonPointModel copyWith({double? azimuth, double? altitude}) {
    return HorizonPointModel(
      azimuth: azimuth ?? this.azimuth,
      altitude: altitude ?? this.altitude,
    );
  }
}

class FilterState {
  double minAltitude;
  double maxAltitude;
  double minDurationHours;
  DateTime date;
  double minMoonSeparation;
  double minAzimuth;
  double maxAzimuth;
  int quadrant; // 0=All, 1=N, 2=E, 3=S, 4=W, 5=NE, 6=SE, 7=SW, 8=NW
  double maxMagnitude;
  double minMagnitude;
  double minSizeArcmin;
  double maxSizeArcmin;
  Set<String> selectedCatalogs;
  Set<String> selectedObjectTypes;
  String searchQuery;
  int maxTargets;

  // Custom Horizon Profile
  bool useCustomHorizon;
  List<HorizonPointModel> horizonPoints;
  String? panoramaImagePath;
  double panoramaAzimuthOffset; // 0..360 degrees to align North
  double panoramaAltitudeOffset; // -20..+20 degrees for ground baseline
  double panoramaAltitudeScale; // 0.5..2.0 vertical stretch
  double panoramaOpacity; // 0.1..1.0 transparency

  // Observing Time Window (Telescopius rule)
  bool useCustomTimeWindow;
  int customStartHour;
  int customStartMinute;
  int customEndHour;
  int customEndMinute;

  // Observer
  double observerLat;
  double observerLon;
  double observerElevation;
  String observerLocationName;

  FilterState({
    this.minAltitude = 30.0,
    this.maxAltitude = 90.0,
    this.minDurationHours = 2.0,
    DateTime? date,
    this.minMoonSeparation = 15.0,
    this.minAzimuth = 0.0,
    this.maxAzimuth = 360.0,
    this.quadrant = 0,
    this.maxMagnitude = 14.0,
    this.minMagnitude = -5.0,
    this.minSizeArcmin = 0.0,
    this.maxSizeArcmin = 600.0,
    Set<String>? selectedCatalogs,
    Set<String>? selectedObjectTypes,
    this.searchQuery = '',
    this.maxTargets = 20,
    this.useCustomHorizon = false,
    List<HorizonPointModel>? horizonPoints,
    this.panoramaImagePath,
    this.panoramaAzimuthOffset = 0.0,
    this.panoramaAltitudeOffset = 0.0,
    this.panoramaAltitudeScale = 1.0,
    this.panoramaOpacity = 0.6,
    this.useCustomTimeWindow = false,
    this.customStartHour = 21,
    this.customStartMinute = 0,
    this.customEndHour = 23,
    this.customEndMinute = 0,
    this.observerLat = -22.2819,
    this.observerLon = -42.5311,
    this.observerElevation = 858.0,
    this.observerLocationName = 'Nova Friburgo, Rio de Janeiro, Brazil',
  })  : date = date != null
            ? DateTime(date.year, date.month, date.day)
            : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
        horizonPoints = horizonPoints ?? [],
        selectedCatalogs = selectedCatalogs ?? {'Messier', 'Caldwell'},
        selectedObjectTypes = selectedObjectTypes ?? {
          'Galaxy',
          'Planetary Nebula',
          'Bright Nebula',
          'Dark Nebula',
          'Open Cluster',
          'Globular Cluster',
          'Supernova Remnant',
        };

  /// Returns the start DateTime for the observing session (handling evening vs morning).
  DateTime getWindowStart([DateTime? refDate]) {
    final base = refDate ?? date;
    if (customStartHour >= 12) {
      return DateTime(base.year, base.month, base.day, customStartHour, customStartMinute);
    } else {
      final nextDay = base.add(const Duration(days: 1));
      return DateTime(nextDay.year, nextDay.month, nextDay.day, customStartHour, customStartMinute);
    }
  }

  /// Returns the end DateTime for the observing session (handling cross-midnight).
  DateTime getWindowEnd([DateTime? refDate]) {
    final startDt = getWindowStart(refDate);
    int startMins = customStartHour * 60 + customStartMinute;
    int endMins = customEndHour * 60 + customEndMinute;
    int diffMins = endMins - startMins;
    if (diffMins <= 0) {
      diffMins += 24 * 60; // crossed into next morning
    }
    return startDt.add(Duration(minutes: diffMins));
  }

  /// Total duration of the custom window in hours.
  double get windowDurationHours {
    int startMins = customStartHour * 60 + customStartMinute;
    int endMins = customEndHour * 60 + customEndMinute;
    int diffMins = endMins - startMins;
    if (diffMins <= 0) {
      diffMins += 24 * 60;
    }
    return diffMins / 60.0;
  }

  /// Formatted string like "21:00h - 23:00h" or "Astronomical Darkness".
  String get formattedWindow {
    if (!useCustomTimeWindow) {
      return "Astronomical Darkness";
    }
    final sH = customStartHour.toString().padLeft(2, '0');
    final sM = customStartMinute.toString().padLeft(2, '0');
    final eH = customEndHour.toString().padLeft(2, '0');
    final eM = customEndMinute.toString().padLeft(2, '0');
    return "$sH:${sM}h - $eH:${eM}h";
  }

  FilterState copyWith({
    double? minAltitude,
    double? maxAltitude,
    double? minDurationHours,
    DateTime? date,
    double? minMoonSeparation,
    double? minAzimuth,
    double? maxAzimuth,
    int? quadrant,
    double? maxMagnitude,
    double? minMagnitude,
    double? minSizeArcmin,
    double? maxSizeArcmin,
    Set<String>? selectedCatalogs,
    Set<String>? selectedObjectTypes,
    String? searchQuery,
    int? maxTargets,
    bool? useCustomHorizon,
    List<HorizonPointModel>? horizonPoints,
    String? panoramaImagePath,
    double? panoramaAzimuthOffset,
    double? panoramaAltitudeOffset,
    double? panoramaAltitudeScale,
    double? panoramaOpacity,
    bool? useCustomTimeWindow,
    int? customStartHour,
    int? customStartMinute,
    int? customEndHour,
    int? customEndMinute,
    double? observerLat,
    double? observerLon,
    double? observerElevation,
    String? observerLocationName,
  }) {
    return FilterState(
      minAltitude: minAltitude ?? this.minAltitude,
      maxAltitude: maxAltitude ?? this.maxAltitude,
      minDurationHours: minDurationHours ?? this.minDurationHours,
      date: date ?? this.date,
      minMoonSeparation: minMoonSeparation ?? this.minMoonSeparation,
      minAzimuth: minAzimuth ?? this.minAzimuth,
      maxAzimuth: maxAzimuth ?? this.maxAzimuth,
      quadrant: quadrant ?? this.quadrant,
      maxMagnitude: maxMagnitude ?? this.maxMagnitude,
      minMagnitude: minMagnitude ?? this.minMagnitude,
      minSizeArcmin: minSizeArcmin ?? this.minSizeArcmin,
      maxSizeArcmin: maxSizeArcmin ?? this.maxSizeArcmin,
      selectedCatalogs: selectedCatalogs ?? Set.from(this.selectedCatalogs),
      selectedObjectTypes: selectedObjectTypes ?? Set.from(this.selectedObjectTypes),
      searchQuery: searchQuery ?? this.searchQuery,
      maxTargets: maxTargets ?? this.maxTargets,
      useCustomHorizon: useCustomHorizon ?? this.useCustomHorizon,
      horizonPoints: horizonPoints ?? List.from(this.horizonPoints),
      panoramaImagePath: panoramaImagePath ?? this.panoramaImagePath,
      panoramaAzimuthOffset: panoramaAzimuthOffset ?? this.panoramaAzimuthOffset,
      panoramaAltitudeOffset: panoramaAltitudeOffset ?? this.panoramaAltitudeOffset,
      panoramaAltitudeScale: panoramaAltitudeScale ?? this.panoramaAltitudeScale,
      panoramaOpacity: panoramaOpacity ?? this.panoramaOpacity,
      useCustomTimeWindow: useCustomTimeWindow ?? this.useCustomTimeWindow,
      customStartHour: customStartHour ?? this.customStartHour,
      customStartMinute: customStartMinute ?? this.customStartMinute,
      customEndHour: customEndHour ?? this.customEndHour,
      customEndMinute: customEndMinute ?? this.customEndMinute,
      observerLat: observerLat ?? this.observerLat,
      observerLon: observerLon ?? this.observerLon,
      observerElevation: observerElevation ?? this.observerElevation,
      observerLocationName: observerLocationName ?? this.observerLocationName,
    );
  }

  Map<String, dynamic> toJson() => {
    'minAltitude': minAltitude,
    'maxAltitude': maxAltitude,
    'minDurationHours': minDurationHours,
    'minMoonSeparation': minMoonSeparation,
    'minAzimuth': minAzimuth,
    'maxAzimuth': maxAzimuth,
    'quadrant': quadrant,
    'maxMagnitude': maxMagnitude,
    'minMagnitude': minMagnitude,
    'minSizeArcmin': minSizeArcmin,
    'maxSizeArcmin': maxSizeArcmin,
    'selectedCatalogs': selectedCatalogs.toList(),
    'selectedObjectTypes': selectedObjectTypes.toList(),
    'searchQuery': searchQuery,
    'maxTargets': maxTargets,
    'useCustomHorizon': useCustomHorizon,
    'horizonPoints': horizonPoints.map((p) => p.toJson()).toList(),
    'panoramaImagePath': panoramaImagePath,
    'panoramaAzimuthOffset': panoramaAzimuthOffset,
    'panoramaAltitudeOffset': panoramaAltitudeOffset,
    'panoramaAltitudeScale': panoramaAltitudeScale,
    'panoramaOpacity': panoramaOpacity,
    'useCustomTimeWindow': useCustomTimeWindow,
    'customStartHour': customStartHour,
    'customStartMinute': customStartMinute,
    'customEndHour': customEndHour,
    'customEndMinute': customEndMinute,
    'observerLat': observerLat,
    'observerLon': observerLon,
    'observerElevation': observerElevation,
    'observerLocationName': observerLocationName,
  };

  factory FilterState.fromJson(Map<String, dynamic> json) {
    return FilterState(
      minAltitude: (json['minAltitude'] as num?)?.toDouble() ?? 30.0,
      maxAltitude: (json['maxAltitude'] as num?)?.toDouble() ?? 90.0,
      minDurationHours: (json['minDurationHours'] as num?)?.toDouble() ?? 2.0,
      minMoonSeparation: (json['minMoonSeparation'] as num?)?.toDouble() ?? 15.0,
      minAzimuth: (json['minAzimuth'] as num?)?.toDouble() ?? 0.0,
      maxAzimuth: (json['maxAzimuth'] as num?)?.toDouble() ?? 360.0,
      quadrant: json['quadrant'] as int? ?? 0,
      maxMagnitude: (json['maxMagnitude'] as num?)?.toDouble() ?? 14.0,
      minMagnitude: (json['minMagnitude'] as num?)?.toDouble() ?? -5.0,
      minSizeArcmin: (json['minSizeArcmin'] as num?)?.toDouble() ?? 0.0,
      maxSizeArcmin: (json['maxSizeArcmin'] as num?)?.toDouble() ?? 600.0,
      selectedCatalogs: (json['selectedCatalogs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          {'Messier', 'Caldwell'},
      selectedObjectTypes: (json['selectedObjectTypes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toSet(),
      searchQuery: json['searchQuery'] as String? ?? '',
      maxTargets: (json['maxTargets'] as num?)?.toInt() ?? 20,
      useCustomHorizon: json['useCustomHorizon'] as bool? ?? false,
      horizonPoints: (json['horizonPoints'] as List<dynamic>?)
              ?.map((p) => HorizonPointModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      panoramaImagePath: json['panoramaImagePath'] as String?,
      panoramaAzimuthOffset: (json['panoramaAzimuthOffset'] as num?)?.toDouble() ?? 0.0,
      panoramaAltitudeOffset: (json['panoramaAltitudeOffset'] as num?)?.toDouble() ?? 0.0,
      panoramaAltitudeScale: (json['panoramaAltitudeScale'] as num?)?.toDouble() ?? 1.0,
      panoramaOpacity: (json['panoramaOpacity'] as num?)?.toDouble() ?? 0.6,
      useCustomTimeWindow: json['useCustomTimeWindow'] as bool? ?? false,
      customStartHour: json['customStartHour'] as int? ?? 21,
      customStartMinute: json['customStartMinute'] as int? ?? 0,
      customEndHour: json['customEndHour'] as int? ?? 23,
      customEndMinute: json['customEndMinute'] as int? ?? 0,
      observerLat: (json['observerLat'] as num?)?.toDouble() ?? -22.2819,
      observerLon: (json['observerLon'] as num?)?.toDouble() ?? -42.5311,
      observerElevation: (json['observerElevation'] as num?)?.toDouble() ?? 858.0,
      observerLocationName: json['observerLocationName'] as String? ?? 'Nova Friburgo, Rio de Janeiro, Brazil',
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'observing_site.dart';
import 'terrain_profile_model.dart';

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HorizonPointModel &&
          runtimeType == other.runtimeType &&
          azimuth == other.azimuth &&
          altitude == other.altitude;

  @override
  int get hashCode => Object.hash(azimuth, altitude);
}

class FilterState {
  static const Object _sentinel = Object();

  final double minAltitude;
  final double maxAltitude;
  final double minDurationHours;
  final DateTime date;
  final double minMoonSeparation;
  final double minAzimuth;
  final double maxAzimuth;
  final int quadrant; // 0=All, 1=N, 2=E, 3=S, 4=W, 5=NE, 6=SE, 7=SW, 8=NW
  final double maxMagnitude;
  final double minMagnitude;
  final double minSizeArcmin;
  final double maxSizeArcmin;
  final Set<String> selectedCatalogs;
  final Set<String> selectedObjectTypes;
  final String searchQuery;
  final int maxTargets;

  // Custom Horizon Profile
  final bool useCustomHorizon;
  final List<HorizonPointModel> horizonPoints;
  final String? panoramaImagePath;
  final double panoramaAzimuthOffset; // 0..360 degrees to align North
  final double panoramaAltitudeOffset; // -20..+20 degrees for ground baseline
  final double panoramaAltitudeScale; // 0.5..2.0 vertical stretch
  final double panoramaOpacity; // 0.1..1.0 transparency

  // Mountain Silhouette / Terrain Horizon
  final bool showTerrainSilhouette;
  final TerrainProfileModel? terrainProfile;

  // Observing Time Window
  final bool useCustomTimeWindow;
  final int customStartHour;
  final int customStartMinute;
  final int customEndHour;
  final int customEndMinute;

  // Observer
  final double observerLat;
  final double observerLon;
  final double observerElevation;
  final String observerLocationName;

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
    this.showTerrainSilhouette = true,
    this.terrainProfile,
    this.useCustomTimeWindow = false,
    this.customStartHour = 21,
    this.customStartMinute = 0,
    this.customEndHour = 23,
    this.customEndMinute = 0,
    this.observerLat = ObservingSite.defaultLatitude,
    this.observerLon = ObservingSite.defaultLongitude,
    this.observerElevation = ObservingSite.defaultElevation,
    this.observerLocationName = ObservingSite.defaultSiteName,
  })  : date = date != null
            ? DateTime(date.year, date.month, date.day)
            : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
        horizonPoints = horizonPoints ?? const [],
        selectedCatalogs = selectedCatalogs ?? const {'Messier', 'Caldwell'},
        selectedObjectTypes = selectedObjectTypes ?? const {
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

  /// Returns whether a custom horizon or mountain terrain profile is active.
  bool get hasHorizon =>
      (useCustomHorizon && horizonPoints.isNotEmpty) ||
      (showTerrainSilhouette && terrainProfile != null);

  /// Returns interpolated obstacle altitude in degrees for any given azimuth [0..360].
  /// Combines custom obstacle polygon (e.g. roofs/trees) and DEM mountain profile if both active.
  double getHorizonAltitudeAt(double azDeg) {
    if (!hasHorizon) return 0.0;
    final normAz = ((azDeg % 360.0) + 360.0) % 360.0;

    double customAlt = 0.0;
    if (useCustomHorizon && horizonPoints.isNotEmpty) {
      customAlt = _interpolateHorizonPoints(normAz);
    }

    double terrainAlt = 0.0;
    if (showTerrainSilhouette && terrainProfile != null) {
      terrainAlt = terrainProfile!.altitudeAt(normAz);
    }

    if (useCustomHorizon && showTerrainSilhouette && terrainProfile != null && horizonPoints.isNotEmpty) {
      return math.max(customAlt, terrainAlt);
    } else if (useCustomHorizon && horizonPoints.isNotEmpty) {
      return customAlt;
    } else {
      return terrainAlt;
    }
  }

  double _interpolateHorizonPoints(double az) {
    if (horizonPoints.isEmpty) return 0.0;
    if (horizonPoints.length == 1) return horizonPoints.first.altitude;

    final sorted = List<HorizonPointModel>.from(horizonPoints)
      ..sort((a, b) => a.azimuth.compareTo(b.azimuth));

    for (int i = 0; i < sorted.length; i++) {
      if (az < sorted[i].azimuth) {
        final pPrev = i == 0 ? sorted.last : sorted[i - 1];
        final pNext = sorted[i];
        final span = (i == 0)
            ? (pNext.azimuth + 360.0) - pPrev.azimuth
            : pNext.azimuth - pPrev.azimuth;
        if (span <= 0.0001) return pNext.altitude;
        final frac = (i == 0)
            ? (az + 360.0 - pPrev.azimuth) / span
            : (az - pPrev.azimuth) / span;
        return pPrev.altitude + frac * (pNext.altitude - pPrev.altitude);
      }
    }

    final pPrev = sorted.last;
    final pNext = sorted.first;
    final span = (pNext.azimuth + 360.0) - pPrev.azimuth;
    if (span <= 0.0001) return pNext.altitude;
    final frac = (az - pPrev.azimuth) / span;
    return pPrev.altitude + frac * (pNext.altitude - pPrev.altitude);
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
    Object? panoramaImagePath = _sentinel,
    double? panoramaAzimuthOffset,
    double? panoramaAltitudeOffset,
    double? panoramaAltitudeScale,
    double? panoramaOpacity,
    bool? showTerrainSilhouette,
    Object? terrainProfile = _sentinel,
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
      panoramaImagePath: identical(panoramaImagePath, _sentinel)
          ? this.panoramaImagePath
          : panoramaImagePath as String?,
      panoramaAzimuthOffset: panoramaAzimuthOffset ?? this.panoramaAzimuthOffset,
      panoramaAltitudeOffset: panoramaAltitudeOffset ?? this.panoramaAltitudeOffset,
      panoramaAltitudeScale: panoramaAltitudeScale ?? this.panoramaAltitudeScale,
      panoramaOpacity: panoramaOpacity ?? this.panoramaOpacity,
      showTerrainSilhouette: showTerrainSilhouette ?? this.showTerrainSilhouette,
      terrainProfile: identical(terrainProfile, _sentinel)
          ? this.terrainProfile
          : terrainProfile as TerrainProfileModel?,
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
    'date': date.toIso8601String(),
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
    'showTerrainSilhouette': showTerrainSilhouette,
    'terrainProfile': terrainProfile?.toJson(),
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
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
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
          const {'Messier', 'Caldwell'},
      selectedObjectTypes: (json['selectedObjectTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet(),
      searchQuery: json['searchQuery'] as String? ?? '',
      maxTargets: (json['maxTargets'] as num?)?.toInt() ?? 20,
      useCustomHorizon: json['useCustomHorizon'] as bool? ?? false,
      horizonPoints: (json['horizonPoints'] as List<dynamic>?)
              ?.map((p) => HorizonPointModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
      panoramaImagePath: json['panoramaImagePath'] as String?,
      panoramaAzimuthOffset: (json['panoramaAzimuthOffset'] as num?)?.toDouble() ?? 0.0,
      panoramaAltitudeOffset: (json['panoramaAltitudeOffset'] as num?)?.toDouble() ?? 0.0,
      panoramaAltitudeScale: (json['panoramaAltitudeScale'] as num?)?.toDouble() ?? 1.0,
      panoramaOpacity: (json['panoramaOpacity'] as num?)?.toDouble() ?? 0.6,
      showTerrainSilhouette: json['showTerrainSilhouette'] as bool? ?? true,
      terrainProfile: json['terrainProfile'] != null
          ? TerrainProfileModel.fromJson(json['terrainProfile'] as Map<String, dynamic>)
          : null,
      useCustomTimeWindow: json['useCustomTimeWindow'] as bool? ?? false,
      customStartHour: json['customStartHour'] as int? ?? 21,
      customStartMinute: json['customStartMinute'] as int? ?? 0,
      customEndHour: json['customEndHour'] as int? ?? 23,
      customEndMinute: json['customEndMinute'] as int? ?? 0,
      observerLat: (json['observerLat'] as num?)?.toDouble() ?? ObservingSite.defaultLatitude,
      observerLon: (json['observerLon'] as num?)?.toDouble() ?? ObservingSite.defaultLongitude,
      observerElevation: (json['observerElevation'] as num?)?.toDouble() ?? ObservingSite.defaultElevation,
      observerLocationName: json['observerLocationName'] as String? ?? ObservingSite.defaultSiteName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterState &&
        other.minAltitude == minAltitude &&
        other.maxAltitude == maxAltitude &&
        other.minDurationHours == minDurationHours &&
        other.date == date &&
        other.minMoonSeparation == minMoonSeparation &&
        other.minAzimuth == minAzimuth &&
        other.maxAzimuth == maxAzimuth &&
        other.quadrant == quadrant &&
        other.maxMagnitude == maxMagnitude &&
        other.minMagnitude == minMagnitude &&
        other.minSizeArcmin == minSizeArcmin &&
        other.maxSizeArcmin == maxSizeArcmin &&
        setEquals(other.selectedCatalogs, selectedCatalogs) &&
        setEquals(other.selectedObjectTypes, selectedObjectTypes) &&
        other.searchQuery == searchQuery &&
        other.maxTargets == maxTargets &&
        other.useCustomHorizon == useCustomHorizon &&
        listEquals(other.horizonPoints, horizonPoints) &&
        other.panoramaImagePath == panoramaImagePath &&
        other.panoramaAzimuthOffset == panoramaAzimuthOffset &&
        other.panoramaAltitudeOffset == panoramaAltitudeOffset &&
        other.panoramaAltitudeScale == panoramaAltitudeScale &&
        other.panoramaOpacity == panoramaOpacity &&
        other.showTerrainSilhouette == showTerrainSilhouette &&
        other.terrainProfile == terrainProfile &&
        other.useCustomTimeWindow == useCustomTimeWindow &&
        other.customStartHour == customStartHour &&
        other.customStartMinute == customStartMinute &&
        other.customEndHour == customEndHour &&
        other.customEndMinute == customEndMinute &&
        other.observerLat == observerLat &&
        other.observerLon == observerLon &&
        other.observerElevation == observerElevation &&
        other.observerLocationName == observerLocationName;
  }

  @override
  int get hashCode => Object.hashAll([
        minAltitude,
        maxAltitude,
        minDurationHours,
        date,
        minMoonSeparation,
        minAzimuth,
        maxAzimuth,
        quadrant,
        maxMagnitude,
        minMagnitude,
        minSizeArcmin,
        maxSizeArcmin,
        Object.hashAll(selectedCatalogs),
        Object.hashAll(selectedObjectTypes),
        searchQuery,
        maxTargets,
        useCustomHorizon,
        Object.hashAll(horizonPoints),
        panoramaImagePath,
        panoramaAzimuthOffset,
        showTerrainSilhouette,
        useCustomTimeWindow,
        customStartHour,
        customStartMinute,
        customEndHour,
        customEndMinute,
        observerLat,
        observerLon,
        observerElevation,
      ]);
}

import 'dart:isolate';

import '../models/altitude_point.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/period_target_item.dart';
import '../models/target_item.dart';
import '../models/yearly_visibility.dart';
import 'astro_bridge.dart';

/// Helper for offloading compute-intensive astronomy calculations
/// to a background Dart isolate, ensuring the UI thread never drops frames.
class AstroIsolate {
  /// Evaluates celestial target filtering in a background isolate.
  static Future<List<TargetItem>> filterTargets({
    required String dbPath,
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  }) async {
    return await Isolate.run(() {
      final bridge = AstroBridge.create();
      bridge.initEngine(dbPath);
      try {
        return bridge.filterTargets(
          filters: filters,
          night: night,
          stepMinutes: stepMinutes,
        );
      } finally {
        bridge.dispose();
      }
    });
  }

  /// Evaluates solar system planets in a background isolate.
  static Future<List<TargetItem>> getPlanets({
    required String dbPath,
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  }) async {
    return await Isolate.run(() {
      final bridge = AstroBridge.create();
      bridge.initEngine(dbPath);
      try {
        return bridge.getPlanets(
          filters: filters,
          night: night,
          stepMinutes: stepMinutes,
        );
      } finally {
        bridge.dispose();
      }
    });
  }

  /// Evaluates bright stars in a background isolate.
  static Future<List<TargetItem>> getBrightStars({
    required String dbPath,
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  }) async {
    return await Isolate.run(() {
      final bridge = AstroBridge.create();
      bridge.initEngine(dbPath);
      try {
        return bridge.getBrightStars(
          filters: filters,
          night: night,
          stepMinutes: stepMinutes,
        );
      } finally {
        bridge.dispose();
      }
    });
  }

  /// Evaluates period target filtering in a background isolate.
  static Future<List<PeriodTargetItem>> filterTargetsPeriod({
    required String dbPath,
    required FilterState filters,
    required DateTime periodStart,
    required DateTime periodEnd,
    int stepMinutes = 10,
  }) async {
    return await Isolate.run(() {
      final bridge = AstroBridge.create();
      bridge.initEngine(dbPath);
      try {
        return bridge.filterTargetsPeriod(
          filters: filters,
          periodStart: periodStart,
          periodEnd: periodEnd,
          stepMinutes: stepMinutes,
        );
      } finally {
        bridge.dispose();
      }
    });
  }

  /// Generates altitude curves in a background isolate.
  static Future<List<AltitudePoint>> generateAltitudeCurve({
    required String dbPath,
    required int targetId,
    required double latitude,
    required double longitude,
    required double elevation,
    required DateTime start,
    required DateTime end,
    int stepMinutes = 5,
  }) async {
    return await Isolate.run(() {
      final bridge = AstroBridge.create();
      bridge.initEngine(dbPath);
      try {
        return bridge.generateAltitudeCurve(
          targetId: targetId,
          latitude: latitude,
          longitude: longitude,
          elevation: elevation,
          start: start,
          end: end,
          stepMinutes: stepMinutes,
        );
      } finally {
        bridge.dispose();
      }
    });
  }

  /// Computes yearly visibility stats across 365 days in a background isolate.
  static Future<YearlyVisibilityModel?> getTargetYearlyVisibility({
    required String dbPath,
    required int targetId,
    required double latitude,
    required double longitude,
    required double elevation,
    FilterState? filters,
    double minAltitude = 30.0,
    double minDurationHours = 2.0,
    int? year,
  }) async {
    return await Isolate.run(() {
      final bridge = AstroBridge.create();
      bridge.initEngine(dbPath);
      try {
        return bridge.getTargetYearlyVisibility(
          targetId: targetId,
          latitude: latitude,
          longitude: longitude,
          elevation: elevation,
          filters: filters,
          minAltitude: minAltitude,
          minDurationHours: minDurationHours,
          year: year,
        );
      } finally {
        bridge.dispose();
      }
    });
  }
}

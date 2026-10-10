import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'astro_ffi_types.dart';
import '../models/target_item.dart';
import '../models/period_target_item.dart';
import '../models/night_summary.dart';
import '../models/altitude_point.dart';
import '../models/filter_state.dart';

/// Pure data mappers and builders converting between C ABI FFI structs and Dart domain models.
class FfiMappers {
  /// Safely converts a native Utf8 pointer to Dart String, returning empty string if null or zero-addressed.
  static String pointerToString(Pointer<Utf8> ptr) {
    return ptr.address != 0 ? ptr.toDartString() : '';
  }

  /// Maps native `AstroNightSummary` to Dart `NightSummary`.
  static NightSummary mapNightSummary(AstroNightSummary s) {
    return NightSummary(
      sunset: DateTime.fromMillisecondsSinceEpoch(s.sunsetUtc * 1000, isUtc: true).toLocal(),
      civilDusk: DateTime.fromMillisecondsSinceEpoch(s.civilDuskUtc * 1000, isUtc: true).toLocal(),
      nauticalDusk: DateTime.fromMillisecondsSinceEpoch(s.nauticalDuskUtc * 1000, isUtc: true).toLocal(),
      astronomicalDusk: DateTime.fromMillisecondsSinceEpoch(s.astronomicalDuskUtc * 1000, isUtc: true).toLocal(),
      solarMidnight: DateTime.fromMillisecondsSinceEpoch(s.solarMidnightUtc * 1000, isUtc: true).toLocal(),
      astronomicalDawn: DateTime.fromMillisecondsSinceEpoch(s.astronomicalDawnUtc * 1000, isUtc: true).toLocal(),
      nauticalDawn: DateTime.fromMillisecondsSinceEpoch(s.nauticalDawnUtc * 1000, isUtc: true).toLocal(),
      civilDawn: DateTime.fromMillisecondsSinceEpoch(s.civilDawnUtc * 1000, isUtc: true).toLocal(),
      sunrise: DateTime.fromMillisecondsSinceEpoch(s.sunriseUtc * 1000, isUtc: true).toLocal(),
      moonIllumination: s.moonIllumination,
      moonPhaseName: pointerToString(s.moonPhaseName),
      hasAstronomicalNight: s.hasAstronomicalNight == 1,
    );
  }

  /// Maps native `AstroTargetItem` to Dart `TargetItem`.
  static TargetItem mapTargetItem(AstroTargetItem item) {
    final mag = item.magnitude < 900.0 ? item.magnitude : null;
    final majAx = item.majorAxisArcmin >= 0.0 ? item.majorAxisArcmin : null;
    final posAng = item.positionAngleDeg >= 0.0 ? item.positionAngleDeg : null;
    final sb = item.surfaceBrightness >= 0.0 ? item.surfaceBrightness : null;

    final nameStr = pointerToString(item.name);
    final mStr = pointerToString(item.messier);
    final cStr = pointerToString(item.caldwell);
    final arpStr = pointerToString(item.arp);
    final herschelStr = pointerToString(item.herschel);
    final catStr = pointerToString(item.catalog);
    final typeStr = pointerToString(item.objectType);
    final constelStr = pointerToString(item.constellation);
    final commonStr = pointerToString(item.commonName);

    final transit = DateTime.fromMillisecondsSinceEpoch(item.transitUtc * 1000, isUtc: true).toLocal();
    final vStart = item.visibleStartUtc > 0
        ? DateTime.fromMillisecondsSinceEpoch(item.visibleStartUtc * 1000, isUtc: true).toLocal()
        : null;
    final vEnd = item.visibleEndUtc > 0
        ? DateTime.fromMillisecondsSinceEpoch(item.visibleEndUtc * 1000, isUtc: true).toLocal()
        : null;

    return TargetItem(
      id: item.id,
      name: nameStr,
      messier: mStr.isNotEmpty ? mStr : null,
      caldwell: cStr.isNotEmpty ? cStr : null,
      arp: arpStr.isNotEmpty ? arpStr : null,
      herschel: herschelStr.isNotEmpty ? herschelStr : null,
      catalog: catStr,
      objectType: typeStr,
      constellation: constelStr,
      raHours: item.raHours,
      decDegrees: item.decDegrees,
      magnitude: mag,
      majorAxisArcmin: majAx,
      positionAngleDeg: posAng,
      surfaceBrightness: sb,
      commonName: commonStr.isNotEmpty ? commonStr : null,
      peakAltitudeDeg: item.peakAltitudeDeg,
      visibleDurationHours: item.visibleDurationHours,
      transitTime: transit,
      visibleStartTime: vStart,
      visibleEndTime: vEnd,
      minMoonSepDeg: item.minMoonSepDeg,
      meetsCriteria: item.meetsCriteria == 1,
    );
  }

  /// Maps native `AstroPeriodTargetItem` to Dart `PeriodTargetItem`.
  static PeriodTargetItem mapPeriodTargetItem(AstroPeriodTargetItem cItem) {
    final mStr = pointerToString(cItem.messier);
    final cStr = pointerToString(cItem.caldwell);
    final arpStr = pointerToString(cItem.arp);
    final herschelStr = pointerToString(cItem.herschel);
    final commonStr = pointerToString(cItem.commonName);

    final peakDt = cItem.peakDateUtc > 0
        ? () {
            final utc = DateTime.fromMillisecondsSinceEpoch(cItem.peakDateUtc * 1000, isUtc: true);
            return DateTime(utc.year, utc.month, utc.day);
          }()
        : null;

    return PeriodTargetItem(
      id: cItem.id,
      name: pointerToString(cItem.name),
      messier: mStr.isNotEmpty ? mStr : null,
      caldwell: cStr.isNotEmpty ? cStr : null,
      arp: arpStr.isNotEmpty ? arpStr : null,
      herschel: herschelStr.isNotEmpty ? herschelStr : null,
      catalog: pointerToString(cItem.catalog),
      objectType: pointerToString(cItem.objectType),
      constellation: pointerToString(cItem.constellation),
      raHours: cItem.raHours,
      decDegrees: cItem.decDegrees,
      magnitude: cItem.magnitude < 900.0 ? cItem.magnitude : null,
      majorAxisArcmin: cItem.majorAxisArcmin >= 0 ? cItem.majorAxisArcmin : null,
      positionAngleDeg: cItem.positionAngleDeg >= 0 ? cItem.positionAngleDeg : null,
      surfaceBrightness: cItem.surfaceBrightness >= 0 ? cItem.surfaceBrightness : null,
      commonName: commonStr.isNotEmpty ? commonStr : null,
      peakAltitudeDeg: cItem.peakAltitudeDeg,
      maxHoursObservable: cItem.maxHoursObservable,
      peakDate: peakDt,
      observableDaysCount: cItem.observableDaysCount,
      totalPeriodDays: cItem.totalPeriodDays,
      startMonth: cItem.startMonth,
      startDay: cItem.startDay,
      endMonth: cItem.endMonth,
      endDay: cItem.endDay,
      isObservable: cItem.isObservable != 0,
    );
  }

  /// Maps native `AstroAltitudePoint` to Dart `AltitudePoint`.
  static AltitudePoint mapAltitudePoint(AstroAltitudePoint p) {
    return AltitudePoint(
      time: DateTime.fromMillisecondsSinceEpoch(p.timestampUtc * 1000, isUtc: true).toLocal(),
      altitude: p.altitudeDeg,
      azimuth: p.azimuthDeg,
      moonSeparation: p.moonSeparationDeg,
      meetsCriteria: p.meetsCriteria == 1,
    );
  }

  /// Populates native `AstroObserver` struct from observer coordinates.
  static void populateObserver(
    Pointer<AstroObserver> obsPtr, {
    required double latitudeDeg,
    required double longitudeDeg,
    required double elevationM,
  }) {
    obsPtr.ref.latitudeDeg = latitudeDeg;
    obsPtr.ref.longitudeDeg = longitudeDeg;
    obsPtr.ref.elevationM = elevationM;
  }

  /// Populates custom horizon profile into `AstroFilterCriteria`.
  static void populateCustomHorizon(
    Pointer<AstroFilterCriteria> critPtr,
    FilterState? filters,
    List<Pointer<NativeType>> allocatedPointers,
  ) {
    if (filters == null) {
      critPtr.ref.maxAltitudeDeg = 90.0;
      critPtr.ref.useCustomHorizon = 0;
      critPtr.ref.horizonPointsCount = 0;
      critPtr.ref.horizonAzimuths = nullptr;
      critPtr.ref.horizonAltitudes = nullptr;
      return;
    }

    critPtr.ref.maxAltitudeDeg = filters.maxAltitude;

    if (filters.useCustomHorizon && filters.horizonPoints.isNotEmpty) {
      final count = filters.horizonPoints.length;
      final azPtr = calloc<Double>(count);
      final altPtr = calloc<Double>(count);
      allocatedPointers.add(azPtr);
      allocatedPointers.add(altPtr);

      for (int i = 0; i < count; i++) {
        azPtr[i] = filters.horizonPoints[i].azimuth;
        altPtr[i] = filters.horizonPoints[i].altitude;
      }

      critPtr.ref.useCustomHorizon = 1;
      critPtr.ref.horizonPointsCount = count;
      critPtr.ref.horizonAzimuths = azPtr;
      critPtr.ref.horizonAltitudes = altPtr;
    } else {
      critPtr.ref.useCustomHorizon = 0;
      critPtr.ref.horizonPointsCount = 0;
      critPtr.ref.horizonAzimuths = nullptr;
      critPtr.ref.horizonAltitudes = nullptr;
    }
  }

  /// Populates native `AstroFilterCriteria` struct from `FilterState` and target window.
  static void populateCriteria(
    Pointer<AstroFilterCriteria> critPtr, {
    required FilterState filters,
    required int windowStartUtc,
    required int windowEndUtc,
    required int limit,
    required List<Pointer<NativeType>> allocatedPointers,
    int? utcOffsetMinutes,
  }) {
    critPtr.ref.minAltitudeDeg = filters.minAltitude;
    critPtr.ref.minDurationHours = filters.minDurationHours;
    critPtr.ref.windowStartUtc = windowStartUtc;
    critPtr.ref.windowEndUtc = windowEndUtc;
    critPtr.ref.minMoonSeparationDeg = filters.minMoonSeparation;
    critPtr.ref.minAzimuthDeg = filters.minAzimuth;
    critPtr.ref.maxAzimuthDeg = filters.maxAzimuth;
    critPtr.ref.quadrant = filters.quadrant;
    critPtr.ref.maxMagnitude = filters.maxMagnitude;
    critPtr.ref.minMagnitude = filters.minMagnitude;
    critPtr.ref.minSizeArcmin = filters.minSizeArcmin;
    critPtr.ref.maxSizeArcmin = filters.maxSizeArcmin;

    final catStr = filters.selectedCatalogs.join(',');
    final catUtf8 = catStr.toNativeUtf8();
    allocatedPointers.add(catUtf8);
    critPtr.ref.catalogsCsv = catUtf8;

    final typeStr = filters.selectedObjectTypes.join(',');
    final typeUtf8 = typeStr.toNativeUtf8();
    allocatedPointers.add(typeUtf8);
    critPtr.ref.objectTypesCsv = typeUtf8;

    final searchUtf8 = filters.searchQuery.trim().toNativeUtf8();
    allocatedPointers.add(searchUtf8);
    critPtr.ref.searchQuery = searchUtf8;

    critPtr.ref.limit = limit;
    critPtr.ref.offset = 0;
    critPtr.ref.useCustomTimeWindow = filters.useCustomTimeWindow ? 1 : 0;
    critPtr.ref.customStartHour = filters.customStartHour;
    critPtr.ref.customStartMinute = filters.customStartMinute;
    critPtr.ref.customEndHour = filters.customEndHour;
    critPtr.ref.customEndMinute = filters.customEndMinute;
    critPtr.ref.utcOffsetMinutes = utcOffsetMinutes ?? filters.date.timeZoneOffset.inMinutes;

    populateCustomHorizon(critPtr, filters, allocatedPointers);
  }
}

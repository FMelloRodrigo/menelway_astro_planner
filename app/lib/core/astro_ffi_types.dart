import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Opaque Engine handle
final class AstroEngineContext extends Opaque {}

final class AstroObserver extends Struct {
  @Double()
  external double latitudeDeg;

  @Double()
  external double longitudeDeg;

  @Double()
  external double elevationM;
}

final class AstroNightSummary extends Struct {
  @Int64()
  external int sunsetUtc;

  @Int64()
  external int civilDuskUtc;

  @Int64()
  external int nauticalDuskUtc;

  @Int64()
  external int astronomicalDuskUtc;

  @Int64()
  external int solarMidnightUtc;

  @Int64()
  external int astronomicalDawnUtc;

  @Int64()
  external int nauticalDawnUtc;

  @Int64()
  external int civilDawnUtc;

  @Int64()
  external int sunriseUtc;

  @Double()
  external double moonIllumination;

  external Pointer<Utf8> moonPhaseName;

  @Int32()
  external int hasAstronomicalNight;
}

final class AstroFilterCriteria extends Struct {
  @Double()
  external double minAltitudeDeg;

  @Double()
  external double minDurationHours;

  @Int64()
  external int windowStartUtc;

  @Int64()
  external int windowEndUtc;

  @Double()
  external double minMoonSeparationDeg;

  @Double()
  external double minAzimuthDeg;

  @Double()
  external double maxAzimuthDeg;

  @Int32()
  external int quadrant;

  @Double()
  external double maxMagnitude;

  @Double()
  external double minMagnitude;

  @Double()
  external double minSizeArcmin;

  @Double()
  external double maxSizeArcmin;

  external Pointer<Utf8> catalogsCsv;

  external Pointer<Utf8> objectTypesCsv;

  external Pointer<Utf8> searchQuery;

  @Int32()
  external int limit;

  @Int32()
  external int offset;

  @Int32()
  external int useCustomTimeWindow;

  @Int32()
  external int customStartHour;

  @Int32()
  external int customStartMinute;

  @Int32()
  external int customEndHour;

  @Int32()
  external int customEndMinute;

  @Int32()
  external int utcOffsetMinutes;
}

final class AstroTargetItem extends Struct {
  @Int64()
  external int id;

  external Pointer<Utf8> name;

  external Pointer<Utf8> messier;

  external Pointer<Utf8> caldwell;

  external Pointer<Utf8> arp;

  external Pointer<Utf8> herschel;

  external Pointer<Utf8> catalog;

  external Pointer<Utf8> objectType;

  external Pointer<Utf8> constellation;

  @Double()
  external double raHours;

  @Double()
  external double decDegrees;

  @Double()
  external double magnitude;

  @Double()
  external double majorAxisArcmin;

  @Double()
  external double positionAngleDeg;

  @Double()
  external double surfaceBrightness;

  external Pointer<Utf8> commonName;

  @Double()
  external double peakAltitudeDeg;

  @Double()
  external double visibleDurationHours;

  @Int64()
  external int transitUtc;

  @Int64()
  external int visibleStartUtc;

  @Int64()
  external int visibleEndUtc;

  @Double()
  external double minMoonSepDeg;

  @Int32()
  external int meetsCriteria;
}

final class AstroTargetList extends Struct {
  external Pointer<AstroTargetItem> items;

  @Size()
  external int count;
}

final class AstroAltitudePoint extends Struct {
  @Int64()
  external int timestampUtc;

  @Double()
  external double altitudeDeg;

  @Double()
  external double azimuthDeg;

  @Double()
  external double moonSeparationDeg;

  @Int32()
  external int meetsCriteria;
}

final class AstroCurveData extends Struct {
  external Pointer<AstroAltitudePoint> points;

  @Size()
  external int count;
}

final class AstroPeriodTargetItem extends Struct {
  @Int64()
  external int id;

  external Pointer<Utf8> name;
  external Pointer<Utf8> messier;
  external Pointer<Utf8> caldwell;
  external Pointer<Utf8> arp;
  external Pointer<Utf8> herschel;
  external Pointer<Utf8> catalog;
  external Pointer<Utf8> objectType;
  external Pointer<Utf8> constellation;

  @Double()
  external double raHours;

  @Double()
  external double decDegrees;

  @Double()
  external double magnitude;

  @Double()
  external double majorAxisArcmin;

  @Double()
  external double positionAngleDeg;

  @Double()
  external double surfaceBrightness;

  external Pointer<Utf8> commonName;

  @Double()
  external double peakAltitudeDeg;

  @Double()
  external double maxHoursObservable;

  @Int64()
  external int peakDateUtc;

  @Int32()
  external int observableDaysCount;

  @Int32()
  external int totalPeriodDays;

  @Int32()
  external int startMonth;

  @Int32()
  external int startDay;

  @Int32()
  external int endMonth;

  @Int32()
  external int endDay;

  @Int32()
  external int isObservable;
}

final class AstroPeriodTargetList extends Struct {
  external Pointer<AstroPeriodTargetItem> items;

  @Size()
  external int count;
}

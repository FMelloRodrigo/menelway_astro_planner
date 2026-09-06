import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import 'astro_ffi_types.dart';
import '../models/target_item.dart';
import '../models/night_summary.dart';
import '../models/altitude_point.dart';
import '../models/filter_state.dart';
import '../models/observing_list.dart';

// Typedefs for Native and Dart functions
typedef _AstroEngineCreateC = Pointer<AstroEngineContext> Function(Pointer<Utf8> dbPath);
typedef _AstroEngineCreateDart = Pointer<AstroEngineContext> Function(Pointer<Utf8> dbPath);

typedef _AstroEngineDestroyC = Void Function(Pointer<AstroEngineContext> engine);
typedef _AstroEngineDestroyDart = void Function(Pointer<AstroEngineContext> engine);

typedef _AstroEngineGetLastErrorC = Pointer<Utf8> Function(Pointer<AstroEngineContext> engine);
typedef _AstroEngineGetLastErrorDart = Pointer<Utf8> Function(Pointer<AstroEngineContext> engine);

typedef _AstroGetNightSummaryC = Int32 Function(
  Pointer<AstroEngineContext> engine,
  Pointer<AstroObserver> observer,
  Int64 dateTimestampUtc,
  Pointer<AstroNightSummary> outSummary,
);
typedef _AstroGetNightSummaryDart = int Function(
  Pointer<AstroEngineContext> engine,
  Pointer<AstroObserver> observer,
  int dateTimestampUtc,
  Pointer<AstroNightSummary> outSummary,
);

typedef _AstroFilterTargetsC = Pointer<AstroTargetList> Function(
  Pointer<AstroEngineContext> engine,
  Pointer<AstroObserver> observer,
  Pointer<AstroFilterCriteria> criteria,
  Int32 stepMinutes,
);
typedef _AstroFilterTargetsDart = Pointer<AstroTargetList> Function(
  Pointer<AstroEngineContext> engine,
  Pointer<AstroObserver> observer,
  Pointer<AstroFilterCriteria> criteria,
  int stepMinutes,
);

typedef _AstroFreeTargetListC = Void Function(Pointer<AstroTargetList> list);
typedef _AstroFreeTargetListDart = void Function(Pointer<AstroTargetList> list);

typedef _AstroGenerateCurveC = Pointer<AstroCurveData> Function(
  Pointer<AstroEngineContext> engine,
  Int64 targetId,
  Pointer<AstroObserver> observer,
  Int64 startUtc,
  Int64 endUtc,
  Int32 stepMinutes,
);
typedef _AstroGenerateCurveDart = Pointer<AstroCurveData> Function(
  Pointer<AstroEngineContext> engine,
  int targetId,
  Pointer<AstroObserver> observer,
  int startUtc,
  int endUtc,
  int stepMinutes,
);

typedef _AstroFreeCurveDataC = Void Function(Pointer<AstroCurveData> curve);
typedef _AstroFreeCurveDataDart = void Function(Pointer<AstroCurveData> curve);

typedef _AstroCreateObservingListC = Int64 Function(
  Pointer<AstroEngineContext> engine,
  Pointer<Utf8> name,
  Pointer<Utf8> description,
  Pointer<Utf8> sessionDate,
);
typedef _AstroCreateObservingListDart = int Function(
  Pointer<AstroEngineContext> engine,
  Pointer<Utf8> name,
  Pointer<Utf8> description,
  Pointer<Utf8> sessionDate,
);

typedef _AstroDeleteObservingListC = Int32 Function(
  Pointer<AstroEngineContext> engine,
  Int64 listId,
);
typedef _AstroDeleteObservingListDart = int Function(
  Pointer<AstroEngineContext> engine,
  int listId,
);

typedef _AstroAddToListC = Int32 Function(
  Pointer<AstroEngineContext> engine,
  Int64 listId,
  Int64 dsoId,
  Pointer<Utf8> notes,
);
typedef _AstroAddToListDart = int Function(
  Pointer<AstroEngineContext> engine,
  int listId,
  int dsoId,
  Pointer<Utf8> notes,
);

typedef _AstroRemoveFromListC = Int32 Function(
  Pointer<AstroEngineContext> engine,
  Int64 listId,
  Int64 dsoId,
);
typedef _AstroRemoveFromListDart = int Function(
  Pointer<AstroEngineContext> engine,
  int listId,
  int dsoId,
);

typedef _AstroGetListsJsonC = Pointer<Utf8> Function(Pointer<AstroEngineContext> engine);
typedef _AstroGetListsJsonDart = Pointer<Utf8> Function(Pointer<AstroEngineContext> engine);

typedef _AstroClearAllObservingListsC = Int32 Function(Pointer<AstroEngineContext> engine);
typedef _AstroClearAllObservingListsDart = int Function(Pointer<AstroEngineContext> engine);

typedef _AstroFreeStringC = Void Function(Pointer<Utf8> str);
typedef _AstroFreeStringDart = void Function(Pointer<Utf8> str);

class AstroBridge {
  static AstroBridge? _instance;
  late final DynamicLibrary _lib;
  Pointer<AstroEngineContext>? _engine;

  late final _AstroEngineCreateDart _engineCreate;
  late final _AstroEngineDestroyDart _engineDestroy;
  late final _AstroEngineGetLastErrorDart _engineGetLastError;
  late final _AstroGetNightSummaryDart _getNightSummary;
  late final _AstroFilterTargetsDart _filterTargets;
  late final _AstroFreeTargetListDart _freeTargetList;
  late final _AstroGenerateCurveDart _generateCurve;
  late final _AstroFreeCurveDataDart _freeCurveData;
  late final _AstroCreateObservingListDart _createList;
  late final _AstroDeleteObservingListDart _deleteList;
  late final _AstroAddToListDart _addToList;
  late final _AstroRemoveFromListDart _removeFromList;
  late final _AstroGetListsJsonDart _getListsJson;
  late final _AstroClearAllObservingListsDart _clearAllLists;
  late final _AstroFreeStringDart _freeString;

  AstroBridge._() {
    _lib = _loadLibrary();
    _bindFunctions();
  }

  static AstroBridge get instance {
    _instance ??= AstroBridge._();
    return _instance!;
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isWindows) {
      // 1. Try standard DLL load (same directory as .exe)
      try {
        return DynamicLibrary.open('astro_core.dll');
      } catch (_) {}

      // 2. Try path relative to executable
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final dllPath = p.join(exeDir, 'astro_core.dll');
      if (File(dllPath).existsSync()) {
        return DynamicLibrary.open(dllPath);
      }

      // 3. Try build output from core/build/Release
      final devDll = p.join(Directory.current.path, '..', 'core', 'build', 'Release', 'astro_core.dll');
      if (File(devDll).existsSync()) {
        return DynamicLibrary.open(p.canonicalize(devDll));
      }

      final devDllAlt = p.join(Directory.current.path, 'core', 'build', 'Release', 'astro_core.dll');
      if (File(devDllAlt).existsSync()) {
        return DynamicLibrary.open(p.canonicalize(devDllAlt));
      }

      return DynamicLibrary.open('astro_core.dll');
    } else if (Platform.isAndroid) {
      return DynamicLibrary.open('libastro_core.so');
    } else {
      return DynamicLibrary.process();
    }
  }

  void _bindFunctions() {
    _engineCreate = _lib
        .lookup<NativeFunction<_AstroEngineCreateC>>('astro_engine_create')
        .asFunction<_AstroEngineCreateDart>();
    _engineDestroy = _lib
        .lookup<NativeFunction<_AstroEngineDestroyC>>('astro_engine_destroy')
        .asFunction<_AstroEngineDestroyDart>();
    _engineGetLastError = _lib
        .lookup<NativeFunction<_AstroEngineGetLastErrorC>>('astro_engine_get_last_error')
        .asFunction<_AstroEngineGetLastErrorDart>();
    _getNightSummary = _lib
        .lookup<NativeFunction<_AstroGetNightSummaryC>>('astro_get_night_summary')
        .asFunction<_AstroGetNightSummaryDart>();
    _filterTargets = _lib
        .lookup<NativeFunction<_AstroFilterTargetsC>>('astro_filter_targets')
        .asFunction<_AstroFilterTargetsDart>();
    _freeTargetList = _lib
        .lookup<NativeFunction<_AstroFreeTargetListC>>('astro_free_target_list')
        .asFunction<_AstroFreeTargetListDart>();
    _generateCurve = _lib
        .lookup<NativeFunction<_AstroGenerateCurveC>>('astro_generate_curve')
        .asFunction<_AstroGenerateCurveDart>();
    _freeCurveData = _lib
        .lookup<NativeFunction<_AstroFreeCurveDataC>>('astro_free_curve_data')
        .asFunction<_AstroFreeCurveDataDart>();
    _createList = _lib
        .lookup<NativeFunction<_AstroCreateObservingListC>>('astro_create_observing_list')
        .asFunction<_AstroCreateObservingListDart>();
    _deleteList = _lib
        .lookup<NativeFunction<_AstroDeleteObservingListC>>('astro_delete_observing_list')
        .asFunction<_AstroDeleteObservingListDart>();
    _addToList = _lib
        .lookup<NativeFunction<_AstroAddToListC>>('astro_add_to_observing_list')
        .asFunction<_AstroAddToListDart>();
    _removeFromList = _lib
        .lookup<NativeFunction<_AstroRemoveFromListC>>('astro_remove_from_observing_list')
        .asFunction<_AstroRemoveFromListDart>();
    _getListsJson = _lib
        .lookup<NativeFunction<_AstroGetListsJsonC>>('astro_get_observing_lists_json')
        .asFunction<_AstroGetListsJsonDart>();
    _clearAllLists = _lib
        .lookup<NativeFunction<_AstroClearAllObservingListsC>>('astro_clear_all_observing_lists')
        .asFunction<_AstroClearAllObservingListsDart>();
    _freeString = _lib
        .lookup<NativeFunction<_AstroFreeStringC>>('astro_free_string')
        .asFunction<_AstroFreeStringDart>();
  }

  void initEngine(String dbPath) {
    if (_engine != null) {
      _engineDestroy(_engine!);
      _engine = null;
    }
    final dbPathUtf8 = dbPath.toNativeUtf8();
    try {
      _engine = _engineCreate(dbPathUtf8);
    } finally {
      calloc.free(dbPathUtf8);
    }
  }

  void dispose() {
    if (_engine != null) {
      _engineDestroy(_engine!);
      _engine = null;
    }
  }

  String getLastError() {
    if (_engine == null) return "Engine not initialized";
    final ptr = _engineGetLastError(_engine!);
    return ptr.toDartString();
  }

  NightSummary getNightSummary({
    required double latitude,
    required double longitude,
    required double elevation,
    required DateTime date,
  }) {
    if (_engine == null) {
      throw StateError("AstroEngine not initialized");
    }

    final obsPtr = calloc<AstroObserver>();
    final summaryPtr = calloc<AstroNightSummary>();

    try {
      obsPtr.ref.latitudeDeg = latitude;
      obsPtr.ref.longitudeDeg = longitude;
      obsPtr.ref.elevationM = elevation;

      final dateSecondsUtc = date.toUtc().millisecondsSinceEpoch ~/ 1000;
      final ok = _getNightSummary(_engine!, obsPtr, dateSecondsUtc, summaryPtr);
      if (ok != 1) {
        throw StateError("Failed to get night summary: ${getLastError()}");
      }

      final s = summaryPtr.ref;
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
        moonPhaseName: s.moonPhaseName.toDartString(),
        hasAstronomicalNight: s.hasAstronomicalNight == 1,
      );
    } finally {
      calloc.free(obsPtr);
      calloc.free(summaryPtr);
    }
  }

  List<TargetItem> filterTargets({
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  }) {
    if (_engine == null) return [];

    final obsPtr = calloc<AstroObserver>();
    final critPtr = calloc<AstroFilterCriteria>();

    Pointer<Utf8>? catUtf8;
    Pointer<Utf8>? typeUtf8;
    Pointer<Utf8>? searchUtf8;

    try {
      obsPtr.ref.latitudeDeg = filters.observerLat;
      obsPtr.ref.longitudeDeg = filters.observerLon;
      obsPtr.ref.elevationM = filters.observerElevation;

      critPtr.ref.minAltitudeDeg = filters.minAltitude;
      critPtr.ref.minDurationHours = filters.minDurationHours;

      int windowStartUtc;
      int windowEndUtc;
      if (filters.useCustomTimeWindow) {
        final startDt = filters.getWindowStart(filters.date);
        final endDt = filters.getWindowEnd(filters.date);
        windowStartUtc = startDt.toUtc().millisecondsSinceEpoch ~/ 1000;
        windowEndUtc = endDt.toUtc().millisecondsSinceEpoch ~/ 1000;
      } else {
        if (!night.hasAstronomicalNight || night.astronomicalDawn.isBefore(night.astronomicalDusk)) {
          final start = night.nauticalDusk.isBefore(night.nauticalDawn) ? night.nauticalDusk : night.sunset;
          final end = night.nauticalDawn.isAfter(night.nauticalDusk) ? night.nauticalDawn : night.sunrise;
          windowStartUtc = start.toUtc().millisecondsSinceEpoch ~/ 1000;
          windowEndUtc = end.toUtc().millisecondsSinceEpoch ~/ 1000;
        } else {
          windowStartUtc = night.astronomicalDusk.toUtc().millisecondsSinceEpoch ~/ 1000;
          windowEndUtc = night.astronomicalDawn.toUtc().millisecondsSinceEpoch ~/ 1000;
        }
      }
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
      catUtf8 = catStr.toNativeUtf8();
      critPtr.ref.catalogsCsv = catUtf8;

      final typeStr = filters.selectedObjectTypes.join(',');
      typeUtf8 = typeStr.toNativeUtf8();
      critPtr.ref.objectTypesCsv = typeUtf8;

      searchUtf8 = filters.searchQuery.trim().toNativeUtf8();
      critPtr.ref.searchQuery = searchUtf8;

      critPtr.ref.limit = 200;
      critPtr.ref.offset = 0;

      final listPtr = _filterTargets(_engine!, obsPtr, critPtr, stepMinutes);
      if (listPtr == nullptr) return [];

      try {
        final count = listPtr.ref.count;
        final itemsPtr = listPtr.ref.items;
        final results = <TargetItem>[];

        for (int i = 0; i < count; ++i) {
          final item = itemsPtr[i];

          final mag = item.magnitude < 900.0 ? item.magnitude : null;
          final majAx = item.majorAxisArcmin >= 0.0 ? item.majorAxisArcmin : null;
          final sb = item.surfaceBrightness >= 0.0 ? item.surfaceBrightness : null;

          final mStr = item.messier.toDartString();
          final cStr = item.caldwell.toDartString();
          final arpStr = item.arp.toDartString();
          final herschelStr = item.herschel.toDartString();
          final commonStr = item.commonName.toDartString();

          final transit = DateTime.fromMillisecondsSinceEpoch(item.transitUtc * 1000, isUtc: true).toLocal();
          final vStart = item.visibleStartUtc > 0
              ? DateTime.fromMillisecondsSinceEpoch(item.visibleStartUtc * 1000, isUtc: true).toLocal()
              : null;
          final vEnd = item.visibleEndUtc > 0
              ? DateTime.fromMillisecondsSinceEpoch(item.visibleEndUtc * 1000, isUtc: true).toLocal()
              : null;

          results.add(TargetItem(
            id: item.id,
            name: item.name.toDartString(),
            messier: mStr.isNotEmpty ? mStr : null,
            caldwell: cStr.isNotEmpty ? cStr : null,
            arp: arpStr.isNotEmpty ? arpStr : null,
            herschel: herschelStr.isNotEmpty ? herschelStr : null,
            catalog: item.catalog.toDartString(),
            objectType: item.objectType.toDartString(),
            constellation: item.constellation.toDartString(),
            raHours: item.raHours,
            decDegrees: item.decDegrees,
            magnitude: mag,
            majorAxisArcmin: majAx,
            surfaceBrightness: sb,
            commonName: commonStr.isNotEmpty ? commonStr : null,
            peakAltitudeDeg: item.peakAltitudeDeg,
            visibleDurationHours: item.visibleDurationHours,
            transitTime: transit,
            visibleStartTime: vStart,
            visibleEndTime: vEnd,
            minMoonSepDeg: item.minMoonSepDeg,
            meetsCriteria: item.meetsCriteria == 1,
          ));
        }

        return results;
      } finally {
        _freeTargetList(listPtr);
      }
    } finally {
      if (catUtf8 != null) calloc.free(catUtf8);
      if (typeUtf8 != null) calloc.free(typeUtf8);
      if (searchUtf8 != null) calloc.free(searchUtf8);
      calloc.free(obsPtr);
      calloc.free(critPtr);
    }
  }

  List<AltitudePoint> generateAltitudeCurve({
    required int targetId,
    required double latitude,
    required double longitude,
    required double elevation,
    required DateTime start,
    required DateTime end,
    int stepMinutes = 5,
  }) {
    if (_engine == null) return [];

    final obsPtr = calloc<AstroObserver>();
    try {
      obsPtr.ref.latitudeDeg = latitude;
      obsPtr.ref.longitudeDeg = longitude;
      obsPtr.ref.elevationM = elevation;

      final startSec = start.toUtc().millisecondsSinceEpoch ~/ 1000;
      final endSec = end.toUtc().millisecondsSinceEpoch ~/ 1000;

      final curvePtr = _generateCurve(
        _engine!,
        targetId,
        obsPtr,
        startSec,
        endSec,
        stepMinutes,
      );
      if (curvePtr == nullptr) return [];

      try {
        final count = curvePtr.ref.count;
        final pointsPtr = curvePtr.ref.points;
        final points = <AltitudePoint>[];

        for (int i = 0; i < count; ++i) {
          final p = pointsPtr[i];
          points.add(AltitudePoint(
            time: DateTime.fromMillisecondsSinceEpoch(p.timestampUtc * 1000, isUtc: true).toLocal(),
            altitude: p.altitudeDeg,
            azimuth: p.azimuthDeg,
            moonSeparation: p.moonSeparationDeg,
            meetsCriteria: p.meetsCriteria == 1,
          ));
        }
        return points;
      } finally {
        _freeCurveData(curvePtr);
      }
    } finally {
      calloc.free(obsPtr);
    }
  }

  int createObservingList(String name, String description, String sessionDate) {
    if (_engine == null) return -1;
    final nameUtf8 = name.toNativeUtf8();
    final descUtf8 = description.toNativeUtf8();
    final dateUtf8 = sessionDate.toNativeUtf8();
    try {
      return _createList(_engine!, nameUtf8, descUtf8, dateUtf8);
    } finally {
      calloc.free(nameUtf8);
      calloc.free(descUtf8);
      calloc.free(dateUtf8);
    }
  }

  bool deleteObservingList(int listId) {
    if (_engine == null) return false;
    return _deleteList(_engine!, listId) == 1;
  }

  bool addTargetToList(int listId, int dsoId, String notes) {
    if (_engine == null) return false;
    final notesUtf8 = notes.toNativeUtf8();
    try {
      return _addToList(_engine!, listId, dsoId, notesUtf8) == 1;
    } finally {
      calloc.free(notesUtf8);
    }
  }

  bool removeTargetFromList(int listId, int dsoId) {
    if (_engine == null) return false;
    return _removeFromList(_engine!, listId, dsoId) == 1;
  }

  List<ObservingListModel> getObservingLists() {
    if (_engine == null) return [];
    final jsonPtr = _getListsJson(_engine!);
    try {
      final jsonStr = jsonPtr.toDartString();
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded.map((e) => ObservingListModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    } finally {
      _freeString(jsonPtr);
    }
  }

  bool clearAllObservingLists() {
    if (_engine == null) return false;
    return _clearAllLists(_engine!) == 1;
  }
}

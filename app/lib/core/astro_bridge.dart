import 'dart:convert';
import 'dart:ffi';
import 'dart:math' as math;
import 'package:ffi/ffi.dart';

import 'astro_ffi_types.dart';
import 'astro_engine.dart';
import 'ffi_mappers.dart';
import 'night_window_policy.dart';
import 'native_library_resolver.dart';
import 'app_logger.dart';
import '../models/target_item.dart';
import '../models/night_summary.dart';
import '../models/altitude_point.dart';
import '../models/filter_state.dart';
import '../models/observing_list.dart';
import '../models/yearly_visibility.dart';
import '../models/period_target_item.dart';
import '../models/target_description.dart';

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

typedef _AstroFilterTargetsPeriodC = Pointer<AstroPeriodTargetList> Function(
  Pointer<AstroEngineContext> engine,
  Pointer<AstroObserver> observer,
  Pointer<AstroFilterCriteria> criteria,
  Int64 periodStartUtc,
  Int64 periodEndUtc,
  Int32 stepMinutes,
);
typedef _AstroFilterTargetsPeriodDart = Pointer<AstroPeriodTargetList> Function(
  Pointer<AstroEngineContext> engine,
  Pointer<AstroObserver> observer,
  Pointer<AstroFilterCriteria> criteria,
  int periodStartUtc,
  int periodEndUtc,
  int stepMinutes,
);

typedef _AstroFreePeriodTargetListC = Void Function(Pointer<AstroPeriodTargetList> list);
typedef _AstroFreePeriodTargetListDart = void Function(Pointer<AstroPeriodTargetList> list);

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

typedef _AstroGetTargetYearlyVisibilityJsonC = Pointer<Utf8> Function(
  Pointer<AstroEngineContext> engine,
  Int64 targetId,
  Pointer<AstroObserver> observer,
  Pointer<AstroFilterCriteria> criteria,
  Int32 year,
);
typedef _AstroGetTargetYearlyVisibilityJsonDart = Pointer<Utf8> Function(
  Pointer<AstroEngineContext> engine,
  int targetId,
  Pointer<AstroObserver> observer,
  Pointer<AstroFilterCriteria> criteria,
  int year,
);

typedef _AstroFreeStringC = Void Function(Pointer<Utf8> str);
typedef _AstroFreeStringDart = void Function(Pointer<Utf8> str);

typedef _AstroGetTargetDescriptionJsonC = Pointer<Utf8> Function(
  Pointer<AstroEngineContext> engine,
  Pointer<Utf8> targetName,
);
typedef _AstroGetTargetDescriptionJsonDart = Pointer<Utf8> Function(
  Pointer<AstroEngineContext> engine,
  Pointer<Utf8> targetName,
);

typedef _AstroSaveTargetDescriptionC = Int32 Function(
  Pointer<AstroEngineContext> engine,
  Pointer<Utf8> title,
  Pointer<Utf8> description,
  Pointer<Utf8> extract,
  Pointer<Utf8> thumbnailUrl,
  Pointer<Utf8> pageUrl,
  Pointer<Utf8> source,
  Pointer<Utf8> aliasesCsv,
);
typedef _AstroSaveTargetDescriptionDart = int Function(
  Pointer<AstroEngineContext> engine,
  Pointer<Utf8> title,
  Pointer<Utf8> description,
  Pointer<Utf8> extract,
  Pointer<Utf8> thumbnailUrl,
  Pointer<Utf8> pageUrl,
  Pointer<Utf8> source,
  Pointer<Utf8> aliasesCsv,
);

class AstroBridge implements AstroEngine {
  static AstroBridge? _instance;
  late final DynamicLibrary _lib;
  Pointer<AstroEngineContext>? _engine;

  late final _AstroEngineCreateDart _engineCreate;
  late final _AstroEngineDestroyDart _engineDestroy;
  late final _AstroEngineGetLastErrorDart _engineGetLastError;
  late final _AstroGetNightSummaryDart _getNightSummary;
  late final _AstroFilterTargetsDart _filterTargets;
  late final _AstroFreeTargetListDart _freeTargetList;
  late final _AstroFilterTargetsPeriodDart _filterTargetsPeriod;
  late final _AstroFreePeriodTargetListDart _freePeriodTargetList;
  late final _AstroGenerateCurveDart _generateCurve;
  late final _AstroFreeCurveDataDart _freeCurveData;
  late final _AstroCreateObservingListDart _createList;
  late final _AstroDeleteObservingListDart _deleteList;
  late final _AstroAddToListDart _addToList;
  late final _AstroRemoveFromListDart _removeFromList;
  late final _AstroGetListsJsonDart _getListsJson;
  late final _AstroClearAllObservingListsDart _clearAllLists;
  late final _AstroGetTargetYearlyVisibilityJsonDart _getTargetYearlyVisibilityJson;
  late final _AstroGetTargetDescriptionJsonDart _getTargetDescriptionJson;
  late final _AstroSaveTargetDescriptionDart _saveTargetDescription;
  late final _AstroFreeStringDart _freeString;

  AstroBridge._({DynamicLibrary? library}) {
    _lib = library ?? NativeLibraryResolver.resolve();
    _bindFunctions();
  }

  static AstroBridge get instance {
    _instance ??= AstroBridge._();
    return _instance!;
  }

  /// Registers AstroBridge as the default engine provider for AstroEngine.instance.
  static void registerAsDefault() {
    AstroEngine.defaultFactory = () => AstroBridge.instance;
  }

  /// Creates a dedicated AstroBridge instance (e.g. for worker isolates).
  factory AstroBridge.create({DynamicLibrary? library}) {
    return AstroBridge._(library: library);
  }

  /// Creates an AstroBridge instance backed by a custom DynamicLibrary.
  factory AstroBridge.fromLibrary(DynamicLibrary library) {
    return AstroBridge._(library: library);
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
    _filterTargetsPeriod = _lib
        .lookup<NativeFunction<_AstroFilterTargetsPeriodC>>('astro_filter_targets_period')
        .asFunction<_AstroFilterTargetsPeriodDart>();
    _freePeriodTargetList = _lib
        .lookup<NativeFunction<_AstroFreePeriodTargetListC>>('astro_free_period_target_list')
        .asFunction<_AstroFreePeriodTargetListDart>();
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
    _getTargetYearlyVisibilityJson = _lib
        .lookup<NativeFunction<_AstroGetTargetYearlyVisibilityJsonC>>('astro_get_target_yearly_visibility_json')
        .asFunction<_AstroGetTargetYearlyVisibilityJsonDart>();
    _getTargetDescriptionJson = _lib
        .lookup<NativeFunction<_AstroGetTargetDescriptionJsonC>>('astro_get_target_description_json')
        .asFunction<_AstroGetTargetDescriptionJsonDart>();
    _saveTargetDescription = _lib
        .lookup<NativeFunction<_AstroSaveTargetDescriptionC>>('astro_save_target_description')
        .asFunction<_AstroSaveTargetDescriptionDart>();
    _freeString = _lib
        .lookup<NativeFunction<_AstroFreeStringC>>('astro_free_string')
        .asFunction<_AstroFreeStringDart>();
  }

  String? _dbPath;
  String? get databasePath => _dbPath;

  @override
  void initEngine(String dbPath) {
    if (_engine != null) {
      _engineDestroy(_engine!);
      _engine = null;
    }
    _dbPath = dbPath;
    final dbPathUtf8 = dbPath.toNativeUtf8();
    try {
      final ptr = _engineCreate(dbPathUtf8);
      if (ptr == nullptr) {
        throw StateError("Failed to initialize AstroEngine at path: $dbPath. Database may be missing or corrupt.");
      }
      _engine = ptr;
    } finally {
      calloc.free(dbPathUtf8);
    }
  }

  @override
  void dispose() {
    if (_engine != null) {
      _engineDestroy(_engine!);
      _engine = null;
    }
  }

  @override
  String getLastError() {
    if (_engine == null) return "Engine not initialized";
    final ptr = _engineGetLastError(_engine!);
    return ptr.toDartString();
  }

  @override
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

      final dateMidnightUtc = DateTime.utc(date.year, date.month, date.day);
      final dateSecondsUtc = dateMidnightUtc.millisecondsSinceEpoch ~/ 1000;
      final ok = _getNightSummary(_engine!, obsPtr, dateSecondsUtc, summaryPtr);
      if (ok != 1) {
        throw StateError("Failed to get night summary: ${getLastError()}");
      }

      final s = summaryPtr.ref;
      return FfiMappers.mapNightSummary(s);
    } finally {
      calloc.free(obsPtr);
      calloc.free(summaryPtr);
    }
  }

  @override
  List<TargetItem> filterTargets({
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  }) {
    if (_engine == null) return [];

    final obsPtr = calloc<AstroObserver>();
    final critPtr = calloc<AstroFilterCriteria>();
    final allocatedPointers = <Pointer<NativeType>>[];

    try {
      FfiMappers.populateObserver(
        obsPtr,
        latitudeDeg: filters.observerLat,
        longitudeDeg: filters.observerLon,
        elevationM: filters.observerElevation,
      );

      final window = NightWindowPolicy.calculateWindow(filters: filters, night: night);
      final candidatePoolLimit = math.max(filters.maxTargets * 10, 500);

      FfiMappers.populateCriteria(
        critPtr,
        filters: filters,
        windowStartUtc: window.startUtcSeconds,
        windowEndUtc: window.endUtcSeconds,
        limit: candidatePoolLimit,
        allocatedPointers: allocatedPointers,
      );

      final listPtr = _filterTargets(_engine!, obsPtr, critPtr, stepMinutes);
      if (listPtr == nullptr) return [];

      try {
        final count = listPtr.ref.count;
        final itemsPtr = listPtr.ref.items;
        final results = <TargetItem>[];

        for (int i = 0; i < count; ++i) {
          results.add(FfiMappers.mapTargetItem(itemsPtr[i]));
        }

        return results;
      } finally {
        _freeTargetList(listPtr);
      }
    } finally {
      for (final p in allocatedPointers) {
        calloc.free(p);
      }
      calloc.free(obsPtr);
      calloc.free(critPtr);
    }
  }

  @override
  List<TargetItem> getPlanets({
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  }) {
    final planetFilters = filters.copyWith(
      selectedCatalogs: {'Solar System'},
      selectedObjectTypes: {'Planet', 'Star'},
      searchQuery: '',
      minMagnitude: -30.0,
      maxMagnitude: 20.0,
      minSizeArcmin: 0.0,
      maxSizeArcmin: 100000.0,
      maxTargets: 50,
    );
    return filterTargets(
      filters: planetFilters,
      night: night,
      stepMinutes: stepMinutes,
    );
  }

  @override
  List<TargetItem> getBrightStars({
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  }) {
    final starFilters = filters.copyWith(
      selectedCatalogs: {'Stars'},
      selectedObjectTypes: {'Star', 'Double Star'},
      searchQuery: '',
      minMagnitude: -5.0,
      maxMagnitude: 10.0,
      minSizeArcmin: 0.0,
      maxSizeArcmin: 100000.0,
      maxTargets: 150,
    );
    return filterTargets(
      filters: starFilters,
      night: night,
      stepMinutes: stepMinutes,
    );
  }

  @override
  List<PeriodTargetItem> filterTargetsPeriod({
    required FilterState filters,
    required DateTime periodStart,
    required DateTime periodEnd,
    int stepMinutes = 10,
  }) {
    if (_engine == null) return [];

    final obsPtr = calloc<AstroObserver>();
    final critPtr = calloc<AstroFilterCriteria>();
    final allocatedPointers = <Pointer<NativeType>>[];

    try {
      FfiMappers.populateObserver(
        obsPtr,
        latitudeDeg: filters.observerLat,
        longitudeDeg: filters.observerLon,
        elevationM: filters.observerElevation,
      );

      final candidatePoolLimit = math.max(filters.maxTargets * 10, 500);
      final startUtc = DateTime.utc(periodStart.year, periodStart.month, periodStart.day, 12, 0, 0)
              .millisecondsSinceEpoch ~/ 1000;
      final endUtc = DateTime.utc(periodEnd.year, periodEnd.month, periodEnd.day, 12, 0, 0)
              .millisecondsSinceEpoch ~/ 1000;

      FfiMappers.populateCriteria(
        critPtr,
        filters: filters,
        windowStartUtc: startUtc,
        windowEndUtc: endUtc,
        limit: candidatePoolLimit,
        allocatedPointers: allocatedPointers,
        utcOffsetMinutes: periodStart.timeZoneOffset.inMinutes,
      );

      final listPtr = _filterTargetsPeriod(
        _engine!,
        obsPtr,
        critPtr,
        startUtc,
        endUtc,
        stepMinutes,
      );

      if (listPtr == nullptr) return [];

      try {
        final count = listPtr.ref.count;
        final itemsPtr = listPtr.ref.items;
        final results = <PeriodTargetItem>[];

        for (int i = 0; i < count; i++) {
          results.add(FfiMappers.mapPeriodTargetItem(itemsPtr[i]));
        }

        return results;
      } finally {
        _freePeriodTargetList(listPtr);
      }
    } finally {
      for (final p in allocatedPointers) {
        calloc.free(p);
      }
      calloc.free(obsPtr);
      calloc.free(critPtr);
    }
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
          points.add(FfiMappers.mapAltitudePoint(pointsPtr[i]));
        }
        return points;
      } finally {
        _freeCurveData(curvePtr);
      }
    } finally {
      calloc.free(obsPtr);
    }
  }

  @override
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

  @override
  bool deleteObservingList(int listId) {
    if (_engine == null) return false;
    return _deleteList(_engine!, listId) == 1;
  }

  @override
  bool addTargetToList(int listId, int dsoId, String notes) {
    if (_engine == null) return false;
    final notesUtf8 = notes.toNativeUtf8();
    try {
      return _addToList(_engine!, listId, dsoId, notesUtf8) == 1;
    } finally {
      calloc.free(notesUtf8);
    }
  }

  @override
  bool removeTargetFromList(int listId, int dsoId) {
    if (_engine == null) return false;
    return _removeFromList(_engine!, listId, dsoId) == 1;
  }

  @override
  List<ObservingListModel> getObservingLists() {
    if (_engine == null) return [];
    final jsonPtr = _getListsJson(_engine!);
    try {
      final jsonStr = jsonPtr.toDartString();
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded.map((e) => ObservingListModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e, st) {
      AppLogger.error('Failed to parse observing lists JSON from engine', tag: 'AstroBridge', error: e, stackTrace: st);
      return [];
    } finally {
      _freeString(jsonPtr);
    }
  }

  @override
  bool clearAllObservingLists() {
    if (_engine == null) return false;
    return _clearAllLists(_engine!) == 1;
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
    if (_engine == null) return null;
    final simYear = year ?? DateTime.now().year;

    final obsPtr = calloc<AstroObserver>();
    obsPtr.ref.latitudeDeg = latitude;
    obsPtr.ref.longitudeDeg = longitude;
    obsPtr.ref.elevationM = elevation;

    final critPtr = calloc<AstroFilterCriteria>();
    final allocatedPointers = <Pointer<NativeType>>[];

    critPtr.ref.minAltitudeDeg = filters?.minAltitude ?? minAltitude;
    critPtr.ref.minDurationHours = filters?.minDurationHours ?? minDurationHours;
    critPtr.ref.minAzimuthDeg = filters?.minAzimuth ?? 0.0;
    critPtr.ref.maxAzimuthDeg = filters?.maxAzimuth ?? 360.0;
    critPtr.ref.quadrant = filters?.quadrant ?? 0;
    critPtr.ref.minMoonSeparationDeg = 0.0;
    critPtr.ref.useCustomTimeWindow = (filters?.useCustomTimeWindow ?? false) ? 1 : 0;
    critPtr.ref.customStartHour = filters?.customStartHour ?? 21;
    critPtr.ref.customStartMinute = filters?.customStartMinute ?? 0;
    critPtr.ref.customEndHour = filters?.customEndHour ?? 23;
    critPtr.ref.customEndMinute = filters?.customEndMinute ?? 0;
    critPtr.ref.utcOffsetMinutes = filters?.date.timeZoneOffset.inMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
    FfiMappers.populateCustomHorizon(critPtr, filters, allocatedPointers);

    try {
      final jsonPtr = _getTargetYearlyVisibilityJson(
        _engine!,
        targetId,
        obsPtr,
        critPtr,
        simYear,
      );

      if (jsonPtr == nullptr) return null;
      try {
        final jsonStr = jsonPtr.toDartString();
        if (jsonStr.isEmpty || jsonStr == '{}') return null;
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return YearlyVisibilityModel.fromJson(decoded);
      } finally {
        _freeString(jsonPtr);
      }
    } catch (e, st) {
      AppLogger.error('Failed to calculate target yearly visibility', tag: 'AstroBridge', error: e, stackTrace: st);
      return null;
    } finally {
      for (final p in allocatedPointers) {
        calloc.free(p);
      }
      calloc.free(obsPtr);
      calloc.free(critPtr);
    }
  }

  @override
  TargetDescription? getTargetDescription(String targetName) {
    if (_engine == null || targetName.trim().isEmpty) return null;
    final namePtr = targetName.toNativeUtf8();
    try {
      final jsonPtr = _getTargetDescriptionJson(_engine!, namePtr);
      if (jsonPtr == nullptr) return null;
      try {
        final jsonStr = jsonPtr.toDartString();
        if (jsonStr.isEmpty || jsonStr == '{}') return null;
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return TargetDescription.fromJson(decoded);
      } finally {
        _freeString(jsonPtr);
      }
    } catch (e, st) {
      AppLogger.warning('Failed to query target description for $targetName: $e', tag: 'AstroBridge', error: e, stackTrace: st);
      return null;
    } finally {
      calloc.free(namePtr);
    }
  }

  @override
  bool saveTargetDescription(TargetDescription desc, {List<String>? aliases}) {
    if (_engine == null || desc.title.isEmpty || desc.extract.isEmpty) return false;
    final titlePtr = desc.title.toNativeUtf8();
    final descPtr = desc.description.toNativeUtf8();
    final extractPtr = desc.extract.toNativeUtf8();
    final thumbPtr = (desc.thumbnailUrl ?? '').toNativeUtf8();
    final pagePtr = (desc.pageUrl ?? '').toNativeUtf8();
    final sourcePtr = desc.source.toNativeUtf8();
    final aliasesCsv = (aliases ?? []).join(',');
    final aliasesPtr = aliasesCsv.toNativeUtf8();

    try {
      final res = _saveTargetDescription(
        _engine!,
        titlePtr,
        descPtr,
        extractPtr,
        thumbPtr,
        pagePtr,
        sourcePtr,
        aliasesPtr,
      );
      return res == 1;
    } catch (e, st) {
      AppLogger.warning('Failed to save target description for ${desc.title}: $e', tag: 'AstroBridge', error: e, stackTrace: st);
      return false;
    } finally {
      calloc.free(titlePtr);
      calloc.free(descPtr);
      calloc.free(extractPtr);
      calloc.free(thumbPtr);
      calloc.free(pagePtr);
      calloc.free(sourcePtr);
      calloc.free(aliasesPtr);
    }
  }
}

import '../models/altitude_point.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/period_target_item.dart';
import '../models/target_description.dart';
import '../models/target_item.dart';
import '../models/yearly_visibility.dart';
import 'astro_bridge.dart';

/// Abstract contract for astronomy computation and catalog operations.
/// Decouples views and controllers from direct native C++ / FFI dependencies.
abstract class AstroEngine {
  static AstroEngine? _instance;

  /// Retrieves the globally active astronomy engine instance.
  /// Defaults to the native FFI [AstroBridge] if not overridden.
  static AstroEngine get instance {
    _instance ??= AstroBridge.instance;
    return _instance!;
  }

  /// Injects a custom or mock engine instance (e.g., during tests).
  static set instance(AstroEngine engine) {
    _instance = engine;
  }

  /// Resets the engine instance back to the default native FFI bridge.
  static void reset() {
    _instance = null;
  }

  /// Initializes the underlying engine with the SQLite catalogs database.
  void initEngine(String dbPath);

  /// Releases native resources and database handles.
  void dispose();

  /// Returns the most recent error message from the engine.
  String getLastError();

  /// Calculates astronomical night transitions, dusk/dawn, and moon ephemeris.
  NightSummary getNightSummary({
    required double latitude,
    required double longitude,
    required double elevation,
    required DateTime date,
  });

  /// Queries and filters celestial targets based on observing conditions and criteria.
  List<TargetItem> filterTargets({
    required FilterState filters,
    required NightSummary night,
    int stepMinutes = 10,
  });

  /// Filters targets across an extended multi-night period.
  List<PeriodTargetItem> filterTargetsPeriod({
    required FilterState filters,
    required DateTime periodStart,
    required DateTime periodEnd,
    int stepMinutes = 10,
  });

  /// Generates chronological altitude data points for graphing target elevation.
  List<AltitudePoint> generateAltitudeCurve({
    required int targetId,
    required double latitude,
    required double longitude,
    required double elevation,
    required DateTime start,
    required DateTime end,
    int stepMinutes = 5,
  });

  /// Creates a new user observing list.
  int createObservingList(String name, String description, String sessionDate);

  /// Deletes an observing list by its identifier.
  bool deleteObservingList(int listId);

  /// Adds a target to an observing list.
  bool addTargetToList(int listId, int dsoId, String notes);

  /// Removes a target from an observing list.
  bool removeTargetFromList(int listId, int dsoId);

  /// Returns all saved observing lists with their associated items.
  List<ObservingListModel> getObservingLists();

  /// Clears all user observing lists.
  bool clearAllObservingLists();

  /// Computes monthly visibility statistics for a target across an entire calendar year.
  YearlyVisibilityModel? getTargetYearlyVisibility({
    required int targetId,
    required double latitude,
    required double longitude,
    required double elevation,
    FilterState? filters,
    double minAltitude = 30.0,
    double minDurationHours = 2.0,
    int year = 2026,
  });

  /// Retrieves the pre-baked or cached descriptive prose for a celestial target.
  TargetDescription? getTargetDescription(String targetName);

  /// Saves a target description and its associated lookup aliases into the local cache database.
  bool saveTargetDescription(TargetDescription desc, {List<String>? aliases});
}

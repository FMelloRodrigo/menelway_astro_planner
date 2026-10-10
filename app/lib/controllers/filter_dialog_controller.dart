import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../models/filter_state.dart';

/// Controller handling state, validation, and mutations for the FilterDialog.
/// Decouples filter business logic from the dialog's presentation widgets.
class FilterDialogController extends ChangeNotifier {
  late FilterState _state;
  final FilterState _initialFilters;

  FilterDialogController({required FilterState initialFilters})
      : _initialFilters = initialFilters {
    var minAlt = ((initialFilters.minAltitude / 5.0).round() * 5.0).toDouble().clamp(10.0, 70.0);
    var maxAlt = ((initialFilters.maxAltitude / 5.0).round() * 5.0).toDouble().clamp(50.0, 90.0);
    if (minAlt >= maxAlt) {
      minAlt = math.max(10.0, maxAlt - 5.0);
    }
    _state = initialFilters.copyWith(
      minAltitude: minAlt,
      maxAltitude: maxAlt,
    );
  }

  FilterState get state => _state;
  FilterState get initialFilters => _initialFilters;

  static const List<String> defaultCatalogs = [
    'Messier',
    'Caldwell',
    'Arp',
    'Herschel',
    'NGC',
    'IC',
    'Sharpless',
    'Barnard',
  ];

  static const List<String> defaultObjectTypes = [
    'Galaxy',
    'Planetary Nebula',
    'Bright Nebula',
    'Dark Nebula',
    'Open Cluster',
    'Globular Cluster',
    'Supernova Remnant',
  ];

  /// Computes cardinal direction abbreviation for an azimuth in degrees.
  static String cardinalName(double az, {bool isPt = false}) {
    final a = (az % 360 + 360) % 360;
    if (a >= 337.5 || a < 22.5) return "N";
    if (a < 67.5) return "NE";
    if (a < 112.5) return isPt ? "L" : "E";
    if (a < 157.5) return "SE";
    if (a < 202.5) return "S";
    if (a < 247.5) return isPt ? "SO" : "SW";
    if (a < 292.5) return isPt ? "O" : "W";
    return isPt ? "NO" : "NW";
  }

  int get presetIndex {
    final min = _state.minAzimuth.round();
    final max = _state.maxAzimuth.round();
    if (min == 0 && max == 360) return 0;
    if (min == 315 && max == 45) return 1;
    if (min == 45 && max == 135) return 2;
    if (min == 135 && max == 225) return 3;
    if (min == 225 && max == 315) return 4;
    if (min == 0 && max == 90) return 5;
    if (min == 90 && max == 180) return 6;
    if (min == 180 && max == 270) return 7;
    if (min == 270 && max == 360) return 8;
    return 9; // Custom Degree Range
  }

  void applyPreset(int index) {
    double minAz = _state.minAzimuth;
    double maxAz = _state.maxAzimuth;
    switch (index) {
      case 0: minAz = 0.0; maxAz = 360.0; break;
      case 1: minAz = 315.0; maxAz = 45.0; break;
      case 2: minAz = 45.0; maxAz = 135.0; break;
      case 3: minAz = 135.0; maxAz = 225.0; break;
      case 4: minAz = 225.0; maxAz = 315.0; break;
      case 5: minAz = 0.0; maxAz = 90.0; break;
      case 6: minAz = 90.0; maxAz = 180.0; break;
      case 7: minAz = 180.0; maxAz = 270.0; break;
      case 8: minAz = 270.0; maxAz = 360.0; break;
      case 9: break;
    }
    _state = _state.copyWith(minAzimuth: minAz, maxAzimuth: maxAz, quadrant: 0);
    notifyListeners();
  }

  void setCustomAzimuth(double min, double max) {
    _state = _state.copyWith(minAzimuth: min, maxAzimuth: max, quadrant: 0);
    notifyListeners();
  }

  void setMinAzimuth(double value) {
    _state = _state.copyWith(minAzimuth: value, quadrant: 0);
    notifyListeners();
  }

  void setMaxAzimuth(double value) {
    _state = _state.copyWith(maxAzimuth: value, quadrant: 0);
    notifyListeners();
  }

  void setMinAltitude(double value) {
    final snapped = ((value / 5.0).round() * 5.0).toDouble();
    var maxAlt = _state.maxAltitude;
    if (snapped >= maxAlt) {
      maxAlt = math.min(90.0, snapped + 5.0);
    }
    _state = _state.copyWith(minAltitude: snapped, maxAltitude: maxAlt);
    notifyListeners();
  }

  void setMaxAltitude(double value) {
    final snapped = ((value / 5.0).round() * 5.0).toDouble();
    var minAlt = _state.minAltitude;
    if (snapped <= minAlt) {
      minAlt = math.max(10.0, snapped - 5.0);
    }
    _state = _state.copyWith(minAltitude: minAlt, maxAltitude: snapped);
    notifyListeners();
  }

  void setMinDurationHours(double value) {
    _state = _state.copyWith(minDurationHours: value);
    notifyListeners();
  }

  void setMinMoonSeparation(double value) {
    _state = _state.copyWith(minMoonSeparation: value);
    notifyListeners();
  }

  void setMaxMagnitude(double value) {
    _state = _state.copyWith(maxMagnitude: value);
    notifyListeners();
  }

  void setMinSizeArcmin(double value) {
    _state = _state.copyWith(minSizeArcmin: value);
    notifyListeners();
  }

  void setMagnitudeRange(double min, double max) {
    _state = _state.copyWith(minMagnitude: min, maxMagnitude: max);
    notifyListeners();
  }

  void setSizeRange(double min, double max) {
    _state = _state.copyWith(minSizeArcmin: min, maxSizeArcmin: max);
    notifyListeners();
  }

  void setUseCustomTimeWindow(bool useCustom) {
    var minDur = _state.minDurationHours;
    if (useCustom) {
      final maxDur = _state.windowDurationHours;
      if (minDur > maxDur) {
        minDur = math.max(0.5, maxDur);
      }
    }
    _state = _state.copyWith(useCustomTimeWindow: useCustom, minDurationHours: minDur);
    notifyListeners();
  }

  void setCustomStartTime(int hour, int minute) {
    final tempState = _state.copyWith(customStartHour: hour, customStartMinute: minute);
    final maxDur = tempState.windowDurationHours;
    var minDur = tempState.minDurationHours;
    if (minDur > maxDur) {
      minDur = math.max(0.5, maxDur);
    }
    _state = tempState.copyWith(minDurationHours: minDur);
    notifyListeners();
  }

  void setCustomEndTime(int hour, int minute) {
    final tempState = _state.copyWith(customEndHour: hour, customEndMinute: minute);
    final maxDur = tempState.windowDurationHours;
    var minDur = tempState.minDurationHours;
    if (minDur > maxDur) {
      minDur = math.max(0.5, maxDur);
    }
    _state = tempState.copyWith(minDurationHours: minDur);
    notifyListeners();
  }

  void setCustomTime({required bool isStart, required int hour, required int minute}) {
    final tempState = isStart
        ? _state.copyWith(customStartHour: hour, customStartMinute: minute)
        : _state.copyWith(customEndHour: hour, customEndMinute: minute);
    final maxDur = tempState.windowDurationHours;
    var minDur = tempState.minDurationHours;
    if (minDur > maxDur) {
      minDur = math.max(0.5, maxDur);
    }
    _state = tempState.copyWith(minDurationHours: minDur);
    notifyListeners();
  }

  void setCustomWindow(int startH, int startM, int endH, int endM) {
    final tempState = _state.copyWith(
      useCustomTimeWindow: true,
      customStartHour: startH,
      customStartMinute: startM,
      customEndHour: endH,
      customEndMinute: endM,
    );
    final maxDur = tempState.windowDurationHours;
    var minDur = tempState.minDurationHours;
    if (minDur > maxDur) {
      minDur = math.max(0.5, maxDur);
    }
    _state = tempState.copyWith(minDurationHours: minDur);
    notifyListeners();
  }

  void setCatalogSelected(String catalog, bool selected) {
    final set = Set<String>.from(_state.selectedCatalogs);
    if (selected) {
      set.add(catalog);
    } else if (set.length > 1) {
      set.remove(catalog);
    }
    _state = _state.copyWith(selectedCatalogs: set);
    notifyListeners();
  }

  void toggleCatalog(String catalog) {
    final set = Set<String>.from(_state.selectedCatalogs);
    if (set.contains(catalog)) {
      if (set.length > 1) {
        set.remove(catalog);
      }
    } else {
      set.add(catalog);
    }
    _state = _state.copyWith(selectedCatalogs: set);
    notifyListeners();
  }

  void selectAllCatalogs([List<String>? all]) {
    _state = _state.copyWith(selectedCatalogs: Set<String>.from(all ?? defaultCatalogs));
    notifyListeners();
  }

  void clearCatalogs() {
    _state = _state.copyWith(selectedCatalogs: <String>{});
    notifyListeners();
  }

  void setObjectTypeSelected(String type, bool selected) {
    final set = Set<String>.from(_state.selectedObjectTypes);
    if (selected) {
      set.add(type);
    } else if (set.length > 1) {
      set.remove(type);
    }
    _state = _state.copyWith(selectedObjectTypes: set);
    notifyListeners();
  }

  void toggleObjectType(String type) {
    final set = Set<String>.from(_state.selectedObjectTypes);
    if (set.contains(type)) {
      if (set.length > 1) {
        set.remove(type);
      }
    } else {
      set.add(type);
    }
    _state = _state.copyWith(selectedObjectTypes: set);
    notifyListeners();
  }

  void selectAllObjectTypes([List<String>? all]) {
    _state = _state.copyWith(selectedObjectTypes: Set<String>.from(all ?? defaultObjectTypes));
    notifyListeners();
  }

  void clearObjectTypes() {
    _state = _state.copyWith(selectedObjectTypes: <String>{});
    notifyListeners();
  }

  void setUseCustomHorizon(bool val) {
    _state = _state.copyWith(useCustomHorizon: val);
    notifyListeners();
  }

  void updateFilterState(FilterState updated) {
    _state = updated;
    notifyListeners();
  }

  void resetToDefaults() {
    _state = FilterState(
      observerLat: _initialFilters.observerLat,
      observerLon: _initialFilters.observerLon,
      observerElevation: _initialFilters.observerElevation,
      observerLocationName: _initialFilters.observerLocationName,
      date: _initialFilters.date,
    );
    notifyListeners();
  }
}

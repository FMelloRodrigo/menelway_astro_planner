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
    _state = initialFilters.copyWith();
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
    switch (index) {
      case 0:
        _state.minAzimuth = 0.0;
        _state.maxAzimuth = 360.0;
        _state.quadrant = 0;
        break;
      case 1:
        _state.minAzimuth = 315.0;
        _state.maxAzimuth = 45.0;
        _state.quadrant = 0;
        break;
      case 2:
        _state.minAzimuth = 45.0;
        _state.maxAzimuth = 135.0;
        _state.quadrant = 0;
        break;
      case 3:
        _state.minAzimuth = 135.0;
        _state.maxAzimuth = 225.0;
        _state.quadrant = 0;
        break;
      case 4:
        _state.minAzimuth = 225.0;
        _state.maxAzimuth = 315.0;
        _state.quadrant = 0;
        break;
      case 5:
        _state.minAzimuth = 0.0;
        _state.maxAzimuth = 90.0;
        _state.quadrant = 0;
        break;
      case 6:
        _state.minAzimuth = 90.0;
        _state.maxAzimuth = 180.0;
        _state.quadrant = 0;
        break;
      case 7:
        _state.minAzimuth = 180.0;
        _state.maxAzimuth = 270.0;
        _state.quadrant = 0;
        break;
      case 8:
        _state.minAzimuth = 270.0;
        _state.maxAzimuth = 360.0;
        _state.quadrant = 0;
        break;
      case 9:
        _state.quadrant = 0;
        break;
    }
    notifyListeners();
  }

  void setCustomAzimuth(double min, double max) {
    _state.minAzimuth = min;
    _state.maxAzimuth = max;
    _state.quadrant = 0;
    notifyListeners();
  }

  void setMinAzimuth(double value) {
    _state.minAzimuth = value;
    _state.quadrant = 0;
    notifyListeners();
  }

  void setMaxAzimuth(double value) {
    _state.maxAzimuth = value;
    _state.quadrant = 0;
    notifyListeners();
  }

  void setMinAltitude(double value) {
    _state.minAltitude = value;
    notifyListeners();
  }

  void setMaxAltitude(double value) {
    _state.maxAltitude = value;
    notifyListeners();
  }

  void setMinDurationHours(double value) {
    _state.minDurationHours = value;
    notifyListeners();
  }

  void setMinMoonSeparation(double value) {
    _state.minMoonSeparation = value;
    notifyListeners();
  }

  void setMaxMagnitude(double value) {
    _state.maxMagnitude = value;
    notifyListeners();
  }

  void setMinSizeArcmin(double value) {
    _state.minSizeArcmin = value;
    notifyListeners();
  }

  void setMagnitudeRange(double min, double max) {
    _state.minMagnitude = min;
    _state.maxMagnitude = max;
    notifyListeners();
  }

  void setSizeRange(double min, double max) {
    _state.minSizeArcmin = min;
    _state.maxSizeArcmin = max;
    notifyListeners();
  }

  void setUseCustomTimeWindow(bool useCustom) {
    _state.useCustomTimeWindow = useCustom;
    if (useCustom) {
      final maxDur = _state.windowDurationHours;
      if (_state.minDurationHours > maxDur) {
        _state.minDurationHours = math.max(0.5, maxDur);
      }
    }
    notifyListeners();
  }

  void setCustomStartTime(int hour, int minute) {
    _state.customStartHour = hour;
    _state.customStartMinute = minute;
    final maxDur = _state.windowDurationHours;
    if (_state.minDurationHours > maxDur) {
      _state.minDurationHours = math.max(0.5, maxDur);
    }
    notifyListeners();
  }

  void setCustomEndTime(int hour, int minute) {
    _state.customEndHour = hour;
    _state.customEndMinute = minute;
    final maxDur = _state.windowDurationHours;
    if (_state.minDurationHours > maxDur) {
      _state.minDurationHours = math.max(0.5, maxDur);
    }
    notifyListeners();
  }

  void setCustomTime({required bool isStart, required int hour, required int minute}) {
    if (isStart) {
      _state.customStartHour = hour;
      _state.customStartMinute = minute;
    } else {
      _state.customEndHour = hour;
      _state.customEndMinute = minute;
    }
    final maxDur = _state.windowDurationHours;
    if (_state.minDurationHours > maxDur) {
      _state.minDurationHours = math.max(0.5, maxDur);
    }
    notifyListeners();
  }

  void setCustomWindow(int startH, int startM, int endH, int endM) {
    _state.useCustomTimeWindow = true;
    _state.customStartHour = startH;
    _state.customStartMinute = startM;
    _state.customEndHour = endH;
    _state.customEndMinute = endM;
    final maxDur = _state.windowDurationHours;
    if (_state.minDurationHours > maxDur) {
      _state.minDurationHours = math.max(0.5, maxDur);
    }
    notifyListeners();
  }

  void setCatalogSelected(String catalog, bool selected) {
    if (selected) {
      _state.selectedCatalogs.add(catalog);
    } else if (_state.selectedCatalogs.length > 1) {
      _state.selectedCatalogs.remove(catalog);
    }
    notifyListeners();
  }

  void toggleCatalog(String catalog) {
    if (_state.selectedCatalogs.contains(catalog)) {
      if (_state.selectedCatalogs.length > 1) {
        _state.selectedCatalogs.remove(catalog);
      }
    } else {
      _state.selectedCatalogs.add(catalog);
    }
    notifyListeners();
  }

  void selectAllCatalogs([List<String>? all]) {
    _state.selectedCatalogs = Set<String>.from(all ?? defaultCatalogs);
    notifyListeners();
  }

  void clearCatalogs() {
    _state.selectedCatalogs.clear();
    notifyListeners();
  }

  void setObjectTypeSelected(String type, bool selected) {
    if (selected) {
      _state.selectedObjectTypes.add(type);
    } else if (_state.selectedObjectTypes.length > 1) {
      _state.selectedObjectTypes.remove(type);
    }
    notifyListeners();
  }

  void toggleObjectType(String type) {
    if (_state.selectedObjectTypes.contains(type)) {
      if (_state.selectedObjectTypes.length > 1) {
        _state.selectedObjectTypes.remove(type);
      }
    } else {
      _state.selectedObjectTypes.add(type);
    }
    notifyListeners();
  }

  void selectAllObjectTypes([List<String>? all]) {
    _state.selectedObjectTypes = Set<String>.from(all ?? defaultObjectTypes);
    notifyListeners();
  }

  void clearObjectTypes() {
    _state.selectedObjectTypes.clear();
    notifyListeners();
  }

  void setUseCustomHorizon(bool val) {
    _state.useCustomHorizon = val;
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

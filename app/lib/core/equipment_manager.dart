import 'package:flutter/foundation.dart';
import '../models/equipment_profile.dart';
import 'equipment_database.dart';

class EquipmentManager extends ChangeNotifier {
  EquipmentManager._();
  static final EquipmentManager instance = EquipmentManager._();

  List<EquipmentProfile> _profiles = [];
  String _activeProfileId = '';
  double _cameraAngleDeg = 0.0;
  bool _showRuleOfThirds = false;
  bool _isFramingEnabled = false;

  List<EquipmentProfile> get profiles => List.unmodifiable(_profiles);
  String get activeProfileId => _activeProfileId;
  double get cameraAngleDeg => _cameraAngleDeg;
  bool get showRuleOfThirds => _showRuleOfThirds;
  bool get isFramingEnabled => _isFramingEnabled;

  EquipmentProfile get activeProfile {
    if (_profiles.isEmpty) {
      _profiles = List.from(EquipmentDatabase.defaultProfiles);
      _activeProfileId = _profiles.first.id;
    }
    return _profiles.firstWhere(
      (p) => p.id == _activeProfileId,
      orElse: () => _profiles.first,
    );
  }

  void init({
    List<EquipmentProfile>? savedProfiles,
    String? savedActiveId,
  }) {
    if (savedProfiles != null && savedProfiles.isNotEmpty) {
      _profiles = List.from(savedProfiles);
    } else {
      _profiles = List.from(EquipmentDatabase.defaultProfiles);
    }

    if (savedActiveId != null && _profiles.any((p) => p.id == savedActiveId)) {
      _activeProfileId = savedActiveId;
    } else {
      _activeProfileId = _profiles.first.id;
    }
    notifyListeners();
  }

  void setActiveProfile(String id) {
    if (_profiles.any((p) => p.id == id)) {
      _activeProfileId = id;
      notifyListeners();
    }
  }

  void addProfile(EquipmentProfile profile) {
    _profiles.add(profile);
    _activeProfileId = profile.id;
    notifyListeners();
  }

  void updateProfile(EquipmentProfile profile) {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      _profiles[index] = profile;
      notifyListeners();
    }
  }

  void deleteProfile(String id) {
    if (_profiles.length <= 1) return; // Keep at least one profile
    _profiles.removeWhere((p) => p.id == id);
    if (_activeProfileId == id) {
      _activeProfileId = _profiles.first.id;
    }
    notifyListeners();
  }

  void setCameraAngle(double angleDeg) {
    // Normalize to [0, 360)
    var a = angleDeg % 360.0;
    if (a < 0) a += 360.0;
    _cameraAngleDeg = a;
    notifyListeners();
  }

  void rotateBy(double deltaDeg) {
    setCameraAngle(_cameraAngleDeg + deltaDeg);
  }

  void toggleRuleOfThirds([bool? value]) {
    _showRuleOfThirds = value ?? !_showRuleOfThirds;
    notifyListeners();
  }

  void setFramingEnabled(bool enabled) {
    _isFramingEnabled = enabled;
    notifyListeners();
  }

  /// Automatically aligns the camera sensor's long axis with the target's major axis orientation
  void autoAlignWithTarget(double targetAngleDeg) {
    setCameraAngle(targetAngleDeg);
  }
}

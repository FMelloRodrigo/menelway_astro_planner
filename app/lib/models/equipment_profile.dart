import 'dart:math' as math;

class TelescopeProfile {
  final String id;
  final String name;
  final double focalLengthMm;
  final double apertureMm;
  final double reducerFactor;

  const TelescopeProfile({
    required this.id,
    required this.name,
    required this.focalLengthMm,
    required this.apertureMm,
    this.reducerFactor = 1.0,
  });

  double get effectiveFocalLength => focalLengthMm * reducerFactor;

  double get focalRatio => apertureMm > 0 ? effectiveFocalLength / apertureMm : 0.0;

  String get focalRatioString => "f/${focalRatio.toStringAsFixed(1)}";

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'focalLengthMm': focalLengthMm,
        'apertureMm': apertureMm,
        'reducerFactor': reducerFactor,
      };

  factory TelescopeProfile.fromJson(Map<String, dynamic> json) {
    return TelescopeProfile(
      id: json['id'] as String? ?? 'custom_scope',
      name: json['name'] as String? ?? 'Custom Telescope',
      focalLengthMm: (json['focalLengthMm'] as num?)?.toDouble() ?? 400.0,
      apertureMm: (json['apertureMm'] as num?)?.toDouble() ?? 72.0,
      reducerFactor: (json['reducerFactor'] as num?)?.toDouble() ?? 1.0,
    );
  }

  TelescopeProfile copyWith({
    String? id,
    String? name,
    double? focalLengthMm,
    double? apertureMm,
    double? reducerFactor,
  }) {
    return TelescopeProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      focalLengthMm: focalLengthMm ?? this.focalLengthMm,
      apertureMm: apertureMm ?? this.apertureMm,
      reducerFactor: reducerFactor ?? this.reducerFactor,
    );
  }
}

class CameraProfile {
  final String id;
  final String name;
  final double sensorWidthMm;
  final double sensorHeightMm;
  final double pixelSizeMicrons;
  final int resolutionWidthPx;
  final int resolutionHeightPx;

  const CameraProfile({
    required this.id,
    required this.name,
    required this.sensorWidthMm,
    required this.sensorHeightMm,
    required this.pixelSizeMicrons,
    required this.resolutionWidthPx,
    required this.resolutionHeightPx,
  });

  double get aspectRatio => sensorHeightMm > 0 ? sensorWidthMm / sensorHeightMm : 1.0;

  double get megapixels => (resolutionWidthPx * resolutionHeightPx) / 1000000.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sensorWidthMm': sensorWidthMm,
        'sensorHeightMm': sensorHeightMm,
        'pixelSizeMicrons': pixelSizeMicrons,
        'resolutionWidthPx': resolutionWidthPx,
        'resolutionHeightPx': resolutionHeightPx,
      };

  factory CameraProfile.fromJson(Map<String, dynamic> json) {
    return CameraProfile(
      id: json['id'] as String? ?? 'custom_camera',
      name: json['name'] as String? ?? 'Custom Camera',
      sensorWidthMm: (json['sensorWidthMm'] as num?)?.toDouble() ?? 23.5,
      sensorHeightMm: (json['sensorHeightMm'] as num?)?.toDouble() ?? 15.6,
      pixelSizeMicrons: (json['pixelSizeMicrons'] as num?)?.toDouble() ?? 3.76,
      resolutionWidthPx: (json['resolutionWidthPx'] as num?)?.toInt() ?? 6248,
      resolutionHeightPx: (json['resolutionHeightPx'] as num?)?.toInt() ?? 4176,
    );
  }

  CameraProfile copyWith({
    String? id,
    String? name,
    double? sensorWidthMm,
    double? sensorHeightMm,
    double? pixelSizeMicrons,
    int? resolutionWidthPx,
    int? resolutionHeightPx,
  }) {
    return CameraProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      sensorWidthMm: sensorWidthMm ?? this.sensorWidthMm,
      sensorHeightMm: sensorHeightMm ?? this.sensorHeightMm,
      pixelSizeMicrons: pixelSizeMicrons ?? this.pixelSizeMicrons,
      resolutionWidthPx: resolutionWidthPx ?? this.resolutionWidthPx,
      resolutionHeightPx: resolutionHeightPx ?? this.resolutionHeightPx,
    );
  }
}

class EquipmentProfile {
  final String id;
  final String name;
  final TelescopeProfile telescope;
  final CameraProfile camera;

  const EquipmentProfile({
    required this.id,
    required this.name,
    required this.telescope,
    required this.camera,
  });

  /// Horizontal Sensor Field of View in degrees
  double get sensorFovWidthDeg {
    final effFl = telescope.effectiveFocalLength;
    if (effFl <= 0) return 0.0;
    return 2.0 * math.atan(camera.sensorWidthMm / (2.0 * effFl)) * (180.0 / math.pi);
  }

  /// Vertical Sensor Field of View in degrees
  double get sensorFovHeightDeg {
    final effFl = telescope.effectiveFocalLength;
    if (effFl <= 0) return 0.0;
    return 2.0 * math.atan(camera.sensorHeightMm / (2.0 * effFl)) * (180.0 / math.pi);
  }

  /// Diagonal Sensor Field of View in degrees
  double get sensorFovDiagonalDeg {
    final w = sensorFovWidthDeg;
    final h = sensorFovHeightDeg;
    return math.sqrt(w * w + h * h);
  }

  /// Sensor FOV in arcminutes
  double get sensorFovWidthArcmin => sensorFovWidthDeg * 60.0;
  double get sensorFovHeightArcmin => sensorFovHeightDeg * 60.0;

  /// Image Scale / Resolution in arcseconds per pixel
  double get imageScaleArcsecPerPixel {
    final effFl = telescope.effectiveFocalLength;
    if (effFl <= 0) return 0.0;
    return (206.265 * camera.pixelSizeMicrons) / effFl;
  }

  /// Sampling category for typical atmospheric seeing (2" - 3")
  String get samplingCategory {
    final scale = imageScaleArcsecPerPixel;
    if (scale < 0.67) {
      return "Over-sampled (${scale.toStringAsFixed(2)}\"/px)";
    } else if (scale <= 2.0) {
      return "Optimal (${scale.toStringAsFixed(2)}\"/px)";
    } else {
      return "Wide-field (${scale.toStringAsFixed(2)}\"/px)";
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'telescope': telescope.toJson(),
        'camera': camera.toJson(),
      };

  factory EquipmentProfile.fromJson(Map<String, dynamic> json) {
    return EquipmentProfile(
      id: json['id'] as String? ?? 'rig_default',
      name: json['name'] as String? ?? 'Default Rig',
      telescope: json['telescope'] != null
          ? TelescopeProfile.fromJson(json['telescope'] as Map<String, dynamic>)
          : const TelescopeProfile(
              id: 'redcat51',
              name: 'William Optics RedCat 51',
              focalLengthMm: 250.0,
              apertureMm: 51.0,
            ),
      camera: json['camera'] != null
          ? CameraProfile.fromJson(json['camera'] as Map<String, dynamic>)
          : const CameraProfile(
              id: 'asi2600mc',
              name: 'ZWO ASI2600MC Pro',
              sensorWidthMm: 23.5,
              sensorHeightMm: 15.6,
              pixelSizeMicrons: 3.76,
              resolutionWidthPx: 6248,
              resolutionHeightPx: 4176,
            ),
    );
  }

  EquipmentProfile copyWith({
    String? id,
    String? name,
    TelescopeProfile? telescope,
    CameraProfile? camera,
  }) {
    return EquipmentProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      telescope: telescope ?? this.telescope,
      camera: camera ?? this.camera,
    );
  }
}

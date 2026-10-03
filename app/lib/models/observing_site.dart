import 'package:flutter/material.dart';

/// Helper defining Bortle scale metadata, IAU color standards, and sky characteristics.
class BortleInfo {
  final int level;
  final String title;
  final String description;
  final String sqmRange;
  final Color color;

  const BortleInfo({
    required this.level,
    required this.title,
    required this.description,
    required this.sqmRange,
    required this.color,
  });

  static const List<BortleInfo> allLevels = [
    BortleInfo(
      level: 1,
      title: 'Excellent Dark Sky',
      description: 'Zodiacal light, gegenschein, and airglow clearly visible. M33 direct naked-eye vision.',
      sqmRange: '21.7 - 22.0',
      color: Color(0xFF10141D), // Pitch black / deep space
    ),
    BortleInfo(
      level: 2,
      title: 'Truly Dark Site',
      description: 'Airglow faintly visible near horizon. Milky Way highly structured and detailed.',
      sqmRange: '21.5 - 21.7',
      color: Color(0xFF1E3A5F), // Deep navy / indigo
    ),
    BortleInfo(
      level: 3,
      title: 'Rural Sky',
      description: 'Milky Way shows intricate structure; slight light pollution domes on horizon.',
      sqmRange: '21.3 - 21.5',
      color: Color(0xFF2E7D32), // Forest green
    ),
    BortleInfo(
      level: 4,
      title: 'Rural / Suburban Transition',
      description: 'Light domes visible in several directions. Milky Way impressive but lacks detail near horizon.',
      sqmRange: '20.4 - 21.3',
      color: Color(0xFF689F38), // Olive green
    ),
    BortleInfo(
      level: 5,
      title: 'Suburban Sky',
      description: 'Milky Way washed out or invisible near horizon. Light domes prominent.',
      sqmRange: '19.5 - 20.4',
      color: Color(0xFFF9A825), // Amber / Gold
    ),
    BortleInfo(
      level: 6,
      title: 'Bright Suburban Sky',
      description: 'Milky Way only visible towards zenith. Sky background glows grayish-white.',
      sqmRange: '18.5 - 19.5',
      color: Color(0xFFEF6C00), // Orange
    ),
    BortleInfo(
      level: 7,
      title: 'Suburban / Urban Transition',
      description: 'Entire sky background has strong glow. Milky Way invisible or nearly so.',
      sqmRange: '18.0 - 18.5',
      color: Color(0xFFD84315), // Red-orange
    ),
    BortleInfo(
      level: 8,
      title: 'City Sky',
      description: 'Sky glows brightly whitish-gray. Only brightest stars and planets easily identified.',
      sqmRange: '17.5 - 18.0',
      color: Color(0xFFC62828), // Crimson red
    ),
    BortleInfo(
      level: 9,
      title: 'Inner-City Sky',
      description: 'Entire sky brightly illuminated. Only Moon, planets, and very bright stars visible.',
      sqmRange: '< 17.5',
      color: Color(0xFFAD1457), // Magenta / Deep rose
    ),
  ];

  static BortleInfo get(int level) {
    final clamped = level.clamp(1, 9);
    return allLevels[clamped - 1];
  }
}

/// Represents an observing site with geographical coordinates, elevation, and sky darkness rating.
class ObservingSite {
  static const double minLatitude = -90.0;
  static const double maxLatitude = 90.0;
  static const double minLongitude = -180.0;
  static const double maxLongitude = 180.0;
  static const double minElevation = -500.0;
  static const double maxElevation = 9000.0;
  static const int minBortle = 1;
  static const int maxBortle = 9;

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double elevation;
  final int bortleClass; // 1 to 9
  final String notes;

  const ObservingSite({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    this.bortleClass = 4,
    this.notes = '',
  });

  /// Formatted coordinates string, e.g. "22.3°S, 42.5°W (858m)"
  String get coordinatesFormatted {
    final latStr = latitude >= 0
        ? '${latitude.toStringAsFixed(2)}°N'
        : '${(-latitude).toStringAsFixed(2)}°S';
    final lonStr = longitude >= 0
        ? '${longitude.toStringAsFixed(2)}°E'
        : '${(-longitude).toStringAsFixed(2)}°W';
    return '$latStr, $lonStr (${elevation.round()}m)';
  }

  /// Compact coordinates, e.g. "22.3°S, 42.5°W"
  String get compactCoordinates {
    final latStr = latitude >= 0
        ? '${latitude.toStringAsFixed(1)}°N'
        : '${(-latitude).toStringAsFixed(1)}°S';
    final lonStr = longitude >= 0
        ? '${longitude.toStringAsFixed(1)}°E'
        : '${(-longitude).toStringAsFixed(1)}°W';
    return '$latStr, $lonStr';
  }

  /// Bortle metadata
  BortleInfo get bortleInfo => BortleInfo.get(bortleClass);

  ObservingSite copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? elevation,
    int? bortleClass,
    String? notes,
  }) {
    return ObservingSite(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: (latitude ?? this.latitude).clamp(minLatitude, maxLatitude),
      longitude: (longitude ?? this.longitude).clamp(minLongitude, maxLongitude),
      elevation: (elevation ?? this.elevation).clamp(minElevation, maxElevation),
      bortleClass: (bortleClass ?? this.bortleClass).clamp(minBortle, maxBortle),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'elevation': elevation,
        'bortleClass': bortleClass,
        'notes': notes,
      };

  factory ObservingSite.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble() ?? -22.2819;
    final lon = (json['longitude'] as num?)?.toDouble() ?? -42.5311;
    final ele = (json['elevation'] as num?)?.toDouble() ?? 858.0;
    final bortle = (json['bortleClass'] as num?)?.toInt() ?? 4;

    return ObservingSite(
      id: json['id'] as String? ?? 'site_default',
      name: json['name'] as String? ?? 'Nova Friburgo, RJ, Brazil',
      latitude: lat.clamp(minLatitude, maxLatitude),
      longitude: lon.clamp(minLongitude, maxLongitude),
      elevation: ele.clamp(minElevation, maxElevation),
      bortleClass: bortle.clamp(minBortle, maxBortle),
      notes: json['notes'] as String? ?? '',
    );
  }

  static const double defaultLatitude = -22.2819;
  static const double defaultLongitude = -42.5311;
  static const double defaultElevation = 858.0;
  static const String defaultSiteName = 'Nova Friburgo, Rio de Janeiro, Brazil';

  /// Default fallback site when no saved configurations exist
  static const ObservingSite defaultSite = ObservingSite(
    id: 'site_default',
    name: defaultSiteName,
    latitude: defaultLatitude,
    longitude: defaultLongitude,
    elevation: defaultElevation,
    bortleClass: 4,
    notes: 'Default observing site',
  );
}

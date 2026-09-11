class TargetItem {
  final int id;
  final String name;
  final String? messier;
  final String? caldwell;
  final String? arp;
  final String? herschel;
  final String catalog;
  final String objectType;
  final String constellation;
  final double raHours;
  final double decDegrees;
  final double? magnitude;
  final double? majorAxisArcmin;
  final double? positionAngleDeg;
  final double? surfaceBrightness;
  final String? commonName;
  final double peakAltitudeDeg;
  final double visibleDurationHours;
  final DateTime transitTime;
  final DateTime? visibleStartTime;
  final DateTime? visibleEndTime;
  final double minMoonSepDeg;
  final bool meetsCriteria;

  const TargetItem({
    required this.id,
    required this.name,
    this.messier,
    this.caldwell,
    this.arp,
    this.herschel,
    required this.catalog,
    required this.objectType,
    required this.constellation,
    required this.raHours,
    required this.decDegrees,
    this.magnitude,
    this.majorAxisArcmin,
    this.positionAngleDeg,
    this.surfaceBrightness,
    this.commonName,
    required this.peakAltitudeDeg,
    required this.visibleDurationHours,
    required this.transitTime,
    this.visibleStartTime,
    this.visibleEndTime,
    required this.minMoonSepDeg,
    required this.meetsCriteria,
  });

  String get displayName {
    if (messier != null && messier!.isNotEmpty) {
      if (commonName != null && commonName!.isNotEmpty) {
        return '$messier ($commonName)';
      }
      return '$messier - $name';
    }
    if (caldwell != null && caldwell!.isNotEmpty) {
      if (commonName != null && commonName!.isNotEmpty) {
        return '$caldwell ($commonName)';
      }
      return '$caldwell - $name';
    }
    if (arp != null && arp!.isNotEmpty) {
      if (commonName != null && commonName!.isNotEmpty) {
        return '$arp ($commonName)';
      }
      return '$arp - $name';
    }
    if (herschel != null && herschel!.isNotEmpty) {
      if (commonName != null && commonName!.isNotEmpty) {
        return '$herschel ($commonName)';
      }
      return '$herschel - $name';
    }
    if (commonName != null && commonName!.isNotEmpty) {
      return '$name ($commonName)';
    }
    return name;
  }

  String get formattedRa {
    final h = raHours.floor();
    final m = ((raHours - h) * 60).floor();
    final s = (((raHours - h) * 60 - m) * 60).toStringAsFixed(1);
    return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m ${s.padLeft(4, '0')}s';
  }

  String get formattedDec {
    final sign = decDegrees >= 0 ? '+' : '-';
    final absD = decDegrees.abs();
    final d = absD.floor();
    final m = ((absD - d) * 60).floor();
    final s = (((absD - d) * 60 - m) * 60).toStringAsFixed(1);
    return '$sign${d.toString().padLeft(2, '0')}° ${m.toString().padLeft(2, '0')}\' ${s.padLeft(4, '0')}"';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'messier': messier,
      'caldwell': caldwell,
      'arp': arp,
      'herschel': herschel,
      'catalog': catalog,
      'objectType': objectType,
      'constellation': constellation,
      'raHours': raHours,
      'decDegrees': decDegrees,
      'magnitude': magnitude,
      'majorAxisArcmin': majorAxisArcmin,
      'positionAngleDeg': positionAngleDeg,
      'surfaceBrightness': surfaceBrightness,
      'commonName': commonName,
      'peakAltitudeDeg': peakAltitudeDeg,
      'visibleDurationHours': visibleDurationHours,
      'transitTime': transitTime.toIso8601String(),
      'visibleStartTime': visibleStartTime?.toIso8601String(),
      'visibleEndTime': visibleEndTime?.toIso8601String(),
      'minMoonSepDeg': minMoonSepDeg,
      'meetsCriteria': meetsCriteria,
    };
  }

  factory TargetItem.fromJson(Map<String, dynamic> json) {
    return TargetItem(
      id: json['id'] as int,
      name: json['name'] as String,
      messier: json['messier'] as String?,
      caldwell: json['caldwell'] as String?,
      arp: json['arp'] as String?,
      herschel: json['herschel'] as String?,
      catalog: json['catalog'] as String? ?? 'NGC',
      objectType: json['objectType'] as String? ?? 'DSO',
      constellation: json['constellation'] as String? ?? '',
      raHours: (json['raHours'] as num).toDouble(),
      decDegrees: (json['decDegrees'] as num).toDouble(),
      magnitude: (json['magnitude'] as num?)?.toDouble(),
      majorAxisArcmin: (json['majorAxisArcmin'] as num?)?.toDouble(),
      positionAngleDeg: (json['positionAngleDeg'] as num?)?.toDouble(),
      surfaceBrightness: (json['surfaceBrightness'] as num?)?.toDouble(),
      commonName: json['commonName'] as String?,
      peakAltitudeDeg: (json['peakAltitudeDeg'] as num?)?.toDouble() ?? 0.0,
      visibleDurationHours: (json['visibleDurationHours'] as num?)?.toDouble() ?? 0.0,
      transitTime: json['transitTime'] != null
          ? DateTime.tryParse(json['transitTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      visibleStartTime: json['visibleStartTime'] != null
          ? DateTime.tryParse(json['visibleStartTime'] as String)
          : null,
      visibleEndTime: json['visibleEndTime'] != null
          ? DateTime.tryParse(json['visibleEndTime'] as String)
          : null,
      minMoonSepDeg: (json['minMoonSepDeg'] as num?)?.toDouble() ?? 0.0,
      meetsCriteria: json['meetsCriteria'] as bool? ?? false,
    );
  }
}

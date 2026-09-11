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
}

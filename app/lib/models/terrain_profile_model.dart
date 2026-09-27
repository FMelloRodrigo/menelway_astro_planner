import 'dart:math' as math;
import 'filter_state.dart';

/// Represents a computed 360-degree topographical horizon profile from digital elevation models (DEM).
class TerrainProfileModel {
  final double originLat;
  final double originLon;
  final double groundElevation;
  final double stepDeg; // e.g. 0.5 deg (720 rays) or 1.0 deg (360 rays)
  final List<double> altitudes; // in degrees
  final List<double>? distances; // in meters to the peak / ridge
  final DateTime generatedAt;

  const TerrainProfileModel({
    required this.originLat,
    required this.originLon,
    required this.groundElevation,
    this.stepDeg = 0.5,
    required this.altitudes,
    this.distances,
    required this.generatedAt,
  });

  int get rayCount => altitudes.length;

  /// Returns interpolated altitude at any arbitrary azimuth angle [0..360].
  double altitudeAt(double azDeg) {
    if (altitudes.isEmpty) return 0.0;
    final n = altitudes.length;
    final normAz = ((azDeg % 360.0) + 360.0) % 360.0;
    final f = (normAz / 360.0) * n;
    final i = f.floor() % n;
    final j = (i + 1) % n;
    final t = f - f.floor();
    return altitudes[i] * (1.0 - t) + altitudes[j] * t;
  }

  /// Converts the dense ray scan into a manageable, editable list of
  /// landmark points using the Ramer-Douglas-Peucker (RDP) polyline simplification algorithm.
  /// [epsilonDeg] is the maximum vertical angle deviation in degrees before a peak is preserved.
  List<HorizonPointModel> toSimplifiedHorizonPoints({double epsilonDeg = 0.3}) {
    if (altitudes.isEmpty) return [];

    // Create 2D coordinate list: x = azimuth [0..360], y = altitude
    final rawPoints = <math.Point<double>>[];
    for (int i = 0; i < altitudes.length; i++) {
      final az = (i * stepDeg);
      rawPoints.add(math.Point<double>(az, altitudes[i]));
    }
    // Append 360 point matching 0 degrees for closed cycle
    rawPoints.add(math.Point<double>(360.0, altitudes.first));

    final simplified = _rdpSimplify(rawPoints, epsilonDeg);

    // Convert back to HorizonPointModel, rounding to 1 decimal place
    return simplified.map((p) {
      return HorizonPointModel(
        azimuth: (p.x.clamp(0.0, 360.0) * 10).round() / 10.0,
        altitude: (p.y.clamp(0.0, 90.0) * 10).round() / 10.0,
      );
    }).toList();
  }

  static List<math.Point<double>> _rdpSimplify(
    List<math.Point<double>> points,
    double epsilon,
  ) {
    if (points.length < 3) return points;

    double maxDist = 0.0;
    int index = 0;
    final first = points.first;
    final last = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDistance(points[i], first, last);
      if (d > maxDist) {
        maxDist = d;
        index = i;
      }
    }

    if (maxDist > epsilon) {
      final left = _rdpSimplify(points.sublist(0, index + 1), epsilon);
      final right = _rdpSimplify(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [first, last];
    }
  }

  static double _perpendicularDistance(
    math.Point<double> p,
    math.Point<double> lineStart,
    math.Point<double> lineEnd,
  ) {
    final dx = lineEnd.x - lineStart.x;
    final dy = lineEnd.y - lineStart.y;
    final lineLengthSq = dx * dx + dy * dy;

    if (lineLengthSq == 0.0) {
      return p.distanceTo(lineStart);
    }

    final t = ((p.x - lineStart.x) * dx + (p.y - lineStart.y) * dy) / lineLengthSq;
    final clampedT = t.clamp(0.0, 1.0);
    final projection = math.Point<double>(
      lineStart.x + clampedT * dx,
      lineStart.y + clampedT * dy,
    );
    return p.distanceTo(projection);
  }

  Map<String, dynamic> toJson() => {
    'originLat': originLat,
    'originLon': originLon,
    'groundElevation': groundElevation,
    'stepDeg': stepDeg,
    'altitudes': altitudes,
    'distances': distances,
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory TerrainProfileModel.fromJson(Map<String, dynamic> json) {
    return TerrainProfileModel(
      originLat: (json['originLat'] as num?)?.toDouble() ?? 0.0,
      originLon: (json['originLon'] as num?)?.toDouble() ?? 0.0,
      groundElevation: (json['groundElevation'] as num?)?.toDouble() ?? 0.0,
      stepDeg: (json['stepDeg'] as num?)?.toDouble() ?? 0.5,
      altitudes: (json['altitudes'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      distances: (json['distances'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

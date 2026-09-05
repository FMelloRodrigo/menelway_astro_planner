class AltitudePoint {
  final DateTime time;
  final double altitude;
  final double azimuth;
  final double moonSeparation;
  final bool meetsCriteria;

  const AltitudePoint({
    required this.time,
    required this.altitude,
    required this.azimuth,
    required this.moonSeparation,
    required this.meetsCriteria,
  });
}

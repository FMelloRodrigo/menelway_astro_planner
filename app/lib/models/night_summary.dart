class NightSummary {
  final DateTime sunset;
  final DateTime civilDusk;
  final DateTime nauticalDusk;
  final DateTime astronomicalDusk;
  final DateTime solarMidnight;
  final DateTime astronomicalDawn;
  final DateTime nauticalDawn;
  final DateTime civilDawn;
  final DateTime sunrise;
  final double moonIllumination;
  final String moonPhaseName;
  final bool hasAstronomicalNight;

  const NightSummary({
    required this.sunset,
    required this.civilDusk,
    required this.nauticalDusk,
    required this.astronomicalDusk,
    required this.solarMidnight,
    required this.astronomicalDawn,
    required this.nauticalDawn,
    required this.civilDawn,
    required this.sunrise,
    required this.moonIllumination,
    required this.moonPhaseName,
    required this.hasAstronomicalNight,
  });

  Duration get darkDuration {
    return astronomicalDawn.difference(astronomicalDusk);
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'app_logger.dart';

class GeoLocationResult {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double elevation;
  final String country;
  final String? admin1;
  final String? timezone;
  final String? featureCode;
  final String? formattedAddress;

  const GeoLocationResult({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.country,
    this.admin1,
    this.timezone,
    this.featureCode,
    this.formattedAddress,
  });

  /// Returns true if this location represents an airport, airfield, or heliport.
  bool get isAirport {
    final code = (featureCode ?? '').toUpperCase();
    if (code.startsWith('AIR')) return true;
    final lowerName = name.toLowerCase();
    if (lowerName.contains('airport') ||
        lowerName.contains('aeroporto') ||
        lowerName.contains('airfield') ||
        lowerName.contains('airstrip') ||
        lowerName.contains('heliport') ||
        lowerName.contains('heliponto')) {
      return true;
    }
    return false;
  }

  String get displayName {
    if (formattedAddress != null && formattedAddress!.isNotEmpty) {
      return formattedAddress!;
    }
    final parts = <String>[name];
    if (admin1 != null && admin1!.isNotEmpty && admin1 != name) {
      parts.add(admin1!);
    }
    if (country.isNotEmpty) {
      parts.add(country);
    }
    return parts.join(', ');
  }

  factory GeoLocationResult.fromJson(Map<String, dynamic> json) {
    return GeoLocationResult(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
      country: json['country'] as String? ?? '',
      admin1: json['admin1'] as String?,
      timezone: json['timezone'] as String?,
      featureCode: json['feature_code'] as String?,
    );
  }

  factory GeoLocationResult.fromNominatim(Map<String, dynamic> json) {
    final addr = json['address'] as Map<String, dynamic>? ?? {};
    final rawName = json['name'] as String? ?? '';
    final road = addr['road'] as String? ?? '';
    final suburb = addr['suburb'] as String? ?? addr['neighbourhood'] as String? ?? '';
    final city = addr['city'] as String? ?? addr['town'] as String? ?? addr['municipality'] as String? ?? '';
    final state = addr['state'] as String? ?? '';
    final country = addr['country'] as String? ?? '';

    final name = rawName.isNotEmpty ? rawName : (road.isNotEmpty ? road : (suburb.isNotEmpty ? suburb : city));
    final displayName = json['display_name'] as String? ?? name;

    return GeoLocationResult(
      id: json['place_id'] as int? ?? 0,
      name: name,
      latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
      elevation: 0.0,
      country: country,
      admin1: state.isNotEmpty ? state : suburb,
      featureCode: json['type'] as String? ?? json['class'] as String?,
      formattedAddress: displayName,
    );
  }

  GeoLocationResult copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    double? elevation,
    String? country,
    String? admin1,
    String? timezone,
    String? featureCode,
    String? formattedAddress,
  }) {
    return GeoLocationResult(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevation: elevation ?? this.elevation,
      country: country ?? this.country,
      admin1: admin1 ?? this.admin1,
      timezone: timezone ?? this.timezone,
      featureCode: featureCode ?? this.featureCode,
      formattedAddress: formattedAddress ?? this.formattedAddress,
    );
  }
}

class GeocodingService {
  static const String _tag = 'GeocodingService';
  static const Duration requestTimeout = Duration(seconds: 6);
  static const int maxResults = 8;

  /// Searches for matching cities/locations using the free Open-Meteo Geocoding API (Default city flow).
  static Future<List<GeoLocationResult>> searchCities(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    try {
      final encoded = Uri.encodeComponent(cleanQuery);
      final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=$encoded&count=16&language=en&format=json',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'AstroTargetsPlanner/1.0'},
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          return results
              .map((e) => GeoLocationResult.fromJson(e as Map<String, dynamic>))
              .where((loc) => !loc.isAirport)
              .take(maxResults)
              .toList();
        }
      } else {
        AppLogger.warning('Open-Meteo API returned HTTP ${response.statusCode} for "$cleanQuery"', tag: _tag);
      }
    } catch (e) {
      AppLogger.warning('Geocoding search failed for "$cleanQuery"', tag: _tag, error: e);
    }
    return [];
  }

  /// Searches for precise streets, avenues, neighborhoods, or landmarks worldwide (Optional precision flow)
  /// using the free, keyless OpenStreetMap Nominatim API.
  static Future<List<GeoLocationResult>> searchPreciseAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    try {
      final encoded = Uri.encodeComponent(cleanQuery);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&addressdetails=1&limit=8',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'AstroTargetsPlanner/1.0 (local_astronomy_tool)',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => GeoLocationResult.fromNominatim(e as Map<String, dynamic>))
            .take(maxResults)
            .toList();
      } else {
        AppLogger.warning('OSM Nominatim returned HTTP ${response.statusCode} for "$cleanQuery"', tag: _tag);
      }
    } catch (e) {
      AppLogger.warning('OSM Nominatim address search failed for "$cleanQuery"', tag: _tag, error: e);
    }
    return [];
  }

  /// Automatically retrieves ground elevation in meters for a given coordinate.
  static Future<double?> fetchElevation(double latitude, double longitude) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/elevation?latitude=$latitude&longitude=$longitude',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'AstroTargetsPlanner/1.0'},
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final elevList = data['elevation'] as List<dynamic>?;
        if (elevList != null && elevList.isNotEmpty) {
          final val = (elevList[0] as num?)?.toDouble();
          return val;
        }
      }
    } catch (e) {
      AppLogger.warning('Elevation lookup failed for ($latitude, $longitude)', tag: _tag, error: e);
    }
    return null;
  }
}

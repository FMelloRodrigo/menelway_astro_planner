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

  const GeoLocationResult({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.country,
    this.admin1,
    this.timezone,
  });

  String get displayName {
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
    );
  }
}

class GeocodingService {
  static const String _tag = 'GeocodingService';
  static const Duration requestTimeout = Duration(seconds: 6);
  static const int maxResults = 8;

  /// Searches for matching cities/locations using the free Open-Meteo Geocoding API.
  static Future<List<GeoLocationResult>> searchCities(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    try {
      final encoded = Uri.encodeComponent(cleanQuery);
      final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=$encoded&count=$maxResults&language=en&format=json',
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
}

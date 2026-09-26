import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/geocoding_service.dart';

void main() {
  group('GeoLocationResult Tests', () {
    test('Correctly identifies airport feature codes and names', () {
      final airportByCode = GeoLocationResult.fromJson({
        'id': 6300669,
        'name': 'Sao José Dos Campos',
        'latitude': -23.22817,
        'longitude': -45.86274,
        'elevation': 646.0,
        'country': 'Brazil',
        'admin1': 'São Paulo',
        'feature_code': 'AIRP',
      });
      expect(airportByCode.isAirport, isTrue);

      final city = GeoLocationResult.fromJson({
        'id': 3448636,
        'name': 'São José dos Campos',
        'latitude': -23.17944,
        'longitude': -45.88694,
        'elevation': 600.0,
        'country': 'Brazil',
        'admin1': 'São Paulo',
        'feature_code': 'PPLA2',
      });
      expect(city.isAirport, isFalse);

      final airportByName = GeoLocationResult.fromJson({
        'id': 12345,
        'name': 'London Heathrow Airport',
        'latitude': 51.47,
        'longitude': -0.45,
        'elevation': 25.0,
        'country': 'United Kingdom',
        'feature_code': 'PPL',
      });
      expect(airportByName.isAirport, isTrue);

      final heliport = GeoLocationResult.fromJson({
        'id': 12346,
        'name': 'Downtown Heliponto',
        'latitude': -23.55,
        'longitude': -46.63,
        'elevation': 750.0,
        'country': 'Brazil',
        'feature_code': 'AIRH',
      });
      expect(heliport.isAirport, isTrue);
    });

    test('displayName builds clean hierarchy', () {
      final loc = GeoLocationResult(
        id: 1,
        name: 'São José dos Campos',
        latitude: -23.17944,
        longitude: -45.88694,
        elevation: 600.0,
        country: 'Brazil',
        admin1: 'São Paulo',
      );
      expect(loc.displayName, equals('São José dos Campos, São Paulo, Brazil'));
    });
  });
}

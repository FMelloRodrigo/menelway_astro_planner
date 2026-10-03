import 'package:flutter_test/flutter_test.dart';
import 'package:app/utils/astro_formatters.dart';

void main() {
  group('AstroFormatters', () {
    test('formatRa converts decimal hours to canonical HHh MMm SS.Ss', () {
      expect(AstroFormatters.formatRa(0.0), '00h 00m 00.0s');
      expect(AstroFormatters.formatRa(12.5), '12h 30m 00.0s');
      expect(AstroFormatters.formatRa(5.588), '05h 35m 16.8s');
      expect(AstroFormatters.formatRa(23.999), '23h 59m 56.4s');
    });

    test('formatRa handles negative and wrapping hours', () {
      expect(AstroFormatters.formatRa(25.0), '01h 00m 00.0s');
      expect(AstroFormatters.formatRa(-1.0), '23h 00m 00.0s');
    });

    test('formatDec formats positive declinations with + prefix', () {
      expect(AstroFormatters.formatDec(0.0), '+00° 00\' 00.0"');
      expect(AstroFormatters.formatDec(45.5), '+45° 30\' 00.0"');
      expect(AstroFormatters.formatDec(89.25), '+89° 15\' 00.0"');
    });

    test('formatDec formats negative declinations with - prefix', () {
      expect(AstroFormatters.formatDec(-16.716), '-16° 42\' 57.6"');
      expect(AstroFormatters.formatDec(-0.5), '-00° 30\' 00.0"');
      expect(AstroFormatters.formatDec(-90.0), '-90° 00\' 00.0"');
    });

    test('cardinalFromAzimuth returns correct 8-point compass in English and Portuguese', () {
      // 0 deg -> North
      expect(AstroFormatters.cardinalFromAzimuth(0), 'N');
      expect(AstroFormatters.cardinalFromAzimuth(360), 'N');
      expect(AstroFormatters.cardinalFromAzimuth(10), 'N');
      expect(AstroFormatters.cardinalFromAzimuth(355), 'N');

      // 45 deg -> North-East
      expect(AstroFormatters.cardinalFromAzimuth(45), 'NE');
      expect(AstroFormatters.cardinalFromAzimuth(45, isPt: true), 'NE');

      // 90 deg -> East (Leste in Portuguese)
      expect(AstroFormatters.cardinalFromAzimuth(90), 'E');
      expect(AstroFormatters.cardinalFromAzimuth(90, isPt: true), 'L');

      // 180 deg -> South
      expect(AstroFormatters.cardinalFromAzimuth(180), 'S');
      expect(AstroFormatters.cardinalFromAzimuth(180, isPt: true), 'S');

      // 225 deg -> South-West (Sudoeste in Portuguese)
      expect(AstroFormatters.cardinalFromAzimuth(225), 'SW');
      expect(AstroFormatters.cardinalFromAzimuth(225, isPt: true), 'SO');

      // 270 deg -> West (Oeste in Portuguese)
      expect(AstroFormatters.cardinalFromAzimuth(270), 'W');
      expect(AstroFormatters.cardinalFromAzimuth(270, isPt: true), 'O');

      // 315 deg -> North-West (Noroeste in Portuguese)
      expect(AstroFormatters.cardinalFromAzimuth(315), 'NW');
      expect(AstroFormatters.cardinalFromAzimuth(315, isPt: true), 'NO');
    });
  });
}

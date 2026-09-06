import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/filter_state.dart';

void main() {
  group('FilterState Observing Time Window Tests', () {
    test('Standard evening window: 21:00 to 23:00', () {
      final date = DateTime(2026, 9, 5, 12, 0);
      final filter = FilterState(
        date: date,
        useCustomTimeWindow: true,
        customStartHour: 21,
        customStartMinute: 0,
        customEndHour: 23,
        customEndMinute: 0,
      );

      expect(filter.windowDurationHours, closeTo(2.0, 1e-4));
      expect(filter.formattedWindow, equals('21:00h - 23:00h'));

      final start = filter.getWindowStart(date);
      final end = filter.getWindowEnd(date);

      expect(start.year, equals(2026));
      expect(start.month, equals(9));
      expect(start.day, equals(5));
      expect(start.hour, equals(21));
      expect(start.minute, equals(0));

      expect(end.year, equals(2026));
      expect(end.month, equals(9));
      expect(end.day, equals(5));
      expect(end.hour, equals(23));
      expect(end.minute, equals(0));

      expect(end.difference(start).inMinutes, equals(120));
    });

    test('Cross-midnight window: 21:00 to 02:30 next morning', () {
      final date = DateTime(2026, 9, 5, 12, 0);
      final filter = FilterState(
        date: date,
        useCustomTimeWindow: true,
        customStartHour: 21,
        customStartMinute: 0,
        customEndHour: 2,
        customEndMinute: 30,
      );

      expect(filter.windowDurationHours, closeTo(5.5, 1e-4));
      expect(filter.formattedWindow, equals('21:00h - 02:30h'));

      final start = filter.getWindowStart(date);
      final end = filter.getWindowEnd(date);

      expect(start.day, equals(5));
      expect(start.hour, equals(21));

      expect(end.day, equals(6));
      expect(end.hour, equals(2));
      expect(end.minute, equals(30));

      expect(end.difference(start).inMinutes, equals(330));
    });

    test('Post-midnight morning window: 01:00 to 04:00', () {
      final date = DateTime(2026, 9, 5, 12, 0);
      final filter = FilterState(
        date: date,
        useCustomTimeWindow: true,
        customStartHour: 1,
        customStartMinute: 0,
        customEndHour: 4,
        customEndMinute: 0,
      );

      expect(filter.windowDurationHours, closeTo(3.0, 1e-4));
      expect(filter.formattedWindow, equals('01:00h - 04:00h'));

      final start = filter.getWindowStart(date);
      final end = filter.getWindowEnd(date);

      expect(start.day, equals(6));
      expect(start.hour, equals(1));

      expect(end.day, equals(6));
      expect(end.hour, equals(4));

      expect(end.difference(start).inMinutes, equals(180));
    });
  });
}

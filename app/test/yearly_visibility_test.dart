import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/yearly_visibility.dart';

void main() {
  group('YearlyVisibilityModel Tests', () {
    test('Correctly parses JSON payload from C++ engine', () {
      final json = {
        "target_id": 42,
        "theoretical_max_altitude_deg": 88.5,
        "can_ever_reach_min_alt": true,
        "peak_month": 1,
        "best_window_start": 10,
        "best_window_end": 2,
        "max_hours_in_peak": 6.8,
        "best_window_summary": "October – February (Peak: January)",
        "months": [
          {
            "month": 1,
            "name": "Jan",
            "hours_observable": 6.8,
            "peak_altitude_deg": 88.4,
            "is_observable": true
          },
          {
            "month": 2,
            "name": "Feb",
            "hours_observable": 4.5,
            "peak_altitude_deg": 88.4,
            "is_observable": true
          },
          {
            "month": 6,
            "name": "Jun",
            "hours_observable": 0.0,
            "peak_altitude_deg": -15.0,
            "is_observable": false
          }
        ]
      };

      final model = YearlyVisibilityModel.fromJson(json);

      expect(model.targetId, 42);
      expect(model.theoreticalMaxAltitudeDeg, 88.5);
      expect(model.canEverReachMinAlt, true);
      expect(model.peakMonth, 1);
      expect(model.bestWindowStart, 10);
      expect(model.bestWindowEnd, 2);
      expect(model.maxHoursInPeak, 6.8);
      expect(model.bestWindowSummary, "October – February (Peak: January)");
      expect(model.months.length, 3);
      expect(model.months[0].name, "Jan");
      expect(model.months[0].isObservable, true);
      expect(model.months[2].name, "Jun");
      expect(model.months[2].isObservable, false);
    });

    test('Handles unreachable target from observer latitude', () {
      final json = {
        "target_id": 999,
        "theoretical_max_altitude_deg": 12.4,
        "can_ever_reach_min_alt": false,
        "peak_month": 3,
        "best_window_start": 0,
        "best_window_end": 0,
        "max_hours_in_peak": 0.0,
        "best_window_summary": "Never reaches 30° at this latitude (Max: 12.4°)",
        "months": []
      };

      final model = YearlyVisibilityModel.fromJson(json);

      expect(model.canEverReachMinAlt, false);
      expect(model.bestWindowSummary, contains("Never reaches"));
      expect(model.theoreticalMaxAltitudeDeg, 12.4);
    });

    test('Parses day-level precision for Rosette Nebula (C49) scenario', () {
      final json = {
        "target_id": 49,
        "theoretical_max_altitude_deg": 55.0,
        "can_ever_reach_min_alt": true,
        "peak_month": 1,
        "peak_day": 2,
        "start_month": 9,
        "start_day": 27,
        "end_month": 3,
        "end_day": 28,
        "best_window_start": 9,
        "best_window_end": 3,
        "total_observable_days": 183,
        "max_hours_in_peak": 8.4,
        "best_window_summary": "Sep 27 – Mar 28 (Peak: Jan 2)",
        "months": [
          {
            "month": 9,
            "name": "Sep",
            "hours_observable": 2.4,
            "peak_altitude_deg": 42.0,
            "is_observable": true,
            "observable_days_count": 4,
            "start_day": 27,
            "end_day": 30,
            "total_days_in_month": 30
          },
          {
            "month": 10,
            "name": "Oct",
            "hours_observable": 4.8,
            "peak_altitude_deg": 54.0,
            "is_observable": true,
            "observable_days_count": 31,
            "start_day": 1,
            "end_day": 31,
            "total_days_in_month": 31
          },
          {
            "month": 4,
            "name": "Apr",
            "hours_observable": 0.0,
            "peak_altitude_deg": 18.0,
            "is_observable": false,
            "observable_days_count": 0,
            "start_day": 0,
            "end_day": 0,
            "total_days_in_month": 30
          }
        ]
      };

      final model = YearlyVisibilityModel.fromJson(json);

      expect(model.startMonth, 9);
      expect(model.startDay, 27);
      expect(model.endMonth, 3);
      expect(model.endDay, 28);
      expect(model.peakDay, 2);
      expect(model.totalObservableDays, 183);
      expect(model.bestWindowSummary, "Sep 27 – Mar 28 (Peak: Jan 2)");

      // September should be identified as a partial month
      final sep = model.months[0];
      expect(sep.isPartialMonth, true);
      expect(sep.observableDaysCount, 4);
      expect(sep.startDay, 27);
      expect(sep.endDay, 30);
      expect(sep.dateRangeLabel, contains("From Sep 27 (4 days"));

      // October is a full month
      final oct = model.months[1];
      expect(oct.isPartialMonth, false);
      expect(oct.observableDaysCount, 31);
      expect(oct.dateRangeLabel, contains("Full month (31 days"));

      // April is not observable
      final apr = model.months[2];
      expect(apr.isObservable, false);
      expect(apr.dateRangeLabel, contains("Not observable"));

      // isDateObservable tests
      expect(model.isDateObservable(DateTime(2026, 9, 21)), isFalse); // 6 days before season starts
      expect(model.isDateObservable(DateTime(2026, 9, 26)), isFalse);
      expect(model.isDateObservable(DateTime(2026, 9, 27)), isTrue);  // Season start
      expect(model.isDateObservable(DateTime(2026, 9, 30)), isTrue);
      expect(model.isDateObservable(DateTime(2026, 10, 15)), isTrue); // Full month
      expect(model.isDateObservable(DateTime(2026, 4, 15)), isFalse); // Non-observable month
      expect(model.isDateObservable(DateTime(2026, 5, 10)), isFalse); // Month not present in payload
    });

    test('isDateObservable returns false for unreachable or zero-day targets', () {
      final unreachableModel = const YearlyVisibilityModel(
        targetId: 1,
        theoreticalMaxAltitudeDeg: 10,
        canEverReachMinAlt: false,
        peakMonth: 1,
        bestWindowStart: 0,
        bestWindowEnd: 0,
        maxHoursInPeak: 0,
        bestWindowSummary: 'Unreachable',
        months: [],
      );
      expect(unreachableModel.isDateObservable(DateTime(2026, 9, 21)), isFalse);

      final zeroDaysModel = const YearlyVisibilityModel(
        targetId: 2,
        theoreticalMaxAltitudeDeg: 50,
        canEverReachMinAlt: true,
        peakMonth: 1,
        bestWindowStart: 0,
        bestWindowEnd: 0,
        totalObservableDays: 0,
        maxHoursInPeak: 0,
        bestWindowSummary: 'Zero days',
        months: [],
      );
      expect(zeroDaysModel.isDateObservable(DateTime(2026, 9, 21)), isFalse);
    });
  });
}

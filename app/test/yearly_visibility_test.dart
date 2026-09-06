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
  });
}

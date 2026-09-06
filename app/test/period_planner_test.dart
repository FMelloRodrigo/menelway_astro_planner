import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/period_target_item.dart';

void main() {
  group('PeriodTargetItem Model Tests', () {
    test('PeriodTargetItem parses and converts to TargetItem properly', () {
      final periodItem = PeriodTargetItem(
        id: 42,
        name: 'NGC 2244',
        caldwell: 'C49',
        commonName: 'Rosette Nebula',
        catalog: 'Caldwell',
        objectType: 'Open Cluster',
        constellation: 'Mon',
        raHours: 6.54,
        decDegrees: 4.95,
        magnitude: 4.8,
        majorAxisArcmin: 24.0,
        surfaceBrightness: 12.0,
        peakAltitudeDeg: 48.5,
        maxHoursObservable: 1.8,
        peakDate: DateTime(2026, 2, 14),
        observableDaysCount: 17,
        totalPeriodDays: 28,
        startMonth: 2,
        startDay: 1,
        endMonth: 2,
        endDay: 28,
        isObservable: true,
      );

      expect(periodItem.id, 42);
      expect(periodItem.caldwell, 'C49');
      expect(periodItem.observableDaysCount, 17);
      expect(periodItem.totalPeriodDays, 28);
      expect(periodItem.isObservable, isTrue);
      expect(periodItem.peakAltitudeDeg, 48.5);
      expect(periodItem.displayName, 'C49 (Rosette Nebula)');

      final targetItem = periodItem.toTargetItem();
      expect(targetItem.id, 42);
      expect(targetItem.name, 'NGC 2244');
      expect(targetItem.caldwell, 'C49');
      expect(targetItem.commonName, 'Rosette Nebula');
      expect(targetItem.objectType, 'Open Cluster');
      expect(targetItem.constellation, 'Mon');
      expect(targetItem.peakAltitudeDeg, 48.5);
      expect(targetItem.visibleDurationHours, 1.8);
      expect(targetItem.meetsCriteria, isTrue);
    });

    test('PeriodTargetItem with 0 observable days handles ratio safely', () {
      final periodItem = const PeriodTargetItem(
        id: 100,
        name: 'NGC 224',
        messier: 'M31',
        commonName: 'Andromeda Galaxy',
        catalog: 'Messier',
        objectType: 'Galaxy',
        constellation: 'And',
        raHours: 0.71,
        decDegrees: 41.27,
        magnitude: 3.4,
        majorAxisArcmin: 180.0,
        surfaceBrightness: 13.5,
        peakAltitudeDeg: 0.0,
        maxHoursObservable: 0.0,
        peakDate: null,
        observableDaysCount: 0,
        totalPeriodDays: 30,
        startMonth: 9,
        startDay: 1,
        endMonth: 9,
        endDay: 30,
        isObservable: false,
      );

      expect(periodItem.observableDaysCount, 0);
      expect(periodItem.isObservable, isFalse);
      expect(periodItem.peakDate, isNull);

      final targetItem = periodItem.toTargetItem();
      expect(targetItem.meetsCriteria, isFalse);
      expect(targetItem.visibleDurationHours, 0.0);
    });
  });
}

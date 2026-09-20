import 'package:flutter_test/flutter_test.dart';
import 'package:app/controllers/filter_dialog_controller.dart';
import 'package:app/models/filter_state.dart';

void main() {
  group('FilterDialogController Tests', () {
    late FilterState initialFilters;
    late FilterDialogController controller;

    setUp(() {
      initialFilters = FilterState(
        observerLat: 45.0,
        observerLon: 10.0,
        observerElevation: 200.0,
        observerLocationName: 'Observatory',
        date: DateTime(2026, 9, 21),
      );
      controller = FilterDialogController(initialFilters: initialFilters);
    });

    test('initializes with copies of provided filter state', () {
      expect(controller.state.observerLat, 45.0);
      expect(controller.state.observerLon, 10.0);
      expect(controller.state.minAltitude, initialFilters.minAltitude);
      expect(controller.presetIndex, 0); // 0..360 is preset 0
    });

    test('applies directional presets and reflects correct presetIndex', () {
      var listenerTriggered = false;
      controller.addListener(() => listenerTriggered = true);

      // Preset 1: North (315 to 45)
      controller.applyPreset(1);
      expect(listenerTriggered, isTrue);
      expect(controller.state.minAzimuth, 315.0);
      expect(controller.state.maxAzimuth, 45.0);
      expect(controller.presetIndex, 1);

      // Preset 2: East (45 to 135)
      controller.applyPreset(2);
      expect(controller.state.minAzimuth, 45.0);
      expect(controller.state.maxAzimuth, 135.0);
      expect(controller.presetIndex, 2);

      // Preset 3: South (135 to 225)
      controller.applyPreset(3);
      expect(controller.state.minAzimuth, 135.0);
      expect(controller.state.maxAzimuth, 225.0);
      expect(controller.presetIndex, 3);

      // Custom azimuth range: returns preset 9
      controller.setCustomAzimuth(10.0, 80.0);
      expect(controller.presetIndex, 9);
    });

    test('updates altitude, duration, and moon separation filters', () {
      controller.setMinAltitude(35.0);
      expect(controller.state.minAltitude, 35.0);

      controller.setMaxAltitude(80.0);
      expect(controller.state.maxAltitude, 80.0);

      controller.setMinDurationHours(4.5);
      expect(controller.state.minDurationHours, 4.5);

      controller.setMinMoonSeparation(40.0);
      expect(controller.state.minMoonSeparation, 40.0);
    });

    test('manages custom time window and clamps duration', () {
      controller.setMinDurationHours(8.0);

      // Set custom window of 3 hours (21:00 to 00:00)
      controller.setCustomWindow(21, 0, 0, 0);
      expect(controller.state.useCustomTimeWindow, isTrue);
      expect(controller.state.customStartHour, 21);
      expect(controller.state.customEndHour, 0);

      // minDurationHours should be clamped to window duration (3.0 hours)
      expect(controller.state.minDurationHours, lessThanOrEqualTo(3.0));

      // Toggle back to full darkness
      controller.setUseCustomTimeWindow(false);
      expect(controller.state.useCustomTimeWindow, isFalse);
    });

    test('manages catalog selections with minimum 1 guard', () {
      controller.selectAllCatalogs(['Messier', 'NGC', 'IC']);
      expect(controller.state.selectedCatalogs, {'Messier', 'NGC', 'IC'});

      // Toggling off when multiple are selected removes it
      controller.setCatalogSelected('Messier', false);
      expect(controller.state.selectedCatalogs.contains('Messier'), isFalse);

      // Removing until 1 remains
      controller.setCatalogSelected('NGC', false);
      expect(controller.state.selectedCatalogs, {'IC'});

      // Trying to unselect the last one is guarded (keeps at least 1)
      controller.setCatalogSelected('IC', false);
      expect(controller.state.selectedCatalogs, {'IC'});

      // Adding catalog
      controller.setCatalogSelected('Messier', true);
      expect(controller.state.selectedCatalogs.contains('Messier'), isTrue);
    });

    test('manages object type selections with minimum 1 guard', () {
      controller.selectAllObjectTypes(['Galaxy', 'Open Cluster']);
      expect(controller.state.selectedObjectTypes, {'Galaxy', 'Open Cluster'});

      controller.setObjectTypeSelected('Galaxy', false);
      expect(controller.state.selectedObjectTypes, {'Open Cluster'});

      // Last item cannot be removed
      controller.setObjectTypeSelected('Open Cluster', false);
      expect(controller.state.selectedObjectTypes, {'Open Cluster'});
    });

    test('resets filters to defaults preserving observer coordinates', () {
      controller.setMinAltitude(50.0);
      controller.setMaxMagnitude(8.0);
      controller.setMinSizeArcmin(25.0);

      controller.resetToDefaults();

      expect(controller.state.observerLat, 45.0);
      expect(controller.state.observerLon, 10.0);
      expect(controller.state.minAltitude, initialFilters.minAltitude);
      expect(controller.state.maxMagnitude, initialFilters.maxMagnitude);
      expect(controller.state.minSizeArcmin, initialFilters.minSizeArcmin);
    });

    test('calculates cardinal abbreviations in English and Portuguese', () {
      expect(FilterDialogController.cardinalName(0.0), 'N');
      expect(FilterDialogController.cardinalName(45.0), 'NE');
      expect(FilterDialogController.cardinalName(90.0, isPt: false), 'E');
      expect(FilterDialogController.cardinalName(90.0, isPt: true), 'L');
      expect(FilterDialogController.cardinalName(180.0), 'S');
      expect(FilterDialogController.cardinalName(225.0, isPt: false), 'SW');
      expect(FilterDialogController.cardinalName(225.0, isPt: true), 'SO');
      expect(FilterDialogController.cardinalName(270.0, isPt: false), 'W');
      expect(FilterDialogController.cardinalName(270.0, isPt: true), 'O');
      expect(FilterDialogController.cardinalName(315.0, isPt: false), 'NW');
      expect(FilterDialogController.cardinalName(315.0, isPt: true), 'NO');
    });
  });
}

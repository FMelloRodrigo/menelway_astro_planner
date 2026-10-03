import 'package:flutter/material.dart';
import 'observing_sites_dialog.dart';

/// Compatibility wrapper forwarding to [ObservingSitesDialog].
class ObserverLocationDialog extends StatelessWidget {
  final double initialLat;
  final double initialLon;
  final double initialElevation;
  final String initialLocationName;
  final bool isRedNightMode;
  final void Function(double lat, double lon, double elevation, String locationName) onLocationApplied;

  const ObserverLocationDialog({
    super.key,
    required this.initialLat,
    required this.initialLon,
    required this.initialElevation,
    required this.initialLocationName,
    required this.isRedNightMode,
    required this.onLocationApplied,
  });

  @override
  Widget build(BuildContext context) {
    return ObservingSitesDialog(
      isRedNightMode: isRedNightMode,
      onActiveSiteChanged: (site) {
        onLocationApplied(site.latitude, site.longitude, site.elevation, site.name);
      },
    );
  }
}

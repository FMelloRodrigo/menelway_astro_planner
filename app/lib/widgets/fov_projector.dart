import 'dart:math' as math;
import 'package:flutter/material.dart';

class ScaleBarData {
  final double scaleArcmin;
  final double barPixels;
  final String label;
  final double startX;
  final double y;
  final bool isValid;

  const ScaleBarData({
    required this.scaleArcmin,
    required this.barPixels,
    required this.label,
    required this.startX,
    required this.y,
    required this.isValid,
  });
}

/// Pure mathematical coordinate projection and geometry calculator for
/// astronomical fields of view (FOV), target dimensions, sensor framing,
/// and scale rulers. Separates astronomy math from Flutter canvas rendering.
class FovProjector {
  final Size viewportSize;
  final double fovDeg;
  final double panOffsetArcminX;
  final double panOffsetArcminY;

  const FovProjector({
    required this.viewportSize,
    required this.fovDeg,
    this.panOffsetArcminX = 0.0,
    this.panOffsetArcminY = 0.0,
  });

  /// Total field of view in arcminutes.
  double get fovArcmin => fovDeg * 60.0;

  /// Minimum viewport dimension in pixels.
  double get minDim => math.min(viewportSize.width, viewportSize.height);

  /// Number of screen pixels per arcminute of sky.
  double get pixelsPerArcmin {
    final arcmin = fovArcmin;
    if (arcmin <= 0.0) return 1.0;
    return minDim / arcmin;
  }

  /// Geometric center of the preview viewport.
  Offset get viewportCenter => Offset(viewportSize.width / 2, viewportSize.height / 2);

  /// Position of the celestial target center after applying panning offsets.
  Offset get targetCenter {
    return Offset(
      viewportCenter.dx - (panOffsetArcminX * pixelsPerArcmin),
      viewportCenter.dy - (panOffsetArcminY * pixelsPerArcmin),
    );
  }

  /// Computes screen pixel dimensions for a camera sensor rectangle.
  Size calculateSensorPixelSize(double sensorWidthArcmin, double sensorHeightArcmin) {
    return Size(
      sensorWidthArcmin * pixelsPerArcmin,
      sensorHeightArcmin * pixelsPerArcmin,
    );
  }

  /// Computes semi-major and semi-minor radii in pixels for a deep-sky object.
  Size calculateTargetRadii(double? majorArcmin, double? surfaceBrightness) {
    if (majorArcmin == null || majorArcmin <= 0) {
      return Size.zero;
    }
    final minorArcmin = (surfaceBrightness != null) ? majorArcmin * 0.65 : majorArcmin;
    final radX = (majorArcmin / 2.0) * pixelsPerArcmin;
    final radY = (minorArcmin / 2.0) * pixelsPerArcmin;
    return Size(radX, radY);
  }

  /// Calculates astronomical scale bar parameters based on current zoom FOV.
  ScaleBarData calculateScaleBar() {
    double scaleArcmin = 10.0;
    if (fovArcmin < 20.0) {
      scaleArcmin = 5.0;
    } else if (fovArcmin < 50.0) {
      scaleArcmin = 10.0;
    } else if (fovArcmin < 120.0) {
      scaleArcmin = 30.0;
    } else if (fovArcmin < 300.0) {
      scaleArcmin = 60.0;
    } else {
      scaleArcmin = 120.0;
    }

    final barPixels = scaleArcmin * pixelsPerArcmin;
    final isValid = barPixels > 0 && barPixels <= viewportSize.width * 0.7;

    final scaleLabel = scaleArcmin >= 60.0
        ? "${(scaleArcmin / 60.0).toStringAsFixed(0)}°"
        : "${scaleArcmin.toStringAsFixed(0)}'";

    final startX = viewportSize.width * 0.28;
    final y = viewportSize.height - 14.0;

    return ScaleBarData(
      scaleArcmin: scaleArcmin,
      barPixels: barPixels,
      label: scaleLabel,
      startX: startX,
      y: y,
      isValid: isValid,
    );
  }

  /// Formats apparent target dimensions as degrees, arcminutes, or point source.
  static String formatApparentSize(double? majorAxisArcmin) {
    if (majorAxisArcmin != null && majorAxisArcmin > 0) {
      return majorAxisArcmin >= 60.0
          ? "Size: ${(majorAxisArcmin / 60.0).toStringAsFixed(1)}°"
          : "Size: ${majorAxisArcmin.toStringAsFixed(1)}'";
    }
    return "Point Source";
  }
}

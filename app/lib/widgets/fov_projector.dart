import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/target_item.dart';
import 'target_renderers/target_body_renderer.dart';

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

  /// Maximum viewport dimension in pixels.
  double get maxDim => math.max(viewportSize.width, viewportSize.height);

  /// Viewport aspect ratio compensation factor (maxDim / minDim).
  /// Used to ensure photographic cutouts cover the entire rectangular viewport
  /// while maintaining strict 1:1 scale parity with the sensor overlay and vector canvas.
  double get aspectScaleFactor {
    if (minDim <= 0.0) return 1.0;
    return maxDim / minDim;
  }

  /// The effective field of view (in degrees) required for a square sky cutout
  /// to completely cover this rectangular viewport without scaling distortions.
  double get coverageFovDeg => fovDeg * aspectScaleFactor;

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

  /// Computes the precise screen positioning and bounds for a photographic sky
  /// cutout fetched with [imageFovDeg]. Ensures that 1 arcminute in the photograph
  /// occupies exactly [pixelsPerArcmin] screen pixels, completely eliminating
  /// mobile / desktop aspect ratio framing mismatches.
  Rect calculateImageRect({
    required double imageFovDeg,
    double imageBasePanX = 0.0,
    double imageBasePanY = 0.0,
  }) {
    final effectiveImageFov = (imageFovDeg > 0.0) ? imageFovDeg : fovDeg;
    final imageSidePixels = (effectiveImageFov * 60.0) * pixelsPerArcmin;
    final shiftX = -(panOffsetArcminX - imageBasePanX) * pixelsPerArcmin;
    final shiftY = -(panOffsetArcminY - imageBasePanY) * pixelsPerArcmin;
    final left = (viewportSize.width - imageSidePixels) / 2.0 + shiftX;
    final top = (viewportSize.height - imageSidePixels) / 2.0 + shiftY;
    return Rect.fromLTWH(left, top, imageSidePixels, imageSidePixels);
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

  /// Formats apparent target dimensions as degrees, arcminutes, or arcseconds.
  static String formatApparentSize(double? majorAxisArcmin) {
    if (majorAxisArcmin != null && majorAxisArcmin > 0) {
      if (majorAxisArcmin >= 60.0) {
        return "Size: ${(majorAxisArcmin / 60.0).toStringAsFixed(1)}°";
      } else if (majorAxisArcmin >= 1.0) {
        return "Size: ${majorAxisArcmin.toStringAsFixed(1)}'";
      } else {
        return "Size: ${(majorAxisArcmin * 60.0).toStringAsFixed(1)}\"";
      }
    }
    return "Point Source";
  }

  /// Checks whether a celestial target's physical screen radius falls below the
  /// minimum visibility threshold on the current FOV, requiring a visibility clamp.
  bool isTargetSubpixelClamped(TargetItem target) {
    final lowerType = target.objectType.toLowerCase();
    final isPlanet = target.catalog == 'Solar System' ||
        (lowerType.contains('planet') && !lowerType.contains('planetary'));
    if (!isPlanet) return false;
    if (target.name == 'Sun' || target.name == 'Moon') return false;

    final majorArcmin = target.majorAxisArcmin;
    if (majorArcmin == null || majorArcmin <= 0) return true;
    final unconstrainedRadius = (majorArcmin / 2.0) * pixelsPerArcmin;
    return unconstrainedRadius < TargetBodyRenderer.minPlanetRadiusPixels;
  }
}

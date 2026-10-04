import 'package:flutter/material.dart';

import '../fov_projector.dart';
import '../../models/target_item.dart';
import 'deep_sky_body_renderer.dart';
import 'planet_body_renderer.dart';
import 'star_body_renderer.dart';

/// Strategy interface for rendering celestial body vectors on the canvas.
abstract class TargetBodyRenderer {
  const TargetBodyRenderer();

  /// Minimum clamped planet radius in pixels to ensure visibility on wide FOVs.
  static const double minPlanetRadiusPixels = 9.0;

  /// Maximum clamped planet radius in pixels.
  static const double maxPlanetRadiusPixels = 140.0;

  /// Renders the celestial body apparent physical dimensions and features on [canvas].
  void render(
    Canvas canvas, {
    required TargetItem target,
    required FovProjector projector,
    required Size radii,
    required bool isRedNightMode,
    required bool isVectorOnly,
    required Color primaryColor,
    required Color secondaryColor,
    required Color goldColor,
  });

  /// Factory strategy selector determining the appropriate renderer for [target].
  static TargetBodyRenderer selectRenderer(TargetItem target) {
    final lowerType = target.objectType.toLowerCase();
    final isPlanet = target.catalog == 'Solar System' ||
        (lowerType.contains('planet') && !lowerType.contains('planetary'));
    if (isPlanet) return const PlanetBodyRenderer();

    final isStar = lowerType.contains('star') && !lowerType.contains('cluster');
    if (isStar) return const StarBodyRenderer();

    return const DeepSkyBodyRenderer();
  }
}

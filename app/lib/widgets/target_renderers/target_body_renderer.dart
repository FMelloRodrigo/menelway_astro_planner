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

  /// Returns whether this renderer strategy can handle the given [target].
  bool canRender(TargetItem target);

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

  /// Extensible strategy registry. Checked in order from first to last.
  static final List<TargetBodyRenderer> _registry = [
    const PlanetBodyRenderer(),
    const StarBodyRenderer(),
    const DeepSkyBodyRenderer(),
  ];

  /// Register an additional renderer with precedence over built-in defaults.
  static void registerRenderer(TargetBodyRenderer renderer) {
    _registry.insert(0, renderer);
  }

  /// Strategy selector determining the appropriate renderer for [target] via registry inspection.
  static TargetBodyRenderer selectRenderer(TargetItem target) {
    for (final renderer in _registry) {
      if (renderer.canRender(target)) {
        return renderer;
      }
    }
    return const DeepSkyBodyRenderer();
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../fov_projector.dart';
import '../../models/target_item.dart';
import '../../theme/astro_theme.dart';
import 'target_body_renderer.dart';

/// Renders Deep Sky Objects (Galaxies, Planetary Nebulae, Star Clusters, Diffuse Nebulae).
class DeepSkyBodyRenderer extends TargetBodyRenderer {
  const DeepSkyBodyRenderer();

  @override
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
  }) {
    final targetCenter = projector.targetCenter;
    final lowerType = target.objectType.toLowerCase();

    if (radii == Size.zero) {
      final pointPaint = Paint()
        ..color = goldColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(targetCenter, 6.0, pointPaint);
      return;
    }

    final radX = radii.width;
    final radY = radii.height;

    canvas.save();
    canvas.translate(targetCenter.dx, targetCenter.dy);
    final paRad = target.positionAngleDeg != null
        ? (target.positionAngleDeg! * math.pi / 180.0)
        : (math.pi / 5.0);
    canvas.rotate(paRad);

    if (lowerType.contains('galaxy')) {
      _renderGalaxy(canvas, radX, radY, primaryColor, goldColor, isRedNightMode, isVectorOnly);
    } else if (lowerType.contains('planetary')) {
      _renderPlanetaryNebula(canvas, radX, isRedNightMode);
    } else if (lowerType.contains('globular')) {
      _renderGlobularCluster(canvas, radX, primaryColor, goldColor, isRedNightMode);
    } else if (lowerType.contains('open cluster') || lowerType.contains('cluster')) {
      _renderOpenCluster(canvas, radX, target.id, goldColor, isRedNightMode);
    } else {
      _renderDiffuseNebula(canvas, radX, radY, primaryColor, secondaryColor, isVectorOnly);
    }

    canvas.restore();
  }

  void _renderGalaxy(
    Canvas canvas,
    double radX,
    double radY,
    Color primaryColor,
    Color goldColor,
    bool isRedNightMode,
    bool isVectorOnly,
  ) {
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: isVectorOnly ? 0.45 : 0.25),
          primaryColor.withValues(alpha: 0.0),
        ],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: radX * 2.2, height: radY * 2.2));
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radX * 2.0, height: radY * 2.0), haloPaint);

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isRedNightMode ? Colors.white : goldColor).withValues(alpha: 0.9),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: radX * 0.4, height: radY * 0.4));
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radX * 0.4, height: radY * 0.4), corePaint);

    final outlinePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radX * 2.0, height: radY * 2.0), outlinePaint);
  }

  void _renderPlanetaryNebula(Canvas canvas, double radX, bool isRedNightMode) {
    final ringPaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.deepSkyTeal).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, radX * 0.25);
    canvas.drawCircle(Offset.zero, radX, ringPaint);

    final dwarfPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 1.8, dwarfPaint);
  }

  void _renderGlobularCluster(Canvas canvas, double radX, Color primaryColor, Color goldColor, bool isRedNightMode) {
    final globPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isRedNightMode ? AstroColors.nightVisionRed : Colors.white).withValues(alpha: 0.85),
          goldColor.withValues(alpha: 0.4),
          primaryColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radX));
    canvas.drawCircle(Offset.zero, radX, globPaint);

    final globBorder = Paint()
      ..color = goldColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset.zero, radX, globBorder);
  }

  void _renderOpenCluster(Canvas canvas, double radX, int targetId, Color goldColor, bool isRedNightMode) {
    final clusterBorder = Paint()
      ..color = goldColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset.zero, radX, clusterBorder);

    final starP = Paint()..style = PaintingStyle.fill;
    final cRand = math.Random(targetId * 7);
    for (var i = 0; i < 18; i++) {
      final r = math.sqrt(cRand.nextDouble()) * radX * 0.9;
      final th = cRand.nextDouble() * 2 * math.pi;
      starP.color = (isRedNightMode ? AstroColors.nightVisionRed : Colors.white).withValues(alpha: 0.85);
      canvas.drawCircle(Offset(r * math.cos(th), r * math.sin(th)), 1.2, starP);
    }
  }

  void _renderDiffuseNebula(
    Canvas canvas,
    double radX,
    double radY,
    Color primaryColor,
    Color secondaryColor,
    bool isVectorOnly,
  ) {
    final nebPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          secondaryColor.withValues(alpha: isVectorOnly ? 0.5 : 0.3),
          primaryColor.withValues(alpha: isVectorOnly ? 0.25 : 0.12),
          primaryColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: radX * 2.2, height: radY * 2.2));
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radX * 2.0, height: radY * 2.0), nebPaint);

    final outlinePaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radX * 2.0, height: radY * 2.0), outlinePaint);
  }
}

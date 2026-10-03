import 'package:flutter/material.dart';

import '../fov_projector.dart';
import '../../models/target_item.dart';
import '../../theme/astro_theme.dart';
import 'target_body_renderer.dart';

/// Renders stellar objects with soft stellar halo, optical diffraction spikes, and core brilliance.
class StarBodyRenderer extends TargetBodyRenderer {
  const StarBodyRenderer();

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
    final mag = target.magnitude ?? 2.0;
    final coreR = (4.0 - (mag * 0.35)).clamp(2.5, 6.0);
    final spikeLen = (32.0 - (mag * 2.8)).clamp(12.0, 42.0);

    canvas.save();
    canvas.translate(targetCenter.dx, targetCenter.dy);

    // 1. Soft stellar halo glow
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isRedNightMode ? AstroColors.nightVisionRed : goldColor).withValues(alpha: 0.55),
          (isRedNightMode ? AstroColors.nightVisionRed : primaryColor).withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: spikeLen * 0.9));
    canvas.drawCircle(Offset.zero, spikeLen * 0.9, haloPaint);

    // 2. 4-point Diffraction Cross (Telescope Spider Spikes)
    final spikePaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : Colors.white).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawLine(Offset(-spikeLen, 0), Offset(spikeLen, 0), spikePaint);
    canvas.drawLine(Offset(0, -spikeLen), Offset(0, spikeLen), spikePaint);

    // Diagonal soft micro-spikes for 1st magnitude stars
    if (mag < 1.5) {
      final diagLen = spikeLen * 0.45;
      final diagPaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRed : goldColor).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawLine(Offset(-diagLen, -diagLen), Offset(diagLen, diagLen), diagPaint);
      canvas.drawLine(Offset(-diagLen, diagLen), Offset(diagLen, -diagLen), diagPaint);
    }

    // 3. Central Brilliant White Star Core
    final corePaint = Paint()
      ..color = isRedNightMode ? AstroColors.nightVisionRed : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, coreR, corePaint);

    // 4. Secondary companion for double stars
    if (lowerType.contains('double')) {
      final compOffset = Offset(coreR * 3.2, -coreR * 2.2);
      final compSpike = spikeLen * 0.5;
      canvas.drawLine(compOffset + Offset(-compSpike, 0), compOffset + Offset(compSpike, 0), spikePaint);
      canvas.drawLine(compOffset + Offset(0, -compSpike), compOffset + Offset(0, compSpike), spikePaint);
      canvas.drawCircle(compOffset, coreR * 0.65, corePaint);
    }

    canvas.restore();
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../fov_projector.dart';
import '../../models/target_item.dart';
import '../../theme/astro_theme.dart';
import 'target_body_renderer.dart';

/// Renders Solar System bodies with physically inspired features (Saturn's rings, Jupiter's belts, etc.).
class PlanetBodyRenderer extends TargetBodyRenderer {
  const PlanetBodyRenderer();

  @override
  bool canRender(TargetItem target) {
    final lowerType = target.objectType.toLowerCase();
    return target.catalog == 'Solar System' ||
        (lowerType.contains('planet') && !lowerType.contains('planetary'));
  }

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
    final radPixels = radii.width > 0 ? radii.width : 14.0;
    final planetR = radPixels.clamp(
      TargetBodyRenderer.minPlanetRadiusPixels,
      TargetBodyRenderer.maxPlanetRadiusPixels,
    );
    final targetCenter = projector.targetCenter;

    canvas.save();
    canvas.translate(targetCenter.dx, targetCenter.dy);

    final pName = target.name;
    if (pName == 'Saturn') {
      _renderSaturn(canvas, planetR, isRedNightMode);
    } else if (pName == 'Jupiter') {
      _renderJupiter(canvas, planetR, isRedNightMode);
    } else if (pName == 'Mars') {
      _renderMars(canvas, planetR, isRedNightMode);
    } else if (pName == 'Moon') {
      _renderMoon(canvas, planetR, isRedNightMode);
    } else if (pName == 'Sun') {
      _renderSun(canvas, planetR, isRedNightMode);
    } else if (pName == 'Venus') {
      _renderVenus(canvas, planetR, isRedNightMode);
    } else if (pName == 'Uranus') {
      _renderUranus(canvas, planetR, isRedNightMode);
    } else if (pName == 'Neptune') {
      _renderNeptune(canvas, planetR, isRedNightMode);
    } else {
      _renderGenericPlanet(canvas, planetR, isRedNightMode);
    }

    // Precision outline ring
    final borderPaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : primaryColor).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset.zero, planetR, borderPaint);

    canvas.restore();
  }

  void _renderSaturn(Canvas canvas, double planetR, bool isRedNightMode) {
    final ringAngle = -26.0 * math.pi / 180.0;
    final ringOuterW = planetR * 4.6;
    final ringOuterH = planetR * 1.7;
    final ringInnerW = planetR * 2.8;
    final ringInnerH = planetR * 1.05;

    // 1. Back half of rings: clip to top half (y <= 0)
    canvas.save();
    canvas.rotate(ringAngle);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-ringOuterW, -ringOuterH, ringOuterW, 0));
    final ringBackPaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : const Color(0xFFD4B26F)).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (ringOuterH - ringInnerH) * 0.45;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: (ringOuterW + ringInnerW) / 2, height: (ringOuterH + ringInnerH) / 2),
      ringBackPaint,
    );
    canvas.restore();
    canvas.restore();

    // 2. Planet Sphere
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.9,
        colors: isRedNightMode
            ? [AstroColors.nightVisionRed, const Color(0xFF350A0A)]
            : [const Color(0xFFF3E5AB), const Color(0xFFC29B38), const Color(0xFF785E23)],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
    canvas.drawCircle(Offset.zero, planetR, bodyPaint);

    // Subtle Saturn atmospheric belt
    final beltPaint = Paint()
      ..color = (isRedNightMode ? Colors.black : const Color(0xFF8B6B23)).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = planetR * 0.22;
    canvas.drawArc(Rect.fromCenter(center: Offset.zero, width: planetR * 2, height: planetR * 0.8), -0.2, 3.5, false, beltPaint);

    // 3. Front half of rings: clip to bottom half (y > 0)
    canvas.save();
    canvas.rotate(ringAngle);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-ringOuterW, 0, ringOuterW, ringOuterH));
    final ringFrontPaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : const Color(0xFFE2C485)).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (ringOuterH - ringInnerH) * 0.45;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: (ringOuterW + ringInnerW) / 2, height: (ringOuterH + ringInnerH) / 2),
      ringFrontPaint,
    );
    // Cassini division gap line
    final cassiniPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: ringOuterW * 0.84, height: ringOuterH * 0.84), cassiniPaint);
    canvas.restore();
    canvas.restore();
  }

  void _renderJupiter(Canvas canvas, double planetR, bool isRedNightMode) {
    final jupPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
        colors: isRedNightMode
            ? [AstroColors.nightVisionRed, const Color(0xFF380808)]
            : [const Color(0xFFFFF8E7), const Color(0xFFE0B984), const Color(0xFF9E6B38)],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
    canvas.drawCircle(Offset.zero, planetR, jupPaint);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: planetR)));

    final beltColor = (isRedNightMode ? Colors.black : const Color(0xFF8B4513)).withValues(alpha: 0.45);
    final beltPaint = Paint()
      ..color = beltColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(-planetR, -planetR * 0.38, planetR, -planetR * 0.12), beltPaint);
    canvas.drawRect(Rect.fromLTRB(-planetR, planetR * 0.12, planetR, planetR * 0.38), beltPaint);

    final faintBelt = Paint()
      ..color = beltColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(-planetR, planetR * 0.52, planetR, planetR * 0.65), faintBelt);
    canvas.drawRect(Rect.fromLTRB(-planetR, -planetR * 0.65, planetR, -planetR * 0.52), faintBelt);

    // Great Red Spot
    final grsPaint = Paint()
      ..color = (isRedNightMode ? Colors.white : const Color(0xFFCC4422)).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: Offset(planetR * 0.35, planetR * 0.25), width: planetR * 0.4, height: planetR * 0.22), grsPaint);

    canvas.restore();
  }

  void _renderMars(Canvas canvas, double planetR, bool isRedNightMode) {
    final marsPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.85,
        colors: isRedNightMode
            ? [AstroColors.nightVisionRed, const Color(0xFF400A0A)]
            : [const Color(0xFFFF7A45), const Color(0xFFC84B20), const Color(0xFF6B1D0B)],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
    canvas.drawCircle(Offset.zero, planetR, marsPaint);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: planetR)));
    final capPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -planetR * 0.82), width: planetR * 0.7, height: planetR * 0.3), capPaint);
    canvas.restore();
  }

  void _renderMoon(Canvas canvas, double planetR, bool isRedNightMode) {
    final moonPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
        colors: isRedNightMode
            ? [AstroColors.nightVisionRed, const Color(0xFF300808)]
            : [const Color(0xFFF0F2F5), const Color(0xFFB0B4BC), const Color(0xFF4A4E57)],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
    canvas.drawCircle(Offset.zero, planetR, moonPaint);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: planetR)));
    final mariaPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(-planetR * 0.28, -planetR * 0.25), planetR * 0.32, mariaPaint);
    canvas.drawCircle(Offset(planetR * 0.22, -planetR * 0.15), planetR * 0.25, mariaPaint);
    canvas.drawCircle(Offset(planetR * 0.15, planetR * 0.3), planetR * 0.28, mariaPaint);
    canvas.restore();
  }

  void _renderSun(Canvas canvas, double planetR, bool isRedNightMode) {
    final coronaPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isRedNightMode ? AstroColors.nightVisionRed : const Color(0xFFFFB300)).withValues(alpha: 0.35),
          (isRedNightMode ? AstroColors.nightVisionRed : const Color(0xFFFF6D00)).withValues(alpha: 0.1),
          Colors.transparent,
        ],
        stops: const [0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR * 1.6));
    canvas.drawCircle(Offset.zero, planetR * 1.6, coronaPaint);

    final sunPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: isRedNightMode
            ? [Colors.white, AstroColors.nightVisionRed]
            : [const Color(0xFFFFFFE0), const Color(0xFFFFD700), const Color(0xFFFF8C00)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
    canvas.drawCircle(Offset.zero, planetR, sunPaint);
  }

  void _renderVenus(Canvas canvas, double planetR, bool isRedNightMode) {
    final venusPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.85,
        colors: isRedNightMode
            ? [AstroColors.nightVisionRed, const Color(0xFF350A0A)]
            : [const Color(0xFFFFFDF5), const Color(0xFFEADBBE), const Color(0xFF9E8E72)],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
    canvas.drawCircle(Offset.zero, planetR, venusPaint);
  }

  void _renderUranus(Canvas canvas, double planetR, bool isRedNightMode) {
    final uranusPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.85,
        colors: isRedNightMode
            ? [AstroColors.nightVisionRed, const Color(0xFF280808)]
            : [const Color(0xFFD6F9FA), const Color(0xFF7CE4EC), const Color(0xFF2C7D88)],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
    canvas.drawCircle(Offset.zero, planetR, uranusPaint);
  }

  void _renderNeptune(Canvas canvas, double planetR, bool isRedNightMode) {
    final nepPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.85,
        colors: isRedNightMode
            ? [AstroColors.nightVisionRed, const Color(0xFF200505)]
            : [const Color(0xFF8AB8FD), const Color(0xFF386FE0), const Color(0xFF142B75)],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
    canvas.drawCircle(Offset.zero, planetR, nepPaint);
  }

  void _renderGenericPlanet(Canvas canvas, double planetR, bool isRedNightMode) {
    final defPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.85,
        colors: isRedNightMode
            ? [AstroColors.nightVisionRed, const Color(0xFF200505)]
            : [const Color(0xFFD8D8D8), const Color(0xFF8A8A8A), const Color(0xFF3B3B3B)],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
    canvas.drawCircle(Offset.zero, planetR, defPaint);
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../models/filter_state.dart';
import '../../models/terrain_profile_model.dart';
import '../../theme/astro_theme.dart';

class HorizonChartPainter extends CustomPainter {
  final List<HorizonPointModel> points;
  final int? selectedIndex;
  final int? draggedIndex;
  final Offset? hoverPos;
  final bool isRedNightMode;
  final double minAzimuth;
  final double maxAzimuth;
  final double minAltitude;
  final double maxAltitude;
  final ui.Image? decodedImage;
  final double azimuthOffset;
  final double altitudeOffset;
  final double altitudeScale;
  final double imageOpacity;
  final TerrainProfileModel? terrainProfile;
  final bool showTerrainSilhouette;
  final bool showPoints;
  final double zoomLevel;
  final double viewStartAzimuth;

  HorizonChartPainter({
    required this.points,
    required this.selectedIndex,
    required this.draggedIndex,
    required this.hoverPos,
    required this.isRedNightMode,
    required this.minAzimuth,
    required this.maxAzimuth,
    required this.minAltitude,
    required this.maxAltitude,
    required this.decodedImage,
    required this.azimuthOffset,
    required this.altitudeOffset,
    required this.altitudeScale,
    required this.imageOpacity,
    this.terrainProfile,
    this.showTerrainSilhouette = true,
    this.showPoints = true,
    this.zoomLevel = 1.0,
    this.viewStartAzimuth = 0.0,
  });

  static const double leftMargin = 40.0;
  static const double rightMargin = 16.0;
  static const double topMargin = 18.0;
  static const double bottomMargin = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      leftMargin,
      topMargin,
      math.max(10.0, size.width - leftMargin - rightMargin),
      math.max(10.0, size.height - topMargin - bottomMargin),
    );

    final visibleAzSpan = 360.0 / zoomLevel;
    double azToX(double az) => r.left + ((az - viewStartAzimuth) / visibleAzSpan) * r.width;
    double altToY(double alt) => r.bottom - (alt / 90.0) * r.height;

    // 1. Draw Panorama Image Backdrop (wrapped cyclically across 360°)
    if (decodedImage != null) {
      canvas.save();
      canvas.clipRect(r);

      final imgW = decodedImage!.width.toDouble();
      final imgH = decodedImage!.height.toDouble();

      final paintImg = Paint()
        ..color = Colors.white.withValues(alpha: imageOpacity.clamp(0.05, 1.0))
        ..filterQuality = FilterQuality.medium;

      // Base vertical destination
      final baseAltY = altToY(altitudeOffset);
      final destH = r.height * altitudeScale;
      final destY = baseAltY - destH;

      // Full 360 cycle width at current zoom
      final fullCycleWidth = r.width * zoomLevel;
      final startX = azToX(0.0) - (azimuthOffset / 360.0) * fullCycleWidth;

      final srcRect = Rect.fromLTWH(0, 0, imgW, imgH);

      final minTile = ((r.left - startX) / fullCycleWidth).floor() - 1;
      final maxTile = ((r.right - startX) / fullCycleWidth).ceil() + 1;

      for (int t = minTile; t <= maxTile; t++) {
        final dest = Rect.fromLTWH(startX + t * fullCycleWidth, destY, fullCycleWidth, destH);
        canvas.drawImageRect(decodedImage!, srcRect, dest, paintImg);
      }

      canvas.restore();
    }

    // 1.5. Draw Mountain Silhouette Backdrop (Vector Topography)
    if (showTerrainSilhouette && terrainProfile != null && terrainProfile!.altitudes.isNotEmpty) {
      _drawMountainSilhouette(canvas, r, azToX, altToY);
    }

    // 2. Active Azimuth Corridor Shading (Visual Conjunction with Azimuth Range Filter)
    _drawAzimuthCorridor(canvas, r, azToX);

    // 3. Grid Lines & Axis Markers
    _drawGridLines(canvas, r, azToX, altToY);

    // 4. Min & Max Altitude Threshold Lines
    _drawAltitudeThresholds(canvas, r, altToY);

    // 5. Obstacle Silhouette & Shaded Obstruction Fill
    _drawObstacleMask(canvas, r, azToX, altToY);

    // 6. Point Handles and Interactive Highlights
    _drawPointHandles(canvas, r, azToX, altToY);
  }

  void _drawMountainSilhouette(
    Canvas canvas,
    Rect r,
    double Function(double) azToX,
    double Function(double) altToY,
  ) {
    if (terrainProfile == null || terrainProfile!.altitudes.isEmpty) return;

    canvas.save();
    canvas.clipRect(r);

    final path = Path();
    final fillPath = Path();

    final n = terrainProfile!.altitudes.length;
    final step = terrainProfile!.stepDeg;

    final firstAlt = terrainProfile!.altitudes[0];
    final lastAlt = terrainProfile!.altitudes.first;

    path.moveTo(azToX(0.0), altToY(firstAlt));
    fillPath.moveTo(azToX(0.0), r.bottom);
    fillPath.lineTo(azToX(0.0), altToY(firstAlt));

    for (int i = 0; i < n; i++) {
      final az = i * step;
      final alt = terrainProfile!.altitudes[i];
      final px = azToX(az);
      final py = altToY(alt);
      path.lineTo(px, py);
      fillPath.lineTo(px, py);
    }

    path.lineTo(azToX(360.0), altToY(lastAlt));
    fillPath.lineTo(azToX(360.0), altToY(lastAlt));
    fillPath.lineTo(azToX(360.0), r.bottom);
    fillPath.close();

    // Twilight mountain gradient fill (dark midnight slate into mountain ridge)
    final fillGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: isRedNightMode
          ? [
              const Color(0xFF140303).withValues(alpha: 0.95),
              const Color(0xFF2E0808).withValues(alpha: 0.90),
            ]
          : [
              const Color(0xFF070E1A).withValues(alpha: 0.95),
              const Color(0xFF16253B).withValues(alpha: 0.90),
            ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(r)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Mountain ridge highlight stroke
    final strokePaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.70)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    canvas.restore();
  }

  void _drawAzimuthCorridor(Canvas canvas, Rect r, double Function(double) azToX) {
    final hasAzLimit = !(minAzimuth == 0.0 && maxAzimuth == 360.0);
    if (!hasAzLimit) return;

    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.52)
      ..style = PaintingStyle.fill;

    final boundLinePaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRedDim : AstroColors.starlightCyan).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRect(r);

    if (minAzimuth <= maxAzimuth) {
      // Out of range: 0 -> minAzimuth and maxAzimuth -> 360
      final xMin = azToX(minAzimuth);
      final xMax = azToX(maxAzimuth);

      if (minAzimuth > 0) {
        canvas.drawRect(Rect.fromLTRB(azToX(0.0), r.top, xMin, r.bottom), dimPaint);
        canvas.drawLine(Offset(xMin, r.top), Offset(xMin, r.bottom), boundLinePaint);
      }
      if (maxAzimuth < 360) {
        canvas.drawRect(Rect.fromLTRB(xMax, r.top, azToX(360.0), r.bottom), dimPaint);
        canvas.drawLine(Offset(xMax, r.top), Offset(xMax, r.bottom), boundLinePaint);
      }
    } else {
      // Wraps across 360/0: out of range is maxAzimuth -> minAzimuth
      final xMax = azToX(maxAzimuth);
      final xMin = azToX(minAzimuth);
      canvas.drawRect(Rect.fromLTRB(xMax, r.top, xMin, r.bottom), dimPaint);
      canvas.drawLine(Offset(xMax, r.top), Offset(xMax, r.bottom), boundLinePaint);
      canvas.drawLine(Offset(xMin, r.top), Offset(xMin, r.bottom), boundLinePaint);
    }

    canvas.restore();
  }

  void _drawGridLines(
    Canvas canvas,
    Rect r,
    double Function(double) azToX,
    double Function(double) altToY,
  ) {
    final gridPaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionBorder.withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1.0;

    final axisLabelStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white60,
      fontSize: 9,
      fontFamily: 'monospace',
    );

    final cardinalLabelStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    // Altitude horizontal grid (0°, 15°, 30°, 45°, 60°, 75°, 90°)
    for (double alt = 0; alt <= 90; alt += 15) {
      final y = altToY(alt);
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(text: "${alt.toInt()}°", style: axisLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(r.left - tp.width - 4, y - tp.height / 2));
    }

    // Determine grid step based on zoomLevel
    final double azStep;
    if (zoomLevel >= 4.5) {
      azStep = 5.0;
    } else if (zoomLevel >= 2.2) {
      azStep = 15.0;
    } else {
      azStep = 45.0;
    }

    final visibleAzSpan = 360.0 / zoomLevel;
    final firstAz = (viewStartAzimuth / azStep).floor() * azStep;
    final lastAz = ((viewStartAzimuth + visibleAzSpan) / azStep).ceil() * azStep;

    for (double az = firstAz; az <= lastAz; az += azStep) {
      final x = azToX(az);
      if (x < r.left - 1 || x > r.right + 1) continue;

      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), gridPaint);

      // Check cardinal label
      final cardinal = _cardinalForAz(az);
      if (cardinal != null) {
        final tpCard = TextPainter(
          text: TextSpan(text: cardinal, style: cardinalLabelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tpCard.paint(canvas, Offset(x - tpCard.width / 2, r.bottom + 4));
      }

      // Degree label
      final tpDeg = TextPainter(
        text: TextSpan(text: "${az.round()}°", style: axisLabelStyle.copyWith(fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tpDeg.paint(canvas, Offset(x - tpDeg.width / 2, r.bottom + 16));
    }
  }

  String? _cardinalForAz(double az) {
    final a = (az.round() % 360 + 360) % 360;
    switch (a) {
      case 0:
        return "N";
      case 45:
        return "NE";
      case 90:
        return "E";
      case 135:
        return "SE";
      case 180:
        return "S";
      case 225:
        return "SW";
      case 270:
        return "W";
      case 315:
        return "NW";
      default:
        return null;
    }
  }

  void _drawAltitudeThresholds(
    Canvas canvas,
    Rect r,
    double Function(double) altToY,
  ) {
    // Min Altitude dashed guide
    final yMin = altToY(minAltitude);
    final minPaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRedDim : AstroColors.starGold).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, Offset(r.left, yMin), Offset(r.right, yMin), minPaint);

    final tpMin = TextPainter(
      text: TextSpan(
        text: "MIN ALT: ${minAltitude.toInt()}°",
        style: TextStyle(
          color: isRedNightMode ? AstroColors.nightVisionRedDim : AstroColors.starGold,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpMin.paint(canvas, Offset(r.right - tpMin.width - 6, yMin - tpMin.height - 2));

    // Max Altitude dashed guide (if < 90°)
    if (maxAltitude < 90.0) {
      final yMax = altToY(maxAltitude);
      final maxPaint = Paint()
        ..color = Colors.amberAccent.withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, Offset(r.left, yMax), Offset(r.right, yMax), maxPaint);

      final tpMax = TextPainter(
        text: TextSpan(
          text: "MAX ALT: ${maxAltitude.toInt()}°",
          style: const TextStyle(
            color: Colors.amberAccent,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpMax.paint(canvas, Offset(r.right - tpMax.width - 6, yMax + 2));
    }
  }

  void _drawObstacleMask(
    Canvas canvas,
    Rect r,
    double Function(double) azToX,
    double Function(double) altToY,
  ) {
    if (points.isEmpty) return;

    canvas.save();
    canvas.clipRect(r);

    final path = Path();
    final fillPath = Path();

    // Compute altitude at 0° and 360° via interpolation
    final altAt0 = _interpolatedAlt(0.0);
    final altAt360 = _interpolatedAlt(360.0);

    path.moveTo(azToX(0.0), altToY(altAt0));
    fillPath.moveTo(azToX(0.0), r.bottom);
    fillPath.lineTo(azToX(0.0), altToY(altAt0));

    for (final p in points) {
      final px = azToX(p.azimuth);
      final py = altToY(p.altitude);
      path.lineTo(px, py);
      fillPath.lineTo(px, py);
    }

    path.lineTo(azToX(360.0), altToY(altAt360));
    fillPath.lineTo(azToX(360.0), altToY(altAt360));
    fillPath.lineTo(azToX(360.0), r.bottom);
    fillPath.close();

    // Fill underneath horizon line (Obstructed area)
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isRedNightMode
          ? [
              AstroColors.nightVisionRed.withValues(alpha: 0.40),
              AstroColors.nightVisionRed.withValues(alpha: 0.15),
            ]
          : [
              Colors.redAccent.withValues(alpha: 0.35),
              Colors.brown.withValues(alpha: 0.20),
            ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(r)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Horizon outline stroke
    final strokePaint = Paint()
      ..color = isRedNightMode ? AstroColors.nightVisionRed : Colors.redAccent
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    canvas.restore();
  }

  void _drawPointHandles(
    Canvas canvas,
    Rect r,
    double Function(double) azToX,
    double Function(double) altToY,
  ) {
    final accentColor = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isSelected = selectedIndex == i;
      final isDragging = draggedIndex == i;

      // If point visibility is toggled off, only draw the currently selected/dragged point
      if (!showPoints && !isSelected && !isDragging) {
        continue;
      }

      final px = azToX(p.azimuth);
      final py = altToY(p.altitude);

      // Skip drawing if outside chart bounds with margin
      if (px < r.left - 30 || px > r.right + 30) continue;

      // Outer Selection / Dragging Ring
      if (isSelected || isDragging) {
        final ringPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), 16.0, ringPaint);

        final ringStroke = Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(px, py), 10.0, ringStroke);
      }

      // Inner Point Disc
      final dotPaint = Paint()
        ..color = isSelected ? Colors.white : (isRedNightMode ? AstroColors.nightVisionRed : Colors.amberAccent)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), isSelected ? 5.5 : 4.5, dotPaint);

      final dotBorder = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(Offset(px, py), isSelected ? 5.5 : 4.5, dotBorder);

      // Tooltip tag if selected
      if (isSelected) {
        final tagText = "${p.azimuth.round()}°, ${p.altitude.round()}°";
        final tpTag = TextPainter(
          text: TextSpan(
            text: tagText,
            style: const TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final tagRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(px - tpTag.width / 2 - 4, py - tpTag.height - 10, tpTag.width + 8, tpTag.height + 4),
          const Radius.circular(4),
        );
        final tagBg = Paint()..color = Colors.black87;
        canvas.drawRRect(tagRect, tagBg);
        tpTag.paint(canvas, Offset(px - tpTag.width / 2, py - tpTag.height - 8));
      }
    }
  }

  double _interpolatedAlt(double az) {
    if (points.isEmpty) return 0.0;
    if (points.length == 1) return points.first.altitude;

    // Linear interpolation with cyclic 360 wrap
    double normAz = (az % 360.0 + 360.0) % 360.0;

    for (int i = 0; i < points.length; i++) {
      if (normAz < points[i].azimuth) {
        if (i == 0) {
          // between last and first
          final pPrev = points.last;
          final pNext = points.first;
          final span = (pNext.azimuth + 360.0) - pPrev.azimuth;
          final frac = (normAz + 360.0 - pPrev.azimuth) / span;
          return pPrev.altitude + frac * (pNext.altitude - pPrev.altitude);
        } else {
          final pPrev = points[i - 1];
          final pNext = points[i];
          final span = pNext.azimuth - pPrev.azimuth;
          final frac = (normAz - pPrev.azimuth) / span;
          return pPrev.altitude + frac * (pNext.altitude - pPrev.altitude);
        }
      }
    }

    // Between last point and first point
    final pPrev = points.last;
    final pNext = points.first;
    final span = (pNext.azimuth + 360.0) - pPrev.azimuth;
    final frac = (normAz - pPrev.azimuth) / span;
    return pPrev.altitude + frac * (pNext.altitude - pPrev.altitude);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final count = (distance / (dashWidth + dashSpace)).floor();
    final nx = dx / distance;
    final ny = dy / distance;

    for (int i = 0; i < count; i++) {
      final start = Offset(p1.dx + nx * (i * (dashWidth + dashSpace)), p1.dy + ny * (i * (dashWidth + dashSpace)));
      final end = Offset(start.dx + nx * dashWidth, start.dy + ny * dashWidth);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HorizonChartPainter old) {
    return old.points != points ||
        old.selectedIndex != selectedIndex ||
        old.draggedIndex != draggedIndex ||
        old.hoverPos != hoverPos ||
        old.isRedNightMode != isRedNightMode ||
        old.minAzimuth != minAzimuth ||
        old.maxAzimuth != maxAzimuth ||
        old.minAltitude != minAltitude ||
        old.maxAltitude != maxAltitude ||
        old.decodedImage != decodedImage ||
        old.azimuthOffset != azimuthOffset ||
        old.altitudeOffset != altitudeOffset ||
        old.altitudeScale != altitudeScale ||
        old.imageOpacity != imageOpacity ||
        old.terrainProfile != terrainProfile ||
        old.showTerrainSilhouette != showTerrainSilhouette ||
        old.showPoints != showPoints ||
        old.zoomLevel != zoomLevel ||
        old.viewStartAzimuth != viewStartAzimuth;
  }
}

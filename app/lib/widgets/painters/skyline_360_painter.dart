import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../l10n/app_localizations.dart';
import '../../models/altitude_point.dart';
import '../../models/filter_state.dart';
import '../../theme/astro_theme.dart';

/// 360° Skyline (NWES) View Painter
/// Displays the full 360-degree mountain horizon silhouette (N -> E -> S -> W -> N)
/// with cardinal markers, the target's trajectory arc across the sky over the mountains,
/// and time waypoint tags.
class Skyline360Painter extends CustomPainter {
  final List<AltitudePoint> points;
  final FilterState? filterState;
  final bool showHorizonSilhouette;
  final double minAltitudeThreshold;
  final double maxAltitudeThreshold;
  final double? hoverFraction;
  final bool isRedNightMode;
  final double zoomLevel;
  final double centerAzimuth;
  final DateTime? customWindowStart;
  final DateTime? customWindowEnd;
  final AppLocalizations l10n;

  Skyline360Painter({
    required this.points,
    this.filterState,
    this.showHorizonSilhouette = true,
    required this.minAltitudeThreshold,
    required this.maxAltitudeThreshold,
    this.hoverFraction,
    required this.isRedNightMode,
    this.zoomLevel = 1.0,
    this.centerAzimuth = 180.0,
    this.customWindowStart,
    this.customWindowEnd,
    required this.l10n,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomMargin = 28.0;

    final chartRect = Rect.fromLTWH(
      0,
      0,
      size.width,
      math.max(10.0, size.height - bottomMargin),
    );

    final visibleAzSpan = 360.0 / zoomLevel;
    final startAz = ((centerAzimuth - visibleAzSpan / 2.0) % 360.0 + 360.0) % 360.0;

    double azToX(double az) {
      var diff = (az - startAz) % 360.0;
      if (diff < 0) diff += 360.0;
      return (diff / visibleAzSpan) * size.width;
    }

    double altToY(double alt) =>
        chartRect.bottom - (alt.clamp(0.0, 90.0) / 90.0) * chartRect.height;

    canvas.save();
    canvas.clipRect(chartRect);

    // 1. Draw Horizontal Grid Lines (0°, 15°, 30°, 45°, 60°, 75°, 90°)
    final gridPaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionBorder.withValues(alpha: 0.4)
          : Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white30,
      fontSize: 9,
    );

    for (final alt in [0.0, 15.0, 30.0, 45.0, 60.0, 75.0, 90.0]) {
      final y = altToY(alt);
      if (alt == minAltitudeThreshold) {
        final threshPaint = Paint()
          ..color = isRedNightMode
              ? AstroColors.nightVisionRedDim.withValues(alpha: 0.7)
              : AstroColors.starGold.withValues(alpha: 0.4)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), threshPaint);
      } else {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      final textSpan = TextSpan(text: "${alt.toInt()}°", style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(6, y - tp.height - 2));
    }

    // 2. Draw Vertical Azimuth Guidelines (at cardinal lines)
    final cardinalGridPaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionBorder.withValues(alpha: 0.25)
          : Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    for (double az = 0.0; az < 360.0; az += 45.0) {
      final x = azToX(az);
      if (x >= 0 && x <= size.width) {
        canvas.drawLine(Offset(x, 0), Offset(x, chartRect.bottom), cardinalGridPaint);
      }
    }

    // 2b. Draw Custom Observing Window Background Band (faint sky tint)
    if (customWindowStart != null && customWindowEnd != null && points.isNotEmpty) {
      _drawCustomWindowBand(canvas, chartRect, azToX, visibleAzSpan, startAz, size.width);
    }

    // 3. Draw 360° Mountain Horizon Silhouette
    final hasHorizon = filterState != null && filterState!.hasHorizon;
    if (hasHorizon && showHorizonSilhouette) {
      _draw360Horizon(canvas, chartRect, azToX, altToY, visibleAzSpan, startAz, size.width);
    }

    // 3b. Draw Custom Observing Window Vertical Dashed Lines, Badges & Labels
    if (customWindowStart != null && customWindowEnd != null && points.isNotEmpty) {
      _drawCustomWindowDashedLines(canvas, chartRect, azToX, visibleAzSpan, startAz, size.width);
    }

    // 4. Draw Target Trajectory Path across the 360° Sky
    if (points.isNotEmpty) {
      _drawTargetTrajectory(canvas, chartRect, azToX, altToY, startAz, hasHorizon, visibleAzSpan);
    }

    canvas.restore();

    // 5. Draw Cardinal Direction Markers on the Bottom Axis (N, NE, E, SE, S, SW, W, NW)
    _drawCardinalAxis(canvas, size, chartRect, startAz, visibleAzSpan);

    // 6. Draw Interactive Cursor and Waypoint Highlights on Hover
    if (hoverFraction != null) {
      _drawHoverIndicator(canvas, chartRect, azToX, altToY, visibleAzSpan, startAz, hasHorizon, size.width);
    }
  }

  void _draw360Horizon(
    Canvas canvas,
    Rect chartRect,
    double Function(double) azToX,
    double Function(double) altToY,
    double visibleAzSpan,
    double startAz,
    double sizeWidth,
  ) {
    final horizonPath = Path();
    final horizonFillPath = Path();
    final numSteps = math.max(180, (sizeWidth / 2.0).round());

    bool first = true;
    for (int i = 0; i <= numSteps; i++) {
      final frac = i / numSteps;
      final az = (startAz + frac * visibleAzSpan) % 360.0;
      final hAlt = filterState!.getHorizonAltitudeAt(az);
      final x = frac * sizeWidth;
      final y = altToY(hAlt);

      if (first) {
        horizonPath.moveTo(x, y);
        horizonFillPath.moveTo(x, chartRect.bottom);
        horizonFillPath.lineTo(x, y);
        first = false;
      } else {
        horizonPath.lineTo(x, y);
        horizonFillPath.lineTo(x, y);
      }
    }

    horizonFillPath.lineTo(sizeWidth, chartRect.bottom);
    horizonFillPath.close();

    final mountainGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isRedNightMode
          ? [
              const Color(0xFF380808).withValues(alpha: 0.88),
              const Color(0xFF140202).withValues(alpha: 0.96),
            ]
          : [
              const Color(0xFF16253B).withValues(alpha: 0.90),
              const Color(0xFF070E1A).withValues(alpha: 0.97),
            ],
    );

    canvas.drawPath(horizonFillPath, Paint()..shader = mountainGradient.createShader(chartRect)..style = PaintingStyle.fill);

    final ridgePaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionRed.withValues(alpha: 0.75)
          : const Color(0xFF38BDF8).withValues(alpha: 0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(horizonPath, ridgePaint);
  }

  void _drawTargetTrajectory(
    Canvas canvas,
    Rect chartRect,
    double Function(double) azToX,
    double Function(double) altToY,
    double startAz,
    bool hasHorizon,
    double visibleAzSpan,
  ) {
    // 1. Separate path into continuous segments relative to startAz
    final segments = <List<AltitudePoint>>[];
    var currentSeg = <AltitudePoint>[points.first];

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      var dPrev = (prev.azimuth - startAz) % 360.0;
      if (dPrev < 0) dPrev += 360.0;
      var dCurr = (curr.azimuth - startAz) % 360.0;
      if (dCurr < 0) dCurr += 360.0;

      if ((dCurr - dPrev).abs() > 180.0) {
        segments.add(currentSeg);
        currentSeg = <AltitudePoint>[curr];
      } else {
        currentSeg.add(curr);
      }
    }
    segments.add(currentSeg);

    // 2. Draw occluded background path (dim dashed) and visible path (bright solid)
    final occludedPaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.35)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final visiblePaint = Paint()
      ..color = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final seg in segments) {
      if (seg.isEmpty) continue;
      final path = Path();
      path.moveTo(azToX(seg.first.azimuth), altToY(seg.first.altitude));
      for (int i = 1; i < seg.length; i++) {
        path.lineTo(azToX(seg[i].azimuth), altToY(seg[i].altitude));
      }
      canvas.drawPath(path, occludedPaint);

      final clearPath = Path();
      bool inClear = false;

      for (int i = 0; i < seg.length; i++) {
        final p = seg[i];
        final hAlt = (hasHorizon && showHorizonSilhouette)
            ? filterState!.getHorizonAltitudeAt(p.azimuth)
            : 0.0;
        final isClear = p.altitude >= hAlt;
        final x = azToX(p.azimuth);
        final y = altToY(p.altitude);

        if (isClear) {
          if (!inClear) {
            clearPath.moveTo(x, y);
            inClear = true;
          } else {
            clearPath.lineTo(x, y);
          }
        } else {
          inClear = false;
        }
      }

      // Draw active observing window trajectory glow
      if (customWindowStart != null && customWindowEnd != null) {
        final windowGlowPath = Path();
        bool inWindowGlow = false;
        for (int i = 0; i < seg.length; i++) {
          final p = seg[i];
          final isInWindow = !p.time.isBefore(customWindowStart!) && !p.time.isAfter(customWindowEnd!);
          final hAlt = (hasHorizon && showHorizonSilhouette)
              ? filterState!.getHorizonAltitudeAt(p.azimuth)
              : 0.0;
          final isClear = p.altitude >= hAlt;
          final x = azToX(p.azimuth);
          final y = altToY(p.altitude);

          if (isInWindow && isClear) {
            if (!inWindowGlow) {
              windowGlowPath.moveTo(x, y);
              inWindowGlow = true;
            } else {
              windowGlowPath.lineTo(x, y);
            }
          } else {
            inWindowGlow = false;
          }
        }
        final glowPaint = Paint()
          ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.35)
          ..strokeWidth = 5.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(windowGlowPath, glowPaint);
      }

      canvas.drawPath(clearPath, visiblePaint);
    }

    // 3. Mark Peak / Transit Point
    AltitudePoint peak = points.first;
    for (final p in points) {
      if (p.altitude > peak.altitude) peak = p;
    }
    final peakX = azToX(peak.azimuth);
    final peakY = altToY(peak.altitude);

    if (peakX >= chartRect.left && peakX <= chartRect.right) {
      canvas.drawCircle(Offset(peakX, peakY), 5.0, Paint()..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold));
      canvas.drawCircle(
        Offset(peakX, peakY),
        8.0,
        Paint()
          ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 4. Draw Waypoint Time Labels along the trajectory (every ~2 hours)
    final stepIdx = math.max(1, (points.length / 7).round());
    for (int i = 0; i < points.length; i += stepIdx) {
      final p = points[i];
      final wx = azToX(p.azimuth);
      final wy = altToY(p.altitude);
      if (wx < chartRect.left || wx > chartRect.right) continue;

      canvas.drawCircle(Offset(wx, wy), 2.5, Paint()..color = Colors.white70);

      final timeStr = DateFormat('HH:mm').format(p.time);
      final tp = TextPainter(
        text: TextSpan(
          text: timeStr,
          style: TextStyle(
            fontSize: 8.5,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: isRedNightMode ? AstroColors.nightVisionRed : Colors.white70,
            backgroundColor: const Color(0xAA000000),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(wx - tp.width / 2.0, wy - tp.height - 4));
    }

    // 5. Draw Custom Observing Window Waypoint Highlights on the Trajectory
    if (customWindowStart != null && customWindowEnd != null) {
      _drawCustomWindowTrajectoryHighlights(canvas, chartRect, altToY, visibleAzSpan, startAz);
    }
  }

  void _drawCardinalAxis(
    Canvas canvas,
    Size size,
    Rect chartRect,
    double startAz,
    double visibleAzSpan,
  ) {
    final cardinals = [
      (0.0, "N"),
      (45.0, "NE"),
      (90.0, "E"),
      (135.0, "SE"),
      (180.0, "S"),
      (225.0, "SW"),
      (270.0, "W"),
      (315.0, "NW"),
    ];

    for (final c in cardinals) {
      var diff = (c.$1 - startAz) % 360.0;
      if (diff < 0) diff += 360.0;

      if (diff <= visibleAzSpan + 0.01) {
        final x = (diff / visibleAzSpan) * size.width;
        _paintSingleCardinal(canvas, chartRect, c.$1, c.$2, x, size.width);
      }
      // If at left edge (diff close to 0) and at full 360 span, also paint at right edge
      if (diff < 0.01 && (visibleAzSpan - 360.0).abs() < 1e-3) {
        _paintSingleCardinal(canvas, chartRect, c.$1, c.$2, size.width, size.width);
      }
    }
  }

  void _paintSingleCardinal(
    Canvas canvas,
    Rect chartRect,
    double az,
    String label,
    double x,
    double sizeWidth,
  ) {
    if (x < -2 || x > sizeWidth + 2) return;

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(x, chartRect.bottom), Offset(x, chartRect.bottom + 5), tickPaint);

    final isMajor = label == "N" || label == "E" || label == "S" || label == "W";
    final span = TextSpan(
      text: "$label\n${az.toInt()}°",
      style: TextStyle(
        fontSize: isMajor ? 9.5 : 8.0,
        fontWeight: isMajor ? FontWeight.bold : FontWeight.w500,
        fontFamily: 'monospace',
        height: 1.1,
        color: isMajor
            ? (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan)
            : (isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white54),
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout();
    final textX = (x - tp.width / 2.0).clamp(2.0, sizeWidth - tp.width - 2.0);
    tp.paint(canvas, Offset(textX, chartRect.bottom + 6));
  }

  void _drawHoverIndicator(
    Canvas canvas,
    Rect chartRect,
    double Function(double) azToX,
    double Function(double) altToY,
    double visibleAzSpan,
    double startAz,
    bool hasHorizon,
    double sizeWidth,
  ) {
    final scrubX = (hoverFraction! * sizeWidth).clamp(0.0, sizeWidth);
    final rawHoveredAz = startAz + hoverFraction! * visibleAzSpan;
    final hoveredAz = ((rawHoveredAz % 360.0) + 360.0) % 360.0;

    final guidePaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : Colors.white60)
      ..strokeWidth = 1.0;
    _drawDashedLine(canvas, Offset(scrubX, chartRect.top), Offset(scrubX, chartRect.bottom), guidePaint);

    if (hasHorizon && showHorizonSilhouette) {
      final hAlt = filterState!.getHorizonAltitudeAt(hoveredAz);
      final ry = altToY(hAlt);
      canvas.drawCircle(Offset(scrubX, ry), 4.5, Paint()..color = Colors.amberAccent);
      canvas.drawCircle(
        Offset(scrubX, ry),
        7.5,
        Paint()
          ..color = Colors.amberAccent.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    if (points.isNotEmpty) {
      int bestIdx = 0;
      double bestDiff = double.infinity;
      for (int i = 0; i < points.length; i++) {
        double diff = (points[i].azimuth - hoveredAz).abs();
        if (diff > 180.0) diff = 360.0 - diff;
        if (diff < bestDiff) {
          bestDiff = diff;
          bestIdx = i;
        }
      }
      final p = points[bestIdx];
      final isNear = bestDiff <= 18.0;
      final tx = azToX(p.azimuth);
      final ty = altToY(p.altitude);

      if (tx >= 0 && tx <= sizeWidth) {
        canvas.drawCircle(
          Offset(tx, ty),
          isNear ? 5.5 : 3.5,
          Paint()..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: isNear ? 1.0 : 0.5),
        );
        if (isNear) {
          canvas.drawCircle(
            Offset(tx, ty),
            9.0,
            Paint()
              ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double currentX = p1.dx;
    double currentY = p1.dy;
    final isHorizontal = (p1.dy - p2.dy).abs() < 1e-4;

    if (isHorizontal) {
      while (currentX < p2.dx) {
        canvas.drawLine(
          Offset(currentX, p1.dy),
          Offset(math.min(currentX + dashWidth, p2.dx), p1.dy),
          paint,
        );
        currentX += dashWidth + dashSpace;
      }
    } else {
      while (currentY < p2.dy) {
        canvas.drawLine(
          Offset(p1.dx, currentY),
          Offset(p1.dx, math.min(currentY + dashWidth, p2.dy)),
          paint,
        );
        currentY += dashWidth + dashSpace;
      }
    }
  }

  void _drawVerticalDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashHeight = 4.0;
    const dashSpace = 3.0;
    double currentY = p1.dy;
    while (currentY < p2.dy) {
      canvas.drawLine(
        Offset(p1.dx, currentY),
        Offset(p1.dx, math.min(currentY + dashHeight, p2.dy)),
        paint,
      );
      currentY += dashHeight + dashSpace;
    }
  }

  ({double az, double alt})? _getTargetPositionAtTime(DateTime t) {
    if (points.isEmpty) return null;
    if (t.isBefore(points.first.time)) {
      return (az: points.first.azimuth, alt: points.first.altitude);
    }
    if (!t.isBefore(points.last.time)) {
      return (az: points.last.azimuth, alt: points.last.altitude);
    }

    int low = 0;
    int high = points.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (points[mid].time.isBefore(t)) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    final p0 = points[math.max(0, low - 1)];
    final p1 = points[math.min(points.length - 1, low)];
    final spanSec = p1.time.difference(p0.time).inSeconds;
    if (spanSec <= 0) return (az: p0.azimuth, alt: p0.altitude);

    final frac = t.difference(p0.time).inSeconds / spanSec;
    double diffAz = p1.azimuth - p0.azimuth;
    if (diffAz > 180.0) diffAz -= 360.0;
    if (diffAz < -180.0) diffAz += 360.0;
    var az = (p0.azimuth + frac * diffAz) % 360.0;
    if (az < 0) az += 360.0;
    final alt = p0.altitude + frac * (p1.altitude - p0.altitude);
    return (az: az, alt: alt);
  }

  void _drawCustomWindowBand(
    Canvas canvas,
    Rect chartRect,
    double Function(double) azToX,
    double visibleAzSpan,
    double startAz,
    double sizeWidth,
  ) {
    if (customWindowStart == null || customWindowEnd == null || points.isEmpty) return;
    if (customWindowEnd!.isBefore(points.first.time) || customWindowStart!.isAfter(points.last.time)) return;

    final startPos = _getTargetPositionAtTime(customWindowStart!);
    final endPos = _getTargetPositionAtTime(customWindowEnd!);
    if (startPos == null || endPos == null) return;

    final accentColor = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    var diffStart = (startPos.az - startAz) % 360.0;
    if (diffStart < 0) diffStart += 360.0;

    var diffEnd = (endPos.az - startAz) % 360.0;
    if (diffEnd < 0) diffEnd += 360.0;

    final startX = (diffStart / visibleAzSpan) * sizeWidth;
    final endX = (diffEnd / visibleAzSpan) * sizeWidth;

    final windowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.06);

    if (zoomLevel <= 1.05) {
      if (diffStart <= diffEnd) {
        canvas.drawRect(Rect.fromLTRB(startX, 0, endX, chartRect.bottom), windowPaint);
      } else {
        canvas.drawRect(Rect.fromLTRB(startX, 0, sizeWidth, chartRect.bottom), windowPaint);
        canvas.drawRect(Rect.fromLTRB(0, 0, endX, chartRect.bottom), windowPaint);
      }
    } else {
      final isStartVisible = diffStart <= visibleAzSpan + 0.01;
      final isEndVisible = diffEnd <= visibleAzSpan + 0.01;

      if (isStartVisible && isEndVisible) {
        if (diffStart <= diffEnd) {
          canvas.drawRect(Rect.fromLTRB(startX, 0, endX, chartRect.bottom), windowPaint);
        } else {
          canvas.drawRect(Rect.fromLTRB(startX, 0, sizeWidth, chartRect.bottom), windowPaint);
          canvas.drawRect(Rect.fromLTRB(0, 0, endX, chartRect.bottom), windowPaint);
        }
      } else if (isStartVisible && !isEndVisible) {
        if (diffStart < diffEnd) {
          canvas.drawRect(Rect.fromLTRB(startX, 0, sizeWidth, chartRect.bottom), windowPaint);
        } else {
          canvas.drawRect(Rect.fromLTRB(0, 0, startX, chartRect.bottom), windowPaint);
        }
      } else if (!isStartVisible && isEndVisible) {
        if (diffStart < diffEnd) {
          canvas.drawRect(Rect.fromLTRB(0, 0, endX, chartRect.bottom), windowPaint);
        } else {
          canvas.drawRect(Rect.fromLTRB(endX, 0, sizeWidth, chartRect.bottom), windowPaint);
        }
      }
    }
  }

  void _drawCustomWindowDashedLines(
    Canvas canvas,
    Rect chartRect,
    double Function(double) azToX,
    double visibleAzSpan,
    double startAz,
    double sizeWidth,
  ) {
    if (customWindowStart == null || customWindowEnd == null || points.isEmpty) return;
    if (customWindowEnd!.isBefore(points.first.time) || customWindowStart!.isAfter(points.last.time)) return;

    final startPos = _getTargetPositionAtTime(customWindowStart!);
    final endPos = _getTargetPositionAtTime(customWindowEnd!);
    if (startPos == null || endPos == null) return;

    final accentColor = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    var diffStart = (startPos.az - startAz) % 360.0;
    if (diffStart < 0) diffStart += 360.0;

    var diffEnd = (endPos.az - startAz) % 360.0;
    if (diffEnd < 0) diffEnd += 360.0;

    final isStartVisible = diffStart <= visibleAzSpan + 0.01;
    final isEndVisible = diffEnd <= visibleAzSpan + 0.01;

    final startX = (diffStart / visibleAzSpan) * sizeWidth;
    final endX = (diffEnd / visibleAzSpan) * sizeWidth;

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    if (isStartVisible) {
      _drawVerticalDashedLine(canvas, Offset(startX, 0), Offset(startX, chartRect.bottom), borderPaint);
      _drawWindowBadge(
        canvas,
        chartRect,
        startX,
        "▶ ${DateFormat('HH:mm').format(customWindowStart!)}",
        accentColor,
      );
    }

    if (isEndVisible) {
      _drawVerticalDashedLine(canvas, Offset(endX, 0), Offset(endX, chartRect.bottom), borderPaint);
      _drawWindowBadge(
        canvas,
        chartRect,
        endX,
        "${DateFormat('HH:mm').format(customWindowEnd!)} ◀",
        accentColor,
      );
    }

    // Label between lines if space allows
    if (isStartVisible && isEndVisible && diffStart < diffEnd) {
      final spanWidth = endX - startX;
      final labelStyle = TextStyle(
        color: accentColor.withValues(alpha: 0.75),
        fontSize: 8.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: l10n.observingWindowLabel.toUpperCase(),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      if (spanWidth > tp.width + 16) {
        tp.paint(canvas, Offset(startX + (spanWidth - tp.width) / 2, chartRect.bottom - tp.height - 6));
      }
    }
  }

  void _drawWindowBadge(
    Canvas canvas,
    Rect chartRect,
    double x,
    String text,
    Color accentColor,
  ) {
    final style = TextStyle(
      color: accentColor,
      fontSize: 8.5,
      fontFamily: 'monospace',
      fontWeight: FontWeight.bold,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    const badgePaddingH = 5.0;
    const badgePaddingV = 2.0;
    final badgeW = tp.width + badgePaddingH * 2;
    final badgeH = tp.height + badgePaddingV * 2;

    final badgeLeft = (x - badgeW / 2.0).clamp(chartRect.left + 2.0, chartRect.right - badgeW - 2.0);
    final badgeTop = chartRect.top + 6.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeLeft, badgeTop, badgeW, badgeH),
      const Radius.circular(4.0),
    );

    final bgPaint = Paint()
      ..color = const Color(0xDD070D19)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, borderPaint);

    tp.paint(canvas, Offset(badgeLeft + badgePaddingH, badgeTop + badgePaddingV));
  }

  void _drawCustomWindowTrajectoryHighlights(
    Canvas canvas,
    Rect chartRect,
    double Function(double) altToY,
    double visibleAzSpan,
    double startAz,
  ) {
    if (customWindowStart == null || customWindowEnd == null || points.isEmpty) return;
    if (customWindowEnd!.isBefore(points.first.time) || customWindowStart!.isAfter(points.last.time)) return;

    final startPos = _getTargetPositionAtTime(customWindowStart!);
    final endPos = _getTargetPositionAtTime(customWindowEnd!);
    final accentColor = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    if (startPos != null) {
      var diffStart = (startPos.az - startAz) % 360.0;
      if (diffStart < 0) diffStart += 360.0;
      if (diffStart <= visibleAzSpan + 0.01) {
        final sx = (diffStart / visibleAzSpan) * chartRect.width;
        final sy = altToY(startPos.alt);
        canvas.drawCircle(Offset(sx, sy), 9.0, Paint()..color = accentColor.withValues(alpha: 0.25));
        canvas.drawCircle(
          Offset(sx, sy),
          6.0,
          Paint()
            ..color = accentColor.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(Offset(sx, sy), 3.0, Paint()..color = accentColor);
      }
    }

    if (endPos != null) {
      var diffEnd = (endPos.az - startAz) % 360.0;
      if (diffEnd < 0) diffEnd += 360.0;
      if (diffEnd <= visibleAzSpan + 0.01) {
        final ex = (diffEnd / visibleAzSpan) * chartRect.width;
        final ey = altToY(endPos.alt);
        canvas.drawCircle(Offset(ex, ey), 9.0, Paint()..color = accentColor.withValues(alpha: 0.25));
        canvas.drawCircle(
          Offset(ex, ey),
          6.0,
          Paint()
            ..color = accentColor.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(Offset(ex, ey), 3.0, Paint()..color = accentColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant Skyline360Painter old) {
    return old.points != points ||
        old.filterState != filterState ||
        old.showHorizonSilhouette != showHorizonSilhouette ||
        old.hoverFraction != hoverFraction ||
        old.zoomLevel != zoomLevel ||
        old.centerAzimuth != centerAzimuth ||
        old.isRedNightMode != isRedNightMode ||
        old.minAltitudeThreshold != minAltitudeThreshold ||
        old.maxAltitudeThreshold != maxAltitudeThreshold ||
        old.customWindowStart != customWindowStart ||
        old.customWindowEnd != customWindowEnd;
  }
}

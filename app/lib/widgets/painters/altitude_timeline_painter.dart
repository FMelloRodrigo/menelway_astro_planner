import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../l10n/app_localizations.dart';
import '../../models/altitude_point.dart';
import '../../models/filter_state.dart';
import '../../models/night_summary.dart';
import '../../theme/astro_theme.dart';

/// Classic Altitude vs. Time Chart Painter with Integrated Compass Directions
class AltitudeTimelinePainter extends CustomPainter {
  final List<AltitudePoint> points;
  final NightSummary night;
  final double minAltitudeThreshold;
  final double maxAltitudeThreshold;
  final double? hoverFraction;
  final bool isRedNightMode;
  final DateTime visibleStartTime;
  final DateTime visibleEndTime;
  final DateTime totalStartTime;
  final DateTime totalEndTime;
  final DateTime? customWindowStart;
  final DateTime? customWindowEnd;
  final FilterState? filterState;
  final bool showHorizonSilhouette;
  final AppLocalizations l10n;

  AltitudeTimelinePainter({
    required this.points,
    required this.night,
    required this.minAltitudeThreshold,
    required this.maxAltitudeThreshold,
    required this.hoverFraction,
    required this.isRedNightMode,
    required this.visibleStartTime,
    required this.visibleEndTime,
    required this.totalStartTime,
    required this.totalEndTime,
    this.customWindowStart,
    this.customWindowEnd,
    this.filterState,
    this.showHorizonSilhouette = true,
    required this.l10n,
  });

  static String _cardinal(double az) {
    final a = ((az % 360) + 360) % 360;
    if (a >= 337.5 || a < 22.5) return "N";
    if (a < 67.5) return "NE";
    if (a < 112.5) return "E";
    if (a < 157.5) return "SE";
    if (a < 202.5) return "S";
    if (a < 247.5) return "SW";
    if (a < 292.5) return "W";
    return "NW";
  }

  @override
  void paint(Canvas canvas, Size size) {
    const bottomMargin = 28.0;
    final chartRect = Rect.fromLTWH(0, 0, size.width, size.height - bottomMargin);
    final visibleDurationSec = visibleEndTime.difference(visibleStartTime).inSeconds;
    if (visibleDurationSec <= 0) return;

    double timeToX(DateTime t) {
      final sec = t.difference(visibleStartTime).inSeconds;
      return (sec / visibleDurationSec) * size.width;
    }

    double altToY(double altDeg) {
      final normalized = (altDeg.clamp(-10.0, 90.0) - (-10.0)) / 100.0;
      return chartRect.bottom - normalized * chartRect.height;
    }

    canvas.save();
    canvas.clipRect(chartRect);

    // 1. Draw Twilight bands
    _drawTwilightBands(canvas, chartRect, timeToX);

    // 1b. Draw Custom Observing Window Band (if set)
    _drawCustomWindowBand(canvas, chartRect, timeToX);

    // 2. Draw Horizontal Grid lines (0°, 30°, 60°, 90°)
    final gridPaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionBorder.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    final thresholdPaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionRedDim.withValues(alpha: 0.7)
          : AstroColors.starGold.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white30,
      fontSize: 9,
    );

    for (final alt in [0.0, 30.0, 60.0, 90.0]) {
      final y = altToY(alt);
      if (alt == minAltitudeThreshold) {
        _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), thresholdPaint);
      } else {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      final textSpan = TextSpan(text: "${alt.toInt()}°", style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(6, y - tp.height - 2));
    }

    if (maxAltitudeThreshold < 90.0) {
      final yMax = altToY(maxAltitudeThreshold);
      final maxPaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRedDim : Colors.amberAccent).withValues(alpha: 0.55)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, Offset(0, yMax), Offset(size.width, yMax), maxPaint);

      final tpMax = TextPainter(
        text: TextSpan(
          text: "MAX: ${maxAltitudeThreshold.toInt()}°",
          style: textStyle.copyWith(
            color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.amberAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpMax.paint(canvas, Offset(size.width - tpMax.width - 8, yMax - tpMax.height - 2));
    }

    // 3. Draw Target Altitude Path (Background & Fill)
    if (points.isNotEmpty) {
      final path = Path();
      final fillPath = Path();

      bool first = true;
      for (final p in points) {
        final x = timeToX(p.time);
        final y = altToY(p.altitude);
        if (first) {
          path.moveTo(x, y);
          fillPath.moveTo(x, chartRect.bottom);
          fillPath.lineTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }
      fillPath.lineTo(timeToX(points.last.time), chartRect.bottom);
      fillPath.close();

      final fillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isRedNightMode
            ? [
                AstroColors.nightVisionRed.withValues(alpha: 0.22),
                AstroColors.nightVisionRed.withValues(alpha: 0.0),
              ]
            : [
                AstroColors.starlightCyan.withValues(alpha: 0.25),
                AstroColors.nebulaIndigo.withValues(alpha: 0.0),
              ],
      );

      final fillPaint = Paint()
        ..shader = fillGradient.createShader(chartRect)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      final occludedStrokePaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.35)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, occludedStrokePaint);
    }

    // 4. Draw Horizon Silhouette (Mountain Topography / Custom Obstacles)
    final hasHorizon = filterState != null && filterState!.hasHorizon;
    if (hasHorizon && showHorizonSilhouette && points.isNotEmpty) {
      _drawHorizonSilhouette(canvas, chartRect, timeToX, altToY);
    }

    // 5. Draw Target Visible Foreground Stroke (Bright segments above horizon)
    if (points.isNotEmpty) {
      final solidPath = Path();
      bool inSolid = false;

      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final x = timeToX(p.time);
        final y = altToY(p.altitude);

        final hAlt = (hasHorizon && showHorizonSilhouette)
            ? filterState!.getHorizonAltitudeAt(p.azimuth)
            : 0.0;
        final isClear = p.altitude >= hAlt;

        if (isClear) {
          if (!inSolid) {
            solidPath.moveTo(x, y);
            inSolid = true;
          } else {
            solidPath.lineTo(x, y);
          }
        } else {
          inSolid = false;
        }
      }

      final solidStrokePaint = Paint()
        ..color = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(solidPath, solidStrokePaint);

      AltitudePoint peakPoint = points.first;
      for (final p in points) {
        if (p.altitude > peakPoint.altitude) peakPoint = p;
      }

      final peakX = timeToX(peakPoint.time);
      final peakY = altToY(peakPoint.altitude);

      final peakPaint = Paint()
        ..color = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(peakX, peakY), 4.0, peakPaint);
      canvas.drawCircle(
        Offset(peakX, peakY),
        7.0,
        Paint()
          ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.restore();

    // 6. Draw Time & Compass Direction Labels along the Bottom Axis
    _drawTimeLabels(canvas, size, chartRect, visibleDurationSec);

    // 7. Scrubber Line & Cursor
    if (hoverFraction != null) {
      final scrubX = hoverFraction! * size.width;
      final scrubPaint = Paint()
        ..color = isRedNightMode ? AstroColors.nightVisionRed : Colors.white70
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(scrubX, 0), Offset(scrubX, chartRect.bottom), scrubPaint);

      final hoveredSec = (hoverFraction! * visibleDurationSec).round();
      final hoveredTime = visibleStartTime.add(Duration(seconds: hoveredSec));

      if (points.isNotEmpty) {
        AltitudePoint closestP = points.first;
        int minDiff = 999999999;
        for (final p in points) {
          final diff = (p.time.difference(hoveredTime).inSeconds).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closestP = p;
          }
        }

        final dotY = altToY(closestP.altitude);
        canvas.drawCircle(
          Offset(scrubX, dotY),
          4.5,
          Paint()..color = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
        );

        if (hasHorizon && showHorizonSilhouette) {
          final hAlt = filterState!.getHorizonAltitudeAt(closestP.azimuth);
          final hDotY = altToY(hAlt);
          canvas.drawCircle(
            Offset(scrubX, hDotY),
            3.5,
            Paint()..color = Colors.amberAccent.withValues(alpha: 0.9),
          );
        }
      }
    }
  }

  double _getTargetAzimuthAtTime(DateTime t) {
    if (points.isEmpty) return 0.0;
    if (t.isBefore(points.first.time)) return points.first.azimuth;
    if (!t.isBefore(points.last.time)) return points.last.azimuth;

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
    if (spanSec <= 0) return p0.azimuth;

    final frac = t.difference(p0.time).inSeconds / spanSec;
    double diff = p1.azimuth - p0.azimuth;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    final az = (p0.azimuth + frac * diff) % 360.0;
    return az < 0 ? az + 360.0 : az;
  }

  void _drawHorizonSilhouette(
    Canvas canvas,
    Rect chartRect,
    double Function(DateTime) timeToX,
    double Function(double) altToY,
  ) {
    final horizonPath = Path();
    final horizonFillPath = Path();
    final visibleDurationSec = visibleEndTime.difference(visibleStartTime).inSeconds;
    if (visibleDurationSec <= 0) return;

    final numSteps = math.max(160, (chartRect.width / 2.0).round());
    bool first = true;

    for (int i = 0; i <= numSteps; i++) {
      final frac = i / numSteps;
      final x = chartRect.left + frac * chartRect.width;
      final t = visibleStartTime.add(Duration(seconds: (frac * visibleDurationSec).round()));
      final az = _getTargetAzimuthAtTime(t);
      final hAlt = filterState!.getHorizonAltitudeAt(az);
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

    horizonFillPath.lineTo(chartRect.right, chartRect.bottom);
    horizonFillPath.close();

    final mountainGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isRedNightMode
          ? [
              const Color(0xFF380808).withValues(alpha: 0.85),
              const Color(0xFF140202).withValues(alpha: 0.96),
            ]
          : [
              const Color(0xFF1A2436).withValues(alpha: 0.88),
              const Color(0xFF090E17).withValues(alpha: 0.96),
            ],
    );

    final fillPaint = Paint()
      ..shader = mountainGradient.createShader(chartRect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(horizonFillPath, fillPaint);

    final ridgePaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionRed.withValues(alpha: 0.65)
          : const Color(0xFF38BDF8).withValues(alpha: 0.75)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(horizonPath, ridgePaint);

    final badgeStyle = TextStyle(
      fontSize: 7.5,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
      color: isRedNightMode
          ? AstroColors.nightVisionRed.withValues(alpha: 0.6)
          : const Color(0xFF38BDF8).withValues(alpha: 0.7),
    );
    final firstAz = _getTargetAzimuthAtTime(visibleStartTime);
    final firstHAlt = filterState!.getHorizonAltitudeAt(firstAz);
    final firstY = altToY(firstHAlt);

    final tp = TextPainter(
      text: TextSpan(
        text: "HORIZON: ${firstHAlt.toStringAsFixed(1)}° (${firstAz.toStringAsFixed(0)}° AZ)",
        style: badgeStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(chartRect.left + 8.0, math.min(chartRect.bottom - tp.height - 4, firstY + 4)));
  }

  void _drawTwilightBands(Canvas canvas, Rect rect, double Function(DateTime) timeToX) {
    final astroDuskX = timeToX(night.astronomicalDusk).clamp(0.0, rect.width);
    final astroDawnX = timeToX(night.astronomicalDawn).clamp(0.0, rect.width);

    if (astroDuskX < astroDawnX) {
      final darkRect = Rect.fromLTRB(astroDuskX, 0, astroDawnX, rect.bottom);
      final darkPaint = Paint()
        ..color = isRedNightMode
            ? AstroColors.nightVisionSurfaceVariant.withValues(alpha: 0.6)
            : const Color(0xFF04060A).withValues(alpha: 0.85);
      canvas.drawRect(darkRect, darkPaint);

      final labelStyle = TextStyle(
        color: isRedNightMode ? AstroColors.nightVisionRedDim.withValues(alpha: 0.6) : Colors.white24,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: l10n.astronomicalDarkness.toUpperCase(),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textWidth = tp.width;
      final spanWidth = astroDawnX - astroDuskX;
      if (spanWidth > textWidth + 16) {
        tp.paint(canvas, Offset(astroDuskX + (spanWidth - textWidth) / 2, 8));
      }
    }

    final nautDuskX = timeToX(night.nauticalDusk).clamp(0.0, rect.width);
    if (nautDuskX < astroDuskX) {
      final nautPaint = Paint()
        ..color = isRedNightMode
            ? AstroColors.nightVisionSurface.withValues(alpha: 0.4)
            : const Color(0xFF0A1224).withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTRB(nautDuskX, 0, astroDuskX, rect.bottom), nautPaint);
    }

    final nautDawnX = timeToX(night.nauticalDawn).clamp(0.0, rect.width);
    if (astroDawnX < nautDawnX) {
      final nautPaint = Paint()
        ..color = isRedNightMode
            ? AstroColors.nightVisionSurface.withValues(alpha: 0.4)
            : const Color(0xFF0A1224).withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTRB(astroDawnX, 0, nautDawnX, rect.bottom), nautPaint);
    }
  }

  void _drawCustomWindowBand(Canvas canvas, Rect rect, double Function(DateTime) timeToX) {
    if (customWindowStart == null || customWindowEnd == null) return;

    final startX = timeToX(customWindowStart!).clamp(0.0, rect.width);
    final endX = timeToX(customWindowEnd!).clamp(0.0, rect.width);

    if (startX < endX) {
      final windowRect = Rect.fromLTRB(startX, 0, endX, rect.bottom);
      final windowPaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.07);
      canvas.drawRect(windowRect, windowPaint);

      final borderPaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      _drawVerticalDashedLine(canvas, Offset(startX, 0), Offset(startX, rect.bottom), borderPaint);
      _drawVerticalDashedLine(canvas, Offset(endX, 0), Offset(endX, rect.bottom), borderPaint);

      final labelStyle = TextStyle(
        color: isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
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

      final spanWidth = endX - startX;
      if (spanWidth > tp.width + 12) {
        tp.paint(canvas, Offset(startX + (spanWidth - tp.width) / 2, rect.bottom - tp.height - 6));
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

  void _drawTimeLabels(Canvas canvas, Size size, Rect chartRect, int durationSec) {
    const labelCount = 6;
    final textStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white60,
      fontSize: 9.5,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );
    final cardStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
      fontSize: 8.0,
      fontWeight: FontWeight.w600,
      fontFamily: 'monospace',
    );

    for (int i = 0; i <= labelCount; ++i) {
      final frac = i / labelCount;
      final x = frac * size.width;
      final time = visibleStartTime.add(Duration(seconds: (frac * durationSec).round()));

      final timeStr = DateFormat('HH:mm').format(time);
      final az = _getTargetAzimuthAtTime(time);
      final cardStr = _cardinal(az);

      final span = TextSpan(
        children: [
          TextSpan(text: "$timeStr\n", style: textStyle),
          TextSpan(text: "$cardStr (${az.round()}°)", style: cardStyle),
        ],
      );
      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final textX = (x - tp.width / 2).clamp(2.0, size.width - tp.width - 2);
      tp.paint(canvas, Offset(textX, chartRect.bottom + 4));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double currentX = p1.dx;
    while (currentX < p2.dx) {
      canvas.drawLine(
        Offset(currentX, p1.dy),
        Offset(math.min(currentX + dashWidth, p2.dx), p1.dy),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant AltitudeTimelinePainter old) {
    return old.points != points ||
        old.hoverFraction != hoverFraction ||
        old.visibleStartTime != visibleStartTime ||
        old.visibleEndTime != visibleEndTime ||
        old.customWindowStart != customWindowStart ||
        old.customWindowEnd != customWindowEnd ||
        old.isRedNightMode != isRedNightMode ||
        old.showHorizonSilhouette != showHorizonSilhouette ||
        old.filterState != filterState ||
        old.minAltitudeThreshold != minAltitudeThreshold;
  }
}

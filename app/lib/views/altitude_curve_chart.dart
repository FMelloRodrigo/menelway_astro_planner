import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/altitude_point.dart';
import '../models/night_summary.dart';
import '../theme/astro_theme.dart';
import '../l10n/app_localizations.dart';

class AltitudeCurveChart extends StatefulWidget {
  final List<AltitudePoint> targetPoints;
  final NightSummary night;
  final String targetName;
  final double minAltitudeThreshold;
  final double maxAltitudeThreshold;
  final bool isRedNightMode;
  final DateTime? customWindowStart;
  final DateTime? customWindowEnd;

  const AltitudeCurveChart({
    super.key,
    required this.targetPoints,
    required this.night,
    required this.targetName,
    this.minAltitudeThreshold = 30.0,
    this.maxAltitudeThreshold = 90.0,
    this.isRedNightMode = false,
    this.customWindowStart,
    this.customWindowEnd,
  });

  @override
  State<AltitudeCurveChart> createState() => _AltitudeCurveChartState();
}

class _AltitudeCurveChartState extends State<AltitudeCurveChart> {
  double? _hoverFraction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.targetPoints.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
          ),
        ),
        child: Center(
          child: Text(l10n?.noAltitudeData ?? "No altitude data available for window", style: const TextStyle(color: Colors.white54)),
        ),
      );
    }

    final startTime = widget.targetPoints.first.time;
    final endTime = widget.targetPoints.last.time;

    AltitudePoint? hoveredPoint;
    if (_hoverFraction != null && widget.targetPoints.isNotEmpty) {
      final index = (_hoverFraction! * (widget.targetPoints.length - 1))
          .clamp(0, widget.targetPoints.length - 1)
          .round();
      hoveredPoint = widget.targetPoints[index];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with stats and scrubber info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Builder(
                builder: (context) {
                  final titleWidget = Row(
                    children: [
                      Icon(
                        Icons.show_chart_rounded,
                        size: 18,
                        color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n?.altitudeVsTimeTarget(widget.targetName) ?? "Altitude vs. Time: ${widget.targetName}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          DateFormat('MMM d').format(widget.night.sunset),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                          ),
                        ),
                      ),
                    ],
                  );

                  Widget? hoveredWidget;
                  if (hoveredPoint != null) {
                    hoveredWidget = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.isRedNightMode
                            ? AstroColors.nightVisionSurfaceVariant
                            : AstroColors.spaceDarkSurfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.isRedNightMode
                              ? AstroColors.nightVisionBorder
                              : AstroColors.spaceDarkBorder,
                        ),
                      ),
                      child: Text(
                        "${DateFormat('HH:mm').format(hoveredPoint.time)}  •  "
                        "Alt: ${hoveredPoint.altitude.toStringAsFixed(1)}°  •  "
                        "Az: ${hoveredPoint.azimuth.toStringAsFixed(0)}°  •  "
                        "${l10n?.moonSeparationShort(hoveredPoint.moonSeparation.toStringAsFixed(0)) ?? 'Moon: ${hoveredPoint.moonSeparation.toStringAsFixed(0)}°'}",
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }

                  if (constraints.maxWidth < 480 && hoveredWidget != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 4),
                        hoveredWidget,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: titleWidget),
                      if (hoveredWidget != null) ...[
                        const SizedBox(width: 8),
                        hoveredWidget,
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            // Chart Canvas
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                final localX = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                setState(() {
                  _hoverFraction = localX / constraints.maxWidth;
                });
              },
              onHorizontalDragEnd: (_) => setState(() => _hoverFraction = null),
              child: MouseRegion(
                onHover: (event) {
                  final localX = event.localPosition.dx.clamp(0.0, constraints.maxWidth);
                  setState(() {
                    _hoverFraction = localX / constraints.maxWidth;
                  });
                },
                onExit: (_) => setState(() => _hoverFraction = null),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 190,
                    decoration: BoxDecoration(
                      color: widget.isRedNightMode
                          ? AstroColors.nightVisionSurface
                          : AstroColors.spaceDarkSurface,
                      border: Border.all(
                        color: widget.isRedNightMode
                            ? AstroColors.nightVisionBorder
                            : AstroColors.spaceDarkBorder,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, 190),
                      painter: _AltitudeChartPainter(
                        points: widget.targetPoints,
                        night: widget.night,
                        minAltitudeThreshold: widget.minAltitudeThreshold,
                        maxAltitudeThreshold: widget.maxAltitudeThreshold,
                        hoverFraction: _hoverFraction,
                        isRedNightMode: widget.isRedNightMode,
                        startTime: startTime,
                        endTime: endTime,
                        customWindowStart: widget.customWindowStart,
                        customWindowEnd: widget.customWindowEnd,
                        l10n: l10n,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AltitudeChartPainter extends CustomPainter {
  final List<AltitudePoint> points;
  final NightSummary night;
  final double minAltitudeThreshold;
  final double maxAltitudeThreshold;
  final double? hoverFraction;
  final bool isRedNightMode;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? customWindowStart;
  final DateTime? customWindowEnd;
  final AppLocalizations? l10n;

  _AltitudeChartPainter({
    required this.points,
    required this.night,
    required this.minAltitudeThreshold,
    required this.maxAltitudeThreshold,
    required this.hoverFraction,
    required this.isRedNightMode,
    required this.startTime,
    required this.endTime,
    this.customWindowStart,
    this.customWindowEnd,
    this.l10n,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(0, 0, size.width, size.height - 24);
    final totalDuration = endTime.difference(startTime).inSeconds;
    if (totalDuration <= 0) return;

    double timeToX(DateTime t) {
      final sec = t.difference(startTime).inSeconds;
      return (sec / totalDuration) * size.width;
    }

    double altToY(double altDeg) {
      // 0 deg is at chartRect.bottom, 90 deg is at chartRect.top
      final normalized = (altDeg.clamp(-10.0, 90.0) - (-10.0)) / 100.0;
      return chartRect.bottom - normalized * chartRect.height;
    }

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
        // Dashed threshold line
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

    // 3. Draw Target Altitude Path
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

      // Gradient Fill
      final fillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isRedNightMode
            ? [
                AstroColors.nightVisionRed.withValues(alpha: 0.25),
                AstroColors.nightVisionRed.withValues(alpha: 0.0),
              ]
            : [
                AstroColors.starlightCyan.withValues(alpha: 0.3),
                AstroColors.nebulaIndigo.withValues(alpha: 0.0),
              ],
      );

      final fillPaint = Paint()
        ..shader = fillGradient.createShader(chartRect)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Stroke Path
      final strokePaint = Paint()
        ..color = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, strokePaint);

      // Find and mark transit / peak altitude
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

    // 4. Draw Time Axis Labels
    _drawTimeLabels(canvas, size, chartRect, totalDuration);

    // 5. Scrubber Line & Cursor
    if (hoverFraction != null) {
      final scrubX = hoverFraction! * size.width;
      final scrubPaint = Paint()
        ..color = isRedNightMode ? AstroColors.nightVisionRed : Colors.white70
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(scrubX, 0), Offset(scrubX, chartRect.bottom), scrubPaint);
    }
  }

  void _drawTwilightBands(Canvas canvas, Rect rect, double Function(DateTime) timeToX) {
    // Astronomical dusk to dawn is full darkness
    final astroDuskX = timeToX(night.astronomicalDusk).clamp(0.0, rect.width);
    final astroDawnX = timeToX(night.astronomicalDawn).clamp(0.0, rect.width);

    if (astroDuskX < astroDawnX) {
      final darkRect = Rect.fromLTRB(astroDuskX, 0, astroDawnX, rect.bottom);
      final darkPaint = Paint()
        ..color = isRedNightMode
            ? AstroColors.nightVisionSurfaceVariant.withValues(alpha: 0.6)
            : const Color(0xFF04060A).withValues(alpha: 0.85);
      canvas.drawRect(darkRect, darkPaint);

      // Dusk marker text
      final labelStyle = TextStyle(
        color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white24,
        fontSize: 8,
        letterSpacing: 0.5,
      );
      final tp = TextPainter(
        text: TextSpan(text: l10n?.astronomicalDarknessLabel ?? "ASTRONOMICAL DARKNESS", style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(darkRect.center.dx - tp.width / 2, 8));
    }
  }

  void _drawCustomWindowBand(Canvas canvas, Rect rect, double Function(DateTime) timeToX) {
    if (customWindowStart == null || customWindowEnd == null) return;
    final winStartX = timeToX(customWindowStart!).clamp(0.0, rect.width);
    final winEndX = timeToX(customWindowEnd!).clamp(0.0, rect.width);

    if (winStartX < winEndX) {
      final winRect = Rect.fromLTRB(winStartX, 0, winEndX, rect.bottom);
      final winPaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawRect(winRect, winPaint);

      // Boundary vertical dashed lines
      final borderPaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.7)
        ..strokeWidth = 1.2;

      _drawDashedVerticalLine(canvas, winStartX, 0, rect.bottom, borderPaint);
      _drawDashedVerticalLine(canvas, winEndX, 0, rect.bottom, borderPaint);

      // Window badge
      final labelStyle = TextStyle(
        color: isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
        fontSize: 8,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );
      final tp = TextPainter(
        text: TextSpan(text: l10n?.observingWindowLabel ?? "OBSERVING WINDOW", style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(winStartX + 4, rect.bottom - tp.height - 4));
    }
  }

  void _drawDashedVerticalLine(Canvas canvas, double x, double startY, double endY, Paint paint) {
    const dashHeight = 4.0;
    const dashSpace = 3.0;
    double currentY = startY;
    while (currentY < endY) {
      canvas.drawLine(
        Offset(x, currentY),
        Offset(x, math.min(currentY + dashHeight, endY)),
        paint,
      );
      currentY += dashHeight + dashSpace;
    }
  }

  void _drawTimeLabels(Canvas canvas, Size size, Rect chartRect, int totalDurationSec) {
    const labelCount = 6;
    final textStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white38,
      fontSize: 10,
    );

    for (int i = 0; i <= labelCount; ++i) {
      final frac = i / labelCount;
      final x = frac * size.width;
      final time = startTime.add(Duration(seconds: (frac * totalDurationSec).round()));

      final timeStr = DateFormat('HH:mm').format(time);
      final tp = TextPainter(
        text: TextSpan(text: timeStr, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final textX = (x - tp.width / 2).clamp(2.0, size.width - tp.width - 2);
      tp.paint(canvas, Offset(textX, chartRect.bottom + 6));
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
  bool shouldRepaint(covariant _AltitudeChartPainter old) {
    return old.points != points ||
        old.hoverFraction != hoverFraction ||
        old.customWindowStart != customWindowStart ||
        old.customWindowEnd != customWindowEnd ||
        old.isRedNightMode != isRedNightMode ||
        old.minAltitudeThreshold != minAltitudeThreshold;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/astro_theme.dart';

class AzimuthCompassDial extends StatelessWidget {
  final double minAzimuth;
  final double maxAzimuth;
  final bool isRedNightMode;
  final AppLocalizations l10n;

  const AzimuthCompassDial({
    super.key,
    required this.minAzimuth,
    required this.maxAzimuth,
    this.isRedNightMode = false,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(100, 100),
          painter: _CompassPainter(
            minAz: minAzimuth,
            maxAz: maxAzimuth,
            isRed: isRedNightMode,
            l10n: l10n,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _spanLabel(),
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
          ),
        ),
      ],
    );
  }

  String _spanLabel() {
    final min = minAzimuth.round();
    final max = maxAzimuth.round();
    if (min == 0 && max == 360) return l10n.compassAll360;
    if (min == max) return l10n.compassClosed;
    final span = (max >= min) ? (max - min) : (360 - min + max);
    return l10n.compassSpan(span.toString());
  }
}

class _CompassPainter extends CustomPainter {
  final double minAz;
  final double maxAz;
  final bool isRed;
  final AppLocalizations l10n;

  _CompassPainter({
    required this.minAz,
    required this.maxAz,
    required this.isRed,
    required this.l10n,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // 1. Dark circular background
    final bgPaint = Paint()
      ..color = isRed
          ? AstroColors.nightVisionBackground
          : const Color(0xFF070B12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Outer ring border
    final ringPaint = Paint()
      ..color = isRed
          ? AstroColors.nightVisionBorder
          : AstroColors.spaceDarkBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, ringPaint);

    // 3. Highlighted active wedge (Azimuth cone)
    final wedgePaint = Paint()
      ..color = (isRed ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final arcPaint = Paint()
      ..color = isRed ? AstroColors.nightVisionRed : AstroColors.starlightCyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Convert degrees to radians (0 deg is North = -pi/2 in canvas)
    double degToRad(double deg) => (deg - 90) * (math.pi / 180.0);

    final startAngle = degToRad(minAz);
    double sweepAngle;
    if ((minAz - maxAz).abs() < 1e-4 || (minAz == 0 && maxAz == 360)) {
      sweepAngle = 2 * math.pi;
    } else if (maxAz >= minAz) {
      sweepAngle = (maxAz - minAz) * (math.pi / 180.0);
    } else {
      sweepAngle = (360 - minAz + maxAz) * (math.pi / 180.0);
    }

    // Draw active wedge & arc
    canvas.drawArc(arcRect, startAngle, sweepAngle, true, wedgePaint);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);

    // 4. Crosshairs
    final crosshairPaint = Paint()
      ..color = (isRed ? AstroColors.nightVisionBorder : Colors.white12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), crosshairPaint);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), crosshairPaint);

    // 5. Center dot
    canvas.drawCircle(center, 2.5, Paint()..color = (isRed ? AstroColors.nightVisionRed : Colors.white54));

    // 6. Cardinal labels (N, E, S, W)
    final textStyle = TextStyle(
      color: isRed ? AstroColors.nightVisionRed : Colors.white70,
      fontSize: 9,
      fontWeight: FontWeight.bold,
    );

    void drawCardinal(String label, Offset pos) {
      final tp = TextPainter(text: TextSpan(text: label, style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }

    final isPt = l10n.localeName.startsWith('pt');
    drawCardinal("N", Offset(center.dx, center.dy - radius - 6));
    drawCardinal(isPt ? "L" : "E", Offset(center.dx + radius + 6, center.dy));
    drawCardinal("S", Offset(center.dx, center.dy + radius + 6));
    drawCardinal(isPt ? "O" : "W", Offset(center.dx - radius - 6, center.dy));
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) {
    return oldDelegate.minAz != minAz || oldDelegate.maxAz != maxAz || oldDelegate.isRed != isRed || oldDelegate.l10n != l10n;
  }
}

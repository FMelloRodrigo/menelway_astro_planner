import 'package:flutter/material.dart';

import '../../models/filter_state.dart';
import '../../theme/astro_theme.dart';

class MiniHorizonPreviewPainter extends CustomPainter {
  final List<HorizonPointModel> points;
  final bool isRedNightMode;

  const MiniHorizonPreviewPainter({
    required this.points,
    required this.isRedNightMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final path = Path();
    final fillPath = Path();

    double azToX(double az) => (az / 360.0) * size.width;
    double altToY(double alt) => size.height - (alt / 90.0) * size.height;

    final firstY = altToY(points.first.altitude);

    path.moveTo(0, firstY);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, firstY);

    for (final p in points) {
      final x = azToX(p.azimuth);
      final y = altToY(p.altitude);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    final lastY = altToY(points.last.altitude);
    path.lineTo(size.width, lastY);
    fillPath.lineTo(size.width, lastY);
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : Colors.redAccent).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = isRedNightMode ? AstroColors.nightVisionRed : Colors.redAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant MiniHorizonPreviewPainter oldDelegate) =>
      oldDelegate.isRedNightMode != isRedNightMode ||
      oldDelegate.points != points;
}

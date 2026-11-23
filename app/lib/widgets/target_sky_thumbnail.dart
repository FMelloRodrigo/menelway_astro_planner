import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../core/sky_image_service.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import 'fov_projector.dart';
import 'target_renderers/target_body_renderer.dart';

/// Compact thumbnail widget that streams a target's sky survey image using the
/// same HiPS2FITS / ESA HEALPix pipeline and recommended FOV framing as
/// [TargetPreviewCanvas], with a clean vector fallback while loading or offline.
class TargetSkyThumbnail extends StatefulWidget {
  final TargetItem target;
  final double size;
  final bool? isRedNightMode;
  final BorderRadius borderRadius;

  const TargetSkyThumbnail({
    super.key,
    required this.target,
    this.size = 104.0,
    this.isRedNightMode,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  State<TargetSkyThumbnail> createState() => _TargetSkyThumbnailState();
}

class _TargetSkyThumbnailState extends State<TargetSkyThumbnail> {
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _hasError = false;
  int _requestId = 0;
  late SkySurveyProvider _lastProvider;

  @override
  void initState() {
    super.initState();
    _lastProvider = SkyImageService.instance.provider;
    SkyImageService.instance.addListener(_onSkyServiceChanged);
    if (widget.target.catalog != 'Solar System') {
      _loadImage();
    }
  }

  @override
  void didUpdateWidget(covariant TargetSkyThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.id != widget.target.id ||
        oldWidget.target.raHours != widget.target.raHours ||
        oldWidget.target.decDegrees != widget.target.decDegrees ||
        oldWidget.target.catalog != widget.target.catalog) {
      _requestId++;
      _imageBytes = null;
      _hasError = false;
      _isLoading = false;
      if (widget.target.catalog != 'Solar System') {
        _loadImage();
      }
    }
  }

  @override
  void dispose() {
    _requestId++;
    SkyImageService.instance.removeListener(_onSkyServiceChanged);
    super.dispose();
  }

  void _onSkyServiceChanged() {
    if (!mounted) return;
    final currentProvider = SkyImageService.instance.provider;
    if (currentProvider != _lastProvider) {
      _lastProvider = currentProvider;
      if (widget.target.catalog != 'Solar System') {
        _loadImage();
      }
    }
  }

  double get _fovDeg =>
      SkyImageService.computeRecommendedFovDeg(widget.target.majorAxisArcmin);

  Future<void> _loadImage() async {
    final reqId = ++_requestId;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final url = SkyImageService.buildHiPSUrl(
      raHours: widget.target.raHours,
      decDegrees: widget.target.decDegrees,
      fovDeg: _fovDeg,
      surveyId: SkyImageService.defaultSurveyId,
      width: 512,
      height: 512,
    );

    final bytes = await SkyImageService.instance.fetchSkyImage(url);

    if (mounted && reqId == _requestId) {
      setState(() {
        _isLoading = false;
        if (bytes != null && bytes.isNotEmpty) {
          _imageBytes = bytes;
          _hasError = false;
        } else {
          _hasError = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AstroPalette.of(context);
    final effectiveRedMode = widget.isRedNightMode ?? palette.isRedNightMode;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: widget.borderRadius,
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_imageBytes != null)
            Image.memory(
              _imageBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              color: effectiveRedMode ? AstroColors.nightVisionRed : null,
              colorBlendMode: effectiveRedMode ? BlendMode.modulate : null,
            )
          else
            CustomPaint(
              painter: _ThumbnailVectorPainter(
                target: widget.target,
                fovDeg: _fovDeg,
                isRedNightMode: effectiveRedMode,
              ),
            ),
          if (_isLoading && _imageBytes == null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: palette.accent,
                  ),
                ),
              ),
            )
          else if (_hasError && _imageBytes == null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 12,
                  color: Colors.amber,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThumbnailVectorPainter extends CustomPainter {
  final TargetItem target;
  final double fovDeg;
  final bool isRedNightMode;

  const _ThumbnailVectorPainter({
    required this.target,
    required this.fovDeg,
    required this.isRedNightMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final projector = FovProjector(
      viewportSize: size,
      fovDeg: fovDeg,
    );
    final center = projector.viewportCenter;

    final primaryColor =
        isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final secondaryColor =
        isRedNightMode ? AstroColors.nightVisionRedDim : AstroColors.nebulaIndigo;
    final goldColor =
        isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold;

    final bgRect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: isRedNightMode
            ? const [Color(0xFF220808), Color(0xFF0D0202)]
            : const [Color(0xFF0F172A), Color(0xFF050811)],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    final starRandom = math.Random(target.id * 31 + 17);
    final starPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 24; i++) {
      final sx = starRandom.nextDouble() * size.width;
      final sy = starRandom.nextDouble() * size.height;
      final distToCenter = (Offset(sx, sy) - center).distance;
      if (distToCenter < 12) continue;

      final magNorm = starRandom.nextDouble();
      final radius = 0.5 + (1.0 - magNorm) * 1.1;
      final opacity = 0.25 + (1.0 - magNorm) * 0.6;
      starPaint.color =
          (isRedNightMode ? AstroColors.nightVisionRed : Colors.white)
              .withValues(alpha: opacity);
      canvas.drawCircle(Offset(sx, sy), radius, starPaint);
    }

    final radii = projector.calculateTargetRadii(
      target.majorAxisArcmin,
      target.surfaceBrightness,
    );
    final renderer = TargetBodyRenderer.selectRenderer(target);
    renderer.render(
      canvas,
      target: target,
      projector: projector,
      radii: radii,
      isRedNightMode: isRedNightMode,
      isVectorOnly: true,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      goldColor: goldColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ThumbnailVectorPainter oldDelegate) {
    return oldDelegate.target.id != target.id ||
        oldDelegate.fovDeg != fovDeg ||
        oldDelegate.isRedNightMode != isRedNightMode;
  }
}

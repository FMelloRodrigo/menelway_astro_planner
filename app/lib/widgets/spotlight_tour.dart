import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/astro_theme.dart';

class SpotlightTourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final IconData icon;
  final EdgeInsets padding;
  final double borderRadius;

  const SpotlightTourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    this.padding = const EdgeInsets.all(6),
    this.borderRadius = 10,
  });
}

class SpotlightTour {
  static OverlayEntry? _currentOverlay;

  /// Shows the interactive spotlight tour with the given steps.
  static void show({
    required BuildContext context,
    required List<SpotlightTourStep> steps,
    required bool isRedNightMode,
    VoidCallback? onFinished,
    VoidCallback? onSkipped,
  }) {
    if (steps.isEmpty) return;
    dismiss();

    final overlayState = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _SpotlightTourWidget(
        steps: steps,
        isRedNightMode: isRedNightMode,
        onDismiss: () {
          dismiss();
          onSkipped?.call();
        },
        onFinish: () {
          dismiss();
          onFinished?.call();
        },
      ),
    );

    _currentOverlay = entry;
    overlayState.insert(entry);
  }

  /// Dismisses any active spotlight tour.
  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Returns true if a tour is currently active.
  static bool get isShowing => _currentOverlay != null;
}

class _SpotlightTourWidget extends StatefulWidget {
  final List<SpotlightTourStep> steps;
  final bool isRedNightMode;
  final VoidCallback onDismiss;
  final VoidCallback onFinish;

  const _SpotlightTourWidget({
    required this.steps,
    required this.isRedNightMode,
    required this.onDismiss,
    required this.onFinish,
  });

  @override
  State<_SpotlightTourWidget> createState() => _SpotlightTourWidgetState();
}

class _SpotlightTourWidgetState extends State<_SpotlightTourWidget>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex < widget.steps.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      widget.onFinish();
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  Rect? _getTargetRect(SpotlightTourStep step) {
    final context = step.targetKey.currentContext;
    if (context == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    return Rect.fromLTWH(
      offset.dx - step.padding.left,
      offset.dy - step.padding.top,
      size.width + step.padding.horizontal,
      size.height + step.padding.vertical,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentStep = widget.steps[_currentIndex];
    final targetRect = _getTargetRect(currentStep);
    final screenSize = MediaQuery.of(context).size;

    final accentColor = widget.isRedNightMode
        ? AstroColors.nightVisionRed
        : AstroColors.starlightCyan;
    final secondaryAccent = widget.isRedNightMode
        ? AstroColors.nightVisionRedDim
        : AstroColors.starGold;
    final cardBg = widget.isRedNightMode
        ? const Color(0xFF1E0303)
        : const Color(0xFF111726);
    final borderColor = widget.isRedNightMode
        ? AstroColors.nightVisionRed.withValues(alpha: 0.6)
        : AstroColors.starlightCyan.withValues(alpha: 0.4);
    final textColor = widget.isRedNightMode
        ? AstroColors.nightVisionRed
        : Colors.white;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onDismiss();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _next();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _prev();
          }
        }
      },
      child: Stack(
        children: [
          // 1. Animated Cutout Backdrop Painter
          AnimatedBuilder(
            animation: _pulseController,
            builder: (ctx, child) {
              return CustomPaint(
                size: screenSize,
                painter: _SpotlightCutoutPainter(
                  targetRect: targetRect,
                  borderRadius: currentStep.borderRadius,
                  glowProgress: _pulseController.value,
                  accentColor: accentColor,
                  isRedNightMode: widget.isRedNightMode,
                ),
              );
            },
          ),

          // 2. Click catcher around the target to allow proceeding by clicking the hole
          if (targetRect != null)
            Positioned.fromRect(
              rect: targetRect,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _next,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

          // 3. Floating Callout Card
          _buildCalloutCard(
            context: context,
            l10n: l10n,
            targetRect: targetRect,
            screenSize: screenSize,
            currentStep: currentStep,
            accentColor: accentColor,
            secondaryAccent: secondaryAccent,
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildCalloutCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required Rect? targetRect,
    required Size screenSize,
    required SpotlightTourStep currentStep,
    required Color accentColor,
    required Color secondaryAccent,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
  }) {
    const double cardWidth = 380.0;
    const double margin = 16.0;

    double topPos = 120.0;
    double leftPos = (screenSize.width - cardWidth) / 2;

    if (targetRect != null) {
      // Determine vertical clearance
      final spaceBelow = screenSize.height - targetRect.bottom;
      final spaceAbove = targetRect.top;

      if (spaceBelow >= 220 || spaceBelow >= spaceAbove) {
        // Place below the target
        topPos = targetRect.bottom + 14.0;
      } else {
        // Place above the target
        topPos = math.max(margin, targetRect.top - 230.0);
      }

      // Horizontal alignment: try aligning with target center
      leftPos = targetRect.center.dx - (cardWidth / 2);
      // Clamp within screen bounds
      leftPos = leftPos.clamp(margin, math.max(margin, screenSize.width - cardWidth - margin));
    }

    final isLastStep = _currentIndex == widget.steps.length - 1;

    return Positioned(
      top: topPos,
      left: leftPos,
      width: math.min(cardWidth, screenSize.width - (margin * 2)),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 30,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Step pill badge + Skip button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(currentStep.icon, size: 14, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          l10n.tourStepIndicator(_currentIndex + 1, widget.steps.length),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: textColor.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: widget.onDismiss,
                    child: Text(
                      l10n.tourSkip,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                currentStep.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                currentStep.description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: textColor.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Actions: Back button + Next / Finish button
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_currentIndex > 0)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor.withValues(alpha: 0.9),
                          side: BorderSide(color: textColor.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _prev,
                        child: Text(
                          l10n.tourBack,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: widget.isRedNightMode ? Colors.black : const Color(0xFF0A0F1D),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 4,
                      ),
                      icon: Icon(
                        isLastStep ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isLastStep
                            ? (l10n.tourFinish)
                            : (l10n.tourNext),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightCutoutPainter extends CustomPainter {
  final Rect? targetRect;
  final double borderRadius;
  final double glowProgress;
  final Color accentColor;
  final bool isRedNightMode;

  _SpotlightCutoutPainter({
    required this.targetRect,
    required this.borderRadius,
    required this.glowProgress,
    required this.accentColor,
    required this.isRedNightMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayColor = isRedNightMode
        ? const Color(0xDD0B0101)
        : const Color(0xCC050810);

    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect == null) {
      canvas.drawPath(bgPath, Paint()..color = overlayColor);
      return;
    }

    final cutoutRRect = RRect.fromRectAndRadius(
      targetRect!,
      Radius.circular(borderRadius),
    );

    final cutoutPath = Path()..addRRect(cutoutRRect);

    // Subtract cutout from dark overlay
    final combinedPath = Path.combine(PathOperation.difference, bgPath, cutoutPath);
    canvas.drawPath(combinedPath, Paint()..color = overlayColor);

    // Draw animated outer pulsing glow halo
    final glowSpread = 2.0 + (glowProgress * 4.0);
    final glowAlpha = 0.25 + (glowProgress * 0.45);
    final glowRRect = RRect.fromRectAndRadius(
      targetRect!.inflate(glowSpread),
      Radius.circular(borderRadius + glowSpread),
    );

    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + (glowProgress * 2.0)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 + (glowProgress * 4.0));
    canvas.drawRRect(glowRRect, glowPaint);

    // Draw crisp inner boundary ring
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(cutoutRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightCutoutPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.glowProgress != glowProgress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isRedNightMode != isRedNightMode;
  }
}

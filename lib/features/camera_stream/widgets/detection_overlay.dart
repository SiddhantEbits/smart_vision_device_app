import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/responsive_num_extension.dart';
import '../../../../data/models/detected_object.dart';

class DetectionOverlay extends StatelessWidget {
  final RxList<DetectedObject> detections;

  /// IDs of people currently inside restricted area
  final Set<int> restrictedIds;

  final bool onlyPersons;

  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.restrictedIds,
    this.onlyPersons = true,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Obx(() => CustomPaint(
        size: Size.infinite,
        painter: _DetectionPainter(
          detections: detections.toList(),
          restrictedIds: restrictedIds,
          onlyPersons: onlyPersons,
        ),
      )),
    );
  }
}

// ===================================================================
// PAINTER
// ===================================================================

class _DetectionPainter extends CustomPainter {
  final List<DetectedObject> detections;
  final Set<int> restrictedIds;
  final bool onlyPersons;

  // Reused paints (VERY important for performance)
  static final Paint _boxPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.adaptSize
    ..isAntiAlias = false;

  static final Paint _fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;

  static final TextStyle _labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 10.adaptSize,
    fontWeight: FontWeight.w600,
  );

  _DetectionPainter({
    required this.detections,
    required this.restrictedIds,
    required this.onlyPersons,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    for (final d in detections) {
      if (onlyPersons &&
          d.label.toLowerCase() != AppConstants.defaultDetectClass) {
        continue;
      }

      final bool isRestricted = restrictedIds.contains(d.id);

      // --------------------------------------------------
      // COLORS: Red for restricted, Cyan for normal
      // --------------------------------------------------
      _boxPaint.color = isRestricted ? Colors.redAccent : Colors.cyanAccent;
      _fillPaint.color = isRestricted
          ? Colors.red.withOpacity(0.55)
          : Colors.black.withOpacity(0.45);

      // --------------------------------------------------
      // NORMALIZED → SCREEN SPACE
      // --------------------------------------------------
      final rect = Rect.fromLTRB(
        d.bbox.left * size.width,
        d.bbox.top * size.height,
        d.bbox.right * size.width,
        d.bbox.bottom * size.height,
      );

      // --------------------------------------------------
      // BOX
      // --------------------------------------------------
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(4.adaptSize),
        ),
        _boxPaint,
      );

      // --------------------------------------------------
      // LABEL
      // --------------------------------------------------
      final label = isRestricted
          ? "RESTRICTED ${(d.confidence * 100).toStringAsFixed(0)}%"
          : "person ${(d.confidence * 100).toStringAsFixed(0)}%";

      final tp = TextPainter(
        text: TextSpan(text: label, style: _labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      final padX = 4.adaptSize;
      final padY = 2.adaptSize;

      double top = rect.top - tp.height - 4.adaptSize;
      if (top < 0) top = rect.top + 4.adaptSize;

      final labelRect = Rect.fromLTWH(
        rect.left,
        top,
        tp.width + padX * 2,
        tp.height + padY * 2,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          labelRect,
          Radius.circular(3.adaptSize),
        ),
        _fillPaint,
      );

      tp.paint(
        canvas,
        Offset(labelRect.left + padX, labelRect.top + padY),
      );
    }
  }

  @override
  bool shouldRepaint(_DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.restrictedIds != restrictedIds ||
        oldDelegate.onlyPersons != onlyPersons;
  }
}

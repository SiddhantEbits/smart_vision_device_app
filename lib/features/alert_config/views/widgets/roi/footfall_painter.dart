import 'package:flutter/material.dart';
import 'package:smart_vision_device_app/data/models/roi_config_model.dart';

class FootfallPainter extends CustomPainter {
  final RoiAlertConfig config;

  /// 🔑 Controls whether footfall line + direction are drawn
  final bool showLine;

  FootfallPainter(
    this.config, {
    this.showLine = true, // default = FOOTFALL
  });

  @override
  void paint(Canvas canvas, Size size) {
    // =========================================================
    // ROI (ALWAYS DRAWN)
    // =========================================================
    final roi = Rect.fromLTRB(
      config.roi.left * size.width,
      config.roi.top * size.height,
      config.roi.right * size.width,
      config.roi.bottom * size.height,
    );

    final roiPaint = Paint()
      ..color = Colors.green.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final roiBorder = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(roi, roiPaint);
    canvas.drawRect(roi, roiBorder);

    // =========================================================
    // FOOTFALL LINE + DIRECTION (ONLY IF ENABLED)
    // =========================================================
    if (!showLine) return;

    final linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final start = Offset(
      config.lineStart.dx * size.width,
      config.lineStart.dy * size.height,
    );

    final end = Offset(
      config.lineEnd.dx * size.width,
      config.lineEnd.dy * size.height,
    );

    // Footfall line
    canvas.drawLine(start, end, linePaint);

    // Direction arrow
    final center = (start + end) / 2;
    final dir = config.direction * 30;

    canvas.drawLine(
      center,
      center + Offset(dir.dx, dir.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant FootfallPainter oldDelegate) {
    return oldDelegate.config != config || oldDelegate.showLine != showLine;
  }
}

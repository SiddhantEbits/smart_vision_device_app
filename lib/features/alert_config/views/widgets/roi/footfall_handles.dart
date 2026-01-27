import 'package:flutter/material.dart';
import 'package:smart_vision_device_app/core/constants/app_enums.dart';
import 'package:smart_vision_device_app/data/models/roi_config_model.dart';

class FootfallHandles {
  FootfallEditMode mode = FootfallEditMode.none;

  static const double _hitRadius = 0.04;
  static const double _minRoiSize = 0.08;

  // ============================================================
  // HIT TEST
  // ============================================================
  FootfallEditMode hitTest(Offset pos, RoiAlertConfig c) {
    // ROI corners (highest priority)
    if (_near(pos, c.roi.topLeft)) return FootfallEditMode.roiTopLeft;
    if (_near(pos, c.roi.topRight)) return FootfallEditMode.roiTopRight;
    if (_near(pos, c.roi.bottomLeft)) return FootfallEditMode.roiBottomLeft;
    if (_near(pos, c.roi.bottomRight)) return FootfallEditMode.roiBottomRight;

    // Line endpoints
    if (_near(pos, c.lineStart)) return FootfallEditMode.lineStart;
    if (_near(pos, c.lineEnd)) return FootfallEditMode.lineEnd;

    // Arrow (line center)
    final center = (c.lineStart + c.lineEnd) / 2;
    if (_near(pos, center)) return FootfallEditMode.arrow;

    // ROI move
    if (c.roi.contains(pos)) return FootfallEditMode.roiMove;

    return FootfallEditMode.none;
  }

  // ============================================================
  // UPDATE CONFIG
  // ============================================================
  RoiAlertConfig update({
    required RoiAlertConfig config,
    required Offset delta,
  }) {
    // Clamp delta to avoid jumps
    delta = Offset(
      delta.dx.clamp(-0.05, 0.05),
      delta.dy.clamp(-0.05, 0.05),
    );

    switch (mode) {
      case FootfallEditMode.roiMove:
        return config.copyWith(
          roi: _moveRect(config.roi, delta),
        );

      case FootfallEditMode.roiTopLeft:
        return _resizeROI(config, delta, tl: true);

      case FootfallEditMode.roiTopRight:
        return _resizeROI(config, delta, tr: true);

      case FootfallEditMode.roiBottomLeft:
        return _resizeROI(config, delta, bl: true);

      case FootfallEditMode.roiBottomRight:
        return _resizeROI(config, delta, br: true);

      case FootfallEditMode.lineStart:
        return config.copyWith(
          lineStart: _clamp(config.lineStart + delta),
        );

      case FootfallEditMode.lineEnd:
        return config.copyWith(
          lineEnd: _clamp(config.lineEnd + delta),
        );

      case FootfallEditMode.arrow:
        final center = (config.lineStart + config.lineEnd) / 2;
        final dir = (center + delta) - center;
        return config.copyWith(direction: _normalize(dir));

      case FootfallEditMode.none:
        return config;
    }
  }

  // ============================================================
  // ROI RESIZE
  // ============================================================
  RoiAlertConfig _resizeROI(
    RoiAlertConfig c,
    Offset d, {
    bool tl = false,
    bool tr = false,
    bool bl = false,
    bool br = false,
  }) {
    double l = c.roi.left;
    double t = c.roi.top;
    double r = c.roi.right;
    double b = c.roi.bottom;

    if (tl) { l += d.dx; t += d.dy; }
    if (tr) { r += d.dx; t += d.dy; }
    if (bl) { l += d.dx; b += d.dy; }
    if (br) { r += d.dx; b += d.dy; }

    // Enforce min size
    if (r - l < _minRoiSize || b - t < _minRoiSize) return c;

    l = l.clamp(0.0, 1.0);
    t = t.clamp(0.0, 1.0);
    r = r.clamp(0.0, 1.0);
    b = b.clamp(0.0, 1.0);

    return c.copyWith(
      roi: Rect.fromLTRB(l, t, r, b),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  bool _near(Offset a, Offset b) => (a - b).distance <= _hitRadius;

  Offset _clamp(Offset p) => Offset(
        p.dx.clamp(0.0, 1.0),
        p.dy.clamp(0.0, 1.0),
      );

  Rect _moveRect(Rect r, Offset d) {
    final moved = r.shift(d);

    final left = moved.left.clamp(0.0, 1.0 - r.width);
    final top = moved.top.clamp(0.0, 1.0 - r.height);

    return Rect.fromLTWH(left, top, r.width, r.height);
  }

  Offset _normalize(Offset v) {
    final len = v.distance;
    if (len < 0.0001) return const Offset(0, 1);
    return v / len;
  }
}

import 'package:flutter/material.dart';
import 'package:smart_vision_device_app/core/constants/app_enums.dart';
import 'package:smart_vision_device_app/data/models/roi_config_model.dart';
import 'package:smart_vision_device_app/core/constants/responsive_num_extension.dart';
import 'footfall_painter.dart';
import 'footfall_handles.dart';

class FootfallCanvas extends StatefulWidget {
  final RoiAlertConfig config;
  final ValueChanged<RoiAlertConfig> onChanged;
  final bool interactive;

  /// 🔑 UI CONTROL: show/hide line & direction
  final bool showLine;

  const FootfallCanvas({
    super.key,
    required this.config,
    required this.onChanged,
    this.interactive = true,
    this.showLine = true, // default = FOOTFALL
  });

  @override
  State<FootfallCanvas> createState() => _FootfallCanvasState();
}

class _FootfallCanvasState extends State<FootfallCanvas> {
  final FootfallHandles _handles = FootfallHandles();
  Size _size = Size.zero;

  Offset _toNormalized(Offset local) => Offset(
        (local.dx / _size.width).clamp(0.0, 1.0),
        (local.dy / _size.height).clamp(0.0, 1.0),
      );

  Offset _toNormalizedDelta(Offset delta) => Offset(
        delta.dx / _size.width,
        delta.dy / _size.height,
      );

  Offset _toLocal(Offset n) => Offset(n.dx * _size.width, n.dy * _size.height);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);

        return IgnorePointer(
          ignoring: !widget.interactive,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              final pos = _toNormalized(d.localPosition);
              _handles.mode = _handles.hitTest(
                pos,
                widget.config,
              );
            },
            onPanUpdate: (d) {
              if (_handles.mode == FootfallEditMode.none) return;

              widget.onChanged(
                _handles.update(
                  config: widget.config,
                  delta: _toNormalizedDelta(d.delta),
                ),
              );
            },
            onPanEnd: (_) => _handles.mode = FootfallEditMode.none,
            child: Stack(
              children: [
                // Paint ROI + optional line
                CustomPaint(
                  size: Size.infinite,
                  painter: FootfallPainter(
                    widget.config,
                    showLine: widget.showLine,
                  ),
                ),

                // ROI handles (ALWAYS)
                ..._roiHandles(),

                // Line & direction handles (ONLY IF ENABLED)
                if (widget.showLine) ...[
                  _handleDot(widget.config.lineStart, Colors.red),
                  _handleDot(widget.config.lineEnd, Colors.red),
                  _handleDot(
                    (widget.config.lineStart + widget.config.lineEnd) / 2,
                    Colors.orange,
                  ),
                ],

                // Reset button on the left side
                Positioned(
                  left: 8.adaptSize,
                  bottom: 70.adaptSize,
                  child: _buildResetButton(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _roiHandles() {
    final roi = widget.config.roi;
    // Use red for restricted area, green for footfall
    final handleColor = widget.config.isRestrictedArea ? Colors.red : Colors.green;
    
    return [
      _handleDot(roi.topLeft, handleColor),
      _handleDot(roi.topRight, handleColor),
      _handleDot(roi.bottomLeft, handleColor),
      _handleDot(roi.bottomRight, handleColor),
    ];
  }

  Widget _handleDot(Offset n, Color color) {
    final p = _toLocal(n);
    return Positioned(
      left: p.dx - 6.adaptSize,
      top: p.dy - 6.adaptSize,
      child: Container(
        width: 12.adaptSize,
        height: 12.adaptSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.adaptSize),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4.adaptSize),
      ),
      child: IconButton(
        icon: Icon(
          Icons.refresh,
          color: Colors.white,
          size: 20.adaptSize,
        ),
        onPressed: () {
          widget.onChanged(RoiAlertConfig.forFootfall());
        },
        tooltip: 'Reset to default',
        padding: EdgeInsets.all(4.adaptSize),
        constraints: BoxConstraints(
          minWidth: 32.adaptSize,
          minHeight: 32.adaptSize,
        ),
      ),
    );
  }
}

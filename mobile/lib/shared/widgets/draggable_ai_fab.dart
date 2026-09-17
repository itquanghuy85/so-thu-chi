import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Nút AI chat nhanh — kéo lên/xuống dọc mép phải màn hình.
///
/// Chỉ trượt theo trục Y, offset X luôn cố định sát mép phải, để nút không
/// bao giờ đè lên nội dung chính giữa màn hình. Widget này cố tình **không**
/// phụ thuộc Riverpod/auth để test được độc lập; phần đọc/ghi vị trí đã lưu
/// nằm ở phía gọi (`MainShellScreen`), truyền vào qua [initialTopRatio] và
/// [onTopRatioChanged].
class DraggableAiFab extends StatefulWidget {
  /// Called when the button is tapped (without a drag).
  final VoidCallback onTap;

  /// Vị trí đã lưu lần trước, biểu diễn theo **tỉ lệ** 0..1 của khoảng trượt
  /// dọc (`top / maxTop`) chứ không phải pixel tuyệt đối — nhờ vậy vị trí vẫn
  /// đúng khi đổi độ phân giải hoặc xoay màn hình. `null` = chưa có vị trí
  /// lưu, dùng mặc định (xem [_defaultBottomInset]).
  final double? initialTopRatio;

  /// Gọi khi người dùng **thả tay** sau khi kéo, kèm tỉ lệ 0..1 mới. Không gọi
  /// trong lúc đang kéo để tránh ghi storage mỗi frame.
  final ValueChanged<double>? onTopRatioChanged;

  const DraggableAiFab({
    super.key,
    required this.onTap,
    this.initialTopRatio,
    this.onTopRatioChanged,
  });

  @override
  State<DraggableAiFab> createState() => _DraggableAiFabState();
}

class _DraggableAiFabState extends State<DraggableAiFab> {
  static const double _size = 48;
  static const double _margin = 16;

  /// Nút mặc định được nâng lên trên dải FAB của các màn con (các FAB
  /// `endFloat` chuẩn của Material cao 56px, cách đáy vùng nội dung 16px) để
  /// hai nút không chồng lên nhau ở lần mở app đầu tiên.
  static const double _defaultBottomInset = 88;

  /// Only Y changes; X is always pinned to the right edge.
  double? _top;

  /// Ratio waiting to be turned into a pixel offset on the next build — the
  /// available height is only known inside [LayoutBuilder].
  double? _pendingRatio;

  /// Gesture origin of the current drag, so the button tracks the finger
  /// absolutely instead of accumulating deltas (which would drift when the
  /// position is clamped at an edge).
  double? _dragStartTop;
  double? _dragStartY;

  /// `initialTopRatio` is applied at most once, and only if the user has not
  /// dragged yet — the provider reads its value asynchronously, so it can
  /// arrive after the first frame.
  bool _ratioApplied = false;

  @override
  void didUpdateWidget(covariant DraggableAiFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTopRatio != widget.initialTopRatio) {
      _ratioApplied = false;
      _maybeApplyRatio();
    }
  }

  @override
  void initState() {
    super.initState();
    _maybeApplyRatio();
  }

  void _maybeApplyRatio() {
    final ratio = widget.initialTopRatio;
    if (ratio == null || _ratioApplied || _top != null) return;
    _ratioApplied = true;
    _pendingRatio = ratio.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Defensive `math.max`: a very short viewport would otherwise make the
      // upper bound smaller than the lower one and `clamp` would throw.
      final maxX = math.max(0.0, constraints.maxWidth - _size - _margin);
      final maxY = math.max(0.0, constraints.maxHeight - _size - _margin);

      final pending = _pendingRatio;
      if (pending != null) {
        _pendingRatio = null;
        _top = pending * maxY;
      }

      final defaultTop = math.max(0.0, maxY - _defaultBottomInset);
      final y = _top?.clamp(0.0, maxY) ?? defaultTop;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: maxX,
            top: y,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (d) {
                _dragStartTop = y;
                _dragStartY = d.globalPosition.dy;
              },
              onVerticalDragUpdate: (d) {
                if (_dragStartTop == null || _dragStartY == null) return;
                final nt = (_dragStartTop! + (d.globalPosition.dy - _dragStartY!)).clamp(0.0, maxY);
                setState(() => _top = nt);
              },
              onVerticalDragEnd: (_) {
                _dragStartTop = null;
                _dragStartY = null;
                final top = _top;
                if (top != null && maxY > 0) {
                  widget.onTopRatioChanged?.call((top / maxY).clamp(0.0, 1.0));
                }
              },
              onVerticalDragCancel: () {
                _dragStartTop = null;
                _dragStartY = null;
              },
              onTap: widget.onTap,
              child: Tooltip(
                message: 'Trợ lý AI',
                child: Material(
                  color: const Color(0xFF6C63FF),
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: SizedBox(
                    width: _size,
                    height: _size,
                    child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
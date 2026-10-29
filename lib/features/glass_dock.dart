import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// A translucent, clipped backdrop with a lens that tracks horizontal scrubbing.
/// Page selection commits on release; a cancelled gesture restores the old tab.
class GlassDock extends StatefulWidget {
  const GlassDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  State<GlassDock> createState() => _GlassDockState();
}

class _GlassDockState extends State<GlassDock> {
  static const _padding = 6.0;
  static const _labels = ['日程', '课表', '我的'];
  static const _icons = [
    CupertinoIcons.calendar,
    CupertinoIcons.square_grid_2x2,
    CupertinoIcons.person,
  ];
  double? _dragPosition;
  int? _hoverIndex;
  bool _pointerCancelled = false;

  double _positionAt(double x, double cell) =>
      ((x - _padding - cell / 2) / cell).clamp(0.0, 2.0);
  void _select(int index, {bool feedback = true}) {
    if (index == widget.selectedIndex) return;
    if (feedback) HapticFeedback.selectionClick();
    widget.onSelected(index);
  }

  void _track(double x, double cell) {
    final position = _positionAt(x, cell);
    final index = position.round();
    if (_hoverIndex != null && _hoverIndex != index) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _dragPosition = position;
      _hoverIndex = index;
    });
  }

  void _end() {
    // Flutter can deliver drag-end, rather than drag-cancel, after an accepted
    // drag receives PointerCancel. Preserve the original tab in either case.
    if (_pointerCancelled) {
      _cancel();
      return;
    }
    final index = (_dragPosition ?? widget.selectedIndex.toDouble()).round();
    _select(index, feedback: false);
    _cancel();
  }

  void _cancel() => setState(() {
    _dragPosition = null;
    _hoverIndex = null;
  });

  @override
  Widget build(BuildContext context) {
    final dragging = _dragPosition != null;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final target = _dragPosition ?? widget.selectedIndex.toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 258.0);
        final cell = (width - _padding * 2) / 3;
        return AnimatedScale(
          scale: dragging && !reducedMotion ? 1.025 : 1,
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: width,
            height: 64,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x160B1933),
                    blurRadius: 22,
                    spreadRadius: -5,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: GestureDetector(
                    key: const Key('glass-dock'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (details) =>
                        _track(details.localPosition.dx, cell),
                    onHorizontalDragUpdate: (details) =>
                        _track(details.localPosition.dx, cell),
                    onHorizontalDragEnd: (_) => _end(),
                    onHorizontalDragCancel: _cancel,
                    child: Listener(
                      onPointerDown: (_) => _pointerCancelled = false,
                      onPointerCancel: (_) => _pointerCancelled = true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: highContrast
                                ? const [Color(0xE6FFFFFF), Color(0xD9F1F4FA)]
                                : const [
                                    Color(0x70FFFFFF),
                                    Color(0x25FFFFFF),
                                    Color(0x48EFF4FC),
                                  ],
                            stops: highContrast
                                ? const [0.0, 1.0]
                                : const [0.0, 0.48, 1.0],
                          ),
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: target),
                          duration: dragging || reducedMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          builder: (context, position, _) => Stack(
                            children: [
                              Positioned(
                                left: _padding + position * cell,
                                top: _padding,
                                width: cell,
                                height: 52,
                                child: IgnorePointer(
                                  child: AnimatedScale(
                                    scale: dragging && !reducedMotion
                                        ? 1.045
                                        : 1,
                                    duration: reducedMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 160),
                                    child: DecoratedBox(
                                      key: const Key('dock-indicator'),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xA3FFFFFF),
                                            Color(0x38D5E8FF),
                                            Color(0x70FFFFFF),
                                          ],
                                          stops: [0, 0.55, 1],
                                        ),
                                        border: Border.all(
                                          color: const Color(0xA6FFFFFF),
                                          width: 0.8,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x140D3157),
                                            blurRadius: 7,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(_padding),
                                  child: Row(
                                    children: [
                                      for (var i = 0; i < 3; i++)
                                        Expanded(
                                          child: Semantics(
                                            label: _labels[i],
                                            button: true,
                                            selected: widget.selectedIndex == i,
                                            onTap: () => _select(i),
                                            child: ExcludeSemantics(
                                              child: CupertinoButton(
                                                key: Key('tab-$i'),
                                                padding: EdgeInsets.zero,
                                                onPressed: () => _select(i),
                                                child: SizedBox(
                                                  width: double.infinity,
                                                  height: 52,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        _icons[i],
                                                        size:
                                                            20 +
                                                            (1 -
                                                                    (position -
                                                                            i)
                                                                        .abs())
                                                                .clamp(
                                                                  0.0,
                                                                  1.0,
                                                                ),
                                                        color: Color.lerp(
                                                          const Color(
                                                            0xFF5F6672,
                                                          ),
                                                          CupertinoColors
                                                              .activeBlue,
                                                          (1 -
                                                                  (position - i)
                                                                      .abs())
                                                              .clamp(0.0, 1.0),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Flexible(
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Text(
                                                            _labels[i],
                                                            maxLines: 1,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color.lerp(
                                                                const Color(
                                                                  0xFF5F6672,
                                                                ),
                                                                CupertinoColors
                                                                    .activeBlue,
                                                                (1 -
                                                                        (position -
                                                                                i)
                                                                            .abs())
                                                                    .clamp(
                                                                      0.0,
                                                                      1.0,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _GlassRimPainter(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final rim = RRect.fromRectAndRadius(
      bounds.deflate(0.6),
      const Radius.circular(32),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xEEFFFFFF),
          Color(0x40FFFFFF),
          Color(0x247B91AC),
          Color(0xA6FFFFFF),
        ],
        stops: [0, 0.34, 0.73, 1],
      ).createShader(bounds);
    canvas.drawRRect(rim, paint);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x42FFFFFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(2), const Radius.circular(30)),
      inner,
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) => false;
}

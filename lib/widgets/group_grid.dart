import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import 'primitives.dart';

/// Grid-shaped cousin of `DragList`: tap-to-select, drag-to-reorder.
/// Mirrors the vertical list's feel — on pickup a floating ghost with a
/// slight tilt, ink offset-shadow, and accent halo lifts out of the source
/// slot; neighbors slide to make room; on release the ghost tweens into the
/// landing slot while its chrome unwinds back to the flat resting state.
///
/// Designed for short fixed-width labels (muscle groups, filter chips) laid
/// out in a [crossAxisCount]-column grid.
class ReorderableGroupGrid extends StatefulWidget {
  final List<String> items;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final Widget Function(BuildContext context, String item) cellBuilder;
  final ValueChanged<String>? onTap;
  final ValueChanged<List<String>> onReorder;

  const ReorderableGroupGrid({
    super.key,
    required this.items,
    required this.cellBuilder,
    required this.onReorder,
    this.onTap,
    this.crossAxisCount = 3,
    this.crossAxisSpacing = 6,
    this.mainAxisSpacing = 6,
    this.childAspectRatio = 3.4,
  });

  @override
  State<ReorderableGroupGrid> createState() => _ReorderableGroupGridState();
}

class _ReorderableGroupGridState extends State<ReorderableGroupGrid>
    with SingleTickerProviderStateMixin {
  String? _dragItem;
  String? _hoverItem;
  final Map<String, GlobalKey> _keys = {};

  // Ghost overlay state — same shape as DragList's ghost.
  Offset? _ghostTopLeft;
  Size? _ghostSize;
  Offset _pointerLocal = Offset.zero;
  OverlayEntry? _overlay;
  BrutalPalette? _palette;

  // Drop-settle: ghost tweens from release position into the landing slot.
  AnimationController? _dropCtrl;
  Offset? _dropFrom;
  Offset? _dropTo;

  // Accent fades at drop START (not cleanup) so by the time the ghost lands
  // and the real cell re-appears, the accent is already invisible.
  bool _accentOn = false;

  GlobalKey _keyFor(String o) => _keys.putIfAbsent(o, () => GlobalKey());

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    _dropCtrl?.dispose();
    super.dispose();
  }

  Drag? _onDragStart(String o, Offset globalPosition) {
    if (_dropCtrl?.isAnimating ?? false) {
      _dropCtrl!.stop();
      _cleanupGhost();
    }

    final ctx = _keyFor(o).currentContext;
    if (ctx == null) return null;
    final rb = ctx.findRenderObject();
    if (rb is! RenderBox || !rb.attached) return null;
    final topLeft = rb.localToGlobal(Offset.zero);
    final size = rb.size;

    _palette = BrutalColors.of(context);
    setState(() {
      _dragItem = o;
      _hoverItem = o;
      _ghostTopLeft = topLeft;
      _ghostSize = size;
      _pointerLocal = globalPosition - topLeft;
      _accentOn = true;
    });
    _showOverlay();
    HapticFeedback.selectionClick();

    return _GridDrag(
      onUpdate: (d) => _onPointerMove(d.globalPosition),
      onEnd: (_) => _endDrag(commit: true),
      onCancel: () => _endDrag(commit: false),
    );
  }

  void _onPointerMove(Offset globalPos) {
    _ghostTopLeft = globalPos - _pointerLocal;
    // Skip the source when resolving hover (its own rect always contains the
    // pointer); fall back to the last hover when the pointer is between
    // cells so the preview doesn't flicker back to the source.
    String? nextHover;
    for (final o in widget.items) {
      if (o == _dragItem) continue;
      final ctx = _keys[o]?.currentContext;
      if (ctx == null) continue;
      final rb = ctx.findRenderObject();
      if (rb is! RenderBox || !rb.attached) continue;
      final pos = rb.localToGlobal(Offset.zero);
      final rect = pos & rb.size;
      if (rect.contains(globalPos)) {
        nextHover = o;
        break;
      }
    }
    if (nextHover != null && nextHover != _hoverItem) {
      setState(() => _hoverItem = nextHover);
    }
    _overlay?.markNeedsBuild();
  }

  void _endDrag({required bool commit}) {
    final from = _dragItem;
    final to = _hoverItem;
    final shouldCommit =
        commit && from != null && to != null && from != to;

    if (shouldCommit) {
      final list = List<String>.from(widget.items);
      final fromIdx = list.indexOf(from);
      final toIdx = list.indexOf(to);
      if (fromIdx >= 0 && toIdx >= 0) {
        list.removeAt(fromIdx);
        list.insert(toIdx, from);
        setState(() {
          _hoverItem = null;
          _accentOn = false;
        });
        widget.onReorder(list);
        _startDropSettle();
        return;
      }
    }
    // No commit (or degenerate indices): ghost still tweens home to the
    // source's current displayed slot so release doesn't read as a pop.
    setState(() {
      _hoverItem = null;
      _accentOn = false;
    });
    _startDropSettle();
  }

  void _startDropSettle() {
    final from = _dragItem;
    if (from == null) {
      _cleanupGhost();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _keys[from]?.currentContext;
      final rb = ctx?.findRenderObject();
      if (rb is! RenderBox || !rb.attached) {
        _cleanupGhost();
        return;
      }
      _dropFrom = _ghostTopLeft;
      _dropTo = rb.localToGlobal(Offset.zero);
      final ctrl = _dropCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      )..addListener(_onDropTick);
      ctrl.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        _cleanupGhost();
      });
    });
  }

  void _onDropTick() {
    final ctrl = _dropCtrl;
    final from = _dropFrom;
    final to = _dropTo;
    if (ctrl == null || from == null || to == null) return;
    final t = Curves.easeOutCubic.transform(ctrl.value);
    setState(() {
      _ghostTopLeft = Offset.lerp(from, to, t);
    });
    _overlay?.markNeedsBuild();
  }

  void _cleanupGhost() {
    _overlay?.remove();
    _overlay = null;
    // Reset dropT so the next pickup starts with k=1 (full lift chrome).
    _dropCtrl?.value = 0;
    setState(() {
      _dragItem = null;
      _hoverItem = null;
      _ghostTopLeft = null;
      _ghostSize = null;
      _dropFrom = null;
      _dropTo = null;
      _accentOn = false;
    });
  }

  void _showOverlay() {
    _overlay = OverlayEntry(builder: _buildGhost);
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  Widget _buildGhost(BuildContext _) {
    final top = _ghostTopLeft;
    final size = _ghostSize;
    final palette = _palette;
    final item = _dragItem;
    if (top == null || size == null || palette == null || item == null) {
      return const SizedBox.shrink();
    }
    // Interpolate chrome back to the cell's natural state during drop-settle
    // (k=1 at pickup → k=0 at landing), same formula as DragList.
    final dropT = _dropCtrl?.value ?? 0.0;
    final k = 1.0 - dropT;
    return Positioned(
      left: top.dx,
      top: top.dy,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -0.026 * k,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: 1.0 + 0.02 * k,
            alignment: Alignment.center,
            child: Opacity(
              opacity: 0.95 + 0.05 * dropT,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.paper,
                  boxShadow: [
                    BoxShadow(
                      color: palette.ink,
                      offset: Offset(6 * k, 6 * k),
                    ),
                    BoxShadow(
                      color: palette.accent,
                      spreadRadius: 3 * k,
                    ),
                  ],
                ),
                child: BrutalColors(
                  palette: palette,
                  child: Material(
                    type: MaterialType.transparency,
                    child: widget.cellBuilder(context, item),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _displayedItems() {
    if (_dragItem == null || _hoverItem == null || _dragItem == _hoverItem) {
      return widget.items;
    }
    final list = List<String>.from(widget.items);
    final from = list.indexOf(_dragItem!);
    final to = list.indexOf(_hoverItem!);
    if (from < 0 || to < 0) return widget.items;
    list.removeAt(from);
    list.insert(to, _dragItem!);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayedItems();
    final positionByItem = <String, int>{
      for (int i = 0; i < displayed.length; i++) displayed[i]: i,
    };
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = widget.crossAxisCount;
      final totalSpacingW = widget.crossAxisSpacing * (crossCount - 1);
      final cellW = (constraints.maxWidth - totalSpacingW) / crossCount;
      final cellH = cellW / widget.childAspectRatio;
      final rowCount = (widget.items.length / crossCount).ceil();
      final totalH = rowCount <= 0
          ? 0.0
          : rowCount * cellH + (rowCount - 1) * widget.mainAxisSpacing;
      return SizedBox(
        width: constraints.maxWidth,
        height: totalH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final item in widget.items)
              AnimatedPositioned(
                key: ValueKey('pos-$item'),
                duration: _dragItem == item
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: (positionByItem[item]! % crossCount) *
                    (cellW + widget.crossAxisSpacing),
                top: (positionByItem[item]! ~/ crossCount) *
                    (cellH + widget.mainAxisSpacing),
                width: cellW,
                height: cellH,
                child: KeyedSubtree(
                  key: _keyFor(item),
                  child: _GridCell(
                    dragging: _dragItem == item,
                    showAccent: _dragItem == item && _accentOn,
                    onTap: widget.onTap == null
                        ? null
                        : () => widget.onTap!(item),
                    onDragStart: (pos) => _onDragStart(item, pos),
                    child: widget.cellBuilder(context, item),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _GridCell extends StatelessWidget {
  final bool dragging;
  final bool showAccent;
  final VoidCallback? onTap;
  final Drag? Function(Offset globalPosition) onDragStart;
  final Widget child;
  const _GridCell({
    required this.dragging,
    required this.showAccent,
    required this.onTap,
    required this.onDragStart,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BrutalColors.of(context);
    final visual = Stack(
      children: [
        Visibility(
          visible: !dragging,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              opacity: showAccent ? 1 : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.accent,
                  border: Border.all(color: palette.ink, width: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return GestureDetector(
      onTap: onTap,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          ImmediateMultiDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  ImmediateMultiDragGestureRecognizer>(
            () => ImmediateMultiDragGestureRecognizer(),
            (r) {
              r.onStart = onDragStart;
            },
          ),
        },
        child: visual,
      ),
    );
  }
}

class _GridDrag extends Drag {
  final void Function(DragUpdateDetails) onUpdate;
  final void Function(DragEndDetails) onEnd;
  final VoidCallback onCancel;
  _GridDrag({
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  @override
  void update(DragUpdateDetails details) => onUpdate(details);

  @override
  void end(DragEndDetails details) => onEnd(details);

  @override
  void cancel() => onCancel();
}

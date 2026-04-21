import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'primitives.dart';

/// Wraps a widget to register it as the drag grip for its enclosing item.
/// Passed into [DragList.itemBuilder] as the last argument so the caller can
/// decorate only the handle glyph (⋮⋮) — not the whole card.
typedef DragHandleBuilder = Widget Function(Widget child);

typedef DragItemBuilder<T> = Widget Function(
  BuildContext context,
  int index,
  T item,
  DragHandleBuilder handle,
);

/// Custom reorderable list:
/// * pointer-down on the handle spawns a floating ghost (rotated −1.5°,
///   scaled 1.02, with an ink offset shadow and 3px accent halo);
/// * the list previews the new drop slot by moving the source in *display
///   order* — so list height is always constant (no gap bar expanding) and
///   releasing can never shrink the layout underneath you;
/// * the source card stays in layout as `visibility: hidden` so the slot is
///   reserved while the ghost floats;
/// * on release, the ghost tweens into the source's new rendered slot so
///   the drop doesn't read as a teleport;
/// * auto-scrolls when the pointer sits within 90px of the viewport edge.
class DragList<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) getId;
  final void Function(int fromIdx, int insertIdx) onReorder;
  final DragItemBuilder<T> itemBuilder;
  final double closedGap;
  final bool scrollable;
  final EdgeInsets padding;
  final ScrollController? scrollController;

  const DragList({
    super.key,
    required this.items,
    required this.getId,
    required this.onReorder,
    required this.itemBuilder,
    this.closedGap = 12,
    this.scrollable = true,
    this.padding = EdgeInsets.zero,
    this.scrollController,
  });

  @override
  State<DragList<T>> createState() => _DragListState<T>();
}

class _DragListState<T> extends State<DragList<T>>
    with SingleTickerProviderStateMixin {
  String? _dragId;
  int? _insertIdx;
  Offset? _ghostTopLeft;
  Size? _ghostSize;
  Offset _pointerLocal = Offset.zero;
  Offset _pointer = Offset.zero;
  // Separate from `_dragId`: the accent indicator fades out at *drop start*
  // (not at cleanup), so by the time the drop-settle finishes and the real
  // card becomes visible, the accent has already faded to 0. Otherwise the
  // AnimatedOpacity would start a visible 140ms fade right as the card
  // re-appears — that's the "flash" the user sees on release.
  bool _accentOn = false;

  final Map<String, GlobalKey> _cardKeys = {};
  final GlobalKey _listKey = GlobalKey();
  OverlayEntry? _overlay;
  ScrollController? _ownedScroll;
  Timer? _autoScrollTimer;
  BrutalPalette? _palette;

  // Drop-settle animation: on release the ghost tweens from the finger
  // position to the card's landing slot, so the dragged item doesn't
  // "teleport" into place (which reads as the page scrolling under you).
  AnimationController? _dropCtrl;
  Offset? _dropFrom;
  Offset? _dropTo;

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownedScroll ??= ScrollController());

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    _autoScrollTimer?.cancel();
    _ownedScroll?.dispose();
    _dropCtrl?.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _cardKeys.putIfAbsent(id, () => GlobalKey());

  // ─── drag lifecycle ───────────────────────────────────────────────────

  Drag? _onDragStart(String id, Offset globalPosition) {
    // If a drop-settle animation is still running, finalize it immediately
    // so the new drag starts from a clean slate.
    if (_dropCtrl?.isAnimating ?? false) {
      _dropCtrl!.stop();
      _cleanupGhost();
    }

    final key = _keyFor(id);
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final rb = ctx.findRenderObject() as RenderBox?;
    if (rb == null) return null;

    final topLeft = rb.localToGlobal(Offset.zero);
    final size = rb.size;
    final idx = widget.items.indexWhere((t) => widget.getId(t) == id);

    _palette = BrutalColors.of(context);
    setState(() {
      _dragId = id;
      _insertIdx = idx;
      _ghostTopLeft = topLeft;
      _ghostSize = size;
      _pointerLocal = globalPosition - topLeft;
      _pointer = globalPosition;
      _accentOn = true;
    });
    _showOverlay();
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollTick(),
    );

    return _ReorderDrag(
      onUpdate: _onPointerMove,
      onEnd: (_) => _endDrag(commit: true),
      onCancel: () => _endDrag(commit: false),
    );
  }

  void _onPointerMove(DragUpdateDetails d) {
    _pointer = d.globalPosition;
    final top = d.globalPosition - _pointerLocal;
    final newIdx = _computeInsertIdx(d.globalPosition.dy);
    setState(() {
      _ghostTopLeft = top;
      _insertIdx = newIdx;
    });
    _overlay?.markNeedsBuild();
  }

  void _endDrag({required bool commit}) {
    final fromId = _dragId;
    final insertIdx = _insertIdx;
    final fromIdx = fromId == null
        ? -1
        : widget.items.indexWhere((t) => widget.getId(t) == fromId);
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;

    final shouldMove = commit &&
        fromId != null &&
        fromIdx >= 0 &&
        insertIdx != null &&
        insertIdx != fromIdx &&
        insertIdx != fromIdx + 1;

    if (!shouldMove) {
      // Fade accent first so the snap-back doesn't flash. The ghost overlay
      // is removed inside `_cleanupGhost` so we don't need drop-settle here.
      setState(() => _accentOn = false);
      _cleanupGhost();
      return;
    }

    // Clear the preview and commit the reorder. The source keeps `_dragId`
    // set (and thus stays hidden) while the ghost tweens into the card's
    // final resting slot — the rebuild from onReorder puts the source at
    // its new position in `widget.items`, and its GlobalKey resolves to
    // that new slot on the next frame.
    setState(() {
      _insertIdx = null;
      // Start the accent fade NOW (during the 180ms drop-settle) so by the
      // time the ghost lands and cleanup exposes the real card, the accent
      // has already faded to 0.
      _accentOn = false;
    });
    widget.onReorder(fromIdx, insertIdx);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _cardKeys[fromId]?.currentContext;
      final rb = ctx?.findRenderObject();
      if (rb is! RenderBox || !rb.attached) {
        _cleanupGhost();
        return;
      }
      _dropFrom = _ghostTopLeft;
      _dropTo = rb.localToGlobal(Offset.zero);
      final ctrl = _dropCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 180),
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
    // Reset the drop-settle controller so the next pickup starts with
    // dropT=0 (→ k=1) and renders the full lift chrome (tilt, shadow,
    // accent halo). Without this it stays pinned at 1.0 after a commit
    // and the second+ pickup looks flat.
    _dropCtrl?.value = 0;
    setState(() {
      _dragId = null;
      _insertIdx = null;
      _ghostTopLeft = null;
      _ghostSize = null;
      _dropFrom = null;
      _dropTo = null;
      _accentOn = false;
    });
  }

  /// Insertion index in the original list (0..N), computed from the pointer
  /// y against the midpoints of the *non-source* items. Ignoring the source
  /// is what gives hysteresis: the source's own slot never counts as a
  /// boundary, so jitter around its current position doesn't flip the
  /// preview back and forth.
  int _computeInsertIdx(double y) {
    final items = widget.items;
    if (items.isEmpty) return 0;

    final srcIdx = _dragId == null
        ? -1
        : items.indexWhere((t) => widget.getId(t) == _dragId);

    // Collect (originalIndex, midY) for non-source items. Skip any whose
    // layout we can't measure yet — they just don't constrain the result.
    final nonSrc = <(int, double)>[];
    for (int i = 0; i < items.length; i++) {
      if (i == srcIdx) continue;
      final ctx = _keyFor(widget.getId(items[i])).currentContext;
      if (ctx == null) continue;
      final rb = ctx.findRenderObject();
      if (rb is! RenderBox || !rb.attached) continue;
      final pos = rb.localToGlobal(Offset.zero);
      nonSrc.add((i, pos.dy + rb.size.height / 2));
    }
    if (nonSrc.isEmpty) return srcIdx >= 0 ? srcIdx : 0;

    // Walk non-source midpoints in order and find the first whose mid is
    // below the pointer — that's the item the source would sit before.
    for (final (origIdx, mid) in nonSrc) {
      if (y < mid) return origIdx;
    }
    return items.length;
  }

  void _autoScrollTick() {
    if (_dragId == null) return;
    final listCtx = _listKey.currentContext;
    if (listCtx == null) return;

    // Walk up to the nearest Scrollable — that gives us the viewport render
    // box (state.context) and the ScrollPosition to drive. For scrollable:true
    // this finds our own SingleChildScrollView; for scrollable:false it finds
    // whatever scrollable is hosting the DragList.
    final state = Scrollable.maybeOf(listCtx);
    if (state == null) return;
    final viewport = state.context.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return;
    final rect = viewport.localToGlobal(Offset.zero) & viewport.size;

    const edge = 90.0;
    const maxVel = 16.0;
    double vel = 0;
    if (_pointer.dy < rect.top + edge) {
      vel = -maxVel *
          ((rect.top + edge - _pointer.dy) / edge).clamp(0.0, 1.0);
    } else if (_pointer.dy > rect.bottom - edge) {
      vel = maxVel *
          ((_pointer.dy - (rect.bottom - edge)) / edge).clamp(0.0, 1.0);
    }
    if (vel == 0) return;

    final pos = state.position;
    final next =
        (pos.pixels + vel).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (next == pos.pixels) return;
    pos.jumpTo(next);

    final newIdx = _computeInsertIdx(_pointer.dy);
    if (newIdx != _insertIdx) {
      setState(() => _insertIdx = newIdx);
    }
    _overlay?.markNeedsBuild();
  }

  // ─── overlay ghost ────────────────────────────────────────────────────

  void _showOverlay() {
    _overlay = OverlayEntry(builder: _buildGhost);
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  Widget _buildGhost(BuildContext _) {
    final top = _ghostTopLeft;
    final size = _ghostSize;
    final palette = _palette;
    if (top == null || size == null || palette == null) {
      return const SizedBox.shrink();
    }
    final idx =
        widget.items.indexWhere((t) => widget.getId(t) == _dragId);
    if (idx < 0) return const SizedBox.shrink();
    final item = widget.items[idx];
    // Interpolate ghost chrome back toward the card's natural appearance
    // during the drop-settle: rotation → 0, scale → 1, offset-shadow → 0,
    // accent halo → 0, so by the time the ghost reaches the slot it reads as
    // the real card rather than suddenly popping out of its dragged state.
    final dropT = _dropCtrl?.value ?? 0.0;
    final k = 1.0 - dropT;
    return Positioned(
      left: top.dx,
      top: top.dy,
      width: size.width,
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
                    child: widget.itemBuilder(
                      context,
                      idx,
                      item,
                      (child) => child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── build ────────────────────────────────────────────────────────────

  /// Items in the order they should be *rendered* during drag. The source is
  /// pulled out and re-inserted at the preview slot so the list's physical
  /// layout always has exactly N items with closedGap between them — no gap
  /// bar grows in and collapses on release.
  List<(int, T)> _displayOrder() {
    final items = widget.items;
    if (_dragId == null || _insertIdx == null) {
      return [for (int i = 0; i < items.length; i++) (i, items[i])];
    }
    final srcIdx = items.indexWhere((t) => widget.getId(t) == _dragId);
    if (srcIdx < 0) {
      return [for (int i = 0; i < items.length; i++) (i, items[i])];
    }
    final insertIdx = _insertIdx!;
    if (insertIdx == srcIdx || insertIdx == srcIdx + 1) {
      return [for (int i = 0; i < items.length; i++) (i, items[i])];
    }

    // insertIdx is expressed against the ORIGINAL list (0..N). Translate to
    // a post-removal position so it indexes into the non-source sequence.
    final targetPos = insertIdx > srcIdx ? insertIdx - 1 : insertIdx;
    final result = <(int, T)>[];
    int displayedPos = 0;
    for (int i = 0; i < items.length; i++) {
      if (i == srcIdx) continue;
      if (displayedPos == targetPos) {
        result.add((srcIdx, items[srcIdx]));
      }
      result.add((i, items[i]));
      displayedPos++;
    }
    if (result.length < items.length) {
      result.add((srcIdx, items[srcIdx]));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final displayed = _displayOrder();
    final children = <Widget>[];
    for (int k = 0; k < displayed.length; k++) {
      if (k > 0 && widget.closedGap > 0) {
        children.add(SizedBox(height: widget.closedGap));
      }
      final (origIdx, item) = displayed[k];
      final id = widget.getId(item);
      final isDragging = id == _dragId;
      // The accent indicator follows `_accentOn` (not `isDragging`) so it
      // can fade out at drop START — which finishes before the real card
      // reappears at cleanup, preventing the post-landing flash.
      final showAccent = isDragging && _accentOn;
      children.add(KeyedSubtree(
        key: _keyFor(id),
        child: Stack(
          children: [
            Visibility(
              visible: !isDragging,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: widget.itemBuilder(
                context,
                origIdx,
                item,
                (child) => _DragHandleListener(
                  onStart: (globalPos) => _onDragStart(id, globalPos),
                  child: child,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  opacity: showAccent ? 1 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.accent,
                      border: Border.all(color: p.ink, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ));
    }

    final column = Column(
      key: _listKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    if (widget.scrollable) {
      return SingleChildScrollView(
        controller: _scroll,
        padding: widget.padding,
        physics: _dragId == null
            ? null
            : const NeverScrollableScrollPhysics(),
        child: column,
      );
    }
    return Padding(padding: widget.padding, child: column);
  }
}

/// Wraps a drag grip. Uses [ImmediateMultiDragGestureRecognizer] so the
/// gesture claims the arena on pointer-down — a parent ScrollView can't steal
/// the gesture away on first vertical movement.
class _DragHandleListener extends StatelessWidget {
  final Widget child;
  final Drag? Function(Offset globalPosition) onStart;
  const _DragHandleListener({required this.child, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        ImmediateMultiDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                ImmediateMultiDragGestureRecognizer>(
          () => ImmediateMultiDragGestureRecognizer(),
          (r) {
            r.onStart = onStart;
          },
        ),
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: child,
      ),
    );
  }
}

class _ReorderDrag extends Drag {
  final void Function(DragUpdateDetails) onUpdate;
  final void Function(DragEndDetails) onEnd;
  final VoidCallback onCancel;
  _ReorderDrag({
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

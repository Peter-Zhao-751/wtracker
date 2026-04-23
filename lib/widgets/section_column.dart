import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import 'primitives.dart';

class SectionItem {
  final String key;
  final Widget child;
  const SectionItem({required this.key, required this.child});
}

/// Vertical column of cards that can be reordered via 500ms long-press +
/// drag. The whole card is the drag grip — no visible handle. Uses the same
/// insert-index semantics as [DragList] (release at the source's slot, or
/// the adjacent slot below it, is a no-op) so dropping where you picked up
/// lands the card back in place. Drives the enclosing [Scrollable] when the
/// pointer approaches the viewport edge so the user can drop outside the
/// initially-visible area.
///
/// Inner interactive children keep working: short taps resolve before the
/// 500ms delay, and inner [ImmediateMultiDragGestureRecognizer]s claim the
/// arena on motion before the outer delay fires.
class SectionColumn extends StatefulWidget {
  final List<SectionItem> sections;
  final void Function(List<String> newOrder) onReorder;
  final double gap;
  const SectionColumn({
    super.key,
    required this.sections,
    required this.onReorder,
    this.gap = 12,
  });

  @override
  State<SectionColumn> createState() => _SectionColumnState();
}

class _SectionColumnState extends State<SectionColumn>
    with TickerProviderStateMixin {
  String? _dragKey;
  int? _insertIdx;
  final Map<String, GlobalKey> _gKeys = {};
  final GlobalKey _listKey = GlobalKey();

  Offset? _ghostTopLeft;
  Size? _ghostSize;
  Offset _pointerLocal = Offset.zero;
  Offset _pointer = Offset.zero;
  OverlayEntry? _overlay;
  BrutalPalette? _palette;

  AnimationController? _dropCtrl;
  Offset? _dropFrom;
  Offset? _dropTo;
  AnimationController? _liftCtrl;
  Timer? _autoScrollTimer;

  GlobalKey _keyFor(String k) => _gKeys.putIfAbsent(k, () => GlobalKey());

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    _autoScrollTimer?.cancel();
    _dropCtrl?.dispose();
    _liftCtrl?.dispose();
    super.dispose();
  }

  Drag? _onDragStart(String k, Offset globalPos) {
    if (_dropCtrl?.isAnimating ?? false) {
      _dropCtrl!.stop();
      _cleanupGhost();
    }
    final ctx = _keyFor(k).currentContext;
    if (ctx == null) return null;
    final rb = ctx.findRenderObject();
    if (rb is! RenderBox || !rb.attached) return null;
    final topLeft = rb.localToGlobal(Offset.zero);
    final size = rb.size;
    final srcIdx = widget.sections.indexWhere((s) => s.key == k);

    _palette = BrutalColors.of(context);
    setState(() {
      _dragKey = k;
      // Start at source's own index — insertIdx == srcIdx is treated as
      // "no move" in _displayedSections, so the layout stays put at pickup.
      _insertIdx = srcIdx;
      _ghostTopLeft = topLeft;
      _ghostSize = size;
      _pointerLocal = globalPos - topLeft;
      _pointer = globalPos;
    });
    _showOverlay();
    final lift = _liftCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..addListener(_onLiftTick);
    lift.forward(from: 0);
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollTick(),
    );
    HapticFeedback.mediumImpact();
    return _SectionDrag(
      onUpdate: (d) => _onPointerMove(d.globalPosition),
      onEnd: (_) => _endDrag(commit: true),
      onCancel: () => _endDrag(commit: false),
    );
  }

  void _onLiftTick() {
    setState(() {});
    _overlay?.markNeedsBuild();
  }

  void _onPointerMove(Offset globalPos) {
    _ghostTopLeft = globalPos - _pointerLocal;
    _pointer = globalPos;
    final newIdx = _computeInsertIdx(globalPos.dy);
    if (newIdx != _insertIdx) {
      setState(() => _insertIdx = newIdx);
    }
    _overlay?.markNeedsBuild();
  }

  /// Insertion index in the original list (0..N), computed from the pointer
  /// y against the midpoints of the *non-source* sections. Ignoring the
  /// source gives hysteresis: the source's own slot never counts as a
  /// boundary, so pointer jitter within it doesn't flip the preview back
  /// and forth.
  int _computeInsertIdx(double y) {
    final sections = widget.sections;
    if (sections.isEmpty) return 0;

    final srcIdx = _dragKey == null
        ? -1
        : sections.indexWhere((s) => s.key == _dragKey);

    final nonSrc = <(int, double)>[];
    for (int i = 0; i < sections.length; i++) {
      if (i == srcIdx) continue;
      final ctx = _keyFor(sections[i].key).currentContext;
      if (ctx == null) continue;
      final rb = ctx.findRenderObject();
      if (rb is! RenderBox || !rb.attached) continue;
      final pos = rb.localToGlobal(Offset.zero);
      nonSrc.add((i, pos.dy + rb.size.height / 2));
    }
    if (nonSrc.isEmpty) return srcIdx >= 0 ? srcIdx : 0;

    // Walk non-source midpoints in order and find the first whose mid is
    // below the pointer — that's the section the source would sit before.
    for (final (origIdx, mid) in nonSrc) {
      if (y < mid) return origIdx;
    }
    return sections.length;
  }

  void _endDrag({required bool commit}) {
    final from = _dragKey;
    final insertIdx = _insertIdx;
    final srcIdx = from == null
        ? -1
        : widget.sections.indexWhere((s) => s.key == from);
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;

    final shouldCommit = commit &&
        from != null &&
        insertIdx != null &&
        srcIdx >= 0 &&
        insertIdx != srcIdx &&
        insertIdx != srcIdx + 1;

    setState(() => _insertIdx = null);
    if (shouldCommit) {
      final order = [for (final s in widget.sections) s.key];
      final src = order.removeAt(srcIdx);
      final adjustedInsert = insertIdx > srcIdx ? insertIdx - 1 : insertIdx;
      order.insert(adjustedInsert, src);
      widget.onReorder(order);
    }
    _startDropSettle();
  }

  void _startDropSettle() {
    final from = _dragKey;
    if (from == null) {
      _cleanupGhost();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _gKeys[from]?.currentContext;
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
    _dropCtrl?.value = 0;
    _liftCtrl?.value = 0;
    setState(() {
      _dragKey = null;
      _insertIdx = null;
      _ghostTopLeft = null;
      _ghostSize = null;
      _dropFrom = null;
      _dropTo = null;
    });
  }

  /// Auto-scroll the enclosing [Scrollable] when the pointer sits within
  /// [edge]px of the viewport's top or bottom. Velocity ramps with how far
  /// past the threshold the pointer has gone, capped at [maxVel] per frame.
  void _autoScrollTick() {
    if (_dragKey == null) return;
    final listCtx = _listKey.currentContext;
    if (listCtx == null) return;

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

  void _showOverlay() {
    _overlay = OverlayEntry(builder: _buildGhost);
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  Widget _buildGhost(BuildContext _) {
    final top = _ghostTopLeft;
    final size = _ghostSize;
    final palette = _palette;
    final k = _dragKey;
    if (top == null || size == null || palette == null || k == null) {
      return const SizedBox.shrink();
    }
    final section = widget.sections.firstWhere(
      (s) => s.key == k,
      orElse: () => widget.sections.first,
    );
    final dropT = _dropCtrl?.value ?? 0.0;
    final liftT = _liftCtrl?.value ?? 0.0;
    // kk: 0 = flat in-slot, 1 = fully lifted. Ramps up on pickup, stays at
    // 1 during drag, ramps back to 0 on release so the accent halo unwinds
    // in lockstep with the source-slot accent.
    final kk = (liftT - dropT).clamp(0.0, 1.0);
    return Positioned(
      left: top.dx,
      top: top.dy,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -0.016 * kk,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: 1.0 + 0.015 * kk,
            alignment: Alignment.center,
            child: Opacity(
              opacity: 0.95 + 0.05 * dropT,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.paper,
                  boxShadow: [
                    BoxShadow(
                      color: palette.ink,
                      offset: Offset(6 * kk, 6 * kk),
                    ),
                    BoxShadow(
                      color: palette.accent,
                      spreadRadius: 3 * kk,
                    ),
                  ],
                ),
                child: BrutalColors(
                  palette: palette,
                  child: Material(
                    type: MaterialType.transparency,
                    child: section.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sections in the order they should be *rendered* during drag. The
  /// source is pulled out and reinserted at the preview slot so non-source
  /// cards flow into the gap. When insertIdx is at or adjacent to the
  /// source's original index, no rearrangement is previewed — matching
  /// DragList's "same-slot = no-op" semantics so dropping where you picked
  /// up stays put.
  List<SectionItem> _displayedSections() {
    final sections = widget.sections;
    if (_dragKey == null || _insertIdx == null) {
      return sections;
    }
    final srcIdx = sections.indexWhere((s) => s.key == _dragKey);
    if (srcIdx < 0) return sections;
    final insertIdx = _insertIdx!;
    if (insertIdx == srcIdx || insertIdx == srcIdx + 1) {
      return sections;
    }

    final targetPos = insertIdx > srcIdx ? insertIdx - 1 : insertIdx;
    final result = <SectionItem>[];
    int displayedPos = 0;
    for (int i = 0; i < sections.length; i++) {
      if (i == srcIdx) continue;
      if (displayedPos == targetPos) {
        result.add(sections[srcIdx]);
      }
      result.add(sections[i]);
      displayedPos++;
    }
    if (result.length < sections.length) {
      result.add(sections[srcIdx]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final displayed = _displayedSections();
    final liftT = _liftCtrl?.value ?? 0.0;
    final dropT = _dropCtrl?.value ?? 0.0;
    final kk = (liftT - dropT).clamp(0.0, 1.0);
    return Column(
      key: _listKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < displayed.length; i++) ...[
          if (i > 0) SizedBox(height: widget.gap),
          KeyedSubtree(
            key: _keyFor(displayed[i].key),
            child: _SectionCard(
              section: displayed[i],
              dragging: _dragKey == displayed[i].key,
              accentOpacity: _dragKey == displayed[i].key ? kk : 0.0,
              palette: p,
              onDragStart: (pos) => _onDragStart(displayed[i].key, pos),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final SectionItem section;
  final bool dragging;
  final double accentOpacity;
  final BrutalPalette palette;
  final Drag? Function(Offset globalPosition) onDragStart;
  const _SectionCard({
    required this.section,
    required this.dragging,
    required this.accentOpacity,
    required this.palette,
    required this.onDragStart,
  });

  @override
  Widget build(BuildContext context) {
    final visual = Stack(
      children: [
        Visibility(
          visible: !dragging,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: section.child,
        ),
        if (accentOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: accentOpacity,
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
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        // 500ms long-press before the drag claims the arena. Short taps and
        // quick scrolls fall through to children, and inner
        // ImmediateMultiDragGestureRecognizers claim on motion before the
        // delay fires.
        DelayedMultiDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                DelayedMultiDragGestureRecognizer>(
          () => DelayedMultiDragGestureRecognizer(),
          (r) {
            r.onStart = onDragStart;
          },
        ),
      },
      child: visual,
    );
  }
}

class _SectionDrag extends Drag {
  final void Function(DragUpdateDetails) onUpdate;
  final void Function(DragEndDetails) onEnd;
  final VoidCallback onCancel;
  _SectionDrag({
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

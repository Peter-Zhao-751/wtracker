import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/data.dart';
import '../core/theme.dart';
import '../services/state.dart';
import '../widgets/drag_list.dart';
import '../widgets/primitives.dart';

class ExercisePickerSheet extends StatefulWidget {
  final Prefs prefs;
  final VoidCallback onClose;
  final void Function(Map<String, dynamic>) onPick;
  const ExercisePickerSheet({
    super.key,
    required this.prefs,
    required this.onClose,
    required this.onPick,
  });

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  String _filter = 'ALL';
  String _search = '';
  late final List<Map<String, dynamic>> _pool;
  late final List<String> _allGroups;

  @override
  void initState() {
    super.initState();
    _pool = kExercisePool;
    final gs = <String>{for (final p in _pool) p['group'] as String};
    final sorted = gs.toList()..sort();
    _allGroups = ['ALL', ...sorted];
    _reconcileTabOrder();
  }

  void _reconcileTabOrder() {
    final saved = widget.prefs.tabOrder;
    final next = <String>[
      ...saved.where(_allGroups.contains),
      ..._allGroups.where((g) => !saved.contains(g)),
    ];
    if (saved.isEmpty || saved.length != next.length || !_listEq(saved, next)) {
      widget.prefs.setTabOrder(next);
    }
  }

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<String> get _tabs {
    final saved = widget.prefs.tabOrder;
    if (saved.isEmpty) return _allGroups;
    return saved;
  }

  void _toggleFav(String name) {
    widget.prefs.toggleFavorite(name);
  }

  /// JSX signature: reorderTab(fromG, toG) — move fromG to toG's slot.
  void _reorderTabs(String fromG, String toG) {
    if (fromG == toG) return;
    final list = List<String>.from(_tabs);
    final from = list.indexOf(fromG);
    final to = list.indexOf(toG);
    if (from < 0 || to < 0) return;
    list.removeAt(from);
    list.insert(to, fromG);
    widget.prefs.setTabOrder(list);
  }

  /// Reorder one visible section (favs or rest) using DragList's
  /// (fromIdx, insertIdx) convention. Merge into the per-group order.
  void _reorderSection(
    List<Map<String, dynamic>> section,
    int fromIdx,
    int insertIdx,
  ) {
    final names = section.map((e) => e['name'] as String).toList();
    final moved = names.removeAt(fromIdx);
    final at = insertIdx > fromIdx ? insertIdx - 1 : insertIdx;
    names.insert(at, moved);
    final prior = widget.prefs.exerciseOrderFor(_filter) ?? const <String>[];
    final merged = <String>[
      ...names,
      ...prior.where((n) => !names.contains(n)),
    ];
    widget.prefs.setExerciseOrder(_filter, merged);
  }

  List<Map<String, dynamic>> _compute() {
    final base = _filter == 'ALL'
        ? _pool
        : _pool.where((x) => x['group'] == _filter).toList();
    final savedOrder = widget.prefs.exerciseOrderFor(_filter) ?? const <String>[];
    final byName = {for (final p in base) p['name'] as String: p};
    final ordered = <Map<String, dynamic>>[
      for (final n in savedOrder)
        if (byName.containsKey(n)) byName[n]!,
      ...base.where((p) => !savedOrder.contains(p['name'])),
    ];
    final q = _search.toLowerCase();
    if (q.isEmpty) return ordered;
    return ordered
        .where((p) => (p['name'] as String).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.prefs,
      builder: (context, _) {
        final p = BrutalColors.of(context);
        final filtered = _compute();
        final favs = widget.prefs.exerciseFavorites;
        final starred = filtered.where((x) => favs.contains(x['name'])).toList();
        final rest = filtered.where((x) => !favs.contains(x['name'])).toList();
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                onTap: widget.onClose,
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FractionallySizedBox(
                  widthFactor: 1,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: BoxDecoration(
                      color: p.paper,
                      border: Border(top: BorderSide(color: p.ink, width: 3)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              color: p.ink.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: p.ink, width: 2)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'PICK EXERCISE',
                                  style: mono(
                                    size: 14,
                                    weight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: p.ink,
                                  ),
                                ),
                              ),
                              IconSquare(
                                glyph: '✕',
                                onTap: widget.onClose,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          child: Container(
                            decoration: BoxDecoration(border: Border.all(color: p.ink, width: 2)),
                            child: TextField(
                              onChanged: (v) => setState(() => _search = v),
                              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'SEARCH...',
                                hintStyle: mono(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: p.ink.withValues(alpha: 0.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                              ),
                              style: mono(
                                size: 12,
                                weight: FontWeight.w700,
                                letterSpacing: 1,
                                color: p.ink,
                              ),
                            ),
                          ),
                        ),
                        _TabBarDraggable(
                          tabs: _tabs,
                          active: _filter,
                          onSelect: (g) => setState(() => _filter = g),
                          onReorder: _reorderTabs,
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (starred.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                                    child: Text(
                                      '★ FAVORITES',
                                      style: mono(
                                        size: 9,
                                        weight: FontWeight.w700,
                                        letterSpacing: 2,
                                        color: p.ink.withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ),
                                  _ExSection(
                                    items: starred,
                                    starred: true,
                                    onToggleFav: _toggleFav,
                                    onPick: widget.onPick,
                                    onReorder: (f, i) => _reorderSection(starred, f, i),
                                  ),
                                ],
                                if (rest.isNotEmpty) ...[
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: starred.isNotEmpty ? 14 : 8,
                                      bottom: 4,
                                    ),
                                    child: starred.isNotEmpty
                                        ? Text(
                                            'ALL',
                                            style: mono(
                                              size: 9,
                                              weight: FontWeight.w700,
                                              letterSpacing: 2,
                                              color: p.ink.withValues(alpha: 0.55),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  _ExSection(
                                    items: rest,
                                    starred: false,
                                    onToggleFav: _toggleFav,
                                    onPick: widget.onPick,
                                    onReorder: (f, i) => _reorderSection(rest, f, i),
                                  ),
                                ],
                                if (starred.isEmpty && rest.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 40),
                                    child: Center(
                                      child: Text(
                                        'NO MATCHES',
                                        style: mono(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          letterSpacing: 1,
                                          color: p.ink.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal tab strip. Tap = select; drag-from-any-pointer-down = reorder.
/// Mirrors the vertical [DragList] feel: on pickup a floating overlay ghost
/// lifts out (tilt, ink offset-shadow, accent halo); neighbors slide
/// horizontally via [AnimatedPositioned] to make room; on release the ghost
/// tweens into the landing slot while its chrome unwinds back to flat.
/// Chip widths are measured via [TextPainter] so the Stack layout is known
/// ahead of the first paint — no measurement pass needed.
class _TabBarDraggable extends StatefulWidget {
  final List<String> tabs;
  final String active;
  final ValueChanged<String> onSelect;
  final void Function(String fromG, String toG) onReorder;
  const _TabBarDraggable({
    required this.tabs,
    required this.active,
    required this.onSelect,
    required this.onReorder,
  });

  @override
  State<_TabBarDraggable> createState() => _TabBarDraggableState();
}

class _TabBarDraggableState extends State<_TabBarDraggable>
    with SingleTickerProviderStateMixin {
  String? _dragTab;
  String? _hoverTab;
  final Map<String, GlobalKey> _keys = {};
  final ScrollController _scroll = ScrollController();

  // Pre-measured chip widths (keyed by label). Computed once per label via
  // TextPainter so Stack layout is deterministic.
  final Map<String, double> _widths = {};
  double _chipH = 22;

  // Ghost overlay state — same shape as DragList / ReorderableGroupGrid.
  Offset? _ghostTopLeft;
  Size? _ghostSize;
  Offset _pointerLocal = Offset.zero;
  OverlayEntry? _overlay;
  BrutalPalette? _palette;

  // Drop-settle: ghost tweens from release position into the landing slot.
  AnimationController? _dropCtrl;
  Offset? _dropFrom;
  Offset? _dropTo;
  bool _accentOn = false;

  static const double _gap = 4;
  // Chip chrome (Container padding + border) around the text.
  static const double _chromeW = 23; // 10*2 padding + 1.5*2 border
  static const double _chromeH = 11; // 4*2 padding + 1.5*2 border

  @override
  void initState() {
    super.initState();
    _measureTabs();
  }

  @override
  void didUpdateWidget(covariant _TabBarDraggable old) {
    super.didUpdateWidget(old);
    _measureTabs();
  }

  void _measureTabs() {
    const style = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    );
    double maxH = 0;
    for (final g in widget.tabs) {
      if (_widths.containsKey(g)) {
        final h = _widths[g]! > 0 ? _chipH : 0.0;
        if (h > maxH) maxH = h;
        continue;
      }
      final tp = TextPainter(
        text: TextSpan(text: g, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      _widths[g] = tp.width + _chromeW;
      final h = tp.height + _chromeH;
      if (h > maxH) maxH = h;
    }
    if (maxH > 0) _chipH = maxH;
  }

  GlobalKey _keyFor(String g) => _keys.putIfAbsent(g, () => GlobalKey());

  @override
  void dispose() {
    _scroll.dispose();
    _overlay?.remove();
    _overlay = null;
    _dropCtrl?.dispose();
    super.dispose();
  }

  Drag? _onDragStart(String g, Offset globalPos) {
    if (_dropCtrl?.isAnimating ?? false) {
      _dropCtrl!.stop();
      _cleanupGhost();
    }
    final ctx = _keyFor(g).currentContext;
    if (ctx == null) return null;
    final rb = ctx.findRenderObject();
    if (rb is! RenderBox || !rb.attached) return null;
    final topLeft = rb.localToGlobal(Offset.zero);
    final size = rb.size;

    _palette = BrutalColors.of(context);
    setState(() {
      _dragTab = g;
      _hoverTab = g;
      _ghostTopLeft = topLeft;
      _ghostSize = size;
      _pointerLocal = globalPos - topLeft;
      _accentOn = true;
    });
    _showOverlay();
    HapticFeedback.selectionClick();
    return _TabDrag(
      onUpdate: (d) => _onPointerMove(d.globalPosition),
      onEnd: (_) => _endDrag(commit: true),
      onCancel: () => _endDrag(commit: false),
    );
  }

  void _onPointerMove(Offset globalPos) {
    _ghostTopLeft = globalPos - _pointerLocal;
    String? nextHover;
    for (final g in widget.tabs) {
      if (g == _dragTab) continue;
      final ctx = _keys[g]?.currentContext;
      if (ctx == null) continue;
      final rb = ctx.findRenderObject();
      if (rb is! RenderBox || !rb.attached) continue;
      final pos = rb.localToGlobal(Offset.zero);
      final rect = pos & rb.size;
      if (rect.contains(globalPos)) {
        nextHover = g;
        break;
      }
    }
    if (nextHover != null && nextHover != _hoverTab) {
      setState(() => _hoverTab = nextHover);
    }
    _overlay?.markNeedsBuild();
  }

  void _endDrag({required bool commit}) {
    final from = _dragTab;
    final to = _hoverTab;
    final shouldCommit =
        commit && from != null && to != null && from != to;
    setState(() {
      _hoverTab = null;
      _accentOn = false;
    });
    if (shouldCommit) {
      widget.onReorder(from, to);
    }
    _startDropSettle();
  }

  void _startDropSettle() {
    final from = _dragTab;
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
    _dropCtrl?.value = 0;
    setState(() {
      _dragTab = null;
      _hoverTab = null;
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
    final tab = _dragTab;
    if (top == null || size == null || palette == null || tab == null) {
      return const SizedBox.shrink();
    }
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
                  boxShadow: [
                    BoxShadow(
                      color: palette.ink,
                      offset: Offset(4 * k, 4 * k),
                    ),
                    BoxShadow(
                      color: palette.accent,
                      spreadRadius: 2 * k,
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: _TabChipContent(
                    label: tab,
                    active: widget.active == tab,
                    palette: palette,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tabs in the order they should render while dragging. Source is moved to
  /// the hover slot so neighbors naturally slide around it.
  List<String> _displayedTabs() {
    if (_dragTab == null || _hoverTab == null || _dragTab == _hoverTab) {
      return widget.tabs;
    }
    final list = List<String>.from(widget.tabs);
    final from = list.indexOf(_dragTab!);
    final to = list.indexOf(_hoverTab!);
    if (from < 0 || to < 0) return widget.tabs;
    list.removeAt(from);
    list.insert(to, _dragTab!);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final palette = BrutalColors.of(context);
    final displayed = _displayedTabs();

    // Cumulative x offsets for each tab in its displayed slot.
    final xByTab = <String, double>{};
    double x = 0;
    for (final g in displayed) {
      xByTab[g] = x;
      x += (_widths[g] ?? 40) + _gap;
    }
    final totalW = x <= 0 ? 0.0 : x - _gap;

    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
        physics: _dragTab != null
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        child: SizedBox(
          width: totalW,
          height: _chipH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final g in widget.tabs)
                AnimatedPositioned(
                  key: ValueKey('pos-$g'),
                  duration: _dragTab == g
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: xByTab[g] ?? 0,
                  top: 0,
                  width: _widths[g] ?? 40,
                  height: _chipH,
                  child: KeyedSubtree(
                    key: _keyFor(g),
                    child: _TabChip(
                      label: g,
                      active: widget.active == g,
                      dragging: _dragTab == g,
                      showAccent: _dragTab == g && _accentOn,
                      onTap: () => widget.onSelect(g),
                      onDragStart: (pos) => _onDragStart(g, pos),
                      palette: palette,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static chip visual — used as the ghost's content during drag. Separated
/// from [_TabChip] so the ghost can render without any gesture/visibility
/// machinery.
class _TabChipContent extends StatelessWidget {
  final String label;
  final bool active;
  final BrutalPalette palette;
  const _TabChipContent({
    required this.label,
    required this.active,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? palette.ink : palette.paper,
        border: Border.all(color: palette.ink, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: mono(
          size: 10,
          weight: FontWeight.w800,
          letterSpacing: 1,
          color: active ? palette.paper : palette.ink,
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool dragging;
  final bool showAccent;
  final VoidCallback onTap;
  final Drag? Function(Offset globalPosition) onDragStart;
  final BrutalPalette palette;
  const _TabChip({
    required this.label,
    required this.active,
    required this.dragging,
    required this.showAccent,
    required this.onTap,
    required this.onDragStart,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    // Visibility reserves the chip's slot; the accent rectangle overlays the
    // slot while dragging and fades via `showAccent` (which flips false at
    // drop start — not cleanup — so the fade doesn't flash over the landed
    // chip).
    final visual = Stack(
      children: [
        Visibility(
          visible: !dragging,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: _TabChipContent(
            label: label,
            active: active,
            palette: palette,
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
                  color: palette.accent,
                  border: Border.all(color: palette.ink, width: 1.5),
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

class _TabDrag extends Drag {
  final void Function(DragUpdateDetails) onUpdate;
  final void Function(DragEndDetails) onEnd;
  final VoidCallback onCancel;
  _TabDrag({
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

class _ExSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool starred;
  final void Function(String name) onToggleFav;
  final void Function(Map<String, dynamic>) onPick;
  final void Function(int fromIdx, int insertIdx) onReorder;
  const _ExSection({
    required this.items,
    required this.starred,
    required this.onToggleFav,
    required this.onPick,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return DragList<Map<String, dynamic>>(
      items: items,
      scrollable: false,
      getId: (p) => '${starred ? 'star' : 'rest'}-${p['name']}',
      onReorder: onReorder,
      closedGap: 0,
      itemBuilder: (_, i, data, handle) => _ExRow(
        data: data,
        starred: starred,
        first: i == 0,
        last: i == items.length - 1,
        handle: handle,
        onToggleFav: () => onToggleFav(data['name'] as String),
        onPick: () => onPick(data),
      ),
    );
  }
}

class _ExRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool starred;
  final bool first;
  final bool last;
  final DragHandleBuilder handle;
  final VoidCallback onToggleFav;
  final VoidCallback onPick;
  const _ExRow({
    required this.data,
    required this.starred,
    required this.first,
    required this.last,
    required this.handle,
    required this.onToggleFav,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    // JSX: every row has full border, but non-last rows set bottom: none —
    // so the row below's top acts as the separator. We reproduce that by
    // only drawing a bottom border on the last row.
    return Container(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border(
          left: BorderSide(color: p.ink, width: 1.5),
          right: BorderSide(color: p.ink, width: 1.5),
          top: BorderSide(color: p.ink, width: 1.5),
          bottom: BorderSide(color: p.ink, width: last ? 1.5 : 0),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            handle(
              Container(
                width: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: p.ink, width: 1.5)),
                ),
                child: Text(
                  '⋮⋮',
                  style: mono(
                    size: 14,
                    weight: FontWeight.w800,
                    color: p.ink.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: onToggleFav,
              child: Container(
                width: 32,
                decoration: BoxDecoration(
                  color: starred ? p.accent : p.paper,
                  border: Border(right: BorderSide(color: p.ink, width: 1.5)),
                ),
                alignment: Alignment.center,
                child: Text(
                  starred ? '★' : '☆',
                  style: mono(
                    size: 11,
                    weight: FontWeight.w800,
                    color: starred ? p.accentInk : p.ink,
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: onPick,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data['name'] as String,
                              style: mono(size: 12, weight: FontWeight.w800, color: p.ink),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data['group'] as String,
                              style: mono(
                                size: 9,
                                weight: FontWeight.w700,
                                letterSpacing: 1,
                                color: p.ink.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+',
                        style: mono(size: 16, weight: FontWeight.w900, color: p.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/data.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/state.dart';
import '../widgets/drag_list.dart';
import '../widgets/primitives.dart';

class TemplatesScreen extends StatefulWidget {
  final Tweaks tweaks;
  final Prefs prefs;
  final void Function(Template) onStart;
  const TemplatesScreen({
    super.key,
    required this.tweaks,
    required this.prefs,
    required this.onStart,
  });

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  String _filter = 'ALL';
  String? _expanded;

  List<String> get _order {
    final saved = widget.prefs.templateOrder;
    final base = [for (final t in kTemplates) t.id];
    if (saved.isEmpty) return base;
    final keep = saved.where(base.contains).toList();
    for (final id in base) {
      if (!keep.contains(id)) keep.add(id);
    }
    return keep;
  }

  /// Build templates in persisted order, with overrides applied.
  List<Template> _liveTemplates() {
    final byId = {for (final t in kTemplates) t.id: t};
    return _order.map((id) {
      final base = byId[id];
      if (base == null) return null;
      final ov = widget.prefs.overrideFor(id);
      if (ov == null) return base;
      List<Exercise> exs = base.exercises;
      if (ov.exOrder != null && ov.exOrder!.length == base.exercises.length) {
        exs = [for (final i in ov.exOrder!) if (i >= 0 && i < base.exercises.length) base.exercises[i]];
      }
      exs = [
        for (final e in exs)
          () {
            final origIdx = base.exercises.indexWhere((x) => x.name == e.name);
            final s = ov.setsFor(origIdx);
            return s != null ? e.copyWith(sets: s) : e;
          }(),
      ];
      return base.copyWith(exercises: exs);
    }).whereType<Template>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.prefs,
      builder: (context, _) {
        final live = _liveTemplates();
        final filtered = _filter == 'ALL'
            ? live
            : live.where((t) => t.split == _filter).toList();
        final p = BrutalColors.of(context);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _FilterBarDraggable(
                opts: widget.prefs.tplFilterOrder,
                value: _filter,
                onSelect: (v) => setState(() => _filter = v),
                onReorder: (fromO, toO) {
                  final list = List<String>.from(widget.prefs.tplFilterOrder);
                  final from = list.indexOf(fromO);
                  final to = list.indexOf(toO);
                  if (from < 0 || to < 0 || from == to) return;
                  list.removeAt(from);
                  list.insert(to, fromO);
                  widget.prefs.setTemplateFilterOrder(list);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Text(
                '⋮⋮ DRAG HANDLE TO REORDER · TAP CARD TO EDIT SETS',
                style: mono(
                  size: 9,
                  weight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: p.ink.withValues(alpha: 0.55),
                ),
              ),
            ),
            Expanded(
              child: DragList<Template>(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                items: filtered,
                getId: (t) => t.id,
                onReorder: (fromIdx, insertIdx) =>
                    _reorderTemplates(filtered, fromIdx, insertIdx),
                itemBuilder: (context, i, t, handle) => _TemplateCard(
                  tpl: t,
                  dragHandle: handle,
                  expanded: _expanded == t.id,
                  modified: widget.prefs.hasOverride(t.id),
                  onTap: () => setState(
                    () => _expanded = _expanded == t.id ? null : t.id,
                  ),
                  onStart: () => widget.onStart(t),
                  onSetsChange: (name, sets) {
                    final base = kTemplates.firstWhere((x) => x.id == t.id);
                    final origIdx =
                        base.exercises.indexWhere((x) => x.name == name);
                    if (origIdx < 0) return;
                    widget.prefs.setTemplateSets(t.id, origIdx, sets);
                  },
                  onReorderExercises: (newNameOrder) {
                    final base = kTemplates.firstWhere((x) => x.id == t.id);
                    final idxs = newNameOrder
                        .map((name) => base.exercises
                            .indexWhere((e) => e.name == name))
                        .toList();
                    widget.prefs.setTemplateExOrder(t.id, idxs);
                  },
                  onReset: () => widget.prefs.resetTemplate(t.id),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _reorderTemplates(List<Template> filtered, int fromIdx, int insertIdx) {
    final newIdx = insertIdx > fromIdx ? insertIdx - 1 : insertIdx;
    // Reorder within the filtered subset, then reconcile back into full order.
    final filteredIds = [for (final t in filtered) t.id];
    final moved = filteredIds.removeAt(fromIdx);
    filteredIds.insert(newIdx, moved);

    final full = List<String>.from(_order);
    final positions = <int>[];
    for (int i = 0; i < full.length; i++) {
      if (filteredIds.contains(full[i])) positions.add(i);
    }
    for (int k = 0; k < positions.length; k++) {
      full[positions[k]] = filteredIds[k];
    }
    widget.prefs.setTemplateOrder(full);
  }
}

class _TemplateCard extends StatelessWidget {
  final Template tpl;
  final DragHandleBuilder dragHandle;
  final bool expanded;
  final bool modified;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final void Function(String name, int sets) onSetsChange;
  final void Function(List<String> newOrder) onReorderExercises;
  final VoidCallback onReset;

  const _TemplateCard({
    required this.tpl,
    required this.dragHandle,
    required this.expanded,
    required this.modified,
    required this.onTap,
    required this.onStart,
    required this.onSetsChange,
    required this.onReorderExercises,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final groups = <String>{for (final e in tpl.exercises) e.group};

    return Container(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border.all(color: p.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: p.ink,
              border: Border(bottom: BorderSide(color: p.ink, width: 2)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                dragHandle(
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      '⋮⋮',
                      style: mono(
                        size: 16,
                        weight: FontWeight.w800,
                        letterSpacing: -2,
                        color: p.paper.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tpl.split,
                    style: mono(
                      size: 10,
                      weight: FontWeight.w800,
                      letterSpacing: 2,
                      color: p.paper,
                    ),
                  ),
                ),
                if (modified) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    color: p.accent,
                    child: Text(
                      'MOD',
                      style: mono(
                        size: 8,
                        weight: FontWeight.w800,
                        letterSpacing: 1,
                        color: p.accentInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '~${tpl.est} MIN',
                  style: mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: p.paper.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tpl.name,
                              style: mono(
                                size: 22,
                                weight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tpl.subtitle,
                              style: mono(
                                size: 10,
                                weight: FontWeight.w700,
                                letterSpacing: 1,
                                color: p.ink.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        expanded ? '▲' : '▼',
                        style: mono(
                          size: 11,
                          weight: FontWeight.w800,
                          color: p.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final g in groups)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: p.ink, width: 1.5),
                          ),
                          child: Text(
                            g,
                            style: mono(
                              size: 9,
                              weight: FontWeight.w700,
                              letterSpacing: 1,
                              color: p.ink,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DashedLine(color: p.ink),
                  const SizedBox(height: 10),
                  expanded
                      ? _ExerciseEditor(
                          exercises: tpl.exercises,
                          onSetsChange: onSetsChange,
                          onReorder: onReorderExercises,
                          modified: modified,
                          onReset: onReset,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < tpl.exercises.take(4).length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${(i + 1).toString().padLeft(2, '0')}. ${tpl.exercises[i].name}',
                                        style: mono(size: 11, weight: FontWeight.w700, color: p.ink),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${tpl.exercises[i].sets}×${tpl.exercises[i].reps}',
                                      style: mono(size: 11, color: p.ink.withValues(alpha: 0.7)),
                                    ),
                                  ],
                                ),
                              ),
                            if (tpl.exercises.length > 4)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+ ${tpl.exercises.length - 4} more',
                                  style: mono(size: 10, color: p.ink.withValues(alpha: 0.5)),
                                ),
                              ),
                          ],
                        ),
                  const SizedBox(height: 12),
                  _StartChip(onPressed: onStart, count: tpl.exercises.length),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reorderable exercise list inside an expanded template card.
class _ExerciseEditor extends StatefulWidget {
  final List<Exercise> exercises;
  final void Function(String name, int sets) onSetsChange;
  final void Function(List<String> newOrder) onReorder;
  final bool modified;
  final VoidCallback onReset;

  const _ExerciseEditor({
    required this.exercises,
    required this.onSetsChange,
    required this.onReorder,
    required this.modified,
    required this.onReset,
  });

  @override
  State<_ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<_ExerciseEditor> {
  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DragList<Exercise>(
          scrollable: false,
          closedGap: 0,
          items: widget.exercises,
          getId: (e) => e.name,
          onReorder: (fromIdx, insertIdx) {
            final newIdx = insertIdx > fromIdx ? insertIdx - 1 : insertIdx;
            final names = [for (final e in widget.exercises) e.name];
            final moved = names.removeAt(fromIdx);
            names.insert(newIdx, moved);
            widget.onReorder(names);
          },
          itemBuilder: (context, i, e, handle) {
            final isLast = i == widget.exercises.length - 1;
            return Container(
              decoration: BoxDecoration(
                color: p.paper,
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: p.ink.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  handle(
                    Padding(
                      padding: const EdgeInsets.only(
                          right: 6, left: 0, top: 2, bottom: 2),
                      child: Text(
                        '⋮⋮',
                        style: mono(
                          size: 13,
                          weight: FontWeight.w800,
                          letterSpacing: -1.5,
                          color: p.ink.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${(i + 1).toString().padLeft(2, '0')}. ${e.name}',
                      style: mono(
                          size: 11, weight: FontWeight.w700, color: p.ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _SetsStepper(
                    value: e.sets,
                    reps: e.reps,
                    onChange: (v) => widget.onSetsChange(e.name, v),
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.modified)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: widget.onReset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: p.ink, width: 1.5)),
                  child: Text(
                    '↺ RESET',
                    style: mono(
                      size: 9,
                      weight: FontWeight.w800,
                      letterSpacing: 1,
                      color: p.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SetsStepper extends StatelessWidget {
  final int value;
  final String reps;
  final ValueChanged<int> onChange;
  const _SetsStepper({required this.value, required this.reps, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return SizedBox(
      height: 26,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(context, '−', () => onChange((value - 1).clamp(1, 10))),
          Container(
            constraints: const BoxConstraints(minWidth: 38),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: p.ink, width: 1.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$value×$reps',
              style: mono(size: 11, weight: FontWeight.w800, color: p.ink),
            ),
          ),
          _stepBtn(context, '+', () => onChange((value + 1).clamp(1, 10))),
        ],
      ),
    );
  }

  Widget _stepBtn(BuildContext context, String l, VoidCallback onTap) {
    final p = BrutalColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        decoration: BoxDecoration(border: Border.all(color: p.ink, width: 1.5)),
        alignment: Alignment.center,
        child: Text(l, style: mono(size: 12, weight: FontWeight.w800, color: p.ink)),
      ),
    );
  }
}

class _StartChip extends StatefulWidget {
  final VoidCallback onPressed;
  final int count;
  const _StartChip({required this.onPressed, required this.count});

  @override
  State<_StartChip> createState() => _StartChipState();
}

class _StartChipState extends State<_StartChip> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: _down ? (Matrix4.identity()..translate(2.0, 2.0)) : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.accent,
          border: Border.all(color: p.ink, width: 2),
          boxShadow: [
            BoxShadow(
              color: p.ink,
              offset: _down ? const Offset(1, 1) : const Offset(3, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '▶ START',
              style: mono(size: 12, weight: FontWeight.w800, letterSpacing: 1, color: p.accentInk),
            ),
            Text(
              '${widget.count} EXERCISES',
              style: mono(size: 11, weight: FontWeight.w700, color: p.accentInk),
            ),
          ],
        ),
      ),
    );
  }
}

/// Equal-width segmented filter bar. Tap = select; drag = reorder with the
/// same lift/drop chrome as the vertical [DragList] and horizontal exercise
/// picker tab bar: floating ghost (tilt + ink shadow + accent halo),
/// neighbors slide via [AnimatedPositioned], ghost tweens into the landing
/// slot while its chrome unwinds. Cell width is computed from the parent's
/// constraints so the Stack layout is deterministic.
class _FilterBarDraggable extends StatefulWidget {
  final List<String> opts;
  final String value;
  final ValueChanged<String> onSelect;
  final void Function(String fromO, String toO) onReorder;
  const _FilterBarDraggable({
    required this.opts,
    required this.value,
    required this.onSelect,
    required this.onReorder,
  });

  @override
  State<_FilterBarDraggable> createState() => _FilterBarDraggableState();
}

class _FilterBarDraggableState extends State<_FilterBarDraggable>
    with TickerProviderStateMixin {
  String? _dragOpt;
  String? _hoverOpt;
  final Map<String, GlobalKey> _keys = {};

  Offset? _ghostTopLeft;
  Size? _ghostSize;
  Offset _pointerLocal = Offset.zero;
  OverlayEntry? _overlay;
  BrutalPalette? _palette;

  AnimationController? _dropCtrl;
  AnimationController? _liftCtrl;
  Offset? _dropFrom;
  Offset? _dropTo;
  bool _accentOn = false;

  static const double _height = 36.0;
  static const double _divW = 2.0;

  GlobalKey _keyFor(String o) => _keys.putIfAbsent(o, () => GlobalKey());

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    _dropCtrl?.dispose();
    _liftCtrl?.dispose();
    super.dispose();
  }

  Drag? _onDragStart(String o, Offset globalPos) {
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
      _dragOpt = o;
      _hoverOpt = o;
      _ghostTopLeft = topLeft;
      _ghostSize = size;
      _pointerLocal = globalPos - topLeft;
      _accentOn = true;
    });
    _showOverlay();
    final lift = _liftCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..addListener(_onLiftTick);
    lift.forward(from: 0);
    HapticFeedback.selectionClick();
    return _FilterDrag(
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
    String? nextHover;
    for (final o in widget.opts) {
      if (o == _dragOpt) continue;
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
    if (nextHover != null && nextHover != _hoverOpt) {
      setState(() => _hoverOpt = nextHover);
    }
    _overlay?.markNeedsBuild();
  }

  void _endDrag({required bool commit}) {
    final from = _dragOpt;
    final to = _hoverOpt;
    final shouldCommit = commit && from != null && to != null && from != to;
    setState(() {
      _hoverOpt = null;
      _accentOn = false;
    });
    if (shouldCommit) {
      widget.onReorder(from, to);
    }
    _startDropSettle();
  }

  void _startDropSettle() {
    final from = _dragOpt;
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
    _liftCtrl?.value = 0;
    setState(() {
      _dragOpt = null;
      _hoverOpt = null;
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
    final opt = _dragOpt;
    if (top == null || size == null || palette == null || opt == null) {
      return const SizedBox.shrink();
    }
    final dropT = _dropCtrl?.value ?? 0.0;
    final liftT = _liftCtrl?.value ?? 0.0;
    // k ramps 0→1 during the 160ms lift on pickup, holds at 1 during the
    // drag, then unwinds back to 0 as dropT drives toward 1 on release.
    // Matches the tab-picker's lift so the tilt/scale/halo eases in rather
    // than snapping.
    final k = (liftT - dropT).clamp(0.0, 1.0);
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
                      offset: Offset(5 * k, 5 * k),
                    ),
                    BoxShadow(
                      color: palette.accent,
                      spreadRadius: 2.5 * k,
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: _FilterCellContent(
                    label: opt,
                    active: widget.value == opt,
                    height: _height,
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

  /// Opt order while dragging: source moved into hover slot so neighbors
  /// slide around it. Same displaced-order preview as the other draggables.
  List<String> _displayedOpts() {
    if (_dragOpt == null || _hoverOpt == null || _dragOpt == _hoverOpt) {
      return widget.opts;
    }
    final list = List<String>.from(widget.opts);
    final from = list.indexOf(_dragOpt!);
    final to = list.indexOf(_hoverOpt!);
    if (from < 0 || to < 0) return widget.opts;
    list.removeAt(from);
    list.insert(to, _dragOpt!);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final displayed = _displayedOpts();
    final n = displayed.length;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: p.ink, width: 2)),
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            if (n == 0 || maxW <= 0) return const SizedBox.shrink();
            final cellW = (maxW - (n - 1) * _divW) / n;
            final slotByOpt = <String, int>{};
            for (int i = 0; i < displayed.length; i++) {
              slotByOpt[displayed[i]] = i;
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < n - 1; i++)
                  Positioned(
                    left: (i + 1) * cellW + i * _divW,
                    top: 0,
                    width: _divW,
                    height: _height,
                    child: ColoredBox(color: p.ink),
                  ),
                for (final o in widget.opts)
                  AnimatedPositioned(
                    key: ValueKey('pos-$o'),
                    duration: _dragOpt == o
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: (slotByOpt[o] ?? 0) * (cellW + _divW),
                    top: 0,
                    width: cellW,
                    height: _height,
                    child: KeyedSubtree(
                      key: _keyFor(o),
                      child: _FilterCell(
                        label: o,
                        active: widget.value == o,
                        dragging: _dragOpt == o,
                        showAccent: _dragOpt == o && _accentOn,
                        height: _height,
                        onTap: () => widget.onSelect(o),
                        onDragStart: (pos) => _onDragStart(o, pos),
                        palette: p,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Static cell visual — used as the ghost's content during drag. Separated
/// from [_FilterCell] so the ghost can render without gesture/visibility
/// machinery.
class _FilterCellContent extends StatelessWidget {
  final String label;
  final bool active;
  final double height;
  final BrutalPalette palette;
  const _FilterCellContent({
    required this.label,
    required this.active,
    required this.height,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: active ? palette.ink : palette.paper),
      child: Text(
        label.toUpperCase(),
        style: mono(
          size: 11,
          weight: FontWeight.w700,
          letterSpacing: 0.5,
          color: active ? palette.paper : palette.ink,
        ),
      ),
    );
  }
}

class _FilterCell extends StatelessWidget {
  final String label;
  final bool active;
  final bool dragging;
  final bool showAccent;
  final double height;
  final VoidCallback onTap;
  final Drag? Function(Offset globalPosition) onDragStart;
  final BrutalPalette palette;
  const _FilterCell({
    required this.label,
    required this.active,
    required this.dragging,
    required this.showAccent,
    required this.height,
    required this.onTap,
    required this.onDragStart,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final visual = SizedBox(
      height: height,
      child: Stack(
        children: [
          Visibility(
            visible: !dragging,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: _FilterCellContent(
              label: label,
              active: active,
              height: height,
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
                  decoration: BoxDecoration(color: palette.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          // Delayed so a hold-to-pickup gesture fires only after the pointer
          // stays within kTouchSlop for kLongPressTimeout (~500ms). That lets
          // the lift chrome (tilt, shadow, accent halo) animate in while the
          // user is still holding still — so you feel the pill get picked up
          // before you start dragging it, matching the muscle-profile pills.
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
      ),
    );
  }
}

class _FilterDrag extends Drag {
  final void Function(DragUpdateDetails) onUpdate;
  final void Function(DragEndDetails) onEnd;
  final VoidCallback onCancel;
  _FilterDrag({
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

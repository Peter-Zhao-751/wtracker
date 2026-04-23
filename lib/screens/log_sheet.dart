import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/history.dart';
import '../services/state.dart';
import '../widgets/drag_list.dart';
import '../widgets/primitives.dart';
import 'active_workout.dart' show ActiveSummary;
import 'exercise_picker.dart';

class LogSheet extends StatefulWidget {
  final Tweaks tweaks;
  final Prefs prefs;
  final History history;
  final VoidCallback onClose;
  final void Function(Template) onStart;
  /// QUICK mode commits a completed session straight to history instead of
  /// launching an active workout. The host wires this to its session-finish
  /// handler.
  final void Function(ActiveSummary)? onFinishQuick;
  const LogSheet({
    super.key,
    required this.tweaks,
    required this.prefs,
    required this.history,
    required this.onClose,
    required this.onStart,
    this.onFinishQuick,
  });

  @override
  State<LogSheet> createState() => _LogSheetState();
}

enum _LogMode { manual, quick }

class _PlannerExercise {
  final String uid;
  String name;
  String group;
  int sets;
  int reps;
  double w;
  List<_QuickSet> logs;
  _PlannerExercise({
    required this.uid,
    required this.name,
    required this.group,
    required this.sets,
    required this.reps,
    required this.w,
    List<_QuickSet>? logs,
  }) : logs = logs ?? [];
}

class _QuickSet {
  double w;
  int reps;
  _QuickSet({required this.w, required this.reps});
}

class _LogSheetState extends State<LogSheet>
    with SingleTickerProviderStateMixin {
  final List<_PlannerExercise> _exs = [];
  bool _pickerOpen = false;
  _LogMode _mode = _LogMode.quick;
  List<PrSplashData> _prQueue = const [];
  int _prIdx = 0;
  Timer? _prTimer;

  // Drag-to-dismiss: follow the finger from the handle, then either fling the
  // sheet off-screen or spring it back. Past the release threshold (or past
  // the velocity threshold) we run the same tween controller out to the full
  // sheet height before calling onClose so the close is animated, not popped.
  double _dragOffset = 0;
  double _sheetHeight = 0;
  late final AnimationController _dismissCtrl;
  Animation<double>? _dismissAnim;

  @override
  void initState() {
    super.initState();
    _dismissCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _dismissCtrl.addListener(() {
      final v = _dismissAnim?.value;
      if (v != null && mounted) setState(() => _dragOffset = v);
    });
  }

  @override
  void dispose() {
    _dismissCtrl.dispose();
    _prTimer?.cancel();
    super.dispose();
  }

  void _onHandleDragStart(DragStartDetails _) {
    _dismissCtrl.stop();
  }

  void _onHandleDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragOffset =
          (_dragOffset + d.delta.dy).clamp(0.0, double.infinity);
    });
  }

  void _onHandleDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final shouldClose =
        v > 700 || (_sheetHeight > 0 && _dragOffset > _sheetHeight * 0.18);
    if (shouldClose && _sheetHeight > 0) {
      _dismissAnim = Tween<double>(begin: _dragOffset, end: _sheetHeight)
          .animate(CurvedAnimation(
              parent: _dismissCtrl, curve: Curves.easeOutCubic));
      _dismissCtrl.duration = const Duration(milliseconds: 180);
      _dismissCtrl.forward(from: 0).whenComplete(() {
        if (mounted) widget.onClose();
      });
    } else {
      _dismissAnim = Tween<double>(begin: _dragOffset, end: 0.0).animate(
          CurvedAnimation(parent: _dismissCtrl, curve: Curves.easeOutCubic));
      _dismissCtrl.duration = const Duration(milliseconds: 220);
      _dismissCtrl.forward(from: 0);
    }
  }

  Duration get _prStep =>
      Duration(milliseconds: _prQueue.length > 1 ? 1600 : 2200);

  void _advancePR(ActiveSummary summary) {
    _prTimer?.cancel();
    _prTimer = Timer(_prStep, () {
      if (!mounted) return;
      if (_prIdx + 1 < _prQueue.length) {
        setState(() => _prIdx++);
        _advancePR(summary);
      } else {
        widget.onFinishQuick?.call(summary);
        widget.onClose();
      }
    });
  }

  void _add(Map<String, dynamic> p) {
    final reps = (p['reps'] as String?) ?? '8';
    final tplReps = int.tryParse(reps.split('-').last.replaceAll(RegExp(r'[^0-9]'), '')) ?? 8;
    final name = p['name'] as String;
    final last = widget.history.lastSetFor(name);
    final w = last?.w ?? (p['w'] as num?)?.toDouble() ?? 0;
    final repNum = last?.reps ?? tplReps;
    setState(() {
      _exs.add(_PlannerExercise(
        uid: 'ex_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        group: p['group'] as String,
        sets: 3,
        reps: repNum,
        w: w,
        logs: _mode == _LogMode.quick
            ? [_QuickSet(w: w, reps: repNum)]
            : [],
      ));
      _pickerOpen = false;
    });
  }

  void _setMode(_LogMode m) {
    setState(() {
      _mode = m;
      if (m == _LogMode.quick) {
        // Seed any exercise that has no logged sets yet with one row per
        // planned set, copying the planner's w/reps — matches the JSX demo's
        // behavior when toggling into QUICK.
        for (final e in _exs) {
          if (e.logs.isEmpty) {
            e.logs = [
              for (int i = 0; i < e.sets; i++)
                _QuickSet(w: e.w, reps: e.reps),
            ];
          }
        }
      }
    });
  }

  void _startIt() {
    if (_exs.isEmpty) return;
    final template = Template(
      id: 'log-${DateTime.now().microsecondsSinceEpoch}',
      split: 'LOG',
      name: 'QUICK LOG',
      subtitle: 'AD-HOC SESSION',
      est: _exs.fold(0, (a, e) => a + e.sets * 2),
      exercises: [
        for (final e in _exs)
          Exercise(name: e.name, group: e.group, sets: e.sets, reps: '${e.reps}', w: e.w),
      ],
    );
    widget.onStart(template);
    widget.onClose();
  }

  void _enterQuick() {
    if (_exs.isEmpty) return;
    final prs = <PrSplashData>[];
    final liveExs = <LiveExercise>[];
    for (final e in _exs) {
      double sessionMax = 0;
      final log = <SetLog>[];
      for (final s in e.logs) {
        final isPR = s.w > sessionMax && widget.history.wouldBePR(e.name, s.w);
        if (isPR) {
          sessionMax = s.w;
          prs.add(PrSplashData(lift: e.name, w: s.w, reps: s.reps));
        }
        log.add(SetLog(w: s.w, reps: s.reps, done: true, isPR: isPR));
      }
      liveExs.add(LiveExercise(
        name: e.name,
        group: e.group,
        reps: '${e.reps}',
        log: log,
      ));
    }
    var totalSets = 0;
    var totalVol = 0.0;
    for (final ex in liveExs) {
      for (final s in ex.log) {
        totalSets++;
        totalVol += s.w * s.reps;
      }
    }
    final summary = ActiveSummary(
      dur: 0,
      vol: totalVol,
      sets: totalSets,
      exs: liveExs,
      name: 'QUICK LOG',
      split: 'LOG',
      saveAsTpl: false,
      updateTpl: false,
    );
    if (prs.isEmpty) {
      widget.onFinishQuick?.call(summary);
      widget.onClose();
      return;
    }
    setState(() {
      _prQueue = prs;
      _prIdx = 0;
    });
    _advancePR(summary);
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final tu = widget.tweaks.unit.toUpperCase();
    final mq = MediaQuery.of(context);
    final sheetTop = mq.size.height * 0.08;
    _sheetHeight = mq.size.height - sheetTop;
    final dragProgress =
        _sheetHeight == 0 ? 0.0 : (_dragOffset / _sheetHeight).clamp(0.0, 1.0);
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: Colors.black.withValues(alpha: 0.55 * (1 - dragProgress)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          top: sheetTop,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: Container(
            decoration: BoxDecoration(
              color: p.paper,
              border: Border(top: BorderSide(color: p.ink, width: 3)),
              boxShadow: [BoxShadow(color: p.accent, offset: const Offset(0, -4))],
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  onVerticalDragStart: _onHandleDragStart,
                  onVerticalDragUpdate: _onHandleDragUpdate,
                  onVerticalDragEnd: _onHandleDragEnd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        color: p.ink.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: p.ink, width: 2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'LOG',
                          style: mono(
                            size: 28,
                            weight: FontWeight.w900,
                            letterSpacing: -1,
                            color: p.ink,
                          ),
                        ),
                      ),
                      IconSquare(glyph: '✕', onTap: widget.onClose, size: 32),
                    ],
                  ),
                ),
                _ModeToggle(
                  mode: _mode,
                  onChange: _setMode,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
                    children: [
                      if (_exs.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                          decoration: BoxDecoration(
                            border: Border.all(color: p.ink.withValues(alpha: 0.6), width: 2, style: BorderStyle.solid),
                          ),
                          child: Opacity(
                            opacity: 0.6,
                            child: Column(
                              children: [
                                Text(
                                  '◇',
                                  style: mono(
                                    size: 28,
                                    weight: FontWeight.w900,
                                    letterSpacing: -1,
                                    color: p.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'NO EXERCISES YET',
                                  style: mono(
                                    size: 12,
                                    weight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: p.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'TAP + ADD EXERCISE BELOW',
                                  style: mono(
                                    size: 10,
                                    letterSpacing: 1,
                                    color: p.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_exs.isNotEmpty)
                        DragList<_PlannerExercise>(
                          scrollable: false,
                          items: _exs,
                          getId: (e) => e.uid,
                          onReorder: (fromIdx, insertIdx) {
                            setState(() {
                              final to = insertIdx > fromIdx
                                  ? insertIdx - 1
                                  : insertIdx;
                              final it = _exs.removeAt(fromIdx);
                              _exs.insert(to, it);
                            });
                          },
                          itemBuilder: (_, i, ex, handle) => _PlannerCard(
                            idx: i,
                            ex: ex,
                            mode: _mode,
                            unitLabel: tu,
                            dragHandle: handle,
                            onRemove: () => setState(() => _exs.removeAt(i)),
                            onChange: (patch) => setState(() {
                              if (patch.containsKey('sets')) ex.sets = patch['sets'] as int;
                              if (patch.containsKey('reps')) ex.reps = patch['reps'] as int;
                              if (patch.containsKey('w')) ex.w = (patch['w'] as num).toDouble();
                            }),
                            onAddSet: () => setState(() {
                              final last = ex.logs.isNotEmpty
                                  ? ex.logs.last
                                  : _QuickSet(w: ex.w, reps: ex.reps);
                              ex.logs.add(_QuickSet(w: last.w, reps: last.reps));
                            }),
                            onRmSet: () => setState(() {
                              if (ex.logs.length > 1) ex.logs.removeLast();
                            }),
                            onSetChange: (si, patch) => setState(() {
                              final s = ex.logs[si];
                              if (patch.containsKey('w')) s.w = (patch['w'] as num).toDouble();
                              if (patch.containsKey('reps')) s.reps = patch['reps'] as int;
                            }),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => setState(() => _pickerOpen = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: p.paper,
                            border: Border.all(color: p.ink, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+  ADD EXERCISE',
                            style: mono(
                              size: 12,
                              weight: FontWeight.w800,
                              letterSpacing: 1,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: p.paper,
              border: Border(top: BorderSide(color: p.ink, width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: BrutalButton(
                    label: 'CANCEL',
                    variant: BtnVariant.outline,
                    onPressed: widget.onClose,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: BrutalButton(
                    label: _mode == _LogMode.manual
                        ? '▶ START · ${_exs.length} EX'
                        : '↵ ENTER · ${_exs.length} EX',
                    onPressed: _exs.isEmpty
                        ? null
                        : (_mode == _LogMode.manual ? _startIt : _enterQuick),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_pickerOpen)
          ExercisePickerSheet(
            prefs: widget.prefs,
            onClose: () => setState(() => _pickerOpen = false),
            onPick: _add,
          ),
        if (_prQueue.isNotEmpty)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: PrSplash(
                data: _prQueue[_prIdx],
                unit: widget.tweaks.unit,
                index: _prIdx + 1,
                total: _prQueue.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlannerCard extends StatelessWidget {
  final int idx;
  final _PlannerExercise ex;
  final _LogMode mode;
  final String unitLabel;
  final DragHandleBuilder dragHandle;
  final VoidCallback onRemove;
  final void Function(Map<String, dynamic>) onChange;
  final VoidCallback onAddSet;
  final VoidCallback onRmSet;
  final void Function(int setIdx, Map<String, dynamic>) onSetChange;
  const _PlannerCard({
    required this.idx,
    required this.ex,
    required this.mode,
    required this.unitLabel,
    required this.dragHandle,
    required this.onRemove,
    required this.onChange,
    required this.onAddSet,
    required this.onRmSet,
    required this.onSetChange,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border.all(color: p.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: p.ink,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                dragHandle(
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text(
                      '⋮⋮',
                      style: mono(
                        size: 14,
                        weight: FontWeight.w900,
                        letterSpacing: -1,
                        color: p.paper.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    border: Border.all(color: p.paper, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (idx + 1).toString().padLeft(2, '0'),
                    style: mono(
                      size: 10,
                      weight: FontWeight.w800,
                      color: p.paper,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.name,
                        style: mono(size: 12, weight: FontWeight.w800, color: p.paper),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        ex.group,
                        style: mono(
                          size: 8,
                          weight: FontWeight.w700,
                          letterSpacing: 1,
                          color: p.paper.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: p.accent,
                      border: Border.all(color: p.paper, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '✕',
                      style: mono(
                        size: 10,
                        weight: FontWeight.w800,
                        color: p.accentInk,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (mode == _LogMode.manual)
            Row(
              children: [
                Expanded(
                  child: _FieldStepper(
                    label: 'SETS',
                    value: ex.sets,
                    step: 1,
                    min: 1,
                    max: 10,
                    onChange: (v) => onChange({'sets': v}),
                    rightBorder: true,
                  ),
                ),
                Expanded(
                  child: _FieldStepper(
                    label: 'REPS',
                    value: ex.reps,
                    step: 1,
                    min: 1,
                    onChange: (v) => onChange({'reps': v}),
                    rightBorder: true,
                  ),
                ),
                Expanded(
                  child: _FieldStepper(
                    label: 'WT $unitLabel',
                    value: ex.w.toInt(),
                    step: 5,
                    min: 0,
                    onChange: (v) => onChange({'w': v}),
                  ),
                ),
              ],
            )
          else
            _QuickLogTable(
              ex: ex,
              unitLabel: unitLabel,
              onAddSet: onAddSet,
              onRmSet: onRmSet,
              onSetChange: onSetChange,
            ),
        ],
      ),
    );
  }
}

class _QuickLogTable extends StatelessWidget {
  final _PlannerExercise ex;
  final String unitLabel;
  final VoidCallback onAddSet;
  final VoidCallback onRmSet;
  final void Function(int setIdx, Map<String, dynamic>) onSetChange;
  const _QuickLogTable({
    required this.ex,
    required this.unitLabel,
    required this.onAddSet,
    required this.onRmSet,
    required this.onSetChange,
  });

  TableColumnWidth get _setCol => const FixedColumnWidth(36);

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final labelStyle = mono(
      size: 8,
      weight: FontWeight.w800,
      letterSpacing: 1.5,
      color: p.ink.withValues(alpha: 0.6),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.ink, width: 1.5)),
          ),
          child: Table(
            columnWidths: {0: _setCol, 1: const FlexColumnWidth(), 2: const FlexColumnWidth()},
            children: [
              TableRow(children: [
                Text('SET', style: labelStyle),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text('WT $unitLabel', style: labelStyle),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text('REPS', style: labelStyle),
                ),
              ]),
            ],
          ),
        ),
        for (int si = 0; si < ex.logs.length; si++)
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              border: si < ex.logs.length - 1
                  ? Border(bottom: BorderSide(color: p.ink.withValues(alpha: 0.4), width: 1))
                  : null,
            ),
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: {0: _setCol, 1: const FlexColumnWidth(), 2: const FlexColumnWidth()},
              children: [
                TableRow(children: [
                  Text(
                    (si + 1).toString().padLeft(2, '0'),
                    style: mono(size: 11, weight: FontWeight.w800, color: p.ink),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _NumInput(
                      value: ex.logs[si].w.toInt(),
                      step: 5,
                      min: 0,
                      onChange: (v) => onSetChange(si, {'w': v}),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _NumInput(
                      value: ex.logs[si].reps,
                      step: 1,
                      min: 1,
                      onChange: (v) => onSetChange(si, {'reps': v}),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.ink, width: 1.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SetActionButton(
                  label: '− SET',
                  enabled: ex.logs.length > 1,
                  onTap: onRmSet,
                  rightBorder: true,
                ),
              ),
              Expanded(
                child: _SetActionButton(
                  label: '+ SET',
                  enabled: true,
                  onTap: onAddSet,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool rightBorder;
  const _SetActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.rightBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          border: rightBorder
              ? Border(right: BorderSide(color: p.ink, width: 1.5))
              : null,
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.3,
          child: Text(
            label,
            style: mono(
              size: 10,
              weight: FontWeight.w800,
              letterSpacing: 1.5,
              color: p.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _NumInput extends StatefulWidget {
  final int value;
  final int step;
  final int min;
  final ValueChanged<int> onChange;
  const _NumInput({
    required this.value,
    required this.step,
    required this.min,
    required this.onChange,
  });

  @override
  State<_NumInput> createState() => _NumInputState();
}

class _NumInputState extends State<_NumInput> {
  late final TextEditingController _ctl = TextEditingController(text: '${widget.value}');
  final FocusNode _fn = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _fn.addListener(() {
      if (_fn.hasFocus) {
        _focused = true;
      } else {
        _focused = false;
        final n = int.tryParse(_ctl.text) ?? widget.min;
        widget.onChange(n < widget.min ? widget.min : n);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _NumInput old) {
    super.didUpdateWidget(old);
    if (!_focused && old.value != widget.value) {
      _ctl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _fn.dispose();
    super.dispose();
  }

  void _bump(int delta) {
    final next = widget.value + delta;
    widget.onChange(next < widget.min ? widget.min : next);
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      height: 26,
      decoration: BoxDecoration(border: Border.all(color: p.ink, width: 1.5)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _bump(-widget.step),
            child: Container(
              width: 22,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: p.ink, width: 1.5)),
              ),
              alignment: Alignment.center,
              child: Text('−', style: mono(size: 12, weight: FontWeight.w800, color: p.ink)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctl,
              focusNode: _fn,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onTapOutside: (_) => _fn.unfocus(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: mono(size: 12, weight: FontWeight.w800, color: p.ink),
            ),
          ),
          GestureDetector(
            onTap: () => _bump(widget.step),
            child: Container(
              width: 22,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: p.ink, width: 1.5)),
              ),
              alignment: Alignment.center,
              child: Text('+', style: mono(size: 12, weight: FontWeight.w800, color: p.ink)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final _LogMode mode;
  final ValueChanged<_LogMode> onChange;
  const _ModeToggle({required this.mode, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    Widget cell(_LogMode m, String label, {bool rightBorder = false}) {
      final active = m == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChange(m),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: active ? p.accent : p.paper,
              border: rightBorder
                  ? Border(right: BorderSide(color: p.ink, width: 2))
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: mono(
                size: 14,
                weight: FontWeight.w900,
                letterSpacing: 3,
                color: active ? p.accentInk : p.ink,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.ink, width: 2)),
      ),
      child: Row(
        children: [
          cell(_LogMode.quick, 'QUICK LOG', rightBorder: true),
          cell(_LogMode.manual, 'CREATE PLAN'),
        ],
      ),
    );
  }
}

class _FieldStepper extends StatefulWidget {
  final String label;
  final int value;
  final int step;
  final int min;
  final int? max;
  final bool rightBorder;
  final ValueChanged<int> onChange;
  const _FieldStepper({
    required this.label,
    required this.value,
    required this.step,
    required this.min,
    this.max,
    required this.onChange,
    this.rightBorder = false,
  });

  @override
  State<_FieldStepper> createState() => _FieldStepperState();
}

class _FieldStepperState extends State<_FieldStepper> {
  late final TextEditingController _ctl = TextEditingController(text: '${widget.value}');
  final FocusNode _fn = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _fn.addListener(() {
      if (_fn.hasFocus) {
        _focused = true;
      } else {
        _focused = false;
        final n = int.tryParse(_ctl.text) ?? 0;
        widget.onChange(n.clamp(widget.min, widget.max ?? 99999));
      }
    });
  }

  @override
  void didUpdateWidget(covariant _FieldStepper old) {
    super.didUpdateWidget(old);
    if (!_focused && old.value != widget.value) {
      _ctl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _fn.dispose();
    super.dispose();
  }

  void _apply(int delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max ?? 99999);
    widget.onChange(next);
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: widget.rightBorder
            ? Border(right: BorderSide(color: p.ink, width: 1.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: mono(
              size: 8,
              weight: FontWeight.w700,
              letterSpacing: 1.5,
              color: p.ink.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 28,
            decoration: BoxDecoration(border: Border.all(color: p.ink, width: 1.5)),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _apply(-widget.step),
                  child: Container(
                    width: 22,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: p.ink, width: 1.5)),
                    ),
                    alignment: Alignment.center,
                    child: Text('−', style: mono(size: 12, weight: FontWeight.w800, color: p.ink)),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    focusNode: _fn,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onTapOutside: (_) => _fn.unfocus(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: mono(size: 12, weight: FontWeight.w800, color: p.ink),
                  ),
                ),
                GestureDetector(
                  onTap: () => _apply(widget.step),
                  child: Container(
                    width: 22,
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: p.ink, width: 1.5)),
                    ),
                    alignment: Alignment.center,
                    child: Text('+', style: mono(size: 12, weight: FontWeight.w800, color: p.ink)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

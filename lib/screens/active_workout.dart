import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../history.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/primitives.dart';
import 'exercise_picker.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final Template template;
  final Tweaks tweaks;
  final Prefs prefs;
  final History history;
  final void Function(ActiveSummary) onFinish;
  final VoidCallback onClose;
  const ActiveWorkoutScreen({
    super.key,
    required this.template,
    required this.tweaks,
    required this.prefs,
    required this.history,
    required this.onFinish,
    required this.onClose,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class ActiveSummary {
  final int dur;
  final double vol;
  final int sets;
  final List<LiveExercise> exs;
  final String name;
  final String split;
  final bool saveAsTpl;
  final bool updateTpl;
  final String? newName;
  ActiveSummary({
    required this.dur,
    required this.vol,
    required this.sets,
    required this.exs,
    required this.name,
    required this.split,
    required this.saveAsTpl,
    required this.updateTpl,
    this.newName,
  });
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with SingleTickerProviderStateMixin {
  late List<LiveExercise> _exs;
  int _sessionSec = 0;
  int _restSec = 0;
  int _restTotalSec = 0;
  bool _restActive = false;
  bool _restDone = false;
  int _activeIdx = 0;
  bool _pickerOpen = false;
  _PRData? _showPR;
  Timer? _sessionTimer;
  Timer? _restTimer;
  Timer? _restDoneTimer;
  Timer? _prTimer;
  AnimationController? _restCtrl;

  bool get _isLog => widget.template.split == 'LOG';

  double _conv(double lbs) => widget.tweaks.unit == 'kg' ? (lbs * 0.4536).roundToDouble() : lbs;

  @override
  void initState() {
    super.initState();
    _exs = widget.template.exercises.map((ex) {
      final repNum = int.tryParse(ex.reps.split('-').last.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5;
      return LiveExercise(
        name: ex.name,
        group: ex.group,
        reps: ex.reps,
        log: [
          for (int i = 0; i < ex.sets; i++)
            SetLog(w: _conv(ex.w), reps: repNum),
        ],
      );
    }).toList();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sessionSec++);
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    _restDoneTimer?.cancel();
    _prTimer?.cancel();
    _restCtrl?.dispose();
    super.dispose();
  }

  void _startRest() {
    _restTimer?.cancel();
    final total = widget.tweaks.defaultRest;
    // SingleTickerProviderStateMixin only hands out ONE ticker for the life
    // of this state — disposing + recreating the controller throws on the
    // second set. Keep a single controller, retarget its duration, and
    // forward(from: 0) to replay.
    final ctrl = _restCtrl ??= AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          _restTimer?.cancel();
          setState(() {
            _restSec = 0;
            _restActive = false;
            _restDone = true;
          });
          _restDoneTimer?.cancel();
          _restDoneTimer = Timer(const Duration(seconds: 7), () {
            if (mounted) setState(() => _restDone = false);
          });
        }
      });
    ctrl.stop();
    ctrl.duration = Duration(seconds: total);
    setState(() {
      _restTotalSec = total;
      _restSec = total;
      _restActive = true;
      _restDone = false;
    });
    ctrl.forward(from: 0);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_restActive) {
        t.cancel();
        return;
      }
      final remaining = (_restTotalSec - ctrl.value * _restTotalSec).ceil();
      setState(() => _restSec = remaining.clamp(0, _restTotalSec));
    });
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  void _toggleDone(int exIdx, int setIdx) {
    final s = _exs[exIdx].log[setIdx];
    setState(() {
      s.done = !s.done;
      if (s.done) {
        final exName = _exs[exIdx].name;
        // PR when this set's weight beats every previously logged set for the
        // same lift and it isn't already beaten earlier in this session.
        final sessionMax = _exs[exIdx]
            .log
            .where((x) => x.done && x != s)
            .fold<double>(0, (a, b) => b.w > a ? b.w : a);
        if (s.w > sessionMax && widget.history.wouldBePR(exName, s.w)) {
          s.isPR = true;
          _showPR = _PRData(lift: exName, w: s.w, reps: s.reps);
          _prTimer?.cancel();
          _prTimer = Timer(const Duration(milliseconds: 2200), () {
            if (mounted) setState(() => _showPR = null);
          });
        }
        _startRest();
      } else {
        s.isPR = false;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _adjust(int exIdx, int setIdx, String field, num delta) {
    setState(() {
      final s = _exs[exIdx].log[setIdx];
      if (field == 'w') {
        s.w = (s.w + delta).clamp(0, double.infinity).toDouble();
      } else {
        s.reps = (s.reps + delta.toInt()).clamp(0, 1000);
      }
    });
  }

  void _setVal(int exIdx, int setIdx, String field, num v) {
    setState(() {
      final s = _exs[exIdx].log[setIdx];
      if (field == 'w') {
        s.w = v.toDouble().clamp(0, double.infinity).toDouble();
      } else {
        s.reps = v.toInt().clamp(0, 1000);
      }
    });
  }

  void _addSet(int exIdx) {
    setState(() {
      final log = _exs[exIdx].log;
      final last = log.isNotEmpty ? log.last : SetLog(w: 0, reps: 5);
      log.add(SetLog(w: last.w, reps: last.reps));
    });
  }

  void _removeSet(int exIdx) {
    setState(() {
      if (_exs[exIdx].log.length > 1) {
        _exs[exIdx].log.removeLast();
      }
    });
  }

  void _addExercise(Map<String, dynamic> p) {
    final reps = (p['reps'] as String?) ?? '8';
    final repNum = int.tryParse(reps.split('-').last.replaceAll(RegExp(r'[^0-9]'), '')) ?? 8;
    final w = _conv((p['w'] as num?)?.toDouble() ?? 0);
    setState(() {
      _exs.add(LiveExercise(
        name: p['name'] as String,
        group: p['group'] as String,
        reps: reps,
        log: [for (int i = 0; i < 3; i++) SetLog(w: w, reps: repNum)],
      ));
      _activeIdx = _exs.length - 1;
      _pickerOpen = false;
    });
  }

  int get _totalDone {
    var n = 0;
    for (final ex in _exs) {
      for (final s in ex.log) {
        if (s.done) n++;
      }
    }
    return n;
  }

  int get _totalSets {
    var n = 0;
    for (final ex in _exs) {
      n += ex.log.length;
    }
    return n;
  }

  double get _totalVol {
    var v = 0.0;
    for (final ex in _exs) {
      for (final s in ex.log) {
        if (s.done) v += s.w * s.reps;
      }
    }
    return v;
  }

  void _requestFinish() async {
    final palette = BrutalColors.of(context);
    final result = await showDialog<_SavePromptResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => BrutalColors(
        palette: palette,
        child: Material(
          type: MaterialType.transparency,
          child: _SavePromptDialog(
            mode: _isLog ? _SaveMode.name : _SaveMode.choose,
            templateName: widget.template.name,
            initialName: _isLog
                ? (widget.template.name == 'QUICK LOG' ? '' : widget.template.name)
                : '${widget.template.name} V2',
          ),
        ),
      ),
    );
    if (result == null) return;
    widget.onFinish(ActiveSummary(
      dur: _sessionSec,
      vol: _totalVol,
      sets: _totalDone,
      exs: _exs,
      name: widget.template.name,
      split: widget.template.split,
      saveAsTpl: result.save && result.asNew,
      updateTpl: result.save && !result.asNew,
      newName: result.newName,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final isDark = widget.tweaks.isDark;
    final topInset = MediaQuery.of(context).padding.top;
    final kbInset = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        Container(color: p.paper),
        Column(
          children: [
            SizedBox(
              height: topInset,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.paper,
                        border: isDark
                            ? null
                            : Border(right: BorderSide(color: p.ink, width: 2)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: _restActive ? p.accent : p.paper,
                      alignment: Alignment.bottomLeft,
                      child: _restActive && _restCtrl != null
                          ? AnimatedBuilder(
                              animation: _restCtrl!,
                              builder: (_, _) => FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor:
                                    (1 - _restCtrl!.value).clamp(0.0, 1.0),
                                child: Container(
                                  color: p.accentInk.withValues(alpha: 0.45),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.ink, width: 2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: p.paper,
                        border: Border(right: BorderSide(color: p.ink, width: 2)),
                      ),
                      child: _timerCell('SESSION', _fmt(_sessionSec), false),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(color: _restActive ? p.accent : p.paper),
                        ),
                        if (_restActive && _restCtrl != null)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _restCtrl!,
                              builder: (_, _) => FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor:
                                    (1 - _restCtrl!.value).clamp(0.0, 1.0),
                                child: Container(
                                  color: p.accentInk.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: _timerCell(
                            _restActive ? 'REST' : 'REST TIMER',
                            _restActive ? _fmt(_restSec) : '--:--',
                            false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: p.ink,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.template.split} · LIVE',
                          style: mono(
                            size: 9,
                            weight: FontWeight.w700,
                            letterSpacing: 2,
                            color: p.paper.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          widget.template.name,
                          style: mono(
                            size: 18,
                            weight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: p.paper,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'SETS',
                        style: mono(
                          size: 9,
                          weight: FontWeight.w700,
                          letterSpacing: 2,
                          color: p.paper.withValues(alpha: 0.6),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          style: mono(size: 18, weight: FontWeight.w800, color: p.paper),
                          children: [
                            TextSpan(text: '$_totalDone'),
                            TextSpan(
                              text: '/$_totalSets',
                              style: mono(
                                size: 18,
                                weight: FontWeight.w800,
                                color: p.paper.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: p.paper,
                border: Border(bottom: BorderSide(color: p.ink, width: 2)),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _totalSets == 0 ? 0 : (_totalDone / _totalSets),
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.accent,
                      border: _totalDone > 0
                          ? Border(right: BorderSide(color: p.ink, width: 2))
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
                children: [
                  for (int i = 0; i < _exs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ExerciseBlock(
                        ex: _exs[i],
                        idx: i,
                        expanded: _activeIdx == i,
                        unit: widget.tweaks.unit,
                        onToggle: () => setState(() => _activeIdx = _activeIdx == i ? -1 : i),
                        onDone: (si) => _toggleDone(i, si),
                        onAdjust: (si, f, d) => _adjust(i, si, f, d),
                        onSet: (si, f, v) => _setVal(i, si, f, v),
                        onAddSet: () => _addSet(i),
                        onRemoveSet: () => _removeSet(i),
                      ),
                    ),
                  if (_isLog)
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
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              12,
              10,
              12,
              10 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: p.paper,
              border: Border(top: BorderSide(color: p.ink, width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: BrutalButton(
                    label: '✕ EXIT',
                    variant: BtnVariant.outline,
                    onPressed: widget.onClose,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: BrutalButton(
                    label: '■ FINISH · ${_fmt(_sessionSec)}',
                    onPressed: _requestFinish,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_restDone)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _restDone = false),
              child: Container(
                color: p.accent,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '◉',
                      style: mono(
                        size: 72,
                        weight: FontWeight.w900,
                        letterSpacing: -3,
                        color: p.accentInk,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'REST OVER',
                      style: mono(
                        size: 36,
                        weight: FontWeight.w900,
                        letterSpacing: 2,
                        color: p.accentInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'NEXT SET',
                      style: mono(
                        size: 13,
                        weight: FontWeight.w700,
                        letterSpacing: 3,
                        color: p.accentInk.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: () => setState(() => _restDone = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          color: p.accentInk,
                          border: Border.all(color: p.accentInk, width: 2),
                        ),
                        child: Text(
                          'DISMISS',
                          style: mono(
                            size: 13,
                            weight: FontWeight.w800,
                            letterSpacing: 2,
                            color: p.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'AUTO-DISMISS IN 7s · TAP ANYWHERE',
                      style: mono(
                        size: 9,
                        weight: FontWeight.w700,
                        letterSpacing: 2,
                        color: p.accentInk.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_showPR != null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: -0.035,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                  decoration: BoxDecoration(
                    color: p.accent,
                    border: Border.all(color: p.ink, width: 3),
                    boxShadow: [BoxShadow(color: p.ink, offset: const Offset(6, 6))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '★',
                        style: mono(
                          size: 48,
                          weight: FontWeight.w900,
                          letterSpacing: -2,
                          color: p.accentInk,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'NEW PR',
                        style: mono(
                          size: 28,
                          weight: FontWeight.w900,
                          letterSpacing: 2,
                          color: p.accentInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _showPR!.lift,
                        style: mono(
                          size: 13,
                          weight: FontWeight.w700,
                          color: p.accentInk.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_showPR!.w.toStringAsFixed(0)} ${widget.tweaks.unit.toUpperCase()} × ${_showPR!.reps}',
                        style: mono(size: 22, weight: FontWeight.w800, color: p.accentInk),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_pickerOpen)
          ExercisePickerSheet(
            prefs: widget.prefs,
            onClose: () => setState(() => _pickerOpen = false),
            onPick: _addExercise,
          ),
        if (kbInset > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: kbInset,
            child: GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: p.ink,
                  border: Border(bottom: BorderSide(color: p.accent, width: 2)),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'DONE',
                  style: mono(
                    size: 13,
                    weight: FontWeight.w900,
                    letterSpacing: 2,
                    color: p.accent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _timerCell(String label, String value, bool rest) {
    final p = BrutalColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: mono(
            size: 9,
            weight: FontWeight.w700,
            letterSpacing: 2,
            color: p.ink.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: mono(
            size: 22,
            weight: FontWeight.w800,
            letterSpacing: -0.5,
            color: p.ink,
          ),
        ),
      ],
    );
  }
}

class _PRData {
  final String lift;
  final double w;
  final int reps;
  _PRData({required this.lift, required this.w, required this.reps});
}

class _ExerciseBlock extends StatelessWidget {
  final LiveExercise ex;
  final int idx;
  final bool expanded;
  final String unit;
  final VoidCallback onToggle;
  final void Function(int setIdx) onDone;
  final void Function(int setIdx, String field, num delta) onAdjust;
  final void Function(int setIdx, String field, num value) onSet;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveSet;

  const _ExerciseBlock({
    required this.ex,
    required this.idx,
    required this.expanded,
    required this.unit,
    required this.onToggle,
    required this.onDone,
    required this.onAdjust,
    required this.onSet,
    required this.onAddSet,
    required this.onRemoveSet,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final doneCount = ex.log.where((s) => s.done).length;
    final allDone = doneCount == ex.log.length;

    return Container(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border.all(color: p.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: expanded ? p.ink : p.paper,
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: expanded ? p.paper : p.ink,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (idx + 1).toString().padLeft(2, '0'),
                      style: mono(
                        size: 11,
                        weight: FontWeight.w800,
                        color: expanded ? p.paper : p.ink,
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
                          style: mono(
                            size: 13,
                            weight: FontWeight.w800,
                            color: expanded ? p.paper : p.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${ex.group} · ${ex.log.length}×${ex.reps}',
                          style: mono(
                            size: 9,
                            weight: FontWeight.w700,
                            letterSpacing: 1,
                            color: (expanded ? p.paper : p.ink).withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: allDone
                        ? p.accent
                        : (expanded ? p.paper : p.ink),
                    child: Text(
                      '$doneCount/${ex.log.length}',
                      style: mono(
                        size: 12,
                        weight: FontWeight.w800,
                        color: allDone
                            ? p.accentInk
                            : (expanded ? p.ink : p.paper),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: p.ink, width: 1)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            'SET',
                            style: mono(
                              size: 9,
                              weight: FontWeight.w700,
                              letterSpacing: 1,
                              color: p.ink.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'WEIGHT (${unit.toUpperCase()})',
                            textAlign: TextAlign.center,
                            style: mono(
                              size: 9,
                              weight: FontWeight.w700,
                              letterSpacing: 1,
                              color: p.ink.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'REPS',
                            textAlign: TextAlign.center,
                            style: mono(
                              size: 9,
                              weight: FontWeight.w700,
                              letterSpacing: 1,
                              color: p.ink.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '✓',
                            textAlign: TextAlign.center,
                            style: mono(
                              size: 9,
                              weight: FontWeight.w700,
                              color: p.ink.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (int si = 0; si < ex.log.length; si++)
                    _SetRow(
                      si: si,
                      s: ex.log[si],
                      last: si == ex.log.length - 1,
                      onDone: () => onDone(si),
                      onAdjustW: (d) => onAdjust(si, 'w', d),
                      onAdjustR: (d) => onAdjust(si, 'reps', d),
                      onSetW: (v) => onSet(si, 'w', v),
                      onSetR: (v) => onSet(si, 'reps', v),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          label: '− REMOVE SET',
                          accent: false,
                          disabled: ex.log.length <= 1,
                          onTap: onRemoveSet,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ActionBtn(
                          label: '+ ADD SET',
                          accent: true,
                          onTap: onAddSet,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int si;
  final SetLog s;
  final bool last;
  final VoidCallback onDone;
  final void Function(num) onAdjustW;
  final void Function(num) onAdjustR;
  final void Function(num) onSetW;
  final void Function(num) onSetR;
  const _SetRow({
    required this.si,
    required this.s,
    required this.last,
    required this.onDone,
    required this.onAdjustW,
    required this.onAdjustR,
    required this.onSetW,
    required this.onSetR,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: p.ink.withValues(alpha: 0.6), width: 1)),
            ),
      child: Opacity(
        opacity: s.done ? 0.55 : 1,
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${si + 1}',
                style: mono(size: 12, weight: FontWeight.w800, color: p.ink),
              ),
            ),
            Expanded(
              child: _Stepper(
                value: s.w.toStringAsFixed(0),
                onMinus: () => onAdjustW(-5),
                onPlus: () => onAdjustW(5),
                onChanged: (v) => onSetW(double.tryParse(v) ?? 0),
                disabled: s.done,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Stepper(
                value: '${s.reps}',
                onMinus: () => onAdjustR(-1),
                onPlus: () => onAdjustR(1),
                onChanged: (v) => onSetR(int.tryParse(v) ?? 0),
                disabled: s.done,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDone,
              child: Container(
                width: 38,
                height: 32,
                decoration: BoxDecoration(
                  color: s.done ? (s.isPR ? p.accent : p.ink) : p.paper,
                  border: Border.all(color: p.ink, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  s.isPR ? '★' : (s.done ? '✓' : ''),
                  style: mono(
                    size: 14,
                    weight: FontWeight.w800,
                    color: s.done ? (s.isPR ? p.ink : p.paper) : p.ink,
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

class _Stepper extends StatefulWidget {
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onChanged;
  final bool disabled;
  const _Stepper({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
    required this.disabled,
  });

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  late final TextEditingController _ctl = TextEditingController(text: widget.value);
  bool _focused = false;
  final FocusNode _fn = FocusNode();

  @override
  void initState() {
    super.initState();
    _fn.addListener(() {
      if (_fn.hasFocus) {
        _focused = true;
      } else {
        _focused = false;
        widget.onChanged(_ctl.text);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _Stepper old) {
    super.didUpdateWidget(old);
    if (!_focused && old.value != widget.value) {
      _ctl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      height: 32,
      decoration: BoxDecoration(border: Border.all(color: p.ink, width: 1.5)),
      child: Row(
        children: [
          _btn(context, '−', widget.disabled ? null : widget.onMinus, Border(right: BorderSide(color: p.ink, width: 1.5))),
          Expanded(
            child: IgnorePointer(
              ignoring: widget.disabled,
              child: TextField(
                controller: _ctl,
                focusNode: _fn,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: widget.onChanged,
                onTapOutside: (_) => _fn.unfocus(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: mono(size: 13, weight: FontWeight.w800, color: p.ink),
              ),
            ),
          ),
          _btn(context, '+', widget.disabled ? null : widget.onPlus, Border(left: BorderSide(color: p.ink, width: 1.5))),
        ],
      ),
    );
  }

  Widget _btn(BuildContext context, String l, VoidCallback? tap, Border border) {
    final p = BrutalColors.of(context);
    return GestureDetector(
      onTap: tap,
      child: Container(
        width: 28,
        decoration: BoxDecoration(border: border),
        alignment: Alignment.center,
        child: Text(l, style: mono(size: 14, weight: FontWeight.w800, color: p.ink)),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final bool accent;
  final bool disabled;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.accent,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: accent ? p.accent : p.paper,
            border: Border.all(color: p.ink, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: mono(
              size: 11,
              weight: FontWeight.w800,
              letterSpacing: 1,
              color: accent ? p.accentInk : p.ink,
            ),
          ),
        ),
      ),
    );
  }
}

enum _SaveMode { name, choose }

class _SavePromptResult {
  final bool save;
  final bool asNew;
  final String? newName;
  _SavePromptResult({required this.save, this.asNew = false, this.newName});
}

class _SavePromptDialog extends StatefulWidget {
  final _SaveMode mode;
  final String templateName;
  final String initialName;
  const _SavePromptDialog({
    required this.mode,
    required this.templateName,
    required this.initialName,
  });

  @override
  State<_SavePromptDialog> createState() => _SavePromptDialogState();
}

class _SavePromptDialogState extends State<_SavePromptDialog> {
  late final TextEditingController _nameCtl = TextEditingController(text: widget.initialName);
  late final TextEditingController _newNameCtl = TextEditingController(text: widget.initialName);
  String _choice = 'update';

  @override
  void dispose() {
    _nameCtl.dispose();
    _newNameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.paper,
              border: Border.all(color: p.ink, width: 3),
              boxShadow: [BoxShadow(color: p.accent, offset: const Offset(6, 6))],
            ),
            child: widget.mode == _SaveMode.name
                ? _buildNameMode(context, p)
                : _buildChooseMode(context, p),
          ),
        ),
      ),
    );
  }

  Widget _buildNameMode(BuildContext context, BrutalPalette p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FINISH · SAVE',
          style: mono(
            size: 9,
            weight: FontWeight.w700,
            letterSpacing: 2,
            color: p.ink.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'NAME THIS TEMPLATE?',
          style: mono(
            size: 18,
            weight: FontWeight.w900,
            letterSpacing: -0.5,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(border: Border.all(color: p.ink, width: 2)),
          child: TextField(
            controller: _nameCtl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 24,
            onChanged: (_) => setState(() {}),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              hintText: 'E.G. MONDAY PUSH',
              hintStyle: mono(size: 14, color: p.ink.withValues(alpha: 0.4)),
            ),
            style: mono(size: 14, weight: FontWeight.w800, color: p.ink),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'LEAVE BLANK TO FINISH WITHOUT SAVING',
          style: mono(
            size: 9,
            weight: FontWeight.w700,
            letterSpacing: 1,
            color: p.ink.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: BrutalButton(
                label: "DON'T SAVE",
                variant: BtnVariant.outline,
                onPressed: () => Navigator.pop(context, _SavePromptResult(save: false)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: BrutalButton(
                label: '✓ SAVE TPL',
                onPressed: _nameCtl.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(
                          context,
                          _SavePromptResult(
                            save: true,
                            asNew: true,
                            newName: _nameCtl.text.trim().toUpperCase(),
                          ),
                        ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChooseMode(BuildContext context, BrutalPalette p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FINISH · SAVE',
          style: mono(
            size: 9,
            weight: FontWeight.w700,
            letterSpacing: 2,
            color: p.ink.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          children: [
            Text(
              'SAVE CHANGES TO ',
              style: mono(size: 18, weight: FontWeight.w900, letterSpacing: -0.5, color: p.ink),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              color: p.accent,
              child: Text(
                widget.templateName,
                style: mono(size: 18, weight: FontWeight.w900, color: p.accentInk),
              ),
            ),
            Text(
              '?',
              style: mono(size: 18, weight: FontWeight.w900, color: p.ink),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _optBtn(p, 'update', '↻ UPDATE "${widget.templateName}"'),
        const SizedBox(height: 6),
        _optBtn(p, 'new', '+ SAVE AS NEW TEMPLATE'),
        const SizedBox(height: 6),
        _optBtn(p, 'none', "✕ DON'T SAVE"),
        if (_choice == 'new') ...[
          const SizedBox(height: 10),
          Text(
            'NEW NAME',
            style: mono(
              size: 9,
              weight: FontWeight.w700,
              letterSpacing: 1.5,
              color: p.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(border: Border.all(color: p.ink, width: 2)),
            child: TextField(
              controller: _newNameCtl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 24,
              onChanged: (_) => setState(() {}),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: mono(size: 14, weight: FontWeight.w800, color: p.ink),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: BrutalButton(
                label: 'CANCEL',
                variant: BtnVariant.outline,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: BrutalButton(
                label: '✓ CONFIRM',
                onPressed: (_choice == 'new' && _newNameCtl.text.trim().isEmpty)
                    ? null
                    : () {
                        if (_choice == 'none') {
                          Navigator.pop(context, _SavePromptResult(save: false));
                        } else if (_choice == 'update') {
                          Navigator.pop(context, _SavePromptResult(save: true));
                        } else {
                          Navigator.pop(
                            context,
                            _SavePromptResult(
                              save: true,
                              asNew: true,
                              newName: _newNameCtl.text.trim().toUpperCase(),
                            ),
                          );
                        }
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _optBtn(BrutalPalette p, String key, String label) {
    final active = _choice == key;
    return GestureDetector(
      onTap: () => setState(() => _choice = key),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? p.ink : p.paper,
          border: Border.all(color: p.ink, width: 2),
        ),
        child: Text(
          label,
          style: mono(
            size: 12,
            weight: FontWeight.w800,
            letterSpacing: 1,
            color: active ? p.paper : p.ink,
          ),
        ),
      ),
    );
  }
}

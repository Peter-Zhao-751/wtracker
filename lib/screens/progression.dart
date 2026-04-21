import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/history.dart';
import '../services/state.dart';
import '../widgets/drag_list.dart';
import '../widgets/group_grid.dart';
import '../widgets/primitives.dart';

class ProgressionScreen extends StatefulWidget {
  final Tweaks tweaks;
  final Prefs prefs;
  final History history;
  const ProgressionScreen({
    super.key,
    required this.tweaks,
    required this.prefs,
    required this.history,
  });

  @override
  State<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends State<ProgressionScreen> {
  String _focus = 'LEGS';
  String _scale = '12W';

  static const _scaleOpts = ['4W', '12W', '26W', '52W', 'ALL'];

  int _weeksForScale(String s) {
    switch (s) {
      case '4W':
        return 4;
      case '12W':
        return 12;
      case '26W':
        return 26;
      case '52W':
        return 52;
      case 'ALL':
        return widget.history.lifetimeWeeks;
    }
    return 12;
  }

  String _scaleTagLabel(String s) => s == 'ALL' ? 'LIFETIME' : s;

  String _volConv(double v) => widget.tweaks.unit == 'kg'
      ? (v * 0.4536).toStringAsFixed(1)
      : v.toStringAsFixed(1);
  String _volUnit() => widget.tweaks.unit == 'kg' ? 't' : 'k';
  double _wConv(double lbs) =>
      widget.tweaks.unit == 'kg' ? (lbs * 0.4536).roundToDouble() : lbs;

  @override
  void initState() {
    super.initState();
    widget.history.addListener(_onHistory);
  }

  @override
  void dispose() {
    widget.history.removeListener(_onHistory);
    super.dispose();
  }

  void _onHistory() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final weeks = _weeksForScale(_scale);
    final data = widget.history.progressionFor(_focus, weeks: weeks);
    final delta = data.last - data.first;
    final exSeries = widget.history.perExerciseMaxInGroup(_focus, weeks);
    final sessions = widget.history.sessionRows();
    final scaleTag = _scaleTagLabel(_scale);
    final deltaTag = _scale == 'ALL' ? 'ALL Δ' : '$_scale DELTA';

    return ListenableBuilder(
      listenable: widget.prefs,
      builder: (context, _) {
        final groups = widget.prefs.progGroupOrder;
        return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        BrutalBox(
          tag: 'FOCUS GROUP',
          padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
          child: ReorderableGroupGrid(
            items: groups,
            childAspectRatio: 3.4,
            cellBuilder: (context, g) => _GroupBtn(
              label: g,
              active: _focus == g,
            ),
            onTap: (g) => setState(() => _focus = g),
            onReorder: (next) => widget.prefs.setProgGroupOrder(next),
          ),
        ),
        const SizedBox(height: 12),
        BrutalBox(
          tag: '$_focus · $scaleTag',
          padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT INDEX',
                          style: mono(
                            size: 9,
                            weight: FontWeight.w700,
                            letterSpacing: 1,
                            color: p.ink.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          '${data.last}',
                          style: mono(
                            size: 34,
                            weight: FontWeight.w800,
                            letterSpacing: -1,
                            color: p.ink,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        deltaTag,
                        style: mono(
                          size: 9,
                          weight: FontWeight.w700,
                          letterSpacing: 1,
                          color: p.ink.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.accent,
                          border: Border.all(color: p.ink, width: 2),
                        ),
                        child: Text(
                          '${delta >= 0 ? '+' : ''}$delta',
                          style: mono(
                            size: 16,
                            weight: FontWeight.w800,
                            color: p.accentInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Segmented(
                opts: _scaleOpts,
                value: _scale,
                onChange: (s) => setState(() => _scale = s),
                height: 28,
                fontSize: 10,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: CustomPaint(
                  painter: _ProgLinePainter(
                    data: data,
                    ink: p.ink,
                    paper: p.paper,
                    accent: p.accent,
                    scaleLabel: scaleTag,
                    weeks: weeks,
                  ),
                  size: const Size(double.infinity, 140),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'EXERCISE LOADS · $scaleTag',
                style: mono(
                  size: 9,
                  weight: FontWeight.w700,
                  letterSpacing: 1,
                  color: p.ink.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              _ExerciseProgList(
                items: exSeries,
                unit: widget.tweaks.unit,
                conv: _wConv,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BrutalBox(
          tag: 'ALL GROUPS',
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.only(top: 22),
            child: DragList<String>(
              scrollable: false,
              closedGap: 0,
              items: groups,
              getId: (g) => g,
              onReorder: (fromIdx, insertIdx) {
                final newIdx = insertIdx > fromIdx ? insertIdx - 1 : insertIdx;
                final list = List<String>.from(groups);
                final moved = list.removeAt(fromIdx);
                list.insert(newIdx, moved);
                widget.prefs.setProgGroupOrder(list);
              },
              itemBuilder: (context, i, g, handle) => _GroupRow(
                group: g,
                data: widget.history.progressionFor(g),
                focus: _focus == g,
                handle: handle,
                onTap: () => setState(() => _focus = g),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        BrutalBox(
          tag: 'RECENT SESSIONS',
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Column(
              children: [
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                      child: Text(
                        'NO SESSIONS LOGGED YET',
                        style: mono(
                          size: 10,
                          weight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: p.ink.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  )
                else
                  for (int i = 0; i < sessions.length; i++)
                    _SessionRow(
                      row: sessions[i],
                      first: i == 0,
                      volUnit: _volUnit(),
                      volConv: _volConv,
                    ),
              ],
            ),
          ),
        ),
      ],
        );
      },
    );
  }
}

class _GroupBtn extends StatelessWidget {
  final String label;
  final bool active;
  const _GroupBtn({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      transform: active
          ? (Matrix4.identity()..translate(-1.0, -1.0))
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: active ? p.accent : p.paper,
        border: Border.all(color: p.ink, width: 2),
        boxShadow: active
            ? [BoxShadow(color: p.ink, offset: const Offset(2, 2))]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: mono(
          size: 11,
          weight: FontWeight.w800,
          letterSpacing: 1,
          color: active ? p.accentInk : p.ink,
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final String group;
  final List<int> data;
  final bool focus;
  final DragHandleBuilder handle;
  final VoidCallback onTap;
  const _GroupRow({
    required this.group,
    required this.data,
    required this.focus,
    required this.handle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final delta = data.last - data.first;
    final bg = focus ? p.accent : p.paper;
    final fg = focus ? p.accentInk : p.ink;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: p.ink.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          handle(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Text(
                '⋮⋮',
                style: mono(
                  size: 13,
                  weight: FontWeight.w800,
                  letterSpacing: -1.5,
                  color: fg.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        group,
                        style: mono(size: 12, weight: FontWeight.w800, letterSpacing: 0.5, color: fg),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 24,
                        child: CustomPaint(
                          painter: _SparkLinePainter(
                            data: data,
                            color: fg,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 88,
                      child: Text(
                        '${data.first} → ${data.last}',
                        textAlign: TextAlign.right,
                        style: mono(
                          size: 11,
                          weight: FontWeight.w700,
                          color: fg.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${delta >= 0 ? '+' : ''}$delta',
                        textAlign: TextAlign.right,
                        style: mono(size: 11, weight: FontWeight.w800, color: fg),
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
  }
}

class _SessionRow extends StatelessWidget {
  final dynamic row;
  final bool first;
  final String volUnit;
  final String Function(double) volConv;
  const _SessionRow({
    required this.row,
    required this.first,
    required this.volUnit,
    required this.volConv,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final dateParts = (row.date as String).split(' ');
    final dateDay = dateParts.length > 1 ? dateParts[1] : row.date;
    return Container(
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(
                top: BorderSide(color: p.ink.withValues(alpha: 0.7), width: 1),
              ),
            ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: p.ink, width: 2)),
            child: Column(
              children: [
                Text(
                  row.day,
                  style: mono(size: 8, weight: FontWeight.w700, color: p.ink.withValues(alpha: 0.6)),
                ),
                Text(
                  dateDay,
                  style: mono(size: 10, weight: FontWeight.w800, color: p.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.name,
                        style: mono(size: 12, weight: FontWeight.w800, color: p.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (row.pr == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: p.accent,
                          border: Border.all(color: p.ink, width: 1.5),
                        ),
                        child: Text(
                          'PR',
                          style: mono(size: 9, weight: FontWeight.w800, color: p.accentInk),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.dur}m · ${row.sets} sets · ${volConv(row.vol)}$volUnit',
                  style: mono(size: 10, color: p.ink.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          Text(
            '→',
            style: mono(size: 16, weight: FontWeight.w800, color: p.ink.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}

class _ProgLinePainter extends CustomPainter {
  final List<int> data;
  final Color ink;
  final Color paper;
  final Color accent;
  final String scaleLabel;
  final int weeks;
  _ProgLinePainter({
    required this.data,
    required this.ink,
    required this.paper,
    required this.accent,
    required this.scaleLabel,
    required this.weeks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const yLabelW = 28.0;
    const xLabelH = 22.0;
    final chartX = yLabelW;
    final chartW = size.width - chartX;
    final h = size.height - xLabelH;
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = (max - min) == 0 ? 1 : (max - min);

    final gridPaint = Paint()
      ..color = ink.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;
    const levels = [0.0, 0.25, 0.5, 0.75, 1.0];
    for (final f in levels) {
      final y = h * f;
      _drawDashedLine(canvas, Offset(chartX, y), Offset(size.width, y), gridPaint, 2, 3);
      final value = (max - range * f).round();
      const textH = 10.0;
      final ty = (y - textH / 2).clamp(0.0, h - textH);
      _drawText(
        canvas,
        value.toString(),
        Offset(chartX - 4, ty),
        ink.withValues(alpha: 0.5),
        Alignment.topRight,
        size: 8,
      );
    }

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = chartX + (i / (data.length - 1)) * chartW;
      final y = h - ((data[i] - min) / range) * h;
      points.add(Offset(x, y));
    }

    final areaPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final pt in points.skip(1)) {
      areaPath.lineTo(pt.dx, pt.dy);
    }
    areaPath.lineTo(size.width, h);
    areaPath.lineTo(chartX, h);
    areaPath.close();
    canvas.drawPath(areaPath, Paint()..color = accent.withValues(alpha: 0.4));

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final pt in points.skip(1)) {
      linePath.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.miter,
    );

    final step = (data.length / 20).ceil().clamp(1, data.length);
    for (int i = 0; i < points.length; i++) {
      if (data.length <= 26 || i % step == 0) {
        final r = Rect.fromCenter(center: points[i], width: 4, height: 4);
        canvas.drawRect(r, Paint()..color = paper);
        canvas.drawRect(
          r,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }

    final last = points.last;
    canvas.drawRect(
      Rect.fromCenter(center: last, width: 8, height: 8),
      Paint()..color = accent,
    );
    canvas.drawRect(
      Rect.fromCenter(center: last, width: 8, height: 8),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawLine(
      Offset(chartX, h),
      Offset(size.width, h),
      Paint()
        ..color = ink
        ..strokeWidth = 1.5,
    );

    final xLabels = <String>[
      '${weeks}W AGO',
      '${(weeks * 0.75).round()}W',
      '${(weeks * 0.5).round()}W',
      '${(weeks * 0.25).round()}W',
      'NOW',
    ];
    for (int i = 0; i < xLabels.length; i++) {
      final f = i / (xLabels.length - 1);
      final x = chartX + chartW * f;
      final align = i == 0
          ? Alignment.topLeft
          : i == xLabels.length - 1
              ? Alignment.topRight
              : Alignment.topCenter;
      _drawText(
        canvas,
        xLabels[i],
        Offset(x, h + 8),
        ink.withValues(alpha: 0.5),
        align,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint, double dash, double gap) {
    final total = (to - from).distance;
    final dir = (to - from) / total;
    double d = 0;
    while (d < total) {
      final end = (d + dash).clamp(0, total);
      canvas.drawLine(from + dir * d, from + dir * end.toDouble(), paint);
      d += dash + gap;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    Alignment align, {
    double size = 9,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: mono(size: size, color: color)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    double dx = at.dx;
    if (align == Alignment.topRight) dx -= tp.width;
    if (align == Alignment.topCenter) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_ProgLinePainter old) =>
      old.data != data ||
      old.ink != ink ||
      old.accent != accent ||
      old.scaleLabel != scaleLabel ||
      old.weeks != weeks;
}

class _SparkLinePainter extends CustomPainter {
  final List<int> data;
  final Color color;
  _SparkLinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = (max - min) == 0 ? 1 : (max - min);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - min) / range) * (size.height - 2) - 1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SparkLinePainter old) => old.data != data || old.color != color;
}

class _ExerciseProgList extends StatefulWidget {
  final List<ExerciseSeries> items;
  final String unit;
  final double Function(double) conv;
  const _ExerciseProgList({
    required this.items,
    required this.unit,
    required this.conv,
  });

  static const double _rowH = 32;
  static const int _visibleRows = 5;

  @override
  State<_ExerciseProgList> createState() => _ExerciseProgListState();
}

class _ExerciseProgListState extends State<_ExerciseProgList> {
  final ScrollController _scroll = ScrollController();
  double _tailOpacity = 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final next = max <= 0 ? 1.0 : (1 - (_scroll.offset / max)).clamp(0.0, 1.0);
    if ((next - _tailOpacity).abs() > 0.01) {
      setState(() => _tailOpacity = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final items = widget.items;

    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashedLine(color: p.ink.withValues(alpha: 0.4)),
          SizedBox(
            height: _ExerciseProgList._rowH,
            child: Center(
              child: Text(
                'NO EXERCISES IN WINDOW',
                style: mono(
                  size: 9,
                  weight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: p.ink.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final hasOverflow = items.length > _ExerciseProgList._visibleRows;
    final shown = items.length < _ExerciseProgList._visibleRows
        ? items.length
        : _ExerciseProgList._visibleRows;
    final listH = shown * _ExerciseProgList._rowH;
    final fade = hasOverflow ? _tailOpacity : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashedLine(color: p.ink.withValues(alpha: 0.4)),
        SizedBox(
          height: listH,
          child: ListView.builder(
            controller: _scroll,
            physics: hasOverflow
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemExtent: _ExerciseProgList._rowH,
            itemCount: items.length,
            itemBuilder: (ctx, i) => _ExerciseProgRow(
              item: items[i],
              unit: widget.unit,
              conv: widget.conv,
              first: i == 0,
            ),
          ),
        ),
        if (hasOverflow) ...[
          DashedLine(color: p.ink.withValues(alpha: 0.4 * fade)),
          Container(
            height: 14,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  p.accent.withValues(alpha: 0.7 * fade),
                  p.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExerciseProgRow extends StatelessWidget {
  final ExerciseSeries item;
  final String unit;
  final double Function(double) conv;
  final bool first;
  const _ExerciseProgRow({
    required this.item,
    required this.unit,
    required this.conv,
    required this.first,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final series = item.series;
    final curr = series.last;
    double prev = 0;
    for (final v in series) {
      if (v > 0) {
        prev = v;
        break;
      }
    }
    final delta = curr - prev;
    final chipLabel = prev == 0 || prev == curr
        ? '—'
        : '${delta >= 0 ? '+' : ''}${conv(delta).toStringAsFixed(0)}';
    final chipColor = delta > 0
        ? p.accent
        : (delta < 0 ? p.ink : p.paper);
    final chipInk = delta > 0
        ? p.accentInk
        : (delta < 0 ? p.paper : p.ink.withValues(alpha: 0.6));
    final sparkData = series.map((v) => v.round()).toList();

    return Column(
      children: [
        if (!first) DashedLine(color: p.ink.withValues(alpha: 0.25)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 98,
                  child: Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: mono(
                      size: 11,
                      weight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: p.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 22,
                    child: CustomPaint(
                      painter: _SparkLinePainter(
                        data: sparkData,
                        color: p.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${conv(curr).toStringAsFixed(0)} ${unit.toUpperCase()}',
                  style: mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: p.ink.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: chipColor,
                    border: Border.all(color: p.ink, width: 1.5),
                  ),
                  child: Text(
                    chipLabel,
                    style: mono(
                      size: 9,
                      weight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: chipInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

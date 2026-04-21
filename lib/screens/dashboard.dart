import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../history.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/primitives.dart';
import '../widgets/radar_chart.dart';

class DashboardScreen extends StatefulWidget {
  final Tweaks tweaks;
  final History history;
  final void Function(Template) onStart;
  final ValueChanged<String> onTab;

  const DashboardScreen({
    super.key,
    required this.tweaks,
    required this.history,
    required this.onStart,
    required this.onTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final PageController _pageController = PageController();
  int _page = 0;
  String _pageKey = 'ALL';
  double _morph = 1;
  String _groupScale = '12W';

  @override
  void initState() {
    super.initState();
    widget.tweaks.addListener(_morphReset);
    widget.history.addListener(_onHistory);
  }

  void _morphReset() {
    setState(() => _morph = 0);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _morph = 1);
    });
  }

  void _onHistory() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.tweaks.removeListener(_morphReset);
    widget.history.removeListener(_onHistory);
    _pageController.dispose();
    super.dispose();
  }

  double _conv(double lbs) => widget.tweaks.unit == 'kg' ? (lbs * 0.4536).roundToDouble() : lbs;
  String _volUnit() => widget.tweaks.unit == 'kg' ? 't' : 'k';
  String _volConv(double v) => widget.tweaks.unit == 'kg'
      ? (v * 0.4536).toStringAsFixed(1)
      : v.toStringAsFixed(1);
  String _monthAbbrev() {
    const m = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
               'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return m[DateTime.now().month - 1];
  }

  /// Move [fromKey] into [toKey]'s slot in the tracked-group order, then
  /// splice back into [Tweaks.groupOrder] (untracked groups stay in place).
  /// ALL is pinned to index 0 via `lockedKeys`, so both keys are always group
  /// names here.
  void _onReorderPills(String fromKey, String toKey) {
    final tracked = List<String>.from(widget.tweaks.radarGroups);
    final from = tracked.indexOf(fromKey);
    final to = tracked.indexOf(toKey);
    if (from < 0 || to < 0 || from == to) return;
    tracked.removeAt(from);
    tracked.insert(to, fromKey);

    final groupOrder = List<String>.from(widget.tweaks.groupOrder);
    final trackedPositions = <int>[
      for (int i = 0; i < groupOrder.length; i++)
        if (widget.tweaks.isTracked(groupOrder[i])) i,
    ];
    for (int k = 0; k < trackedPositions.length && k < tracked.length; k++) {
      groupOrder[trackedPositions[k]] = tracked[k];
    }
    widget.tweaks.setGroupOrder(groupOrder);

    // Keep the visible page stable by jumping the controller synchronously;
    // the subsequent rebuild (driven by tweaks notifying) then finds the
    // current page at its new index with no flash of a swapped item.
    final pillKeys = ['ALL', ...tracked];
    final newIdx = pillKeys.indexOf(_pageKey);
    if (newIdx >= 0 && newIdx != _page) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(newIdx);
      }
      setState(() => _page = newIdx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final activeRadar = widget.history.groupStats(widget.tweaks.radarGroups);
    final pages = <Map<String, dynamic>>[
      {'type': 'radar'},
      ...activeRadar.map((g) => {'type': 'group', 'g': g}),
    ];
    final pillKeys = [
      'ALL',
      for (final g in activeRadar) g.group,
    ];
    final pillLabels = <String, String>{
      'ALL': 'ALL',
      for (final g in activeRadar) g.group: g.label,
    };
    // Clamp _page/_pageKey in case the tracked-groups set changed.
    if (_page >= pages.length) _page = pages.length - 1;
    if (_page < 0) _page = 0;
    if (!pillKeys.contains(_pageKey)) _pageKey = pillKeys[_page];

    final volume = widget.history.weeklyVolume();
    final totalVol = volume.fold<double>(0, (a, b) => a + b);
    final thisWeek = volume.last;
    final lastWeek = volume[volume.length - 2];
    final weekDeltaStr = lastWeek == 0
        ? (thisWeek > 0 ? 'NEW' : '0.0%')
        : '${((thisWeek - lastWeek) / lastWeek * 100).toStringAsFixed(1)}%';
    // Split total over 12W into first-half vs second-half to score trend.
    final firstHalf = volume.take(volume.length ~/ 2).fold<double>(0, (a, b) => a + b);
    final secondHalf = volume.skip(volume.length ~/ 2).fold<double>(0, (a, b) => a + b);
    final trendStr = firstHalf == 0
        ? (secondHalf > 0 ? 'NEW' : '0.0%')
        : '${((secondHalf - firstHalf) / firstHalf * 100).toStringAsFixed(1)}%';

    final prs = widget.history.prs();
    final prsThisMonth = widget.history.prsThisMonth();
    final streak = widget.history.streakDays;
    final prevStreak = widget.history.longestPreviousStreak;

    final volUnit = _volUnit();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'STREAK',
                value: '$streak',
                unit: streak > 1 ? 'DAYS' : 'DAY',
                delta: prevStreak > 0 ? 'BEST ${prevStreak}D' : '—',
                deltaColor: p.ink.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'WK VOL',
                value: _volConv(thisWeek),
                unit: volUnit,
                delta: weekDeltaStr,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'PRs',
                value: '$prsThisMonth',
                unit: _monthAbbrev(),
                delta: prsThisMonth > 0 ? '↑ NEW' : '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BrutalBox(
          tag: pages[_page]['type'] == 'radar'
              ? 'MUSCLE PROFILE'
              : 'DETAIL · ${(pages[_page]['g'] as GroupStat).group}',
          child: Column(
            children: [
              const SizedBox(height: 22),
              _PageBarDraggable(
                keys: pillKeys,
                labels: pillLabels,
                activeKey: _pageKey,
                lockedKeys: const {'ALL'},
                onSelect: (k) {
                  final i = pillKeys.indexOf(k);
                  if (i < 0) return;
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                },
                onReorder: _onReorderPills,
              ),
              SizedBox(
                height: 400,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() {
                    _page = i;
                    _pageKey = pillKeys[i];
                  }),
                  itemBuilder: (context, i) {
                    final page = pages[i];
                    if (page['type'] == 'radar') {
                      return _RadarPage(
                        data: activeRadar,
                        styleMode: widget.tweaks.radarStyle,
                        animate: _morph,
                      );
                    }
                    return _GroupPage(
                      g: page['g'] as GroupStat,
                      history: widget.history,
                      allStats: activeRadar,
                      scale: _groupScale,
                      onScale: (s) => setState(() => _groupScale = s),
                      unit: widget.tweaks.unit,
                      conv: _conv,
                    );
                  },
                ),
              ),
              DashedLine(color: p.ink),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < pages.length; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _page == i ? 14 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _page == i ? p.ink : Colors.transparent,
                          border: Border.all(color: p.ink, width: 1.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BrutalBox(
          tag: 'WK VOLUME · 12W',
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL ${_volConv(totalVol)}${volUnit.toUpperCase()}',
                    style: mono(size: 11, weight: FontWeight.w700, color: p.ink),
                  ),
                  Text(
                    '▲ $trendStr',
                    style: mono(size: 11, weight: FontWeight.w700, color: p.accentOnPaper),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 74,
                child: _VolumeBars(data: volume),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('W−11', style: mono(size: 9, color: p.ink.withValues(alpha: 0.5))),
                  Text('W0', style: mono(size: 9, color: p.ink.withValues(alpha: 0.5))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BrutalBox(
          tag: 'RECENT PRs',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
            child: prs.isEmpty
                ? _EmptyHint(text: 'FINISH A WORKOUT TO LOG PRs')
                : Column(
                    children: [
                      for (int i = 0; i < prs.length; i++)
                        _PrRowWidget(
                          pr: prs[i],
                          first: i == 0,
                          unit: widget.tweaks.unit,
                          conv: _conv,
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        BrutalButton(
          label: widget.history.lastSessionName() != null
              ? '▶ START NEXT SESSION'
              : '▶ START YOUR FIRST SESSION',
          onPressed: () => widget.onTab('tpl'),
        ),
      ],
    );
  }
}

/// Horizontal pill strip for the dashboard muscle-profile pages. Tap selects,
/// drag reorders with the same lift/drop chrome as the exercise picker tab
/// bar and templates filter bar. Variable-width pills measured via
/// [TextPainter] so Stack layout is deterministic.
class _PageBarDraggable extends StatefulWidget {
  final List<String> keys;
  final Map<String, String> labels;
  final String activeKey;
  /// Keys that can't be drag-sourced or drop-targeted. Locked pills still
  /// receive taps and animate with the rest of the row.
  final Set<String> lockedKeys;
  final ValueChanged<String> onSelect;
  final void Function(String fromKey, String toKey) onReorder;
  const _PageBarDraggable({
    required this.keys,
    required this.labels,
    required this.activeKey,
    required this.onSelect,
    required this.onReorder,
    this.lockedKeys = const {},
  });

  @override
  State<_PageBarDraggable> createState() => _PageBarDraggableState();
}

class _PageBarDraggableState extends State<_PageBarDraggable>
    with SingleTickerProviderStateMixin {
  String? _dragKey;
  String? _hoverKey;
  final Map<String, GlobalKey> _gKeys = {};
  final ScrollController _scroll = ScrollController();

  final Map<String, double> _widths = {};
  double _pillH = 22;

  Offset? _ghostTopLeft;
  Size? _ghostSize;
  Offset _pointerLocal = Offset.zero;
  OverlayEntry? _overlay;
  BrutalPalette? _palette;

  AnimationController? _dropCtrl;
  Offset? _dropFrom;
  Offset? _dropTo;
  bool _accentOn = false;

  static const double _gap = 4;
  // Pill chrome (padding + border) around the text.
  static const double _chromeW = 20; // 8*2 padding + 2*2 border
  static const double _chromeH = 12; // 4*2 padding + 2*2 border

  @override
  void initState() {
    super.initState();
    _measurePills();
  }

  @override
  void didUpdateWidget(covariant _PageBarDraggable old) {
    super.didUpdateWidget(old);
    _measurePills();
  }

  void _measurePills() {
    const style = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
    );
    double maxH = 0;
    for (final k in widget.keys) {
      final label = widget.labels[k] ?? k;
      final sig = '$k::$label';
      if (_widths.containsKey(sig)) {
        final h = _pillH;
        if (h > maxH) maxH = h;
        continue;
      }
      final tp = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      _widths[sig] = tp.width + _chromeW;
      final h = tp.height + _chromeH;
      if (h > maxH) maxH = h;
    }
    if (maxH > 0) _pillH = maxH;
  }

  double _widthFor(String k) {
    final label = widget.labels[k] ?? k;
    return _widths['$k::$label'] ?? 40;
  }

  GlobalKey _keyFor(String k) => _gKeys.putIfAbsent(k, () => GlobalKey());

  @override
  void dispose() {
    _scroll.dispose();
    _overlay?.remove();
    _overlay = null;
    _dropCtrl?.dispose();
    super.dispose();
  }

  Drag? _onDragStart(String k, Offset globalPos) {
    if (widget.lockedKeys.contains(k)) return null;
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

    _palette = BrutalColors.of(context);
    setState(() {
      _dragKey = k;
      _hoverKey = k;
      _ghostTopLeft = topLeft;
      _ghostSize = size;
      _pointerLocal = globalPos - topLeft;
      _accentOn = true;
    });
    _showOverlay();
    HapticFeedback.selectionClick();
    return _PillDrag(
      onUpdate: (d) => _onPointerMove(d.globalPosition),
      onEnd: (_) => _endDrag(commit: true),
      onCancel: () => _endDrag(commit: false),
    );
  }

  void _onPointerMove(Offset globalPos) {
    _ghostTopLeft = globalPos - _pointerLocal;
    String? nextHover;
    for (final k in widget.keys) {
      if (k == _dragKey) continue;
      if (widget.lockedKeys.contains(k)) continue;
      final ctx = _gKeys[k]?.currentContext;
      if (ctx == null) continue;
      final rb = ctx.findRenderObject();
      if (rb is! RenderBox || !rb.attached) continue;
      final pos = rb.localToGlobal(Offset.zero);
      final rect = pos & rb.size;
      if (rect.contains(globalPos)) {
        nextHover = k;
        break;
      }
    }
    if (nextHover != null && nextHover != _hoverKey) {
      setState(() => _hoverKey = nextHover);
    }
    _overlay?.markNeedsBuild();
  }

  void _endDrag({required bool commit}) {
    final from = _dragKey;
    final to = _hoverKey;
    final shouldCommit =
        commit && from != null && to != null && from != to;
    setState(() {
      _hoverKey = null;
      _accentOn = false;
    });
    if (shouldCommit) {
      widget.onReorder(from, to);
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
    setState(() {
      _dragKey = null;
      _hoverKey = null;
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
    final k = _dragKey;
    if (top == null || size == null || palette == null || k == null) {
      return const SizedBox.shrink();
    }
    final dropT = _dropCtrl?.value ?? 0.0;
    final kk = 1.0 - dropT;
    return Positioned(
      left: top.dx,
      top: top.dy,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -0.026 * kk,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: 1.0 + 0.02 * kk,
            alignment: Alignment.center,
            child: Opacity(
              opacity: 0.95 + 0.05 * dropT,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: palette.ink,
                      offset: Offset(4 * kk, 4 * kk),
                    ),
                    BoxShadow(
                      color: palette.accent,
                      spreadRadius: 2 * kk,
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: _PagePillContent(
                    label: widget.labels[k] ?? k,
                    active: widget.activeKey == k,
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

  List<String> _displayedKeys() {
    if (_dragKey == null || _hoverKey == null || _dragKey == _hoverKey) {
      return widget.keys;
    }
    final list = List<String>.from(widget.keys);
    final from = list.indexOf(_dragKey!);
    final to = list.indexOf(_hoverKey!);
    if (from < 0 || to < 0) return widget.keys;
    list.removeAt(from);
    list.insert(to, _dragKey!);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final palette = BrutalColors.of(context);
    final displayed = _displayedKeys();

    final xByKey = <String, double>{};
    double x = 0;
    for (final k in displayed) {
      xByKey[k] = x;
      x += _widthFor(k) + _gap;
    }
    final totalW = x <= 0 ? 0.0 : x - _gap;

    return SizedBox(
      height: _pillH + 8,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        physics: _dragKey != null
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        child: SizedBox(
          width: totalW,
          height: _pillH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final k in widget.keys)
                AnimatedPositioned(
                  key: ValueKey('pos-$k'),
                  duration: _dragKey == k
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: xByKey[k] ?? 0,
                  top: 0,
                  width: _widthFor(k),
                  height: _pillH,
                  child: KeyedSubtree(
                    key: _keyFor(k),
                    child: _PagePill(
                      label: widget.labels[k] ?? k,
                      active: widget.activeKey == k,
                      dragging: _dragKey == k,
                      showAccent: _dragKey == k && _accentOn,
                      onTap: () => widget.onSelect(k),
                      onDragStart: (pos) => _onDragStart(k, pos),
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

/// Static pill visual — used as the ghost's content during drag.
class _PagePillContent extends StatelessWidget {
  final String label;
  final bool active;
  final BrutalPalette palette;
  const _PagePillContent({
    required this.label,
    required this.active,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? palette.ink : palette.paper,
        border: Border.all(color: palette.ink, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: mono(
          size: 9,
          weight: FontWeight.w800,
          letterSpacing: 1,
          color: active ? palette.paper : palette.ink,
        ),
      ),
    );
  }
}

class _PagePill extends StatelessWidget {
  final String label;
  final bool active;
  final bool dragging;
  final bool showAccent;
  final VoidCallback onTap;
  final Drag? Function(Offset globalPosition) onDragStart;
  final BrutalPalette palette;
  const _PagePill({
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
    final visual = Stack(
      children: [
        Visibility(
          visible: !dragging,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: _PagePillContent(
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

class _PillDrag extends Drag {
  final void Function(DragUpdateDetails) onUpdate;
  final void Function(DragEndDetails) onEnd;
  final VoidCallback onCancel;
  _PillDrag({
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

class _RadarPage extends StatelessWidget {
  final List<GroupStat> data;
  final String styleMode;
  final double animate;
  const _RadarPage({required this.data, required this.styleMode, required this.animate});

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    if (data.length < 3) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: p.ink, width: 2, style: BorderStyle.solid),
          ),
          alignment: Alignment.center,
          child: Text(
            'SELECT 3+ GROUPS IN TWEAKS',
            style: mono(
              size: 11,
              weight: FontWeight.w700,
              letterSpacing: 1,
              color: p.ink.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }
    final avg = (data.map((e) => e.value).reduce((a, b) => a + b) / data.length).round();
    final prevAvg = (data.map((e) => e.prev).reduce((a, b) => a + b) / data.length).round();
    final overallDelta = avg - prevAvg;
    final sorted = [...data]..sort((a, b) => b.value.compareTo(a.value));
    final strongest = sorted.first;
    final weakest = sorted.last;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
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
                      'OVERALL INDEX',
                      style: mono(
                        size: 10,
                        weight: FontWeight.w700,
                        letterSpacing: 1,
                        color: p.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$avg',
                          style: mono(
                            size: 38,
                            weight: FontWeight.w800,
                            letterSpacing: -1,
                            color: p.ink,
                            height: 1,
                          ),
                        ),
                        Text(
                          '/100',
                          style: mono(
                            size: 14,
                            weight: FontWeight.w600,
                            color: p.ink.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${overallDelta >= 0 ? '▲ +' : '▼ '}$overallDelta vs 4W AGO',
                      style: mono(size: 10, weight: FontWeight.w700, color: p.accentOnPaper),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'STRONGEST',
                    style: mono(
                      size: 9,
                      weight: FontWeight.w700,
                      letterSpacing: 1,
                      color: p.ink.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${strongest.group} · ${strongest.value}',
                    style: mono(size: 13, weight: FontWeight.w800, color: p.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'WEAKEST',
                    style: mono(
                      size: 9,
                      weight: FontWeight.w700,
                      letterSpacing: 1,
                      color: p.ink.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${weakest.group} · ${weakest.value}',
                    style: mono(size: 13, weight: FontWeight.w800, color: p.ink),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: LayoutBuilder(
              builder: (context, c) {
                final side = c.maxWidth.clamp(240.0, 290.0);
                return RadarChartWidget(
                  data: data,
                  size: side,
                  styleMode: styleMode,
                  accent: p.accent,
                  ink: p.ink,
                  paper: p.paper,
                  animate: animate,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupPage extends StatelessWidget {
  final GroupStat g;
  final History history;
  final List<GroupStat> allStats;
  final String scale;
  final ValueChanged<String> onScale;
  final String unit;
  final double Function(double) conv;
  const _GroupPage({
    required this.g,
    required this.history,
    required this.allStats,
    required this.scale,
    required this.onScale,
    required this.unit,
    required this.conv,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final weeks = {'4W': 4, '12W': 12, '26W': 26, '52W': 52}[scale] ?? 12;
    final full = history.progressionFor(g.group);
    final data = full.sublist(full.length - weeks);
    final delta = data.last - data.first;
    final improvements = history.mostImprovedInGroup(g.group);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
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
                      '${g.group} INDEX',
                      style: mono(
                        size: 10,
                        weight: FontWeight.w700,
                        letterSpacing: 1,
                        color: p.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${data.last}',
                          style: mono(
                            size: 38,
                            weight: FontWeight.w800,
                            letterSpacing: -1,
                            color: p.ink,
                            height: 1,
                          ),
                        ),
                        Text(
                          '/100',
                          style: mono(
                            size: 14,
                            weight: FontWeight.w600,
                            color: p.ink.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.accent,
                        border: Border.all(color: p.ink, width: 1.5),
                      ),
                      child: Text(
                        '${delta >= 0 ? '+' : ''}$delta / $scale',
                        style: mono(size: 10, weight: FontWeight.w700, color: p.accentInk),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statBadge(
                    context,
                    'RANK',
                    '${allStats.where((x) => x.value > g.value).length + 1}/${allStats.length}',
                  ),
                  const SizedBox(height: 4),
                  _statBadge(context, 'MAX', '${full.reduce((a, b) => a > b ? a : b)}'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Segmented(
            opts: const ['4W', '12W', '26W', '52W'],
            value: scale,
            onChange: onScale,
            height: 28,
            fontSize: 10,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _GroupLineChartPainter(
                data: data,
                ink: p.ink,
                paper: p.paper,
                accent: p.accent,
                scaleLabel: scale,
              ),
              size: const Size(double.infinity, 120),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _MostImprovedList(
              items: improvements,
              unit: unit,
              conv: conv,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(BuildContext context, String k, String v) {
    final p = BrutalColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: p.ink, width: 1.5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            k,
            style: mono(
              size: 9,
              weight: FontWeight.w700,
              color: p.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 10),
          Text(v, style: mono(size: 11, weight: FontWeight.w800, color: p.ink)),
        ],
      ),
    );
  }
}

/// Vertically scrollable list of the most-improved exercises for a muscle
/// group. Clamps viewport to exactly [_visibleRows] so only 3 items show at
/// once; when more rows exist, a dashed line + accent gradient hangs under the
/// viewport and fades out in lockstep with scroll progress so it vanishes once
/// the user reaches the bottom.
class _MostImprovedList extends StatefulWidget {
  final List<ExerciseImprovement> items;
  final String unit;
  final double Function(double) conv;
  const _MostImprovedList({
    required this.items,
    required this.unit,
    required this.conv,
  });

  static const double _rowH = 28;
  static const int _visibleRows = 3;

  @override
  State<_MostImprovedList> createState() => _MostImprovedListState();
}

class _MostImprovedListState extends State<_MostImprovedList> {
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
    final labelStyle = mono(
      size: 10,
      weight: FontWeight.w700,
      letterSpacing: 1,
      color: p.ink.withValues(alpha: 0.6),
    );

    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('MOST IMPROVED', style: labelStyle),
          const SizedBox(height: 4),
          DashedLine(color: p.ink.withValues(alpha: 0.4)),
          const Expanded(
            child: Center(
              child: _InlineHint('NO IMPROVEMENTS IN 8W'),
            ),
          ),
        ],
      );
    }

    final hasOverflow = items.length > _MostImprovedList._visibleRows;
    final shown = items.length < _MostImprovedList._visibleRows
        ? items.length
        : _MostImprovedList._visibleRows;
    final listH = shown * _MostImprovedList._rowH;
    final fade = hasOverflow ? _tailOpacity : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MOST IMPROVED', style: labelStyle),
        const SizedBox(height: 4),
        DashedLine(color: p.ink.withValues(alpha: 0.4)),
        SizedBox(
          height: listH,
          child: ListView.builder(
            controller: _scroll,
            physics: hasOverflow
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemExtent: _MostImprovedList._rowH,
            itemCount: items.length,
            itemBuilder: (ctx, i) => _ImprovementRow(
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

class _ImprovementRow extends StatelessWidget {
  final ExerciseImprovement item;
  final String unit;
  final double Function(double) conv;
  final bool first;
  const _ImprovementRow({
    required this.item,
    required this.unit,
    required this.conv,
    required this.first,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final delta = item.curr - item.prev;
    final chipLabel = item.isNew
        ? 'NEW'
        : '+${conv(delta).toStringAsFixed(0)}';

    return Column(
      children: [
        if (!first) DashedLine(color: p.ink.withValues(alpha: 0.25)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.exerciseName,
                    overflow: TextOverflow.ellipsis,
                    style: mono(
                      size: 11,
                      weight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: p.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${conv(item.curr).toStringAsFixed(0)} ${unit.toUpperCase()}',
                  style: mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: p.ink.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: p.accent,
                    border: Border.all(color: p.ink, width: 1.5),
                  ),
                  child: Text(
                    chipLabel,
                    style: mono(
                      size: 9,
                      weight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: p.accentInk,
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

class _InlineHint extends StatelessWidget {
  final String text;
  const _InlineHint(this.text);

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Text(
      text,
      style: mono(
        size: 9,
        weight: FontWeight.w700,
        letterSpacing: 1.5,
        color: p.ink.withValues(alpha: 0.45),
      ),
    );
  }
}

class _GroupLineChartPainter extends CustomPainter {
  final List<int> data;
  final Color ink;
  final Color paper;
  final Color accent;
  final String scaleLabel;

  _GroupLineChartPainter({
    required this.data,
    required this.ink,
    required this.paper,
    required this.accent,
    required this.scaleLabel,
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

    // horizontal grid + y-axis labels
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

    // area
    final areaPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(size.width, h);
    areaPath.lineTo(chartX, h);
    areaPath.close();
    canvas.drawPath(areaPath, Paint()..color = accent.withValues(alpha: 0.4));

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.miter,
    );

    // points
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
    // last point emphasized
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

    // x axis baseline
    canvas.drawLine(
      Offset(chartX, h),
      Offset(size.width, h),
      Paint()
        ..color = ink
        ..strokeWidth = 1.5,
    );

    final weeks = {'4W': 4, '12W': 12, '26W': 26, '52W': 52}[scaleLabel] ?? 4;
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
  bool shouldRepaint(_GroupLineChartPainter old) =>
      old.data != data || old.ink != ink || old.accent != accent || old.scaleLabel != scaleLabel;
}

class _VolumeBars extends StatelessWidget {
  final List<double> data;
  const _VolumeBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final rawMax = data.fold<double>(0, (a, b) => b > a ? b : a);
    final max = rawMax == 0 ? 1.0 : rawMax;
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 4.0;
        const labelHeadroom = 12.0;
        final barWidth = (c.maxWidth - gap * (data.length - 1)) / data.length;
        final barZoneH = (c.maxHeight - 4 - labelHeadroom).clamp(0.0, double.infinity);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.ink, width: 1.5)),
                ),
              ),
            ),
            for (int i = 0; i < data.length; i++)
              Positioned(
                left: i * (barWidth + gap),
                bottom: 2,
                width: barWidth,
                height: (data[i] / max) * barZoneH,
                child: Container(
                  decoration: BoxDecoration(
                    color: i == data.length - 1 ? p.accent : p.ink,
                    border: Border.all(color: p.ink, width: 1.5),
                  ),
                ),
              ),
            if (data.isNotEmpty)
              Positioned(
                left: (data.length - 1) * (barWidth + gap),
                top: 0,
                width: barWidth,
                child: Center(
                  child: Text(
                    'NOW',
                    style: mono(size: 8, weight: FontWeight.w800, color: p.ink),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PrRowWidget extends StatelessWidget {
  final PrRow pr;
  final bool first;
  final String unit;
  final double Function(double) conv;
  const _PrRowWidget({
    required this.pr,
    required this.first,
    required this.unit,
    required this.conv,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first) DashedLine(color: p.ink),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pr.lift, style: mono(size: 12, weight: FontWeight.w800, color: p.ink)),
                const SizedBox(height: 1),
                Text(
                  '${pr.reps} REPS · ${pr.date}',
                  style: mono(size: 9, color: p.ink.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    conv(pr.prev).toStringAsFixed(0),
                    style: mono(size: 10, color: p.ink.withValues(alpha: 0.5)).copyWith(
                      decoration: TextDecoration.lineThrough,
                      decorationColor: p.ink.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    conv(pr.w).toStringAsFixed(0),
                    style: mono(size: 18, weight: FontWeight.w800, letterSpacing: -0.5, color: p.ink),
                  ),
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit.toUpperCase(),
                      style: mono(size: 9, color: p.ink.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
              if (pr.reps > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '≈ ${conv(pr.w * (1 + pr.reps / 30)).toStringAsFixed(0)} ${unit.toUpperCase()} · 1RM',
                    style: mono(
                      size: 9,
                      weight: FontWeight.w700,
                      color: p.ink.withValues(alpha: 0.55),
                    ),
                  ),
                ),
            ],
          ),
        ],
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          text,
          style: mono(
            size: 10,
            weight: FontWeight.w700,
            letterSpacing: 1.5,
            color: p.ink.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

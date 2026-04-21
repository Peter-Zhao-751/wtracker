import 'package:flutter/material.dart';
import '../core/data.dart';
import '../core/theme.dart';
import '../services/state.dart';
import '../widgets/group_grid.dart';
import '../widgets/primitives.dart';

class TweaksPanel extends StatelessWidget {
  final Tweaks tweaks;
  final VoidCallback onClose;
  const TweaksPanel({super.key, required this.tweaks, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          child: Container(color: Colors.black.withValues(alpha: 0.55)),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            decoration: BoxDecoration(
              color: p.paper,
              border: Border(top: BorderSide(color: p.ink, width: 3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: p.ink,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TWEAKS',
                          style: mono(
                            size: 16,
                            weight: FontWeight.w800,
                            letterSpacing: 2,
                            color: p.paper,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            border: Border.all(color: p.paper, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '✕',
                            style: mono(size: 14, weight: FontWeight.w800, color: p.paper),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListenableBuilder(
                    listenable: tweaks,
                    builder: (context, _) => ListView(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        14,
                        14,
                        20 + MediaQuery.of(context).padding.bottom,
                      ),
                      shrinkWrap: true,
                      children: [
                        _section('THEME'),
                        Segmented(
                          opts: const ['LIGHT', 'DARK'],
                          value: tweaks.theme.toUpperCase(),
                          onChange: (v) => tweaks.setTheme(v.toLowerCase()),
                        ),
                        const SizedBox(height: 16),
                        _section('ACCENT'),
                        Row(
                          children: [
                            for (int i = 0; i < kAccents.length; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: _AccentBtn(
                                  accent: kAccents[i],
                                  active: tweaks.accent.name == kAccents[i].name,
                                  onTap: () => tweaks.setAccent(kAccents[i]),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        _section('UNIT'),
                        Segmented(
                          opts: const ['LBS', 'KG'],
                          value: tweaks.unit.toUpperCase(),
                          onChange: (v) => tweaks.setUnit(v.toLowerCase()),
                        ),
                        const SizedBox(height: 16),
                        _section('RADAR STYLE'),
                        Segmented(
                          opts: const ['FILLED', 'OUTLINE', 'GRADIENT'],
                          value: tweaks.radarStyle.toUpperCase(),
                          onChange: (v) => tweaks.setRadarStyle(v.toLowerCase()),
                        ),
                        const SizedBox(height: 16),
                        _sectionWithRight(
                          'TRACKED GROUPS',
                          '${tweaks.radarGroups.length}/${kGroupNames.length}',
                        ),
                        ReorderableGroupGrid(
                          items: tweaks.groupOrder,
                          childAspectRatio: 3.6,
                          cellBuilder: (context, g) => _GroupToggle(
                            group: g,
                            on: tweaks.isTracked(g),
                          ),
                          onTap: (g) => tweaks.toggleGroup(g),
                          onReorder: (next) => tweaks.setGroupOrder(next),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'DRAG TO REORDER · TAP TO TOGGLE · MIN 3 FOR RADAR',
                          style: mono(
                            size: 9,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5) ??
                                Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _section('DENSITY'),
                        Segmented(
                          opts: const ['COMPACT', 'SPACIOUS'],
                          value: tweaks.density.toUpperCase(),
                          onChange: (v) => tweaks.setDensity(v.toLowerCase()),
                        ),
                        const SizedBox(height: 16),
                        _RestSection(tweaks: tweaks),
                      ],
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

  Widget _section(String label) {
    return Builder(builder: (context) {
      final p = BrutalColors.of(context);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: mono(
            size: 10,
            weight: FontWeight.w700,
            letterSpacing: 2,
            color: p.ink.withValues(alpha: 0.6),
          ),
        ),
      );
    });
  }

  Widget _sectionWithRight(String label, String right) {
    return Builder(builder: (context) {
      final p = BrutalColors.of(context);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: mono(
                  size: 10,
                  weight: FontWeight.w700,
                  letterSpacing: 2,
                  color: p.ink.withValues(alpha: 0.6),
                ),
              ),
            ),
            Text(
              right,
              style: mono(size: 10, weight: FontWeight.w800, color: p.ink),
            ),
          ],
        ),
      );
    });
  }
}

class _AccentBtn extends StatelessWidget {
  final Accent accent;
  final bool active;
  final VoidCallback onTap;
  const _AccentBtn({required this.accent, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: active
            ? (Matrix4.identity()..translate(-1.5, -1.5))
            : Matrix4.identity(),
        height: 44,
        decoration: BoxDecoration(
          color: accent.v,
          border: Border.all(color: p.ink, width: 2),
          boxShadow: active
              ? [BoxShadow(color: p.ink, offset: const Offset(3, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          active ? '●' : accent.name,
          style: mono(
            size: 9,
            weight: FontWeight.w800,
            letterSpacing: 1,
            color: accent.ink,
          ),
        ),
      ),
    );
  }
}

class _GroupToggle extends StatelessWidget {
  final String group;
  final bool on;
  const _GroupToggle({required this.group, required this.on});

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: on ? p.accent : p.paper,
        border: Border.all(color: p.ink, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: on ? 1 : 0.3,
            child: Text(
              on ? '■' : '□',
              style: mono(
                size: 11,
                weight: FontWeight.w800,
                color: on ? p.accentInk : p.ink,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              group,
              overflow: TextOverflow.ellipsis,
              style: mono(
                size: 11,
                weight: FontWeight.w800,
                letterSpacing: 0.5,
                color: on ? p.accentInk : p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestSection extends StatelessWidget {
  final Tweaks tweaks;
  const _RestSection({required this.tweaks});

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final rest = tweaks.defaultRest;
    final mins = rest ~/ 60;
    final secs = rest % 60;
    const presets = [30, 60, 90, 120, 180, 300];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'DEFAULT REST',
                style: mono(
                  size: 10,
                  weight: FontWeight.w700,
                  letterSpacing: 2,
                  color: p.ink.withValues(alpha: 0.6),
                ),
              ),
            ),
            RichText(
              text: TextSpan(
                style: mono(size: 20, weight: FontWeight.w800, letterSpacing: -0.5, color: p.ink),
                children: [
                  TextSpan(text: '$mins'),
                  TextSpan(
                    text: 'M ',
                    style: mono(size: 12, color: p.ink.withValues(alpha: 0.6)),
                  ),
                  TextSpan(text: secs.toString().padLeft(2, '0')),
                  TextSpan(
                    text: 'S',
                    style: mono(size: 12, color: p.ink.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RestStepper(
                label: 'MIN',
                value: mins,
                max: 10,
                onChange: (v) => tweaks.setDefaultRest(v * 60 + secs),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RestStepper(
                label: 'SEC',
                value: secs,
                max: 55,
                step: 5,
                onChange: (v) => tweaks.setDefaultRest(mins * 60 + v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final t in presets)
              GestureDetector(
                onTap: () => tweaks.setDefaultRest(t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rest == t ? p.ink : p.paper,
                    border: Border.all(color: p.ink, width: 2),
                  ),
                  child: Text(
                    '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}',
                    style: mono(
                      size: 10,
                      weight: FontWeight.w800,
                      letterSpacing: 1,
                      color: rest == t ? p.paper : p.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RestStepper extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final int step;
  final ValueChanged<int> onChange;
  const _RestStepper({
    required this.label,
    required this.value,
    required this.max,
    required this.onChange,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(border: Border.all(color: p.ink, width: 2)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChange((value - step).clamp(0, max)),
            child: Container(
              width: 40,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: p.ink, width: 2)),
              ),
              alignment: Alignment.center,
              child: Text('−', style: mono(size: 20, weight: FontWeight.w800, color: p.ink)),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: mono(
                    size: 9,
                    weight: FontWeight.w700,
                    letterSpacing: 1,
                    color: p.ink.withValues(alpha: 0.5),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.toString().padLeft(2, '0'),
                  style: mono(
                    size: 18,
                    weight: FontWeight.w800,
                    color: p.ink,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChange((value + step).clamp(0, max)),
            child: Container(
              width: 40,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: p.ink, width: 2)),
              ),
              alignment: Alignment.center,
              child: Text('+', style: mono(size: 20, weight: FontWeight.w800, color: p.ink)),
            ),
          ),
        ],
      ),
    );
  }
}

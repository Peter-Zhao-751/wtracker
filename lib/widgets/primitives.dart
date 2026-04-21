import 'package:flutter/material.dart';
import '../theme.dart';

class BrutalColors extends InheritedWidget {
  final BrutalPalette palette;
  const BrutalColors({super.key, required this.palette, required super.child});

  static BrutalPalette of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<BrutalColors>();
    assert(w != null, 'BrutalColors not found in context');
    return w!.palette;
  }

  @override
  bool updateShouldNotify(BrutalColors old) => old.palette != palette;
}

/// Heavy-bordered container with optional tag label sticking out of the corner.
class BrutalBox extends StatelessWidget {
  final Widget child;
  final String? tag;
  final EdgeInsetsGeometry? padding;
  final Color? background;
  final VoidCallback? onTap;
  final double borderWidth;

  const BrutalBox({
    super.key,
    required this.child,
    this.tag,
    this.padding,
    this.background,
    this.onTap,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    Widget content = Container(
      decoration: BoxDecoration(
        color: background ?? p.paper,
        border: Border.all(color: p.ink, width: borderWidth),
      ),
      padding: padding,
      child: child,
    );
    if (tag != null) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            top: -borderWidth,
            left: -borderWidth,
            child: Container(
              color: p.ink,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                tag!,
                style: mono(size: 9, weight: FontWeight.w700, letterSpacing: 0.5, color: p.paper),
              ),
            ),
          ),
        ],
      );
    }
    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? delta;
  final Color? deltaColor;
  final bool large;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.deltaColor,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border.all(color: p.ink, width: 2),
      ),
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: mono(size: 9, weight: FontWeight.w700, letterSpacing: 1, color: p.ink.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: mono(
                  size: large ? 28 : 20,
                  weight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: p.ink,
                  height: 1,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: mono(size: 10, weight: FontWeight.w600, color: p.ink.withValues(alpha: 0.7)),
                ),
              ],
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(
              delta!,
              style: mono(
                size: 10,
                weight: FontWeight.w700,
                color: deltaColor ?? p.accentOnPaper,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class Segmented extends StatelessWidget {
  final List<String> opts;
  final String value;
  final ValueChanged<String> onChange;
  final double height;
  final double fontSize;
  const Segmented({
    super.key,
    required this.opts,
    required this.value,
    required this.onChange,
    this.height = 36,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: p.ink, width: 2)),
      child: Row(
        children: [
          for (int i = 0; i < opts.length; i++) ...[
            if (i > 0) Container(width: 2, height: height, color: p.ink),
            Expanded(
              child: InkWell(
                onTap: () => onChange(opts[i]),
                child: Container(
                  height: height,
                  alignment: Alignment.center,
                  color: value == opts[i] ? p.ink : p.paper,
                  child: Text(
                    opts[i].toUpperCase(),
                    style: mono(
                      size: fontSize,
                      weight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: value == opts[i] ? p.paper : p.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum BtnVariant { primary, dark, outline }

class BrutalButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final BtnVariant variant;
  final bool disabled;
  final double? width;
  final double height;
  const BrutalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BtnVariant.primary,
    this.disabled = false,
    this.width,
    this.height = 44,
  });

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final bg = switch (widget.variant) {
      BtnVariant.primary => p.accent,
      BtnVariant.dark => p.ink,
      BtnVariant.outline => p.paper,
    };
    final fg = switch (widget.variant) {
      // Primary sits on a bright accent. `accentInk` is the dark companion
      // paired to each accent (see theme.dart) and stays readable on light
      // accents (ACID/LIME) in dark mode, where plain `ink` is near-white.
      BtnVariant.primary => p.accentInk,
      BtnVariant.dark => p.paper,
      BtnVariant.outline => p.ink,
    };
    final hasShadow = widget.variant == BtnVariant.primary;
    final disabled = widget.disabled || widget.onPressed == null;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: hasShadow && _down
            ? (Matrix4.identity()..translate(2.0, 2.0))
            : Matrix4.identity(),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: p.ink, width: 2),
          boxShadow: hasShadow
              ? [
                  BoxShadow(
                    color: p.ink,
                    offset: _down ? const Offset(1, 1) : const Offset(3, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Text(
            widget.label,
            style: mono(size: 13, weight: FontWeight.w800, letterSpacing: 1, color: fg),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class TabDef {
  final String id;
  final String label;
  final String icon;
  const TabDef(this.id, this.label, this.icon);
}

class BottomTabBar extends StatelessWidget {
  final String active;
  final ValueChanged<String> onTab;
  const BottomTabBar({super.key, required this.active, required this.onTab});

  static const tabs = [
    TabDef('dash', 'HUB',   '◎'),
    TabDef('tpl',  'PLANS', '▤'),
    TabDef('log',  'LOG',   '●'),
    TabDef('prog', 'PROG',  '▲'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: p.paper,
        border: Border(top: BorderSide(color: p.ink, width: 2)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++) ...[
            if (i > 0) Container(width: 2, color: p.ink),
            Expanded(
              child: InkWell(
                onTap: () => onTab(tabs[i].id),
                child: Container(
                  color: active == tabs[i].id ? p.ink : p.paper,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tabs[i].icon,
                        style: mono(
                          size: 16,
                          color: active == tabs[i].id ? p.paper : p.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tabs[i].label,
                        style: mono(
                          size: 10,
                          weight: FontWeight.w800,
                          letterSpacing: 1,
                          color: active == tabs[i].id ? p.paper : p.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppHeaderBar extends StatelessWidget {
  final String title;
  final String sub;
  final Widget? right;
  final Widget? titleWidget;
  const AppHeaderBar({
    super.key,
    required this.title,
    required this.sub,
    this.right,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border(bottom: BorderSide(color: p.ink, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.toUpperCase(),
                  style: mono(
                    size: 10,
                    weight: FontWeight.w700,
                    letterSpacing: 2,
                    color: p.ink.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                titleWidget ??
                    Text(
                      title.toUpperCase(),
                      style: mono(
                        size: 26,
                        weight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: p.ink,
                      ),
                    ),
              ],
            ),
          ),
          if (right != null) right!,
        ],
      ),
    );
  }
}

/// Icon button — square, bordered. Accepts either a glyph string or an icon.
class IconSquare extends StatelessWidget {
  final String? glyph;
  final IconData? icon;
  final VoidCallback onTap;
  final double size;
  const IconSquare({
    super.key,
    this.glyph,
    this.icon,
    required this.onTap,
    this.size = 40,
  }) : assert(glyph != null || icon != null, 'IconSquare needs a glyph or icon');

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.paper,
          border: Border.all(color: p.ink, width: 2),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: size * 0.5, color: p.ink)
            : Text(glyph!, style: mono(size: 16, weight: FontWeight.w800, color: p.ink)),
      ),
    );
  }
}

/// Returns a proxyDecorator for ReorderableListView. Matches the original
/// JSX ghost: rotate(-1.5deg), scale(1.02), ink offset shadow + accent halo.
///
/// The drag proxy is built inside the reorder overlay — above BrutalColors in
/// the tree — so the palette must be captured at the call site and passed in.
Widget Function(Widget, int, Animation<double>) brutalGhostDecorator(
  BrutalPalette palette,
) {
  return (Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, inner) {
        final t = Curves.easeOutCubic.transform(animation.value);
        return Transform.rotate(
          alignment: Alignment.center,
          angle: -0.026 * t,
          child: Transform.scale(
            alignment: Alignment.center,
            scale: 1 + 0.025 * t,
            child: Material(
              type: MaterialType.transparency,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.paper,
                  boxShadow: [
                    BoxShadow(
                      color: palette.ink.withValues(alpha: 0.9),
                      offset: Offset(6 * t, 6 * t),
                    ),
                    BoxShadow(
                      color: palette.accent,
                      spreadRadius: 3 * t,
                    ),
                  ],
                ),
                child: inner,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  };
}

class PrSplashData {
  final String lift;
  final double w;
  final int reps;
  const PrSplashData({required this.lift, required this.w, required this.reps});
}

/// Rotated accent splash shown when a set beats every previously-logged weight
/// for that lift. Host mounts this inside a [Positioned.fill] container and
/// clears it on a timer — the widget is purely presentational. When [total]
/// > 1 a "PR N OF M" counter is rendered so multi-PR sequences self-announce.
class PrSplash extends StatelessWidget {
  final PrSplashData data;
  final String unit;
  final int index;
  final int total;
  const PrSplash({
    super.key,
    required this.data,
    required this.unit,
    this.index = 1,
    this.total = 1,
  });

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final multi = total > 1;
    return Container(
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
              if (multi) ...[
                Text(
                  'PR $index OF $total',
                  style: mono(
                    size: 11,
                    weight: FontWeight.w800,
                    letterSpacing: 2.5,
                    color: p.accentInk.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 6),
              ],
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
                data.lift,
                style: mono(
                  size: 13,
                  weight: FontWeight.w700,
                  color: p.accentInk.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${data.w.toStringAsFixed(0)} ${unit.toUpperCase()} × ${data.reps}',
                style: mono(size: 22, weight: FontWeight.w800, color: p.accentInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashedLine extends StatelessWidget {
  final Color color;
  final double dash;
  final double gap;
  final double strokeWidth;
  const DashedLine({
    super.key,
    required this.color,
    this.dash = 3,
    this.gap = 3,
    this.strokeWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: strokeWidth,
      child: CustomPaint(
        painter: _DashedLinePainter(color: color, dash: dash, gap: gap, strokeWidth: strokeWidth),
        size: Size.infinite,
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dash;
  final double gap;
  final double strokeWidth;
  _DashedLinePainter({
    required this.color,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      final end = (x + dash).clamp(0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end.toDouble(), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.color != color || old.dash != dash || old.gap != gap || old.strokeWidth != strokeWidth;
}

class SparkPainter extends CustomPainter {
  final List<double> data;
  final Color ink;
  final Color accent;
  SparkPainter({required this.data, required this.ink, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = (max - min) == 0 ? 1.0 : (max - min);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final strokePaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);

    final lastX = size.width;
    final lastY = size.height - ((data.last - min) / range) * size.height;
    final dot = Paint()..color = accent;
    canvas.drawCircle(Offset(lastX, lastY), 2.5, dot);
    canvas.drawCircle(
      Offset(lastX, lastY),
      2.5,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(SparkPainter old) => old.data != data || old.ink != ink || old.accent != accent;
}

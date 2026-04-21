import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

class RadarChartWidget extends StatelessWidget {
  final List<GroupStat> data;
  final double size;
  final String styleMode; // 'filled' | 'outline' | 'gradient'
  final Color accent;
  final Color ink;
  final Color paper;
  final double animate; // 0..1

  const RadarChartWidget({
    super.key,
    required this.data,
    this.size = 290,
    required this.styleMode,
    required this.accent,
    required this.ink,
    required this.paper,
    this.animate = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          data: data,
          styleMode: styleMode,
          accent: accent,
          ink: ink,
          paper: paper,
          animate: animate,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<GroupStat> data;
  final String styleMode;
  final Color accent;
  final Color ink;
  final Color paper;
  final double animate;

  _RadarPainter({
    required this.data,
    required this.styleMode,
    required this.accent,
    required this.ink,
    required this.paper,
    required this.animate,
  });

  Offset _pt(Offset center, int i, double r, int n) {
    final a = -pi / 2 + (i * 2 * pi) / n;
    return Offset(center.dx + cos(a) * r, center.dy + sin(a) * r);
  }

  Path _poly(Offset center, List<double> vals, double R, int n) {
    final path = Path();
    for (int i = 0; i < vals.length; i++) {
      final p = _pt(center, i, (vals[i] / 100) * R, n);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 3) return;
    final n = data.length;
    final center = Offset(size.width / 2, size.height / 2);
    final R = size.width * 0.36;

    final current = data
        .map((d) => (d.prev + (d.value - d.prev) * animate).toDouble())
        .toList();
    final prev = data.map((d) => d.prev.toDouble()).toList();

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = ink;

    // rings
    final rings = [0.25, 0.5, 0.75, 1.0];
    for (int r = 0; r < rings.length; r++) {
      final f = rings[r];
      final vals = List<double>.filled(n, f * 100);
      final path = _poly(center, vals, R, n);
      final isLast = r == rings.length - 1;
      ringPaint.strokeWidth = isLast ? 2 : 0.75;
      ringPaint.color = ink.withValues(alpha: isLast ? 1.0 : 0.35);
      if (isLast) {
        canvas.drawPath(path, ringPaint);
      } else {
        _drawDashed(canvas, path, ringPaint, 2, 3);
      }
    }

    // spokes
    final spoke = Paint()
      ..color = ink.withValues(alpha: 0.35)
      ..strokeWidth = 0.75;
    for (int i = 0; i < n; i++) {
      final p = _pt(center, i, R, n);
      canvas.drawLine(center, p, spoke);
    }

    // previous (ghost, dashed)
    final prevPath = _poly(center, prev, R, n);
    final prevPaint = Paint()
      ..color = ink.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashed(canvas, prevPath, prevPaint, 3, 3);

    // current
    final currentPath = _poly(center, current, R, n);

    if (styleMode == 'filled') {
      canvas.drawPath(
        currentPath,
        Paint()..color = accent.withValues(alpha: 0.35),
      );
    } else if (styleMode == 'outline') {
      _drawHatch(canvas, currentPath, ink);
    } else if (styleMode == 'gradient') {
      // Match the JSX demo exactly: darkest stop (0.85 alpha) at the strongest
      // vertex, lightest (0.15 alpha) at the opposite side. If two+ vertices
      // tie for max, collapse to a centered radial gradient so direction
      // doesn't jitter.
      final maxVal = current.reduce((a, b) => a > b ? a : b);
      final maxIdxs = <int>[];
      for (int i = 0; i < current.length; i++) {
        if (current[i] == maxVal) maxIdxs.add(i);
      }
      final bounds = currentPath.getBounds();
      final Shader shader;
      if (maxIdxs.length > 1) {
        shader = RadialGradient(
          center: Alignment.center,
          radius: 0.5,
          colors: [
            accent.withValues(alpha: 0.85),
            accent.withValues(alpha: 0.15),
          ],
        ).createShader(bounds);
      } else {
        // SVG objectBoundingBox: dark at (0.5 + cos·0.5, 0.5 + sin·0.5),
        // light at the mirror. Flutter's Alignment = 2·u − 1, so the
        // begin/end collapse to (cos, sin) and (−cos, −sin).
        final angle = -pi / 2 + (maxIdxs[0] * 2 * pi) / n;
        final dx = cos(angle);
        final dy = sin(angle);
        shader = LinearGradient(
          begin: Alignment(dx, dy),
          end: Alignment(-dx, -dy),
          colors: [
            accent.withValues(alpha: 0.85),
            accent.withValues(alpha: 0.15),
          ],
        ).createShader(bounds);
      }
      canvas.drawPath(currentPath, Paint()..shader = shader);
    }

    canvas.drawPath(
      currentPath,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.miter,
    );

    // vertices
    for (int i = 0; i < n; i++) {
      final v = current[i];
      final p = _pt(center, i, (v / 100) * R, n);
      final r = Rect.fromCenter(center: p, width: 8, height: 8);
      canvas.drawRect(r, Paint()..color = paper);
      canvas.drawRect(
        r,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // labels
    for (int i = 0; i < n; i++) {
      final p = _pt(center, i, R + 22, n);
      final label = data[i].label;
      final value = current[i].round().toString().padLeft(2, '0');
      _drawText(canvas, label, p, ink, 11, FontWeight.w700, 0.5);
      _drawText(
        canvas,
        value,
        Offset(p.dx, p.dy + 13),
        ink.withValues(alpha: 0.55),
        10,
        FontWeight.w400,
        0,
      );
    }

    // crosshair
    final ch = Paint()
      ..color = ink
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - 4, center.dy),
      Offset(center.dx + 4, center.dy),
      ch,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 4),
      Offset(center.dx, center.dy + 4),
      ch,
    );
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint, double dash, double gap) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final seg = metric.extractPath(distance, distance + dash);
        canvas.drawPath(seg, paint);
        distance += dash + gap;
      }
    }
  }

  void _drawHatch(Canvas canvas, Path path, Color ink) {
    canvas.save();
    canvas.clipPath(path);
    final bounds = path.getBounds();
    final hatch = Paint()
      ..color = ink.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (double d = -bounds.height; d < bounds.width + bounds.height; d += 6) {
      canvas.drawLine(
        Offset(bounds.left + d, bounds.top),
        Offset(bounds.left + d + bounds.height, bounds.bottom),
        hatch,
      );
    }
    canvas.restore();
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos,
    Color color,
    double size,
    FontWeight weight,
    double letterSpacing,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: mono(
          size: size,
          weight: weight,
          letterSpacing: letterSpacing,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.animate != animate ||
      old.styleMode != styleMode ||
      old.data != data ||
      old.accent != accent ||
      old.ink != ink ||
      old.paper != paper;
}


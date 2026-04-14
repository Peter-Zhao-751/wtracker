import 'package:flutter/material.dart';
import '../theme.dart';

class CyberCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool showCornerAccents;
  final VoidCallback? onTap;

  const CyberCard({
    super.key,
    required this.child,
    this.glowColor = CyberTheme.neonCyan,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    this.showCornerAccents = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: CyberTheme.cardDecoration(glowColor: glowColor),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(padding: padding, child: child),
            if (showCornerAccents) ..._cornerAccents(),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }

  List<Widget> _cornerAccents() {
    return [
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: _CornerMark(color: glowColor, topLeft: true),
      ),
      // Bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: _CornerMark(color: glowColor, topLeft: false),
      ),
    ];
  }
}

class _CornerMark extends StatelessWidget {
  final Color color;
  final bool topLeft;

  const _CornerMark({required this.color, required this.topLeft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _CornerPainter(color: color, topLeft: topLeft),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final bool topLeft;

  _CornerPainter({required this.color, required this.topLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    if (topLeft) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
      canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
    } else {
      canvas.drawLine(
        Offset(0, size.height),
        Offset(size.width, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

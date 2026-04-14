import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models.dart';

class MovementCard extends StatelessWidget {
  final MovementProgress progress;

  const MovementCard({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final isPositive = progress.changePerMonth > 0;
    final isFlat = progress.changePerMonth.abs() < 1;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: CyberTheme.cardDecoration(
        glowColor: isFlat
            ? CyberTheme.neonYellow
            : (isPositive ? CyberTheme.neonGreen : CyberTheme.neonMagenta),
        glowOpacity: 0.06,
        borderOpacity: 0.12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            progress.name.toUpperCase(),
            style: CyberTheme.chipText.copyWith(
              color: CyberTheme.textSecondary,
              letterSpacing: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                progress.currentBestWeight.toStringAsFixed(0),
                style: GoogleFonts.orbitron(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: CyberTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '× ${progress.currentBestReps}',
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CyberTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 30,
            child: CustomPaint(
              size: const Size(double.infinity, 30),
              painter: _SparklinePainter(
                data: progress.recentScores,
                lineColor: isFlat
                    ? CyberTheme.neonYellow
                    : (isPositive
                        ? CyberTheme.neonGreen
                        : CyberTheme.neonMagenta),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildTrend(isPositive, isFlat),
        ],
      ),
    );
  }

  Widget _buildTrend(bool isPositive, bool isFlat) {
    final Color color;
    final String text;
    final IconData icon;

    if (isFlat) {
      color = CyberTheme.neonYellow;
      text = 'FLAT';
      icon = Icons.remove;
    } else if (isPositive) {
      color = CyberTheme.neonGreen;
      text = '+${progress.changePerMonth.toStringAsFixed(0)} LB/MO';
      icon = Icons.arrow_upward;
    } else {
      color = CyberTheme.neonMagenta;
      text = '${progress.changePerMonth.toStringAsFixed(0)} LB/MO';
      icon = Icons.arrow_downward;
    }

    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.orbitron(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;

  _SparklinePainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final maxVal = data.reduce(max);
    final minVal = data.reduce(min);
    final range = maxVal - minVal;
    if (range == 0) return;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.2),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height - ((data[i] - minVal) / range) * (size.height - 4) - 2;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // End dot
    final lastX = size.width;
    final lastY = size.height -
        ((data.last - minVal) / range) * (size.height - 4) -
        2;
    canvas.drawCircle(
      Offset(lastX, lastY),
      3,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

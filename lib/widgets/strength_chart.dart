import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models.dart';

class StrengthChart extends StatefulWidget {
  final List<StrengthDataPoint> data;
  final double currentScore;
  final double changePercent;

  const StrengthChart({
    super.key,
    required this.data,
    required this.currentScore,
    required this.changePercent,
  });

  @override
  State<StrengthChart> createState() => _StrengthChartState();
}

class _StrengthChartState extends State<StrengthChart> {
  int _selectedRange = 2; // index into [1, 3, 6, 12]
  static const _ranges = [1, 3, 6, 12];

  List<StrengthDataPoint> get _filteredData {
    final months = _ranges[_selectedRange];
    final cutoff = DateTime.now().subtract(Duration(days: months * 30));
    return widget.data.where((p) => p.date.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: CyberTheme.cardDecoration(
        glowColor: CyberTheme.neonCyan,
        glowOpacity: 0.12,
        borderOpacity: 0.2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Subtle grid background
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 6),
                  _buildScoreRow(),
                  const SizedBox(height: 20),
                  SizedBox(height: 200, child: _buildChart()),
                  const SizedBox(height: 16),
                  _buildRangeToggle(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'STRENGTH SCORE',
      style: CyberTheme.sectionTitle.copyWith(
        color: CyberTheme.neonCyan.withValues(alpha: 0.7),
        fontSize: 11,
      ),
    );
  }

  Widget _buildScoreRow() {
    final isPositive = widget.changePercent >= 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          widget.currentScore.toStringAsFixed(0),
          style: CyberTheme.scoreDisplay,
        ),
        const SizedBox(width: 8),
        Text('LB', style: CyberTheme.statLabel.copyWith(fontSize: 14)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (isPositive ? CyberTheme.neonGreen : CyberTheme.neonMagenta)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (isPositive
                      ? CyberTheme.neonGreen
                      : CyberTheme.neonMagenta)
                  .withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 14,
                color:
                    isPositive ? CyberTheme.neonGreen : CyberTheme.neonMagenta,
              ),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}${widget.changePercent.toStringAsFixed(1)}%',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPositive
                      ? CyberTheme.neonGreen
                      : CyberTheme.neonMagenta,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    final data = _filteredData;
    if (data.isEmpty) {
      return Center(
        child: Text('No data yet', style: CyberTheme.cardBody),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].score));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.95;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.03;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: CyberTheme.textMuted.withValues(alpha: 0.15),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: (maxY - minY) / 4,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  color: CyberTheme.textMuted,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (data.length / 5).ceilToDouble().clamp(1, 100),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('M/d').format(data[idx].date),
                    style: GoogleFonts.rajdhani(
                      fontSize: 10,
                      color: CyberTheme.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => CyberTheme.bgSurface,
            tooltipBorder:
                BorderSide(color: CyberTheme.neonCyan.withValues(alpha: 0.3)),
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots.map((spot) {
              final idx = spot.spotIndex;
              final point = data[idx];
              return LineTooltipItem(
                '${DateFormat('MMM d').format(point.date)}\n',
                GoogleFonts.rajdhani(
                  color: CyberTheme.textSecondary,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: point.score.toStringAsFixed(0),
                    style: GoogleFonts.orbitron(
                      color: CyberTheme.neonCyan,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: CyberTheme.neonCyan,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                if (index == spots.length - 1) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: CyberTheme.neonCyan,
                    strokeWidth: 2,
                    strokeColor: CyberTheme.bgDark,
                  );
                }
                return FlDotCirclePainter(
                  radius: 0,
                  color: Colors.transparent,
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  CyberTheme.neonCyan.withValues(alpha: 0.2),
                  CyberTheme.neonCyan.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildRangeToggle() {
    const labels = ['1M', '3M', '6M', '1Y'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(labels.length, (i) {
        final isActive = _selectedRange == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedRange = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? CyberTheme.neonCyan.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? CyberTheme.neonCyan.withValues(alpha: 0.4)
                    : CyberTheme.textMuted.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              labels[i],
              style: CyberTheme.chipText.copyWith(
                color:
                    isActive ? CyberTheme.neonCyan : CyberTheme.textMuted,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CyberTheme.neonCyan.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    const spacing = 24.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

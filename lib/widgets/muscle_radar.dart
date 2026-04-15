import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../exercise_info.dart';
import '../data.dart';
import '../models.dart';

// ── Page 0: Radar overview ──

class MuscleRadarPage extends StatefulWidget {
  const MuscleRadarPage({super.key});

  @override
  State<MuscleRadarPage> createState() => _MuscleRadarPageState();
}

class _MuscleRadarPageState extends State<MuscleRadarPage>
    with SingleTickerProviderStateMixin {
  static const _groups = MuscleGroup.values;
  static const _groupLabels = ['CHEST', 'BACK', 'LEGS', 'SHLDR', 'ARMS'];

  bool _expanded = false;
  late AnimationController _animController;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = WorkoutRepository.instance;
    final best = repo.allBest1RMs;
    final hasData = best.isNotEmpty;

    final groupScores = <double>[];
    for (final g in _groups) {
      groupScores.add(muscleGroupScore(g, best));
    }

    // Overall = geometric average of groups with data
    final nonZero = groupScores.where((s) => s > 0).toList();
    final overall = nonZero.isEmpty
        ? 0.0
        : math.exp(nonZero.map(math.log).reduce((a, b) => a + b) / nonZero.length);
    final overallColor = ratingColor(overall);
    final overallLevel = ratingLabel(overall);
    final next = _nextMilestone(overall);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: CyberTheme.cardDecoration(
        glowColor: overallColor,
        glowOpacity: 0.1,
        borderOpacity: 0.18,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GridBgPainter())),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(overall, overallLevel, overallColor, next),
                  const SizedBox(height: 6),
                  if (hasData)
                    SizedBox(
                      height: 210,
                      child: _buildRadar(groupScores, next.threshold),
                    )
                  else
                    SizedBox(
                      height: 210,
                      child: Center(
                        child: Text(
                          'Log workouts to see\nyour muscle balance',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rajdhani(
                            fontSize: 14,
                            color: CyberTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  if (hasData) ...[
                    const SizedBox(height: 4),
                    _buildGoalLegend(next),
                    const SizedBox(height: 10),
                    _buildGroupScoreRow(groupScores),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    double overall,
    String level,
    Color color,
    _Milestone next,
  ) {
    final ptsToNext = (next.threshold - overall).ceil();
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATHLETE PROFILE',
              style: CyberTheme.sectionTitle.copyWith(
                color: color.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                level,
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (ptsToNext > 0)
              Text(
                '$ptsToNext pts to ${next.label}',
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: next.color.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              overall > 0 ? overall.toStringAsFixed(0) : '—',
              style: GoogleFonts.orbitron(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              '/ 100',
              style: GoogleFonts.orbitron(
                fontSize: 10,
                color: CyberTheme.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRadar(List<double> scores, double goalThreshold) {
    final dataMax = [
      ...scores,
      goalThreshold,
    ].reduce(math.max);
    final fittedMax = (dataMax * 1.15).clamp(10.0, 100.0);

    return GestureDetector(
      onTap: _toggleExpanded,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _expandAnim,
        builder: (context, child) {
          final maxValue =
              fittedMax + (100.0 - fittedMax) * _expandAnim.value;
          return CustomPaint(
            painter: _SpiderWebRadarPainter(
              scores: scores,
              maxValue: maxValue,
              goalThreshold: goalThreshold,
              rankThresholds: const [35, 55, 75, 88, 100],
              groupLabels: _groupLabels,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildGoalLegend(_Milestone next) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 18,
          height: 1.5,
          color: CyberTheme.textSecondary.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 6),
        Text(
          'GOAL: ${next.label} (${next.threshold.toStringAsFixed(0)})',
          style: GoogleFonts.orbitron(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: CyberTheme.textSecondary.withValues(alpha: 0.6),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 18,
          height: 1.5,
          color: CyberTheme.textSecondary.withValues(alpha: 0.35),
        ),
      ],
    );
  }

  Widget _buildGroupScoreRow(List<double> scores) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(_groups.length, (i) {
        final color = _groupColor(_groups[i]);
        final score = scores[i];
        return Column(
          children: [
            Text(
              score > 0 ? score.toStringAsFixed(0) : '—',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: score > 0 ? color : CyberTheme.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _groupLabels[i],
              style: GoogleFonts.orbitron(
                fontSize: 8,
                color: CyberTheme.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Pages 1–5: Individual muscle group detail ──

class MuscleGroupDetailPage extends StatelessWidget {
  final MuscleGroup group;

  const MuscleGroupDetailPage({super.key, required this.group});

  static const _groupNames = {
    MuscleGroup.chest: 'CHEST',
    MuscleGroup.back: 'BACK',
    MuscleGroup.legs: 'LEGS',
    MuscleGroup.shoulders: 'SHOULDERS',
    MuscleGroup.arms: 'ARMS',
  };

  @override
  Widget build(BuildContext context) {
    final repo = WorkoutRepository.instance;
    final best = repo.allBest1RMs;
    final score = muscleGroupScore(group, best);
    final color = _groupColor(group);
    final label = ratingLabel(score);
    final history = repo.muscleGroupHistory(group);
    final exercises = exerciseDatabase.where((e) => e.group == group).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: CyberTheme.cardDecoration(
        glowColor: color,
        glowOpacity: 0.1,
        borderOpacity: 0.18,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GridBgPainter())),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(score, label, color),
                  const SizedBox(height: 12),
                  _buildScoreBar(score, color),
                  const SizedBox(height: 14),
                  Text(
                    'PROGRESSION',
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: CyberTheme.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 80,
                    child: history.length >= 2
                        ? _buildProgressionChart(history, color)
                        : Center(
                            child: Text(
                              score > 0
                                  ? 'Train more to see progression'
                                  : 'No data yet',
                              style: GoogleFonts.rajdhani(
                                fontSize: 12,
                                color: CyberTheme.textMuted,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'EXERCISES',
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: CyberTheme.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      children: exercises
                          .map((ex) => _buildExerciseRow(ex, best, color))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double score, String label, Color color) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _groupNames[group]!,
              style: CyberTheme.sectionTitle.copyWith(
                color: color.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                label,
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              score > 0 ? score.toStringAsFixed(0) : '—',
              style: GoogleFonts.orbitron(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              '/ 100',
              style: GoogleFonts.orbitron(
                fontSize: 10,
                color: CyberTheme.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreBar(double score, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(color: CyberTheme.bgSurface),
            FractionallySizedBox(
              widthFactor: (score / 100).clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.5),
                      color,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressionChart(List<StrengthDataPoint> history, Color color) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].score));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                if (index == spots.length - 1) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: color,
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
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(
      ExerciseInfo ex, Map<String, double> best, Color groupColor) {
    final e1rm = best[ex.name] ?? 0;
    final standard = eliteStandards[ex.name] ?? 200;
    final score = e1rm > 0 ? liftScore(e1rm, standard) : 0.0;
    final color = score > 0 ? ratingColor(score) : CyberTheme.textMuted;
    final label = ratingLabelShort(score);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              _shortName(ex.name),
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    score > 0 ? CyberTheme.textSecondary : CyberTheme.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 28,
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 5,
                child: Stack(
                  children: [
                    Container(color: CyberTheme.bgSurface),
                    FractionallySizedBox(
                      widthFactor: (score / 100).clamp(0, 1),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.6),
                              color,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            child: Text(
              score > 0 ? score.toStringAsFixed(0) : '—',
              style: GoogleFonts.orbitron(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ──

class _Milestone {
  final double threshold;
  final String label;
  final Color color;
  const _Milestone(this.threshold, this.label, this.color);
}

_Milestone _nextMilestone(double score) {
  if (score >= 88) return const _Milestone(100, 'MAX', CyberTheme.neonGreen);
  if (score >= 75) return const _Milestone(88, 'ELITE', CyberTheme.neonGreen);
  if (score >= 55) return const _Milestone(75, 'ADVANCED', CyberTheme.neonPurple);
  if (score >= 35) return const _Milestone(55, 'INTERMEDIATE', CyberTheme.neonCyan);
  return const _Milestone(35, 'NOVICE', CyberTheme.neonYellow);
}

Color _groupColor(MuscleGroup group) => switch (group) {
      MuscleGroup.chest => CyberTheme.neonCyan,
      MuscleGroup.back => CyberTheme.neonPurple,
      MuscleGroup.legs => CyberTheme.neonMagenta,
      MuscleGroup.shoulders => CyberTheme.neonYellow,
      MuscleGroup.arms => CyberTheme.neonGreen,
    };

String _shortName(String name) {
  return name
      .replaceAll('Barbell ', '')
      .replaceAll('Overhead ', 'OH ')
      .replaceAll('Back ', '')
      .replaceAll('Incline Dumbbell ', 'Inc DB ')
      .replaceAll('Romanian ', 'Rom ')
      .replaceAll('Dumbbell ', 'DB ')
      .replaceAll('Tricep ', 'Tri ');
}

class _SpiderWebRadarPainter extends CustomPainter {
  final List<double> scores;
  final double maxValue;
  final double goalThreshold;
  final List<double> rankThresholds;
  final List<String> groupLabels;

  _SpiderWebRadarPainter({
    required this.scores,
    required this.maxValue,
    required this.goalThreshold,
    required this.rankThresholds,
    required this.groupLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.78;
    final sides = scores.length;
    final angleStep = 2 * math.pi / sides;
    const startAngle = -math.pi / 2;

    final gridPaint = Paint()
      ..color = CyberTheme.textMuted.withValues(alpha: 0.35)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final goalGridPaint = Paint()
      ..color = CyberTheme.textSecondary.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Concentric pentagons at rank thresholds (35, 55, 75, 88, 100)
    for (final threshold in rankThresholds) {
      if (threshold > maxValue) continue;
      final r = (threshold / maxValue) * radius;
      canvas.drawPath(
        _polygonPath(center, r, sides, startAngle, angleStep),
        threshold == goalThreshold ? goalGridPaint : gridPaint,
      );
    }

    // Radial spokes from center
    for (int i = 0; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, end, gridPaint);
    }

    // Data polygon
    final dataPath = Path();
    final dataPoints = <Offset>[];
    for (int i = 0; i <= sides; i++) {
      final idx = i % sides;
      final angle = startAngle + angleStep * idx;
      final r = (scores[idx] / maxValue).clamp(0.0, 1.0) * radius;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i < sides) dataPoints.add(point);
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }

    // Fill
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = CyberTheme.neonCyan.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    // Glow
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = CyberTheme.neonCyan.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Border
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = CyberTheme.neonCyan.withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Data dots
    final dotPaint = Paint()
      ..color = CyberTheme.neonCyan
      ..style = PaintingStyle.fill;
    for (final point in dataPoints) {
      canvas.drawCircle(point, 3, dotPaint);
    }

    // Axis labels
    for (int i = 0; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final labelR = radius + 16;
      final labelPos = Offset(
        center.dx + labelR * math.cos(angle),
        center.dy + labelR * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: groupLabels[i],
          style: GoogleFonts.orbitron(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: CyberTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(labelPos.dx - tp.width / 2, labelPos.dy - tp.height / 2),
      );
    }
  }

  Path _polygonPath(Offset center, double r, int sides, double startAngle,
      double angleStep) {
    final path = Path();
    for (int i = 0; i <= sides; i++) {
      final angle = startAngle + angleStep * (i % sides);
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(_SpiderWebRadarPainter old) =>
      old.maxValue != maxValue ||
      old.goalThreshold != goalThreshold ||
      !_listEquals(old.scores, scores);

  bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _GridBgPainter extends CustomPainter {
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

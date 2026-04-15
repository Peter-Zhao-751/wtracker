import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

// ── Enums ──

enum MuscleGroup { chest, back, legs, shoulders, arms }

enum IllustType { bench, squat, deadlift, overhead, row, pullUp, curl, machine }

// ── Exercise info ──

class ExerciseInfo {
  final String name;
  final MuscleGroup group;
  final IllustType illustration;
  final bool defaultStarred;

  const ExerciseInfo(
    this.name,
    this.group,
    this.illustration, [
    this.defaultStarred = false,
  ]);

  Color get color => switch (group) {
        MuscleGroup.chest => CyberTheme.neonCyan,
        MuscleGroup.back => CyberTheme.neonPurple,
        MuscleGroup.legs => CyberTheme.neonMagenta,
        MuscleGroup.shoulders => CyberTheme.neonYellow,
        MuscleGroup.arms => CyberTheme.neonGreen,
      };
}

// ── Database ──

const List<ExerciseInfo> exerciseDatabase = [
  // Chest
  ExerciseInfo('Bench Press', MuscleGroup.chest, IllustType.bench, true),
  ExerciseInfo('Incline Barbell Bench', MuscleGroup.chest, IllustType.bench),
  ExerciseInfo('Incline Dumbbell Press', MuscleGroup.chest, IllustType.bench),
  ExerciseInfo('Dumbbell Bench Press', MuscleGroup.chest, IllustType.bench),
  ExerciseInfo('Cable Fly', MuscleGroup.chest, IllustType.machine),
  ExerciseInfo('Machine Chest Press', MuscleGroup.chest, IllustType.machine),
  ExerciseInfo('Dips', MuscleGroup.chest, IllustType.bench),

  // Back
  ExerciseInfo('Barbell Row', MuscleGroup.back, IllustType.row, true),
  ExerciseInfo('Pull-ups', MuscleGroup.back, IllustType.pullUp),
  ExerciseInfo('Chin-ups', MuscleGroup.back, IllustType.pullUp),
  ExerciseInfo('Lat Pulldown', MuscleGroup.back, IllustType.pullUp),
  ExerciseInfo('T-Bar Row', MuscleGroup.back, IllustType.row),
  ExerciseInfo('Seated Row', MuscleGroup.back, IllustType.row),
  ExerciseInfo('Face Pull', MuscleGroup.back, IllustType.machine),
  ExerciseInfo('Shrugs', MuscleGroup.back, IllustType.deadlift),

  // Legs
  ExerciseInfo('Back Squat', MuscleGroup.legs, IllustType.squat, true),
  ExerciseInfo('Deadlift', MuscleGroup.legs, IllustType.deadlift, true),
  ExerciseInfo('Front Squat', MuscleGroup.legs, IllustType.squat),
  ExerciseInfo('Romanian Deadlift', MuscleGroup.legs, IllustType.deadlift),
  ExerciseInfo('Sumo Deadlift', MuscleGroup.legs, IllustType.deadlift),
  ExerciseInfo('Leg Press', MuscleGroup.legs, IllustType.machine),
  ExerciseInfo('Hack Squat', MuscleGroup.legs, IllustType.squat),
  ExerciseInfo('Bulgarian Split Squat', MuscleGroup.legs, IllustType.squat),
  ExerciseInfo('Lunges', MuscleGroup.legs, IllustType.squat),
  ExerciseInfo('Hip Thrust', MuscleGroup.legs, IllustType.machine),
  ExerciseInfo('Leg Extension', MuscleGroup.legs, IllustType.machine),
  ExerciseInfo('Hamstring Curl', MuscleGroup.legs, IllustType.machine),
  ExerciseInfo('Calf Raises', MuscleGroup.legs, IllustType.machine),

  // Shoulders
  ExerciseInfo('Overhead Press', MuscleGroup.shoulders, IllustType.overhead, true),
  ExerciseInfo('Seated Dumbbell Press', MuscleGroup.shoulders, IllustType.overhead),
  ExerciseInfo('Arnold Press', MuscleGroup.shoulders, IllustType.overhead),
  ExerciseInfo('Lateral Raise', MuscleGroup.shoulders, IllustType.machine),
  ExerciseInfo('Front Raise', MuscleGroup.shoulders, IllustType.machine),
  ExerciseInfo('Rear Delt Fly', MuscleGroup.shoulders, IllustType.machine),

  // Arms
  ExerciseInfo('Barbell Curl', MuscleGroup.arms, IllustType.curl),
  ExerciseInfo('Dumbbell Curl', MuscleGroup.arms, IllustType.curl),
  ExerciseInfo('Hammer Curl', MuscleGroup.arms, IllustType.curl),
  ExerciseInfo('Preacher Curl', MuscleGroup.arms, IllustType.curl),
  ExerciseInfo('Tricep Pushdown', MuscleGroup.arms, IllustType.machine),
  ExerciseInfo('Skull Crushers', MuscleGroup.arms, IllustType.bench),
  ExerciseInfo('Overhead Tricep Extension', MuscleGroup.arms, IllustType.overhead),
  ExerciseInfo('Close-grip Bench Press', MuscleGroup.arms, IllustType.bench),
];

// ── Helpers ──

ExerciseInfo? getExerciseInfo(String name) {
  for (final e in exerciseDatabase) {
    if (e.name == name) return e;
  }
  return null;
}

List<String> get allExerciseNames =>
    exerciseDatabase.map((e) => e.name).toList();

Set<String> get defaultStarredNames =>
    exerciseDatabase.where((e) => e.defaultStarred).map((e) => e.name).toSet();

// ── Strength standards (elite-level e1RM benchmarks) ──

const Map<String, double> eliteStandards = {
  // Chest
  'Bench Press': 315.0,
  'Incline Barbell Bench': 275.0,
  'Incline Dumbbell Press': 90.0,
  'Dumbbell Bench Press': 100.0,
  'Cable Fly': 55.0,
  'Machine Chest Press': 300.0,
  'Dips': 135.0,
  // Back
  'Barbell Row': 275.0,
  'Pull-ups': 90.0,
  'Chin-ups': 90.0,
  'Lat Pulldown': 225.0,
  'T-Bar Row': 275.0,
  'Seated Row': 225.0,
  'Face Pull': 70.0,
  'Shrugs': 365.0,
  // Legs
  'Back Squat': 405.0,
  'Deadlift': 500.0,
  'Front Squat': 315.0,
  'Romanian Deadlift': 365.0,
  'Sumo Deadlift': 500.0,
  'Leg Press': 540.0,
  'Hack Squat': 405.0,
  'Bulgarian Split Squat': 185.0,
  'Lunges': 225.0,
  'Hip Thrust': 405.0,
  'Leg Extension': 200.0,
  'Hamstring Curl': 115.0,
  'Calf Raises': 315.0,
  // Shoulders
  'Overhead Press': 200.0,
  'Seated Dumbbell Press': 80.0,
  'Arnold Press': 70.0,
  'Lateral Raise': 35.0,
  'Front Raise': 40.0,
  'Rear Delt Fly': 30.0,
  // Arms
  'Barbell Curl': 135.0,
  'Dumbbell Curl': 55.0,
  'Hammer Curl': 60.0,
  'Preacher Curl': 115.0,
  'Tricep Pushdown': 90.0,
  'Skull Crushers': 135.0,
  'Overhead Tricep Extension': 100.0,
  'Close-grip Bench Press': 275.0,
};

/// Non-linear score from 0–100 using exponential decay.
/// Asymptotically approaches 100 so nobody can truly "max out."
double liftScore(double e1rm, double eliteStandard) {
  if (e1rm <= 0 || eliteStandard <= 0) return 0;
  final ratio = e1rm / eliteStandard;
  return 100 * (1 - math.exp(-2.0 * ratio));
}

/// Score for a whole muscle group: strongest movement in that group.
double muscleGroupScore(
    MuscleGroup group, Map<String, double> best1RMs) {
  final exercises = exerciseDatabase.where((e) => e.group == group);
  double best = 0;
  for (final ex in exercises) {
    final e1rm = best1RMs[ex.name];
    if (e1rm != null && e1rm > 0) {
      final s = liftScore(e1rm, eliteStandards[ex.name] ?? 200);
      if (s > best) best = s;
    }
  }
  return best;
}

String ratingLabel(double score) {
  if (score >= 88) return 'ELITE';
  if (score >= 75) return 'ADVANCED';
  if (score >= 55) return 'INTERMEDIATE';
  if (score >= 35) return 'NOVICE';
  if (score > 0) return 'BEGINNER';
  return 'UNTRAINED';
}

String ratingLabelShort(double score) {
  if (score >= 88) return 'ELT';
  if (score >= 75) return 'ADV';
  if (score >= 55) return 'INT';
  if (score >= 35) return 'NOV';
  if (score > 0) return 'BEG';
  return '—';
}

Color ratingColor(double score) {
  if (score >= 88) return CyberTheme.neonGreen;
  if (score >= 75) return CyberTheme.neonPurple;
  if (score >= 55) return CyberTheme.neonCyan;
  if (score >= 35) return CyberTheme.neonYellow;
  if (score > 0) return CyberTheme.textSecondary;
  return CyberTheme.textMuted;
}

// ── Avatar widget ──

class ExerciseAvatar extends StatelessWidget {
  final String exerciseName;
  final double size;

  const ExerciseAvatar({
    super.key,
    required this.exerciseName,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final info = getExerciseInfo(exerciseName);
    final color = info?.color ?? CyberTheme.textMuted;
    final type = info?.illustration ?? IllustType.machine;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.15),
        child: CustomPaint(
          size: Size(size * 0.7, size * 0.7),
          painter: _ExercisePainter(type: type, color: color),
        ),
      ),
    );
  }
}

// ── Painter ──

class _ExercisePainter extends CustomPainter {
  final IllustType type;
  final Color color;

  _ExercisePainter({required this.type, required this.color});

  Offset _p(Size s, double x, double y) =>
      Offset(s.width * x, s.height * y);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.05
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case IllustType.bench:
        _drawBench(canvas, size, paint);
      case IllustType.squat:
        _drawSquat(canvas, size, paint);
      case IllustType.deadlift:
        _drawDeadlift(canvas, size, paint);
      case IllustType.overhead:
        _drawOverhead(canvas, size, paint);
      case IllustType.row:
        _drawRow(canvas, size, paint);
      case IllustType.pullUp:
        _drawPullUp(canvas, size, paint);
      case IllustType.curl:
        _drawCurl(canvas, size, paint);
      case IllustType.machine:
        _drawMachine(canvas, size, paint);
    }
  }

  void _drawBench(Canvas canvas, Size s, Paint p) {
    // Bench surface
    canvas.drawLine(_p(s, 0.12, 0.74), _p(s, 0.78, 0.74), p);
    // Head
    canvas.drawCircle(_p(s, 0.2, 0.58), s.width * 0.08, p);
    // Torso lying flat
    canvas.drawLine(_p(s, 0.28, 0.62), _p(s, 0.6, 0.62), p);
    // Arms pressing up
    canvas.drawLine(_p(s, 0.36, 0.62), _p(s, 0.36, 0.3), p);
    canvas.drawLine(_p(s, 0.52, 0.62), _p(s, 0.52, 0.3), p);
    // Bar
    final bar = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_p(s, 0.22, 0.3), _p(s, 0.66, 0.3), bar);
    // Legs
    canvas.drawLine(_p(s, 0.6, 0.62), _p(s, 0.75, 0.74), p);
    canvas.drawLine(_p(s, 0.75, 0.74), _p(s, 0.85, 0.9), p);
  }

  void _drawSquat(Canvas canvas, Size s, Paint p) {
    // Head
    canvas.drawCircle(_p(s, 0.5, 0.15), s.width * 0.08, p);
    // Bar across shoulders
    final bar = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_p(s, 0.22, 0.27), _p(s, 0.78, 0.27), bar);
    // Torso slight lean
    canvas.drawLine(_p(s, 0.5, 0.26), _p(s, 0.45, 0.52), p);
    // Thighs bent
    canvas.drawLine(_p(s, 0.45, 0.52), _p(s, 0.28, 0.68), p);
    canvas.drawLine(_p(s, 0.45, 0.52), _p(s, 0.62, 0.68), p);
    // Shins
    canvas.drawLine(_p(s, 0.28, 0.68), _p(s, 0.3, 0.9), p);
    canvas.drawLine(_p(s, 0.62, 0.68), _p(s, 0.6, 0.9), p);
  }

  void _drawDeadlift(Canvas canvas, Size s, Paint p) {
    // Head forward
    canvas.drawCircle(_p(s, 0.32, 0.2), s.width * 0.08, p);
    // Torso angled
    canvas.drawLine(_p(s, 0.36, 0.27), _p(s, 0.55, 0.5), p);
    // Arms hanging
    canvas.drawLine(_p(s, 0.42, 0.34), _p(s, 0.44, 0.62), p);
    // Bar at shins
    final bar = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_p(s, 0.25, 0.62), _p(s, 0.68, 0.62), bar);
    // Legs slightly bent
    canvas.drawLine(_p(s, 0.55, 0.5), _p(s, 0.56, 0.72), p);
    canvas.drawLine(_p(s, 0.55, 0.5), _p(s, 0.66, 0.72), p);
    canvas.drawLine(_p(s, 0.56, 0.72), _p(s, 0.52, 0.9), p);
    canvas.drawLine(_p(s, 0.66, 0.72), _p(s, 0.7, 0.9), p);
  }

  void _drawOverhead(Canvas canvas, Size s, Paint p) {
    // Head
    canvas.drawCircle(_p(s, 0.5, 0.32), s.width * 0.08, p);
    // Arms up
    canvas.drawLine(_p(s, 0.5, 0.25), _p(s, 0.32, 0.12), p);
    canvas.drawLine(_p(s, 0.5, 0.25), _p(s, 0.68, 0.12), p);
    // Bar overhead
    final bar = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_p(s, 0.18, 0.12), _p(s, 0.82, 0.12), bar);
    // Torso
    canvas.drawLine(_p(s, 0.5, 0.4), _p(s, 0.5, 0.66), p);
    // Legs
    canvas.drawLine(_p(s, 0.5, 0.66), _p(s, 0.36, 0.9), p);
    canvas.drawLine(_p(s, 0.5, 0.66), _p(s, 0.64, 0.9), p);
  }

  void _drawRow(Canvas canvas, Size s, Paint p) {
    // Head forward
    canvas.drawCircle(_p(s, 0.28, 0.25), s.width * 0.08, p);
    // Torso angled ~45°
    canvas.drawLine(_p(s, 0.32, 0.32), _p(s, 0.6, 0.52), p);
    // Upper arm down
    canvas.drawLine(_p(s, 0.4, 0.38), _p(s, 0.42, 0.58), p);
    // Forearm pulling back
    canvas.drawLine(_p(s, 0.42, 0.58), _p(s, 0.5, 0.48), p);
    // Bar
    final bar = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_p(s, 0.25, 0.58), _p(s, 0.58, 0.58), bar);
    // Legs
    canvas.drawLine(_p(s, 0.6, 0.52), _p(s, 0.62, 0.72), p);
    canvas.drawLine(_p(s, 0.62, 0.72), _p(s, 0.72, 0.9), p);
  }

  void _drawPullUp(Canvas canvas, Size s, Paint p) {
    // Bar at top
    final bar = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_p(s, 0.12, 0.1), _p(s, 0.88, 0.1), bar);
    // Arms up
    canvas.drawLine(_p(s, 0.35, 0.1), _p(s, 0.42, 0.28), p);
    canvas.drawLine(_p(s, 0.65, 0.1), _p(s, 0.58, 0.28), p);
    // Head
    canvas.drawCircle(_p(s, 0.5, 0.32), s.width * 0.08, p);
    // Torso
    canvas.drawLine(_p(s, 0.5, 0.4), _p(s, 0.5, 0.66), p);
    // Legs
    canvas.drawLine(_p(s, 0.5, 0.66), _p(s, 0.4, 0.9), p);
    canvas.drawLine(_p(s, 0.5, 0.66), _p(s, 0.6, 0.9), p);
  }

  void _drawCurl(Canvas canvas, Size s, Paint p) {
    // Head
    canvas.drawCircle(_p(s, 0.45, 0.15), s.width * 0.08, p);
    // Torso
    canvas.drawLine(_p(s, 0.45, 0.24), _p(s, 0.45, 0.58), p);
    // Left arm at side
    canvas.drawLine(_p(s, 0.45, 0.3), _p(s, 0.3, 0.52), p);
    // Right arm: upper
    canvas.drawLine(_p(s, 0.45, 0.3), _p(s, 0.58, 0.42), p);
    // Right arm: forearm curling up
    canvas.drawLine(_p(s, 0.58, 0.42), _p(s, 0.64, 0.28), p);
    // Dumbbell
    canvas.drawCircle(_p(s, 0.64, 0.25), s.width * 0.05, p);
    // Legs
    canvas.drawLine(_p(s, 0.45, 0.58), _p(s, 0.34, 0.88), p);
    canvas.drawLine(_p(s, 0.45, 0.58), _p(s, 0.56, 0.88), p);
  }

  void _drawMachine(Canvas canvas, Size s, Paint p) {
    // Head
    canvas.drawCircle(_p(s, 0.38, 0.2), s.width * 0.08, p);
    // Torso seated
    canvas.drawLine(_p(s, 0.38, 0.28), _p(s, 0.4, 0.52), p);
    // Arms forward
    canvas.drawLine(_p(s, 0.38, 0.35), _p(s, 0.62, 0.35), p);
    // Machine frame
    canvas.drawRect(
      Rect.fromLTWH(
          s.width * 0.66, s.height * 0.15, s.width * 0.14, s.height * 0.52),
      p,
    );
    // Legs
    canvas.drawLine(_p(s, 0.4, 0.52), _p(s, 0.52, 0.7), p);
    canvas.drawLine(_p(s, 0.52, 0.7), _p(s, 0.48, 0.9), p);
    // Seat
    canvas.drawLine(_p(s, 0.28, 0.52), _p(s, 0.52, 0.52), p);
  }

  @override
  bool shouldRepaint(covariant _ExercisePainter old) =>
      old.type != type || old.color != color;
}

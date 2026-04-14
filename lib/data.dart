import 'dart:math';
import 'models.dart';

const List<String> keyLifts = [
  'Bench Press',
  'Back Squat',
  'Deadlift',
  'Overhead Press',
  'Barbell Row',
];

const List<String> allExercises = [
  'Bench Press',
  'Back Squat',
  'Deadlift',
  'Overhead Press',
  'Barbell Row',
  'Incline Dumbbell Press',
  'Pull-ups',
  'Dumbbell Curl',
  'Tricep Pushdown',
  'Lateral Raise',
  'Face Pull',
  'Leg Press',
  'Romanian Deadlift',
  'Front Squat',
  'Lunges',
  'Calf Raises',
  'Hamstring Curl',
  'Cable Fly',
  'Dips',
  'Seated Row',
];

class WorkoutRepository {
  WorkoutRepository._();
  static final WorkoutRepository instance = WorkoutRepository._();

  final List<Workout> _workouts = [];
  bool _initialized = false;

  List<Workout> get workouts {
    _ensureInitialized();
    return List.unmodifiable(_workouts);
  }

  void _ensureInitialized() {
    if (!_initialized) {
      _workouts.addAll(_gatherSavedData());
      _initialized = true;
    }
  }

  void addWorkout(Workout workout) {
    _ensureInitialized();
    _workouts.insert(0, workout);
  }

  Workout? get mostRecent {
    _ensureInitialized();
    return _workouts.isEmpty ? null : _workouts.first;
  }

  // ── Strength score over time ──
  List<StrengthDataPoint> strengthHistory({int months = 6}) {
    _ensureInitialized();
    final cutoff = DateTime.now().subtract(Duration(days: months * 30));
    final filtered = _workouts.where((w) => w.date.isAfter(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final Map<String, double> bestByLift = {};
    final List<StrengthDataPoint> points = [];

    for (final workout in filtered) {
      for (final ex in workout.exercises) {
        if (keyLifts.contains(ex.exerciseName)) {
          final est = ex.bestSet.estimated1RM;
          final prev = bestByLift[ex.exerciseName] ?? 0;
          if (est > prev) bestByLift[ex.exerciseName] = est;
        }
      }
      if (bestByLift.isNotEmpty) {
        final score = bestByLift.values.reduce((a, b) => a + b);
        points.add(StrengthDataPoint(date: workout.date, score: score));
      }
    }
    return points;
  }

  double get currentStrengthScore {
    final history = strengthHistory();
    return history.isEmpty ? 0 : history.last.score;
  }

  double get strengthChangePercent {
    final history = strengthHistory(months: 2);
    if (history.length < 2) return 0;
    final oldest = history.first.score;
    final newest = history.last.score;
    if (oldest == 0) return 0;
    return ((newest - oldest) / oldest) * 100;
  }

  int workoutsThisWeek() {
    _ensureInitialized();
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _workouts.where((w) => w.date.isAfter(start)).length;
  }

  // ── Movement progression ──
  List<MovementProgress> movementProgress() {
    _ensureInitialized();
    final results = <MovementProgress>[];

    for (final lift in keyLifts.take(4)) {
      final entries = <MapEntry<DateTime, WorkoutSet>>[];

      for (final w in _workouts) {
        for (final ex in w.exercises) {
          if (ex.exerciseName == lift) {
            entries.add(MapEntry(w.date, ex.bestSet));
          }
        }
      }

      if (entries.isEmpty) continue;
      entries.sort((a, b) => a.key.compareTo(b.key));

      final current = entries.last.value;
      final previous = entries.length > 1
          ? entries[entries.length - 2].value
          : current;

      final scores = entries
          .map((e) => e.value.estimated1RM)
          .toList();

      double change = 0;
      if (entries.length >= 2) {
        final firstDate = entries.first.key;
        final lastDate = entries.last.key;
        final monthsDiff = lastDate.difference(firstDate).inDays / 30.0;
        if (monthsDiff > 0) {
          change = (scores.last - scores.first) / monthsDiff;
        }
      }

      results.add(MovementProgress(
        name: lift,
        currentBestWeight: current.weight,
        currentBestReps: current.reps,
        previousBestWeight: previous.weight,
        previousBestReps: previous.reps,
        recentScores: scores.length > 8
            ? scores.sublist(scores.length - 8)
            : scores,
        changePerMonth: change,
      ));
    }

    return results;
  }

  // ── Previous best for an exercise ──
  WorkoutSet? previousBest(String exerciseName) {
    _ensureInitialized();
    WorkoutSet? best;
    for (final w in _workouts) {
      for (final ex in w.exercises) {
        if (ex.exerciseName == exerciseName) {
          final b = ex.bestSet;
          if (best == null || b.estimated1RM > best.estimated1RM) {
            best = b;
          }
        }
      }
    }
    return best;
  }

  // ── gather saved data ──
  List<Workout> _gatherSavedData() {
    // Implementation for gathering saved data
    return [];
  }
}

class _WorkoutTemplate {
  final String title;
  final List<String> exercises;
  const _WorkoutTemplate(this.title, this.exercises);
}

import 'models.dart';
import 'storage.dart';
import 'exercise_info.dart';

class WorkoutRepository {
  WorkoutRepository._();
  static final WorkoutRepository instance = WorkoutRepository._();

  final List<Workout> _workouts = [];
  final Map<String, bool> _starred = {};
  List<String> _exerciseOrder = [];
  bool _initialized = false;

  // ── Initialization (call once at startup) ──

  Future<void> init() async {
    if (_initialized) return;
    final loaded = await StorageService.loadWorkouts();
    _workouts.addAll(loaded);
    final starMap = await StorageService.loadStarred();
    _starred.addAll(starMap);
    _exerciseOrder = await StorageService.loadExerciseOrder();
    _initialized = true;
  }

  // ── Workouts ──

  List<Workout> get workouts => List.unmodifiable(_workouts);

  Workout? get mostRecent => _workouts.isEmpty ? null : _workouts.first;

  /// Adds workout with automatic PR detection.
  /// Returns the workout with PR flags set.
  Workout addWorkout(Workout workout) {
    final withPRs = _detectPRs(workout);
    _workouts.insert(0, withPRs);
    // Fire-and-forget persist
    StorageService.saveWorkouts(_workouts);
    return withPRs;
  }

  /// Updates an existing workout by ID, re-running PR detection.
  Workout updateWorkout(Workout workout) {
    final idx = _workouts.indexWhere((w) => w.id == workout.id);
    if (idx == -1) return addWorkout(workout);
    _workouts.removeAt(idx);
    final withPRs = _detectPRs(workout);
    _workouts.insert(idx, withPRs);
    StorageService.saveWorkouts(_workouts);
    return withPRs;
  }

  void deleteWorkout(String id) {
    _workouts.removeWhere((w) => w.id == id);
    StorageService.saveWorkouts(_workouts);
  }

  // ── Starred exercises ──

  List<String> get starredExerciseNames {
    return exerciseDatabase
        .where((e) => isStarred(e.name))
        .map((e) => e.name)
        .toList();
  }

  bool isStarred(String exerciseName) {
    if (_starred.containsKey(exerciseName)) return _starred[exerciseName]!;
    return defaultStarredNames.contains(exerciseName);
  }

  void toggleStar(String exerciseName) {
    _starred[exerciseName] = !isStarred(exerciseName);
    StorageService.saveStarred(_starred);
  }

  // ── Exercise order ──

  /// Returns exercises in the user's preferred order, defaulting to muscle-group sort.
  List<ExerciseInfo> get orderedExercises {
    final all = List<ExerciseInfo>.from(exerciseDatabase);

    if (_exerciseOrder.isEmpty) {
      all.sort((a, b) {
        final g = a.group.index.compareTo(b.group.index);
        if (g != 0) return g;
        return a.name.compareTo(b.name);
      });
      return all;
    }

    final ordered = <ExerciseInfo>[];
    final remaining = List<ExerciseInfo>.from(all);

    for (final name in _exerciseOrder) {
      final idx = remaining.indexWhere((e) => e.name == name);
      if (idx != -1) ordered.add(remaining.removeAt(idx));
    }

    // Append any new exercises not in the saved order
    remaining.sort((a, b) {
      final g = a.group.index.compareTo(b.group.index);
      if (g != 0) return g;
      return a.name.compareTo(b.name);
    });
    ordered.addAll(remaining);

    return ordered;
  }

  void reorderExercises(List<String> order) {
    _exerciseOrder = order;
    StorageService.saveExerciseOrder(order);
  }

  // ── PR detection ──

  /// For each set in the workout, checks if its estimated 1RM
  /// exceeds the historical best for that exercise.
  Workout _detectPRs(Workout workout) {
    final updatedExercises = workout.exercises.map((entry) {
      final histBest = _historicalBest1RM(entry.exerciseName);

      // Track the running best so multiple sets in the same workout
      // can each be PRs if they keep improving
      double runningBest = histBest;

      final updatedSets = entry.sets.map((set) {
        final e1rm = set.estimated1RM;
        if (e1rm > runningBest && set.weight > 0 && set.reps > 0) {
          runningBest = e1rm;
          return set.copyWith(isPersonalRecord: true);
        }
        return set;
      }).toList();

      return entry.copyWith(sets: updatedSets);
    }).toList();

    return Workout(
      id: workout.id,
      date: workout.date,
      title: workout.title,
      duration: workout.duration,
      exercises: updatedExercises,
      notes: workout.notes,
    );
  }

  double _historicalBest1RM(String exerciseName) {
    double best = 0;
    for (final w in _workouts) {
      for (final ex in w.exercises) {
        if (ex.exerciseName == exerciseName) {
          for (final s in ex.sets) {
            if (s.estimated1RM > best) best = s.estimated1RM;
          }
        }
      }
    }
    return best;
  }

  /// Get the all-time best estimated 1RM for an exercise.
  double bestEstimated1RM(String exerciseName) =>
      _historicalBest1RM(exerciseName);

  /// Map of exercise name → best estimated 1RM across all workouts.
  Map<String, double> get allBest1RMs {
    final result = <String, double>{};
    for (final w in _workouts) {
      for (final ex in w.exercises) {
        final e1rm = ex.bestSet.estimated1RM;
        if ((result[ex.exerciseName] ?? 0) < e1rm) {
          result[ex.exerciseName] = e1rm;
        }
      }
    }
    return result;
  }

  /// Get the previous best set (by e1RM) for an exercise.
  WorkoutSet? previousBest(String exerciseName) {
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

  // ── Strength score ──

  List<StrengthDataPoint> strengthHistory({int months = 6}) {
    final cutoff = DateTime.now().subtract(Duration(days: months * 30));
    final filtered = _workouts.where((w) => w.date.isAfter(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final starred = starredExerciseNames;
    if (starred.isEmpty || filtered.isEmpty) return [];

    final Map<String, double> bestByLift = {};
    final List<StrengthDataPoint> points = [];

    for (final workout in filtered) {
      for (final ex in workout.exercises) {
        if (starred.contains(ex.exerciseName)) {
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

  /// History of a specific muscle group's score over time.
  List<StrengthDataPoint> muscleGroupHistory(MuscleGroup group,
      {int months = 6}) {
    final cutoff = DateTime.now().subtract(Duration(days: months * 30));
    final sorted = _workouts.where((w) => w.date.isAfter(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.isEmpty) return [];

    final Map<String, double> runningBest = {};
    final List<StrengthDataPoint> points = [];

    for (final workout in sorted) {
      bool touchedGroup = false;
      for (final ex in workout.exercises) {
        final info = getExerciseInfo(ex.exerciseName);
        if (info != null) {
          final est = ex.bestSet.estimated1RM;
          final prev = runningBest[ex.exerciseName] ?? 0;
          if (est > prev) runningBest[ex.exerciseName] = est;
          if (info.group == group) touchedGroup = true;
        }
      }
      if (touchedGroup) {
        final score = muscleGroupScore(group, runningBest);
        if (score > 0) {
          points.add(StrengthDataPoint(date: workout.date, score: score));
        }
      }
    }
    return points;
  }

  int get totalPRCount {
    int count = 0;
    for (final w in _workouts) {
      for (final ex in w.exercises) {
        count += ex.sets.where((s) => s.isPersonalRecord).length;
      }
    }
    return count;
  }

  int workoutsThisWeek() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _workouts.where((w) => w.date.isAfter(start)).length;
  }

  /// Summary stats for the current week.
  ({int exercises, int sets, int prs, int progressed}) weekSummary() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);

    final thisWeek = _workouts.where((w) => w.date.isAfter(start)).toList();
    final older = _workouts.where((w) => !w.date.isAfter(start)).toList();

    final exerciseNames = <String>{};
    int totalSets = 0;
    int totalPRs = 0;

    for (final w in thisWeek) {
      for (final ex in w.exercises) {
        exerciseNames.add(ex.exerciseName);
        totalSets += ex.sets.length;
        totalPRs += ex.sets.where((s) => s.isPersonalRecord).length;
      }
    }

    // Count exercises where this week's best e1RM > historical best before this week
    int progressed = 0;
    for (final name in exerciseNames) {
      double weekBest = 0;
      for (final w in thisWeek) {
        for (final ex in w.exercises) {
          if (ex.exerciseName == name) {
            final e = ex.bestSet.estimated1RM;
            if (e > weekBest) weekBest = e;
          }
        }
      }
      double histBest = 0;
      for (final w in older) {
        for (final ex in w.exercises) {
          if (ex.exerciseName == name) {
            final e = ex.bestSet.estimated1RM;
            if (e > histBest) histBest = e;
          }
        }
      }
      if (weekBest > histBest && histBest > 0) progressed++;
    }

    return (
      exercises: exerciseNames.length,
      sets: totalSets,
      prs: totalPRs,
      progressed: progressed,
    );
  }

  // ── Movement progression ──

  List<MovementProgress> movementProgress() {
    final starred = starredExerciseNames;
    final results = <MovementProgress>[];

    for (final lift in starred) {
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
      final previous =
          entries.length > 1 ? entries[entries.length - 2].value : current;

      final scores = entries.map((e) => e.value.estimated1RM).toList();

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
        recentScores:
            scores.length > 8 ? scores.sublist(scores.length - 8) : scores,
        changePerMonth: change,
      ));
    }

    return results;
  }
}

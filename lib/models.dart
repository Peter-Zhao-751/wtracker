class WorkoutSet {
  final double weight;
  final int reps;
  final bool isPersonalRecord;

  const WorkoutSet({
    required this.weight,
    required this.reps,
    this.isPersonalRecord = false,
  });

  double get volume => weight * reps;
  double get estimated1RM => weight * (1 + reps / 30.0);

  WorkoutSet copyWith({double? weight, int? reps, bool? isPersonalRecord}) {
    return WorkoutSet(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      isPersonalRecord: isPersonalRecord ?? this.isPersonalRecord,
    );
  }
}

class ExerciseEntry {
  final String exerciseName;
  final List<WorkoutSet> sets;

  const ExerciseEntry({
    required this.exerciseName,
    required this.sets,
  });

  double get totalVolume =>
      sets.fold(0.0, (sum, s) => sum + s.volume);

  WorkoutSet get bestSet =>
      sets.reduce((a, b) => a.estimated1RM > b.estimated1RM ? a : b);

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);

  ExerciseEntry copyWith({String? exerciseName, List<WorkoutSet>? sets}) {
    return ExerciseEntry(
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
    );
  }
}

class Workout {
  final String id;
  final DateTime date;
  final String title;
  final Duration duration;
  final List<ExerciseEntry> exercises;
  final String? notes;

  const Workout({
    required this.id,
    required this.date,
    required this.title,
    required this.duration,
    required this.exercises,
    this.notes,
  });

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.sets.length);

  double get totalVolume =>
      exercises.fold(0.0, (sum, e) => sum + e.totalVolume);

  int get exerciseCount => exercises.length;

  bool get hasPR =>
      exercises.any((e) => e.sets.any((s) => s.isPersonalRecord));

  List<String> get prExercises => exercises
      .where((e) => e.sets.any((s) => s.isPersonalRecord))
      .map((e) => e.exerciseName)
      .toList();

  String get durationFormatted {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class StrengthDataPoint {
  final DateTime date;
  final double score;
  final int workoutCount;

  const StrengthDataPoint({
    required this.date,
    required this.score,
    this.workoutCount = 1,
  });
}

class MovementProgress {
  final String name;
  final double currentBestWeight;
  final int currentBestReps;
  final double previousBestWeight;
  final int previousBestReps;
  final List<double> recentScores;
  final double changePerMonth;

  const MovementProgress({
    required this.name,
    required this.currentBestWeight,
    required this.currentBestReps,
    required this.previousBestWeight,
    required this.previousBestReps,
    required this.recentScores,
    required this.changePerMonth,
  });
}

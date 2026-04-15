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

  /// Epley formula: estimated 1-rep max
  double get estimated1RM => reps == 1 ? weight : weight * (1 + reps / 30.0);

  WorkoutSet copyWith({double? weight, int? reps, bool? isPersonalRecord}) {
    return WorkoutSet(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      isPersonalRecord: isPersonalRecord ?? this.isPersonalRecord,
    );
  }

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'reps': reps,
        'isPersonalRecord': isPersonalRecord,
      };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
        weight: (json['weight'] as num).toDouble(),
        reps: json['reps'] as int,
        isPersonalRecord: json['isPersonalRecord'] as bool? ?? false,
      );
}

class ExerciseEntry {
  final String exerciseName;
  final List<WorkoutSet> sets;

  const ExerciseEntry({
    required this.exerciseName,
    required this.sets,
  });

  double get totalVolume => sets.fold(0.0, (sum, s) => sum + s.volume);

  WorkoutSet get bestSet =>
      sets.reduce((a, b) => a.estimated1RM > b.estimated1RM ? a : b);

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);

  bool get hasPR => sets.any((s) => s.isPersonalRecord);

  ExerciseEntry copyWith({String? exerciseName, List<WorkoutSet>? sets}) {
    return ExerciseEntry(
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) => ExerciseEntry(
        exerciseName: json['exerciseName'] as String,
        sets: (json['sets'] as List)
            .map((s) => WorkoutSet.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
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

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets.length);

  double get totalVolume =>
      exercises.fold(0.0, (sum, e) => sum + e.totalVolume);

  int get exerciseCount => exercises.length;

  bool get hasPR => exercises.any((e) => e.hasPR);

  List<String> get prExercises => exercises
      .where((e) => e.hasPR)
      .map((e) => e.exerciseName)
      .toList();

  String get durationFormatted {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'durationMinutes': duration.inMinutes,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        title: json['title'] as String,
        duration: Duration(minutes: json['durationMinutes'] as int),
        exercises: (json['exercises'] as List)
            .map((e) => ExerciseEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: json['notes'] as String?,
      );
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

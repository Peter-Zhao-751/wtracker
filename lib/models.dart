class Exercise {
  final String name;
  final String group;
  final int sets;
  final String reps;
  final double w;
  const Exercise({
    required this.name,
    required this.group,
    required this.sets,
    required this.reps,
    required this.w,
  });

  Exercise copyWith({String? name, String? group, int? sets, String? reps, double? w}) =>
      Exercise(
        name: name ?? this.name,
        group: group ?? this.group,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        w: w ?? this.w,
      );
}

class Template {
  final String id;
  final String split;
  final String name;
  final String subtitle;
  final int est;
  final List<Exercise> exercises;
  const Template({
    required this.id,
    required this.split,
    required this.name,
    required this.subtitle,
    required this.est,
    required this.exercises,
  });

  Template copyWith({
    String? id,
    String? split,
    String? name,
    String? subtitle,
    int? est,
    List<Exercise>? exercises,
  }) {
    return Template(
      id: id ?? this.id,
      split: split ?? this.split,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      est: est ?? this.est,
      exercises: exercises ?? this.exercises,
    );
  }
}

class GroupStat {
  final String group;
  final String label;
  final int value;
  final int prev;
  final String delta;
  const GroupStat({
    required this.group,
    required this.label,
    required this.value,
    required this.prev,
    required this.delta,
  });
}

class PrRow {
  final String lift;
  final double w;
  final double prev;
  final int reps;
  final String date;
  const PrRow({required this.lift, required this.w, required this.prev, required this.reps, required this.date});
}

class SessionRow {
  final String date;
  final String day;
  final String name;
  final int dur;
  final double vol;
  final int sets;
  final bool pr;
  const SessionRow({
    required this.date,
    required this.day,
    required this.name,
    required this.dur,
    required this.vol,
    required this.sets,
    required this.pr,
  });
}

class SetLog {
  double w;
  int reps;
  bool done;
  bool isPR;
  SetLog({required this.w, required this.reps, this.done = false, this.isPR = false});
}

class LiveExercise {
  String name;
  String group;
  String reps;
  List<SetLog> log;
  LiveExercise({required this.name, required this.group, required this.reps, required this.log});
}

class LoggedSet {
  final String exerciseName;
  final String group;
  final double w;
  final int reps;
  final bool isPR;
  const LoggedSet({
    required this.exerciseName,
    required this.group,
    required this.w,
    required this.reps,
    required this.isPR,
  });

  factory LoggedSet.fromJson(Map j) => LoggedSet(
        exerciseName: j['name'] as String,
        group: j['group'] as String,
        w: (j['w'] as num).toDouble(),
        reps: j['reps'] as int,
        isPR: j['pr'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': exerciseName,
        'group': group,
        'w': w,
        'reps': reps,
        if (isPR) 'pr': true,
      };
}

class SessionRecord {
  final DateTime date;
  final String name;
  final String split;
  final int durSec;
  final List<LoggedSet> sets;
  const SessionRecord({
    required this.date,
    required this.name,
    required this.split,
    required this.durSec,
    required this.sets,
  });

  factory SessionRecord.fromJson(Map j) => SessionRecord(
        date: DateTime.parse(j['date'] as String),
        name: j['name'] as String,
        split: j['split'] as String,
        durSec: j['dur'] as int,
        sets: [
          for (final s in (j['sets'] as List))
            LoggedSet.fromJson(s as Map),
        ],
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'name': name,
        'split': split,
        'dur': durSec,
        'sets': [for (final s in sets) s.toJson()],
      };
}

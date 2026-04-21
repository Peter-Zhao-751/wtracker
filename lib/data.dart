import 'models.dart';

/// Canonical list of muscle groups the app tracks. Used for the tweaks panel
/// group-toggle grid and as the default set of radar axes.
const List<String> kGroupNames = [
  'CHEST', 'BACK', 'SHLDR', 'ARMS', 'LEGS', 'CORE',
  'NECK', 'CALVES', 'GLUTES', 'FOREARM', 'TRAPS', 'ABS',
];

/// Display label per group (only differs where the full name is too wide).
const Map<String, String> kGroupLabels = {
  'FOREARM': 'F.ARM',
};

String groupLabel(String g) => kGroupLabels[g] ?? g;

const List<Template> kTemplates = [
  Template(
    id: 'push-a', split: 'PPL', name: 'PUSH · A',
    subtitle: 'CHEST / SHOULDERS / TRI', est: 62,
    exercises: [
      Exercise(name: 'BENCH PRESS',      group: 'CHEST', sets: 4, reps: '5-6',   w: 185),
      Exercise(name: 'INCLINE DB PRESS', group: 'CHEST', sets: 3, reps: '8-10',  w: 70),
      Exercise(name: 'OHP',              group: 'SHLDR', sets: 4, reps: '6-8',   w: 115),
      Exercise(name: 'LATERAL RAISE',    group: 'SHLDR', sets: 3, reps: '12-15', w: 25),
      Exercise(name: 'CABLE FLY',        group: 'CHEST', sets: 3, reps: '12',    w: 40),
      Exercise(name: 'TRICEP PUSHDOWN',  group: 'ARMS',  sets: 3, reps: '10-12', w: 55),
    ],
  ),
  Template(
    id: 'pull-a', split: 'PPL', name: 'PULL · A',
    subtitle: 'BACK / BICEPS / REAR', est: 58,
    exercises: [
      Exercise(name: 'DEADLIFT',     group: 'BACK',  sets: 3, reps: '5',    w: 315),
      Exercise(name: 'PULL-UP',      group: 'BACK',  sets: 4, reps: '6-10', w: 0),
      Exercise(name: 'BARBELL ROW',  group: 'BACK',  sets: 3, reps: '8',    w: 155),
      Exercise(name: 'FACE PULL',    group: 'SHLDR', sets: 3, reps: '15',   w: 35),
      Exercise(name: 'BARBELL CURL', group: 'ARMS',  sets: 3, reps: '8-10', w: 75),
      Exercise(name: 'HAMMER CURL',  group: 'ARMS',  sets: 3, reps: '10',   w: 30),
    ],
  ),
  Template(
    id: 'legs-a', split: 'PPL', name: 'LEGS · A',
    subtitle: 'QUADS / HAMS / GLUTES', est: 70,
    exercises: [
      Exercise(name: 'BACK SQUAT',        group: 'LEGS', sets: 4, reps: '5',     w: 245),
      Exercise(name: 'RDL',               group: 'LEGS', sets: 3, reps: '8',     w: 205),
      Exercise(name: 'LEG PRESS',         group: 'LEGS', sets: 3, reps: '10-12', w: 360),
      Exercise(name: 'LEG CURL',          group: 'LEGS', sets: 3, reps: '12',    w: 110),
      Exercise(name: 'CALF RAISE',        group: 'LEGS', sets: 4, reps: '12-15', w: 180),
      Exercise(name: 'HANGING LEG RAISE', group: 'CORE', sets: 3, reps: '12',    w: 0),
    ],
  ),
  Template(
    id: 'upper', split: 'U/L', name: 'UPPER',
    subtitle: 'FULL UPPER BODY', est: 65,
    exercises: [
      Exercise(name: 'BENCH PRESS',   group: 'CHEST', sets: 4, reps: '6-8', w: 175),
      Exercise(name: 'BARBELL ROW',   group: 'BACK',  sets: 4, reps: '6-8', w: 155),
      Exercise(name: 'OHP',           group: 'SHLDR', sets: 3, reps: '8',   w: 110),
      Exercise(name: 'LAT PULLDOWN',  group: 'BACK',  sets: 3, reps: '10',  w: 140),
      Exercise(name: 'EZ-BAR CURL',   group: 'ARMS',  sets: 3, reps: '10',  w: 65),
      Exercise(name: 'SKULL CRUSHER', group: 'ARMS',  sets: 3, reps: '10',  w: 70),
    ],
  ),
  Template(
    id: 'lower', split: 'U/L', name: 'LOWER',
    subtitle: 'LEGS / CORE', est: 55,
    exercises: [
      Exercise(name: 'BACK SQUAT',    group: 'LEGS', sets: 4, reps: '6',     w: 235),
      Exercise(name: 'ROMANIAN DL',   group: 'LEGS', sets: 3, reps: '8',     w: 200),
      Exercise(name: 'WALKING LUNGE', group: 'LEGS', sets: 3, reps: '10 ea', w: 60),
      Exercise(name: 'CALF RAISE',    group: 'LEGS', sets: 4, reps: '12',    w: 180),
      Exercise(name: 'CABLE CRUNCH',  group: 'CORE', sets: 3, reps: '15',    w: 90),
    ],
  ),
  Template(
    id: 'fullbody', split: 'FB', name: 'FULL BODY',
    subtitle: 'COMPOUND FOCUS', est: 50,
    exercises: [
      Exercise(name: 'BACK SQUAT',   group: 'LEGS',  sets: 3, reps: '5',   w: 225),
      Exercise(name: 'BENCH PRESS',  group: 'CHEST', sets: 3, reps: '5',   w: 175),
      Exercise(name: 'BARBELL ROW',  group: 'BACK',  sets: 3, reps: '5',   w: 155),
      Exercise(name: 'OHP',          group: 'SHLDR', sets: 3, reps: '5',   w: 110),
      Exercise(name: 'PLANK',        group: 'CORE',  sets: 3, reps: '60s', w: 0),
    ],
  ),
  Template(
    id: 'chest-day', split: 'BRO', name: 'CHEST DAY',
    subtitle: 'PECS / TRI', est: 55,
    exercises: [
      Exercise(name: 'BENCH PRESS',   group: 'CHEST', sets: 4, reps: '6-8', w: 185),
      Exercise(name: 'INCLINE BENCH', group: 'CHEST', sets: 3, reps: '8',   w: 155),
      Exercise(name: 'DB FLY',        group: 'CHEST', sets: 3, reps: '12',  w: 35),
      Exercise(name: 'DIPS',          group: 'CHEST', sets: 3, reps: '10',  w: 25),
      Exercise(name: 'CABLE FLY',     group: 'CHEST', sets: 3, reps: '15',  w: 35),
    ],
  ),
  Template(
    id: 'back-day', split: 'BRO', name: 'BACK DAY',
    subtitle: 'LATS / MID-BACK', est: 60,
    exercises: [
      Exercise(name: 'DEADLIFT',     group: 'BACK', sets: 3, reps: '5',  w: 315),
      Exercise(name: 'PULL-UP',      group: 'BACK', sets: 4, reps: '8',  w: 0),
      Exercise(name: 'T-BAR ROW',    group: 'BACK', sets: 3, reps: '8',  w: 135),
      Exercise(name: 'LAT PULLDOWN', group: 'BACK', sets: 3, reps: '10', w: 140),
      Exercise(name: 'CABLE ROW',    group: 'BACK', sets: 3, reps: '12', w: 130),
    ],
  ),
  Template(
    id: 'shoulder-day', split: 'BRO', name: 'SHOULDER DAY',
    subtitle: 'DELTS ALL 3 HEADS', est: 50,
    exercises: [
      Exercise(name: 'OHP',           group: 'SHLDR', sets: 4, reps: '6-8', w: 115),
      Exercise(name: 'LATERAL RAISE', group: 'SHLDR', sets: 4, reps: '12',  w: 25),
      Exercise(name: 'REAR DELT FLY', group: 'SHLDR', sets: 3, reps: '15',  w: 20),
      Exercise(name: 'FACE PULL',     group: 'SHLDR', sets: 3, reps: '15',  w: 35),
      Exercise(name: 'SHRUG',         group: 'SHLDR', sets: 3, reps: '12',  w: 90),
    ],
  ),
  Template(
    id: 'leg-day', split: 'BRO', name: 'LEG DAY',
    subtitle: 'QUAD DOMINANT', est: 65,
    exercises: [
      Exercise(name: 'BACK SQUAT',    group: 'LEGS', sets: 5, reps: '5',  w: 245),
      Exercise(name: 'LEG PRESS',     group: 'LEGS', sets: 4, reps: '10', w: 380),
      Exercise(name: 'LEG EXTENSION', group: 'LEGS', sets: 3, reps: '12', w: 120),
      Exercise(name: 'LEG CURL',      group: 'LEGS', sets: 3, reps: '12', w: 110),
      Exercise(name: 'CALF RAISE',    group: 'LEGS', sets: 4, reps: '15', w: 180),
    ],
  ),
  Template(
    id: 'arm-day', split: 'BRO', name: 'ARM DAY',
    subtitle: 'BIS / TRIS', est: 45,
    exercises: [
      Exercise(name: 'EZ-BAR CURL',      group: 'ARMS', sets: 4, reps: '8',  w: 70),
      Exercise(name: 'CLOSE-GRIP BENCH', group: 'ARMS', sets: 4, reps: '8',  w: 155),
      Exercise(name: 'HAMMER CURL',      group: 'ARMS', sets: 3, reps: '10', w: 30),
      Exercise(name: 'OVERHEAD EXT',     group: 'ARMS', sets: 3, reps: '10', w: 55),
      Exercise(name: 'CABLE CURL',       group: 'ARMS', sets: 3, reps: '12', w: 45),
      Exercise(name: 'ROPE PUSHDOWN',    group: 'ARMS', sets: 3, reps: '12', w: 50),
    ],
  ),
];

List<Map<String, dynamic>> get kExercisePool {
  final seen = <String, Map<String, dynamic>>{};
  for (final t in kTemplates) {
    for (final e in t.exercises) {
      seen.putIfAbsent(e.name, () => {
        'name': e.name, 'group': e.group, 'w': e.w, 'reps': e.reps,
      });
    }
  }
  final list = seen.values.toList();
  list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  return list;
}

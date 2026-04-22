import '../core/models.dart';
import '../core/strength_standards.dart';

/// Epley estimated 1-rep max. Reps clamped at 12 because Epley degrades for
/// high-rep sets — we don't want a 135x20 to project a 225 lb 1RM. Returns 0
/// for non-positive weight or reps.
double estimate1RM(double w, int reps) {
  if (w <= 0 || reps <= 0) return 0;
  final r = reps > 12 ? 12 : reps;
  return w * (1 + r / 30.0);
}

/// Score a lift's estimated 1RM on the 0-100 scale using its derived anchor
/// curve. Returns null for exercises not in [kLiftStandards] so callers can
/// decide whether to skip them (see [groupScore]). Scores clamp at 0 / 100.
int? scoreLift(String exerciseName, double oneRm) {
  final std = kLiftStandards[exerciseName];
  if (std == null) return null;
  if (oneRm <= 0) return 0;
  final anchors = deriveAnchors(std.a75, std.a95);
  if (oneRm >= anchors.last.w) return 100;
  for (int i = 1; i < anchors.length; i++) {
    final lo = anchors[i - 1];
    final hi = anchors[i];
    if (oneRm <= hi.w) {
      final t = (oneRm - lo.w) / (hi.w - lo.w);
      final raw = lo.score + t * (hi.score - lo.score);
      return raw.round().clamp(0, 100);
    }
  }
  return 100;
}

/// Compute the 0-100 muscle-group score for [group] using sessions that fall
/// inside the 4-week (by default) window ending at [windowEnd].
///
/// Algorithm:
/// 1. Per exercise in the window, take the best Epley 1RM across all logged
///    sets of that exercise.
/// 2. Map each to a 0-100 score via [scoreLift]; drop unknown exercises and
///    bodyweight-only sets (w <= 0).
/// 3. Weight each score by 2.0 for compounds, 1.0 for isolation.
/// 4. Sort by `score * weight` desc, take top 3.
/// 5. Return the weighted average, rounded and clamped to 0-100.
int groupScore(
  List<SessionRecord> sessions,
  String group, {
  required DateTime windowEnd,
  int windowWeeks = 4,
}) {
  final windowStart = windowEnd.subtract(Duration(days: 7 * windowWeeks));
  final best1RM = <String, double>{};

  for (final s in sessions) {
    if (s.date.isBefore(windowStart) || s.date.isAfter(windowEnd)) continue;
    for (final set in s.sets) {
      if (set.group != group) continue;
      if (set.w <= 0) continue;
      final oneRm = estimate1RM(set.w, set.reps);
      final cur = best1RM[set.exerciseName] ?? 0;
      if (oneRm > cur) best1RM[set.exerciseName] = oneRm;
    }
  }

  final scored = <_ScoredLift>[];
  best1RM.forEach((name, oneRm) {
    final score = scoreLift(name, oneRm);
    if (score == null) return;
    final std = kLiftStandards[name]!;
    scored.add(_ScoredLift(score, std.isCompound ? 2.0 : 1.0));
  });

  if (scored.isEmpty) return 0;

  scored.sort((a, b) => (b.score * b.weight).compareTo(a.score * a.weight));
  final top = scored.take(3);

  double numer = 0;
  double denom = 0;
  for (final e in top) {
    numer += e.score * e.weight;
    denom += e.weight;
  }
  return (numer / denom).round().clamp(0, 100);
}

class _ScoredLift {
  final int score;
  final double weight;
  const _ScoredLift(this.score, this.weight);
}

/// Score for [group] at each of the trailing [weeks] weeks, oldest first,
/// using a rolling 4-week trailing window at each point. The last element
/// corresponds to "current" and will match [groupScore] called with the same
/// [now] as windowEnd. [now] defaults to DateTime.now(); overridable for tests.
List<int> weeklyGroupScores(
  List<SessionRecord> sessions,
  String group, {
  required int weeks,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final thisWeekStart = _weekStart(n);
  final out = <int>[];
  for (int i = 0; i < weeks; i++) {
    final weeksBack = weeks - 1 - i;
    final weekEnd = thisWeekStart
        .add(const Duration(days: 7))
        .subtract(Duration(days: weeksBack * 7));
    out.add(groupScore(sessions, group, windowEnd: weekEnd, windowWeeks: 4));
  }
  return out;
}

/// Monday-based start-of-week for [d]. Mirrors the convention in history.dart.
DateTime _weekStart(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

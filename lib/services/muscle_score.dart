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

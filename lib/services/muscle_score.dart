/// Epley estimated 1-rep max. Reps clamped at 12 because Epley degrades for
/// high-rep sets — we don't want a 135x20 to project a 225 lb 1RM. Returns 0
/// for non-positive weight or reps.
double estimate1RM(double w, int reps) {
  if (w <= 0 || reps <= 0) return 0;
  final r = reps > 12 ? 12 : reps;
  return w * (1 + r / 30.0);
}

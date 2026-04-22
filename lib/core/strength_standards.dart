/// Per-lift strength anchor. A full 0-100 score curve is derived from just two
/// anchor weights: the 1RM that should score 75 and the 1RM that should score
/// 95. See [deriveAnchors] for the full curve shape.
class LiftStandard {
  final double a75;
  final double a95;
  final bool isCompound;
  const LiftStandard({
    required this.a75,
    required this.a95,
    required this.isCompound,
  });
}

/// Single point on a piecewise-linear 1RM-to-score curve.
class StrengthAnchor {
  final double w;
  final int score;
  const StrengthAnchor(this.w, this.score);
}

/// Derive the full 9-point piecewise-linear score curve from a lift's
/// (a75, a95) pair. The shape is tuned so that ~60% of the lift's terminal
/// weight gets you 75% of the score, and the final 5 points require 45%+
/// more weight on top of a95. See the design spec for the math.
List<StrengthAnchor> deriveAnchors(double a75, double a95) {
  final d = a95 - a75;
  return [
    StrengthAnchor(0, 0),
    StrengthAnchor(a75 * 0.42, 25),
    StrengthAnchor(a75 * 0.60, 40),
    StrengthAnchor(a75 * 0.82, 60),
    StrengthAnchor(a75, 75),
    StrengthAnchor(a75 + d * 0.55, 85),
    StrengthAnchor(a95, 95),
    StrengthAnchor(a95 + d * 0.55, 98),
    StrengthAnchor(a95 + d * 1.00, 100),
  ];
}

const Map<String, LiftStandard> kLiftStandards = {
  // ─── Compounds ──────────────────────────────────────────────────
  'BENCH PRESS':       LiftStandard(a75: 225, a95: 315, isCompound: true),
  'INCLINE BENCH':     LiftStandard(a75: 190, a95: 265, isCompound: true),
  'INCLINE DB PRESS':  LiftStandard(a75: 190, a95: 265, isCompound: true),
  'CLOSE-GRIP BENCH':  LiftStandard(a75: 190, a95: 265, isCompound: true),
  'OHP':               LiftStandard(a75: 150, a95: 205, isCompound: true),
  'BARBELL ROW':       LiftStandard(a75: 180, a95: 250, isCompound: true),
  'T-BAR ROW':         LiftStandard(a75: 180, a95: 250, isCompound: true),
  'BACK SQUAT':        LiftStandard(a75: 295, a95: 410, isCompound: true),
  'RDL':               LiftStandard(a75: 270, a95: 380, isCompound: true),
  'ROMANIAN DL':       LiftStandard(a75: 270, a95: 380, isCompound: true),
  'DEADLIFT':          LiftStandard(a75: 335, a95: 470, isCompound: true),
  'LEG PRESS':         LiftStandard(a75: 475, a95: 650, isCompound: true),

  // ─── Isolation / accessory ──────────────────────────────────────
  'LAT PULLDOWN':      LiftStandard(a75: 155, a95: 220, isCompound: false),
  'CABLE ROW':         LiftStandard(a75: 155, a95: 220, isCompound: false),
  'LEG CURL':          LiftStandard(a75: 135, a95: 180, isCompound: false),
  'LEG EXTENSION':     LiftStandard(a75: 150, a95: 200, isCompound: false),
  'CALF RAISE':        LiftStandard(a75: 300, a95: 420, isCompound: false),
  'LATERAL RAISE':     LiftStandard(a75:  30, a95:  50, isCompound: false),
  'REAR DELT FLY':     LiftStandard(a75:  25, a95:  45, isCompound: false),
  'FACE PULL':         LiftStandard(a75:  50, a95:  75, isCompound: false),
  'SHRUG':             LiftStandard(a75: 225, a95: 315, isCompound: false),
  'DB FLY':            LiftStandard(a75:  50, a95:  75, isCompound: false),
  'CABLE FLY':         LiftStandard(a75:  60, a95:  90, isCompound: false),
  'BARBELL CURL':      LiftStandard(a75: 110, a95: 145, isCompound: false),
  'EZ-BAR CURL':       LiftStandard(a75: 110, a95: 145, isCompound: false),
  'HAMMER CURL':       LiftStandard(a75:  45, a95:  65, isCompound: false),
  'CABLE CURL':        LiftStandard(a75:  70, a95: 100, isCompound: false),
  'TRICEP PUSHDOWN':   LiftStandard(a75:  85, a95: 115, isCompound: false),
  'ROPE PUSHDOWN':     LiftStandard(a75:  85, a95: 115, isCompound: false),
  'SKULL CRUSHER':     LiftStandard(a75: 105, a95: 140, isCompound: false),
  'OVERHEAD EXT':      LiftStandard(a75:  80, a95: 110, isCompound: false),
  'CABLE CRUNCH':      LiftStandard(a75: 150, a95: 200, isCompound: false),
  'WALKING LUNGE':     LiftStandard(a75:  90, a95: 130, isCompound: false),
};

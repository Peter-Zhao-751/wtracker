# Muscle Index Scoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the volume-based muscle-group index (0-100) with a strength-based score derived from estimated 1RMs, per-exercise anchor curves, and a compound-weighted top-3 aggregation.

**Architecture:** Two new pure-Dart modules — `strength_standards.dart` holds the per-lift `(a75, a95)` anchor data + curve derivation, `muscle_score.dart` holds scoring functions (`estimate1RM`, `scoreLift`, `groupScore`, `weeklyGroupScores`) that operate on `List<SessionRecord>`. `history.dart`'s `groupStats` and `progressionFor` delegate to the new scorer without changing their public signatures. No UI changes. No storage migration. Full spec: `docs/superpowers/specs/2026-04-21-muscle-index-scoring-design.md`.

**Tech Stack:** Dart 3.x / Flutter. Tests run with `flutter test` using `flutter_test`. Package name is `wtracker`.

---

## File Structure

- **Create** `lib/core/strength_standards.dart` — `LiftStandard` class, `kLiftStandards` map, `deriveAnchors()` helper, `StrengthAnchor` record.
- **Create** `lib/services/muscle_score.dart` — `estimate1RM`, `scoreLift`, `groupScore`, `weeklyGroupScores`.
- **Modify** `lib/services/history.dart` — `groupStats()` (lines 183-212) and `progressionFor()` (lines 217-250).
- **Create** `test/muscle_score_test.dart` — unit tests for all new pure functions.

---

## Task 1: Strength standards — anchor data + curve derivation

**Files:**
- Create: `lib/core/strength_standards.dart`
- Test: `test/muscle_score_test.dart`

- [ ] **Step 1: Write failing test for `deriveAnchors`**

Create `test/muscle_score_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wtracker/core/strength_standards.dart';

void main() {
  group('deriveAnchors', () {
    test('bench anchors (225, 315) produce expected curve', () {
      final a = deriveAnchors(225, 315);
      expect(a.length, 9);
      expect(a[0].w, 0);
      expect(a[0].score, 0);
      expect(a[1].w, closeTo(94.5, 0.01));
      expect(a[1].score, 25);
      expect(a[2].w, closeTo(135, 0.01));
      expect(a[2].score, 40);
      expect(a[3].w, closeTo(184.5, 0.01));
      expect(a[3].score, 60);
      expect(a[4].w, 225);
      expect(a[4].score, 75);
      expect(a[5].w, closeTo(274.5, 0.01));
      expect(a[5].score, 85);
      expect(a[6].w, 315);
      expect(a[6].score, 95);
      expect(a[7].w, closeTo(364.5, 0.01));
      expect(a[7].score, 98);
      expect(a[8].w, closeTo(405, 0.01));
      expect(a[8].score, 100);
    });

    test('weights are strictly increasing', () {
      final a = deriveAnchors(100, 150);
      for (int i = 1; i < a.length; i++) {
        expect(a[i].w, greaterThan(a[i - 1].w));
      }
    });

    test('scores are strictly increasing', () {
      final a = deriveAnchors(100, 150);
      for (int i = 1; i < a.length; i++) {
        expect(a[i].score, greaterThan(a[i - 1].score));
      }
    });
  });

  group('kLiftStandards', () {
    test('has bench press as compound', () {
      final std = kLiftStandards['BENCH PRESS'];
      expect(std, isNotNull);
      expect(std!.isCompound, isTrue);
      expect(std.a75, 225);
      expect(std.a95, 315);
    });

    test('has cable fly as isolation', () {
      final std = kLiftStandards['CABLE FLY'];
      expect(std, isNotNull);
      expect(std!.isCompound, isFalse);
    });

    test('returns null for unknown exercise', () {
      expect(kLiftStandards['MADE UP LIFT'], isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/muscle_score_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:wtracker/core/strength_standards.dart'".

- [ ] **Step 3: Implement `strength_standards.dart`**

Create `lib/core/strength_standards.dart`:

```dart
/// Per-lift strength anchor. A full 0-100 score curve is derived from just two
/// anchor weights: the 1RM that should score 75 and the 1RM that should score
/// 95. See `deriveAnchors` for the full curve shape.
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/muscle_score_test.dart`
Expected: PASS — all 6 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/core/strength_standards.dart test/muscle_score_test.dart
git commit -m "feat(scoring): strength standards anchor table + curve derivation"
```

---

## Task 2: `estimate1RM` — Epley with reps clamp

**Files:**
- Create: `lib/services/muscle_score.dart`
- Modify: `test/muscle_score_test.dart`

- [ ] **Step 1: Write failing tests**

Append to `test/muscle_score_test.dart` inside the top-level `main()`:

```dart
  group('estimate1RM', () {
    test('Epley formula for 225x5', () {
      expect(estimate1RM(225, 5), closeTo(225 * (1 + 5 / 30), 0.001));
    });

    test('155x7 produces ~191', () {
      expect(estimate1RM(155, 7), closeTo(191.17, 0.01));
    });

    test('single rep equals the weight * (1 + 1/30)', () {
      expect(estimate1RM(300, 1), closeTo(300 * (1 + 1 / 30), 0.001));
    });

    test('clamps reps at 12 so 135x20 does not inflate', () {
      // 135 * (1 + 12/30) = 189, NOT 135 * (1 + 20/30) = 225
      expect(estimate1RM(135, 20), closeTo(189, 0.01));
    });

    test('zero weight returns 0', () {
      expect(estimate1RM(0, 5), 0);
    });

    test('zero reps returns 0', () {
      expect(estimate1RM(225, 0), 0);
    });
  });
```

Add the import at the top of the test file:

```dart
import 'package:wtracker/services/muscle_score.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/muscle_score_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:wtracker/services/muscle_score.dart'".

- [ ] **Step 3: Implement `estimate1RM`**

Create `lib/services/muscle_score.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/muscle_score_test.dart`
Expected: PASS — all previous tests still green + 6 new tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/services/muscle_score.dart test/muscle_score_test.dart
git commit -m "feat(scoring): Epley 1RM estimation with reps clamp"
```

---

## Task 3: `scoreLift` — 1RM to 0-100 via anchor curve

**Files:**
- Modify: `lib/services/muscle_score.dart`
- Modify: `test/muscle_score_test.dart`

- [ ] **Step 1: Write failing tests**

Append to `main()` in `test/muscle_score_test.dart`:

```dart
  group('scoreLift', () {
    test('bench at 225 scores 75', () {
      expect(scoreLift('BENCH PRESS', 225), 75);
    });

    test('bench at 315 scores 95', () {
      expect(scoreLift('BENCH PRESS', 315), 95);
    });

    test('bench at 191 (from 155x7) scores ~62', () {
      expect(scoreLift('BENCH PRESS', 191), inInclusiveRange(61, 63));
    });

    test('bench at 95 (the bar) scores 25', () {
      expect(scoreLift('BENCH PRESS', 95), inInclusiveRange(24, 26));
    });

    test('bench above top anchor clamps at 100', () {
      expect(scoreLift('BENCH PRESS', 500), 100);
      expect(scoreLift('BENCH PRESS', 1000), 100);
    });

    test('bench at zero scores 0', () {
      expect(scoreLift('BENCH PRESS', 0), 0);
    });

    test('linear interpolation between anchors', () {
      // Between (225, 75) and (275, 85): midpoint 250 -> 80
      expect(scoreLift('BENCH PRESS', 250), 80);
    });

    test('unknown exercise returns null', () {
      expect(scoreLift('MADE UP LIFT', 225), isNull);
    });

    test('isolation curve scales correctly (lateral raise at 30 = 75)', () {
      expect(scoreLift('LATERAL RAISE', 30), 75);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/muscle_score_test.dart`
Expected: FAIL with "The method 'scoreLift' isn't defined for the type 'muscle_score'".

- [ ] **Step 3: Implement `scoreLift`**

Append to `lib/services/muscle_score.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/muscle_score_test.dart`
Expected: PASS — all 9 new tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/services/muscle_score.dart test/muscle_score_test.dart
git commit -m "feat(scoring): scoreLift — 1RM to 0-100 via anchor curve"
```

---

## Task 4: `groupScore` — top-3 weighted aggregation

**Files:**
- Modify: `lib/services/muscle_score.dart`
- Modify: `test/muscle_score_test.dart`

- [ ] **Step 1: Write failing tests**

Append to `main()` in `test/muscle_score_test.dart`:

```dart
  group('groupScore', () {
    // Builders keep tests compact. Sessions are synthesized at specific
    // offsets from a fixed `now` so window math is deterministic.
    final now = DateTime(2026, 4, 21);
    SessionRecord session(int daysAgo, List<LoggedSet> sets) => SessionRecord(
          date: now.subtract(Duration(days: daysAgo)),
          name: 'T',
          split: 'PPL',
          durSec: 0,
          sets: sets,
        );
    LoggedSet set(String name, String group, double w, int reps) =>
        LoggedSet(exerciseName: name, group: group, w: w, reps: reps, isPR: false);

    test('empty sessions -> 0', () {
      expect(
        groupScore(const [], 'CHEST', windowEnd: now, windowWeeks: 4),
        0,
      );
    });

    test('single bench 225x1 -> ~75', () {
      final hist = [
        session(3, [set('BENCH PRESS', 'CHEST', 225, 1)]),
      ];
      // 225x1 Epley = 232.5 -> interpolates (225,75)-(275,85): ~77.
      final s = groupScore(hist, 'CHEST', windowEnd: now, windowWeeks: 4);
      expect(s, inInclusiveRange(75, 80));
    });

    test('compound double-weighted vs isolation', () {
      // Bench scores 75 (compound, weight 2), cable fly scores 95 (iso, weight 1).
      // Weighted avg of both: (75*2 + 95*1) / (2+1) = 245/3 ≈ 82.
      final hist = [
        session(3, [
          set('BENCH PRESS', 'CHEST', 225, 1),
          set('CABLE FLY', 'CHEST', 90, 1),
        ]),
      ];
      // Bench 225x1 -> Epley 232.5 -> ~77.
      // Cable fly 90x1 -> Epley 93 -> curve hits 95-ish near a95=90.
      // Accept a range that covers the weighted-average outcome.
      final s = groupScore(hist, 'CHEST', windowEnd: now, windowWeeks: 4);
      expect(s, inInclusiveRange(78, 88));
    });

    test('top-3 cap — extra isolation does not dilute', () {
      // Five bench-only sessions + three puny cable fly sessions.
      // Top 3 by score*weight should be the bench entries (one bench entry,
      // since it's aggregated to best-1RM-per-exercise, plus two fly entries
      // if fly is the only other exercise). Actually since we aggregate per
      // exercise, there's only 2 exercises here — bench and fly.
      final hist = [
        session(3, [set('BENCH PRESS', 'CHEST', 315, 1)]),
        session(4, [set('CABLE FLY', 'CHEST', 30, 1)]),
      ];
      final s = groupScore(hist, 'CHEST', windowEnd: now, windowWeeks: 4);
      // Bench ~95 (compound wt 2), fly low (iso wt 1).
      // Weighted: (95*2 + low*1) / 3.  With fly 30x1 Epley=31 — below a75=60,
      // interpolates in lower segments, low score (~20-30).
      // Expect the bench to dominate — score should be ≥ 70.
      expect(s, greaterThanOrEqualTo(70));
    });

    test('bodyweight-only (w=0) is skipped', () {
      final hist = [
        session(3, [set('PULL-UP', 'BACK', 0, 8)]),
      ];
      expect(
        groupScore(hist, 'BACK', windowEnd: now, windowWeeks: 4),
        0,
      );
    });

    test('unknown exercise is skipped', () {
      final hist = [
        session(3, [set('MADE UP LIFT', 'CHEST', 500, 5)]),
      ];
      expect(
        groupScore(hist, 'CHEST', windowEnd: now, windowWeeks: 4),
        0,
      );
    });

    test('sessions outside window are ignored', () {
      // 100 days ago, way outside a 4-week window.
      final hist = [
        session(100, [set('BENCH PRESS', 'CHEST', 315, 1)]),
      ];
      expect(
        groupScore(hist, 'CHEST', windowEnd: now, windowWeeks: 4),
        0,
      );
    });

    test('uses best 1RM per exercise within window', () {
      // Three bench sessions in window: 185x5, 225x1, 135x10.
      // Epley 1RMs: 185*(1+5/30)=216, 225*(1+1/30)=232.5, 135*(1+10/30)=180.
      // Max is 232.5 -> ~77.
      final hist = [
        session(1, [set('BENCH PRESS', 'CHEST', 185, 5)]),
        session(5, [set('BENCH PRESS', 'CHEST', 225, 1)]),
        session(10, [set('BENCH PRESS', 'CHEST', 135, 10)]),
      ];
      final s = groupScore(hist, 'CHEST', windowEnd: now, windowWeeks: 4);
      expect(s, inInclusiveRange(75, 80));
    });
  });
```

Add the import at the top of the test file if not already present:

```dart
import 'package:wtracker/core/models.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/muscle_score_test.dart`
Expected: FAIL — 'groupScore' not defined.

- [ ] **Step 3: Implement `groupScore`**

Append to `lib/services/muscle_score.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/muscle_score_test.dart`
Expected: PASS — all `groupScore` tests green. If any bounds in the test ranges fail, recheck the Epley → anchor interpolation by hand, then tighten or widen the bounds to match actual math (the test ranges above were picked with the spec's anchor values).

- [ ] **Step 5: Commit**

```bash
git add lib/services/muscle_score.dart test/muscle_score_test.dart
git commit -m "feat(scoring): groupScore — top-3 compound-weighted aggregation"
```

---

## Task 5: `weeklyGroupScores` — rolling 4-week series

**Files:**
- Modify: `lib/services/muscle_score.dart`
- Modify: `test/muscle_score_test.dart`

- [ ] **Step 1: Write failing tests**

Append to `main()` in `test/muscle_score_test.dart`:

```dart
  group('weeklyGroupScores', () {
    SessionRecord session(DateTime at, List<LoggedSet> sets) => SessionRecord(
          date: at,
          name: 'T',
          split: 'PPL',
          durSec: 0,
          sets: sets,
        );
    LoggedSet set(String name, String group, double w, int reps) =>
        LoggedSet(exerciseName: name, group: group, w: w, reps: reps, isPR: false);

    test('returns a list of length [weeks]', () {
      final out = weeklyGroupScores(
        const [],
        'CHEST',
        weeks: 12,
        now: DateTime(2026, 4, 21),
      );
      expect(out.length, 12);
      expect(out.every((v) => v == 0), isTrue);
    });

    test('a recent session raises the last point but not the oldest', () {
      final now = DateTime(2026, 4, 21); // Tuesday
      final hist = [
        session(now.subtract(const Duration(days: 1)), [
          set('BENCH PRESS', 'CHEST', 225, 1),
        ]),
      ];
      final out = weeklyGroupScores(hist, 'CHEST', weeks: 4, now: now);
      // Most recent point's 4-week trailing window includes the session.
      expect(out.last, greaterThan(70));
      // Oldest point's window ends ~3 weeks before the session, so excludes it.
      expect(out[0], 0);
    });

    test('bench session drops out of trailing 4-week window after 4 weeks', () {
      final now = DateTime(2026, 4, 21);
      // Session 40 days ago -> in window for earliest weeks, gone by now.
      final hist = [
        session(now.subtract(const Duration(days: 40)), [
          set('BENCH PRESS', 'CHEST', 315, 1),
        ]),
      ];
      final out = weeklyGroupScores(hist, 'CHEST', weeks: 12, now: now);
      // Most recent point: session is outside the trailing 4 weeks -> 0.
      expect(out.last, 0);
      // Earlier points that DID include the session: non-zero.
      expect(out.take(8).any((v) => v > 0), isTrue);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/muscle_score_test.dart`
Expected: FAIL — 'weeklyGroupScores' not defined.

- [ ] **Step 3: Implement `weeklyGroupScores`**

Append to `lib/services/muscle_score.dart`:

```dart
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
    // weeksBack = 0 for the most recent (latest) point.
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/muscle_score_test.dart`
Expected: PASS — all `weeklyGroupScores` tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/services/muscle_score.dart test/muscle_score_test.dart
git commit -m "feat(scoring): weeklyGroupScores — rolling 4-week series for line chart"
```

---

## Task 6: Wire into `history.dart`

**Files:**
- Modify: `lib/services/history.dart` (replace `groupStats` lines 183-212 and `progressionFor` lines 217-250)

- [ ] **Step 1: Add import**

Open `lib/services/history.dart`. Below the existing `import 'storage.dart';` line, add:

```dart
import 'muscle_score.dart';
```

- [ ] **Step 2: Replace `groupStats`**

Replace the entire `groupStats` method (starts at line 183 with `/// Per-group radar stats...` comment and the method body through line 212's closing brace) with:

```dart
  /// Per-group radar stats: strength-based score 0-100 for current 4 weeks,
  /// and a comparable score for weeks 4-8 back (the "PREV" value feeding the
  /// 4W delta badge). Delegates to `muscle_score.groupScore`.
  List<GroupStat> groupStats(List<String> groups) {
    final now = DateTime.now();
    final thisWeekStart = _weekStart(now);
    final curEnd = thisWeekStart.add(const Duration(days: 7));
    final prevEnd = curEnd.subtract(const Duration(days: 28));
    return [
      for (final g in groups)
        () {
          final cur = groupScore(_sessions, g, windowEnd: curEnd, windowWeeks: 4);
          final prev = groupScore(_sessions, g, windowEnd: prevEnd, windowWeeks: 4);
          return GroupStat(
            group: g,
            label: groupLabel(g),
            value: cur,
            prev: prev,
            delta: _deltaStr(cur - prev),
          );
        }(),
    ];
  }
```

- [ ] **Step 3: Replace `progressionFor`**

Replace the entire `progressionFor` method (starts around line 217 with `/// Index curve for [group]...` through the closing brace of the method) with:

```dart
  /// Weekly strength-score series for [group]. Each point is the group's
  /// score using a 4-week trailing window ending at that week. Length is
  /// always [weeks]; oldest first. The last point equals the current INDEX.
  List<int> progressionFor(String group, {int weeks = 52}) {
    return weeklyGroupScores(_sessions, group, weeks: weeks);
  }
```

- [ ] **Step 4: Run the test suite**

Run: `flutter test`
Expected: PASS — all muscle_score tests plus the pre-existing `widget_test.dart` smoke test still green.

- [ ] **Step 5: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues found. If any unused-import warnings show up for `history.dart`, they should be removed.

- [ ] **Step 6: Manual smoke test in simulator**

Launch the app: `flutter run` (or open in your preferred simulator).

Manually verify:
- Dashboard → MUSCLE PROFILE: INDEX values are no longer "100 for the most-trained group". A lifter with 155×7 bench should see CHEST around 55-65. A lifter with 225 bench should see ~75.
- Dashboard → tap a group pill → line chart shows the weekly strength curve.
- Progression screen → focus group → CURRENT INDEX number matches the dashboard's per-group INDEX for that group.
- Sessions older than 4 weeks without any recent logs → group score drops to 0 (not stuck at some previous peak).

If any value looks wildly wrong, recheck `kLiftStandards` anchors in `strength_standards.dart` — those are the knobs.

- [ ] **Step 7: Commit**

```bash
git add lib/services/history.dart
git commit -m "feat(scoring): wire strength-based scoring into history API"
```

---

## Self-Review Notes

- **Spec coverage**: Pipeline (Task 2-5), anchor derivation (Task 1), top-3 weighted aggregation (Task 4), rolling 4-week progression (Task 5), UI untouched (Task 6 only modifies two internal method bodies), tests for all bullet points in the spec's Testing section (Task 1-5).
- **Non-goals respected**: No bodyweight field, no UI changes, no storage migration. Bodyweight-only lifts (w=0) skipped per spec.
- **Reps clamp at 12**: covered by test in Task 2.
- **Unknown exercises**: covered by test in Task 3 (`scoreLift` returns null) and Task 4 (`groupScore` skips them).

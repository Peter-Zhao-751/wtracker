# Muscle Index Scoring Redesign

## Problem

The current "muscle index" (0-100 per group) on the dashboard and progression
screens is computed from total training **volume** (`weight × reps` summed
over 4 weeks), normalized so the group with the most volume = 100. This is a
share-of-training metric pretending to be a strength metric:

- A user benching 155×7 shows **CHEST = 100** because chest is whatever group
  they happen to train most. A beginner who trains only chest hits 100 instantly;
  someone who actually benches 315 gets the same number.
- The index can't be compared across users or against any external standard.
- It rewards volume churn, not progression.

## Goal

Make the index reflect **estimated strength** on each muscle group, with the
property that *scaling gets harder the stronger you get*. Anchor values:
`225 bench ≈ 75`, `315 bench ≈ 95`. A `155×7` session (~191 lb est-1RM) should
land around **62**, not 100.

## Design

### Pipeline

```
logged sets  ─▶  est-1RM per exercise  ─▶  anchor curve  ─▶  exercise score (0-100)
                                                                    │
                                   weighted top-3 average  ◀────────┘
                                            │
                                            ▼
                                   muscle-group score (0-100)
```

All scoring lives in a new module. `history.dart` keeps its public surface
(`groupStats`, `progressionFor`) but swaps the volume math for the new scorer.

### Est-1RM

Epley: `1RM = w × (1 + reps / 30)`. Reps clamped to 12 before the formula —
Epley degrades past ~12 reps, and we don't want a 135×20 set to project to a
280 lb 1RM.

For each exercise in the relevant time window, `best 1RM = max` of Epley
applied to every logged set of that exercise.

### Anchor curves

Each known exercise is defined by a single `(a75, a95)` pair — the 1RM that
should score 75, and the 1RM that should score 95. A full piecewise-linear
curve is derived from that pair:

```
(0,             0)
(a75 × 0.42,    25)
(a75 × 0.60,    40)
(a75 × 0.82,    60)
(a75,           75)
(a75 + d × 0.55, 85)      where d = a95 − a75
(a95,           95)
(a95 + d × 0.55, 98)
(a95 + d × 1.0,  100)
```

Between anchors: linear interpolation. Above the last anchor: clamped at 100.
(The first anchor is `(0, 0)` so there's no "below" case.)

The diminishing-returns shape comes out of the derivation: between score 0 and
75, ~60% of the lift's terminal weight gets you 75% of the score; the next 15
score points take another ~30% of weight; the final 5 points ask for 45%+
more weight again.

**Bench Press** is the baseline: `a75 = 225`, `a95 = 315`. Plugging in yields
anchors `(95,25), (135,40), (185,60), (225,75), (275,85), (315,95), (365,98), (405,100)`.
A `155×7` session (Epley 1RM = 191) interpolates between `(185,60)` and
`(225,75)` → **score ≈ 62**. ✓

**Compound `(a75, a95)` pairs**:
| Exercise | a75 | a95 |
|---|---|---|
| BENCH PRESS | 225 | 315 |
| INCLINE BENCH / INCLINE DB PRESS / CLOSE-GRIP BENCH | 190 | 265 |
| OHP | 150 | 205 |
| BARBELL ROW / T-BAR ROW | 180 | 250 |
| BACK SQUAT | 295 | 410 |
| RDL / ROMANIAN DL | 270 | 380 |
| DEADLIFT | 335 | 470 |
| LEG PRESS | 475 | 650 |

**Isolation `(a75, a95)` pairs**:
| Exercise | a75 | a95 |
|---|---|---|
| LAT PULLDOWN | 155 | 220 |
| CABLE ROW | 155 | 220 |
| LEG CURL | 135 | 180 |
| LEG EXTENSION | 150 | 200 |
| CALF RAISE | 300 | 420 |
| LATERAL RAISE | 30 | 50 |
| REAR DELT FLY | 25 | 45 |
| FACE PULL | 50 | 75 |
| SHRUG | 225 | 315 |
| DB FLY | 50 | 75 |
| CABLE FLY | 60 | 90 |
| BARBELL CURL / EZ-BAR CURL | 110 | 145 |
| HAMMER CURL | 45 | 65 |
| CABLE CURL | 70 | 100 |
| TRICEP PUSHDOWN / ROPE PUSHDOWN | 85 | 115 |
| SKULL CRUSHER | 105 | 140 |
| OVERHEAD EXT | 80 | 110 |
| CABLE CRUNCH | 150 | 200 |
| WALKING LUNGE | 90 | 130 |

**`isCompound` flag** per exercise drives aggregation weighting. True for
bench, OHP, incline bench/DB, close-grip bench, barbell row, T-bar row,
back squat, RDL, deadlift, leg press, dips. False for all the isolation
exercises above.

### Aggregation (exercise → muscle)

For a given muscle group and time window:

1. Enumerate every logged exercise in the window whose group matches AND
   has anchors defined.
2. For each: compute best 1RM → exercise score via anchor curve.
3. Assign each a weight: **2.0 if compound, 1.0 if isolation**.
4. Sort by `score × weight` descending, take top 3.
5. Muscle score = `sum(score_i × weight_i) / sum(weight_i)` over those top 3.
6. Round to integer 0-100.

Fewer than 3 qualifying lifts: use what's there. Zero: score = 0.

### Time windows

- **Current score**: rolling 4-week window ending this week (weeks 0-3 back).
- **Previous score** (for 4W delta): weeks 4-7 back.
- **Weekly progression line** (52 wk): for each week W, compute the score
  using logs from `[W-3, W]`. This mirrors the "current" definition so the
  latest point on the chart equals the headline INDEX number.

### Unknowns & edge cases

- **Custom / unrecognized exercises**: no anchors → skipped entirely from
  muscle score (do not count against aggregation's top-3).
- **Bodyweight-only lifts** (PULL-UP, DIPS, HANGING LEG RAISE, PLANK logged
  with `w = 0`): skipped for now. No bodyweight field exists and the user
  explicitly declined to add one.
- **Very high reps** (> 12): clamped to 12 before Epley.
- **Zero-weight set with reps > 0 on a lift that normally has weight**:
  treat as no data for that set.

### What doesn't change

- `perExerciseMaxInGroup` and `mostImprovedInGroup` (history.dart) keep
  their weight-based logic — they surface raw numbers, not index scores.
- `prs`, `prsThisMonth`, `weeklyVolume`, streak logic: unchanged.
- UI files (`dashboard.dart`, `progression.dart`): no changes. They already
  consume int 0-100 group scores and will get new numbers through the same
  API.
- Storage schema: no migration. Historical sessions rescore automatically
  under the new rules.

## File Changes

| File | Change |
|---|---|
| `lib/core/strength_standards.dart` | **New**. Anchor table, `isCompound` flags, helper to derive full curve from `(a75, a95)` pairs. |
| `lib/services/muscle_score.dart` | **New**. `estimate1RM`, `scoreLift`, `groupScore`, `weeklyGroupScores`. Pure functions operating on `List<SessionRecord>`. |
| `lib/services/history.dart` | **Edit**. `groupStats` delegates to `groupScore` for current + prev windows. `progressionFor` delegates to `weeklyGroupScores`. |

## Testing

Dart unit tests under `test/muscle_score_test.dart`:

- Epley correctness and reps-clamp at 12.
- `scoreLift`: bench anchor values (155×7 ≈ 62, 225 = 75, 315 = 95, 500 = 100).
- `scoreLift`: interpolation correctness between two anchors.
- `scoreLift`: unknown exercise returns null.
- `groupScore`: top-3 weighted average with a mix of compound + isolation.
- `groupScore`: zero qualifying lifts → 0.
- `groupScore`: bodyweight-only pull-up with `w=0` excluded.
- `weeklyGroupScores`: rolling 4-week window; dropout week lowers but
  doesn't zero if prior weeks are in window.

## Non-goals (explicit)

- Bodyweight / gender calibration. Fixed absolute anchors only.
- Bodyweight-lift scoring (deferred until bodyweight field added).
- UI changes beyond the numbers themselves.
- Backward compatibility for the old volume-based scores (they're stateless
  derived values — nothing persisted changes).

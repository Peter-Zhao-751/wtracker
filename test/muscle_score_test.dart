import 'package:flutter_test/flutter_test.dart';
import 'package:wtracker/core/models.dart';
import 'package:wtracker/core/strength_standards.dart';
import 'package:wtracker/services/muscle_score.dart';

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

  group('groupScore', () {
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

    test('single bench 225x1 -> ~77', () {
      final hist = [
        session(3, [set('BENCH PRESS', 'CHEST', 225, 1)]),
      ];
      // 225x1 Epley = 232.5 -> interpolates (225,75)-(275,85): ~77.
      final s = groupScore(hist, 'CHEST', windowEnd: now, windowWeeks: 4);
      expect(s, inInclusiveRange(75, 80));
    });

    test('compound double-weighted vs isolation', () {
      final hist = [
        session(3, [
          set('BENCH PRESS', 'CHEST', 225, 1),
          set('CABLE FLY', 'CHEST', 90, 1),
        ]),
      ];
      final s = groupScore(hist, 'CHEST', windowEnd: now, windowWeeks: 4);
      expect(s, inInclusiveRange(78, 88));
    });

    test('top-3 cap — high compound dominates', () {
      final hist = [
        session(3, [set('BENCH PRESS', 'CHEST', 315, 1)]),
        session(4, [set('CABLE FLY', 'CHEST', 30, 1)]),
      ];
      final s = groupScore(hist, 'CHEST', windowEnd: now, windowWeeks: 4);
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
}

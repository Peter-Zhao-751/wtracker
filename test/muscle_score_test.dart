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

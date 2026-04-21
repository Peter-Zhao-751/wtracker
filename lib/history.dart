import 'package:flutter/foundation.dart';
import 'data.dart';
import 'models.dart';
import 'storage.dart';

class History extends ChangeNotifier {
  List<SessionRecord> _sessions = [];

  List<SessionRecord> get sessions => List.unmodifiable(_sessions);

  Future<void> load() async {
    final raw = await Storage.loadHistory();
    _sessions = [
      for (final s in raw)
        if (s is Map) SessionRecord.fromJson(s),
    ]..sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
  }

  Future<void> _persist() async {
    await Storage.saveHistory([for (final s in _sessions) s.toJson()]);
  }

  /// Inspect a set that's about to be marked done against history: returns
  /// true if [w] at [reps] would beat the heaviest previously logged weight
  /// for that lift (regardless of reps). Used for live PR detection.
  bool wouldBePR(String exerciseName, double w) {
    double max = 0;
    for (final sess in _sessions) {
      for (final s in sess.sets) {
        if (s.exerciseName == exerciseName && s.w > max) max = s.w;
      }
    }
    return w > max && w > 0;
  }

  Future<void> add(SessionRecord record) async {
    _sessions = [..._sessions, record]..sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    await _persist();
  }

  // ─── Analytics ──────────────────────────────────────────────────────────

  /// Total streak of consecutive days ending today (or yesterday) that have
  /// at least one logged session. Returns 0 if the most recent session is
  /// older than yesterday.
  int get streakDays {
    if (_sessions.isEmpty) return 0;
    final days = <int>{};
    for (final s in _sessions) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      days.add(d.millisecondsSinceEpoch);
    }
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(cursor.millisecondsSinceEpoch)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor.millisecondsSinceEpoch)) return 0;
    }
    var count = 0;
    while (days.contains(cursor.millisecondsSinceEpoch)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Longest streak of consecutive training days that ended *before* the
  /// current active streak. Returns 0 if the user has never had a prior
  /// streak (e.g., this is their first streak, or no sessions yet).
  int get longestPreviousStreak {
    if (_sessions.isEmpty) return 0;
    final dayMs = <int>{};
    for (final s in _sessions) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      dayMs.add(d.millisecondsSinceEpoch);
    }
    final sortedDays = dayMs.toList()..sort();
    // Walk forward, grouping consecutive days into streak-lengths.
    final runs = <int>[];
    int run = 1;
    for (int i = 1; i < sortedDays.length; i++) {
      final prev = DateTime.fromMillisecondsSinceEpoch(sortedDays[i - 1]);
      final cur = DateTime.fromMillisecondsSinceEpoch(sortedDays[i]);
      if (cur.difference(prev).inDays == 1) {
        run++;
      } else {
        runs.add(run);
        run = 1;
      }
    }
    runs.add(run);
    // The current-streak run is the last one iff it reaches today or
    // yesterday — drop it so we only return the prior best.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime.fromMillisecondsSinceEpoch(sortedDays.last);
    final isCurrent =
        lastDay.isAtSameMomentAs(today) ||
        lastDay.isAtSameMomentAs(today.subtract(const Duration(days: 1)));
    if (isCurrent && runs.isNotEmpty) runs.removeLast();
    if (runs.isEmpty) return 0;
    return runs.reduce((a, b) => a > b ? a : b);
  }

  /// Monday-based start-of-week for [d].
  DateTime _weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// Volume (weight × reps summed) for every logged set in [weeks] rolling
  /// weeks ending with the current week. Returns a list of length [weeks],
  /// oldest first, in thousands of lbs (or kg if units configured elsewhere —
  /// raw numbers here stay in whatever units were logged, which is lbs).
  List<double> weeklyVolume([int weeks = 12]) {
    final now = DateTime.now();
    final thisWeek = _weekStart(now);
    final buckets = List<double>.filled(weeks, 0);
    for (final s in _sessions) {
      final w = _weekStart(s.date);
      final diff = thisWeek.difference(w).inDays ~/ 7;
      final idx = weeks - 1 - diff;
      if (idx < 0 || idx >= weeks) continue;
      for (final l in s.sets) {
        buckets[idx] += l.w * l.reps;
      }
    }
    return [for (final v in buckets) v / 1000.0];
  }

  /// Top PRs (max weight per lift). [limit] controls how many rows to return.
  List<PrRow> prs({int limit = 5}) {
    final byLift = <String, List<LoggedSet>>{};
    final dates = <LoggedSet, DateTime>{};
    for (final s in _sessions) {
      for (final l in s.sets) {
        byLift.putIfAbsent(l.exerciseName, () => []).add(l);
        dates[l] = s.date;
      }
    }
    final rows = <PrRow>[];
    byLift.forEach((lift, sets) {
      sets.sort((a, b) => b.w.compareTo(a.w));
      final top = sets.first;
      final prev = sets.length > 1 ? sets[1].w : 0.0;
      rows.add(PrRow(
        lift: lift,
        w: top.w,
        prev: prev,
        reps: top.reps,
        date: _fmtDate(dates[top]!),
      ));
    });
    rows.sort((a, b) => b.w.compareTo(a.w));
    return rows.take(limit).toList();
  }

  /// Count of all-time PRs set within the last 30 days — used for the
  /// dashboard "PRs" stat tile.
  int prsThisMonth() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final bestBefore = <String, double>{};
    final recentBest = <String, double>{};
    for (final s in _sessions) {
      for (final l in s.sets) {
        final target = s.date.isBefore(cutoff) ? bestBefore : recentBest;
        final cur = target[l.exerciseName] ?? 0;
        if (l.w > cur) target[l.exerciseName] = l.w;
      }
    }
    var n = 0;
    recentBest.forEach((lift, w) {
      if (w > (bestBefore[lift] ?? 0)) n++;
    });
    return n;
  }

  /// Per-group radar stats: current (last 4 weeks) vs previous (weeks 5-8),
  /// each normalized to 0..100 relative to the max group volume in the
  /// current window. Groups with no data show 0.
  List<GroupStat> groupStats(List<String> groups) {
    final now = DateTime.now();
    final thisWeek = _weekStart(now);
    final cur = <String, double>{for (final g in groups) g: 0};
    final prev = <String, double>{for (final g in groups) g: 0};
    for (final s in _sessions) {
      final w = _weekStart(s.date);
      final wksBack = thisWeek.difference(w).inDays ~/ 7;
      final bucket = wksBack < 4
          ? cur
          : (wksBack < 8 ? prev : null);
      if (bucket == null) continue;
      for (final l in s.sets) {
        if (!bucket.containsKey(l.group)) continue;
        bucket[l.group] = bucket[l.group]! + l.w * l.reps;
      }
    }
    final maxVol = [...cur.values, ...prev.values].fold<double>(0, (a, b) => b > a ? b : a);
    int norm(double v) => maxVol == 0 ? 0 : ((v / maxVol) * 100).round().clamp(0, 100);
    return [
      for (final g in groups)
        GroupStat(
          group: g,
          label: groupLabel(g),
          value: norm(cur[g] ?? 0),
          prev: norm(prev[g] ?? 0),
          delta: _deltaStr(norm(cur[g] ?? 0) - norm(prev[g] ?? 0)),
        ),
    ];
  }

  /// Index curve for [group]: weekly volume normalized 0..100 against the
  /// group's peak week in the window, then 4-week trailing-averaged for
  /// smoothness. Length is always [weeks]; empty history yields all zeros.
  List<int> progressionFor(String group, {int weeks = 52}) {
    final raw = List<double>.filled(weeks, 0);
    final now = DateTime.now();
    final thisWeek = _weekStart(now);
    for (final s in _sessions) {
      final w = _weekStart(s.date);
      final diff = thisWeek.difference(w).inDays ~/ 7;
      final idx = weeks - 1 - diff;
      if (idx < 0 || idx >= weeks) continue;
      for (final l in s.sets) {
        if (l.group == group) raw[idx] += l.w * l.reps;
      }
    }
    final peak = raw.fold<double>(0, (a, b) => b > a ? b : a);
    if (peak == 0) return List<int>.filled(weeks, 0);
    final smooth = <int>[];
    for (int i = 0; i < raw.length; i++) {
      final from = (i - 3).clamp(0, raw.length - 1);
      double s = 0;
      int c = 0;
      for (int j = from; j <= i; j++) {
        s += raw[j];
        c++;
      }
      final avg = s / c;
      smooth.add(((avg / peak) * 100).round().clamp(0, 100));
    }
    return smooth;
  }

  /// Number of weeks spanning the oldest logged session to the current week
  /// (inclusive). Used to size "ALL" / lifetime timeframes. Clamped to a
  /// minimum of 4 so degenerate charts still have width.
  int get lifetimeWeeks {
    if (_sessions.isEmpty) return 4;
    final oldest = _sessions.first.date;
    final wks = _weekStart(DateTime.now())
            .difference(_weekStart(oldest))
            .inDays ~/
        7 +
        1;
    return wks < 4 ? 4 : wks;
  }

  /// Per-exercise weekly max-weight series for every exercise in [group]
  /// across [weeks] trailing weeks. Rest weeks fill-forward the last known
  /// max so sparklines don't dip to zero between sessions. Exercises with no
  /// logged sets in the window are omitted. Sorted by most recent max desc.
  List<ExerciseSeries> perExerciseMaxInGroup(String group, int weeks) {
    final now = DateTime.now();
    final thisWeek = _weekStart(now);
    final byEx = <String, List<double>>{};
    for (final s in _sessions) {
      final w = _weekStart(s.date);
      final diff = thisWeek.difference(w).inDays ~/ 7;
      final idx = weeks - 1 - diff;
      if (idx < 0 || idx >= weeks) continue;
      for (final l in s.sets) {
        if (l.group != group) continue;
        final series = byEx.putIfAbsent(
          l.exerciseName,
          () => List<double>.filled(weeks, 0),
        );
        if (l.w > series[idx]) series[idx] = l.w;
      }
    }
    for (final series in byEx.values) {
      double last = 0;
      for (int i = 0; i < series.length; i++) {
        if (series[i] == 0) {
          series[i] = last;
        } else {
          last = series[i];
        }
      }
    }
    final out = <ExerciseSeries>[];
    byEx.forEach((name, series) {
      if (series.every((v) => v == 0)) return;
      out.add(ExerciseSeries(name: name, series: series));
    });
    out.sort((a, b) => b.series.last.compareTo(a.series.last));
    return out;
  }

  /// For [group], returns every exercise logged in the last 8 weeks, sorted by
  /// improvement in max single-set weight versus weeks 9-34 before that. Novel
  /// exercises (no prior-window history) are flagged via [ExerciseImprovement.isNew]
  /// so the UI can badge them rather than show a misleading delta.
  List<ExerciseImprovement> mostImprovedInGroup(String group) {
    const recentWeeks = 8;
    const priorWeeks = 26;
    final now = DateTime.now();
    final thisWeek = _weekStart(now);
    final recentBest = <String, double>{};
    final priorBest = <String, double>{};
    for (final s in _sessions) {
      final w = _weekStart(s.date);
      final wksBack = thisWeek.difference(w).inDays ~/ 7;
      for (final l in s.sets) {
        if (l.group != group) continue;
        if (wksBack < recentWeeks) {
          final cur = recentBest[l.exerciseName] ?? 0;
          if (l.w > cur) recentBest[l.exerciseName] = l.w;
        } else if (wksBack < recentWeeks + priorWeeks) {
          final cur = priorBest[l.exerciseName] ?? 0;
          if (l.w > cur) priorBest[l.exerciseName] = l.w;
        }
      }
    }
    final out = <ExerciseImprovement>[];
    for (final name in recentBest.keys) {
      final curr = recentBest[name]!;
      if (curr == 0) continue;
      final prev = priorBest[name] ?? 0;
      final isNew = prev == 0;
      if (!isNew && curr <= prev) continue;
      out.add(ExerciseImprovement(
        exerciseName: name,
        curr: curr,
        prev: prev,
        isNew: isNew,
      ));
    }
    out.sort((a, b) => (b.curr - b.prev).compareTo(a.curr - a.prev));
    return out;
  }

  List<SessionRow> sessionRows({int limit = 12}) {
    final rows = <SessionRow>[];
    final sorted = [..._sessions]..sort((a, b) => b.date.compareTo(a.date));
    for (final s in sorted.take(limit)) {
      var vol = 0.0;
      var hasPR = false;
      for (final l in s.sets) {
        vol += l.w * l.reps;
        if (l.isPR) hasPR = true;
      }
      rows.add(SessionRow(
        date: _fmtDate(s.date),
        day: _weekdayStr(s.date),
        name: s.name,
        dur: s.durSec ~/ 60,
        vol: vol / 1000.0,
        sets: s.sets.length,
        pr: hasPR,
      ));
    }
    return rows;
  }

  /// Most recently completed session's template name — used for the dashboard
  /// "start next" cue. Null if history is empty.
  String? lastSessionName() {
    if (_sessions.isEmpty) return null;
    final sorted = [..._sessions]..sort((a, b) => b.date.compareTo(a.date));
    return sorted.first.name;
  }
}

String _fmtDate(DateTime d) {
  const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
}

String _weekdayStr(DateTime d) {
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return days[d.weekday - 1];
}

String _deltaStr(int d) => d >= 0 ? '+$d' : '$d';

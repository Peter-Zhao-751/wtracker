import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class StorageService {
  static const _workoutsFile = 'wtracker_workouts.json';
  static const _starredFile = 'wtracker_starred.json';
  static const _exerciseOrderFile = 'wtracker_exercise_order.json';

  static Future<String> get _dirPath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  // ── Workouts ──

  static Future<List<Workout>> loadWorkouts() async {
    try {
      final path = await _dirPath;
      final file = File('$path/$_workoutsFile');
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      if (contents.isEmpty) return [];
      final list = jsonDecode(contents) as List;
      return list
          .map((e) => Workout.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveWorkouts(List<Workout> workouts) async {
    try {
      final path = await _dirPath;
      final file = File('$path/$_workoutsFile');
      final json = workouts.map((w) => w.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (_) {
      // Silent fail — don't crash the app for storage issues
    }
  }

  // ── Starred exercises ──

  static Future<Map<String, bool>> loadStarred() async {
    try {
      final path = await _dirPath;
      final file = File('$path/$_starredFile');
      if (!await file.exists()) return {};
      final contents = await file.readAsString();
      if (contents.isEmpty) return {};
      final map = jsonDecode(contents) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as bool));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveStarred(Map<String, bool> starred) async {
    try {
      final path = await _dirPath;
      final file = File('$path/$_starredFile');
      await file.writeAsString(jsonEncode(starred));
    } catch (_) {
      // Silent fail
    }
  }

  // ── Exercise order ──

  static Future<List<String>> loadExerciseOrder() async {
    try {
      final path = await _dirPath;
      final file = File('$path/$_exerciseOrderFile');
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      if (contents.isEmpty) return [];
      final list = jsonDecode(contents) as List;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveExerciseOrder(List<String> order) async {
    try {
      final path = await _dirPath;
      final file = File('$path/$_exerciseOrderFile');
      await file.writeAsString(jsonEncode(order));
    } catch (_) {
      // Silent fail
    }
  }
}

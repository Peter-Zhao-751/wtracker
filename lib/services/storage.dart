import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Storage {
  static const _tweaksFile = 'wtracker_tweaks.json';
  static const _tabFile = 'wtracker_tab.txt';
  static const _prefsFile = 'wtracker_prefs.json';
  static const _historyFile = 'wtracker_history.json';

  static Future<String> get _dirPath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static Future<Map<String, dynamic>> loadTweaks() async {
    try {
      final file = File('${await _dirPath}/$_tweaksFile');
      if (!await file.exists()) return {};
      final c = await file.readAsString();
      if (c.isEmpty) return {};
      return jsonDecode(c) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveTweaks(Map<String, dynamic> tweaks) async {
    try {
      final file = File('${await _dirPath}/$_tweaksFile');
      await file.writeAsString(jsonEncode(tweaks));
    } catch (_) {}
  }

  static Future<String?> loadTab() async {
    try {
      final file = File('${await _dirPath}/$_tabFile');
      if (!await file.exists()) return null;
      return (await file.readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveTab(String tab) async {
    try {
      final file = File('${await _dirPath}/$_tabFile');
      await file.writeAsString(tab);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> loadPrefs() async {
    try {
      final file = File('${await _dirPath}/$_prefsFile');
      if (!await file.exists()) return {};
      final c = await file.readAsString();
      if (c.isEmpty) return {};
      return jsonDecode(c) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> savePrefs(Map<String, dynamic> prefs) async {
    try {
      final file = File('${await _dirPath}/$_prefsFile');
      await file.writeAsString(jsonEncode(prefs));
    } catch (_) {}
  }

  static Future<List> loadHistory() async {
    try {
      final file = File('${await _dirPath}/$_historyFile');
      if (!await file.exists()) return [];
      final c = await file.readAsString();
      if (c.isEmpty) return [];
      final parsed = jsonDecode(c);
      if (parsed is List) return parsed;
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveHistory(List sessions) async {
    try {
      final file = File('${await _dirPath}/$_historyFile');
      await file.writeAsString(jsonEncode(sessions));
    } catch (_) {}
  }
}

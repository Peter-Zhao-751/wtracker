import 'dart:ui' show PlatformDispatcher, Brightness;

import 'package:flutter/foundation.dart';
import 'data.dart';
import 'storage.dart';
import 'theme.dart';

class Tweaks extends ChangeNotifier {
  Accent _accent = kAccents.first;
  String _unit = 'lbs';
  String _radarStyle = 'gradient';
  String _density = 'compact';
  int _defaultRest = 180;
  Set<String> _tracked = const {'CHEST', 'BACK', 'SHLDR', 'ARMS', 'LEGS', 'CORE'};
  List<String> _groupOrder = List<String>.from(kGroupNames);
  String _theme = 'light';

  Accent get accent => _accent;
  String get unit => _unit;
  String get radarStyle => _radarStyle;
  String get density => _density;
  int get defaultRest => _defaultRest;
  /// Tracked groups in the user's preferred display order. Derived from the
  /// master [groupOrder] filtered by the tracked set, so reordering the full
  /// list in the tweaks panel automatically reorders the radar pills.
  List<String> get radarGroups => List.unmodifiable(
        [for (final g in _groupOrder) if (_tracked.contains(g)) g],
      );
  List<String> get groupOrder => List.unmodifiable(_groupOrder);
  bool isTracked(String g) => _tracked.contains(g);
  String get theme => _theme;
  bool get isDark => _theme == 'dark';

  Future<void> load() async {
    final saved = await Storage.loadTweaks();
    if (saved['accent'] is Map) {
      final a = saved['accent'] as Map;
      final match = kAccents.firstWhere(
        (x) => x.name == a['name'],
        orElse: () => kAccents.first,
      );
      _accent = match;
    }
    _unit = (saved['unit'] as String?) ?? _unit;
    _radarStyle = (saved['radarStyle'] as String?) ?? _radarStyle;
    _density = (saved['density'] as String?) ?? _density;
    _defaultRest = (saved['defaultRest'] as int?) ?? _defaultRest;
    if (saved['radarGroups'] is List) {
      _tracked = {
        for (final g in (saved['radarGroups'] as List).cast())
          if (kGroupNames.contains(g.toString())) g.toString(),
      };
    }
    if (saved['groupOrder'] is List) {
      final loaded = (saved['groupOrder'] as List).cast().map((e) => e.toString());
      _groupOrder = _reconcileGroupOrder(loaded);
    }
    final savedTheme = saved['theme'] as String?;
    if (savedTheme != null) {
      _theme = savedTheme;
    } else {
      // First launch: match the OS appearance so the app opens in whatever
      // mode the phone is in. User's explicit toggle in Tweaks will persist
      // and take over on subsequent launches.
      final sysDark =
          PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      _theme = sysDark ? 'dark' : 'light';
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await Storage.saveTweaks({
      'accent': {'name': _accent.name, 'v': _accent.v.value, 'ink': _accent.ink.value},
      'unit': _unit,
      'radarStyle': _radarStyle,
      'density': _density,
      'defaultRest': _defaultRest,
      'radarGroups': _tracked.toList(),
      'groupOrder': _groupOrder,
      'theme': _theme,
    });
  }

  void setAccent(Accent a) { _accent = a; notifyListeners(); _persist(); }
  void setUnit(String u) { _unit = u; notifyListeners(); _persist(); }
  void setRadarStyle(String s) { _radarStyle = s; notifyListeners(); _persist(); }
  void setDensity(String d) { _density = d; notifyListeners(); _persist(); }
  void setDefaultRest(int r) { _defaultRest = r.clamp(0, 600); notifyListeners(); _persist(); }
  void toggleGroup(String g) {
    if (_tracked.contains(g)) {
      _tracked = {..._tracked}..remove(g);
    } else {
      _tracked = {..._tracked, g};
    }
    notifyListeners();
    _persist();
  }
  void setGroupOrder(List<String> order) {
    _groupOrder = _reconcileGroupOrder(order);
    notifyListeners();
    _persist();
  }
  void setTheme(String t) { _theme = t; notifyListeners(); _persist(); }
}

/// Clamp [order] to the canonical [kGroupNames] set — drop unknowns, append
/// any newly-added groups at the end so upgrades don't hide them.
List<String> _reconcileGroupOrder(Iterable<String> order) {
  final seen = <String>{};
  final next = <String>[];
  for (final g in order) {
    if (kGroupNames.contains(g) && seen.add(g)) next.add(g);
  }
  for (final g in kGroupNames) {
    if (seen.add(g)) next.add(g);
  }
  return next;
}

/// Cross-screen preferences: orderings, favorites, per-template overrides.
/// Kept separate from Tweaks so the settings panel stays clean.
class Prefs extends ChangeNotifier {
  static const List<String> kDefaultTplFilterOrder = [
    'ALL',
    'PPL',
    'U/L',
    'FB',
    'BRO',
    'CUSTOM',
  ];

  List<String> _templateOrder = [];
  final Map<String, TplOverride> _templateOverrides = {};
  final Set<String> _exerciseFavorites = {};
  final Map<String, List<String>> _exerciseOrder = {};
  List<String> _tabOrder = [];
  List<String> _tplFilterOrder = List<String>.from(kDefaultTplFilterOrder);
  List<String> _progGroupOrder = List<String>.from(kGroupNames);

  List<String> get templateOrder => List.unmodifiable(_templateOrder);
  Set<String> get exerciseFavorites => Set.unmodifiable(_exerciseFavorites);
  List<String> get tabOrder => List.unmodifiable(_tabOrder);
  List<String> get tplFilterOrder => List.unmodifiable(_tplFilterOrder);
  List<String> get progGroupOrder => List.unmodifiable(_progGroupOrder);

  bool isFavorite(String name) => _exerciseFavorites.contains(name);
  List<String>? exerciseOrderFor(String group) => _exerciseOrder[group];
  TplOverride? overrideFor(String tplId) => _templateOverrides[tplId];
  bool hasOverride(String tplId) => _templateOverrides.containsKey(tplId);

  Future<void> load() async {
    final saved = await Storage.loadPrefs();
    if (saved['templateOrder'] is List) {
      _templateOrder = List<String>.from(saved['templateOrder'] as List);
    }
    if (saved['templateOverrides'] is Map) {
      (saved['templateOverrides'] as Map).forEach((k, v) {
        if (v is Map) _templateOverrides[k.toString()] = TplOverride.fromJson(v);
      });
    }
    if (saved['exerciseFavorites'] is List) {
      _exerciseFavorites
        ..clear()
        ..addAll((saved['exerciseFavorites'] as List).map((e) => e.toString()));
    }
    if (saved['exerciseOrder'] is Map) {
      (saved['exerciseOrder'] as Map).forEach((k, v) {
        if (v is List) _exerciseOrder[k.toString()] = List<String>.from(v);
      });
    }
    if (saved['tabOrder'] is List) {
      _tabOrder = List<String>.from(saved['tabOrder'] as List);
    }
    if (saved['tplFilterOrder'] is List) {
      final loaded = List<String>.from(saved['tplFilterOrder'] as List);
      // Reconcile against defaults so newly-added filters (e.g. CUSTOM)
      // surface for users upgrading from older builds.
      final next = <String>[
        ...loaded.where(kDefaultTplFilterOrder.contains),
        ...kDefaultTplFilterOrder.where((o) => !loaded.contains(o)),
      ];
      _tplFilterOrder = next;
    }
    if (saved['progGroupOrder'] is List) {
      final loaded = (saved['progGroupOrder'] as List).cast().map((e) => e.toString());
      _progGroupOrder = _reconcileGroupOrder(loaded);
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await Storage.savePrefs({
      'templateOrder': _templateOrder,
      'templateOverrides': {
        for (final e in _templateOverrides.entries) e.key: e.value.toJson(),
      },
      'exerciseFavorites': _exerciseFavorites.toList(),
      'exerciseOrder': _exerciseOrder,
      'tabOrder': _tabOrder,
      'tplFilterOrder': _tplFilterOrder,
      'progGroupOrder': _progGroupOrder,
    });
  }

  void setTemplateOrder(List<String> order) {
    _templateOrder = List<String>.from(order);
    notifyListeners();
    _persist();
  }

  void setTemplateSets(String tplId, int origIdx, int sets) {
    final cur = _templateOverrides[tplId] ?? TplOverride();
    cur.sets[origIdx] = sets;
    _templateOverrides[tplId] = cur;
    notifyListeners();
    _persist();
  }

  void setTemplateExOrder(String tplId, List<int> origIndices) {
    final cur = _templateOverrides[tplId] ?? TplOverride();
    cur.exOrder = List<int>.from(origIndices);
    _templateOverrides[tplId] = cur;
    notifyListeners();
    _persist();
  }

  void resetTemplate(String tplId) {
    _templateOverrides.remove(tplId);
    notifyListeners();
    _persist();
  }

  void toggleFavorite(String name) {
    if (_exerciseFavorites.contains(name)) {
      _exerciseFavorites.remove(name);
    } else {
      _exerciseFavorites.add(name);
    }
    notifyListeners();
    _persist();
  }

  void setExerciseOrder(String group, List<String> names) {
    _exerciseOrder[group] = List<String>.from(names);
    notifyListeners();
    _persist();
  }

  void setTabOrder(List<String> order) {
    _tabOrder = List<String>.from(order);
    notifyListeners();
    _persist();
  }

  void setTemplateFilterOrder(List<String> order) {
    final next = <String>[
      ...order.where(kDefaultTplFilterOrder.contains),
      ...kDefaultTplFilterOrder.where((o) => !order.contains(o)),
    ];
    _tplFilterOrder = next;
    notifyListeners();
    _persist();
  }

  void setProgGroupOrder(List<String> order) {
    _progGroupOrder = _reconcileGroupOrder(order);
    notifyListeners();
    _persist();
  }
}

class TplOverride {
  final Map<int, int> sets = {};
  List<int>? exOrder;

  TplOverride();

  factory TplOverride.fromJson(Map j) {
    final o = TplOverride();
    if (j['sets'] is Map) {
      (j['sets'] as Map).forEach((k, v) {
        final key = int.tryParse(k.toString());
        final val = v is int ? v : int.tryParse(v.toString());
        if (key != null && val != null) o.sets[key] = val;
      });
    }
    if (j['exOrder'] is List) {
      o.exOrder = (j['exOrder'] as List).map((e) => e is int ? e : int.parse(e.toString())).toList();
    }
    return o;
  }

  Map<String, dynamic> toJson() => {
        'sets': {for (final e in sets.entries) e.key.toString(): e.value},
        if (exOrder != null) 'exOrder': exOrder,
      };

  int? setsFor(int origIdx) => sets[origIdx];
}

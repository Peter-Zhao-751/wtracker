import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/models.dart';
import 'core/theme.dart';
import 'services/history.dart';
import 'services/state.dart';
import 'services/storage.dart';
import 'widgets/primitives.dart';
import 'screens/dashboard.dart';
import 'screens/launch.dart';
import 'screens/templates.dart';
import 'screens/progression.dart';
import 'screens/log_sheet.dart';
import 'screens/tweaks_panel.dart';
import 'screens/active_workout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  // Preload just the VOLT wordmark so the launch screen can paint it on
  // its very first frame — no flash of empty background.
  final voltSvg = await rootBundle.loadString('assets/wordmark-volt.svg');
  runApp(BootApp(voltSvg: voltSvg));
}

class BootApp extends StatefulWidget {
  final String voltSvg;
  const BootApp({super.key, required this.voltSvg});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  Tweaks? _tweaks;
  Prefs? _prefs;
  History? _history;
  Map<String, String>? _wordmarks;
  String? _initialTab;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final tweaks = Tweaks();
    final prefs = Prefs();
    final history = History();
    final wordmarks = <String, String>{'volt': widget.voltSvg};
    await Future.wait([
      tweaks.load(),
      prefs.load(),
      history.load(),
      () async {
        for (final a in kAccents) {
          final name = a.name.toLowerCase();
          if (name == 'volt') continue;
          wordmarks[name] =
              await rootBundle.loadString('assets/wordmark-$name.svg');
        }
      }(),
      // Keep the launch screen up for a beat even when loads finish fast,
      // so the branding lands instead of flickering past.
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    final savedTab = await Storage.loadTab();
    if (!mounted) return;
    setState(() {
      _tweaks = tweaks;
      _prefs = prefs;
      _history = history;
      _wordmarks = wordmarks;
      _initialTab = savedTab ?? 'dash';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tweaks == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: LaunchScreen.bg,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: LaunchScreen(wordmarkSvg: widget.voltSvg),
        ),
      );
    }
    return WTrackerApp(
      tweaks: _tweaks!,
      prefs: _prefs!,
      history: _history!,
      wordmarks: _wordmarks!,
      initialTab: _initialTab!,
    );
  }
}

class WTrackerApp extends StatelessWidget {
  final Tweaks tweaks;
  final Prefs prefs;
  final History history;
  final Map<String, String> wordmarks;
  final String initialTab;
  const WTrackerApp({
    super.key,
    required this.tweaks,
    required this.prefs,
    required this.history,
    required this.wordmarks,
    required this.initialTab,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tweaks,
      builder: (context, _) {
        final palette = BrutalPalette.fromTweaks(dark: tweaks.isDark, accent: tweaks.accent);
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          // Android: controls icon color directly.
          statusBarIconBrightness:
              tweaks.isDark ? Brightness.light : Brightness.dark,
          // iOS: specifies the background brightness so the system picks
          // contrasting foreground icons. Dark bg → light (white) icons.
          statusBarBrightness:
              tweaks.isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: palette.paper,
          systemNavigationBarIconBrightness:
              tweaks.isDark ? Brightness.light : Brightness.dark,
        );
        return MaterialApp(
          title: 'wTracker',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: palette.paper,
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: palette.ink,
              selectionColor: palette.accent.withValues(alpha: 0.4),
              selectionHandleColor: palette.ink,
            ),
            textTheme: TextTheme(
              bodyMedium: mono(size: 13, weight: FontWeight.w700, color: palette.ink),
            ),
          ),
          home: AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle,
            child: BrutalColors(
              palette: palette,
              child: DefaultTextStyle(
                style: mono(size: 13, weight: FontWeight.w700, color: palette.ink),
                child: Container(
                  color: palette.paper,
                  child: AppShell(
                    tweaks: tweaks,
                    prefs: prefs,
                    history: history,
                    wordmarks: wordmarks,
                    initialTab: initialTab,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  final Tweaks tweaks;
  final Prefs prefs;
  final History history;
  final Map<String, String> wordmarks;
  final String initialTab;
  const AppShell({
    super.key,
    required this.tweaks,
    required this.prefs,
    required this.history,
    required this.wordmarks,
    required this.initialTab,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late String _tab = widget.initialTab;
  Template? _activeTemplate;
  bool _logOpen = false;
  bool _tweaksOpen = false;
  String? _toast;

  void _setTab(String t) {
    if (t == 'log') {
      setState(() => _logOpen = true);
      return;
    }
    setState(() => _tab = t);
    Storage.saveTab(t);
  }

  void _start(Template t) {
    setState(() {
      _activeTemplate = t;
      _logOpen = false;
    });
  }

  void _finish(ActiveSummary s) {
    final logged = <LoggedSet>[];
    for (final ex in s.exs) {
      for (final set in ex.log) {
        if (!set.done) continue;
        logged.add(LoggedSet(
          exerciseName: ex.name,
          group: ex.group,
          w: set.w,
          reps: set.reps,
          isPR: set.isPR,
        ));
      }
    }
    if (logged.isNotEmpty) {
      widget.history.add(SessionRecord(
        date: DateTime.now(),
        name: s.name,
        split: s.split,
        durSec: s.dur,
        sets: logged,
      ));
    }
    setState(() {
      _activeTemplate = null;
      final parts = <String>[];
      if (s.saveAsTpl) {
        parts.add('SAVED "${s.newName}"');
      } else if (s.updateTpl) {
        parts.add('TEMPLATE UPDATED');
      }
      final extra = parts.isEmpty ? '' : ' · ${parts.join(' · ')}';
      _toast = 'SESSION COMPLETE · ${s.dur ~/ 60}m · ${s.sets} sets$extra';
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  String _headerSub() {
    switch (_tab) {
      case 'tpl':
        return 'TEMPLATES';
      case 'prog':
        return 'PROGRESSION';
      case 'log':
        return 'HISTORY';
      case 'dash':
      default:
        return _today();
    }
  }

  String _headerTitle() {
    switch (_tab) {
      case 'tpl':
        return 'PLANS';
      case 'prog':
        return 'PROG';
      case 'log':
        return 'LOG';
      case 'dash':
      default:
        return 'wTRACKER';
    }
  }

  String _today() {
    final now = DateTime.now();
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${days[now.weekday - 1]} · ${months[now.month - 1]} ${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = BrutalColors.of(context);
    final inSession = _activeTemplate != null;

    return Material(
      color: p.paper,
      child: Stack(
        children: [
          if (inSession)
            Positioned.fill(
              child: ActiveWorkoutScreen(
                template: _activeTemplate!,
                tweaks: widget.tweaks,
                prefs: widget.prefs,
                history: widget.history,
                onFinish: _finish,
                onClose: () => setState(() => _activeTemplate = null),
              ),
            )
          else
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    AppHeaderBar(
                      title: _headerTitle(),
                      sub: _headerSub(),
                      titleWidget: _tab == 'dash'
                          ? Builder(builder: (ctx) {
                              final raw = widget.wordmarks[
                                  widget.tweaks.accent.name.toLowerCase()];
                              if (raw == null) return const SizedBox.shrink();
                              return SvgPicture.string(
                                themedWordmark(raw, BrutalColors.of(ctx)),
                                height: 34,
                              );
                            })
                          : null,
                      right: IconSquare(
                        icon: Icons.tune,
                        onTap: () => setState(() => _tweaksOpen = true),
                      ),
                    ),
                    Expanded(
                      child: _buildTab(),
                    ),
                    BottomTabBar(active: _tab, onTab: _setTab),
                  ],
                ),
              ),
            ),
          if (_logOpen && !inSession)
            Positioned.fill(
              child: LogSheet(
                tweaks: widget.tweaks,
                prefs: widget.prefs,
                history: widget.history,
                onClose: () => setState(() => _logOpen = false),
                onStart: _start,
                onFinishQuick: _finish,
              ),
            ),
          if (_tweaksOpen)
            Positioned.fill(
              child: TweaksPanel(
                tweaks: widget.tweaks,
                onClose: () => setState(() => _tweaksOpen = false),
              ),
            ),
          if (_toast != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90 + MediaQuery.of(context).padding.bottom,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: p.ink,
                    border: Border.all(color: p.ink, width: 2),
                    boxShadow: [BoxShadow(color: p.accent, offset: const Offset(3, 3))],
                  ),
                  child: Text(
                    '✓ $_toast',
                    style: mono(
                      size: 12,
                      weight: FontWeight.w800,
                      letterSpacing: 1,
                      color: p.paper,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 'tpl':
        return TemplatesScreen(
          tweaks: widget.tweaks,
          prefs: widget.prefs,
          onStart: _start,
        );
      case 'prog':
        return ProgressionScreen(
          tweaks: widget.tweaks,
          prefs: widget.prefs,
          history: widget.history,
        );
      case 'dash':
      default:
        return DashboardScreen(
          tweaks: widget.tweaks,
          history: widget.history,
          onStart: _start,
          onTab: _setTab,
        );
    }
  }
}

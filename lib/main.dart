import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'data.dart';
import 'screens/home_screen.dart';
import 'screens/log_workout_screen.dart';
import 'screens/past_workouts_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: CyberTheme.bgDark,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await WorkoutRepository.instance.init();
  runApp(const WTrackerApp());
}

class WTrackerApp extends StatelessWidget {
  const WTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WTracker',
      debugShowCheckedModeBanner: false,
      theme: CyberTheme.darkTheme,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentTab = 0;
  int _rebuildKey = 0;

  void _openLogWorkout() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return LogWorkoutScreen(
            onSaved: () {
              Navigator.of(context).pop();
              setState(() {
                _rebuildKey++;
                _currentTab = 0;
              });
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.bgDark,
      body: Stack(
        children: [
          // Subtle background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [
                    CyberTheme.neonCyan.withValues(alpha: 0.03),
                    CyberTheme.bgDark,
                  ],
                ),
              ),
            ),
          ),
          // Content
          IndexedStack(
            key: ValueKey(_rebuildKey),
            index: _currentTab,
            children: [
              HomeScreen(onNavigateToLog: _openLogWorkout),
              const PastWorkoutsScreen(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: CyberTheme.bgCard,
        border: Border(
          top: BorderSide(
            color: CyberTheme.neonCyan.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: CyberTheme.bgDark.withValues(alpha: 0.8),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(Icons.dashboard_outlined, 'HOME', 0),
              _centerLogButton(),
              _navItem(Icons.history, 'HISTORY', 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int tabIndex) {
    final isActive = _currentTab == tabIndex;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentTab = tabIndex),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 3,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isActive ? CyberTheme.neonCyan : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: CyberTheme.neonCyan.withValues(alpha: 0.5),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
            ),
            Icon(
              icon,
              size: 22,
              color: isActive ? CyberTheme.neonCyan : CyberTheme.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isActive ? CyberTheme.neonCyan : CyberTheme.textMuted,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerLogButton() {
    return GestureDetector(
      onTap: _openLogWorkout,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [CyberTheme.neonCyan, CyberTheme.neonMagenta],
          ),
          boxShadow: [
            BoxShadow(
              color: CyberTheme.neonCyan.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: CyberTheme.neonMagenta.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 22),
            Text(
              'LOG',
              style: GoogleFonts.orbitron(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

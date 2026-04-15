import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets/muscle_radar.dart';
import '../exercise_info.dart';
import '../widgets/recent_workout_card.dart';
import '../widgets/movement_card.dart';
import '../widgets/cyber_card.dart';
import 'workout_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToLog;

  const HomeScreen({super.key, this.onNavigateToLog});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pageController = PageController();
  int _chartPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = WorkoutRepository.instance;
    final movements = repo.movementProgress();
    final recent = repo.mostRecent;
    final hasData = repo.workouts.isNotEmpty;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Header ──
        SliverToBoxAdapter(child: _buildHeader()),

        if (hasData) ...[
          // ── Hero charts (horizontally scrollable) ──
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(
                  height: 420,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _chartPage = i),
                    children: [
                      const MuscleRadarPage(),
                      ...MuscleGroup.values.map(
                        (g) => MuscleGroupDetailPage(group: g),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildPageDots(),
              ],
            ),
          ),
          // ── Week summary ──
          SliverToBoxAdapter(child: _buildWeekSummary(repo)),
          // ── Recent workout ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text('LAST SESSION', style: CyberTheme.sectionTitle),
            ),
          ),
          if (recent != null)
            SliverToBoxAdapter(
              child: RecentWorkoutCard(
                workout: recent,
                onViewDetails: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WorkoutDetailScreen(workout: recent),
                  ));
                },
                onRepeat: widget.onNavigateToLog,
              ),
            ),
          // ── Movement progression ──
          if (movements.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child:
                    Text('LIFT PROGRESSION', style: CyberTheme.sectionTitle),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: movements.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) =>
                      MovementCard(progress: movements[i]),
                ),
              ),
            ),
          ],
        ] else
          // ── Empty state ──
          SliverFillRemaining(child: _buildEmptyState()),

        // Bottom padding for nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(1 + MuscleGroup.values.length, (i) {
        final isActive = _chartPage == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isActive ? 22 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? CyberTheme.neonCyan
                : CyberTheme.textMuted.withValues(alpha: 0.25),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: CyberTheme.neonCyan.withValues(alpha: 0.4),
                      blurRadius: 6,
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Column(
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'w',
                    style: GoogleFonts.orbitron(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: CyberTheme.neonCyan,
                      letterSpacing: 1,
                    ),
                  ),
                  TextSpan(
                    text: 'TRACKER',
                    style: GoogleFonts.orbitron(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: CyberTheme.textPrimary,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: CyberTheme.neonYellow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: CyberTheme.neonYellow.withValues(alpha: 0.6)),
              ),
              child: Text(
                'premium by default',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: CyberTheme.neonYellow,
                  letterSpacing: 1,
                ),
              ),
            )
            ,
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSummary(WorkoutRepository repo) {
    final summary = repo.weekSummary();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('THIS WEEK', style: CyberTheme.sectionTitle),
          ),
          Row(
            children: [
              _statChip(
                '${summary.exercises}',
                'EXERCISES',
                CyberTheme.neonCyan,
              ),
              const SizedBox(width: 8),
              _statChip(
                '${summary.sets}',
                'SETS',
                CyberTheme.neonPurple,
              ),
              const SizedBox(width: 8),
              _statChip(
                '${summary.progressed}',
                'IMPROVED',
                CyberTheme.neonYellow,
              ),
              const SizedBox(width: 8),
              _statChip(
                '${summary.prs}',
                'PRs',
                CyberTheme.neonGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color accent) {
    return Expanded(
      child: CyberCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        glowColor: accent,
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: CyberTheme.statLabel.copyWith(fontSize: 8),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: CyberTheme.neonCyan.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.fitness_center_outlined,
                size: 36,
                color: CyberTheme.neonCyan.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'NO DATA YET',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CyberTheme.textSecondary,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Log your first workout to start\ntracking your strength progress.',
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(
                fontSize: 15,
                color: CyberTheme.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: widget.onNavigateToLog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: CyberTheme.accentGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: CyberTheme.neonCyan.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Text(
                  'LOG FIRST WORKOUT',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

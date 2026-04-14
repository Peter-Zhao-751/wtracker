import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets/strength_chart.dart';
import '../widgets/recent_workout_card.dart';
import '../widgets/movement_card.dart';
import '../widgets/cyber_card.dart';
import 'workout_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onNavigateToLog;

  const HomeScreen({super.key, this.onNavigateToLog});

  @override
  Widget build(BuildContext context) {
    final repo = WorkoutRepository.instance;
    final strengthData = repo.strengthHistory();
    final movements = repo.movementProgress();
    final recent = repo.mostRecent;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Header ──
        SliverToBoxAdapter(child: _buildHeader(repo)),
        // ── Strength chart ──
        SliverToBoxAdapter(
          child: StrengthChart(
            data: strengthData,
            currentScore: repo.currentStrengthScore,
            changePercent: repo.strengthChangePercent,
          ),
        ),
        // ── Quick stats ──
        SliverToBoxAdapter(child: _buildQuickStats(repo)),
        // ── Section label ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text('LAST SESSION', style: CyberTheme.sectionTitle),
          ),
        ),
        // ── Recent workout ──
        if (recent != null)
          SliverToBoxAdapter(
            child: RecentWorkoutCard(
              workout: recent,
              onViewDetails: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WorkoutDetailScreen(workout: recent),
                ));
              },
              onRepeat: onNavigateToLog,
            ),
          ),
        // ── Section label ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text('LIFT PROGRESSION', style: CyberTheme.sectionTitle),
          ),
        ),
        // ── Movement cards ──
        SliverToBoxAdapter(
          child: SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: movements.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => MovementCard(progress: movements[i]),
            ),
          ),
        ),
        // Bottom padding for nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildHeader(WorkoutRepository repo) {
    final thisWeek = repo.workoutsThisWeek();
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROGRESS',
                  style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: CyberTheme.textPrimary,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$thisWeek workout${thisWeek == 1 ? '' : 's'} this week',
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: CyberTheme.textMuted,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: CyberTheme.textMuted.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.person_outline,
                size: 18,
                color: CyberTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(WorkoutRepository repo) {
    final thisWeek = repo.workoutsThisWeek();
    final total = repo.workouts.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _statChip(
            repo.currentStrengthScore.toStringAsFixed(0),
            'SCORE',
            CyberTheme.neonCyan,
          ),
          const SizedBox(width: 10),
          _statChip(
            '${repo.strengthChangePercent >= 0 ? '+' : ''}${repo.strengthChangePercent.toStringAsFixed(1)}%',
            'THIS MONTH',
            repo.strengthChangePercent >= 0
                ? CyberTheme.neonGreen
                : CyberTheme.neonMagenta,
          ),
          const SizedBox(width: 10),
          _statChip(
            '$thisWeek / $total',
            'WEEK / ALL',
            CyberTheme.neonPurple,
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
}

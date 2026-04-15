import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../data.dart';
import '../models.dart';
import '../widgets/cyber_card.dart';
import 'workout_detail_screen.dart';

class PastWorkoutsScreen extends StatefulWidget {
  const PastWorkoutsScreen({super.key});

  @override
  State<PastWorkoutsScreen> createState() => _PastWorkoutsScreenState();
}

class _PastWorkoutsScreenState extends State<PastWorkoutsScreen> {
  int _filterIndex = 0; // 0=All, 1=This month, 2+=by starred exercise
  static const _baseFilters = ['ALL', 'THIS MONTH'];

  List<String> get _filters => [
        ..._baseFilters,
        ...WorkoutRepository.instance.starredExerciseNames
            .map((e) => e.toUpperCase()),
      ];

  List<Workout> get _filteredWorkouts {
    final all = WorkoutRepository.instance.workouts;
    switch (_filterIndex) {
      case 0:
        return all;
      case 1:
        final now = DateTime.now();
        return all
            .where(
                (w) => w.date.year == now.year && w.date.month == now.month)
            .toList();
      default:
        final starred = WorkoutRepository.instance.starredExerciseNames;
        final liftIdx = _filterIndex - _baseFilters.length;
        if (liftIdx >= 0 && liftIdx < starred.length) {
          final lift = starred[liftIdx];
          return all
              .where(
                  (w) => w.exercises.any((e) => e.exerciseName == lift))
              .toList();
        }
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final workouts = _filteredWorkouts;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildFilters()),
        if (workouts.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history,
                      size: 48,
                      color: CyberTheme.textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No workouts found',
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      color: CyberTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildWorkoutTile(workouts[index]),
              childCount: workouts.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Text(
          'HISTORY',
          style: GoogleFonts.orbitron(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: CyberTheme.textPrimary,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final isActive = _filterIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? CyberTheme.neonCyan.withValues(alpha: 0.15)
                    : CyberTheme.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? CyberTheme.neonCyan.withValues(alpha: 0.4)
                      : CyberTheme.textMuted.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                _filters[i],
                style: CyberTheme.chipText.copyWith(
                  color:
                      isActive ? CyberTheme.neonCyan : CyberTheme.textMuted,
                  fontSize: 9,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkoutTile(Workout workout) {
    return CyberCard(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WorkoutDetailScreen(workout: workout),
        ));
      },
      glowColor: workout.hasPR ? CyberTheme.neonGreen : CyberTheme.neonCyan,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Date badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CyberTheme.bgSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('d').format(workout.date),
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CyberTheme.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(workout.date).toUpperCase(),
                  style: GoogleFonts.orbitron(
                    fontSize: 8,
                    color: CyberTheme.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workout.title, style: CyberTheme.cardTitle),
                const SizedBox(height: 4),
                Text(
                  '${workout.exerciseCount} exercises · ${workout.totalSets} sets · ${_formatVol(workout.totalVolume)}',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    color: CyberTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // PR badge or chevron
          if (workout.hasPR)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CyberTheme.neonGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: CyberTheme.neonGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'PR',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: CyberTheme.neonGreen,
                ),
              ),
            )
          else
            Icon(Icons.chevron_right,
                size: 20,
                color: CyberTheme.textMuted.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  String _formatVol(double v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k lb';
    return '${v.toStringAsFixed(0)} lb';
  }
}

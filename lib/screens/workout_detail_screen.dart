import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models.dart';
import '../exercise_info.dart';
import '../widgets/cyber_card.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final Workout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.bgDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildSummaryBar()),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildExerciseSection(workout.exercises[i]),
              childCount: workout.exercises.length,
            ),
          ),
          if (workout.notes != null && workout.notes!.isNotEmpty)
            SliverToBoxAdapter(child: _buildNotes()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: CyberTheme.bgDark,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        color: CyberTheme.textSecondary,
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workout.title,
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: CyberTheme.textPrimary,
              letterSpacing: 1,
            ),
          ),
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(workout.date),
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              color: CyberTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration:
          CyberTheme.cardDecoration(glowColor: CyberTheme.neonPurple),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(workout.durationFormatted, 'DURATION'),
          _divider(),
          _summaryItem('${workout.exerciseCount}', 'EXERCISES'),
          _divider(),
          _summaryItem('${workout.totalSets}', 'SETS'),
          _divider(),
          _summaryItem(_formatVol(workout.totalVolume), 'VOLUME'),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: CyberTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: CyberTheme.statLabel.copyWith(fontSize: 8)),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: CyberTheme.textMuted.withValues(alpha: 0.2),
    );
  }

  Widget _buildExerciseSection(ExerciseEntry entry) {
    final info = getExerciseInfo(entry.exerciseName);
    final accentColor = entry.hasPR
        ? CyberTheme.neonGreen
        : (info?.color ?? CyberTheme.neonCyan);

    return CyberCard(
      glowColor: accentColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExerciseAvatar(exerciseName: entry.exerciseName, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(entry.exerciseName, style: CyberTheme.cardTitle),
              ),
              Text(
                _formatVol(entry.totalVolume),
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  color: CyberTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Header row
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text('SET',
                    style: CyberTheme.statLabel.copyWith(fontSize: 9)),
              ),
              Expanded(
                child: Text('WEIGHT',
                    style: CyberTheme.statLabel.copyWith(fontSize: 9)),
              ),
              Expanded(
                child: Text('REPS',
                    style: CyberTheme.statLabel.copyWith(fontSize: 9)),
              ),
              SizedBox(
                width: 50,
                child: Text('E1RM',
                    style: CyberTheme.statLabel.copyWith(fontSize: 9),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(entry.sets.length, (i) {
            final s = entry.sets[i];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: CyberTheme.textMuted.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        color: CyberTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${s.weight.toStringAsFixed(0)} lb',
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: s.isPersonalRecord
                            ? CyberTheme.neonGreen
                            : CyberTheme.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${s.reps}',
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CyberTheme.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      s.estimated1RM.toStringAsFixed(0),
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        color: s.isPersonalRecord
                            ? CyberTheme.neonGreen
                            : CyberTheme.textMuted,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  if (s.isPersonalRecord) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            CyberTheme.neonGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: CyberTheme.neonGreen
                                .withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        'PR',
                        style: GoogleFonts.orbitron(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: CyberTheme.neonGreen,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return CyberCard(
      glowColor: CyberTheme.neonYellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NOTES', style: CyberTheme.sectionTitle),
          const SizedBox(height: 8),
          Text(
            workout.notes!,
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              color: CyberTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatVol(double v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

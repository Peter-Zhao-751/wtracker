import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models.dart';
import 'cyber_card.dart';

class RecentWorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback? onViewDetails;
  final VoidCallback? onRepeat;

  const RecentWorkoutCard({
    super.key,
    required this.workout,
    this.onViewDetails,
    this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      glowColor: CyberTheme.neonPurple,
      showCornerAccents: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildStats(),
          const SizedBox(height: 14),
          _buildHighlights(),
          const SizedBox(height: 16),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [CyberTheme.neonCyan, CyberTheme.neonPurple],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LAST SESSION',
                style: CyberTheme.chipText.copyWith(
                  color: CyberTheme.neonPurple.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                workout.title,
                style: CyberTheme.cardTitle.copyWith(fontSize: 17),
              ),
            ],
          ),
        ),
        Text(
          DateFormat('MMM d').format(workout.date),
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: CyberTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CyberTheme.bgSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(workout.durationFormatted, 'DURATION'),
          _divider(),
          _stat('${workout.exerciseCount}', 'EXERCISES'),
          _divider(),
          _stat('${workout.totalSets}', 'SETS'),
          _divider(),
          _stat(_formatVolume(workout.totalVolume), 'VOLUME'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 14,
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
      height: 24,
      color: CyberTheme.textMuted.withValues(alpha: 0.2),
    );
  }

  Widget _buildHighlights() {
    final highlights = workout.exercises.take(3).map((ex) {
      final best = ex.bestSet;
      return _highlightRow(
        ex.exerciseName,
        '${best.weight.toStringAsFixed(0)} × ${best.reps}',
        best.isPersonalRecord,
      );
    }).toList();

    return Column(children: highlights);
  }

  Widget _highlightRow(String name, String detail, bool isPR) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPR ? CyberTheme.neonGreen : CyberTheme.textMuted,
              boxShadow: isPR
                  ? [
                      BoxShadow(
                        color: CyberTheme.neonGreen.withValues(alpha: 0.5),
                        blurRadius: 6,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CyberTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            detail,
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPR ? CyberTheme.neonGreen : CyberTheme.textPrimary,
            ),
          ),
          if (isPR) ...[
            const SizedBox(width: 6),
            Text(
              'PR',
              style: GoogleFonts.orbitron(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: CyberTheme.neonGreen,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onViewDetails,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: CyberTheme.neonCyan.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                'VIEW DETAILS',
                style: CyberTheme.chipText.copyWith(
                  color: CyberTheme.neonCyan,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onRepeat,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CyberTheme.neonCyan.withValues(alpha: 0.15),
                    CyberTheme.neonPurple.withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(
                  color: CyberTheme.neonPurple.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                'REPEAT',
                style: CyberTheme.chipText.copyWith(
                  color: CyberTheme.neonPurple,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 10000) {
      return '${(volume / 1000).toStringAsFixed(1)}k';
    }
    return volume.toStringAsFixed(0);
  }
}

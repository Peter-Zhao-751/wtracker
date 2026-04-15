import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models.dart';
import '../data.dart';
import '../exercise_info.dart';
import '../widgets/cyber_card.dart';
import 'log_workout_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  bool _editing = false;
  late Workout _workout;

  // Edit state
  late TextEditingController _titleController;
  late DateTime _date;
  late List<_EditExercise> _exercises;

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
    _titleController = TextEditingController(text: _workout.title);
    _date = _workout.date;
    _exercises = [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _disposeExercises();
    super.dispose();
  }

  void _disposeExercises() {
    for (final ex in _exercises) {
      ex.dispose();
    }
  }

  void _enterEditMode() {
    _disposeExercises();
    _titleController.text = _workout.title;
    _date = _workout.date;
    _exercises = _workout.exercises.map((e) => _EditExercise.fromEntry(e)).toList();
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    _disposeExercises();
    _exercises = [];
    setState(() => _editing = false);
  }

  void _saveEdit() {
    final exercises = <ExerciseEntry>[];
    for (final ex in _exercises) {
      final sets = <WorkoutSet>[];
      for (final s in ex.sets) {
        final w = double.tryParse(s.weightController.text);
        final r = int.tryParse(s.repsController.text);
        if (w != null && r != null && w > 0 && r > 0) {
          sets.add(WorkoutSet(weight: w, reps: r));
        }
      }
      if (sets.isNotEmpty) {
        exercises.add(ExerciseEntry(exerciseName: ex.name, sets: sets));
      }
    }

    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Need at least one exercise with valid sets',
              style: GoogleFonts.rajdhani(color: Colors.white)),
          backgroundColor: CyberTheme.neonMagenta.withValues(alpha: 0.8),
        ),
      );
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? 'Workout'
        : _titleController.text.trim();

    final updated = Workout(
      id: _workout.id,
      date: _date,
      title: title,
      duration: _workout.duration,
      exercises: exercises,
      notes: _workout.notes,
    );

    final saved = WorkoutRepository.instance.updateWorkout(updated);
    _disposeExercises();
    _exercises = [];
    setState(() {
      _workout = saved;
      _editing = false;
    });
  }

  void _deleteWorkout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CyberTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CyberTheme.neonMagenta.withValues(alpha: 0.3)),
        ),
        title: Text('DELETE WORKOUT?',
            style: GoogleFonts.orbitron(
                fontSize: 14, fontWeight: FontWeight.w700, color: CyberTheme.neonMagenta)),
        content: Text('This cannot be undone.',
            style: GoogleFonts.rajdhani(fontSize: 14, color: CyberTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: GoogleFonts.orbitron(fontSize: 11, color: CyberTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              WorkoutRepository.instance.deleteWorkout(_workout.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('DELETE',
                style: GoogleFonts.orbitron(fontSize: 11, color: CyberTheme.neonMagenta)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.bgDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          if (!_editing) ...[
            SliverToBoxAdapter(child: _buildSummaryBar()),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildExerciseSection(_workout.exercises[i]),
                childCount: _workout.exercises.length,
              ),
            ),
            if (_workout.notes != null && _workout.notes!.isNotEmpty)
              SliverToBoxAdapter(child: _buildNotes()),
          ] else ...[
            SliverToBoxAdapter(child: _buildEditHeader()),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildEditExerciseCard(i),
                childCount: _exercises.length,
              ),
            ),
            SliverToBoxAdapter(child: _buildAddExerciseButton()),
            SliverToBoxAdapter(child: _buildEditActions()),
          ],
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
        onPressed: () {
          if (_editing) {
            _cancelEdit();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editing ? 'EDITING' : _workout.title,
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _editing ? CyberTheme.neonCyan : CyberTheme.textPrimary,
              letterSpacing: 1,
            ),
          ),
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(_editing ? _date : _workout.date),
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              color: CyberTheme.textMuted,
            ),
          ),
        ],
      ),
      actions: [
        if (!_editing)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: CyberTheme.neonCyan,
            onPressed: _enterEditMode,
          ),
        if (!_editing)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: CyberTheme.neonMagenta.withValues(alpha: 0.7),
            onPressed: _deleteWorkout,
          ),
      ],
    );
  }

  // ── View Mode Widgets ──

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration:
          CyberTheme.cardDecoration(glowColor: CyberTheme.neonPurple),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(_workout.durationFormatted, 'DURATION'),
          _divider(),
          _summaryItem('${_workout.exerciseCount}', 'EXERCISES'),
          _divider(),
          _summaryItem('${_workout.totalSets}', 'SETS'),
          _divider(),
          _summaryItem(_formatVol(_workout.totalVolume), 'VOLUME'),
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
            _workout.notes!,
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

  // ── Edit Mode Widgets ──

  Widget _buildEditHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: CyberTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CyberTheme.textMuted.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: CyberTheme.textMuted),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(_date),
                    style: GoogleFonts.rajdhani(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CyberTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleController,
            style: GoogleFonts.rajdhani(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CyberTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Workout name',
              prefixIcon: const Icon(Icons.fitness_center_outlined,
                  size: 18, color: CyberTheme.textMuted),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditExerciseCard(int exerciseIndex) {
    final ex = _exercises[exerciseIndex];
    final info = getExerciseInfo(ex.name);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: CyberTheme.cardDecoration(
        glowColor: info?.color ?? CyberTheme.neonCyan,
        borderOpacity: 0.12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExerciseAvatar(exerciseName: ex.name, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(ex.name, style: CyberTheme.cardTitle),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _exercises[exerciseIndex].dispose();
                    _exercises.removeAt(exerciseIndex);
                  }),
                  child: Icon(Icons.close,
                      size: 18,
                      color: CyberTheme.textMuted.withValues(alpha: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('SET',
                        style: CyberTheme.statLabel.copyWith(fontSize: 9)),
                  ),
                  Expanded(
                    child: Text('WEIGHT (LB)',
                        style: CyberTheme.statLabel.copyWith(fontSize: 9)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('REPS',
                        style: CyberTheme.statLabel.copyWith(fontSize: 9)),
                  ),
                  const SizedBox(width: 30),
                ],
              ),
            ),
            ...List.generate(ex.sets.length, (setIndex) {
              final set = ex.sets[setIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${setIndex + 1}',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          color: CyberTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _numField(set.weightController, 'lbs'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _numField(set.repsController, 'reps'),
                    ),
                    SizedBox(
                      width: 30,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          ex.sets[setIndex].dispose();
                          ex.sets.removeAt(setIndex);
                        }),
                        child: Icon(Icons.remove_circle_outline,
                            size: 16,
                            color: CyberTheme.neonMagenta
                                .withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() {
                ex.sets.add(_EditSet());
              }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: CyberTheme.textMuted.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add,
                        size: 14,
                        color: CyberTheme.textMuted.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      'ADD SET',
                      style: CyberTheme.chipText.copyWith(
                        color: CyberTheme.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController controller, String hint) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: GoogleFonts.orbitron(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CyberTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildAddExerciseButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: _showExercisePicker,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: CyberTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: CyberTheme.neonCyan.withValues(alpha: 0.2),
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline,
                  size: 18,
                  color: CyberTheme.neonCyan.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text(
                'ADD EXERCISE',
                style: CyberTheme.chipText.copyWith(
                  color: CyberTheme.neonCyan,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: _saveEdit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: CyberTheme.accentGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: CyberTheme.neonCyan.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'SAVE CHANGES',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _cancelEdit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: CyberTheme.textMuted.withValues(alpha: 0.3),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'CANCEL',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CyberTheme.textMuted,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: CyberTheme.neonCyan,
              surface: CyberTheme.bgCard,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _showExercisePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CyberTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => ExercisePickerSheet(
        onSelected: (name) {
          Navigator.pop(context);
          setState(() {
            _exercises.add(_EditExercise(name));
          });
        },
      ),
    );
  }

  String _formatVol(double v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ── Edit mode helpers ──

class _EditSet {
  final TextEditingController weightController;
  final TextEditingController repsController;

  _EditSet({String weight = '', String reps = ''})
      : weightController = TextEditingController(text: weight),
        repsController = TextEditingController(text: reps);

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

class _EditExercise {
  final String name;
  final List<_EditSet> sets;

  _EditExercise(this.name) : sets = [_EditSet(), _EditSet(), _EditSet()];

  _EditExercise._(this.name, this.sets);

  factory _EditExercise.fromEntry(ExerciseEntry entry) {
    return _EditExercise._(
      entry.exerciseName,
      entry.sets
          .map((s) => _EditSet(
                weight: s.weight.toStringAsFixed(0),
                reps: s.reps.toString(),
              ))
          .toList(),
    );
  }

  void dispose() {
    for (final s in sets) {
      s.dispose();
    }
  }
}

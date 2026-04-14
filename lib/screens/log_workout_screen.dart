import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models.dart';
import '../data.dart';

class LogWorkoutScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const LogWorkoutScreen({super.key, this.onSaved});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  DateTime _date = DateTime.now();
  final _titleController = TextEditingController(text: '');
  final List<_ExerciseForm> _exercises = [];
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final ex in _exercises) {
      ex.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.bgDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildDateAndTitle()),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildExerciseCard(index),
              childCount: _exercises.length,
            ),
          ),
          SliverToBoxAdapter(child: _buildAddExerciseButton()),
          SliverToBoxAdapter(child: _buildSaveButton()),
          SliverToBoxAdapter(child: _buildCancelButton()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(
          children: [
            Text(
              'LOG WORKOUT',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: CyberTheme.textPrimary,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            _buildTimer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 30)),
      builder: (context, _) {
        final elapsed = DateTime.now().difference(_startTime);
        final m = elapsed.inMinutes;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: CyberTheme.neonCyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: CyberTheme.neonCyan.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: CyberTheme.neonCyan.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                '${m}m',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  color: CyberTheme.neonCyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateAndTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Date picker
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
          // Title field
          TextField(
            controller: _titleController,
            style: GoogleFonts.rajdhani(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CyberTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Workout name (e.g. Upper Body)',
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

  Widget _buildExerciseCard(int exerciseIndex) {
    final ex = _exercises[exerciseIndex];
    final prevBest = WorkoutRepository.instance.previousBest(ex.name);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: CyberTheme.cardDecoration(
        glowColor: CyberTheme.neonCyan,
        borderOpacity: 0.1,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise header
            Row(
              children: [
                Expanded(
                  child: Text(
                    ex.name,
                    style: CyberTheme.cardTitle,
                  ),
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
            if (prevBest != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Previous best: ${prevBest.weight.toStringAsFixed(0)} × ${prevBest.reps}',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    color: CyberTheme.neonCyan.withValues(alpha: 0.6),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Column headers
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('SET',
                        style:
                            CyberTheme.statLabel.copyWith(fontSize: 9)),
                  ),
                  Expanded(
                    child: Text('WEIGHT (LB)',
                        style:
                            CyberTheme.statLabel.copyWith(fontSize: 9)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('REPS',
                        style:
                            CyberTheme.statLabel.copyWith(fontSize: 9)),
                  ),
                  const SizedBox(width: 30),
                ],
              ),
            ),
            // Set rows
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
                            color:
                                CyberTheme.neonMagenta.withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            // Add set button
            GestureDetector(
              onTap: () => setState(() {
                ex.sets.add(_SetForm());
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

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GestureDetector(
        onTap: _saveWorkout,
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
            'SAVE WORKOUT',
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GestureDetector(
        onTap: _cancelWorkout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: CyberTheme.chartGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'CANCEL',
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  void _cancelWorkout() {
    for (final ex in _exercises) {
      ex.dispose();
    }
    Navigator.pop(context);
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
      builder: (context) => _ExercisePickerSheet(
        onSelected: (name) {
          Navigator.pop(context);
          setState(() {
            _exercises.add(_ExerciseForm(name));
          });
        },
      ),
    );
  }

  void _saveWorkout() {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Add at least one exercise',
            style: GoogleFonts.rajdhani(color: Colors.white),
          ),
          backgroundColor: CyberTheme.neonMagenta.withValues(alpha: 0.8),
        ),
      );
      return;
    }

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
          content: Text(
            'Fill in at least one set',
            style: GoogleFonts.rajdhani(color: Colors.white),
          ),
          backgroundColor: CyberTheme.neonMagenta.withValues(alpha: 0.8),
        ),
      );
      return;
    }

    final duration = DateTime.now().difference(_startTime);
    final title = _titleController.text.trim().isEmpty
        ? 'Workout'
        : _titleController.text.trim();

    final workout = Workout(
      id: 'w_${DateTime.now().millisecondsSinceEpoch}',
      date: _date,
      title: title,
      duration: duration,
      exercises: exercises,
    );

    WorkoutRepository.instance.addWorkout(workout);
    widget.onSaved?.call();
  }
}

// ── Form helpers ──

class _ExerciseForm {
  final String name;
  final List<_SetForm> sets;

  _ExerciseForm(this.name) : sets = [_SetForm(), _SetForm(), _SetForm()];

  void dispose() {
    for (final s in sets) {
      s.dispose();
    }
  }
}

class _SetForm {
  final TextEditingController weightController = TextEditingController();
  final TextEditingController repsController = TextEditingController();

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

// ── Exercise picker ──

class _ExercisePickerSheet extends StatefulWidget {
  final ValueChanged<String> onSelected;

  const _ExercisePickerSheet({required this.onSelected});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';

  List<String> get _filtered {
    if (_query.isEmpty) return allExercises;
    final q = _query.toLowerCase();
    return allExercises.where((e) => e.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CyberTheme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SELECT EXERCISE',
                style: CyberTheme.sectionTitle,
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: GoogleFonts.rajdhani(
                  fontSize: 15,
                  color: CyberTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search exercises...',
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: CyberTheme.textMuted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 44, minHeight: 0),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final name = _filtered[i];
                    final isKey = keyLifts.contains(name);
                    return ListTile(
                      onTap: () => widget.onSelected(name),
                      dense: true,
                      leading: Icon(
                        isKey
                            ? Icons.star_outline
                            : Icons.fitness_center_outlined,
                        size: 18,
                        color: isKey
                            ? CyberTheme.neonCyan
                            : CyberTheme.textMuted,
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.rajdhani(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CyberTheme.textPrimary,
                        ),
                      ),
                      trailing: isKey
                          ? Text(
                              'KEY',
                              style: CyberTheme.chipText.copyWith(
                                color: CyberTheme.neonCyan.withValues(alpha: 0.5),
                                fontSize: 8,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

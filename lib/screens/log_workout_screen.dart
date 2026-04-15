import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models.dart';
import '../data.dart';
import '../exercise_info.dart';

class LogWorkoutScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const LogWorkoutScreen({super.key, this.onSaved});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  DateTime _date = DateTime.now();
  final _titleController = TextEditingController();
  final List<_ExerciseForm> _exercises = [];
  late final DateTime _startTime;
  bool _saving = false;

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    final info = getExerciseInfo(ex.name);
    final prevBest = WorkoutRepository.instance.previousBest(ex.name);
    final best1RM = WorkoutRepository.instance.bestEstimated1RM(ex.name);

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
            // Exercise header with avatar
            Row(
              children: [
                ExerciseAvatar(exerciseName: ex.name, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name, style: CyberTheme.cardTitle),
                      if (prevBest != null)
                        Text(
                          'Best: ${prevBest.weight.toStringAsFixed(0)} × ${prevBest.reps}  •  E1RM: ${best1RM.toStringAsFixed(0)} lb',
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            color: CyberTheme.neonCyan.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
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
            const SizedBox(height: 12),
            // Column headers
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
                            color: CyberTheme.neonMagenta
                                .withValues(alpha: 0.4)),
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
      builder: (context) => ExercisePickerSheet(
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
    if (_saving) return;
    _saving = true;

    if (_exercises.isEmpty) {
      _saving = false;
      _showError('Add at least one exercise');
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
      _saving = false;
      _showError('Fill in at least one set');
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

    // Add with PR detection
    final saved = WorkoutRepository.instance.addWorkout(workout);

    // Show PR celebration if any
    if (saved.hasPR) {
      _showPRCelebration(saved);
    }

    widget.onSaved?.call();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.rajdhani(color: Colors.white)),
        backgroundColor: CyberTheme.neonMagenta.withValues(alpha: 0.8),
      ),
    );
  }

  void _showPRCelebration(Workout workout) {
    final prExercises = workout.prExercises;
    final prDetails = <String>[];
    for (final ex in workout.exercises) {
      for (final s in ex.sets) {
        if (s.isPersonalRecord) {
          prDetails.add(
              '${ex.exerciseName}: ${s.estimated1RM.toStringAsFixed(0)} lb e1RM');
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: CyberTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: CyberTheme.neonGreen.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CyberTheme.neonGreen.withValues(alpha: 0.15),
                  border: Border.all(
                      color: CyberTheme.neonGreen.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: CyberTheme.neonGreen.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.emoji_events,
                    color: CyberTheme.neonGreen, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'NEW PR${prExercises.length > 1 ? 's' : ''}!',
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: CyberTheme.neonGreen,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              ...prDetails.take(5).map((detail) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      detail,
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        color: CyberTheme.textSecondary,
                      ),
                    ),
                  )),
              const SizedBox(height: 8),
              Text(
                'Based on estimated 1-rep max (Epley)',
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  color: CyberTheme.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: CyberTheme.neonGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            CyberTheme.neonGreen.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'NICE',
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: CyberTheme.neonGreen,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

// ── Exercise picker with reorderable list ──

class ExercisePickerSheet extends StatefulWidget {
  final ValueChanged<String> onSelected;

  const ExercisePickerSheet({super.key, required this.onSelected});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  String _query = '';
  final repo = WorkoutRepository.instance;
  late List<ExerciseInfo> _starredList;
  late List<ExerciseInfo> _unstarredList;

  @override
  void initState() {
    super.initState();
    final ordered = repo.orderedExercises;
    _starredList = ordered.where((e) => repo.isStarred(e.name)).toList();
    _unstarredList = ordered.where((e) => !repo.isStarred(e.name)).toList();
  }

  List<ExerciseInfo> get _combined => [..._starredList, ..._unstarredList];

  List<ExerciseInfo> get _filtered {
    if (_query.isEmpty) return _combined;
    final q = _query.toLowerCase();
    return _combined
        .where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.group.name.toLowerCase().contains(q))
        .toList();
  }

  void _saveOrder() {
    repo.reorderExercises(_combined.map((e) => e.name).toList());
  }

  void _toggleStar(ExerciseInfo info) {
    setState(() {
      repo.toggleStar(info.name);
      if (repo.isStarred(info.name)) {
        _unstarredList.remove(info);
        // Insert after the last starred exercise of the same muscle group
        int insertAt = -1;
        for (int i = _starredList.length - 1; i >= 0; i--) {
          if (_starredList[i].group == info.group) {
            insertAt = i + 1;
            break;
          }
        }
        if (insertAt == -1) {
          // No same-group items yet; insert in muscle group order
          insertAt = _starredList.length;
          for (int i = 0; i < _starredList.length; i++) {
            if (_starredList[i].group.index > info.group.index) {
              insertAt = i;
              break;
            }
          }
        }
        _starredList.insert(insertAt, info);
      } else {
        _starredList.remove(info);
        // Insert into unstarred in muscle-group order
        final groupIdx =
            _unstarredList.indexWhere((e) => e.group.index > info.group.index);
        if (groupIdx == -1) {
          _unstarredList.add(info);
        } else {
          _unstarredList.insert(groupIdx, info);
        }
      }
      _saveOrder();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    final sc = _starredList.length;
    if (newIndex > oldIndex) newIndex--;

    final oldIsStarred = oldIndex < sc;
    final newIsStarred = newIndex < sc;

    // Don't allow crossing the starred/unstarred boundary
    if (oldIsStarred != newIsStarred) return;

    setState(() {
      if (oldIsStarred) {
        final item = _starredList.removeAt(oldIndex);
        _starredList.insert(newIndex, item);
      } else {
        final item = _unstarredList.removeAt(oldIndex - sc);
        _unstarredList.insert(newIndex - sc, item);
      }
      _saveOrder();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CyberTheme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('SELECT EXERCISE', style: CyberTheme.sectionTitle),
              const SizedBox(height: 12),
              TextField(
                autofocus: false,
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
                child: isSearching
                    ? _buildSearchResults(scrollController)
                    : _buildReorderableList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(ScrollController controller) {
    final results = _filtered;
    return ListView.builder(
      controller: controller,
      itemCount: results.length,
      itemBuilder: (context, i) {
        final info = results[i];
        return _buildTile(info, i, reorderable: false);
      },
    );
  }

  Widget _buildReorderableList(ScrollController controller) {
    final combined = _combined;
    final sc = _starredList.length;

    return ReorderableListView.builder(
      scrollController: controller,
      buildDefaultDragHandles: false,
      itemCount: combined.length,
      onReorder: _onReorder,
      proxyDecorator: _proxyDecorator,
      itemBuilder: (context, i) {
        final info = combined[i];
        final isStarredSection = i < sc;

        // Section headers
        Widget? sectionHeader;
        if (i == 0 && sc > 0) {
          sectionHeader = _sectionLabel('STARRED', CyberTheme.neonYellow);
        } else if (i == sc) {
          sectionHeader = _sectionLabel('ALL EXERCISES', CyberTheme.textMuted);
        }

        // Group header for unstarred items
        Widget? groupHeader;
        if (!isStarredSection) {
          final isFirstInSection = i == sc;
          final prevDiffGroup =
              !isFirstInSection && combined[i - 1].group != info.group;
          // Also show group header if previous item was in starred section
          if (isFirstInSection || prevDiffGroup) {
            groupHeader = Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Row(
                children: [
                  Text(
                    info.group.name.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: info.color.withValues(alpha: 0.6),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: info.color.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            );
          }
        }

        return Column(
          key: ValueKey(info.name),
          mainAxisSize: MainAxisSize.min,
          children: [
            ?sectionHeader,
            ?groupHeader,
            _buildTile(info, i, reorderable: true),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.orbitron(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _proxyDecorator(
      Widget child, int index, Animation<double> animation) {
    return Material(
      color: CyberTheme.bgCardLight,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CyberTheme.neonCyan.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: CyberTheme.neonCyan.withValues(alpha: 0.15),
              blurRadius: 12,
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildTile(ExerciseInfo info, int index,
      {required bool reorderable}) {
    final isStarred = repo.isStarred(info.name);
    return GestureDetector(
      onTap: () => widget.onSelected(info.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        child: Row(
          children: [
            // Star (left side)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleStar(info),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 22,
                  color: isStarred
                      ? CyberTheme.neonYellow
                      : CyberTheme.textMuted.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Avatar
            ExerciseAvatar(exerciseName: info.name, size: 34),
            const SizedBox(width: 10),
            // Name + group
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    info.name,
                    style: GoogleFonts.rajdhani(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CyberTheme.textPrimary,
                    ),
                  ),
                  Text(
                    info.group.name.toUpperCase(),
                    style: CyberTheme.chipText.copyWith(
                      color: info.color.withValues(alpha: 0.5),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            // Drag handle (right side, only in reorderable mode)
            if (reorderable)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 20,
                    color: CyberTheme.textMuted.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

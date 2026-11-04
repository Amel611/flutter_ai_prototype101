
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _exerciseController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  final _durationController = TextEditingController();

  List<Map<String, dynamic>> _workouts = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  @override
  void dispose() {
    _exerciseController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // LOAD WORKOUTS FROM SUPABASE

  Future<void> _loadWorkouts() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final data = await _supabase
          .from('workout_history')
          .select()
          .eq('user_id', user.id)
          .order('completed_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _workouts = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Could not load workouts: $error');
    }
  }

  // SAVE A NEW WORKOUT

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Please sign in before saving a workout.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final completedAt = DateTime.now().toUtc();

      await _supabase.from('workout_history').insert({
        'user_id': user.id,
        'exercise': _exerciseController.text.trim(),
        'sets': int.parse(_setsController.text.trim()),
        'reps': int.parse(_repsController.text.trim()),
        'weight': int.parse(_weightController.text.trim()),
        'duration_minutes':
            int.parse(_durationController.text.trim()),
            'completed_at': completedAt.toIso8601String(),
      });

      _exerciseController.clear();
      _setsController.clear();
      _repsController.clear();
      _weightController.clear();
      _durationController.clear();

      await _loadWorkouts();

      if (!mounted) return;

      _showMessage('Workout saved successfully!');
    } catch (error) {
      if (!mounted) return;

      _showMessage('Could not save workout: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // FORMAT COMPLETION DATE AND TIME

  String _formatCompletedAt(dynamic value) {
    if (value == null) {
      return 'Date unavailable';
    }

    DateTime? completedAt;

    if (value is DateTime) {
      completedAt = value;
    } else {
      final dateString = value.toString().trim();

      completedAt = DateTime.tryParse(dateString);

      // Handle timestamps that use a space instead of T.
      if (completedAt == null &&
          dateString.contains(' ') &&
          !dateString.contains('T')) {
        completedAt = DateTime.tryParse(
          dateString.replaceFirst(' ', 'T'),
        );
      }
    }

    if (completedAt == null) {
      return 'Date unavailable';
    }

    final localDate = completedAt.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year;

    final hour = localDate.hour % 12 == 0
        ? 12
        : localDate.hour % 12;

    final minute = localDate.minute.toString().padLeft(2, '0');

    final period = localDate.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • $hour:$minute $period';
  }

  // SHOW MESSAGES

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // NUMBER INPUT FIELD

  Widget _numberField(
    TextEditingController controller,
    String label,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Enter $label';
        }

        final number = int.tryParse(value.trim());

        if (number == null || number < 0) {
          return 'Enter a valid whole number';
        }

        return null;
      },
    );
  }

  // WORKOUT CARD

  Widget _workoutCard(Map<String, dynamic> workout) {
    final dateLabel = _formatCompletedAt(
      workout['completed_at'],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.fitness_center),
        ),
        title: Text(
          workout['exercise']?.toString() ?? 'Exercise',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${workout['sets']} sets × ${workout['reps']} reps'
          '\nWeight: ${workout['weight']} kg'
          ' • Duration: ${workout['duration_minutes']} min'
          '\nCompleted: $dateLabel',
        ),
        isThreeLine: true,
      ),
    );
  }

  // MAIN SCREEN

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
      ),

      body: RefreshIndicator(
        onRefresh: _loadWorkouts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // RECORD WORKOUT FORM

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Record a Workout',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _exerciseController,
                        decoration: const InputDecoration(
                          labelText: 'Exercise',
                          hintText: 'e.g. Squats',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Enter an exercise name';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      _numberField(
                        _setsController,
                        'Sets',
                      ),

                      const SizedBox(height: 12),

                      _numberField(
                        _repsController,
                        'Reps',
                      ),

                      const SizedBox(height: 12),

                      _numberField(
                        _weightController,
                        'Weight Used (kg)',
                      ),

                      const SizedBox(height: 12),

                      _numberField(
                        _durationController,
                        'Duration (minutes)',
                      ),

                      const SizedBox(height: 16),

                      FilledButton(
                        onPressed:
                            _isSaving ? null : _saveWorkout,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            _isSaving
                                ? 'Saving...'
                                : 'Save Workout',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // PREVIOUS WORKOUTS

            const Text(
              'Previous Workouts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_workouts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No workouts recorded yet.'),
                ),
              )
            else
              ..._workouts.map(_workoutCard),
          ],
        ),
      ),
    );
  }
}

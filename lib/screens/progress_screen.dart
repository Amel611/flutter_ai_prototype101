
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _workouts = [];

  bool _isLoading = true;
  String? _error;

  int _totalWorkouts = 0;
  int _totalMinutes = 0;
  int _activeDays = 0;

  final List<int> _weeklyActivity = List.filled(7, 0);

  List<String> _weekdays = [];

  final List<String> _weekdayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'Please sign in to view your progress.';
      });
      return;
    }

    try {
      // Load workout history.
      final data = await _supabase
          .from('workout_history')
          .select(
            'exercise, sets, reps, weight, duration_minutes, completed_at',
          )
          .eq('user_id', user.id)
          .order('completed_at', ascending: false);

      // Test read-only access to the progress table.
      final progressTest = await _supabase
          .from('progress')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);

      debugPrint(
        'Progress table connection successful. '
        'Records found: ${progressTest.length}',
      );

      if (!mounted) return;

      final workouts = List<Map<String, dynamic>>.from(data);

      _calculateProgress(workouts);

      setState(() {
        _workouts = workouts;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Progress loading error: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'Could not load progress: $error';
      });
    }
  }

  void _calculateProgress(
    List<Map<String, dynamic>> workouts,
  ) {
    _totalWorkouts = workouts.length;
    _totalMinutes = 0;
    _activeDays = 0;

    _weeklyActivity.fillRange(0, 7, 0);

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    // Start of the rolling 7-day period.
    final sevenDaysAgo = today.subtract(
      const Duration(days: 6),
    );

    // Generate weekday labels in chronological order.
    _weekdays = List.generate(7, (index) {
      final date = sevenDaysAgo.add(Duration(days: index));
      return _weekdayNames[date.weekday - 1];
    });

    final activeDateKeys = <String>{};

    for (final workout in workouts) {
      final duration = int.tryParse(
            workout['duration_minutes']?.toString() ?? '',
          ) ??
          0;

      _totalMinutes += duration;

      final timestamp = DateTime.tryParse(
        workout['completed_at']?.toString() ?? '',
      );

      if (timestamp == null) continue;

      final localDate = timestamp.toLocal();

      final workoutDay = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
      );

      // Ignore workouts outside the last 7 days.
      if (workoutDay.isBefore(sevenDaysAgo) ||
          workoutDay.isAfter(today)) {
        continue;
      }

      // Today always appears at index 6.
      final dayIndex = workoutDay.difference(sevenDaysAgo).inDays;

      _weeklyActivity[dayIndex]++;

      final dateKey =
          '${workoutDay.year}-${workoutDay.month}-${workoutDay.day}';

      activeDateKeys.add(dateKey);
    }

    _activeDays = activeDateKeys.length;
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Date unavailable';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'Date unavailable';

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;

    return '$day/$month/$year';
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weeklyChart() {
    final maxValue = _weeklyActivity.fold<int>(
      0,
      (previous, current) =>
          current > previous ? current : previous,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your workouts over the last 7 days',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final count = _weeklyActivity[index];

                  final barHeight = maxValue == 0
                      ? 0.0
                      : (count / maxValue) * 105;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          count.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: barHeight == 0 ? 4 : barHeight,
                          width: 20,
                          decoration: BoxDecoration(
                            color: Colors.purple.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _weekdays[index],
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentWorkouts() {
    if (_workouts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('No workout history available yet.'),
          ),
        ),
      );
    }

    final recent = _workouts.take(5).toList();

    return Column(
      children: recent.map((workout) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.fitness_center),
            ),
            title: Text(
              workout['exercise']?.toString() ?? 'Exercise',
            ),
            subtitle: Text(
              '${workout['sets']} sets × ${workout['reps']} reps'
              '\n${workout['duration_minutes']} minutes'
              '\n${_formatDate(workout['completed_at'])}',
            ),
            isThreeLine: true,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh progress',
            onPressed: _isLoading ? null : _loadProgress,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadProgress,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProgress,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Your Fitness Journey',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track your activity and stay consistent.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.15,
                        children: [
                          _metricCard(
                            title: 'Total Workouts',
                            value: _totalWorkouts.toString(),
                            subtitle: 'All recorded workouts',
                            icon: Icons.fitness_center,
                            color: Colors.purple,
                          ),
                          _metricCard(
                            title: 'Workout Duration',
                            value: '$_totalMinutes min',
                            subtitle: 'Total recorded minutes',
                            icon: Icons.timer_outlined,
                            color: Colors.teal,
                          ),
                          _metricCard(
                            title: 'Active Days',
                            value: '$_activeDays',
                            subtitle: 'In the last 7 days',
                            icon: Icons.calendar_today,
                            color: Colors.orange,
                          ),
                          _metricCard(
                            title: 'This Week',
                            value: '${_weeklyActivity.reduce(
                              (a, b) => a + b,
                            )}',
                            subtitle: 'Recorded workouts',
                            icon: Icons.trending_up,
                            color: Colors.blue,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _weeklyChart(),

                      const SizedBox(height: 24),

                      const Text(
                        'Recent Workouts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      _recentWorkouts(),
                    ],
                  ),
                ),
    );
  }
}

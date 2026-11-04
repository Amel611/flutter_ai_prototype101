
import 'package:flutter/material.dart';
import '../services/achievement_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() =>
      _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final AchievementService _service = AchievementService();

  late Future<Map<String, dynamic>> _screenData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _screenData = _fetchData();
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final results = await Future.wait([
      _service.getAchievements(),
      _service.getUserAchievements(),
      _service.getUserXP(),
    ]);

    return {
      'achievements': results[0],
      'unlocked': results[1],
      'xp': results[2],
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _loadData();
    });
    await _screenData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _screenData,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load achievements.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final achievements =
              data['achievements'] as List<Map<String, dynamic>>;
          final unlocked =
              data['unlocked'] as List<Map<String, dynamic>>;
          final xp = data['xp'] as Map<String, dynamic>;

          final unlockedIds = unlocked
              .map((item) =>
                  item['achievement_id'].toString())
              .toSet();

          final totalXP =
              (xp['total_xp'] as num?)?.toInt() ?? 0;
          final level = (xp['level'] as num?)?.toInt() ?? 1;

          final unlockedCount = achievements.where((item) {
            return unlockedIds.contains(item['id'].toString());
          }).length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildLevelCard(totalXP, level),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your achievements',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$unlockedCount / ${achievements.length} unlocked',
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (achievements.isEmpty)
                  const Center(
                    child: Text('No achievements available yet.'),
                  ),

                ...achievements.map((achievement) {
                  final isUnlocked = unlockedIds.contains(
                    achievement['id'].toString(),
                  );

                  return _buildAchievementCard(
                    achievement,
                    isUnlocked,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLevelCard(int totalXP, int level) {
    final currentLevelXP = totalXP % 100;
    final progress = currentLevelXP / 100;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR FITNESS LEVEL',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.stars_rounded,
                  size: 42,
                  color: Colors.amber,
                ),
                const SizedBox(width: 12),
                Text(
                  'Level $level',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalXP XP',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              '$currentLevelXP / 100 XP to the next level',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(
    Map<String, dynamic> achievement,
    bool isUnlocked,
  ) {
    final reward = achievement['reward']?.toString() ?? '';
    final description =
        achievement['description']?.toString() ?? '';
    final category =
        achievement['category']?.toString() ?? '';
    final icon = achievement['icon']?.toString() ?? '🏆';
    final points =
        (achievement['points'] as num?)?.toInt() ?? 0;
    final xpReward =
        (achievement['xp_reward'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUnlocked ? 2 : 0,
      color: isUnlocked
          ? Colors.green.withValues(alpha: 0.08)
          : Colors.grey.withValues(alpha: 0.06),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 27,
          backgroundColor: isUnlocked
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          child: Text(
            isUnlocked ? icon : '🔒',
            style: const TextStyle(fontSize: 25),
          ),
        ),
        title: Text(
          reward,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 5),
              Text(
                '$category • $points points • $xpReward XP',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        trailing: Icon(
          isUnlocked ? Icons.check_circle : Icons.lock_outline,
          color: isUnlocked ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}

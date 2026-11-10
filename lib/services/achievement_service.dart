
import 'package:supabase_flutter/supabase_flutter.dart';

class AchievementService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Load all active achievement definitions.
  Future<List<Map<String, dynamic>>> getAchievements() async {
    try {
      final response = await _supabase
          .from('achievements')
          .select()
          .eq('is_active', true)
          .order('id');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Could not load achievements: $e');
    }
  }

  /// Load achievements unlocked by the current user.
  Future<List<Map<String, dynamic>>> getUserAchievements() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    try {
      final response = await _supabase
          .from('user_achievements')
          .select('achievement_id, unlocked_at')
          .eq('user_id', user.id)
          .order('unlocked_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Could not load unlocked achievements: $e');
    }
  }

  /// Load the current user's XP and level.
  Future<Map<String, dynamic>> getUserXP() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    try {
      final response = await _supabase
          .from('user_xp')
          .select('total_xp, level')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        return {
          'total_xp': 0,
          'level': 1,
        };
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Could not load XP: $e');
    }
  }

  /// Unlock an achievement.
  ///
  /// Supabase automatically awards 100 XP through the
  /// award_achievement_xp database trigger.
  /// Flutter must not award XP separately.
  Future<void> unlockAchievement(
    Map<String, dynamic> achievement,
  ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    final achievementId = achievement['id'];

    if (achievementId == null) {
      throw Exception('Invalid achievement ID.');
    }

    try {
      // Check whether the achievement is already unlocked.
      final existing = await _supabase
          .from('user_achievements')
          .select('id')
          .eq('user_id', user.id)
          .eq('achievement_id', achievementId)
          .maybeSingle();

      if (existing != null) {
        return;
      }

      // Insert the unlocked achievement.
      // The database trigger automatically awards 100 XP.
      await _supabase.from('user_achievements').insert({
        'user_id': user.id,
        'achievement_id': achievementId,
      });
    } catch (e) {
      throw Exception('Could not unlock achievement: $e');
    }
  }
}

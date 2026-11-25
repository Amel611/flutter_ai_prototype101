import 'package:supabase_flutter/supabase_flutter.dart';

class WellnessAIService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
  }) async {
    final response = await _supabase.functions.invoke(
      'wellness-assistant',
      body: {
        'message': message,
        'history': history,
      },
    );

    if (response.status != 200) {
      throw Exception('AI request failed: ${response.data}');
    }

    final data = response.data;

    if (data == null || data['reply'] == null) {
      throw Exception('The AI returned an empty response.');
    }

    return data['reply'] as String;
  }
}
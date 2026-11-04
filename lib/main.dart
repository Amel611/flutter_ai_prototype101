
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nmawimakwlutcmxmmfmh.supabase.co',
    publishableKey: 'sb_publishable_wIylibm1mnnNo8To9ibx-g_6EwjXS5e');

  runApp(const WellnessAIApp());
} 

class WellnessAIApp extends StatelessWidget {
  const WellnessAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Interactive Social Wellness App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(205, 149, 12, 154),
        ),
        useMaterial3: true,
      ),
      home: Supabase.instance.client.auth.currentSession == null
          ? const AuthScreen()
          : const WellnessHomeScreen(),
    );
  }
}

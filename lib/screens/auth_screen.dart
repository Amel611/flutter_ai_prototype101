
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_screens.dart';
import 'workout_history_screen.dart';
import 'progress_screen.dart';
import 'achievements_screen.dart';

// ==========================================
// AUTHENTICATION SCREEN
// ==========================================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      final email = emailController.text.trim();
      final password = passwordController.text;

      if (isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (!mounted) return;

        if (response.session == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created. Please check your email to confirm your account.',
              ),
            ),
          );

          setState(() {
            isLogin = true;
          });

          return;
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const WellnessHomeScreen(),
        ),
        (route) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellness AI Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.favorite,
                    size: 64,
                    color: Colors.pink,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    isLogin
                        ? 'Welcome back'
                        : 'Create your account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall,
                  ),

                  const SizedBox(height: 24),

                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null ||
                          !value.contains('@') ||
                          !value.contains('.')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: isLoading ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        isLoading
                            ? 'Please wait...'
                            : isLogin
                                ? 'Log in'
                                : 'Sign up',
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(() {
                              isLogin = !isLogin;
                            });
                          },
                    child: Text(
                      isLogin
                          ? 'New here? Create an account'
                          : 'Already registered? Log in',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// WELLNESS AI DASHBOARD
// ==========================================

class WellnessHomeScreen extends StatelessWidget {
  const WellnessHomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not log out: $error'),
        ),
      );
    }
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  void _openWorkoutHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WorkoutHistoryScreen(),
      ),
    );
  }

  void _openProgress(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProgressScreen(),
      ),
    );
  }

  // NEW: Open Achievements and XP screen
  void _openAchievements(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AchievementsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellness AI'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              const Text(
                'Welcome to Wellness AI',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                user?.email ?? 'Welcome back!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Your Wellness Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // 1. MY PROFILE

              _DashboardCard(
                title: 'My Profile',
                description:
                    'Manage your personal information, health background, '
                    'fitness goals and wellness preferences.',
                icon: Icons.person_outline,
                color: Colors.purple,
                onTap: () => _openProfile(context),
              ),

              const SizedBox(height: 16),

              // 2. WORKOUT HISTORY

              _DashboardCard(
                title: 'Workout History',
                description:
                    'Record your exercises, sets, repetitions, '
                    'weights and workout duration.',
                icon: Icons.fitness_center,
                color: Colors.teal,
                onTap: () => _openWorkoutHistory(context),
              ),

              const SizedBox(height: 16),

              // 3. MY PROGRESS

              _DashboardCard(
                title: 'My Progress',
                description:
                    'Track your workout duration, weekly activity '
                    'and fitness progress through charts and statistics.',
                icon: Icons.show_chart,
                color: Colors.deepPurple,
                onTap: () => _openProgress(context),
              ),

              const SizedBox(height: 16),

              // 4. ACHIEVEMENTS & XP

              _DashboardCard(
                title: 'Achievements & XP',
                description:
                    'View your earned badges, track your XP points '
                    'and monitor your fitness level.',
                icon: Icons.emoji_events_outlined,
                color: Colors.orange,
                onTap: () => _openAchievements(context),
              ),

              const SizedBox(height: 24),

              const Divider(),

              const SizedBox(height: 12),

              const Center(
                child: Text(
                  'Your wellness journey starts here.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
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

// ==========================================
// REUSABLE DASHBOARD CARD
// ==========================================

class _DashboardCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

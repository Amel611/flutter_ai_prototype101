import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController healthBackgroundController =
      TextEditingController();

  String? selectedGender;
  String? selectedGoal;
  String? selectedActivityLevel;
  String? selectedDietaryPreference;

  bool periodStarted = false;
  DateTime? periodStartDate;
  bool isSavingCycle = false;
  bool isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadCycleData();
    _loadFitnessGoal();
  }

  @override
  void dispose() {
    nameController.dispose();
    dobController.dispose();
    heightController.dispose();
    weightController.dispose();
    healthBackgroundController.dispose();
    super.dispose();
  }

  Future<void> _selectPeriodStartDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: periodStartDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Select period start date',
    );

    if (pickedDate != null && mounted) {
      setState(() {
        periodStartDate = pickedDate;
        periodStarted = true;
      });
    }
  }

  Future<void> _loadCycleData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final result = await Supabase.instance.client
          .from('cycle_data')
          .select('period_start')
          .eq('user_id', user.id)
          .order('period_start', ascending: false)
          .limit(1);

      if (!mounted || result.isEmpty) return;

      final savedDate = DateTime.tryParse(
        result.first['period_start'].toString(),
      );

      if (savedDate != null) {
        setState(() {
          periodStartDate = savedDate;
          periodStarted = true;
        });
      }
    } catch (error) {
      debugPrint('Could not load cycle data: $error');
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final result = await Supabase.instance.client
          .from('profiles')
          .select(
            'full_name, dob, height, weight, health_background, gender, bmi',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (result == null || !mounted) return;

      setState(() {
        nameController.text = result['full_name']?.toString() ?? '';
        dobController.text = result['dob']?.toString() ?? '';
        heightController.text = result['height']?.toString() ?? '';
        weightController.text = result['weight']?.toString() ?? '';
        healthBackgroundController.text =
            result['health_background']?.toString() ?? '';

        final savedGender = result['gender']?.toString();
        if (savedGender == 'Male' || savedGender == 'Female') {
          selectedGender = savedGender;
        }
      });
    } catch (error) {
      debugPrint('Could not load profile data: $error');
    }
  }

  Future<void> _loadFitnessGoal() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final result = await Supabase.instance.client
          .from('fitness_goal')
          .select('goal, activity_level, dietary_preference')
          .eq('user_id', user.id)
          .limit(1);

      if (result.isEmpty || !mounted) return;

      final savedGoal = result.first['goal'] as String?;
      final savedActivityLevel =
          result.first['activity_level'] as String?;
      final savedDietaryPreference =
          result.first['dietary_preference'] as String?;

      const validPreferences = [
        'No preference',
        'High protein',
        'Vegetarian',
        'Vegan',
        'Dairy-free',
        'Gluten-free',
        'Low-Salt',
      ];

      setState(() {
        if (savedGoal != null) {
          selectedGoal = savedGoal;
        }

        if (savedActivityLevel != null) {
          selectedActivityLevel = savedActivityLevel;
        }

        if (savedDietaryPreference != null &&
            validPreferences.contains(savedDietaryPreference)) {
          selectedDietaryPreference = savedDietaryPreference;
        }
      });
    } catch (error) {
      debugPrint('Could not load fitness goal: $error');
    }
  }

  Future<void> _saveCycleData() async {
    if (periodStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your period start date.'),
        ),
      );
      return;
    }

    if (isSavingCycle) return;

    setState(() {
      isSavingCycle = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('Please log in before saving cycle data.');
      }

      final date = periodStartDate!;
      final formattedDate =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      final existing = await Supabase.instance.client
          .from('cycle_data')
          .select('id')
          .eq('user_id', user.id)
          .order('period_start', ascending: false)
          .limit(1);

      if (existing.isNotEmpty) {
        final existingId = existing.first['id'];

        final updated = await Supabase.instance.client
            .from('cycle_data')
            .update({'period_start': formattedDate})
            .eq('id', existingId)
            .eq('user_id', user.id)
            .select();

        if (updated.isEmpty) {
          throw Exception(
            'No cycle record was updated. Check the UPDATE RLS policy.',
          );
        }

        debugPrint('Updated cycle rows: $updated');
      } else {
        final inserted = await Supabase.instance.client
            .from('cycle_data')
            .insert({
              'user_id': user.id,
              'period_start': formattedDate,
            })
            .select()
            .single();

        debugPrint('Inserted cycle row: $inserted');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Period start date saved successfully!'),
        ),
      );
    } catch (error) {
      debugPrint('Cycle save error: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save cycle data: $error'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingCycle = false;
        });
      }
    }
  }

  Future<void> _saveFitnessGoal() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('Please log in before saving your fitness goal.');
    }

    if (selectedGoal == null || selectedActivityLevel == null) {
      throw Exception('Please select a fitness goal and activity level.');
    }

    final supabase = Supabase.instance.client;

    final existing = await supabase
        .from('fitness_goal')
        .select('id')
        .eq('user_id', user.id)
        .limit(1);

    final goalData = <String, dynamic>{
      'user_id': user.id,
      'goal': selectedGoal,
      'activity_level': selectedActivityLevel,
      'dietary_preference': selectedDietaryPreference,
    };

    if (existing.isNotEmpty) {
      final existingId = existing.first['id'];

      final updated = await supabase
          .from('fitness_goal')
          .update(goalData)
          .eq('id', existingId)
          .eq('user_id', user.id)
          .select();

      if (updated.isEmpty) {
        throw Exception(
          'No fitness goal was updated. Check your RLS policy.',
        );
      }

      debugPrint('Updated fitness goal: $updated');
    } else {
      final inserted = await supabase
          .from('fitness_goal')
          .insert(goalData)
          .select()
          .single();

      debugPrint('Inserted fitness goal: $inserted');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (isSavingProfile) return;

    final height = double.tryParse(heightController.text.trim());
    final weight = double.tryParse(weightController.text.trim());

    if (nameController.text.trim().isEmpty ||
        dobController.text.trim().isEmpty ||
        selectedGender == null ||
        height == null ||
        weight == null ||
        height <= 0 ||
        weight <= 0 ||
        selectedGoal == null ||
        selectedActivityLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all required fields with valid values.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSavingProfile = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please log in before saving your profile.');
      }

      // Recalculate BMI using the latest height and weight.
      // Height is entered in centimetres.
      final bmi = weight / ((height / 100) * (height / 100));
      final roundedBmi = double.parse(bmi.toStringAsFixed(2));

      final profileData = <String, dynamic>{
        'id': user.id,
        'full_name': nameController.text.trim(),
        'dob': dobController.text.trim(),
        'gender': selectedGender,
        'height': height,
        'weight': weight,
        'bmi': roundedBmi,
        'health_background': healthBackgroundController.text.trim(),
        'goal_type': selectedGoal,
        'fitness_level': selectedActivityLevel,
      };

      // Save latest profile information.
      await supabase.from('profiles').upsert(profileData);

      await _saveFitnessGoal();

      // Check the latest historical measurement.
      try {
        final latestProgress = await supabase
            .from('progress')
            .select('weight, bmi, notes')
            .eq('user_id', user.id)
            .order('recorded_at', ascending: false)
            .limit(1);

        final latestWeight = latestProgress.isEmpty
            ? null
            : double.tryParse(
                latestProgress.first['weight']?.toString() ?? '',
              );

        final latestBmi = latestProgress.isEmpty
            ? null
            : double.tryParse(
                latestProgress.first['bmi']?.toString() ?? '',
              );

        final latestNotes = latestProgress.isEmpty
            ? null
            : latestProgress.first['notes']?.toString();

        final currentNotes = 'Height: ${height.toStringAsFixed(1)} cm.';

        // Compare height as well as weight and BMI.
        final measurementChanged = latestProgress.isEmpty ||
            latestWeight == null ||
            latestBmi == null ||
            latestNotes != currentNotes ||
            (latestWeight - weight).abs() > 0.001 ||
            (latestBmi - roundedBmi).abs() > 0.001;

        if (measurementChanged) {
          await supabase.from('progress').insert({
            'user_id': user.id,
            'weight': weight,
            'bmi': roundedBmi,
            'notes': currentNotes,
            'recorded_at': DateTime.now().toUtc().toIso8601String(),
          });

          debugPrint(
            'Progress measurement saved: '
            'weight=$weight kg, height=$height cm, BMI=$roundedBmi',
          );
        } else {
          debugPrint(
            'No measurement change detected. '
            'Existing progress history was kept.',
          );
        }
      } catch (progressError) {
        debugPrint(
          'Profile saved, but progress history could not be saved: '
          '$progressError',
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile saved, but progress history could not be saved: '
              '$progressError',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile saved successfully! Current BMI: $roundedBmi',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Profile save error: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save profile: $error'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showMenstrualTracker =
        (selectedGender ?? '').trim().toLowerCase() == 'female';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tell us about yourself',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This information will help Wellness AI create a personalized plan for you.',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 25),

                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: dobController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                    );

                    if (pickedDate != null && mounted) {
                      setState(() {
                        dobController.text =
                            '${pickedDate.year}-'
                            '${pickedDate.month.toString().padLeft(2, '0')}-'
                            '${pickedDate.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Male',
                      child: Text('Male'),
                    ),
                    DropdownMenuItem(
                      value: 'Female',
                      child: Text('Female'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: healthBackgroundController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Health Background',
                    hintText:
                        'Tell us about any relevant health conditions or concerns',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedGoal,
                  decoration: const InputDecoration(
                    labelText: 'Fitness Goal',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Lose Weight',
                      child: Text('Lose Weight'),
                    ),
                    DropdownMenuItem(
                      value: 'Maintain Weight',
                      child: Text('Maintain Weight'),
                    ),
                    DropdownMenuItem(
                      value: 'Build Muscle',
                      child: Text('Build Muscle'),
                    ),
                    DropdownMenuItem(
                      value: 'Improve Fitness',
                      child: Text('Improve Fitness'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedGoal = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedActivityLevel,
                  decoration: const InputDecoration(
                    labelText: 'Activity Level',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Beginner',
                      child: Text('Beginner'),
                    ),
                    DropdownMenuItem(
                      value: 'Lightly Active',
                      child: Text('Lightly Active'),
                    ),
                    DropdownMenuItem(
                      value: 'Moderately Active',
                      child: Text('Moderately Active'),
                    ),
                    DropdownMenuItem(
                      value: 'Very Active',
                      child: Text('Very Active'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedActivityLevel = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedDietaryPreference,
                  decoration: const InputDecoration(
                    labelText: 'Dietary Preference',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'No preference',
                      child: Text('No preference'),
                    ),
                    DropdownMenuItem(
                      value: 'High protein',
                      child: Text('High protein'),
                    ),
                    DropdownMenuItem(
                      value: 'Vegetarian',
                      child: Text('Vegetarian'),
                    ),
                    DropdownMenuItem(
                      value: 'Vegan',
                      child: Text('Vegan'),
                    ),
                    DropdownMenuItem(
                      value: 'Dairy-free',
                      child: Text('Dairy-free'),
                    ),
                    DropdownMenuItem(
                      value: 'Gluten-free',
                      child: Text('Gluten-free'),
                    ),
                    DropdownMenuItem(
                      value: 'Low-Salt',
                      child: Text('Low-Salt'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedDietaryPreference = value;
                    });
                  },
                ),

                if (showMenstrualTracker) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Menstrual Cycle Tracker',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Track your period start date to help personalize '
                    'your wellness and workout recommendations.',
                  ),
                  const SizedBox(height: 12),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Has your period started?'),
                    value: periodStarted,
                    onChanged: (value) {
                      setState(() {
                        periodStarted = value;

                        if (!value) {
                          periodStartDate = null;
                        }
                      });
                    },
                  ),

                  if (periodStarted) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Period start date'),
                      subtitle: Text(
                        periodStartDate == null
                            ? 'Please select the date'
                            : '${periodStartDate!.year}-'
                              '${periodStartDate!.month.toString().padLeft(2, '0')}-'
                              '${periodStartDate!.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: _selectPeriodStartDate,
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isSavingCycle ? null : _saveCycleData,
                        child: Text(
                          isSavingCycle
                              ? 'Saving...'
                              : 'Save Period Date',
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        isSavingProfile ? null : _saveProfile,
                    child: Text(
                      isSavingProfile ? 'Saving...' : 'Continue',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
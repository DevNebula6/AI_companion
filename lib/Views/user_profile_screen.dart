import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:ai_companion/utilities/Dialogs/show_message.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _dobController;
  late final TextEditingController _conversationTopicsController;
  DateTime? _selectedDate;
  String? _selectedGender;
  Set<String> _selectedPersonalityTraits = {};
  Set<String> _selectedInterests = {};
  String _selectedLanguage = 'English';
  bool _isLoading = false;
  CustomAuthUser? _currentUser;

  final List<String> _personalityTraits = [
    'Introverted', 'Extroverted', 'Analytical', 'Creative',
    'Empathetic', 'Logical', 'Adventurous', 'Practical'
  ];

  final List<String> _interests = [
    'Music', 'Movies', 'Books', 'Sports', 'Technology',
    'Art', 'Travel', 'Gaming', 'Cooking', 'Fashion',
    'Science', 'Nature', 'Photography', 'Writing'
  ];

  final List<String> _languages = [
    'English', 'Spanish', 'French', 'German', 'Chinese',
    'Japanese', 'Korean', 'Hindi'
  ];


  final List<String> _genders = [
    'Male', 'Female', 'Prefer not to say'
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserData();
  }

  void _initializeControllers() {
    _fullNameController = TextEditingController();
    _dobController = TextEditingController();
    _conversationTopicsController = TextEditingController();
  }

  Future<void> _loadUserData() async {
    final user = await CustomAuthUser.getCurrentUser();
    if (user != null) {
      setState(() {
        _currentUser = user;
        _fullNameController.text = user.fullName ?? '';
        // Load other stored preferences from Supabase here
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _conversationTopicsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime(1923),
      lastDate: DateTime.now().subtract(const Duration(days: 6570)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthStateUserProfile) {
          if (state.exception != null) {
            showMessage(
              context: context,
              message: state.exception.toString(),
              backgroundColor: Colors.red,
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Complete Your Profile',
            style: GoogleFonts.atomicAge(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            )),
        ),
        body: _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildBasicInfoSection(),
          const SizedBox(height: 24),
          _buildPersonalitySection(),
          const SizedBox(height: 24),
          _buildInterestsSection(),
          const SizedBox(height: 24),
          _buildPreferencesSection(),
          const SizedBox(height: 24), 
          _buildSaveButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surfaceVariant,
            ),
            child: ClipOval(
              child: _currentUser?.avatarUrl != null
                  ? Image.network(
                      _currentUser!.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.person, size: 60),
                    )
                  : const Icon(Icons.person, size: 60),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _currentUser?.email ?? '',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Basic Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
        const SizedBox(height: 16),
        TextFormField(
          controller: _fullNameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) =>
            value?.isEmpty ?? true ? 'Please enter your name' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _dobController,
          decoration: InputDecoration(
            labelText: 'Date of Birth',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _selectDate,
            ),
          ),
          readOnly: true,
          validator: (value) =>
            value?.isEmpty ?? true ? 'Please select your date of birth' : null,
        ),
        const SizedBox(height: 16),
        _buildGenderSelection(),
      ],
    );
  }

  Widget _buildGenderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender',
          style: Theme.of(context).textTheme.bodyLarge),
        Wrap(
          spacing: 8.0,
          children: _genders.map((gender) =>
            ChoiceChip(
              label: Text(gender),
              selected: _selectedGender == gender,
              onSelected: (selected) {
                setState(() {
                  _selectedGender = selected ? gender : null;
                });
              },
            ),
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildPersonalitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Personality Traits',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
        const SizedBox(height: 8),
        Text('Select traits that best describe you',
          style: Theme.of(context).textTheme.bodyMedium),
        Wrap(
          spacing: 8.0,
          children: _personalityTraits.map((trait) =>
            FilterChip(
              label: Text(trait),
              selected: _selectedPersonalityTraits.contains(trait),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedPersonalityTraits.add(trait);
                  } else {
                    _selectedPersonalityTraits.remove(trait);
                  }
                });
              },
            ),
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildInterestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Interests',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
        const SizedBox(height: 8),
        Text('Select your interests to personalize conversations',
          style: Theme.of(context).textTheme.bodyMedium),
        Wrap(
          spacing: 8.0,
          children: _interests.map((interest) =>
            FilterChip(
              label: Text(interest),
              selected: _selectedInterests.contains(interest),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedInterests.add(interest);
                  } else {
                    _selectedInterests.remove(interest);
                  }
                });
              },
            ),
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Communication Preferences',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedLanguage,
          decoration: InputDecoration(
            labelText: 'Preferred Language',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: _languages.map((language) =>
            DropdownMenuItem(
              value: language,
              child: Text(language),
            ),
          ).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLanguage = value!;
            });
          },
        ),
      ],
    );
  }

  // Widget _buildConversationTopics() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text('Preferred Conversation Topics',
  //         style: Theme.of(context).textTheme.titleMedium?.copyWith(
  //           fontWeight: FontWeight.bold,
  //         )),
  //       const SizedBox(height: 8),
  //       TextFormField(
  //         controller: _conversationTopicsController,
  //         maxLines: 3,
  //         decoration: InputDecoration(
  //           hintText: 'Enter topics you\'d like to discuss...',
  //           border: OutlineInputBorder(
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveProfile,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? const CircularProgressIndicator()
          : const Text('Save & Continue'),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final userData = {
        'full_name': _fullNameController.text,
        'dob': _selectedDate?.toIso8601String(),
        'gender': _selectedGender,
        'personality_traits': _selectedPersonalityTraits.toList(),
        'interests': _selectedInterests.toList(),
        'preferred_language': _selectedLanguage,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final supabase = SupabaseClientManager().client;
      // await supabase
      //     .from('user_profiles')
      //     .upsert(userData)
      //     .eq('id', _currentUser?.id);

      if (mounted) {
        showMessage(
          context: context,
          message: 'Profile updated successfully',
          backgroundColor: Colors.green,
        );
        Navigator.pushReplacementNamed(context, '/select-companion');
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context: context,
          message: 'Error saving profile: $e',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
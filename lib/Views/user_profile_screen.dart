import 'dart:convert';

import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/auth_exceptions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/utilities/Dialogs/show_message.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _dobController;
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

  // Add new constants for styling
  static const primaryColor = Color(0xFF6C63FF); // Modern purple
  static const secondaryColor = Color(0xFF2C2C2C);
  static const backgroundColor = Color(0xFFF8F9FE);
  static const cardColor = Colors.white;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _initializeControllers();
    _loadUserData();
    _animationController.forward();
  }

  void _initializeControllers() {
    _fullNameController = TextEditingController();
    _dobController = TextEditingController();
  }

  Future<void> _loadUserData() async {
    final user = await CustomAuthUser.getCurrentUser();
    if (user != null) {
      print(user.gender);
      setState(() {
        _currentUser = user;
        _fullNameController.text = user.fullName ?? '';
        _selectedDate = user.dob != null ? DateTime.parse(user.dob!) : null;
        _dobController.text = user.dob != null
            ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
            : '';
        _selectedGender = user.gender;
        _selectedPersonalityTraits = user.personalityTraits != null
            ? user.personalityTraits!.split(',').toSet()
            : {};
        _selectedInterests = user.interests != null
            ? user.interests!.split(',').toSet()
            : {};
        _selectedLanguage = user.chatLanguage ?? 'English';
        // Load other stored preferences from Supabase here
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fullNameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime(1923),
      lastDate: DateTime.now().subtract(const Duration(days: 5114)),
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
        backgroundColor: backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: cardColor,
          title: Text(
            'Your Profile',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: secondaryColor,
            ),
          ),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        body: _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 32),
            _buildBasicInfoSection(),
            const SizedBox(height: 32),
            _buildPersonalitySection(),
            const SizedBox(height: 32),
            _buildInterestsSection(),
            const SizedBox(height: 32),
            _buildPreferencesSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.8), primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: _currentUser?.avatarUrl != null
                  ? Image.network(
                      _currentUser!.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.person, size: 60, color: cardColor),
                    )
                  : Icon(Icons.person, size: 60, color: cardColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _currentUser?.email ?? '',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: secondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 20),
          _buildStylizedTextField(
            controller: _fullNameController,
            label: 'Full Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStylizedTextField(
                  controller: _dobController,
                  label: 'Date of Birth',
                  icon: Icons.calendar_today,
                  onTap: _selectDate,
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildGenderSelection(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStylizedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: GoogleFonts.poppins(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: secondaryColor.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: primaryColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondaryColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: cardColor,
      ),
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

  Widget _buildSaveButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Save & Continue',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    if(_currentUser == null) {
      throw UserNotLoggedInAuthException();
    }
    final updatedUser = _currentUser!.copyWith(
      fullName: _fullNameController.text,
      dob: _selectedDate?.toIso8601String(),
      gender: _selectedGender,
      interests: _selectedInterests.isNotEmpty 
          ? _selectedInterests.join(',') 
          : null,
      personalityTraits: _selectedPersonalityTraits.isNotEmpty 
          ? _selectedPersonalityTraits.join(',') 
          : null,
      chatLanguage: _selectedLanguage,
      metadata: {
        ..._currentUser!.metadata,
        'last_updated': DateTime.now().toIso8601String(),
      },
    );

    try {
    context.read<AuthBloc>().add(AuthEventUserProfile(
      user: updatedUser,
    ));
    if (mounted) {
        showMessage(
          context: context,
          message: 'Profile saved successfully',
          icon: Icons.check_circle_rounded,
          backgroundColor: Colors.green,
        );
      }
    }
    catch (e) {
      if (mounted) {
        showMessage(
          context: context,
          message: 'Error saving profile: $e',
          icon: Icons.error,
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
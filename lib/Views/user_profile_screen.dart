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

  // Updated color scheme
  static const primaryColor = Color(0xFF7C4DFF); // Deep purple for AI/Tech feel
  static const accentColor = Color(0xFF2AC3FF); // Bright blue for accents
  static const backgroundColor = Color(0xFFF8F9FF); // Soft background
  static const secondaryColor = Color(0xFF4D4F5C); // Dark grey for text
  static const cardColor = Colors.white;
  static const textColor = Color(0xFF2D3142);
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
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
      child: PopScope(
  canPop: _currentUser?.aiModel != null && _currentUser!.aiModel!.toString().isNotEmpty,
  onPopInvokedWithResult: (bool didPop, dynamic result) async {
    if (_currentUser?.aiModel != null && _currentUser!.aiModel!.toString().isNotEmpty) {
      // context.read<AuthBloc>().add(
      //   AuthEventLoggedIn(user: _currentUser!),
      // );
    }
  },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          elevation: 0,
          leading: _currentUser?.aiModel != null && _currentUser!.aiModel!.toString().isNotEmpty
            ? BackButton(
                color: secondaryColor,
                onPressed: () {
                  // context.read<AuthBloc>().add(
                    // AuthEventLoggedIn(user: _currentUser!),
                  // );
                },
              )
            : null,
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
    ));
  }

  Widget _buildForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: 16, // Reduced horizontal padding
            vertical: 12,
          ),
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24), // Reduced spacing
            _buildInfoCard(),
            const SizedBox(height: 16), // Reduced spacing
            _buildTraitsCard(),
            const SizedBox(height: 24),
            _buildInterestsCard(),
            const SizedBox(height: 24),
            _buildPreferencesCard(),
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
                          const Icon(Icons.person, size: 60, color: cardColor),
                    )
                  : const Icon(Icons.person, size: 60, color: cardColor),
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

  Widget _buildInfoCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: GoogleFonts.poppins(
                fontSize: 20, // Slightly smaller
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16), // Reduced spacing
            _buildStylizedTextField(
              controller: _fullNameController,
              label: 'Full Name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16), // Reduced spacing
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: _buildStylizedTextField(
                    controller: _dobController,
                    label: 'Date of Birth',
                    icon: Icons.calendar_today,
                    onTap: _selectDate,
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 12), // Reduced spacing
                Expanded(
                  flex: 1,
                  child: _buildGenderDropdown(),
                ),
              ],
            ),
          ],
        ),
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
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: cardColor,
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      isExpanded: true, // Ensures dropdown fits in available space
      isDense: true, // Makes the dropdown more compact
      icon: const Icon(Icons.arrow_drop_down, size: 20), // Smaller icon
      decoration: InputDecoration(
        labelText: 'Gender',
        labelStyle: GoogleFonts.poppins(
          color: textColor.withOpacity(0.7),
          fontSize: 15, // Smaller font size
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ), // Optimized padding
        prefixIcon: const Icon(
          Icons.person_outline,
          color: primaryColor,
          size: 20, // Smaller icon
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: cardColor,
      ),
      items: _genders.map((gender) => DropdownMenuItem(
        value: gender,
        child: Text(
          gender,
          style: GoogleFonts.poppins(
            fontSize: 14, // Smaller font size
          ),
          overflow: TextOverflow.ellipsis,
        ),
      )).toList(),
      onChanged: (value) {
        setState(() => _selectedGender = value);
      },
    );
  }

  Widget _buildTraitsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(_getResponsivePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personality Traits',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _personalityTraits.map((trait) => _buildAnimatedChip(
                label: trait,
                isSelected: _selectedPersonalityTraits.contains(trait),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedPersonalityTraits.add(trait);
                    } else {
                      _selectedPersonalityTraits.remove(trait);
                    }
                  });
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : textColor,
          ),
        ),
        selected: isSelected,
        onSelected: onSelected,
        backgroundColor: cardColor,
        selectedColor: primaryColor,
        checkmarkColor: Colors.white,
        elevation: isSelected ? 4 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildInterestsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interests',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _interests.map((interest) => _buildAnimatedChip(
                label: interest,
                isSelected: _selectedInterests.contains(interest),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(interest);
                    } else {
                      _selectedInterests.remove(interest);
                    }
                  });
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Communication Preferences',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
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
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [primaryColor, accentColor],
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Save Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
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

  // Add responsive sizing helper
  double _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 12.0;
    if (width < 400) return 16.0;
    return 20.0;
  }
}
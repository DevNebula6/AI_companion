import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/ErrorHandling/auth_exceptions.dart';
import 'package:ai_companion/chat/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/utilities/Dialogs/show_message.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:ai_companion/utilities/constants/textstyles.dart';

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
  List<Widget>? _cachedCategoryWidgets;
  bool _interestsChanged = false;
  bool _barAnimationsComplete = false;
  bool _hasConversations = false;


  // Remove static style definitions as we'll use AppTextStyles
  
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
    _barAnimationsComplete = false;
    _checkForConversations();
  }

  void _initializeControllers() {
    _fullNameController = TextEditingController();
    _dobController = TextEditingController();
  }

  Future<void> _loadUserData() async {
    final user = await CustomAuthUser.getCurrentUser();
    if (user != null) {
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
      });
    }
  }
  // Add this method to check for conversations
  Future<void> _checkForConversations() async {
    final user = await CustomAuthUser.getCurrentUser();
    if (user != null) {
      final chatRepository = await ChatRepositoryFactory.getInstance();
      final hasConversations = await chatRepository.hasConversations(user.id);
      setState(() {
        _hasConversations = hasConversations;
      });
    }
  }
  
  @override
  void dispose() {
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('MMM dd, yyyy').format(picked);
      });
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    
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
      child:PopScope(
        // Allow popping only if user has conversations
        canPop: _hasConversations,
        onPopInvoked: (didPop) {
          if (!didPop && _hasConversations) {
            // If back button is pressed and user has conversations
            context.read<AuthBloc>().add(
              AuthEventNavigateToHome(user: _currentUser!)
            );
          }
        },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(themeColors),
        body: _buildBody(themeColors),
      ),
    ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colors) {
    return AppBar(
      elevation: 0,
      leading: _hasConversations 
      ? BackButton(
          color: Colors.white,
          onPressed: () {
            // Navigate to home screen using AuthBloc
            context.read<AuthBloc>().add(
              AuthEventNavigateToHome(user: _currentUser!)
            );
          },
        )
      : null,
      backgroundColor: colors.primary,
      foregroundColor: Colors.white,
      title: Text(
        'Your Profile',
        style: AppTextStyles.appBarTitle.copyWith(color: Colors.white),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      centerTitle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    return Form(
      key: _formKey,
      child: Stack(
        children: [
          // Background design elements
          ..._buildBackgroundElements(colors),
          
          // Scrollable content
          ListView(
            padding: const EdgeInsets.only(
              top: 24,
              bottom: 30, // Extra space for button
              left: 20,
              right: 20,
            ),
            addRepaintBoundaries: true,
            addAutomaticKeepAlives: false,
            physics: const RangeMaintainingScrollPhysics(),
            children: [
              _buildProfileHeader(colors),
              const SizedBox(height: 32),
              
              // Basic Info
               _buildInfoCard(colors),
              
              const SizedBox(height: 20),
              
              // Traits
               _buildTraitsCard(colors),
              
              const SizedBox(height: 20),
              
              // Interests
               _buildInterestsCard(colors),
              
              const SizedBox(height: 20),
              
              // Preferences
               _buildPreferencesCard(colors),
              
              // Space for floating button
              const SizedBox(height: 80),
            ],
          ),
          
          // Floating action button positioned at the bottom
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: _buildSaveButton(colors),
            ),
        ],
      ),
    );
  }
  
  List<Widget> _buildBackgroundElements(ColorScheme colors) {
    return [
      // Subtle pattern overlay
      Positioned.fill(
        child: RepaintBoundary(
          child: Opacity(
            opacity: 0.25,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/backgrounds/pt4.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildProfileHeader(ColorScheme colors) {
    return Center(
      child: Column(
        children: [
          // Profile image with gradient border
          Stack(
            alignment: Alignment.center,
            children: [
              
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary,
                      colors.secondary,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3.0), // Border thickness
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: _currentUser?.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            _currentUser!.avatarUrl!,
                            fit: BoxFit.cover,
                            height: 114,
                            width: 114,
                            errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person, size: 40, color: Colors.black38),
                          ),
                        )
                      : const Icon(Icons.person, size: 40, color: Colors.black38),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // User email with animation
          Text(
            _currentUser?.email ?? '',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colors) {
    return RepaintBoundary(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Basic Information',
                    style: AppTextStyles.sectionHeader,
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Full name field
              _buildFloatingLabelTextField(
                controller: _fullNameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                colors: colors,
                icon: Icons.person_outline,
              ),
              
              const SizedBox(height: 16),
              
              // Date of birth and gender
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date of Birth
                  Expanded(
                    child: _buildFloatingLabelTextField(
                      controller: _dobController,
                      label: 'Date of Birth',
                      hint: 'Select date',
                      colors: colors,
                      icon: Icons.calendar_today,
                      onTap: _selectDate,
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Gender
                  Expanded(
                    child: _buildGenderDropdown(colors),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingLabelTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ColorScheme colors,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTextStyles.labelLarge,
        hintStyle: AppTextStyles.labelMedium.copyWith(color: Colors.black38),
        prefixIcon: Icon(
          icon,
          color: colors.primary,
          size: 20,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildGenderDropdown(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Gender',
          labelStyle: AppTextStyles.labelLarge,
          prefixIcon: Icon(
            Icons.person_outline,
            color: colors.primary,
            size: 20,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colors.primary,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          isDense: true,
        ),
        style: AppTextStyles.bodyMedium,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        items: _genders.map((gender) => DropdownMenuItem(
          value: gender,
          child: Text(
            gender,
            style: AppTextStyles.bodyMedium,
          ),
        )).toList(),
        onChanged: (value) {
          setState(() => _selectedGender = value);
          // Haptic feedback
          HapticFeedback.selectionClick();
        },
      ),
    );
  }

Widget _buildTraitsCard(ColorScheme colors) {
  return RepaintBoundary(
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                //  icon 
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),                    
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.1 ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                
                const Text(
                  'Personality Traits',
                  style: AppTextStyles.sectionHeader,
                ),
                
                const Spacer(),
            
                // Info tooltip
                const Tooltip(
                  message: 'Select traits that match your personality',
                ),
              ],
            ),
            
            // Static divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            // Helper text
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Select traits that describe you best',
                style: AppTextStyles.withItalic(AppTextStyles.bodySmall),
              ),
            ),
            
            // Traits selection with staggered animation
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: _personalityTraits.asMap().entries.map((entry) {
                final trait = entry.value;
                
                return _buildAnimatedChip(
                  label: trait,
                  isSelected: _selectedPersonalityTraits.contains(trait),
                  selectedColor: colors.primary,
                  icon: getTraitIcon(trait),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPersonalityTraits.add(trait);
                      } else {
                        _selectedPersonalityTraits.remove(trait);
                      }
                    });
                    // Haptic feedback
                    HapticFeedback.lightImpact();
                  },
                );
              }).toList(),
            ),
            
            // Selection summary
            if (_selectedPersonalityTraits.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        color: colors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedPersonalityTraits.length} traits selected',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colors.primary,
                            ),
                          ),
                          const Text(
                            'These will help us find your ideal AI companion',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// Enhanced animated chip with more visual interest
Widget _buildAnimatedChip({
  required String label,
  required bool isSelected,
  required Color selectedColor,
  required IconData icon,
  required Function(bool) onSelected,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(30),
      splashColor: selectedColor.withOpacity(0.1),
      highlightColor: selectedColor.withOpacity(0.05),
      onTap: () => onSelected(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? selectedColor 
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected 
                ? Colors.transparent 
                : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isSelected 
              ? [
                  BoxShadow(
                    color: selectedColor.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] 
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with subtle animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.white.withOpacity(0.2) 
                    : selectedColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : selectedColor,
              ),
            ),
            const SizedBox(width: 8),
            
            // Label with animated text style
            Text(
              label,
              style: isSelected 
                  ? AppTextStyles.chipLabel.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    )
                  : AppTextStyles.chipLabel,
            ),
            
            // Selected indicator with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 20 : 0,
              child: isSelected
                  ? const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildInterestsCard(ColorScheme colors) {
  return RepaintBoundary(
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                //  icon container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.secondary.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.favorite_outlined,
                    color: colors.secondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                
                // Section title with animation
                const Text(
                  'Your Interests',
                  style: AppTextStyles.sectionHeader,
                ),
                
                const Spacer(),
              ],
            ),
            
            // Divider - using secondary color
            Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Container(
                    height: 1,
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.secondary.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
            
            // Helper text
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Select topics you enjoy or love to discuss',
                style: AppTextStyles.labelLarge.copyWith(fontStyle: FontStyle.italic)
              ),
            ),
            
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: _interests.asMap().entries.map((entry) {
                final interest = entry.value;
                
                return _buildAnimatedChip(
                  label: interest,
                  isSelected: _selectedInterests.contains(interest),
                  selectedColor: colors.secondary,
                  icon: getInterestIcon(interest),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedInterests.add(interest);
                      } else {
                        _selectedInterests.remove(interest);
                      }
                      _interestsChanged = true; // Mark for recomputation
                    });
                    HapticFeedback.lightImpact();
                  },
                );
              }).toList(),
            ),
            
            // Selection summary - appears when interests are selected
            if (_selectedInterests.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colors.secondary.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: colors.secondary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedInterests.length} interests selected',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colors.secondary,
                            ),
                          ),
                          const Text(
                            'Your AI companion will share these interests with you',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
            // Show interest categories overview if 3+ interests selected  
            if (_selectedInterests.length >= 3)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Text(
                        'Your Interest Profile',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    // Interest categories chart
                    // SizedBox(
                    //   height: 70,
                    //   child: Row(
                    //     children: _buildInterestCategories(colors),
                    //   ),
                    // ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

  // Optimized method to categorize interests and build visual bars
  List<Widget> _buildInterestCategories(ColorScheme colors) {
    // Return cached results if available and interests haven't changed
    if (_cachedCategoryWidgets != null && !_interestsChanged) {
      return _cachedCategoryWidgets!;
    }
    
    // Simple categorization of interests (static mapping)
    final Map<String, List<String>> categories = {
      'Arts': ['Music', 'Art', 'Photography', 'Writing'],
      'Entertainment': ['Movies', 'Books', 'Gaming'],
      'Lifestyle': ['Cooking', 'Fashion', 'Travel'],
      'Science': ['Technology', 'Science', 'Nature'],
      'Active': ['Sports'],
    };
    
    // Quick count interests in each category (optimized)
    final Map<String, int> categoryCounts = {};
    for (final entry in categories.entries) {
      int count = 0;
      for (final interest in _selectedInterests) {
        if (entry.value.contains(interest)) count++;
      }
      if (count > 0) categoryCounts[entry.key] = count;
    }
    
    // No categories matching - return empty
    if (categoryCounts.isEmpty) {
      _cachedCategoryWidgets = [];
      return [];
    }
    
    // Sort by count (higher first) - do this once, not on every render
    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Take up to 5 categories
    final topCategories = sortedCategories.take(5).toList();
    
    // Find max value once
    final maxCount = topCategories.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    
    // Pre-allocate a fixed map of category colors (eliminates repeated switch statements)
    final categoryColors = {
      'Arts': const Color(0xFF9C27B0),
      'Entertainment': const Color(0xFF2196F3),
      'Lifestyle': const Color(0xFFFF9800),
      'Science': const Color(0xFF4CAF50),
      'Active': const Color(0xFFE91E63),
    };
    
    // Build the widgets for each category
    final widgets = topCategories.map((entry) {
      final category = entry.key;
      final count = entry.value;
      final ratio = count / maxCount;
      
      // Get color or use default
      final categoryColor = categoryColors[category] ?? colors.secondary;
      
      return Expanded(
        child: RepaintBoundary( // Add RepaintBoundary to isolate rendering
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                // Category label - static
                Text(
                  category,
                  style: AppTextStyles.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                
                // Bar visualization - simplified to a single animation
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setStateLocal) {
                      // Only animate once when first built
                      if (!_barAnimationsComplete) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) setStateLocal(() => _barAnimationsComplete = true);
                        });
                      }
                      
                      return Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Static background
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          
                          // Foreground with simplified animation
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            height: _barAnimationsComplete ? 40 * ratio : 0,
                            decoration: BoxDecoration(
                              color: categoryColor,
                              borderRadius: BorderRadius.circular(8),
                              // Use a simpler box shadow (less expensive)
                              boxShadow: _barAnimationsComplete ? [
                                BoxShadow(
                                  color: categoryColor.withOpacity(0.2),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ] : null,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // Static count display
                Text(
                  count.toString(),
                  style: AppTextStyles.statsNumber.copyWith(
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
    
    // Cache the results
    _cachedCategoryWidgets = widgets;
    _interestsChanged = false;
    
    return widgets;
  }

  Widget _buildPreferencesCard(ColorScheme colors) {
    return RepaintBoundary(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.tertiary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: colors.tertiary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Communication Preferences',
                      style: AppTextStyles.sectionHeader,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Language selection
              _buildLanguageDropdown(colors),
              
              const SizedBox(height: 16),
              
              // Notification preferences
              _buildSwitchSetting(
                title: 'Daily Check-ins',
                subtitle: 'Receive daily conversation reminders',
                value: true,
                onChanged: (value) {
                  // Implement functionality
                  HapticFeedback.lightImpact();
                },
                colors: colors,
                icon: Icons.notifications_active_outlined,
              ),
              
              const SizedBox(height: 12),
              
              _buildSwitchSetting(
                title: 'Personalized Suggestions',
                subtitle: 'Get companion recommendations based on your profile',
                value: true,
                onChanged: (value) {
                  // Implement functionality
                  HapticFeedback.lightImpact();
                },
                colors: colors,
                icon: Icons.recommend_outlined,
              ),
              
              const SizedBox(height: 12),
              
              _buildSwitchSetting(
                title: 'Message Notifications',
                subtitle: 'Receive alerts for new messages',
                value: true,
                onChanged: (value) {
                  // Implement functionality
                  HapticFeedback.lightImpact();
                },
                colors: colors,
                icon: Icons.mark_chat_unread_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLanguageDropdown(ColorScheme colors) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonFormField<String>(
          value: _selectedLanguage,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Preferred Language',
            labelStyle: AppTextStyles.labelLarge,
            prefixIcon: Icon(
              Icons.language,
              color: colors.tertiary,
              size: 20,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            fillColor: Colors.grey.shade100,
            filled: true,
          ),
          style: AppTextStyles.bodyMedium,
          dropdownColor: Colors.white,
          items: _languages.map((language) => DropdownMenuItem(
            value: language,
            child: Text(
              language,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          )).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedLanguage = value);
              HapticFeedback.selectionClick();
            }
          },
        ),
      ),
    );
  }
    
  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required ColorScheme colors,
    required IconData icon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? colors.tertiary.withOpacity(0.3) : Colors.grey.shade200,
        ),
        boxShadow: value ? [
          BoxShadow(
            color: colors.tertiary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value ? colors.tertiary.withOpacity(0.1) : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: value ? colors.tertiary : Colors.grey,
          ),
        ),
        title: Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.bodySmall,
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: colors.tertiary,
          activeTrackColor: colors.tertiary.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colors) {
    return RepaintBoundary(
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              colors.primary,
              Color.lerp(colors.primary, colors.secondary, 0.5)!,
              colors.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _isLoading ? null : _saveProfile,
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Center(
              child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Save Profile',
                        style: AppTextStyles.buttonLarge,
                      ),
                    ],
                  ),
            ),
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
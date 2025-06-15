import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/conversation.dart';
import 'package:ai_companion/chat/gemini/companion_relationship_tracker.dart';
import 'package:ai_companion/chat/conversation/conversation_bloc.dart';
import 'package:ai_companion/chat/conversation/conversation_event.dart';
import 'package:ai_companion/chat/conversation/conversation_state.dart';
import 'package:ai_companion/utilities/Dialogs/generic_dialog.dart';
import 'package:ai_companion/utilities/constants/textstyles.dart';
import 'package:ai_companion/utilities/widgets/photo_viewer.dart' show ProfilePhotoViewer;
import 'package:ai_companion/utilities/widgets/floating_connectivity_indicator.dart';
import 'package:ai_companion/services/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TextEditingController _searchController;
  String _searchQuery = '';
  late CompanionRelationshipTracker _relationshipTracker;
  bool _isSearching = false;
  bool _isDrawerOpen = false;
  final _scrollController = ScrollController();
  CustomAuthUser? _user;
  late AnimationController _drawerAnimationController;
  final Map<String, String?> _companionEmotions = {}; // Track emotions for each companion
  late ConnectivityService _connectivityService;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _relationshipTracker = CompanionRelationshipTracker();
    _drawerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize the user
    _initializeUser();

    // Improved search controller listener
    _searchController.addListener(() {
      if (_searchController.text != _searchQuery) {
        setState(() {
          _searchQuery = _searchController.text;
          // Print debug info about the search
          print('Search query changed to: $_searchQuery');
        });
      }
    });

    // Load conversations on startup
    _loadConversations();

    _connectivityService = ConnectivityService();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted && isOnline != _isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _drawerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final user = await CustomAuthUser.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _user = user;
      });
    }
  }

  void _loadConversations() async {
    final user = await CustomAuthUser.getCurrentUser();
    if (user != null) {
      context.read<ConversationBloc>().add(LoadConversations(user.id));
    }
  }

  void _toggleDrawer() {
    setState(() {
      _isDrawerOpen = !_isDrawerOpen;
      if (_isDrawerOpen) {
        _drawerAnimationController.forward();
      } else {
        _drawerAnimationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingConnectivityIndicator(
      child: Scaffold(
        backgroundColor: colorScheme.background,
        body: Stack(
          children: [
            // Main content
            _buildMainContent(colorScheme),

            // Overlay for drawer
            if (_isDrawerOpen)
              GestureDetector(
                onTap: _toggleDrawer,
                child: AnimatedOpacity(
                  opacity: _isDrawerOpen ? 0.3 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    color: Colors.black,
                  ),
                ),
              ),
            
            // Integrated drawer
            _buildDrawer(colorScheme),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (_user != null) {
              context.read<AuthBloc>().add(
                AuthEventNavigateToCompanion(user: _user!),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please wait, loading Companion information...')),
              );
            }
          },
          backgroundColor: colorScheme.primary,
          icon: const Icon(Icons.add),
          label: const Text('New Companion'),
          elevation: 3,
        ).animate().scale(
          duration: 400.ms,
          curve: Curves.easeOutBack,
          delay: 300.ms,
        ),
      ),
    );
  }

  Widget _buildMainContent(ColorScheme colorScheme) {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(colorScheme),
          Expanded(
            child: BlocBuilder<ConversationBloc, ConversationState>(
              builder: (context, state) {
                return _buildConversationList(state);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Menu button with animated icon
              AnimatedBuilder(
                animation: _drawerAnimationController,
                builder: (context, child) {
                  return IconButton(
                    icon: AnimatedIcon(
                      icon: AnimatedIcons.menu_close,
                      progress: _drawerAnimationController,
                      color: colorScheme.onBackground,
                      size: 26,
                    ),
                    onPressed: _toggleDrawer,
                  );
                },
              ),

              const SizedBox(width: 8),

              // App title
              Text(
                'Conversations',
                style: AppTextStyles.companionNamePopins.copyWith(
                  color: colorScheme.onBackground,
                  fontWeight: FontWeight.w500,
                  fontSize: 26, // Increased font size
                ),
              ),

              const Spacer(),

              // Search button (removed network indicator)
              IconButton(
                iconSize: 26,
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: colorScheme.onBackground,
                ),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                    }
                  });
                },
              ),
            ],
          ),

          // Search field (visible only when searching)
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _searchController,
                cursorColor: colorScheme.primary,
                style: TextStyle(
                  color: colorScheme.onBackground,
                ),
                decoration: InputDecoration(
                  hintText: 'Search companion by name...',
                  hintStyle: TextStyle(
                    color: colorScheme.onBackground.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.onBackground.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                autofocus: true,
              ).animate().fadeIn(
                duration: 300.ms,
                curve: Curves.easeOut,
              ).slideY(
                begin: -0.1,
                end: 0,
                duration: 300.ms,
                curve: Curves.easeOut,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer(ColorScheme colorScheme) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: _isDrawerOpen ? 0 : -280,
      top: 0,
      bottom: 0,
      width: 280,
      child: Material(
        elevation: 8,
        color: colorScheme.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header with user info
              _buildDrawerHeader(colorScheme),

              // Divider
              Divider(color: colorScheme.outlineVariant),

              // Navigation items
              Expanded(
                child: _buildDrawerNavigationItems(colorScheme),
              ),

              // Footer with logout button
              _buildDrawerFooter(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 36),

          // User avatar - now larger and centered
          CircleAvatar(
            radius: 55, // Increased size
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: _user?.avatarUrl != null
                ? NetworkImage(_user!.avatarUrl!)
                : null,
            child: _user?.avatarUrl == null
                ? Icon(
                    Icons.person,
                    color: colorScheme.primary,
                    size: 55, // Increased icon size
                  )
                : null,
          ),
      
          const SizedBox(height: 18),
      
          // User info - now below avatar
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _user?.fullName ?? 'Guest User',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _user?.email ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
        ],
      ),
    );
  }

  Widget _buildDrawerNavigationItems(ColorScheme colorScheme) {
    final List<_MenuItem> menuItems = [
      _MenuItem(
        icon: Icons.home_outlined,
        title: 'Home',
        isSelected: true,
        onTap: () {
          _toggleDrawer();
        },
      ),
      _MenuItem(
        icon: Icons.person_outline,
        title: 'User Profile',
        onTap: () {
          if (_user != null) {
            _toggleDrawer();
            context.read<AuthBloc>().add(
              AuthEventNavigateToUserProfile(user: _user!),
            );
          }
        },
      ),
      _MenuItem(
        icon: Icons.favorite_outline,
        title: 'Select Companion',
        onTap: () {
          if (_user != null) {
            _toggleDrawer();
            context.read<AuthBloc>().add(
              AuthEventNavigateToCompanion(user: _user!),
            );
          }
        },
      ),
      _MenuItem(
        icon: Icons.settings_outlined,
        title: 'Settings',
        onTap: () {
          _toggleDrawer();
          
        },
      ),
      _MenuItem(
        icon: Icons.help_outline,
        title: 'Help & Support',
        onTap: () {
          _toggleDrawer();
          
        },
      ),
    ];

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        return _buildDrawerMenuItem(item, colorScheme, index);
      },
    );
  }

  Widget _buildDrawerMenuItem(_MenuItem item, ColorScheme colorScheme, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: item.isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withOpacity(0.7),
          size: 24,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 16,
            color: item.isSelected
                ? colorScheme.primary
                : colorScheme.onSurface,
            fontWeight: item.isSelected ? FontWeight.bold : null,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: item.isSelected
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : null,
        onTap: item.onTap ?? () {},
      ),
    ).animate().fadeIn(
      duration: 200.ms,
      delay: 50.ms * index,
    ).slideX(
      begin: -0.1,
      end: 0,
      duration: 200.ms,
      delay: 50.ms * index,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildDrawerFooter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Divider
          Divider(color: colorScheme.outlineVariant),

          const SizedBox(height: 12),

          // Logout button
          ListTile(
            leading: Icon(
              Icons.logout,
              color: colorScheme.error,
            ),
            title: Text(
              'Logout',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.error,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: _confirmLogout,
          ),

          const SizedBox(height: 16),

          // App version
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showGenericDialog<bool>(
      context: context,
      title: 'Logout',
      content: 'Are you sure you want to logout?',
      options: () => {
        'Logout': true,
        'Cancel': false,
      },
    ).then((value) => value ?? false);

    if (shouldLogout) {
      _toggleDrawer();
      // Clear all user cache 
      // context.read<ConversationBloc>().add(const ClearAllCacheForUser());

      // Perform logout
      context.read<AuthBloc>().add(const AuthEventLogOut());
    }
  }

  Widget _buildConversationList(ConversationState state) {
    final colorScheme = Theme.of(context).colorScheme;

    if (state is ConversationLoading) {
      return _buildLoadingList();
    } else if (state is ConversationLoaded) {
      List<Conversation> conversations = [...state.conversations];
      
      // Sort conversations - favourites first, then by last updated
      conversations.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.lastUpdated.compareTo(a.lastUpdated);
      });

      // For all conversations, ensure we have the latest emotion data
      for (var conversation in conversations) {
        _updateConversationEmotion(conversation);
      }

      // Debug any search issues - enhanced with more details
      if (_searchQuery.isNotEmpty) {
        print('Searching for: "$_searchQuery"');
        print('All conversations before filtering:');
        for (var conversation in conversations) {
          print('Conversation ${conversation.id}: '
                'companionId=${conversation.companionId}, '
                'companionName=${conversation.companionName ?? "NULL"}, '
                'lastMessage=${conversation.lastMessage?.substring(0, 20) ?? "NULL"}');
        }
      }

      // Updated search filtering with better null handling and debugging
      if (_searchQuery.isNotEmpty) {
        final lowerQuery = _searchQuery.toLowerCase().trim();
        
        final beforeCount = conversations.length;
        conversations = conversations.where((conversation) {
          // Safely handle null companionName with more detailed logging
          final name = conversation.companionName ?? '';
          if (name.isEmpty) {
            print('WARNING: Conversation ${conversation.id} has no companionName!');
            // Fallback to loading companion directly when name is missing
            return false;  // Skip this conversation in search results
          }
          
          final result = name.toLowerCase().contains(lowerQuery);
          if (result) {
            print('MATCH: "${conversation.companionName}" contains "$lowerQuery"');
          }
          
          return result;
        }).toList();
        
        print('Search results: ${conversations.length}/$beforeCount conversations match "$_searchQuery"');
      }

      // If search yielded no results but we have a query, show search empty state
      if (conversations.isEmpty && _searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'No companions found',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No companions matching "$_searchQuery"',
                style: TextStyle(
                  fontSize: 16, 
                  color: colorScheme.onBackground.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      } else if (conversations.isEmpty) {
        return _buildEmptyState();
      }

      // Show offline message if no conversations and offline
      if (conversations.isEmpty && !_isOnline) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: 80,
                color: colorScheme.primary.withOpacity(0.5),
              ).animate().scale(
                duration: 600.ms,
                curve: Curves.easeOutBack,
              ),
              const SizedBox(height: 16),
              Text(
                'You\'re offline',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onBackground,
                ),
              ).animate().fadeIn(
                duration: 600.ms,
                delay: 300.ms,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Connect to the internet to load your conversations',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onBackground.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(
                duration: 600.ms,
                delay: 600.ms,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  final isOnline = await _connectivityService.refreshConnectivity();
                  if (isOnline) {
                    _loadConversations();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Still no internet connection'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ).animate().fadeIn(
                duration: 600.ms,
                delay: 900.ms,
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: _scrollController,
        itemCount: conversations.length + 1, // +1 for section header
        padding: const EdgeInsets.only(bottom: 80),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Section header
            return SizedBox(height: 15,);
          }
      
          final conversation = conversations[index - 1];
          final bool isFavourite = conversation.isPinned;
      
          // Add staggered animation for items
          return _buildConversationTile(conversation, isFavourite)
              .animate()
              .fadeIn(
                duration: 400.ms,
                delay: (50 * index).ms,
                curve: Curves.easeOutQuad,
              )
              .slideY(
                begin: 0.1,
                end: 0,
                duration: 400.ms,
                delay: (50 * index).ms,
                curve: Curves.easeOutQuad,
              );
        },
      );
    } else if (state is ConversationError) {
      return _buildErrorState(state.message);
    }

    return _buildLoadingList();
  }

  Future<void> _updateConversationEmotion(Conversation conversation) async {
    if (!_companionEmotions.containsKey(conversation.id)) {
      try {
        final enrichedConversation = await _relationshipTracker.enrichConversation(conversation);
        if (mounted) {
          setState(() {
            _companionEmotions[conversation.id] = enrichedConversation.dominantEmotion;
          });
        }
      } catch (e) {
        // Handle any errors silently, emotion just won't display
        print('Error retrieving emotion for conversation ${conversation.id}: $e');
      }
    }
  }

  Widget _buildConversationTile(Conversation conversation, bool isFavourite) {
    return FutureBuilder<AICompanion?>(
      future: context.read<ConversationBloc>()
          .getRepository()
          .getCompanion(conversation.companionId),
      builder: (context, companionSnapshot) {
        if (companionSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingTile();
        }

        final companion = companionSnapshot.data;
        if (companion == null) {
          return const SizedBox.shrink();
        }

        // Add debug check for companionName mismatch
        if (conversation.companionName != null && 
            conversation.companionName != companion.name) {
          print('WARNING: Name mismatch for ${conversation.id}: '
                'DB name="${conversation.companionName}", '
                'Companion model name="${companion.name}"');
        }

        final colorScheme = getCompanionColorScheme(companion);
        final dominantEmotion = _companionEmotions[conversation.id];
        
        // Create a unique hero tag for this avatar
        final String heroTag = 'avatar_${companion.id}_${conversation.id}';

        return Dismissible(
          key: Key('conversation_${conversation.id}'),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          secondaryBackground: Container(
            color: colorScheme.primary,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Icon(
              conversation.isPinned ? Icons.favorite : Icons.favorite_border,
              color: Colors.white,
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Delete conversation
              return await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Delete Conversation'),
                    content: Text(
                      'Are you sure you want to delete your conversation with ${companion.name}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );
            } else {
              // Favourite/unfavourite conversation
              context.read<ConversationBloc>().add(
                PinConversation(conversation.id, !conversation.isPinned),
              );
              return false;
            }
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.startToEnd) {
              context.read<ConversationBloc>().add(
                DeleteConversation(conversation.id),
              );
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isFavourite
                    ? colorScheme.primary.withOpacity(0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Stack(
                children: [
                  // Make the avatar tappable to view full profile photo
                  GestureDetector(
                    onTap: () => _openProfilePhoto(companion, heroTag),
                    child: Hero(
                      tag: heroTag,
                      child: Material(
                        type: MaterialType.transparency,
                        child: CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(companion.avatarUrl),
                        ).animate(
                          onPlay: (controller) => controller.forward(),
                        ).scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.05, 1.05),
                          duration: 200.ms,
                        ).then()
                        .scale(
                          begin: const Offset(1.05, 1.05),
                          end: const Offset(1.0, 1.0),
                          duration: 200.ms,
                        ),
                      ),
                    ),
                  ),
                  if (conversation.unreadCount > 0)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.background,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          conversation.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      companion.name,
                      style: TextStyle(
                        fontWeight: conversation.unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isFavourite)
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage == null || conversation.lastMessage!.isEmpty
                        ? 'Start a conversation'
                        : conversation.lastMessage!,
                    style: TextStyle(
                      color: conversation.unreadCount > 0
                          ? Theme.of(context).colorScheme.onBackground
                          : Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                      fontWeight: conversation.unreadCount > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        getPersonalityIcon(companion),
                        size: 14,
                        color: colorScheme.primary.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Level ${conversation.relationshipLevel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _getTimeString(conversation.lastUpdated),
                    style: TextStyle(
                      fontSize: 12,
                      color: conversation.unreadCount > 0
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (dominantEmotion != null)
                    _buildEmotionIndicator(dominantEmotion),
                ],
              ),
              onTap: () {
                // Navigate to chat page
                if (_user != null) {
                  context.read<AuthBloc>().add(
                    AuthEventNavigateToChat(
                      conversationId: conversation.id,
                      companion: companion,
                      user: _user!,
                    ),
                  );

                  // Mark as read when opening
                  if (conversation.unreadCount > 0) {
                    context.read<ConversationBloc>().add(
                      MarkConversationAsRead(conversation.id),
                    );
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  // Add a new method to open the profile photo viewer
  void _openProfilePhoto(AICompanion companion, String heroTag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => 
          ProfilePhotoViewer(
            imageUrl: companion.avatarUrl,
            heroTag: heroTag,
            title: companion.name,
          ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
    
    // Provide haptic feedback for tapping
    HapticFeedback.lightImpact();
  }

  Widget _buildEmotionIndicator(String emotion) {
    // Map emotions to emojis
    final Map<String, String> emotionEmojis = {
      'happy': '😊',
      'excited': '😃',
      'curious': '🤔',
      'neutral': '😐',
      'confused': '😕',
      'concerned': '😟',
      'sad': '😔',
      'angry': '😠',
      'anxious': '😰',
      'affectionate': '🥰',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        emotionEmojis[emotion.toLowerCase()] ?? '😐',
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
    );
  }

  String _getTimeString(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    } else if (messageDate == yesterday) {
      return "Yesterday";
    } else if (now.difference(dateTime).inDays < 7) {
      switch (dateTime.weekday) {
        case 1:
          return "Monday";
        case 2:
          return "Tuesday";
        case 3:
          return "Wednesday";
        case 4:
          return "Thursday";
        case 5:
          return "Friday";
        case 6:
          return "Saturday";
        case 7:
          return "Sunday";
        default:
          return "";
      }
    } else {
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    }
  }

  Widget _buildLoadingList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, __) => _buildLoadingTile(),
      ),
    );
  }

  Widget _buildLoadingTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ).animate().scale(
            duration: 600.ms,
            curve: Curves.easeOutBack,
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onBackground,
            ),
          ).animate().fadeIn(
            duration: 600.ms,
            delay: 300.ms,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start chatting with AI companions that match your interests and personality',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onBackground.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(
            duration: 600.ms,
            delay: 600.ms,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to companion selection
              if (_user != null) {
                context.read<AuthBloc>().add(
                  AuthEventNavigateToCompanion(user: _user!),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please wait, loading Companion information...')),
                );
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Find a Companion'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ).animate().fadeIn(
            duration: 600.ms,
            delay: 900.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadConversations,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback? onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    this.isSelected = false,
    required this.onTap,
  });
}


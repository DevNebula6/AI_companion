import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:ai_companion/Views/chat_screen/chat_page.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/conversation.dart';
import 'package:ai_companion/chat/gemini/companion_relationship_tracker.dart';
import 'package:ai_companion/chat/conversation/conversation_bloc.dart';
import 'package:ai_companion/chat/conversation/conversation_event.dart';
import 'package:ai_companion/chat/conversation/conversation_state.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  String _searchQuery = '';
  late CompanionRelationshipTracker _relationshipTracker;
  bool _isSearching = false;
  final _scrollController = ScrollController();
  CustomAuthUser? _user;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController = TextEditingController();
    _relationshipTracker = CompanionRelationshipTracker(
      context.read<GeminiService>()
    );
    // Initialize the user
    Future.microtask(() async {
      _user = await CustomAuthUser.getCurrentUser();
    });
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    
    // Load conversations on startup
    _loadConversations();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _loadConversations() async {
    final user = await CustomAuthUser.getCurrentUser();
    if (user != null) {
      context.read<ConversationBloc>().add(LoadConversations(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: BlocBuilder<ConversationBloc, ConversationState>(
          builder: (context, state) {
            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    pinned: true,
                    floating: true,
                    forceElevated: innerBoxIsScrolled,
                    elevation: 0,
                    backgroundColor: colorScheme.background,
                    title: _isSearching 
                        ? _buildSearchField()
                        : Text(
                            'Companions',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onBackground,
                            ),
                          ),
                    actions: [
                      IconButton(
                        icon: Icon(_isSearching ? Icons.close : Icons.search),
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_outline),
                        onPressed: () {
                          // Profile page navigation
                        },
                      ),
                    ],
                    bottom: TabBar(
                      controller: _tabController,
                      indicatorColor: colorScheme.primary,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          child: Text(
                            'All',
                            style: TextStyle(
                              color: colorScheme.onBackground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Tab(
                          child: Text(
                            'Favorites',
                            style: TextStyle(
                              color: colorScheme.onBackground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  // All conversations
                  _buildConversationList(state, false),
                  
                  // Favorites only
                  _buildConversationList(state, true),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to companion selection
        },
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ).animate().scale(
        duration: 300.ms,
        curve: Curves.easeOutBack,
        delay: 200.ms,
      ),
    );
  }
  
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      cursorColor: Theme.of(context).colorScheme.primary,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onBackground,
      ),
      decoration: InputDecoration(
        hintText: 'Search companions...',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      autofocus: true,
    );
  }
  
  Widget _buildConversationList(ConversationState state, bool favoritesOnly) {
    if (state is ConversationLoading) {
      return _buildLoadingList();
    } else if (state is ConversationLoaded) {
      List<Conversation> conversations = favoritesOnly 
          ? state.pinnedConversations 
          : state.conversations;
          
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        conversations = conversations.where((c) => 
          c.lastMessage?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false
        ).toList();
      }
      
      if (conversations.isEmpty) {
        return _buildEmptyState(favoritesOnly);
      }
      
      return RefreshIndicator(
        onRefresh: () async {
          final user = await CustomAuthUser.getCurrentUser();
          if (user != null) {
            context.read<ConversationBloc>().add(RefreshConversations(userId: user.id));
          }
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: conversations.length,
          padding: const EdgeInsets.only(bottom: 80),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            // Add staggered animation for items
            return _buildConversationTile(conversation)
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
        ),
      );
    } else if (state is ConversationError) {
      return _buildErrorState(state.message);
    }
    
    return _buildLoadingList();
  }
  
  Widget _buildConversationTile(Conversation conversation) {
    return FutureBuilder<Conversation>(
      future: _relationshipTracker.enrichConversation(conversation),
      builder: (context, snapshot) {
        final enrichedConversation = snapshot.data ?? conversation;
        
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
            
            final colorScheme = getCompanionColorScheme(companion);
            
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
                  conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: Colors.white
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
                          'Are you sure you want to delete your conversation with ${companion.name}?'
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
                  // Pin/unpin conversation
                  context.read<ConversationBloc>().add(
                    PinConversation(conversation.id, !conversation.isPinned)
                  );
                  return false;
                }
              },
              onDismissed: (direction) {
                if (direction == DismissDirection.startToEnd) {
                  context.read<ConversationBloc>().add(
                    DeleteConversation(conversation.id)
                  );
                }
              },
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Stack(
                  children: [
                    Hero(
                      tag: 'avatar_${companion.id}',
                      child: CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(companion.avatarUrl),
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
                    if (conversation.isPinned)
                      Icon(
                        Icons.push_pin,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage ?? 'Start a conversation',
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
                          'Level ${enrichedConversation.relationshipLevel}',
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
                    if (enrichedConversation.dominantEmotion != null)
                      _buildEmotionIndicator(enrichedConversation.dominantEmotion!),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatPage(
                        companion: companion,
                        conversationId: conversation.id,
                      ),
                    ),
                  );
                  
                  // Mark as read when opening
                  if (conversation.unreadCount > 0) {
                    context.read<ConversationBloc>().add(
                      MarkConversationAsRead(conversation.id)
                    );
                  }
                },
              ),
            );
          },
        );
      }
    );
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
    
    return Text(
      emotionEmojis[emotion] ?? '😐',
      style: const TextStyle(
        fontSize: 16,
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
        case 1: return "Monday";
        case 2: return "Tuesday";
        case 3: return "Wednesday";
        case 4: return "Thursday";
        case 5: return "Friday";
        case 6: return "Saturday";
        case 7: return "Sunday";
        default: return "";
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
        itemBuilder: (_, __) => _buildLoadingTile(),
      ),
    );
  }
  
  Widget _buildLoadingTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 10,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(bool favoritesOnly) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            favoritesOnly ? Icons.star_border : Icons.chat_bubble_outline,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ).animate().scale(
            duration: 600.ms,
            curve: Curves.easeOutBack,
          ),
          const SizedBox(height: 16),
          Text(
            favoritesOnly 
                ? 'No favorite companions yet'
                : 'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onBackground,
            ),
          ).animate().fadeIn(
            duration: 600.ms,
            delay: 300.ms,
          ),
          const SizedBox(height: 8),
          Text(
            favoritesOnly
                ? 'Pin your favorite companions to see them here'
                : 'Start a conversation with a companion',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onBackground.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(
            duration: 600.ms,
            delay: 600.ms,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to companion selection
              context.read<AuthBloc>().add(
                AuthEventNavigateToCompanion(user: _user!)
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Find a Companion'),
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
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadConversations,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}


import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:ai_companion/Views/chat_screen/message_bubble/bubble_theme.dart';
import 'package:ai_companion/Views/chat_screen/message_bubble/message_bubble.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/conversation/conversation_bloc.dart';
import 'package:ai_companion/chat/conversation/conversation_event.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/chat/message_bloc/message_bloc.dart';
import 'package:ai_companion/chat/message_bloc/message_event.dart';
import 'package:ai_companion/chat/message_bloc/message_state.dart';
import 'package:ai_companion/navigation/routes_name.dart';
import 'package:floating_bubbles/floating_bubbles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'package:ai_companion/utilities/widgets/floating_connectivity_indicator.dart';
import 'package:ai_companion/services/connectivity_service.dart';

class ChatPage extends StatefulWidget {
  final AICompanion companion;
  final String conversationId;
  final String? navigationSource;
  
  const ChatPage({
    super.key,
    required this.companion,
    required this.conversationId,
    this.navigationSource,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  late ColorScheme _companionColors;
  late MessageBubbleTheme _messageBubbleTheme;
  late AnimationController _profilePanelController;
  bool _showProfilePanel = false;
  StreamSubscription? _typingSubscription;
  CustomAuthUser? user;
  
  // Add references to blocs to avoid context lookups during disposal
  late MessageBloc _messageBloc;
  late ConversationBloc _conversationBloc;
  late ConnectivityService _connectivityService;
  bool _isOnline = true;
  
  int? _activeFragmentIndex;
  bool _isShowingTypingBetweenFragments = false;
  bool _isTypingFromStream = false; // NEW: Track typing state from stream

  @override
  void initState() {
    super.initState();
    
    _messageBloc = context.read<MessageBloc>();
    _conversationBloc = context.read<ConversationBloc>();
    
    _profilePanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _companionColors = getCompanionColorScheme(widget.companion);
    _messageBubbleTheme = MessageBubbleTheme.fromCompanion(widget.companion);

    // Add listener for text changes to update send button
    _messageController.addListener(() {
      setState(() {
        // This will rebuild the gradient send button with proper state
      });
    });
    
    _loadChatAndInitializeCompanion();
    
    // FIXED: Properly listen to typing stream and update UI state
    _typingSubscription = _messageBloc.typingStream.listen((isTyping) {
      if (mounted) {
        setState(() {
          _isTypingFromStream = isTyping;
        });
        print('Typing stream update: $isTyping');
        
        // Auto-scroll to bottom when typing starts to keep indicator visible
        if (isTyping) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _scrollToBottom();
          });
        }
      }
    });
    
    _connectivityService = context.read<ConnectivityService>();
    _setupConnectivityMonitoring();
  }
  
  void _setupConnectivityMonitoring() {
    _isOnline = _connectivityService.isOnline;
    
    _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted && isOnline != _isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
        
        if (isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Connection restored'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }
  
  @override
  void dispose() {
    // Stop any ongoing fragment animations
    if(_isShowingTypingBetweenFragments || _activeFragmentIndex != null) {
      print('Disposing ChatPage: stopping fragment animations');
      _forceCompleteAllFragments();
    }
    
    _syncConversationOnExit();
    
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _profilePanelController.dispose();
    _typingSubscription?.cancel();
    super.dispose();
  }

  // SIMPLIFIED: Force complete any ongoing fragment display animation
  void _forceCompleteAllFragments() {
    try {
      if (!_messageBloc.isClosed) {
        print('Stopping any ongoing fragment animation');
        // With simplified approach, just ensure all messages are fully displayed
        // No complex sequence tracking needed
        setState(() {
          _activeFragmentIndex = null;
          _isShowingTypingBetweenFragments = false;
          _isTypingFromStream = false; // Also reset stream typing state
        });
      }
    } catch (e) {
      print('Error stopping fragment animation: $e');
    }
  }

  void _syncConversationOnExit() {
    if (widget.conversationId.isEmpty) return;
    
    try {
      if (!_conversationBloc.isClosed) {
        // With simplified approach, just sync the current state
        final messages = _messageBloc.currentMessages;
        
        if (messages.isNotEmpty) {
          final lastMessage = messages.last;
          
          _conversationBloc.add(UpdateConversationMetadata(
            markAsRead: true,
            conversationId: widget.conversationId,
            lastMessage: lastMessage.message,
            lastUpdated: lastMessage.created_at,
            unreadCount: 0, // Mark as read when exiting
          ));
          
          print('Synced conversation metadata on exit: ${widget.conversationId}');
        }
      }
    } catch (e) {
      print('Error in conversation sync: $e');
    }
  }
  
  Future<void> _loadChatAndInitializeCompanion() async {
    if (!mounted) return;
    
    // Stop any existing fragment animations before loading new chat
    _forceCompleteAllFragments();

    user = await CustomAuthUser.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _currentUserId = user!.id;
      });
      
      if (!_messageBloc.isClosed && mounted) {
        // OPTIMIZED: Single event that combines initialization and loading
        _messageBloc.add(InitializeCompanionEvent(
          companion: widget.companion,
          userId: user!.id,
          user: user,
          shouldLoadMessages: true,
        ));
      }
    }
  }
  
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || _currentUserId == null) {
      return;
    }
    
    if (_messageBloc.isClosed || !mounted) {
      return;
    }
    
    final userMessage = Message(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}_${_currentUserId}', // Provide unique ID
      messageFragments: [_messageController.text.trim()],
      userId: _currentUserId!,
      companionId: widget.companion.id,
      conversationId: widget.conversationId,
      isBot: false,
      created_at: DateTime.now(),
    );
    
    _messageBloc.add(SendMessageEvent(message: userMessage));
    _messageController.clear();
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _scrollToBottom();
      }
    });
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingConnectivityIndicator(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: BackButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(); // Close loading dialog
              }
              else {
                context.go(RoutesName.home);
              }
            },
          ),
          title: (!_showProfilePanel)? Row(
            children: [
              Hero(
                tag: 'avatar_${widget.companion.id}',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(widget.companion.avatarUrl),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.companion.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ) : null,
          actions: [
            IconButton(
              icon: Icon(
                _showProfilePanel ? Icons.info : Icons.info_outline,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _showProfilePanel = !_showProfilePanel;
                  if (_showProfilePanel) {
                    _profilePanelController.forward();
                  } else {
                    _profilePanelController.reverse();
                  }
                });
              },
            ),
            PopupMenuButton(
              color: Theme.of(context).colorScheme.surface,
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text('Clear Conversation'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onTap: () {
                    Future.delayed(
                      const Duration(milliseconds: 100),
                      () => _showClearConfirmation(context),
                    );
                  },
                ),
                PopupMenuItem(
                  child: ListTile(
                    leading: const Icon(Icons.report_outlined),
                    title: const Text('Report Issue'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            // Background gradient (bottom layer)
            Container(
              decoration: BoxDecoration(
                gradient: createDynamicGradient(
                  widget.companion,
                  type: GradientType.chat,
                ),
              ),
            ),
            
            // Floating bubbles animation (middle layer)
            Positioned.fill(
              child: _buildFloatingBubbles(),
            ),

            // Chat content (top layer)
            BlocConsumer<MessageBloc, MessageState>(
              listener: (context, state) {
                // Standard message handling with auto-scroll
                if (state is MessageLoaded || state is MessageQueued) {
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (mounted) _scrollToBottom();
                  });
                }
                
                // Typing indicator during AI response (simplified approach uses this)
                if (state is MessageReceiving) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) _scrollToBottom();
                  });
                }
                
                if (state is MessageFragmentInProgress) {
                  setState(() {
                    _activeFragmentIndex = null;
                    _isShowingTypingBetweenFragments = false;
                  });
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) _scrollToBottom();
                  });
                }
                
                if (state is MessageFragmentTyping) {
                  setState(() {
                    _isShowingTypingBetweenFragments = true;
                  });
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) _scrollToBottom();
                  });
                }
                
                if (state is MessageFragmentDisplayed) {
                  final fragmentIndex = state.fragment.metadata['fragment_index'] as int?;
                  setState(() {
                    _activeFragmentIndex = fragmentIndex;
                    _isShowingTypingBetweenFragments = false;
                  });
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) _scrollToBottom();
                  });
                }
                
                if (state is MessageFragmentSequenceCompleted) {
                  setState(() {
                    _activeFragmentIndex = null;
                    _isShowingTypingBetweenFragments = false;
                  });
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) _scrollToBottom();
                  });
                }
                
                // Error handling
                if (state is MessageLoaded && !state.isFromCache && state.hasError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send message'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              builder: (context, state) {
                List<Message> baseMessages = _getMessagesFromState(state);
          
                return Column(
                  children: [
                    // Add some top padding to account for transparent app bar
                    SizedBox(height: MediaQuery.of(context).padding.top),
                    
                    if (_showProfilePanel) _buildProfilePanel(),
                    
                    Expanded(
                      child: Stack(
                        children: [
                          // Main chat content with bottom padding for input field
                          Positioned.fill(
                            child: () {
                              if (state is MessageLoading) {
                                return _buildLoadingMessages();
                              } else if (state is MessageError) {
                                return _buildErrorWidget(state);
                              } else if (baseMessages.isNotEmpty) {
                                return _buildEnhancedMessageList(baseMessages, state);
                              } else {
                                return _emptyMessageWidget();
                              }
                            }(),
                          ),
                          // Chat input field at the bottom with overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildGradientInputField(state),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Get messages from various states
  List<Message> _getMessagesFromState(MessageState state) {
    if (state is MessageLoaded) {
      return List<Message>.from(state.messages);
    } else if (state is MessageQueued) {
      return List<Message>.from(state.messages);
    } else if (state is MessageFragmentDisplayed) {
      return List<Message>.from(state.messages);
    } else if (state is MessageFragmentSequenceCompleted) {
      return List<Message>.from(state.messages);
    } else if (state is MessageFragmentInProgress) {
      return List<Message>.from(state.messages);
    } else {
      return List<Message>.from(_messageBloc.currentMessages);
    }
  }

  //message list with integrated typing indicator and debug logging
  Widget _buildEnhancedMessageList(List<Message> messages, MessageState state) {
    // This method should only be called when we know we want to display messages
    // Loading and error states are handled by the parent widget
    
    if (messages.isEmpty) {
      print('No messages received for conversation ${widget.conversationId}');
      return _emptyMessageWidget();
    }
    
    // ROBUST: Filter messages for this conversation with fallback logic
    var conversationMessages = messages.where((msg) => 
      msg.conversationId == widget.conversationId
    ).toList();
    
    // FALLBACK: If no messages match conversationId, try filtering by companionId and userId
    if (conversationMessages.isEmpty && _currentUserId != null) {
      conversationMessages = messages.where((msg) => 
        msg.companionId == widget.companion.id && 
        msg.userId == _currentUserId
      ).toList();
    }

    if (conversationMessages.isEmpty) {
      return _emptyMessageWidget();
    }

    // Get pending message IDs
    final pendingMessageIds = <String>[];
    if (state is MessageLoaded) {
      pendingMessageIds.addAll(state.pendingMessageIds);
    }
    
    // Check if we should show typing indicator
    final shouldShowTyping = _shouldShowTypingIndicator(state);
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      reverse: false,
      itemCount: conversationMessages.length + (shouldShowTyping ? 1 : 0),
      itemBuilder: (context, index) {
      // If this is the typing indicator position
      if (shouldShowTyping && index == conversationMessages.length) {
        return _buildIntegratedTypingIndicator();
      }
      
      final message = conversationMessages[index];// Use filtered messages
      final isUser = !message.isBot;
      
      // Calculate sender relationships
      bool isPreviousSameSender = false;
      bool isNextSameSender = false;
      
      if (index > 0) {
        isPreviousSameSender = conversationMessages[index - 1].isBot == message.isBot; // Use filtered messages
      }
      if (index < conversationMessages.length - 1) {
        isNextSameSender = conversationMessages[index + 1].isBot == message.isBot; // Use filtered messages
      } else if (shouldShowTyping && !isUser) {
        // If typing indicator follows this message and it's from bot, consider it same sender
        isNextSameSender = true;
      }
      
      // Fragment detection
      final isFragment = message.metadata['is_fragment'] == true;
      final fragmentIndex = message.metadata['fragment_index'] as int?;
      final totalFragments = message.metadata['total_fragments'] as int?;
      final isLastFragment = fragmentIndex != null && totalFragments != null && 
                  fragmentIndex == totalFragments - 1;
      
      bool showAvatar = false;
      if (!isUser) {
        if (isFragment) {            
        showAvatar = isLastFragment;
        } else {
        // Regular messages: show when previous sender is different
        showAvatar = !isPreviousSameSender;
        }
      }
      
      final isPending = message.id != null && pendingMessageIds.contains(message.id);
      
      final messageWidget = MessageBubble(
        key: ValueKey('${message.id}_${message.metadata['fragment_index'] ?? 'msg'}'),
        message: message,
        isUser: isUser,
        theme: _messageBubbleTheme,
        companionAvatar: widget.companion.avatarUrl,
        showAvatar: showAvatar,
        isPreviousSameSender: isPreviousSameSender,
        isNextSameSender: isNextSameSender,
        isPending: isPending,
        isFragment: isFragment,
        isLastFragment: isLastFragment,
        fragmentIndex: fragmentIndex,
        totalFragments: totalFragments,
        isActiveFragment: isFragment && fragmentIndex == _activeFragmentIndex,
      );
      
      // Add date dividers for non-fragments
      if (!isFragment && (index == 0 || !_isSameDay(conversationMessages[index - 1].created_at, message.created_at))) {
        return Column(
        children: [
          _buildDateDivider(message.created_at),
          messageWidget,
        ],
        );
      }
      
      return messageWidget;
      },
    );
  }

  // Integrated typing indicator that's part of the chat flow
  Widget _buildIntegratedTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(
        left: 8,
        right: 50,
        top: 3,
        bottom: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar placeholder (invisible to maintain alignment)
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.companion.avatarUrl),
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
          
          // Typing indicator bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDot(delay: 0),
                      _buildDot(delay: 150),
                      _buildDot(delay: 300),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  /// Determine when to show typing indicator
  bool _shouldShowTypingIndicator(MessageState state) {
    // PRIMARY: Check typing stream from MessageBloc (most reliable)
    if (_isTypingFromStream) {
      print('Showing typing: _isTypingFromStream = true');
      return true;
    }
    
    // Show typing during initial AI response generation
    if (state is MessageReceiving) {
      print('Showing typing: MessageReceiving');
      return true;
    }
    
    // Show typing during fragment sequence start
    if (state is MessageFragmentInProgress) {
      print('Showing typing: MessageFragmentInProgress');
      return true;
    }
    
    // Show typing between fragments
    if (state is MessageFragmentTyping) {
      print('Showing typing: MessageFragmentTyping');
      return true;
    }
    
    // Also check local state for typing between fragments (fallback)
    if (_isShowingTypingBetweenFragments) {
      print('Showing typing: _isShowingTypingBetweenFragments');
      return true;
    }

    // Hide typing when fragments are being displayed
    if (state is MessageFragmentDisplayed) {
      print('Hiding typing: MessageFragmentDisplayed');
      return false;
    }
    
    if (state is MessageFragmentSequenceCompleted) {
      print('Hiding typing: MessageFragmentSequenceCompleted');
      return false;
    }
    
    return false;
  }

  /// Empty message widget with companion introduction
  Center _emptyMessageWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Hero(
            tag: 'avatar_${widget.companion.id}_intro',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _companionColors.primary.withOpacity(0.2),
                    _companionColors.secondary.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: _companionColors.primary.withOpacity(0.3),
                  width: 3,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(widget.companion.avatarUrl),
              ),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  'Start a conversation with ${widget.companion.name}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                const SizedBox(height: 8),
                Text(
                  getPersonalityLabel(widget.companion),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Error widget with gradient styling
  Widget _buildErrorWidget(MessageError state) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 32,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error.toString(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _companionColors.primary,
                    _companionColors.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: _loadChatAndInitializeCompanion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
          )),
          const SizedBox(width: 8),
          Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
          )),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return "Today";
    } else if (messageDate == yesterday) {
      return "Yesterday";
    } else if (now.difference(date).inDays < 7) {
      return _getDayName(date.weekday);
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return "Monday";
      case 2: return "Tuesday";
      case 3: return "Wednesday";
      case 4: return "Thursday";
      case 5: return "Friday";
      case 6: return "Saturday";
      case 7: return "Sunday";
      default: return "";
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  Widget _buildProfilePanel() {
    return AnimatedBuilder(
      animation: _profilePanelController,
      builder: (context, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _profilePanelController,
          curve: Curves.easeOutCubic,
        ));
        
        return SlideTransition(
          position: slideAnimation,
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal:16 ,vertical: 2),
        decoration: BoxDecoration(
          color: _companionColors.primary.withOpacity(0.05),
          border: Border(
            bottom: BorderSide(
              color: _companionColors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(widget.companion.avatarUrl),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.companion.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.companion.personality.primaryTraits.join(', '),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.companion.personality.interests
                  .take(5)
                  .map((interest) => _buildInterestChip(interest))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestChip(String interest) {
    return Chip(
      label: Text(
        interest,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white,
        ),
      ),
      backgroundColor: _companionColors.primary.withOpacity(.9),
      avatar: Icon(
        getInterestIcon(interest),
        size: 14,
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(4),
    );
  }

  Widget _buildLoadingMessages() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, index) {
          final isUser = index % 2 == 0;
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 200,
              height: 50,
              margin: EdgeInsets.only(
                top: 8,
                bottom: 8,
                left: isUser ? 80 : 16,
                right: isUser ? 16 : 80,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build seamless messenger-style input field that blends with gradient
  Widget _buildGradientInputField(MessageState state) {
    return Container(
      decoration: BoxDecoration(
        // Use a very subtle gradient overlay that matches the main gradient
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.05),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: createDynamicGradient(
                  widget.companion,
                  type: GradientType.inputField,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
                // Enhanced glass effect
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                enabled: _isOnline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: _isOnline 
                    ? 'Type a message...'
                    : 'Connect to internet to send messages',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _messageController.text.trim().isEmpty
            ? const SizedBox(width: 0) // Placeholder for send button
            : _buildGradientSendButton(state),
        ],
      ),
    );
  }

  /// Build enhanced messenger-style send button
  Widget _buildGradientSendButton(MessageState state) {
    final hasText = _messageController.text.trim().isNotEmpty;
    final canSend = hasText && !_shouldShowTypingIndicator(state);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: (canSend && _isOnline) ? _sendMessage : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: (canSend && _isOnline)
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.7),
                    ],
                  )
                : null,
            color: !(canSend && _isOnline)
                ? Colors.white.withOpacity(0.2)
                : null,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: (canSend && _isOnline)
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Icon(
            _shouldShowTypingIndicator(state)
                ? Icons.more_horiz
                : Icons.send_rounded,
            color: (canSend && _isOnline)
                ? _companionColors.primary
                : Colors.white.withOpacity(0.5),
            size: 22,
          ),
        ),
      ),
    );
  }

  /// Show confirmation dialog for clearing conversation
  Future<void> _showClearConfirmation(BuildContext context) async {
    final companionColors = _companionColors;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Conversation'),
          content: const Text(
            'Are you sure you want to clear this conversation? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [companionColors.primary, companionColors.secondary],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (!_messageBloc.isClosed) {
                    _messageBloc.add(ClearConversation(
                      userId: _currentUserId!,
                      companionId: widget.companion.id,
                    ));
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDot({required int delay}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _companionColors.primary,
        shape: BoxShape.circle,
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
    ).fadeIn(duration: 600.ms)
    .animate(delay: Duration(milliseconds: delay))
    .scaleXY(begin: 0.4, end: 1.0, duration: 600.ms)
    .then()
    .scaleXY(begin: 1.0, end: 0.4, duration: 600.ms);
  }
  
  /// Build companion-specific floating bubbles animation
  Widget _buildFloatingBubbles() {
    final companionColors = getCompanionColors(widget.companion);
    final personalityType = getPersonalityType(widget.companion);
    
    // Get personality-specific bubble configuration
    final bubbleConfig = _getBubbleConfiguration(personalityType, companionColors);
    
    return FloatingBubbles.alwaysRepeating(
      noOfBubbles: bubbleConfig.noOfBubbles,
      colorsOfBubbles: bubbleConfig.colors,
      sizeFactor: bubbleConfig.sizeFactor,
      opacity: bubbleConfig.opacity,
      paintingStyle: bubbleConfig.paintingStyle,
      strokeWidth: bubbleConfig.strokeWidth,
      shape: bubbleConfig.shape,
      speed: bubbleConfig.speed,
    );
  }

  /// Get bubble configuration based on companion personality
  BubbleConfiguration _getBubbleConfiguration(String personalityType, CompanionColors colors) {
    switch (personalityType.toLowerCase()) {
      case 'warm':
        return BubbleConfiguration(
          noOfBubbles: 25,
          colors: [
            colors.gradient1.withOpacity(0.1),
            colors.gradient2.withOpacity(0.08),
            colors.gradient3.withOpacity(0.06),
            Colors.white.withOpacity(0.04),
          ],
          sizeFactor: 0.13,
          opacity: 30,
          paintingStyle: PaintingStyle.fill,
          strokeWidth: 0,
          shape: BubbleShape.circle,
          speed: BubbleSpeed.slow,
        );
        
      case 'creative':
        return BubbleConfiguration(
          noOfBubbles: 25,
          colors: [
            colors.gradient1.withOpacity(0.12),
            colors.gradient2.withOpacity(0.1),
            colors.gradient3.withOpacity(0.08),
            Colors.white.withOpacity(0.05),
            Colors.pinkAccent.withOpacity(0.06),
          ],
          sizeFactor: 0.15,
          opacity: 35,
          paintingStyle: PaintingStyle.fill,
          strokeWidth: 0,
          shape: BubbleShape.circle,
          speed: BubbleSpeed.normal,
        );
        
      case 'calm':
        return BubbleConfiguration(
          noOfBubbles: 20,
          colors: [
            colors.gradient1.withOpacity(0.08),
            colors.gradient2.withOpacity(0.06),
            colors.gradient3.withOpacity(0.04),
            Colors.white.withOpacity(0.03),
          ],
          sizeFactor: 0.1,
          opacity: 25,
          paintingStyle: PaintingStyle.fill,
          strokeWidth: 0,
          shape: BubbleShape.circle,
          speed: BubbleSpeed.slow,
        );
        
      case 'energetic':
        return BubbleConfiguration(
          noOfBubbles: 30,
          colors: [
            colors.gradient1.withOpacity(0.15),
            colors.gradient2.withOpacity(0.12),
            colors.gradient3.withOpacity(0.1),
            Colors.white.withOpacity(0.06),
            Colors.yellowAccent.withOpacity(0.08),
          ],
          sizeFactor: 0.18,
          opacity: 40,
          paintingStyle: PaintingStyle.fill,
          strokeWidth: 0,
          shape: BubbleShape.circle,
          speed: BubbleSpeed.fast,
        );
        
      case 'thoughtful':
        return BubbleConfiguration(
          noOfBubbles: 24,
          colors: [
            colors.gradient1.withOpacity(0.6),
            colors.gradient2.withOpacity(0.05),
            colors.gradient3.withOpacity(0.04),
            Colors.white.withOpacity(0.1),
          ],
          sizeFactor: 0.14,
          opacity: 30,
          paintingStyle: PaintingStyle.fill,
          strokeWidth: 1,
          shape: BubbleShape.circle,
          speed: BubbleSpeed.slow,
        );
        
      case 'mysterious':
        return BubbleConfiguration(
          noOfBubbles: 22,
          colors: [
            colors.gradient1.withOpacity(0.1),
            colors.gradient2.withOpacity(0.08),
            colors.gradient3.withOpacity(0.06),
            Colors.white.withOpacity(0.03),
            Colors.deepPurple.withOpacity(0.05),
          ],
          sizeFactor: 0.18,
          opacity: 28,
          paintingStyle: PaintingStyle.fill,
          strokeWidth: 0,
          shape: BubbleShape.circle,
          speed: BubbleSpeed.normal,
        );
        
      default:
        return BubbleConfiguration(
          noOfBubbles: 25,
          colors: [
            colors.gradient1.withOpacity(0.1),
            colors.gradient2.withOpacity(0.08),
            colors.gradient3.withOpacity(0.06),
            Colors.white.withOpacity(0.04),
          ],
          sizeFactor: 0.15,
          opacity: 30,
          paintingStyle: PaintingStyle.fill,
          strokeWidth: 0,
          shape: BubbleShape.circle,
          speed: BubbleSpeed.normal,
        );
    }
  }
}
class BubbleConfiguration {
  final int noOfBubbles;
  final List<Color> colors;
  final double sizeFactor;
  final int opacity;
  final PaintingStyle paintingStyle;
  final double strokeWidth;
  final BubbleShape shape;
  final BubbleSpeed speed;

  BubbleConfiguration({
    required this.noOfBubbles,
    required this.colors,
    required this.sizeFactor,
    required this.opacity,
    required this.paintingStyle,
    required this.strokeWidth,
    required this.shape,
    required this.speed,
  });
}
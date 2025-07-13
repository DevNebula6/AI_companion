import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:ai_companion/Views/chat_screen/chat_input_field.dart';
import 'package:ai_companion/Views/chat_screen/message_bubble.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/conversation/conversation_bloc.dart';
import 'package:ai_companion/chat/conversation/conversation_event.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/chat/message_bloc/message_bloc.dart';
import 'package:ai_companion/chat/message_bloc/message_event.dart';
import 'package:ai_companion/chat/message_bloc/message_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  // SIMPLIFIED: Fragment-aware conversation sync
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
            lastMessage: lastMessage.message, // Uses our messageFragments.join(' ')
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
        _messageBloc.add(InitializeCompanionEvent(
          companion: widget.companion,
          userId: user!.id,
          user: user,
        ));
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!_messageBloc.isClosed && mounted) {
          _messageBloc.add(LoadMessagesEvent(
            userId: user!.id,
            companionId: widget.companion.id,
          ));
        }
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
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: _companionColors.primary,
          foregroundColor: _companionColors.onPrimary,
          elevation: 0,
          title: Row(
            children: [
              Hero(
                tag: 'avatar_${widget.companion.id}',
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(widget.companion.avatarUrl),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.companion.name,
                  style: TextStyle(
                    color: _companionColors.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _showProfilePanel ? Icons.info : Icons.info_outline,
                color: _companionColors.onPrimary,
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
              icon: Icon(
                Icons.more_vert,
                color: _companionColors.onPrimary,
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
        body: BlocConsumer<MessageBloc, MessageState>(
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
            
            // Backward compatibility: Enhanced fragment handling (if old system is still used)
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
                if (_showProfilePanel) _buildProfilePanel(),
                
                Expanded(
                  child: Stack(
                    children: [
                      if (baseMessages.isNotEmpty)
                        _buildEnhancedMessageList(baseMessages, state),
                      if (baseMessages.isEmpty)
                        _emptyMessageWidget(),
                      if (state is MessageLoading)
                        _buildLoadingMessages(),
                      if (state is MessageError)
                        _buildErrorWidget(state),
                      
                      // Queue status indicator (keep this as overlay)
                      if (state is MessageQueued && state.queueLength > 1)
                        Positioned(
                          top: 8,
                          right: 16,
                          child: _buildQueueStatusIndicator(state.queueLength),
                        ),
                    ],
                  ),
                ),
                
                ChatInputField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  onSend: _sendMessage,
                  isTyping: _shouldShowTypingIndicator(state),
                  isOnline: _isOnline,
                ),
              ],
            );
          },
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

  // FIXED: Enhanced message list with integrated typing indicator and debug logging
  Widget _buildEnhancedMessageList(List<Message> messages, MessageState state) {
    if (state is MessageLoading && messages.isEmpty) {
      return _buildLoadingMessages();
    }

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
      padding: const EdgeInsets.all(16),
      reverse: false,
      itemCount: conversationMessages.length + (shouldShowTyping ? 1 : 0), // FIXED: Use filtered messages
      itemBuilder: (context, index) {
        // If this is the typing indicator position
        if (shouldShowTyping && index == conversationMessages.length) {
          return _buildIntegratedTypingIndicator();
        }
        
        final message = conversationMessages[index]; // FIXED: Use filtered messages
        final isUser = !message.isBot;
        
        // Calculate sender relationships
        bool isPreviousSameSender = false;
        bool isNextSameSender = false;
        
        if (index > 0) {
          isPreviousSameSender = conversationMessages[index - 1].isBot == message.isBot; // FIXED: Use filtered messages
        }
        if (index < conversationMessages.length - 1) {
          isNextSameSender = conversationMessages[index + 1].isBot == message.isBot; // FIXED: Use filtered messages
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

  // Determine when to show typing indicator
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

  // Queue status indicator
  Widget _buildQueueStatusIndicator(int queueLength) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$queueLength messages queued',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildErrorWidget(MessageError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadChatAndInitializeCompanion,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ...existing helper methods...
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

  Center _emptyMessageWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(widget.companion.avatarUrl),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text(
            'Start a conversation with ${widget.companion.name}',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
        ],
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
        padding: const EdgeInsets.all(16),
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
                          color: _companionColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.companion.personality.primaryTraits.join(', '),
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
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
          color: _companionColors.onPrimary,
        ),
      ),
      backgroundColor: _companionColors.primary,
      avatar: Icon(
        getInterestIcon(interest),
        size: 14,
        color: _companionColors.onPrimary,
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

  Future<void> _showClearConfirmation(BuildContext context) async {
    if (!mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Clear Conversation"),
          content: const Text(
            "Are you sure you want to clear this conversation? This action cannot be undone."
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Clear"),
            ),
          ],
        );
      },
    );
    
    if (result == true && _currentUserId != null && mounted && !_messageBloc.isClosed) {
      _messageBloc.add(ClearConversation(
        userId: _currentUserId!,
        companionId: widget.companion.id,
      ));
      _syncConversationOnExit();
    }
  }
}
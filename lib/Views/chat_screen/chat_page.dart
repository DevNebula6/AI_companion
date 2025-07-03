import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Views/AI_selection/companion_color.dart';
import 'package:ai_companion/Views/chat_screen/chat_input_field.dart';
import 'package:ai_companion/Views/chat_screen/message_bubble.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
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

import '../../chat/msg_fragmentation/message_fragmentation.dart';

class ChatPage extends StatefulWidget {
  final AICompanion companion;
  final String conversationId;
  final String? navigationSource; // Add this parameter to track where we came from
  
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
  bool _isTyping = false;
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
  
  // Enhanced Fragment Support with better avatar tracking
  List<String> _currentFragments = [];
  int _displayedFragmentIndex = 0;
  Timer? _fragmentDisplayTimer;
  bool _isDisplayingFragments = false;
  Message? _fragmentingMessage;
  bool _isTypingForFragments = false;
  final List<Message> _temporaryFragmentMessages = [];
  int? _activeFragmentIndex;
  final Set<String> _animatedFragmentIds = {};
  String? _currentFragmentingMessageId; // NEW: Track which message is currently fragmenting

  @override
  void initState() {
    super.initState();
    
    // Store bloc references at initialization
    _messageBloc = context.read<MessageBloc>();
    _conversationBloc = context.read<ConversationBloc>();
    
    _profilePanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _companionColors = getCompanionColorScheme(widget.companion);
    _loadChatAndInitializeCompanion();
    
    // Use the class member instead of reading from context
    _typingSubscription = _messageBloc.typingStream.listen((isTyping) {
      if (mounted) {
        setState(() {
          _isTyping = isTyping;
        });
      }
    });
    
    // Use injected connectivity service for better performance
    _connectivityService = context.read<ConnectivityService>();
    _setupConnectivityMonitoring();
  }
  
  void _setupConnectivityMonitoring() {
    // Get initial status
    _isOnline = _connectivityService.isOnline;
    
    // Listen to changes from centralized service
    _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted && isOnline != _isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
        
        // Show feedback when connectivity changes
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
    // Ensure conversation data is updated when leaving the chat page
    _syncConversationOnExit();
    _markConversationAsRead();

    _fragmentDisplayTimer?.cancel();
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _profilePanelController.dispose();
    _typingSubscription?.cancel();
    super.dispose();
  }

  // 
  void _markConversationAsRead() {
    if (widget.conversationId.isEmpty) return;
    
    try {
      // Use the stored bloc reference instead of context.read
      _conversationBloc.add(MarkConversationAsRead(widget.conversationId));
      print('Marked conversation as read: ${widget.conversationId}');
    } catch (e) {
      print('Error marking conversation as read: $e');
    }
  }

  // Modified sync method to avoid context dependency
  void _syncConversationOnExit() {
    if (widget.conversationId.isEmpty) return;
    
    try {
      // Use the stored bloc reference instead of context.read
      final messages = _messageBloc.currentMessages;
      
      // Check if messages list is not empty before accessing the last element
      if (messages.isNotEmpty) {
        final lastMessage = messages.last;
        
        // Use stored conversationBloc reference
        _conversationBloc.add(UpdateConversationMetadata(
          conversationId: widget.conversationId,
          lastMessage: lastMessage.message,
          lastUpdated: lastMessage.created_at,
        ));
        
        print('Synced conversation metadata on exit: ${widget.conversationId}');
      } else {
        print('No messages to sync on exit');
      }
    } catch (e) {
      print('Error syncing conversation on exit: $e');
      // Non-blocking - we don't want to prevent navigation if this fails
    }
  }
  
  Future<void> _loadChatAndInitializeCompanion() async {
    user = await CustomAuthUser.getCurrentUser();
    if (user != null) {
      setState(() {
        _currentUserId = user!.id;
      });
      
      // Use stored blocs
      _messageBloc.add(InitializeCompanionEvent(
        companion: widget.companion,
        userId: user!.id,
        user: user,
      ));
      _messageBloc.add(LoadMessagesEvent(
        userId: user!.id,
        companionId: widget.companion.id,
      ));
    }
  }
  
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || _currentUserId == null) {
      return;
    }
    
    final userMessage = Message(
      message: _messageController.text.trim(),
      userId: _currentUserId!,
      companionId: widget.companion.id,
      conversationId: widget.conversationId,
      isBot: false,
      created_at: DateTime.now(),
    );
    
    // Use stored messageBloc reference
    _messageBloc.add(SendMessageEvent(message: userMessage));
    _messageController.clear();
    
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
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
  
  Widget _buildMessageList(List<Message> messages) {
    if (messages.isEmpty) {
      return _emptyMessageWidget();
    }
    
    // Get pending message IDs from the MessageBloc state
    final pendingMessageIds = <String>[];
    final messageState = _messageBloc.state;
    if (messageState is MessageLoaded) {
      pendingMessageIds.addAll(messageState.pendingMessageIds);
    }
    
    // Enhanced message list with fragment support
    final displayMessages = _buildDisplayMessagesList(messages);
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      reverse: false,
      itemCount: displayMessages.length + (_isTypingForFragments ? 1 : 0),
      itemBuilder: (context, index) {
        // Handle typing indicator at the end
        if (index == displayMessages.length && _isTypingForFragments) {
          return _buildFragmentTypingIndicator();
        }
        
        final message = displayMessages[index];
        final isUser = !message.isBot;
        
        bool isPreviousSameSender = false;
        bool isNextSameSender = false;
        
        if (index > 0) {
          isPreviousSameSender = displayMessages[index - 1].isBot == message.isBot;
        }
        if (index < displayMessages.length - 1) {
          isNextSameSender = displayMessages[index + 1].isBot == message.isBot;
        }
        
        // Check if this message is pending
        final isPending = message.id != null && pendingMessageIds.contains(message.id);
        final isFragment = message.metadata['is_fragment'] == true;
        final fragmentIndex = message.metadata['fragment_index'] as int?;
        final totalFragments = message.metadata['total_fragments'] as int?;
        final isLastFragment = fragmentIndex != null && totalFragments != null && 
                              fragmentIndex == totalFragments - 1;
        
        // FIXED: Avatar positioning logic - only affect currently loading fragments
        bool showAvatar = false;
        if (!isUser) {
          if (isFragment) {
            // Get the base message ID to identify which fragment sequence this belongs to
            final baseMessageId = _getBaseMessageId(message);
            
            // Check if this fragment belongs to the currently loading message
            final isCurrentlyFragmenting = _isDisplayingFragments && 
                                         _currentFragmentingMessageId != null &&
                                         baseMessageId == _currentFragmentingMessageId;
            
            if (isCurrentlyFragmenting && _activeFragmentIndex != null) {
              // For currently loading fragments: show avatar on active fragment
              showAvatar = fragmentIndex == _activeFragmentIndex;
            } else {
              // For completed fragment sequences: show avatar on last fragment
              showAvatar = isLastFragment;
            }
          } else {
            // For regular messages: show when previous sender is different
            showAvatar = !isPreviousSameSender;
          }
        }
        
        final messageWidget = MessageBubble(
          key: ValueKey(message.id),
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
        );
        
        if (!isFragment && (index == 0 || !_isSameDay(displayMessages[index - 1].created_at, message.created_at))) {
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

  List<Message> _buildDisplayMessagesList(List<Message> originalMessages) {
    final displayMessages = <Message>[];
    
    // Add original messages (excluding any that are being fragmented)
    for (final message in originalMessages) {
      if (_fragmentingMessage == null || message.id != _fragmentingMessage!.id) {
        displayMessages.add(message);
      }
    }
    
    // Add currently displaying fragments
    if (_isDisplayingFragments && _temporaryFragmentMessages.isNotEmpty) {
      displayMessages.addAll(_temporaryFragmentMessages);
    }
    
    return displayMessages;
  }

  Widget _buildFragmentTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 56, bottom: 8, right: 16, top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(left: 0, child: _buildDot(delay: 0)),
                  _buildDot(delay: 150),
                  Positioned(right: 0, child: _buildDot(delay: 300)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Center _emptyMessageWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(widget.companion.avatarUrl),
          ).animate().scale(
            duration: 600.ms,
            curve: Curves.easeOutBack,
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation with ${widget.companion.name}',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(
            duration: 600.ms,
            delay: 300.ms,
          ),
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
  
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    child: _buildDot(delay: 0),
                  ),
                  _buildDot(delay: 150),
                  Positioned(
                    right: 0,
                    child: _buildDot(delay: 300),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
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
    ).fadeIn(
      duration: 600.ms,
    ).animate(
      delay: Duration(milliseconds: delay),
    ).scaleXY(
      begin: 0.4,
      end: 1.0,
      duration: 600.ms,
    ).then().scaleXY(
      begin: 1.0,
      end: 0.4,
      duration: 600.ms,
    );
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
  
  @override
  Widget build(BuildContext context) {
    return FloatingConnectivityIndicator(
      child: WillPopScope(
        onWillPop: () async {
          _syncConversationOnExit();
          return true;
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: _companionColors.onPrimary,
              ),
              color: _companionColors.onPrimary,
              onPressed: () {
                print('Back button pressed');

                if (user != null) {
                  context.read<AuthBloc>().add(AuthEventNavigateToHome(
                    user: user!,
                  ));
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.companion.name,
                        style: TextStyle(
                          color: _companionColors.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
                        () => _showClearConfirmation(),
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: ListTile(
                      leading: const Icon(Icons.report_outlined),
                      title: const Text('Report Issue'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                    },
                  ),
                ],
              ),
            ],
          ),
          body: BlocConsumer<MessageBloc, MessageState>(
            listener: (context, state) {
              // Enhanced scrolling behavior
              if (state is MessageLoaded) {
                Future.delayed(const Duration(milliseconds: 50), () {
                  _scrollToBottom();
                });
              }
              if (state is MessageFragmenting) {
                _handleFragmentedMessage(state);
              }
              if (state is MessageReceiving) {
                // Scroll when typing indicator appears
                Future.delayed(const Duration(milliseconds: 100), () {
                  _scrollToBottom();
                });
              }
              // Add listener for network status changes
              if (state is MessageLoaded && !state.isFromCache && state.hasError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Having trouble connecting.'),
                    duration: Duration(seconds: 3),
                  )
                );
              }
            },
            builder: (context, state) {
              List<Message> baseMessages = state is MessageLoaded 
                  ? List<Message>.from(state.messages)
                  : List<Message>.from(_messageBloc.currentMessages);

              return Column(
                children: [
                  if (_showProfilePanel) _buildProfilePanel(),
                  
                  Expanded(
                    child: Stack(
                      children: [
                        if (baseMessages.isNotEmpty || _temporaryFragmentMessages.isNotEmpty)
                          _buildMessageList(baseMessages),
                        if (baseMessages.isEmpty && _temporaryFragmentMessages.isEmpty)
                          _emptyMessageWidget(),
                        if (state is MessageLoading)
                          _buildLoadingMessages(),
                        if (state is MessageError)
                          Center(
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
                          ),
                        
                        // Regular typing indicator (only when not fragmenting)
                        if (_isTyping && !_isDisplayingFragments)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildTypingIndicator(),
                          ),
                      ],
                    ),
                  ),
                  
                  ChatInputField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    onSend: _sendMessage,
                    isTyping: _isTyping || _isTypingForFragments,
                    isOnline: _isOnline,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  // Enhanced Fragment Display Logic
  void _handleFragmentedMessage(MessageFragmenting state) {
    setState(() {
      _currentFragments = state.fragments;
      _displayedFragmentIndex = 0;
      _isDisplayingFragments = true;
      _fragmentingMessage = state.originalMessage;
      _temporaryFragmentMessages.clear();
      _isTypingForFragments = true;
      _activeFragmentIndex = null;
      // Clear previous fragment animation tracking for new conversation
      _animatedFragmentIds.clear();
      // FIXED: Track which message is currently being fragmented
      _currentFragmentingMessageId = state.originalMessage.id;
    });

    _startFragmentDisplay();
  }

  void _startFragmentDisplay() {
    if (_currentFragments.isEmpty) return;

    // Show first fragment with typing indicator
    _displayNextFragment();
  }

  void _displayNextFragment() {
    if (_displayedFragmentIndex >= _currentFragments.length) {
      _completeFragmentDisplay();
      return;
    }

    // Hide typing indicator and show current fragment
    setState(() {
      _isTypingForFragments = false;
      _activeFragmentIndex = _displayedFragmentIndex;
      
      final fragmentId = '${_fragmentingMessage!.id}_fragment_$_displayedFragmentIndex';
      final fragmentMessage = Message(
        id: fragmentId,
        message: _currentFragments[_displayedFragmentIndex],
        companionId: _fragmentingMessage!.companionId,
        userId: _fragmentingMessage!.userId,
        conversationId: _fragmentingMessage!.conversationId,
        isBot: true,
        created_at: _fragmentingMessage!.created_at.add(Duration(milliseconds: _displayedFragmentIndex * 100)),
        metadata: {
          ..._fragmentingMessage!.metadata,
          'is_fragment': true,
          'fragment_index': _displayedFragmentIndex,
          'total_fragments': _currentFragments.length,
          'fragment_timestamp': DateTime.now().millisecondsSinceEpoch,
          'base_message_id': _fragmentingMessage!.id, // NEW: Explicit base message tracking
        },
      );
      
      // Track this fragment as animated
      _animatedFragmentIds.add(fragmentId);
      _temporaryFragmentMessages.add(fragmentMessage);
    });

    // Enhanced scrolling behavior with proper timing
    final scrollDelay = MessageFragmenter.calculateScrollDelay(_displayedFragmentIndex);
    Future.delayed(Duration(milliseconds: scrollDelay), () {
      if (mounted) {
        _scrollToBottomImmediate();
      }
    });

    // Prepare next fragment
    if (_displayedFragmentIndex < _currentFragments.length - 1) {
      final currentFragment = _currentFragments[_displayedFragmentIndex];
      final delay = MessageFragmenter.calculateTypingDelay(currentFragment, _displayedFragmentIndex);
      
      _fragmentDisplayTimer = Timer(Duration(milliseconds: delay), () {
        if (mounted) {
          setState(() {
            _isTypingForFragments = true;
          });
          
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _scrollToBottomImmediate();
            }
          });
          
          Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              _displayedFragmentIndex++;
              _displayNextFragment();
            }
          });
        }
      });
    } else {
      _fragmentDisplayTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          _completeFragmentDisplay();
        }
      });
    }
  }

  void _completeFragmentDisplay() {
    if (_fragmentingMessage == null) return;

    setState(() {
      _isDisplayingFragments = false;
      _isTypingForFragments = false;
      // FIXED: Clear the currently fragmenting message ID
      _currentFragmentingMessageId = null;
    });

    // Add fragments to permanent storage with proper base message ID
    for (int i = 0; i < _temporaryFragmentMessages.length; i++) {
      final tempFragment = _temporaryFragmentMessages[i];
      final permanentFragment = tempFragment.copyWith(
        id: 'permanent_fragment_${DateTime.now().millisecondsSinceEpoch}_$i',
        created_at: _fragmentingMessage!.created_at.add(Duration(milliseconds: i * 50)),
        metadata: {
          ...tempFragment.metadata,
          'base_message_id': _fragmentingMessage!.id, // Preserve base message tracking
        },
      );
      
      _messageBloc.add(AddFragmentMessageEvent(permanentFragment));
    }

    // Reset fragmentation state
    _currentFragments.clear();
    _displayedFragmentIndex = 0;
    _fragmentingMessage = null;
    _fragmentDisplayTimer?.cancel();
    
    // Clear temporary fragments and reset tracking after delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _temporaryFragmentMessages.clear();
          _activeFragmentIndex = null;
          // Keep animated fragment IDs to prevent re-animation
        });
      }
    });
    
    // Update conversation metadata
    final userMessage = _messageBloc.currentMessages
        .where((m) => !m.isBot)
        .lastOrNull;
        
    if (userMessage != null) {
      _messageBloc.add(NotifyFragmentationCompleteEvent(userMessage.conversationId));
    }
  }

  void _scrollToBottomImmediate() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
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
  
  Future<void> _showClearConfirmation() async {
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
    
    if (result == true && _currentUserId != null) {
      // Use stored messageBloc reference
      _messageBloc.add(ClearConversation(
        userId: _currentUserId!,
        companionId: widget.companion.id,
      ));
    }
  }
  
  String _getBaseMessageId(Message message) {
    if (message.metadata['is_fragment'] == true) {
      // First check for explicit base_message_id in metadata
      final baseId = message.metadata['base_message_id']?.toString();
      if (baseId != null && baseId.isNotEmpty) {
        return baseId;
      }
      
      // Extract base ID from fragment ID
      final fragmentId = message.id ?? '';
      if (fragmentId.contains('_fragment_')) {
        return fragmentId.split('_fragment_')[0];
      }
      
      // Fallback: use a combination that's unique to this message sequence
      return '${message.companionId}_${message.created_at.millisecondsSinceEpoch ~/ 1000}';
    }
    
    // For non-fragment messages, return the message ID or generate a fallback
    return message.id ?? '${message.companionId}_${message.created_at.millisecondsSinceEpoch ~/ 1000}';
  }
}

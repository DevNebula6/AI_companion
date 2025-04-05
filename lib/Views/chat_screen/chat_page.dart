import 'package:ai_companion/Views/AI_selection/companion_color.dart' show getPersonalityType;
import 'package:ai_companion/Views/AI_selection/companion_details_sheet.dart';
import 'package:ai_companion/Views/chat_screen/chat_input_field.dart';
import 'package:ai_companion/Views/chat_screen/message_bubble.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/chat/message_bloc/message_bloc.dart';
import 'package:ai_companion/chat/message_bloc/message_event.dart';
import 'package:ai_companion/chat/message_bloc/message_state.dart';
import 'package:ai_companion/utilities/constants/textstyles.dart';
import 'package:ai_companion/utilities/widgets/typing_indicator.dart';

class ChatPage extends StatefulWidget {
  final AICompanion companion;
  final CustomAuthUser user;

  const ChatPage({
    super.key,
    required this.companion,
    required this.user,
  });
  
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showScrollToBottom = false;
  bool _isTyping = false;
  
  // Add animation controllers for message animations
  late final AnimationController _sendAnimationController;
  
  @override
  void initState() {
    super.initState();
        
    // Initialize animation controller
    _sendAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Load messages for this companion
    context.read<MessageBloc>().add(
      LoadMessagesEvent(
        userId: widget.user.id,
        companionId :widget.companion.id,
      )
    );
    
    // Show scroll button when not at bottom
    _scrollController.addListener(() {
      final showButton = _scrollController.hasClients && 
        _scrollController.position.maxScrollExtent - 
        _scrollController.position.pixels > 300;
      
      if (showButton != _showScrollToBottom) {
        setState(() => _showScrollToBottom = showButton);
      }
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _sendAnimationController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _handleSendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      // Create and send the message
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: text,
        companionId: widget.companion.id,
        userId: widget.user.id,
        isBot: false,
        created_at: DateTime.now(),
      );
      
      // Trigger animation
      _sendAnimationController.forward(from: 0);
      
      // Send through bloc
      context.read<MessageBloc>().add(SendMessageEvent(
        message: message,
      ));
      
      // Clear input
      _textController.clear();
      
      // Set typing indicator
      setState(() => _isTyping = true);
      
      // Scroll to bottom after a short delay
      Future.delayed(const Duration(milliseconds: 500), _scrollToBottom);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          children: [
            // Use hero animation for smooth transition
            Hero(
              tag: 'companion-avatar-${widget.companion.id}',
              child: CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(widget.companion.avatarUrl),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.companion.name,
              style: AppTextStyles.appBarTitle,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          image: const DecorationImage(
            image: AssetImage('assets/backgrounds/pt2.png'),
            opacity: 0.2,
            repeat: ImageRepeat.repeat,
          ),
        ),
        child: Column(
          children: [
            // Message List
            Expanded(
              child: BlocConsumer<MessageBloc, MessageState>(
                listener: (context, state) {
                  // Auto-scroll and handle typing indicator
                  if (state is MessageSent) {
                    setState(() => _isTyping = false);
                    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
                  } else if (state is MessageReceiving) {
                    setState(() => _isTyping = true);
                  }
                },
                buildWhen: (previous, current) {
                  // Optimize rebuilds
                  if (previous is MessageLoaded && current is MessageLoaded) {
                    return previous.currentMessages != current.currentMessages;
                  }
                  return true;
                },
                builder: (context, state) {
                  if (state is MessageLoaded) {
                    final messages = state.currentMessages;
                    
                    if (messages.isEmpty) {
                      return _buildEmptyState();
                    }
                    
                    return Stack(
                      children: [
                        // Main message list
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show typing indicator at the end if needed
                            if (_isTyping && index == messages.length) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: TypingIndicator(
                                  bubbleColor: colorScheme.surfaceVariant,
                                  dotColor: colorScheme.onSurfaceVariant,
                                ),
                              );
                            }
                            
                            final message = messages[index];
                            final isUser = !message.isBot;
                            final showAvatar = !isUser && (index == 0 || 
                                messages[index - 1].isBot != message.isBot);
                                
                            return MessageBubble(
                              message: message,
                              isUser: isUser,
                              showAvatar: showAvatar,
                              companionAvatar: widget.companion.avatarUrl,
                              animation: _sendAnimationController,
                              isPreviousSameSender: index > 0 && 
                                  messages[index - 1].isBot == message.isBot,
                              isNextSameSender: index < messages.length - 1 && 
                                  messages[index + 1].isBot == message.isBot,
                            );
                          },
                        ),
                        
                        // Scroll to bottom button
                        if (_showScrollToBottom)
                          Positioned(
                            right: 16,
                            bottom: 24,
                            child: FloatingActionButton.small(
                              onPressed: _scrollToBottom,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(
                                Icons.arrow_downward,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    );
                  } else if (state is MessageLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Loading conversation...',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  } else if (state is MessageError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load messages',
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => context.read<MessageBloc>().add(
                              LoadMessagesEvent(
                                userId: widget.user.id,
                                companionId: widget.companion.id,
                              )
                            ),
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return const SizedBox();
                  }
                },
              ),
            ),
            
            // Input field
            ChatInputField(
              controller: _textController,
              focusNode: _focusNode,
              onSend: _handleSendMessage,
              isTyping: _isTyping,
            ),
          ],
        ),
      ),
    );
  }
  
  // Empty state widget when no messages exist
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Companion avatar
            Hero(
              tag: 'companion-avatar-${widget.companion.id}',
              child: CircleAvatar(
                radius: 48,
                backgroundImage: NetworkImage(widget.companion.avatarUrl),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start chatting with ${widget.companion.name}',
              style: AppTextStyles.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.companion.description,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            _buildSuggestionChips(),
          ],
        ),
      ),
    );
  }
  
  // Quick suggestion chips for starting conversations
  Widget _buildSuggestionChips() {
    // Generate suggestions based on companion personality
    final List<String> suggestions;
    
    switch (getPersonalityType(widget.companion)) {
      case 'friendly':
        suggestions = [
          "Hi, nice to meet you!",
          "What's your story?",
          "How can you help me today?",
          "Tell me something interesting"
        ];
        break;
      case 'philosophical':
        suggestions = [
          "What is consciousness?",
          "How can I find meaning in life?",
          "What's your view on happiness?",
          "Tell me about the nature of reality"
        ];
        break;
      case 'professional':
        suggestions = [
          "How can I be more productive?",
          "What skills should I develop?",
          "Help me with personal growth",
          "Tell me about your expertise"
        ];
        break;
      default:
        suggestions = [
          "Hi, nice to meet you!",
          "Tell me about yourself",
          "What can we talk about?",
          "How are you today?"
        ];
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions.map((text) {
        return ActionChip(
          label: Text(text),
          onPressed: () {
            _textController.text = text;
            _handleSendMessage();
          },
        );
      }).toList(),
    );
  }
  
  // Chat options menu
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(widget.companion.avatarUrl),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      widget.companion.name,
                      style: AppTextStyles.appBarTitle,
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear conversation'),
                onTap: () {
                  Navigator.pop(context);
                  _showClearConfirmation(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('View companion details'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to companion details page
                  CompanionDetailsSheet(
                    companion: widget.companion,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Chat settings'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to chat settings page
                  // To be implemented
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Confirmation dialog for clearing chat history
  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear Conversation'),
          content: Text(
            'Are you sure you want to clear your conversation with ${widget.companion.name}? '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                context.read<MessageBloc>().add(ClearConversation(
                  userId: widget.user.id,
                  companionId: widget.companion.id,
                ));
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('CLEAR'),
            ),
          ],
        );
      },
    );
  }
}
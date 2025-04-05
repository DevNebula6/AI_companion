import 'package:ai_companion/Companion/ai_model.dart';
import 'package:ai_companion/Companion/bloc/companion_bloc.dart';
import 'package:ai_companion/Companion/bloc/companion_state.dart';
import 'package:ai_companion/Views/chat_screen/chat_page.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/conversation.dart';
import 'package:ai_companion/chat/conversation_bloc.dart/conversation_bloc.dart';
import 'package:ai_companion/chat/conversation_bloc.dart/conversation_event.dart';
import 'package:ai_companion/chat/conversation_bloc.dart/conversation_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ai_companion/utilities/constants/textstyles.dart';
import 'package:ai_companion/Views/AI_selection/companion_selection.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CustomAuthUser user;

  @override
  void initState() {
    super.initState();
    
    // Get the current user from the context
    user = context.read<CustomAuthUser>();
    
    // Request conversation data when screen initializes
    context.read<ConversationBloc>().add(LoadConversations());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Companions',
          style: AppTextStyles.appBarTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Will implement search functionality later
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon'))
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ConversationBloc, ConversationState>(
        builder: (context, state) {
          if (state is ConversationLoading) {
            return _buildLoadingState();
          } else if (state is ConversationLoaded) {
            return _buildConversationList(context, state);
          } else if (state is ConversationError) {
            return _buildErrorState(state);
          } else {
            return _buildEmptyState();
          }
        },
      ),
      // Add button to create a new conversation
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCompanionSelection(context),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Loading UI with shimmer effect
  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: ListTile(
              leading: const CircleAvatar(radius: 24),
              title: Container(
                height: 14,
                width: double.infinity,
                color: Colors.white,
              ),
              subtitle: Container(
                height: 12,
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8, right: 40),
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  // Error state UI
  Widget _buildErrorState(ConversationError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<ConversationBloc>().add(LoadConversations()),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // Main conversation list UI
  Widget _buildConversationList(BuildContext context, ConversationLoaded state ) {
    final theme = Theme.of(context);
    List<String> companionsId  = state.conversations.map((c) => c.companionId).toList();
    List<AICompanion> companions = context.read<CompanionBloc>().state is CompanionLoaded
        ? (context.read<CompanionBloc>().state as CompanionLoaded).companions
        : [];
    companions = companions.where((c) => companionsId.contains(c.id)).toList();

    if (state.conversations.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      slivers: [
        // Pinned conversations section
        if (state.pinnedConversations.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'PINNED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildConversationTile(
                context,
                state.pinnedConversations[index],
                companions,
              ),
              childCount: state.pinnedConversations.length,
            ),
          ),
        ],
        
        // Regular conversations section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'RECENT CONVERSATIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildConversationTile(
              context,
              state.regularConversations[index],
              companions,
            ),
            childCount: state.regularConversations.length,
          ),
        ),
      ],
    );
  }

  // Individual conversation tile
  Widget _buildConversationTile(BuildContext context, Conversation conversation, List<AICompanion> companions) {
  
    final theme = Theme.of(context);
    // Get companion data from the list of companions
    AICompanion conversationCompanion = companions.firstWhere(
      (companion) => companion.id == conversation.companionId,
    );

    return Dismissible(
      key: Key('conversation_${conversation.id}'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _showDeleteConfirmation(context, conversationCompanion.name),
      onDismissed: (_) {
        context.read<ConversationBloc>().add(
          DeleteConversation(conversation.id)
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation with ${conversationCompanion.name} deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                // Would implement undo functionality here
                // For now just show a message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Undo feature coming soon'))
                );
              },
            ),
          )
        );
      },
      child: InkWell(
        onTap: () => _navigateToChat(context, conversation, conversationCompanion),
        onLongPress: () {
          // Show options to pin/unpin conversation
          context.read<ConversationBloc>().add(
            PinConversation(conversation.id, !conversation.isPinned)
          );
        },
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, 
            vertical: 8,
          ),
          leading: Stack(
            children: [
              // Companion avatar
              Hero(
                tag: 'companion-avatar-${conversation.companionId}',
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(conversationCompanion.avatarUrl),
                ),
              ),
              
              // Unread indicator
              if (conversation.unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
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
                ),
            ],
          ),
          title: Row(
            children: [
              // Companion name
              Expanded(
                child: Text(
                  conversationCompanion.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: conversation.unreadCount > 0 
                        ? FontWeight.bold 
                        : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Last message time
              if (conversation.lastMessage != null)
                Text(
                  _formatTime(conversation.lastUpdated),
                  style: TextStyle(
                    fontSize: 12,
                    color: conversation.unreadCount > 0 
                        ? theme.colorScheme.primary 
                        : Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              // Last message preview
              Text(
                conversation.lastMessage ?? 'Start a conversation',
                style: TextStyle(
                  fontSize: 14,
                  color: conversation.unreadCount > 0 
                      ? Colors.black87 
                      : Colors.grey.shade600,
                  fontWeight: conversation.unreadCount > 0 
                      ? FontWeight.w500 
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          // Pin/unpin button
          trailing:conversation.isPinned? Icon(
              conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: conversation.isPinned ? theme.colorScheme.primary : null,
              size: 20,
            ) : null,
          ),
      ),
    );
  }

  // Empty state UI when no conversations exist
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/backgrounds/pt5.png', 
            width: 150,
            // If the asset doesn't exist, use a placeholder icon
            errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text(
            'No conversations yet',
            style: AppTextStyles.displaySmall,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Start chatting with an AI companion to see your conversations here',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _navigateToCompanionSelection(context),
            icon: const Icon(Icons.add),
            label: const Text('Find a Companion'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to navigate to chat screen
  void _navigateToChat(BuildContext context, Conversation conversation,AICompanion conversationCompanion) {
    // Mark as read when opening
    if (conversation.unreadCount > 0) {
      context.read<ConversationBloc>().add(
        MarkConversationAsRead(conversation.id)
      );
    }
    
    // Navigate to chat page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          user:user ,
          companion: conversationCompanion,
        ),
      ),
    );
  }

  // Helper method to navigate to companion selection
  void _navigateToCompanionSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CompanionSelectionPage(),
      ),
    );
  }

  // Show delete confirmation dialog
  Future<bool> _showDeleteConfirmation(
    BuildContext context, 
    String companionName
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text(
          'Are you sure you want to delete your conversation with $companionName?'
          '\nThis cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Format the timestamp for display
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      // Format as time for today's messages
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      // Show weekday for messages from earlier this week
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dateTime.weekday - 1];
    } else {
      // Show date for older messages
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
import 'package:ai_companion/Views/Home/message_bubble.dart';
import 'package:ai_companion/auth/Bloc/auth_bloc.dart';
import 'package:ai_companion/auth/Bloc/auth_event.dart';
import 'package:ai_companion/auth/Bloc/auth_state.dart';
import 'package:ai_companion/auth/custom_auth_user.dart';
import 'package:ai_companion/chat/chat_bloc/chat_bloc.dart';
import 'package:ai_companion/chat/chat_bloc/chat_event.dart';
import 'package:ai_companion/chat/chat_bloc/chat_state.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:ai_companion/utilities/Dialogs/generic_dialog.dart';
import 'package:ai_companion/utilities/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late CustomAuthUser user;
   UserAvatar? userAvatar;


  @override
  void initState() {
    super.initState();
    // Initialize user in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
      _initilaizeUserAvatar();
    });
  }

  void _initializeUserData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthStateLoggedIn) {
      // print('User ID: ${authState.user.id}');
      setState(() {
        user = authState.user;
      });
      context.read<ChatBloc>().add(
        LoadMessagesEvent(
          userId: user.id,
          userName: user.email.split('@')[0],
          )
        );
    }
  }
  void _initilaizeUserAvatar(){
    setState(() {
      userAvatar = UserAvatar(
        user: user,
        size: 32,
      );
    });
  }
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final shouldLogout = await showLogoutOptions(context);
                if (shouldLogout) {
                  context.read<AuthBloc>().add(
                        const AuthEventLogOut(),
                  );
                }
            },
          ),
        ],
      ),
      body: 
       BlocConsumer<ChatBloc, ChatState>(
          listener: (context, state) {
          if (state is MessageSent){
            _scrollToBottom();
          }
          if (state is ChatLoaded ) {
            _scrollToBottom();
          }
          },
          buildWhen: (previous, current) {
            return current is! MessageSent;
          },
          builder: (context, chatState) {
                if (chatState is ChatLoaded) {
                  return Column(
                    children: [
                      Expanded(
                        child:StreamBuilder<List<Message>>(
                          stream: chatState.messageStream,
                          builder: (context, snapshot) {
                            // if (snapshot.hasError) {
                            //   return Center(child: Text('Error: ${snapshot.error}'));
                            // }
                            
                            final messages = chatState.currentMessages;
                            if (messages.isEmpty) {
                              return const Center(child: Text('No messages yet'));
                            }   
                            return ListView.builder(
                              controller: _scrollController,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                return MessageBubble(
                                  message: message,
                                  userAvatar: userAvatar!,
                                  );
                              },
                      );
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            );
          }
          if (chatState is ChatLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (chatState is ChatError) {
            return const Center(child: Text('An error occurred'));
          }
          if (chatState is ChatInitial) {
            return const Center(child: Text('Loading...'));
          }
          return const Center(child: Text("An error occurred"));
        },
      )
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (_messageController.text.isNotEmpty) {
                context.read<ChatBloc>().add(
                  SendMessageEvent(
                    userId: user.id,
                    message: _messageController.text,
                  ),
                );
                _messageController.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<bool> showLogoutOptions(BuildContext context) {
  return showGenericDialog<bool>(
    context: context,
    title: 'Logout',
    content: 'Are you sure you want to logout?',
    options: () => {
      'Logout': true,
      'Cancel': false,
    },
  ).then((value) => value ?? false);
}
}
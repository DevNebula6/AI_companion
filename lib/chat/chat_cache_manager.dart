import 'dart:convert';
import 'package:ai_companion/chat/conversation.dart';
import 'package:ai_companion/chat/message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatCacheService {
  // Existing constants for message caching
  static const String _cacheKeyPrefix = 'chat_messages_';
  static const String _lastSyncKey = 'last_sync_';
  static const String _cacheVersionKey = 'cache_version';
  static const String _currentVersion = '2.0';
  static const int _maxCacheSize = 1000;
  static const Duration _cacheValidityDuration = Duration(hours: 12);
  
  // New constants for conversation caching
  static const String _conversationCacheKeyPrefix = 'conversations_';
  static const String _conversationLastSyncKey = 'conversation_last_sync_';
  static const int _maxConversationCacheSize = 50;
  
  final SharedPreferences _prefs;
  
  ChatCacheService(this._prefs) {
    _initializeCache();
  }

  Future<void> _initializeCache() async {
    // Handle version migration - the version was previously stored as int
    String? version;
    try {
      // First try to get as string (new format)
      version = _prefs.getString(_cacheVersionKey);
    } catch (e) {
      // If that fails, it might be the old int format
      try {
        final intVersion = _prefs.getInt(_cacheVersionKey);
        if (intVersion != null) {
          // Convert old int version to string for comparison
          version = intVersion.toString();
          print('Converted old integer version $intVersion to string');
        }
      } catch (e) {
        print('Error reading cache version: $e');
      }
    }

    // Always update to the new string version format
    if (version == null || version != _currentVersion) {
      await _prefs.setString(_cacheVersionKey, _currentVersion);
      await _prefs.setBool('isInitialized', true);
      
      // If version upgrade, clear all existing caches to avoid format issues
      if (version != null && version != _currentVersion) {
        await clearAllCaches();
        print('Cache version updated from $version to $_currentVersion, cleared old caches');
      }
    }
  }

  // method to clear all chat caches
  Future<void> clearAllCaches() async {
    final allKeys = _prefs.getKeys();
    final chatKeys = allKeys.where((key) => 
      key.startsWith(_cacheKeyPrefix) || key.startsWith(_lastSyncKey));
    
    for (final key in chatKeys) {
      await _prefs.remove(key);
    }
    print('Cleared all chat caches');
  }

  // Cache messages for a specific user and companion
  Future<void> cacheMessages(String userId, List<Message> messages, {String? companionId}) async {
    try {
      // Ensure messages don't exceed max cache size
      if (messages.length > _maxCacheSize) {
        messages = messages.sublist(messages.length - _maxCacheSize);
      }
      
      if (companionId != null) {
        // Cache companion-specific messages
        final key = _getCompanionCacheKey(userId, companionId);
        final filteredMessages = messages.where((m) => m.companionId == companionId).toList();
        
        if (filteredMessages.isNotEmpty) {
          final data = filteredMessages.map((m) => m.toJson()).toList();
          await _prefs.setString(key, jsonEncode(data));
          await _updateLastSync(userId, companionId: companionId);
        }
      } else {
        // Cache all user messages (maintain backward compatibility)
        final key = _getUserCacheKey(userId);
        final data = messages.map((m) => m.toJson()).toList();
        await _prefs.setString(key, jsonEncode(data));
        await _updateLastSync(userId);
      }
      
      await _prefs.setBool('hasCache', true);
    } catch (e) {
      print('Cache write error: $e');
      _handleCacheError(userId, companionId: companionId);
    }
  }

  // Get cached messages, filtered by companion if specified
  List<Message> getCachedMessages(String userId, {String? companionId}) {
    try {
      if (companionId != null) {
        // Get companion-specific messages
        final key = _getCompanionCacheKey(userId, companionId);
        return _parseMessagesFromCache(key);
      } else {
        // Get all user messages (maintain backward compatibility)
        final key = _getUserCacheKey(userId);
        final messages = _parseMessagesFromCache(key);
        
        // Try reading from companion-specific caches if main cache is empty
        if (messages.isEmpty) {
          final companionKeys = _findCompanionCacheKeys(userId);
          final allMessages = <Message>[];
          
          for (final key in companionKeys) {
            allMessages.addAll(_parseMessagesFromCache(key));
          }
          
          return allMessages;
        }
        
        return messages;
      }
    } catch (e) {
      print('Cache read error: $e');
      _handleCacheError(userId, companionId: companionId);
      return [];
    }
  }

  // Helper to find all companion cache keys for a user
  List<String> _findCompanionCacheKeys(String userId) {
    final prefix = '$_cacheKeyPrefix$userId';
    return _prefs.getKeys()
      .where((k) => k.startsWith(prefix) && k != _getUserCacheKey(userId))
      .toList();
  }

  // Helper to parse messages from cache
  List<Message> _parseMessagesFromCache(String key) {
    final data = _prefs.getString(key);
    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        return jsonList
            .where((json) => json != null)
            .map((json) => Message.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error parsing messages from cache: $e');
        return [];
      }
    }
    return [];
  }

  void _handleCacheError(String userId, {String? companionId}) {
    try {
      // Clear corrupted cache
      if (companionId != null) {
        _prefs.remove(_getCompanionCacheKey(userId, companionId));
        _prefs.remove(_getLastSyncKey(userId, companionId: companionId));
      } else {
        _prefs.remove(_getUserCacheKey(userId));
        _prefs.remove(_getLastSyncKey(userId));
      }
    } catch (e) {
      print('Error clearing corrupted cache: $e');
    }
  }

  // Check if cache needs syncing
  bool needsSync(String userId, {String? companionId}) {
    final lastSync = _getLastSync(userId, companionId: companionId);
    return lastSync == null || 
           DateTime.now().difference(lastSync) > _cacheValidityDuration;
  }

  Future<void> _updateLastSync(String userId, {String? companionId}) async {
    final key = _getLastSyncKey(userId, companionId: companionId);
    await _prefs.setString(
      key,
      DateTime.now().toIso8601String(),
    );
  }

  DateTime? _getLastSync(String userId, {String? companionId}) {
    final key = _getLastSyncKey(userId, companionId: companionId);
    final timestamp = _prefs.getString(key);
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  // Updated key generators that include companionId when available
  String _getUserCacheKey(String userId) => '$_cacheKeyPrefix${userId}_all';
  String _getCompanionCacheKey(String userId, String companionId) => '$_cacheKeyPrefix${userId}_$companionId';
  String _getLastSyncKey(String userId, {String? companionId}) => 
    companionId != null ? '$_lastSyncKey${userId}_$companionId' : '$_lastSyncKey$userId';


  // Paginated access to cached messages
  List<Message> getCachedMessagesPaginated(String userId, {
    String? companionId, 
    int limit = 50, 
    int offset = 0
  }) {
    try {
      final allMessages = getCachedMessages(userId, companionId: companionId);
      if (allMessages.isEmpty) return [];
      
      // Sort messages by timestamp (newest first)
      allMessages.sort((a, b) => b.created_at.compareTo(a.created_at));
      
      final startIndex = offset < allMessages.length ? offset : 0;
      final endIndex = (startIndex + limit) < allMessages.length 
          ? startIndex + limit 
          : allMessages.length;
      
      return allMessages.sublist(startIndex, endIndex);
    } catch (e) {
      print('Cache pagination error: $e');
      return [];
    }
  }

  // Check if we have any cached data
  bool hasCachedData(String userId, {String? companionId}) {
    if (companionId != null) {
      return _prefs.containsKey(_getCompanionCacheKey(userId, companionId));
    } else {
      return _prefs.containsKey(_getUserCacheKey(userId)) ||
             _findCompanionCacheKeys(userId).isNotEmpty;
    }
  }

  // ===== NEW CONVERSATION CACHING METHODS =====

  /// Enhanced cache conversations method that preserves companion names
  Future<void> cacheConversations(String userId, List<Conversation> conversations) async {
    try {
      // Ensure conversations don't exceed max cache size
      if (conversations.length > _maxConversationCacheSize) {
        conversations = conversations.sublist(conversations.length - _maxConversationCacheSize);
      }
      
      final key = _getConversationCacheKey(userId);
      
      // Convert to JSON while preserving all data including companion names
      final data = conversations.map((c) {
        final json = c.toJson();
        // Ensure companion_name is included
        if (json['companion_name'] == null || json['companion_name'].toString().isEmpty) {
          print('WARNING: Caching conversation ${c.id} without companion name');
        }
        return json;
      }).toList();
      
      await _prefs.setString(key, jsonEncode(data));
      await _updateConversationLastSync(userId);
      
      // Store companion IDs separately for quick reference
      final companionIds = conversations.map((c) => c.companionId).toSet().toList();
      await _prefs.setStringList('${key}_companion_ids', companionIds);
      
      print('Cached ${conversations.length} conversations for user $userId');
      
      // Debug what was actually cached
      print('Cached conversation names: ${conversations.map((c) => c.companionName).toList()}');
    } catch (e) {
      print('Error caching conversations: $e');
    }
  }
  
  /// Get cached conversations for a user with better error handling
  List<Conversation> getCachedConversations(String userId) {
    try {
      final key = _getConversationCacheKey(userId);
      final data = _prefs.getString(key);
      
      if (data == null || data.isEmpty) {
        print('No cached conversations found for user $userId');
        return [];
      }
      
      final List<dynamic> jsonList = jsonDecode(data);
      final conversations = <Conversation>[];
      
      print('Found ${jsonList.length} cached conversations in storage');
      
      for (var json in jsonList) {
        try {
          final conversationMap = json as Map<String, dynamic>;
          
          // Enhanced validation
          if (conversationMap['id'] == null || conversationMap['companion_id'] == null) {
            print('Skipping invalid cached conversation: missing id or companion_id');
            continue;
          }
          
          final conversation = Conversation(
            id: conversationMap['id'] ?? '',
            userId: conversationMap['user_id'] ?? '',
            companionId: conversationMap['companion_id'] ?? '',
            companionName: conversationMap['companion_name'], // This should now be preserved
            lastMessage: conversationMap['last_message'],
            unreadCount: conversationMap['unread_count'] ?? 0,
            lastUpdated: conversationMap['last_updated'] != null 
                ? DateTime.parse(conversationMap['last_updated']) 
                : DateTime.now(),
            isPinned: conversationMap['is_pinned'] ?? false,
            metadata: conversationMap['metadata'] as Map<String, dynamic>? ?? {},
          );
          
          conversations.add(conversation);
          print('Loaded cached conversation: ${conversation.companionName} (${conversation.id})');
        } catch (e) {
          print('Error parsing cached conversation: $e');
        }
      }
      
      print('Successfully loaded ${conversations.length} conversations from cache');
      return conversations;
    } catch (e) {
      print('Error getting cached conversations: $e');
      return [];
    }
  }
  /// Check if conversation cache needs syncing
  bool conversationsNeedSync(String userId) {
    final lastSync = _getConversationLastSync(userId);
    return lastSync == null || 
           DateTime.now().difference(lastSync) > _cacheValidityDuration;
  }
  
  /// Update a single conversation in the cache
  Future<void> updateCachedConversation(String userId, Conversation updatedConversation) async {
    try {
      final conversations = getCachedConversations(userId);
      final index = conversations.indexWhere((c) => c.id == updatedConversation.id);
      
      if (index >= 0) {
        conversations[index] = updatedConversation;
        await cacheConversations(userId, conversations);
      } else {
        // If conversation doesn't exist in cache, add it
        conversations.add(updatedConversation);
        await cacheConversations(userId, conversations);
      }
    } catch (e) {
      print('Error updating cached conversation: $e');
    }
  }
  
  /// Remove a conversation from the cache
  Future<void> removeCachedConversation(String userId, String conversationId) async {
    try {
      final conversations = getCachedConversations(userId);
      final filteredConversations = conversations.where((c) => c.id != conversationId).toList();
      
      if (filteredConversations.length < conversations.length) {
        await cacheConversations(userId, filteredConversations);
      }
    } catch (e) {
      print('Error removing cached conversation: $e');
    }
  }
  
  
  /// Helper to update last sync time for conversations
  Future<void> _updateConversationLastSync(String userId) async {
    final key = _getConversationLastSyncKey(userId);
    await _prefs.setString(
      key,
      DateTime.now().toIso8601String(),
    );
  }
  
  /// Helper to get last sync time for conversations
  DateTime? _getConversationLastSync(String userId) {
    final key = _getConversationLastSyncKey(userId);
    final timestamp = _prefs.getString(key);
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }
  
  /// Helper for generating conversation cache keys
  String _getConversationCacheKey(String userId) => '$_conversationCacheKeyPrefix$userId';
  String _getConversationLastSyncKey(String userId) => '$_conversationLastSyncKey$userId';
  
  /// Check if we have any cached conversations
  bool hasCachedConversations(String userId) {
    return _prefs.containsKey(_getConversationCacheKey(userId));
  }
  
  /// Debug method to check cache contents
  void debugCacheContents(String userId) {
    try {
      final key = _getConversationCacheKey(userId);
      final data = _prefs.getString(key);
      
      print('=== CONVERSATION CACHE DEBUG ===');
      print('User ID: $userId');
      print('Cache Key: $key');
      print('Has Cache Data: ${data != null}');
      
      if (data != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(data);
          print('Cached Conversations Count: ${jsonList.length}');
          
          for (int i = 0; i < jsonList.length; i++) {
            final conv = jsonList[i];
            print('  [$i] ID: ${conv['id']}, CompanionID: ${conv['companion_id']}, CompanionName: ${conv['companion_name']}, LastMessage: ${conv['last_message']}');
          }
        } catch (e) {
          print('Error parsing cached data: $e');
        }
      }
      
      print('All Conversation Cache Keys: ${_prefs.getKeys().where((k) => k.startsWith(_conversationCacheKeyPrefix)).toList()}');
      print('===============================');
    } catch (e) {
      print('Debug cache error: $e');
    }
  }
  /// Clear ALL caches for a specific user (used during logout)
  Future<void> clearAllUserCaches(String userId) async {
    try {
      print('Starting comprehensive cache clear for user $userId');
      
      // 1. Clear conversation caches
      await clearConversationsCache(userId);
      
      // 2. Clear all message caches for this user
      await clearCache(userId); // This clears all message caches
      
      // 3. Clear any remaining user-specific keys
      final allKeys = _prefs.getKeys();
      final userSpecificKeys = allKeys.where((key) => 
        (key.startsWith('$_cacheKeyPrefix$userId') ||
        key.contains('user_data') ||
        key.startsWith('$_lastSyncKey$userId') ||
        key.startsWith('$_conversationCacheKeyPrefix$userId') ||
        key.contains('gemini_companion_state_v2_$userId') ||
        key.contains('companion_memory_$userId') ||
        key.startsWith('$_conversationLastSyncKey$userId')) &&
        // Preserve system-level settings
        !key.startsWith(_cacheVersionKey) &&
        key != 'isInitialized'
      );
      
      for (final key in userSpecificKeys) {
        await _prefs.remove(key);
      }

      // 4. CRITICAL FIX: Clean session metadata to remove user's sessions
      await _cleanSessionMetadataForUser(userId);

      // 5. Reset general cache flags
      await _prefs.remove('hasCache');

      print('Completed comprehensive cache clear for user $userId. Cleared ${userSpecificKeys.length} additional keys.');
    } catch (e) {
      print('Error in comprehensive user cache clear: $e');
    }
  }

  /// **NEW: Force cache rebuild after login**
  Future<void> initializeForNewUser(String userId) async {
    try {
      // Clear any stale data first
      await clearAllUserCaches(userId);
      
      // Set initialization flag
      await _prefs.setBool('cache_initialized_$userId', true);
      
      print('Initialized cache for new user $userId');
    } catch (e) {
      print('Error initializing cache for new user: $e');
    }
  }
  /// Enhanced clear conversations cache with better cleanup
  Future<void> clearConversationsCache(String userId) async {
    try {
      final key = _getConversationCacheKey(userId);
      
      // Remove all conversation-related keys
      await _prefs.remove(key);
      await _prefs.remove('${key}_companion_ids');
      await _prefs.remove(_getConversationLastSyncKey(userId));
      
      // Also remove any orphaned conversation keys
      final allKeys = _prefs.getKeys();
      final conversationKeys = allKeys.where((k) => 
        k.startsWith('conversations_$userId') ||
        k.startsWith('conversation_last_sync_$userId'));
      
      for (final orphanKey in conversationKeys) {
        await _prefs.remove(orphanKey);
      }
      
      print('Cleared conversations cache for user $userId');
    } catch (e) {
      print('Error clearing conversations cache: $e');
    }
  }

  /// Enhanced clear cache with companion-specific cleanup
  Future<void> clearCache(String userId, {String? companionId}) async {
    try {
      if (companionId != null) {
        // Clear companion-specific cache
        final key = _getCompanionCacheKey(userId, companionId);
        await _prefs.remove(key);
        await _prefs.remove(_getLastSyncKey(userId, companionId: companionId));
        print('Cleared cache for user $userId and companion $companionId');
      } else {
        // Clear ALL message caches for user
        final allKeys = _prefs.getKeys();
        final userMessageKeys = allKeys.where((key) => 
          key.startsWith('$_cacheKeyPrefix$userId') || 
          key.startsWith('$_lastSyncKey$userId'));
        
        for (final key in userMessageKeys) {
          await _prefs.remove(key);
        }
        print('Cleared all message caches for user $userId. Removed ${userMessageKeys.length} keys.');
      }
    } catch (e) {
      print('Failed to clear cache: $e');
    }
  }

  /// Debug method to test complete cache lifecycle
  Future<void> debugCacheLifecycle(String userId) async {
    try {
      print('=== CACHE LIFECYCLE TEST ===');
      
      final prefs = await SharedPreferences.getInstance();
      final chatCache = ChatCacheService(prefs);
      
      // 1. Test cache creation
      print('1. Testing cache creation...');
      final testMessages = [
        Message(
          id: 'test1',
          messageFragments: ['Test message'],
          userId: userId,
          companionId: 'companion1',
          conversationId: 'conv1',
          isBot: false,
          created_at: DateTime.now(),
        ),
      ];
      await chatCache.cacheMessages(userId, testMessages, companionId: 'companion1');
      print('✅ Messages cached');
      
      // 2. Test cache retrieval
      print('2. Testing cache retrieval...');
      final cachedMessages = chatCache.getCachedMessages(userId, companionId: 'companion1');
      print('✅ Retrieved ${cachedMessages.length} messages');
      
      // 3. Test cache clearing
      print('3. Testing cache clearing...');
      await chatCache.clearAllUserCaches(userId);
      final afterClear = chatCache.getCachedMessages(userId, companionId: 'companion1');
      print('✅ After clear: ${afterClear.length} messages (should be 0)');
      
      // 4. Verify no user data remains
      final allKeys = prefs.getKeys();
      final remainingUserKeys = allKeys.where((key) => key.contains(userId)).toList();
      
      if (remainingUserKeys.isEmpty) {
        print('✅ CACHE LIFECYCLE TEST PASSED');
      } else {
        print('❌ CACHE LIFECYCLE TEST FAILED: ${remainingUserKeys.length} keys remain');
        for (final key in remainingUserKeys) {
          print('  - $key');
        }
      }
      
      print('============================');
    } catch (e) {
      print('❌ CACHE LIFECYCLE TEST ERROR: $e');
    }
  }

  /// **NEW: Clean session metadata for a specific user**
  Future<void> _cleanSessionMetadataForUser(String userId) async {
    try {
      final sessionDataString = _prefs.getString('session_metadata');
      if (sessionDataString != null) {
        final sessionData = jsonDecode(sessionDataString) as Map<String, dynamic>;
        final updatedSessionData = <String, dynamic>{};
        
        // Keep only sessions that don't belong to the cleared user
        sessionData.forEach((key, data) {
          if (!key.startsWith('${userId}_')) {
            updatedSessionData[key] = data;
          }
        });
        
        // Save the filtered metadata
        await _prefs.setString('session_metadata', jsonEncode(updatedSessionData));
        print('🧹 Cleaned session metadata for user $userId');
      }
    } catch (e) {
      print('❌ Failed to clean session metadata for user $userId: $e');
    }
  }
}
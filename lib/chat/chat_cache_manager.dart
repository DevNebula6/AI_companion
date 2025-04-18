import 'dart:convert';
import 'package:ai_companion/chat/message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatCacheService {
  // Updated key structure to support companion-specific caching
  static const String _cacheKeyPrefix = 'chat_messages_';
  static const String _lastSyncKey = 'last_sync_';
  static const String _cacheVersionKey = 'cache_version';
  static const String _currentVersion = '2.0'; // Increment version to force cache refresh
  static const int _maxCacheSize = 1000; // messages
  static const Duration _cacheValidityDuration = Duration(hours: 12);
  
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
        await _clearAllCaches();
        print('Cache version updated from $version to $_currentVersion, cleared old caches');
      }
    }
  }

  // New method to clear all chat caches
  Future<void> _clearAllCaches() async {
    final allKeys = _prefs.getKeys();
    final chatKeys = allKeys.where((key) => 
      key.startsWith(_cacheKeyPrefix) || key.startsWith(_lastSyncKey));
    
    for (final key in chatKeys) {
      await _prefs.remove(key);
    }
  }

  // UPDATED: Cache messages for a specific user and companion
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

  // UPDATED: Get cached messages, filtered by companion if specified
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

  // Updated clear cache method that can target specific companions
  Future<void> clearCache(String userId, {String? companionId}) async {
    try {
      if (companionId != null) {
        // Clear companion-specific cache
        final key = _getCompanionCacheKey(userId, companionId);
        await _prefs.remove(key);
        await _prefs.remove(_getLastSyncKey(userId, companionId: companionId));
        print('Cleared cache for user $userId and companion $companionId');
      } else {
        // Clear all user caches
        final allKeys = _prefs.getKeys();
        final userKeys = allKeys.where((key) => 
          (key.startsWith('$_cacheKeyPrefix$userId') || 
           key.startsWith('$_lastSyncKey$userId')));
        
        for (final key in userKeys) {
          await _prefs.remove(key);
        }
        print('Cleared all caches for user $userId');
      }
    } catch (e) {
      print('Failed to clear cache: $e');
    }
  }

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
}
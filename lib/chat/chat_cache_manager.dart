import 'dart:convert';
import 'package:ai_companion/chat/message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatCacheService {
  static const String _cacheKeyPrefix = 'chat_messages_';
  static const String _lastSyncKey = 'last_sync_';
  static const String _cacheVersionKey = 'cache_version';
  static const int _maxCacheSize = 1000; // messages
  static const Duration _cacheValidityDuration = Duration(hours: 12);
  
  final SharedPreferences _prefs;
  
  ChatCacheService(this._prefs) {
    _initializeCache();
  }

  Future<void> _initializeCache() async {
    final version = _prefs.getInt(_cacheVersionKey);
    if (version == null) {
      await _prefs.setInt(_cacheVersionKey, 1);
      await _prefs.setBool('isInitialized', true);
    }
  }

  Future<void> cacheMessages(String userId, List<Message> messages) async {
    try {
      if (messages.length > _maxCacheSize) {
        messages = messages.sublist(messages.length - _maxCacheSize);
      }
      
      final key = _getCacheKey(userId);
      final data = messages.map((m) => m.toJson()).toList();
      await _prefs.setString(key, jsonEncode(data));
      await _updateLastSync(userId);
      await _prefs.setBool('hasCache', true);
    } catch (e) {
      print('Cache write error: $e');
      _handleCacheError(userId);
    }
  }

  List<Message> getCachedMessages(String userId) {
    try {
      final key = _getCacheKey(userId);
      final data = _prefs.getString(key);
      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        return jsonList
            .where((json) => json != null)
            .map((json) => Message.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Cache read error: $e');
      _handleCacheError(userId);
    }
    return [];
  }

  void _handleCacheError(String userId) {
    try {
      // Clear corrupted cache
      _prefs.remove(_getCacheKey(userId));
      _prefs.remove(_getLastSyncKey(userId));
    } catch (e) {
      print('Error clearing corrupted cache: $e');
    }
  }

  bool needsSync(String userId) {
    final lastSync = _getLastSync(userId);
    return lastSync == null || 
           DateTime.now().difference(lastSync) > _cacheValidityDuration;
  }

  Future<void> _updateLastSync(String userId) async {
    await _prefs.setString(
      _getLastSyncKey(userId),
      DateTime.now().toIso8601String(),
    );
  }

  DateTime? _getLastSync(String userId) {
    final timestamp = _prefs.getString(_getLastSyncKey(userId));
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  String _getCacheKey(String userId) => '$_cacheKeyPrefix$userId';
  String _getLastSyncKey(String userId) => '$_lastSyncKey$userId';

  Future<void> clearCache(String userId) async {
    await _prefs.remove(_getCacheKey(userId));
    await _prefs.remove(_getLastSyncKey(userId));
  }
}
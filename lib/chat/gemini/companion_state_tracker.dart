import 'dart:async';
import 'package:ai_companion/chat/gemini/gemini_service.dart';

/// A utility class to track companion state metrics and optimize memory usage.
class CompanionStateTracker {
  final GeminiService _geminiService;
  Timer? _cleanupTimer;
  final Map<String, int> _companionUsageCount = {};
  
  CompanionStateTracker(this._geminiService) {
    // Set up periodic cleanup
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 30), 
      (_) => _performCleanup()
    );
  }
  
  /// Record a companion usage event
  void trackCompanionUsage(String userId, String companionId) {
    final key = '${userId}_$companionId';
    _companionUsageCount[key] = (_companionUsageCount[key] ?? 0) + 1;
  }
  
  /// Get companion usage statistics
  Map<String, int> getUsageStats() {
    return Map.from(_companionUsageCount);
  }
  
  /// Check if we should keep a companion in memory based on usage
  bool shouldKeepCompanion(String userId, String companionId) {
    final key = '${userId}_$companionId';
    final usageCount = _companionUsageCount[key] ?? 0;
    
    // Keep frequently used companions (arbitrary threshold)
    return usageCount > 5;
  }
  
  /// Perform memory cleanup for unused companions
  Future<void> _performCleanup() async {
    // Get performance report from GeminiService
    final report = _geminiService.getPerformanceReport();
    
    // Log current memory usage
    print('Memory cleanup - Current memory usage: ${report['memoryUsage']}');
    
    // Advanced cleanup would analyze usage patterns and selectively
    // remove companions from memory
    
    // Reset usage counts periodically to avoid permanent caching
    if (_companionUsageCount.length > 20) {
      // Keep only the top 10 most used companions' counts
      final sortedEntries = _companionUsageCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
        
      final topKeys = sortedEntries.take(10).map((e) => e.key).toSet();
      
      _companionUsageCount.removeWhere((key, _) => !topKeys.contains(key));
    }
  }
  
  /// Release resources
  void dispose() {
    _cleanupTimer?.cancel();
    _companionUsageCount.clear();
  }
}

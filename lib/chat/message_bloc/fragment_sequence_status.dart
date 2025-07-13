import 'package:ai_companion/chat/message.dart';

/// Tracks the status of fragment sequences for accurate unread count management
class FragmentSequenceStatus {
  final String sequenceId;
  final Message originalMessage;
  final List<String> fragments;
  final int totalFragments;
  final int displayedCount;
  final bool isCompleted;
  final DateTime startedAt;
  final DateTime? completedAt;
  
  const FragmentSequenceStatus({
    required this.sequenceId,
    required this.originalMessage,
    required this.fragments,
    required this.totalFragments,
    required this.displayedCount,
    required this.isCompleted,
    required this.startedAt,
    this.completedAt,
  });
  
  /// Get remaining fragments that haven't been displayed
  List<String> get remainingFragments {
    if (displayedCount >= fragments.length) return [];
    return fragments.sublist(displayedCount);
  }
  
  /// Check if all fragments have been displayed
  bool get allFragmentsDisplayed => displayedCount >= totalFragments;
  
  /// Get the percentage of fragments completed
  double get completionPercentage {
    if (totalFragments == 0) return 1.0;
    return displayedCount / totalFragments;
  }
  
  /// Create a copy with updated values
  FragmentSequenceStatus copyWith({
    String? sequenceId,
    Message? originalMessage,
    List<String>? fragments,
    int? totalFragments,
    int? displayedCount,
    bool? isCompleted,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return FragmentSequenceStatus(
      sequenceId: sequenceId ?? this.sequenceId,
      originalMessage: originalMessage ?? this.originalMessage,
      fragments: fragments ?? this.fragments,
      totalFragments: totalFragments ?? this.totalFragments,
      displayedCount: displayedCount ?? this.displayedCount,
      isCompleted: isCompleted ?? this.isCompleted,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
  
  @override
  String toString() {
    return 'FragmentSequenceStatus(id: $sequenceId, displayed: $displayedCount/$totalFragments, completed: $isCompleted)';
  }
}

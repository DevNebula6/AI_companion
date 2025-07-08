import 'dart:collection';
import 'dart:async';
import 'package:ai_companion/chat/message.dart';

enum MessageType { user, system, fragment, notification }
enum MessagePriority { low, normal, high, urgent }

class QueuedMessage {
  final String id;
  final Message message;
  final MessageType type;
  final MessagePriority priority;
  final DateTime queuedAt;
  final Map<String, dynamic> metadata;

  QueuedMessage({
    required this.message,
    required this.type,
    this.priority = MessagePriority.normal,
    Map<String, dynamic>? metadata,
  }) : id = 'queued_${DateTime.now().millisecondsSinceEpoch}',
       queuedAt = DateTime.now(),
       metadata = metadata ?? {};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueuedMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MessageQueue {
  final Queue<QueuedMessage> _highPriorityQueue = Queue<QueuedMessage>();
  final Queue<QueuedMessage> _normalQueue = Queue<QueuedMessage>();
  final Queue<QueuedMessage> _lowPriorityQueue = Queue<QueuedMessage>();
  
  bool _isProcessing = false;
  StreamController<QueuedMessage>? _processingController;
  
  MessageQueue() {
    _processingController = StreamController<QueuedMessage>.broadcast();
  }
  
  // Queue management
  void enqueue(QueuedMessage queuedMessage) {
    switch (queuedMessage.priority) {
      case MessagePriority.urgent:
      case MessagePriority.high:
        _highPriorityQueue.add(queuedMessage);
        break;
      case MessagePriority.normal:
        _normalQueue.add(queuedMessage);
        break;
      case MessagePriority.low:
        _lowPriorityQueue.add(queuedMessage);
        break;
    }
    
    _processQueue();
  }
  
  void enqueueUserMessage(Message message) {
    enqueue(QueuedMessage(
      message: message,
      type: MessageType.user,
      priority: MessagePriority.normal,
    ));
  }
  
  void enqueueSystemMessage(Message message, {MessagePriority priority = MessagePriority.high}) {
    enqueue(QueuedMessage(
      message: message,
      type: MessageType.system,
      priority: priority,
    ));
  }
  
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    
    try {
      while (_hasMessages()) {
        final queuedMessage = _dequeue();
        if (queuedMessage != null) {
          _processingController?.add(queuedMessage);
          await _processMessage(queuedMessage);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }
  
  QueuedMessage? _dequeue() {
    if (_highPriorityQueue.isNotEmpty) return _highPriorityQueue.removeFirst();
    if (_normalQueue.isNotEmpty) return _normalQueue.removeFirst();
    if (_lowPriorityQueue.isNotEmpty) return _lowPriorityQueue.removeFirst();
    return null;
  }
  
  bool _hasMessages() {
    return _highPriorityQueue.isNotEmpty || 
           _normalQueue.isNotEmpty || 
           _lowPriorityQueue.isNotEmpty;
  }
  
  Future<void> _processMessage(QueuedMessage queuedMessage) async {
    // Processing logic will be handled by MessageBloc
    await Future.delayed(Duration(milliseconds: 50)); // Prevent overwhelming
  }
  
  int get queueLength => _highPriorityQueue.length + _normalQueue.length + _lowPriorityQueue.length;
  
  void clear() {
    _highPriorityQueue.clear();
    _normalQueue.clear();
    _lowPriorityQueue.clear();
  }
  
  void dispose() {
    _processingController?.close();
  }
  
  // Getter for the processing stream
  Stream<QueuedMessage>? get processingStream => _processingController?.stream;
}

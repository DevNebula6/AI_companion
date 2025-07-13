import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion/chat/message.dart';

void main() {
  group('Message JSON Parsing Tests', () {
    test('should parse legacy string message format', () {
      final json = {
        'id': 'test-id',
        'message': 'Hello, this is a single message',
        'user_id': 'user123',
        'companion_id': 'companion123',
        'conversation_id': 'conv123',
        'is_bot': false,
        'created_at': '2024-01-01T10:00:00Z',
        'metadata': {},
      };

      final message = Message.fromJson(json);
      
      expect(message.messageFragments, ['Hello, this is a single message']);
      expect(message.message, 'Hello, this is a single message');
      expect(message.hasFragments, false);
    });

    test('should parse new array message format', () {
      final json = {
        'id': 'test-id',
        'message': ['Fragment 1', 'Fragment 2', 'Fragment 3'],
        'user_id': 'user123',
        'companion_id': 'companion123',
        'conversation_id': 'conv123',
        'is_bot': true,
        'created_at': '2024-01-01T10:00:00Z',
        'metadata': {},
      };

      final message = Message.fromJson(json);
      
      expect(message.messageFragments.length, 3);
      expect(message.messageFragments[0], 'Fragment 1');
      expect(message.messageFragments[1], 'Fragment 2');
      expect(message.messageFragments[2], 'Fragment 3');
      expect(message.message, 'Fragment 1 Fragment 2 Fragment 3');
      expect(message.hasFragments, true);
    });

    test('should handle null or invalid message data', () {
      final json = {
        'id': 'test-id',
        'message': null,
        'user_id': 'user123',
        'companion_id': 'companion123',
        'conversation_id': 'conv123',
        'is_bot': false,
        'created_at': '2024-01-01T10:00:00Z',
        'metadata': {},
      };

      final message = Message.fromJson(json);
      
      expect(message.messageFragments, []);
      expect(message.message, '');
      expect(message.hasFragments, false);
    });

    test('should serialize to JSON with array format', () {
      final message = Message(
        id: 'test-id',
        messageFragments: ['Fragment 1', 'Fragment 2'],
        userId: 'user123',
        companionId: 'companion123',
        conversationId: 'conv123',
        isBot: true,
        created_at: DateTime.parse('2024-01-01T10:00:00Z'),
      );

      final json = message.toJson();
      
      expect(json['message'], ['Fragment 1', 'Fragment 2']);
      expect(json['id'], 'test-id');
      expect(json['is_bot'], true);
    });
  });
}

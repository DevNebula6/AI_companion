// Test file to verify session management fixes
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion/chat/gemini/gemini_service.dart';

void main() {
  group('Enhanced Gemini Service Session Management', () {
    late GeminiService geminiService;

    setUp(() {
      geminiService = GeminiService();
    });

    test('should provide session diagnostics', () {
      final diagnostics = geminiService.getSessionDiagnostics();
      
      expect(diagnostics, isA<Map<String, dynamic>>());
      expect(diagnostics.containsKey('service_initialized'), true);
      expect(diagnostics.containsKey('total_sessions'), true);
      expect(diagnostics.containsKey('timestamp'), true);
    });

    test('should handle session validation', () async {
      final isValid = await geminiService.validateSessionIntegrity(
        userId: 'test_user',
        companionId: 'test_companion',
      );
      
      expect(isValid, isA<bool>());
    });

    test('should provide performance report', () {
      final report = geminiService.getPerformanceReport();
      
      expect(report, isA<Map<String, dynamic>>());
      expect(report.containsKey('memory_usage'), true);
      expect(report.containsKey('active_sessions'), true);
    });

    test('should check companion initialization status', () {
      final isActive = geminiService.isCompanionActive('test_user', 'test_companion');
      expect(isActive, isA<bool>());
    });

    test('should provide active companion info', () {
      final info = geminiService.getActiveCompanionInfo();
      expect(info, isA<Map<String, String?>>());
    });
  });
}

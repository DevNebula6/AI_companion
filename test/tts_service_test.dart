import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_companion/chat/voice/supabase_tts_service.dart';

void main() {
  group('TTS Service Tests', () {
    late SupabaseTTSService ttsService;

    setUpAll(() async {
      // Load environment variables
      await dotenv.load(fileName: '.env');
      ttsService = SupabaseTTSService();
    });

    test('TTS service should initialize with Azure credentials', () async {
      print('Testing TTS service initialization...');
      
      final azureKey = dotenv.env['AZURE_TTS_API_KEY'];
      final azureRegion = dotenv.env['AZURE_TTS_REGION'];
      
      print('Azure TTS API Key: ${azureKey?.substring(0, 10)}...');
      print('Azure TTS Region: $azureRegion');
      
      if (azureKey == null || azureRegion == null) {
        fail('Azure TTS credentials not found in .env file');
      }
      
      try {
        await ttsService.initialize(
          azureApiKey: azureKey,
          azureRegion: azureRegion,
        );
        
        expect(ttsService.isAvailable, true);
        print('✅ TTS service initialized successfully');
      } catch (e) {
        print('❌ TTS service initialization failed: $e');
        fail('TTS service initialization failed: $e');
      }
    });
  });
}

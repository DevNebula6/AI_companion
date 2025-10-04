import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Azure Speech configuration for the AI Companion app
/// This file contains the configuration needed to set up Azure Speech Streaming
class AzureSpeechConfig {

  static String azureSpeechKey = dotenv.env["AZURE_SPEECH_KEY"]??"";
  
  static String azureRegion = dotenv.env["AZURE_SPEECH_REGION"]??"centralindia";
  
  // Supported locales for speech recognition
  static const Map<String, String> supportedLocales = {
    'en-US': 'English (United States)',
    'en-GB': 'English (United Kingdom)',
    'es-ES': 'Spanish (Spain)',
    'fr-FR': 'French (France)',
    'de-DE': 'German (Germany)',
    'it-IT': 'Italian (Italy)',
    'pt-BR': 'Portuguese (Brazil)',
    'ja-JP': 'Japanese (Japan)',
    'ko-KR': 'Korean (South Korea)',
    'zh-CN': 'Chinese (Mandarin, Simplified)',
  };
  
  // Default speech recognition settings
  static const String defaultLocale = 'en-US';
  static const bool enableInterimResults = true;
  static const bool enableWordLevelTimestamps = true;
  static const String profanityFilter = 'masked';
  static const String outputFormat = 'detailed';
  
  /// Validate that Azure Speech is properly configured
  static bool get isConfigured {
    return azureSpeechKey != 'YOUR_AZURE_SPEECH_KEY_HERE' &&
           azureRegion != 'YOUR_AZURE_REGION_HERE' &&
           azureSpeechKey.isNotEmpty &&
           azureRegion.isNotEmpty;
  }
  
  /// Get the WebSocket URL for Azure Speech
  static String getWebSocketUrl(String locale) {
    return 'wss://$azureRegion.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1'
           '?language=$locale'
           '&format=$outputFormat'
           '&profanity=$profanityFilter'
           '&wordLevelTimestamps=$enableWordLevelTimestamps'
           '&enableInterimResults=$enableInterimResults';
  }
  
  /// Get the token endpoint URL for Azure Speech
  static String get tokenEndpoint {
    return 'https://$azureRegion.api.cognitive.microsoft.com/sts/v1.0/issueToken';
  }
}

/// Instructions for setting up Azure Speech
class AzureSetupInstructions {
  static const String instructions = '''
🚀 AZURE SPEECH SETUP INSTRUCTIONS

1. Create Azure Account:
   - Go to https://azure.microsoft.com/
   - Sign up for a free account (\$200 credit)

2. Create Speech Service:
   - Go to Azure Portal (portal.azure.com)
   - Click "Create a resource"
   - Search for "Speech"
   - Create a Speech service
   - Choose a region (e.g., East US, West US 2)

3. Get API Credentials:
   - Go to your Speech service in Azure Portal
   - Click "Keys and Endpoint"
   - Copy Key 1 and Region
   
4. Configure in App:
   - Open lib/chat/voice/azure_speech_config.dart
   - Replace YOUR_AZURE_SPEECH_KEY_HERE with your key
   - Replace YOUR_AZURE_REGION_HERE with your region

5. Test Configuration:
   - Run the app
   - Try voice chat
   - Check logs for "✅ Azure Speech Streaming: Service initialized successfully"

💰 COST ESTIMATE:
- First 5 hours per month: FREE
- After that: \$0.016 per minute (\$0.96 per hour)
- Example: 10 hours/month = ~\$4.80

🔒 SECURITY NOTES:
- Never commit API keys to source control
- Consider using environment variables in production
- Use Azure Key Vault for production apps
''';
}

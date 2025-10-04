import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'azure_speech_config.dart';

/// Helper class to test Azure Speech configuration
class AzureTestHelper {
  /// Test Azure Speech STT configuration
  static Future<bool> testAzureSTTConfiguration() async {
    try {
      debugPrint('🧪 Testing Azure Speech STT configuration...');
      
      // Check if credentials are configured
      if (!AzureSpeechConfig.isConfigured) {
        debugPrint('❌ Azure credentials not configured');
        debugPrint('📝 Please update azure_speech_config.dart with your actual Azure key and region');
        return false;
      }
      
      debugPrint('🔑 Azure Key: ${AzureSpeechConfig.azureSpeechKey.substring(0, 8)}...');
      debugPrint('🌍 Azure Region: ${AzureSpeechConfig.azureRegion}');
      
      // Test token endpoint
      final tokenUrl = 'https://${AzureSpeechConfig.azureRegion}.api.cognitive.microsoft.com/sts/v1.0/issueToken';
      
      debugPrint('🔑 Testing token endpoint: $tokenUrl');
      
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Ocp-Apim-Subscription-Key': AzureSpeechConfig.azureSpeechKey,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Azure Speech STT configuration is VALID!');
        debugPrint('🎤 Speech-to-Text service is ready');
        debugPrint('🔊 Text-to-Speech service is ready');
        debugPrint('🌐 WebSocket streaming is enabled');
        debugPrint('📋 WebSocket URL: ${AzureSpeechConfig.getWebSocketUrl('en-US')}');
        return true;
      } else {
        debugPrint('❌ Azure Speech test failed: ${response.statusCode}');
        debugPrint('📝 Response: ${response.body}');
        debugPrint('🔧 Check your Azure key and region in .env file');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Azure Speech test error: $e');
      return false;
    }
  }
  
  /// Test WebSocket endpoint
  static String getWebSocketTestUrl() {
    return AzureSpeechConfig.getWebSocketUrl('en-US');
  }
  
  /// Get setup status
  static Map<String, dynamic> getSetupStatus() {
    return {
      'isConfigured': AzureSpeechConfig.isConfigured,
      'hasKey': AzureSpeechConfig.azureSpeechKey.isNotEmpty && 
                AzureSpeechConfig.azureSpeechKey != 'YOUR_AZURE_SPEECH_KEY_HERE',
      'hasRegion': AzureSpeechConfig.azureRegion.isNotEmpty &&
                   AzureSpeechConfig.azureRegion != 'YOUR_AZURE_REGION_HERE',
      'keyLength': AzureSpeechConfig.azureSpeechKey.length,
      'region': AzureSpeechConfig.azureRegion,
      'websocketUrl': AzureSpeechConfig.getWebSocketUrl('en-US'),
      'tokenEndpoint': 'https://${AzureSpeechConfig.azureRegion}.api.cognitive.microsoft.com/sts/v1.0/issueToken',
    };
  }
}

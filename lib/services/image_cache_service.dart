// lib/services/image_cache_service.dart
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CompanionImageCacheManager {
  static const String key = 'companionImageCache';
  
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  static Future<void> clearCache() async {
    await instance.emptyCache();
  }
}
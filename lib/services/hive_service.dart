import 'package:ai_companion/Companion/hive_adapter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../Companion/ai_model.dart';

class HiveService {
  static const String companionsBoxName = 'companions';
  static Box<AICompanion>? _companionsBox;

  static Future<void> initHive() async {
    await Hive.initFlutter();

    // Register adapters if not registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AICompanionAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PhysicalAttributesAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PersonalityTraitsAdapter());
    }
  }

  static Future<Box<AICompanion>> getCompanionsBox() async {
    if (_companionsBox != null && _companionsBox!.isOpen) {
      return _companionsBox!;
    }

    try {
      if (!Hive.isBoxOpen('companions')) {
        _companionsBox = await Hive.openBox<AICompanion>(companionsBoxName);
      } else {
        _companionsBox = Hive.box<AICompanion>(companionsBoxName);
      }
      return _companionsBox!;
    } catch (e) {
      
      print('Error opening companions box: $e');

      // If box is corrupted, delete and recreate
      await Hive.deleteBoxFromDisk(companionsBoxName);
      _companionsBox = await Hive.openBox<AICompanion>(companionsBoxName);
      return _companionsBox!;
    }
  }

  static Future<void> closeBox() async {
    if (_companionsBox != null && _companionsBox!.isOpen) {
      await _companionsBox!.close();
      _companionsBox = null;
    }
  }
}
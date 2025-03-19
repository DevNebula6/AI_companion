import 'package:ai_companion/Companion/ai_model.dart';

abstract class CompanionEvent {}

class LoadCompanions extends CompanionEvent {}

class SyncCompanions extends CompanionEvent {}

class FilterCompanions extends CompanionEvent {
  final List<String> traits;
  FilterCompanions(this.traits);
}

class PreloadCompanionImages extends CompanionEvent {
  final List<AICompanion> companions;
  PreloadCompanionImages(this.companions);
}
abstract class CompanionEvent {}

class LoadCompanions extends CompanionEvent {}

class SyncCompanions extends CompanionEvent {}

class FilterCompanions extends CompanionEvent {
  final List<String> traits;
  FilterCompanions(this.traits);
}
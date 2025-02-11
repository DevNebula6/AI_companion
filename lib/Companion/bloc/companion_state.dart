import 'package:ai_companion/Companion/ai_model.dart';

abstract class CompanionState {}

class CompanionInitial extends CompanionState {}

class CompanionLoading extends CompanionState {}

class CompanionLoaded extends CompanionState {
  final List<AICompanion> companions;
  final bool isSyncing;

  CompanionLoaded(this.companions, {this.isSyncing = false});
}

class CompanionError extends CompanionState {
  final String message;
  CompanionError(this.message);
}
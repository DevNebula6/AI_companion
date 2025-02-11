import 'package:ai_companion/Companion/bloc/companion_event.dart';
import 'package:ai_companion/Companion/bloc/companion_state.dart';
import 'package:ai_companion/Companion/companion_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../ai_model.dart';

class CompanionBloc extends Bloc<CompanionEvent, CompanionState> {
  final AICompanionRepository _repository;
  final Box<AICompanion> _localStore;
  
  CompanionBloc(this._repository) : 
    _localStore = Hive.box('companions'),
    super(CompanionInitial()) {
    on<LoadCompanions>(_onLoadCompanions);
    on<SyncCompanions>(_onSyncCompanions);
    on<FilterCompanions>(_onFilterCompanions);
  }

  Future<void> _onLoadCompanions(
    LoadCompanions event,
    Emitter<CompanionState> emit,
  ) async {
    try {
      emit(CompanionLoading());
      
      // First load from local storage
      final localCompanions = _localStore.values.toList();
      if (localCompanions.isNotEmpty) {
        emit(CompanionLoaded(localCompanions));
        // Trigger sync in background
        add(SyncCompanions());
      } else {
        // If no local data, load from remote
        final companions = await _repository.getAllCompanions();
        await _saveLocally(companions);
        emit(CompanionLoaded(companions));
      }
    } catch (e) {
      emit(CompanionError(e.toString()));
    }
  }

  Future<void> _onSyncCompanions(
    SyncCompanions event,
    Emitter<CompanionState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is CompanionLoaded) {
        emit(CompanionLoaded(currentState.companions, isSyncing: true));
        
        final remoteCompanions = await _repository.getAllCompanions();
        await _saveLocally(remoteCompanions);
        
        emit(CompanionLoaded(remoteCompanions));
      }
    } catch (e) {
      print('Sync error: $e');
      // Don't emit error, just log it
    }
  }

  Future<void> _onFilterCompanions(
    FilterCompanions event,
    Emitter<CompanionState> emit,
  ) async {
    try {
      final companions = _localStore.values.where((companion) {
        return companion.personality.primaryTraits
            .any((trait) => event.traits.contains(trait));
      }).toList();
      
      emit(CompanionLoaded(companions));
    } catch (e) {
      emit(CompanionError(e.toString()));
    }
  }

  Future<void> _saveLocally(List<AICompanion> companions) async {
    await _localStore.clear();
    for (var companion in companions) {
      await _localStore.put(companion.id, companion);
    }
  }
}
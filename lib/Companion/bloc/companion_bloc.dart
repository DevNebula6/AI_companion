import 'dart:async';
import 'package:ai_companion/Companion/bloc/companion_event.dart';
import 'package:ai_companion/Companion/bloc/companion_state.dart';
import 'package:ai_companion/Companion/companion_repository.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:ai_companion/services/hive_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rxdart/rxdart.dart';
import '../ai_model.dart';

class CompanionBloc extends Bloc<CompanionEvent, CompanionState> {
  final AICompanionRepository _repository;
  Box<AICompanion>? _companionsBox;
  StreamSubscription? _companionSubscription;

  CompanionBloc(this._repository) : 
    super(CompanionInitial()) {

    on<LoadCompanions>(_onLoadCompanions);
    on<SyncCompanions>(_onSyncCompanions);
    on<FilterCompanions>(_onFilterCompanions);
    on<PreloadCompanionImages>(_onPreloadCompanionImages);
    
    // Subscribe to companion changes with debounce
    _companionSubscription = _repository.watchCompanions()
        .debounce((_) => TimerStream(true, const Duration(seconds: 2)))
        .listen(
      (companions) {
        if (state is CompanionLoaded) {
          add(SyncCompanions());
        }
      },
      onError: (error) {
        print('Error watching companions: $error');
      }
    );
  }

  Future<void> _onLoadCompanions(
    LoadCompanions event,
    Emitter<CompanionState> emit,
  ) async {
    try {
      emit(CompanionLoading());
      
      // Check if authenticated
      if (SupabaseClientManager().client.auth.currentSession == null) {
          emit(CompanionError('Not authenticated'));
          return;
        }
      // Ensure box is open
      _companionsBox = await HiveService.getCompanionsBox();
      
      // Try local first
      if (_companionsBox!.isNotEmpty) {
        final localCompanions = _companionsBox!.values.toList();
        emit(CompanionLoaded(localCompanions));
        add(SyncCompanions());
      }

      
      // Get from Supabase
      final companions = await _repository.getAllCompanions();
      
      // Update local storage
      await _companionsBox!.clear();
      for (var companion in companions) {
        await _companionsBox!.put(companion.id, companion);
      }

      emit(CompanionLoaded(companions));

    } catch (e) {
      print('Error loading companions: $e');
      emit(CompanionError(e.toString()));
    }
  }
  
  Future<void> _onPreloadCompanionImages(
    PreloadCompanionImages event,
    Emitter<CompanionState> emit,
  ) async {
    try {
      await _repository.prefetchCompanionImages(event.companions);
    } catch (e) {
      print('Error preloading images: $e');
    }
  }

  Future<void> _onSyncCompanions(
    SyncCompanions event,
    Emitter<CompanionState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is CompanionLoaded) {
        // Set syncing state
        emit(CompanionLoaded(currentState.companions, isSyncing: true));
        
        // Get current local companions
        final localCompanions = _companionsBox?.values.toList() ?? [];
        
        // Fetch remote companions only if local box exists
        if (_companionsBox != null) {        
        final remoteCompanions = await _repository.getAllCompanions();
  
        // Compare and update only if there are changes
        if (_hasChanges(localCompanions, remoteCompanions)) {
          await _saveLocally(remoteCompanions);
          emit(CompanionLoaded(remoteCompanions));
          print('Companions synced successfully: ${remoteCompanions.length} companions');
        } 
      }
    }
    } catch (e) {
      print('Sync error: $e');
    }
  }

  // Add helper method to check for changes
  bool _hasChanges(List<AICompanion> local, List<AICompanion> remote) {
    if (local.length != remote.length) return true;
    
    // Create maps for faster comparison
    final localMap = {for (var c in local) c.id: c};
    
    // Check for any differences
    for (final remoteCompanion in remote) {
      final localCompanion = localMap[remoteCompanion.id];
      if (localCompanion == null) return true;
      
      // Compare relevant fields
      if (localCompanion.name != remoteCompanion.name ||
          localCompanion.description != remoteCompanion.description ||
          !_listsEqual(localCompanion.personality.primaryTraits, 
                      remoteCompanion.personality.primaryTraits)) {
        return true;
      }
    }
    
    return false;
  }

  bool _listsEqual(List a, List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _onFilterCompanions(
    FilterCompanions event,
    Emitter<CompanionState> emit,
  ) async {
    try {
      final companions = _companionsBox?.values.where((companion) {
        return companion.personality.primaryTraits
            .any((trait) => event.traits.contains(trait));
      }).toList();
      
      emit(CompanionLoaded(companions??[]));
    } catch (e) {
      emit(CompanionError(e.toString()));
    }
  }

  Future<void> _saveLocally(List<AICompanion> companions) async {
    try {
      await _companionsBox?.clear();
      // Filter out invalid companions
      final validCompanions = companions.where((companion) =>
        companion.id.isNotEmpty &&
        companion.name.isNotEmpty
        // companion.physical != null &&
        // companion.personality != null
      );
    for (var companion in validCompanions) {
      await _companionsBox?.put(companion.id, companion);
    }
  } catch (e) {
      print('Error saving companions locally: $e');
    }
  }

  @override
    Future<void> close() {
      _companionSubscription?.cancel();
      return super.close();
    }
}
import 'dart:async';
import 'package:ai_companion/Companion/bloc/companion_event.dart';
import 'package:ai_companion/Companion/bloc/companion_state.dart';
import 'package:ai_companion/Companion/companion_repository.dart';
import 'package:ai_companion/auth/supabase_client_singleton.dart';
import 'package:ai_companion/services/hive_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai_model.dart';

class CompanionBloc extends Bloc<CompanionEvent, CompanionState> {
  final AICompanionRepository _repository;
  Box<AICompanion>? _companionsBox;

  DateTime? _lastSyncTime;


  CompanionBloc(this._repository) : super(CompanionInitial()) {
    on<LoadCompanions>(_onLoadCompanions);
    on<SyncCompanions>(_onSyncCompanions);
    on<FilterCompanions>(_onFilterCompanions);
    on<PreloadCompanionImages>(_onPreloadCompanionImages);
    on<CheckForUpdates>(_onCheckForUpdates);
  }
  // Add a new event handler for checking updates
  Future<void> _onCheckForUpdates(
    CheckForUpdates event,
    Emitter<CompanionState> emit,
  ) async {
    final currentState = state;
    if (currentState is CompanionLoaded) {
      final now = DateTime.now();
      
      // Check if we should sync (on app launch or daily)
      final shouldSync = _lastSyncTime == null || 
          now.difference(_lastSyncTime!) > const Duration(hours: 24);
          
      if (shouldSync) {
        add(SyncCompanions());
      }
    }
  }
  Future<void> _onLoadCompanions(
    LoadCompanions event,
    Emitter<CompanionState> emit,
  ) async {
    try {
      emit(CompanionLoading());

      // Initialize from previous sync time
      _lastSyncTime = await _loadLastSyncTime();

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
        
        // Only prefetch the first 10 companion images (most likely to be seen)
        if (localCompanions.isNotEmpty) {
          add(PreloadCompanionImages(localCompanions.take(10).toList()));
        }
        
        // Check if we need to sync
        add(CheckForUpdates());
      } else {
        // No local data, must fetch from server
        final companions = await _repository.getAllCompanions();
        
        await _saveLocally(companions);
        emit(CompanionLoaded(companions));
        
        // Set last sync time
        _lastSyncTime = DateTime.now();
        await _saveLastSyncTime(_lastSyncTime!);
        
        // Only prefetch first 10 images
        if (companions.isNotEmpty) {
          add(PreloadCompanionImages(companions.take(10).toList()));
        }
      }
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
        
        // Fetch remote companions
        if (_companionsBox != null) {
          final remoteCompanions = await _repository.getAllCompanions();
  
          // Compare and update only if there are changes
          if (_hasChanges(localCompanions, remoteCompanions)) {
            await _saveLocally(remoteCompanions);
            emit(CompanionLoaded(remoteCompanions));
            print('Companions synced successfully: ${remoteCompanions.length} companions');
          } else {
            emit(CompanionLoaded(currentState.companions, isSyncing: false));
          }
          
          // Update last sync time
          _lastSyncTime = DateTime.now();
          
          // Store sync time in SharedPreferences
          await _saveLastSyncTime(_lastSyncTime!);
        }
      }
    } catch (e) {
      print('Sync error: $e');
      // Improve error handling with specific error state
      if (state is CompanionLoaded) {
        emit(CompanionLoaded((state as CompanionLoaded).companions, 
          isSyncing: false, hasError: true));
      } else {
        emit(CompanionError('Failed to sync companions: $e'));
      }
    }
  }
  
  // Add method to save and load sync time
  Future<void> _saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_companion_sync', time.toIso8601String());
  }
  
  Future<DateTime?> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString('last_companion_sync');
    return timeString != null ? DateTime.parse(timeString) : null;
  }

  // Add helper method to check for changes
  bool _hasChanges(List<AICompanion> local, List<AICompanion> remote) {
    if (local.length != remote.length) return true;
    
    // Create maps for faster comparison
    final localMap = {for (var c in local) c.id: c};
    final remoteIds = remote.map((c) => c.id).toSet();
    
    // Check for added or removed companions
    if (!_setsEqual(localMap.keys.toSet(), remoteIds)) {
      return true;
    }
    
    // Use hash-based comparison for content changes
    for (final remoteCompanion in remote) {
      final localCompanion = localMap[remoteCompanion.id];
      if (localCompanion == null) continue; // Already checked in set equality
      
      // Compare only essential fields for change detection
      if (_getCompanionHash(localCompanion) != _getCompanionHash(remoteCompanion)) {
        return true;
      }
    }
    
    return false;
  }

  // Helper for set comparison
  bool _setsEqual<T>(Set<T> a, Set<T> b) {
    return a.length == b.length && a.containsAll(b);
  }

  // Compute a simple hash for companion to detect changes
  int _getCompanionHash(AICompanion companion) {
    return Object.hash(
      companion.name,
      companion.description,
      companion.avatarUrl,
      Object.hashAll(companion.personality.primaryTraits),
      Object.hashAll(companion.personality.secondaryTraits),
      // Add more fields that would trigger a refresh when changed
    );
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
      );
    for (var companion in validCompanions) {
      await _companionsBox?.put(companion.id, companion);
    }
  } catch (e) {
      print('Error saving companions locally: $e');
    }
  }

}
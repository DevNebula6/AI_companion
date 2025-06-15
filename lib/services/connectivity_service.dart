import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  
  ConnectivityService._internal() {
    _initialize();
  }

  final Connectivity _connectivity = Connectivity();
  final BehaviorSubject<bool> _connectionStatusSubject = BehaviorSubject<bool>.seeded(true);
  final BehaviorSubject<List<ConnectivityResult>> _connectivityResultSubject = 
      BehaviorSubject<List<ConnectivityResult>>.seeded([ConnectivityResult.wifi]);
  
  StreamSubscription? _connectivitySubscription;
  bool _isInitialized = false;

  bool get isOnline => _connectionStatusSubject.value;
  Stream<bool> get onConnectivityChanged => _connectionStatusSubject.stream.distinct();
  Stream<List<ConnectivityResult>> get onConnectivityResultChanged => _connectivityResultSubject.stream.distinct();
  List<ConnectivityResult> get currentResult => _connectivityResultSubject.value;

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check initial connectivity
      final initialResult = await _connectivity.checkConnectivity();
      final isOnline = _isConnected(initialResult);
      
      _connectivityResultSubject.add(initialResult);
      _connectionStatusSubject.add(isOnline);
      
      // Setup listener for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          print('Connectivity service error: $error');
          // On error, assume we're online to avoid blocking functionality
          _connectionStatusSubject.add(true);
        },
      );
      
      _isInitialized = true;
      print('ConnectivityService initialized. Initial status: ${isOnline ? "Online" : "Offline"}');
    } catch (e) {
      print('Failed to initialize ConnectivityService: $e');
      // Assume online if initialization fails
      _connectionStatusSubject.add(true);
      _connectivityResultSubject.add([ConnectivityResult.wifi]);
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> result) {
    final isOnline = _isConnected(result);
    
    _connectivityResultSubject.add(result);
    _connectionStatusSubject.add(isOnline);
    
    print('Connectivity changed: ${_getConnectionTypeString(result.first)} - ${isOnline ? "Online" : "Offline"}');
  }

  bool _isConnected(List<ConnectivityResult> result) {
    return result.isNotEmpty && !result.every((r) => r == ConnectivityResult.none);
  }

  String _getConnectionTypeString(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  String get connectionTypeString => _getConnectionTypeString(currentResult.first);

  // Force refresh connectivity status
  Future<bool> refreshConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _handleConnectivityChange(result);
      return _isConnected(result);
    } catch (e) {
      print('Error refreshing connectivity: $e');
      return isOnline; // Return current status if refresh fails
    }
  }

  // Check if we have a strong connection (for heavy operations)
  bool get hasStrongConnection {
    return isOnline && (currentResult.contains(ConnectivityResult.wifi) || 
                       currentResult.contains(ConnectivityResult.ethernet));
  }

  // Wait for connection to be restored
  Future<void> waitForConnection({Duration? timeout}) async {
    if (isOnline) return;
    
    final completer = Completer<void>();
    late StreamSubscription subscription;
    
    subscription = onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    
    if (timeout != null) {
      Timer(timeout, () {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Connection timeout', timeout));
        }
      });
    }
    
    return completer.future;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionStatusSubject.close();
    _connectivityResultSubject.close();
  }
}

// Extension for easy access throughout the app
extension ConnectivityServiceExtension on ConnectivityService {
  Widget wrapWithNetworkStatus(
    Widget child, {
    bool showPersistentIndicator = false,
    EdgeInsetsGeometry? margin,
    bool showOnlineConfirmation = true,
  }) {
    // This would require importing the network status widget
    // Implementation would be in the widget file
    return child; // Placeholder
  }
}
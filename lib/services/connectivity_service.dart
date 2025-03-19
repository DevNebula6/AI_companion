// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'dart:async';

// class ConnectivityService {
//   static final ConnectivityService _instance = ConnectivityService._internal();
//   final _connectivity = Connectivity();
//   final _controller = StreamController<bool>.broadcast();
//   bool _isConnected = true;

//   factory ConnectivityService() => _instance;

//   ConnectivityService._internal() {
//     _initConnectivity();
//     _setupConnectivityListener();
//   }

//   Stream<bool> get connectionStream => _controller.stream;
//   bool get isConnected => _isConnected;

//   Future<void> _initConnectivity() async {
//     try {
//       final result = await _connectivity.checkConnectivity();
//       _isConnected = result != ConnectivityResult.none;
//       _controller.add(_isConnected);
//     } catch (e) {
//       print('Connectivity check failed: $e');
//     }
//   }

//   void _setupConnectivityListener() {
//     _connectivity.onConnectivityChanged.listen((result) {
//       _isConnected = result != ConnectivityResult.none;
//       _controller.add(_isConnected);
//     });
//   }

//   void dispose() {
//     _controller.close();
//   }
// }
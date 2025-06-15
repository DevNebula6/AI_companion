import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ai_companion/services/connectivity_service.dart';
import 'dart:async';

class FloatingConnectivityIndicator extends StatefulWidget {
  final Widget child;

  const FloatingConnectivityIndicator({
    super.key,
    required this.child,
  });

  @override
  State<FloatingConnectivityIndicator> createState() => _FloatingConnectivityIndicatorState();
}

class _FloatingConnectivityIndicatorState extends State<FloatingConnectivityIndicator>
    with TickerProviderStateMixin {
  final ConnectivityService _connectivityService = ConnectivityService();
  
  bool _isOnline = true;
  bool _wasOffline = false;
  bool _showOfflineIndicator = false;
  bool _showOnlineIndicator = false;
  
  StreamSubscription? _connectivitySubscription;
  Timer? _onlineIndicatorTimer;
  late AnimationController _slideController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _setupAnimationControllers();
    _setupConnectivityListener();
    _checkInitialConnectivity();
  }

  void _setupAnimationControllers() {
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<void> _checkInitialConnectivity() async {
    final isOnline = _connectivityService.isOnline;
    setState(() {
      _isOnline = isOnline;
      _showOfflineIndicator = !isOnline;
    });
    
    if (!isOnline) {
      _slideController.forward();
      _pulseController.repeat();
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivityService.onConnectivityChanged.listen(
      (isOnline) {
        if (mounted && isOnline != _isOnline) {
          final wasOffline = !_isOnline;
          
          setState(() {
            _isOnline = isOnline;
          });
          
          if (isOnline && wasOffline) {
            _handleOnlineTransition();
          } else if (!isOnline) {
            _handleOfflineTransition();
          }
        }
      },
      onError: (e) {
        print('Connectivity indicator stream error: $e');
      },
    );
  }

  void _handleOfflineTransition() {
    setState(() {
      _showOfflineIndicator = true;
      _showOnlineIndicator = false;
    });
    
    _slideController.forward();
    _pulseController.repeat();
  }

  void _handleOnlineTransition() {
    _pulseController.stop();
    
    setState(() {
      _showOnlineIndicator = true;
      _wasOffline = true;
    });
    
    // Show "Back Online" message for 2.5 seconds
    _onlineIndicatorTimer?.cancel();
    _onlineIndicatorTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showOnlineIndicator = false;
          _showOfflineIndicator = false;
          _wasOffline = false;
        });
        _slideController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _onlineIndicatorTimer?.cancel();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Floating connectivity indicators
        if (_showOfflineIndicator || _showOnlineIndicator)
          _buildFloatingIndicator(),
      ],
    );
  }

  Widget _buildFloatingIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeOutCubic,
        )),
        child: _showOnlineIndicator 
            ? _buildOnlineIndicator()
            : _buildOfflineIndicator(),
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade600,
              Colors.orange.shade500,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.3),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No Internet Connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'You\'re offline. Some features may be limited.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'OFFLINE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineIndicator() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade600,
              Colors.green.shade500,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Back Online',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'CONNECTED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(
      begin: -1,
      end: 0,
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

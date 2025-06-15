import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class NetworkStatusWidget extends StatefulWidget {
  final Widget child;
  final bool showPersistentIndicator;
  final EdgeInsetsGeometry? margin;
  final bool showOnlineConfirmation;

  const NetworkStatusWidget({
    super.key,
    required this.child,
    this.showPersistentIndicator = false,
    this.margin,
    this.showOnlineConfirmation = true,
  });

  @override
  State<NetworkStatusWidget> createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget>
    with TickerProviderStateMixin {
  bool _isOnline = true;
  bool _wasOffline = false;
  bool _showOnlineMessage = false;
  StreamSubscription? _connectivitySubscription;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  Timer? _onlineMessageTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimationControllers();
    _initializeConnectivity();
    _setupConnectivityListener();
  }

  void _setupAnimationControllers() {
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  Future<void> _initializeConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final isOnline = result != ConnectivityResult.none;
      
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
        
        if (!isOnline) {
          _slideController.forward();
          _pulseController.repeat();
        }
      }
    } catch (e) {
      print('Initial connectivity check failed: $e');
      // Assume online if check fails
      if (mounted) {
        setState(() {
          _isOnline = true;
        });
      }
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (result) {
        final isOnline = result != ConnectivityResult.none;
        
        if (mounted && isOnline != _isOnline) {
          setState(() {
            if (!_isOnline && isOnline) {
              _wasOffline = true;
            }
            _isOnline = isOnline;
          });
          
          if (isOnline) {
            _handleOnlineTransition();
          } else {
            _handleOfflineTransition();
          }
        }
      },
      onError: (e) {
        print('Connectivity stream error: $e');
      },
    );
  }

  void _handleOfflineTransition() {
    _slideController.forward();
    _pulseController.repeat();
  }

  void _handleOnlineTransition() {
    _pulseController.stop();
    _slideController.reverse();
    
    if (widget.showOnlineConfirmation && _wasOffline) {
      setState(() {
        _showOnlineMessage = true;
      });
      
      _onlineMessageTimer?.cancel();
      _onlineMessageTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showOnlineMessage = false;
            _wasOffline = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _slideController.dispose();
    _pulseController.dispose();
    _onlineMessageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Offline Indicator
        if (!_isOnline || widget.showPersistentIndicator)
          _buildOfflineIndicator(),
        
        // Online Confirmation Message
        if (_showOnlineMessage)
          _buildOnlineConfirmation(),
      ],
    );
  }

  Widget _buildOfflineIndicator() {
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeOutCubic,
        )),
        child: Container(
          margin: widget.margin ?? EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade600,
                Colors.orange.shade500,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.2),
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
        ),
      ),
    );
  }

  Widget _buildOnlineConfirmation() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: widget.margin ?? EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade600,
              Colors.green.shade500,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
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
              Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ).animate().slideY(
        begin: -1,
        end: 0,
        duration: 400.ms,
        curve: Curves.easeOutCubic,
      ).then().slideY(
        begin: 0,
        end: -1,
        duration: 400.ms,
        delay: 2600.ms,
        curve: Curves.easeInCubic,
      ),
    );
  }
}

// Compact network status indicator for smaller spaces
class CompactNetworkIndicator extends StatefulWidget {
  final bool showLabel;
  final Color? color;

  const CompactNetworkIndicator({
    super.key,
    this.showLabel = true,
    this.color,
  });

  @override
  State<CompactNetworkIndicator> createState() => _CompactNetworkIndicatorState();
}

class _CompactNetworkIndicatorState extends State<CompactNetworkIndicator>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _initializeConnectivity();
    _setupConnectivityListener();
  }

  Future<void> _initializeConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final isOnline = result != ConnectivityResult.none;
      
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
        
        if (!isOnline) {
          _animationController.repeat();
        }
      }
    } catch (e) {
      print('Compact connectivity check failed: $e');
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (result) {
        final isOnline = result != ConnectivityResult.none;
        
        if (mounted && isOnline != _isOnline) {
          setState(() {
            _isOnline = isOnline;
          });
          
          if (isOnline) {
            _animationController.stop();
            _animationController.reset();
          } else {
            _animationController.repeat();
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indicatorColor = widget.color ?? 
        (_isOnline ? Colors.green : Colors.orange);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _isOnline ? 1.0 : (1.0 + (_animationController.value * 0.3)),
              child: Icon(
                _isOnline ? Icons.wifi : Icons.wifi_off,
                color: indicatorColor,
                size: 16,
              ),
            );
          },
        ),
        if (widget.showLabel) ...[
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: indicatorColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

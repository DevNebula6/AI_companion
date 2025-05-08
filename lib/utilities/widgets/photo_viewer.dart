import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfilePhotoViewer extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final String title;

  const ProfilePhotoViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    required this.title,
  });

  @override
  State<ProfilePhotoViewer> createState() => _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState extends State<ProfilePhotoViewer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _backgroundOpacityAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    
    // Configure animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _backgroundOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut)
    );
    
    // Play entrance animation
    _animationController.forward();
    
    // Set preferred orientation to portrait and landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    // Reset orientations when leaving
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _handleDismiss() {
    if (_isDismissing) return;
    
    setState(() {
      _isDismissing = true;
    });
    
    // Play exit animation and then pop
    _animationController.reverse().then((_) {
      Navigator.of(context).pop();
    });
    
    // Provide haptic feedback for exit
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.black.withOpacity(_backgroundOpacityAnimation.value * 1),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _handleDismiss,
            ),
            title: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          body: GestureDetector(
            onTap: _handleDismiss,
            child: Center(
              child: Hero(
                tag: widget.heroTag,
                child: PhotoView(
                  imageProvider: CachedNetworkImageProvider(widget.imageUrl),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  initialScale: PhotoViewComputedScale.contained,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  loadingBuilder: (context, event) => Center(
                    child: CircularProgressIndicator(
                      value: event == null ? 0 : 
                        event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 60,
                      ),
                    ),
                  ),
                  scaleStateController: PhotoViewScaleStateController(),
                  enableRotation: true,
                  tightMode: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

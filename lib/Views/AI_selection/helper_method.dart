// Add this class to your file
import 'package:flutter/material.dart';

class MeasureSize extends StatefulWidget {
  final Widget child;
  final Function(Size size) onChange;

  const MeasureSize({super.key, 
    required this.onChange,
    required this.child,
  });

  @override
  State<MeasureSize> createState() => MeasureSizeState();
}

class MeasureSizeState extends State<MeasureSize> {
  final _widgetKey = GlobalKey();
  Size? _oldSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSize();
    });
  }

  void _checkSize() {
    final context = _widgetKey.currentContext;
    if (context == null) return;
    
    final RenderBox box = context.findRenderObject() as RenderBox;
    final size = box.size;
    
    if (_oldSize != size) {
      _oldSize = size;
      widget.onChange(size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkSize());
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: Container(
          key: _widgetKey,
          child: widget.child,
        ),
      ),
    );
  }
}
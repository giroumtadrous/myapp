import 'package:flutter/material.dart';
import 'dart:math' as math;

class AppLoadingIndicator extends StatefulWidget {
  final String? message;

  const AppLoadingIndicator({super.key, this.message});

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 54,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (index) {
                    final phase = (_controller.value - index * 0.16).clamp(
                      0.0,
                      1.0,
                    );
                    final t = math.sin(phase * math.pi).abs();
                    final scale = 0.7 + (t * 0.5);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.5 + (t * 0.5)),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 10),
            Text(widget.message!),
          ],
        ],
      ),
    );
  }
}

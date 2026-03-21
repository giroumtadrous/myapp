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
    final base = const Color(0xFFE2E8F0);
    final highlight = const Color(0xFFF8FAFC);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 240,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final wave = math.sin(_controller.value * math.pi * 2);
                final slide = (wave * 0.5) + 0.5;

                return Column(
                  children: List.generate(3, (index) {
                    final height = index == 0 ? 18.0 : 12.0;
                    final widthFactor = index == 0 ? 1.0 : (index == 1 ? 0.78 : 0.62);

                    return Container(
                      margin: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
                      height: height,
                      width: 240 * widthFactor,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment(-1.0 + (slide * 2), 0),
                          end: Alignment(1.0 + (slide * 2), 0),
                          colors: [base, highlight, base],
                          stops: const [0.2, 0.5, 0.8],
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

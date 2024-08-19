import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/network_service.dart';
import 'radar_painter.dart';

class RadarWidget extends StatefulWidget {
  @override
  _RadarWidgetState createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, networkService, child) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: RadarPainter(
                  angle: _controller.value * 2 * pi,
                ),
                child: Container(
                  width: 500,
                  height: 500,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

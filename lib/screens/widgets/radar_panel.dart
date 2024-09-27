import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../services/network_service.dart';
import '../../services/file_transfer_service.dart';
import '../radar_painter.dart';
import 'dart:math';

class RadarPanel extends StatefulWidget {
  final Function(Device, String) onDeviceSelected;

  const RadarPanel({Key? key, required this.onDeviceSelected}) : super(key: key);

  @override
  _RadarPanelState createState() => _RadarPanelState();
}

class _RadarPanelState extends State<RadarPanel> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  List<Device> discoveredDevices = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(_controller);
    _startDiscovery();
  }

  void _startDiscovery() {
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.startDiscovery();

    // 监听新发现的设备
    networkService.onNewDeviceConnected = (int deviceCount) {
      setState(() {
        discoveredDevices = networkService.devices;
      });
    };

    // 监听新连接
    final fileTransferService = Provider.of<FileTransferService>(context, listen: false);
    fileTransferService.onNewConnection = (Socket socket) {
      networkService.updateDeviceStatus(socket, 'connected');
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    // networkService.stopDiscovery();
    super.dispose();
  }


  void _handleDeviceTap(Device device) {
    final networkService = Provider.of<NetworkService>(context, listen: false);
    if (networkService.deviceStatuses[device.address] == 'connected') {
      // 设备已连接，打开对话框
      widget.onDeviceSelected(device, 'connected');
    } else {
      // 设备未连接，尝试连接
      widget.onDeviceSelected(device, 'disconnected');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, networkService, child) {
        return Center(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: RadarPainter(angle: _animation.value),
                    size: Size(500, 500),
                  );
                },
              ),
              ...networkService.devices.map((device) {
                final angle = networkService.devices.indexOf(device) * (2 * pi / networkService.devices.length);
                final radius = 130.0;
                final x = radius * cos(angle) + 150;
                final y = radius * sin(angle) + 150;
                final offsetX = x.clamp(0.0, 280.0);
                final offsetY = y.clamp(0.0, 280.0);

                return Positioned(
                  left: offsetX,
                  top: offsetY,
                  child: GestureDetector(
                    onTap: () {
                      _handleDeviceTap(device);  // 处理设备点击事件
                    },
                    child: _buildDeviceIcon(networkService, device),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceIcon(NetworkService networkService, Device device) {
    return Container(
      padding: EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2.0,
            spreadRadius: 1.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            networkService.deviceStatuses[device.address] == 'connected'
                ? Icons.circle
                : networkService.deviceStatuses[device.address] == 'transferring'
                    ? Icons.circle_notifications
                    : Icons.circle_outlined,
            color: networkService.deviceStatuses[device.address] == 'connected'
                ? Colors.green
                : networkService.deviceStatuses[device.address] == 'transferring'
                    ? Colors.yellow
                    : Colors.grey,
          ),
          Text(
            device.address,
            style: TextStyle(color: Colors.red, fontSize: 10),
          ),
          Text(
            networkService.transferringFiles[device.address] == null ? '' : networkService.transferringFiles[device.address]!.fileName,
            style: TextStyle(color: Colors.red, fontSize: 10),
          )
        ],
      ),
    );
  }
}
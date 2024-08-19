import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:net_file_transfer/models/device.dart';
import 'package:net_file_transfer/screens/setting_page.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../services/network_service.dart';
import 'radar_painter.dart';
import 'package:file_picker/file_picker.dart';
import 'file_transfer_dialog.dart';



class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String? selectedDeviceAddress;
  bool isConnected = false;
  String connectionStatus = '';
  Map<String, String> receivedFiles = {};
  int deviceCount = 0;


  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Initialize animation
    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(_controller);

    // Start discovery
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.startDiscovery();
    networkService.onFileTransferRequested = (deviceAddress, fileName) {
      setState(() {
        receivedFiles[deviceAddress] = fileName;
      });
    };
    networkService.onNewDeviceConnected = (devCount) {
      setState(() {
        deviceCount = devCount;
      });
    };
  }

  @override
  void dispose() {
    // Stop discovery when the screen is disposed
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.stopDiscovery();

    _controller.dispose();
    super.dispose();
  }


  Future<void> _connectToDevice(NetworkService networkService, Device device) async {
    setState(() {
      selectedDeviceAddress = device.address;
      connectionStatus = 'Connecting...';
    });

    try {
      setState(() {
        isConnected = true;
        connectionStatus = 'Connected to ${device.address}';
      });

      // 显示文件传输对话框
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return FileTransferDialog(deviceAddress: device.address, port: 7999);
        },
      );
    } catch (e) {
      setState(() {
        isConnected = false;
        connectionStatus = 'Failed to connect to ${device.address}';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('正在搜索...已搜索到$deviceCount台设备'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Consumer<NetworkService>(
        builder: (context, networkService, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
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
                      deviceCount = networkService.devices.length;
                    
                      final angle = networkService.devices.indexOf(device) * (2 * pi / networkService.devices.length);
                      final radius = 130.0; // 调整半径使其在雷达内部
                      final x = radius * cos(angle) + 150; // 调整位置，使其在雷达中心内
                      final y = radius * sin(angle) + 150; // 调整位置，使其在雷达中心内

                      // 限制边缘位置
                      final offsetX = x.clamp(0.0, 280.0); // 宽度 300 减去边距 20
                      final offsetY = y.clamp(0.0, 280.0); // 高度 300 减去边距 20

                      return Positioned(
                        left: offsetX,
                        top: offsetY,
                        child: GestureDetector(
                          onTap: () async {
                            await _connectToDevice(networkService, device);
                          },
                          child: Container(
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
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),

              ],
            ),
          );
        },
      ),
    );
  }
}

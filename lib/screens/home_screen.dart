import 'package:flutter/material.dart';
import '../models/device.dart';
import './widgets/left_panel.dart';
import './widgets/radar_panel.dart';
import './widgets/chat_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Device? selectedDevice;
  bool isConnected = false;

  void _onDeviceSelected(Device device, String status) {
    setState(() {
      selectedDevice = device;
      isConnected = status == "connected" ? true : false;
    });
  }

  void _onConnectionStatusChanged(bool status) {
    setState(() {
      isConnected = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: LeftPanel(),
          ),
          Expanded(
            flex: 5,
            child: RadarPanel(
              onDeviceSelected: _onDeviceSelected,
            ),
          ),
          Expanded(
            flex: 3,
            child: ChatPanel(
              selectedDevice: selectedDevice,
              isConnected: isConnected,
              onConnectionStatusChanged: _onConnectionStatusChanged,
            ),
          ),
        ],
      ),
    );
  }
}
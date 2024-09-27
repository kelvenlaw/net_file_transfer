import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../models/file_data.dart';
import 'file_transfer_service.dart';
import 'package:flutter/material.dart';

class NetworkService extends ChangeNotifier {
  List<Device> _devices = [];
  FileTransferService? _fileTransferService;
  RawDatagramSocket? senderSocket;
  RawDatagramSocket? receiverSocket;
  bool isDiscovering = false;
  Function(String, String)? onFileTransferRequested; // 回调函数
  Function(int)? onNewDeviceConnected;
  List<String> connectedDevices = []; // 新增已连接设备列表

  List<Device> get devices => _devices;

  // 设备状态映射：地址 -> 状态
  final Map<String, String> _deviceStatuses = {};
  final Map<String, FileData> _transferringFiles = {};
  Map<String, String> get deviceStatuses => _deviceStatuses;
  Map<String, FileData> get transferringFiles => _transferringFiles;

  Future<void> startDiscovery() async {
    if (isDiscovering) return;  // 防止重复启动
    isDiscovering = true;

    try {
      senderSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8000);
      receiverSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 7999);

      var data = utf8.encode('DEVICE:');
      var broadcastEndpoint = InternetAddress("255.255.255.255");

      senderSocket?.broadcastEnabled = true;

      // 定时发送广播消息
      Timer.periodic(Duration(seconds: 1), (timer) {
        if (!isDiscovering) {
          timer.cancel();
          return;
        }
        try {
          senderSocket?.send(data, broadcastEndpoint, 7999);
        } catch (e) {
          print("Error sending broadcast: $e");
          timer.cancel();
        }
      });

      // 持续接收来自其他设备的响应
      receiverSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = receiverSocket?.receive();
          if (datagram != null) {
            var str = utf8.decode(datagram.data);
            if (str.startsWith('DEVICE:')) {
              var address = datagram.address.address;
              var name = str.split(':')[1];
              var device = Device(name: name, address: address);

              // 检查设备是否已经存在
              if (!_devices.any((d) => d.address == device.address)) {
                device.status = "connected";
                _devices.add(device);

                _deviceStatuses[device.address] = 'disconnected';
                print("Device found: ${device.address}");
                notifyListeners();
                onNewDeviceConnected!(_devices.length);
              }
            }
          }
        }
      });

      // 启动TCP服务器
      // _fileTransferService = FileTransferService(serverAddress: '', serverPort: 7999);
      // await _fileTransferService?.startServer((fileData) {
      //   // 处理接收到的文件
      //   if(fileData.status == 0) {
      //     print('设备已链接：${fileData.clientAddress}');
      //     _deviceStatuses['${fileData.clientAddress}'] = "connected";
      //   } else if (fileData.status == 1) {
      //     print('设备${fileData.clientAddress} 正在传输${fileData.fileName}');
      //     _deviceStatuses['${fileData.clientAddress}'] = "transfering";
      //   } else {
      //     // File receivedFile = File('./${fileData.fileName}');
      //     // receivedFile.writeAsBytesSync(fileData.fileContent);
      //     // print('File saved: ${receivedFile.path}');

      //     // 更新设备状态
      //     _deviceStatuses['${fileData.clientAddress}'] = 'completed';
      //     _transferringFiles['${fileData.clientAddress}'] = fileData;
      //   }

      //   notifyListeners();
      //   // 通过回调通知文件传输请求
      //   // onFileTransferRequested?.call('0.0.0.0', fileName);
      // });
    } catch (e) {
      print("Error during discovery: $e");
      stopDiscovery();
    }
  }

  void stopDiscovery() {
    isDiscovering = false;
    senderSocket?.close();
    receiverSocket?.close();
    senderSocket = null;
    receiverSocket = null;
  }

  Future<void> connectToDevice(Device device) async {
    // 连接到设备的逻辑
    // 例如，启动一个新的 FileTransferClient 并连接到设备
    // _fileTransferService = FileTransferService(serverAddress: device.address, serverPort: 7999);
    // await _fileTransferService?.connect();
  }

  Future<void> sendFile(String filePath) async {
    // if (_fileTransferService != null) {
    //   await _fileTransferService?.sendFile(filePath);
    // } else {
    //   print('Not connected to any device');
    // }
  }

  void disconnect() {
    _fileTransferService?.disconnect();
  }

  void updateDeviceStatus(Socket socket, String status) {
    deviceStatuses[socket.remoteAddress.address] = status;
    if (status == 'connected') {
      // _devices.forEach((d) => if(d.address == socket.remoteAddress.address) {
      //   d.socket = socket;
      // });
      connectedDevices.add(socket.remoteAddress.address);
    }
    notifyListeners();
  }

  void startTransfer(String address, FileData fileData) {
    transferringFiles[address] = fileData;
    deviceStatuses[address] = 'transferring';
    notifyListeners();
  }

  void completeTransfer(String address) {
    transferringFiles.remove(address); // 移除键
    deviceStatuses[address] = 'connected';
    notifyListeners();
  }
}

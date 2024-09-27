import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/file_data.dart';
import 'file_transfer_client.dart';

class FileTransferService {
  final String serverAddress;
  final int serverPort;
  ServerSocket? _serverSocket;
  final int _tcpPort = 7999;
  final Map<String, FileTransferClient> _clients = {};

  FileTransferService({required this.serverAddress, required this.serverPort});

  Function(String, String)? onMessageReceived;
  Function(Socket)? onNewConnection; // 新增回调函数

  Future<void> startServer(Function(FileData) onFileReceived) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, _tcpPort);
    print('Listening on ${_serverSocket!.address.address}:${_serverSocket!.port}');

    _serverSocket!.listen((Socket socket) {
      String clientAddress = socket.remoteAddress.address;

      // 创建新的 FileTransferClient 实例
      FileTransferClient client = FileTransferClient(
        serverAddress: clientAddress,
        serverPort: 7999,
        socket: socket,
        onFileReceived: onFileReceived,
        onMessageReceived: onMessageReceived,
      );

      _clients[clientAddress] = client;

      // 调用新连接回调函数
      onNewConnection?.call(socket);
    });
  }

  Future<FileTransferClient> getClient(String address) async {
    if (_clients.containsKey(address)) {
      return _clients[address]!;
    } else {
      // 创建并连接新的客户端
      FileTransferClient client = FileTransferClient(
        serverAddress: address,
        serverPort: serverPort,
        onFileReceived: (fileData) {
          // 处理接收到的文件
        },
        onMessageReceived: onMessageReceived,
      );
      await client.connect();
      _clients[address] = client;
      return client;
    }
  }

  void disconnect() {
    _serverSocket?.close();
    _clients.forEach((address, client) {
      client.disconnect();
    });
    _clients.clear();
  }
}

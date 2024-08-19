import 'dart:async';
import 'dart:convert';
import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';


class FileTransferClient {
  final String serverAddress;
  final int serverPort;
  int status = 0;
  Socket? _socket;


  FileTransferClient({required this.serverAddress, required this.serverPort});

  Future<void> connect() async {
    print("serviceAddress: $serverAddress, serverPort: $serverPort");
    _socket = await Socket.connect(serverAddress, serverPort);
    status = 1;
    print('Connected to: ${_socket!.remoteAddress.address}:${_socket!.remotePort}');
  }

  Future<void> sendFile(String filePath, String deviceAddress, void Function(int, int) onProgress) async {
    if (_socket == null) {
      throw Exception('No device connected');
    }

    File file = File(filePath);
    int totalBytes = await file.length();
    int sentBytes = 0;

    String fileName = basename(file.path);
    List<int> fileNameByte = utf8.encode(fileName);
    String header = '${'${fileNameByte.length}|$totalBytes'.padRight(100)}$fileName';

    _socket!.add(utf8.encode(header)); // 发送传输头

    await _socket!.addStream(file.openRead().map((data) {
      sentBytes += data.length;
      onProgress(sentBytes, totalBytes);
      return data;
    })).catchError((error) {
      print('Error sending file: $error');
    });
  }

  void disconnect() {
    _socket?.close();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/file_data.dart';

class FileTransferClient {
  final String serverAddress;
  final int serverPort;
  int status = 0;
  Socket? _socket;
  final Function(FileData) onFileReceived;
  final Function(String, String)? onMessageReceived;
  final Map<Socket, FileData> _fileDataMap = {};
  final Map<Socket, bool> _awaitingHeaderMap = {};

  FileTransferClient({
    required this.serverAddress,
    required this.serverPort,
    required this.onFileReceived,
    this.onMessageReceived,
    Socket? socket,
  }) {
    if (socket != null) {
      _socket = socket;
      _initializeSocket();
    }
  }

  Future<void> connect() async {
    print("Connecting to: $serverAddress:$serverPort");
    _socket = await Socket.connect(serverAddress, serverPort);
    status = 1;
    print('Connected to: ${_socket!.remoteAddress.address}:${_socket!.remotePort}');
    _initializeSocket();
  }

  void _initializeSocket() {
    _awaitingHeaderMap[_socket!] = true;
    FileData fileData = FileData.nameedConstructor(clientAddress: _socket!.remoteAddress.address, status: 0);
    _fileDataMap[_socket!] = fileData;

    _socket!.listen((List<int> data) {
      if (_awaitingHeaderMap[_socket!] == true) {
        _handleHeader(_socket!, data);
      } else {
        _handleData(_socket!, data);
      }
    }, onDone: () {
      _fileDataMap.remove(_socket);
      _awaitingHeaderMap.remove(_socket);
      _socket!.destroy();
    }, onError: (error) {
      print('Error: $error');
      _fileDataMap.remove(_socket);
      _awaitingHeaderMap.remove(_socket);
      _socket!.destroy();
    });
  }

  void _handleHeader(Socket socket, List<int> data) {
    // if (_fileDataMap.containsKey(socket)) {
      String header = String.fromCharCodes(data.take(100).toList()).trim();
      print('header ===> ${header}');
      List<String> parts = header.split('|');
      print('parts.length ===> ${parts.length}');
      
      if (parts.length < 2) {
        print('Invalid header');
        return;
      }

      String type = parts[0];
      if (type == 'FILE') {
        _handleFileHeader(socket, data);
      } else if (type == 'MSG') {
        _handleMessageHeader(socket, data);
      } else {
        print('Unknown data type: $type');
      }
    // }
  }

  void _handleFileHeader(Socket socket, List<int> data) {
    FileData fileData = _fileDataMap[socket]!;
    
    String header = String.fromCharCodes(data.take(100).toList()).trim();
    int fileNameLength = int.parse(header.split('|')[1]);
    int fileSize = int.parse(header.split('|')[2]);

    String fileName = utf8.decode(data.skip(100).take(fileNameLength).toList());

    fileData.fileName = fileName;
    fileData.fileSize = fileSize;
    fileData.status = 1;

    List<int> fileContent = data.skip(100 + fileNameLength).toList();
    fileData.fileContent.clear();
    fileData.addData(fileContent);

    _awaitingHeaderMap[socket] = false;

    onFileReceived(fileData);
  }

  void _handleMessageHeader(Socket socket, List<int> data) {
    String header = utf8.decode(data.take(100).toList()).trim();
    int messageLength = int.parse(header.split('|')[1]);

    List<int> messageBytes = data.skip(100).take(messageLength).toList();
    String message = utf8.decode(messageBytes);
    print("Received message: $message");
    onMessageReceived?.call(socket.remoteAddress.address, message);

    _awaitingHeaderMap[socket] = true;  // Ready for next header
  }

  Future<void> _handleData(Socket socket, List<int> data) async {
    if (_fileDataMap.containsKey(socket)) {
      FileData fileData = _fileDataMap[socket]!;
      fileData.addData(data);
      print("fileLength: ${fileData.fileSize} receiveLength: ${fileData.fileContent.length}");

      if (fileData.isComplete()) {
        await _saveAndNotifyFile(fileData);
        _awaitingHeaderMap[socket] = true; 
        fileData.fileContent.clear();  // Reset for the next file
      }
    }
  }

  Future<void> _saveAndNotifyFile(FileData fileData) async {
    fileData.status = 2;
    final prefs = await SharedPreferences.getInstance();
    final directoryPath = prefs.getString('save_directory') ?? 'Not set';
    String tempFilePath = '$directoryPath/${fileData.fileName}';
    File tempFile = File(tempFilePath);
    await tempFile.writeAsBytes(fileData.fileContent);
    onFileReceived(fileData);
  }

  Future<void> sendFile(String filePath, void Function(int, int) onProgress) async {
    File file = File(filePath);
    int totalBytes = await file.length();
    int sentBytes = 0;

    String fileName = basename(file.path);
    List<int> fileNameByte = utf8.encode(fileName);
    String header = '${'FILE|${fileNameByte.length}|$totalBytes'.padRight(100)}$fileName';

    _socket!.add(utf8.encode(header)); // 发送传输头

    await _socket!.addStream(file.openRead().map((data) {
      sentBytes += data.length;
      onProgress(sentBytes, totalBytes);
      return data;
    })).catchError((error) {
      print('Error sending file: $error');
    });
  }

  Future<void> sendMessage(String message) async {
    // 构造消息头
    List<int> messageBytes = utf8.encode(message);
    String msg = '${'MSG|${messageBytes.length}'.padRight(100)}${message}';

    // 发送消息头和消息内容
    _socket!.add(utf8.encode(msg));
    // _socket!.add(messageBytes);

    print('Message sent: $message');
  }

  void disconnect() {
    _socket!.close();
  }
}

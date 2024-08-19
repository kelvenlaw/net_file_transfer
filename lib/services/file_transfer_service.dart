import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/file_data.dart';

class FileTransferService {
  final String serverAddress;
  final int serverPort;
  ServerSocket? _serverSocket;
  final int _tcpPort = 7999;
  final Map<Socket, FileData> _fileDataMap = {};
  final Map<Socket, bool> _awaitingHeaderMap = {};

  FileTransferService({required this.serverAddress, required this.serverPort});


  Future<void> startServer(Function(FileData) onFileReceived) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, _tcpPort);
    print('Listening on ${_serverSocket!.address.address}:${_serverSocket!.port}');

    _serverSocket!.listen((Socket socket) {
      String clientAddress = socket.remoteAddress.address;
      _awaitingHeaderMap[socket] = true;
      FileData fileData = FileData.nameedConstructor(clientAddress: clientAddress, status: 0);
      onFileReceived(fileData);
      _fileDataMap[socket] = fileData;

      socket.listen((List<int> data) {
        if (_awaitingHeaderMap[socket] == true) {
          _handleHeader(socket, clientAddress, data, onFileReceived);
        } else {
          _handleFileData(socket, data, clientAddress, onFileReceived);
        }
      }, onDone: () {
        _fileDataMap.remove(socket);
        _awaitingHeaderMap.remove(socket);
        socket.destroy();
      }, onError: (error) {
        print('Error: $error');
        _fileDataMap.remove(socket);
        _awaitingHeaderMap.remove(socket);
        socket.destroy();
      });
    });
  }

  void _handleHeader(Socket socket, String clientAddress, List<int> data, Function(FileData) onFileReceived) {
    if (_fileDataMap.containsKey(socket)) {
      FileData fileData = _fileDataMap[socket]!;
    
      String header = String.fromCharCodes(data.take(100).toList()).trim();
      int fileNameLength = int.parse(header.split('|')[0]);
      int fileSize = int.parse(header.split('|')[1]);

      String fileName = utf8.decode(data.skip(100).take(fileNameLength).toList()); // 使用utf8.decode解码文件名字节数据为字符串

      fileData.fileName = fileName;
      fileData.fileSize = fileSize;
      fileData.status = 1;
      // FileData fileData = FileData(fileName: fileName, fileSize: fileSize, clientAddress: clientAddress, fileContent: List.empty());
      // _fileDataMap[socket] = fileData;

      List<int> fileContent = data.skip(100 + fileNameLength).toList();
      fileData.fileContent.clear();
      fileData.addData(fileContent);

      _awaitingHeaderMap[socket] = false;

      onFileReceived(fileData);
    }
  }

  Future<void> _handleFileData(Socket socket, List<int> data, String clientAddress, Function(FileData) onFileReceived) async {
    if (_fileDataMap.containsKey(socket)) {
      FileData fileData = _fileDataMap[socket]!;
      fileData.addData(data);
      print("fileLength: ${fileData.fileSize} receiveLength: ${fileData.fileContent.length}");

      if (fileData.isComplete()) {
        fileData.status = 2;
        final prefs = await SharedPreferences.getInstance();
        final directoryPath = prefs.getString('save_directory') ?? 'Not set';
        // String tempDirPath = (await getTemporaryDirectory()).path;
        String tempFilePath = '$directoryPath/${fileData.fileName}';
        File tempFile = File(tempFilePath);
        await tempFile.writeAsBytes(fileData.fileContent);
        onFileReceived(fileData);
        _awaitingHeaderMap[socket] = true; 
        fileData.fileContent.clear();// Reset for the next file
      }
    }
  }




  void disconnect() {
    _serverSocket?.close();
  }
}

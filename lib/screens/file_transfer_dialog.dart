import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:net_file_transfer/services/file_transfer_client.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';


class FileTransferDialog extends StatefulWidget {
  final String deviceAddress;
  final int port;

  FileTransferDialog({required this.deviceAddress, required this.port});

  @override
  _FileTransferDialogState createState() => _FileTransferDialogState();
}

class _FileTransferDialogState extends State<FileTransferDialog> {
  List<String> files = [];
  Map<String, double> progress = {};
  FileTransferClient? _fileTransferClient;
  String connectionStatus = 'Connecting...';
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    // _fileTransferClient = FileTransferClient(serverAddress: widget.deviceAddress, serverPort: widget.port);
    _connectToDevice();
  }

  Future<void> _connectToDevice() async {
    try {
      await _fileTransferClient?.connect();

      setState(() {
        isConnected = true;
        connectionStatus = 'Connected';
      });
    } catch (e) {
      setState(() {
        connectionStatus = 'Failed to connect';
      });
    }
  }

    Future<String> _getPathType(String path) async {
    final file = File(path);
    final directory = Directory(path);

    if (await file.exists()) {
      return 'File';
    } else if (await directory.exists()) {
      return 'Directory';
    } else {
      return 'Unknown';
    }
  }

  Future<void> _pickAndSendFile() async {

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      
    );
    if (result != null) {
      List<String>? filePathList = result.paths.map((path)=>path).cast<String>().toList();
      if (filePathList.length  == 1) {
        String tempFilePath = filePathList[0];
        final fileType = await _getPathType(tempFilePath);
        if (fileType == "File") {
          sendFile(tempFilePath);
        } else {
          String tempDirPath = (await getTemporaryDirectory()).path;
          var uuid = Uuid();
          String tempFilePath = '$tempDirPath/${uuid.v4()}.zip';
          await compressFiles(filePathList, tempFilePath);
          sendFile(tempFilePath);
        }
      } else {
        String tempDirPath = (await getTemporaryDirectory()).path;
        var uuid = Uuid();
        String tempFilePath = '$tempDirPath/${uuid.v4()}.zip';

        await compressFiles(filePathList, tempFilePath);
        sendFile(tempFilePath);
      }
    }
  }

  Future<void> _pickAndSendDirectory() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
        String tempDirPath = (await getTemporaryDirectory()).path;
        var uuid = Uuid();
        String tempFilePath = '$tempDirPath/${uuid.v4()}.zip';

        compressDirectory(result, tempFilePath);
        sendFile(tempFilePath);
      
    }
  }

  Future<void> sendFile(String filePath) async {
    //发送文件
    setState(() {
      files.add(filePath);
      progress[filePath] = 0.0;
    });
    await _fileTransferClient?.sendFile(filePath, (sentBytes, totalBytes) {
      setState(() {
        progress[filePath] = sentBytes / totalBytes;
      });
    });
  }


Future<void> compressFiles(List<String> filePaths, String zipFilePath) async {
  final archive = Archive();

  for (var path in filePaths) {
    final file = File(path);
    final fileBytes = file.readAsBytesSync();
    final fileName = basename(file.path);
    archive.addFile(ArchiveFile(fileName, fileBytes.length, fileBytes));
  }

  final zipEncoder = ZipEncoder();
  final zipFile = File(zipFilePath);
  final zipFileBytes = zipEncoder.encode(archive);

  zipFile.writeAsBytesSync(zipFileBytes!);
}

void compressDirectory(String dirPath, String outputFilePath) {
  final archive = Archive();
  final directory = Directory(dirPath);

  // Recursively add files to the archive
  void addFiles(Directory dir, String rootPath) {
    for (var file in dir.listSync(recursive: true)) {
      if (file is File) {
        final fileBytes = file.readAsBytesSync();
        final relativePath = file.path.substring(rootPath.length + 1);
        archive.addFile(ArchiveFile(relativePath, fileBytes.length, fileBytes));
      }
    }
  }

  addFiles(directory, dirPath);

  // Encode the archive to a ZIP file
  final zipData = ZipEncoder().encode(archive);

  // Write the ZIP file to disk
  final zipFile = File(outputFilePath);
  zipFile.writeAsBytesSync(zipData!);
}


  @override
  void dispose() {
    _fileTransferClient?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('File Transfer to ${widget.deviceAddress}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            Text(connectionStatus, style: TextStyle(fontSize: 16, color: isConnected ? Colors.green : Colors.red)),
            SizedBox(height: 20),
            if (isConnected)
              Container(
                height: 200,
                child: ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    String filePath = files[index];
                    return ListTile(
                      title: Text(filePath),
                      subtitle: LinearProgressIndicator(value: progress[filePath]),
                    );
                  },
                ),
              ),
            SizedBox(height: 20),
            if (isConnected)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _pickAndSendFile,
                    child: Text('Select File'),
                  ),
                  ElevatedButton(
                    onPressed: _pickAndSendDirectory,
                    child: Text('Select Directory'),
                  ),
                ],
              )

          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../services/file_transfer_service.dart';
import '../../services/file_transfer_client.dart';
import '../../models/file_data.dart';

class ChatPanel extends StatefulWidget {
  final Device? selectedDevice;
  final bool isConnected;
  final Function(bool) onConnectionStatusChanged;

  const ChatPanel({
    Key? key,
    this.selectedDevice,
    required this.isConnected,
    required this.onConnectionStatusChanged,
  }) : super(key: key);

  @override
  _ChatPanelState createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  FileTransferClient? _fileTransferClient;
  List<Message> messages = [];

  @override
  void initState() {
    super.initState();
    final fileTransferService = Provider.of<FileTransferService>(context, listen: false);
    fileTransferService.startServer(_onFileReceived);
    fileTransferService.onMessageReceived = _onMessageReceived;
  }

  @override
  void didUpdateWidget(ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDevice != oldWidget.selectedDevice) {
      _connectToDevice();
    }
  }

  @override
  void dispose() {
    _fileTransferClient?.disconnect();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFileReceived(FileData fileData) {
    setState(() {
      messages.add(Message('Received file: ${fileData.fileName}', 'Other'));
    });
  }

  void _onMessageReceived(String address, String message) {
    setState(() {
      messages.add(Message(message, address));
    });
  }

  Future<void> _connectToDevice() async {
    if (widget.selectedDevice != null) {
      final fileTransferService = Provider.of<FileTransferService>(context, listen: false);
      _fileTransferClient = await fileTransferService.getClient(widget.selectedDevice!.address);
      widget.onConnectionStatusChanged(true);
    }
  }

  void _sendMessage(String message) {
    if (widget.isConnected && _fileTransferClient != null) {
      _fileTransferClient!.sendMessage(message);
      setState(() {
        messages.add(Message(message, 'You'));
      });
      _messageController.clear();
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  Future<void> _sendFile() async {
    if (widget.isConnected && _fileTransferClient != null) {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        String filePath = result.files.single.path!;
        _fileTransferClient!.sendFile(filePath, (sentBytes, totalBytes) {
          print('Progress: $sentBytes/$totalBytes');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: widget.selectedDevice == null
          ? Center(child: Text('No device selected'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.isConnected
                        ? 'Connected to ${widget.selectedDevice!.address}'
                        : 'Not connected',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!widget.isConnected)
                  ElevatedButton(
                    onPressed: _connectToDevice,
                    child: Text('Connect'),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      bool isSentByMe = messages[index].sender == 'You';
                      return Align(
                        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              messages[index].sender,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              margin: EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: isSentByMe ? Colors.blue[100] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(messages[index].text),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (text) {
                            if (text.isNotEmpty) {
                              _sendMessage(text);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send),
                        onPressed: widget.isConnected
                            ? () {
                                if (_messageController.text.isNotEmpty) {
                                  _sendMessage(_messageController.text);
                                }
                              }
                            : null,
                      ),
                      IconButton(
                        icon: Icon(Icons.attach_file),
                        onPressed: widget.isConnected ? _sendFile : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class Message {
  final String text;
  final String sender;

  Message(this.text, this.sender);
}
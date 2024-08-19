import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _directoryPath;

  @override
  void initState() {
    super.initState();
    _loadDirectoryPath();
  }

  Future<void> _loadDirectoryPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _directoryPath = prefs.getString('save_directory') ?? 'Not set';
    });
  }

  Future<void> _chooseDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      await _saveDirectoryPath(result);
    }
  }

  Future<void> _saveDirectoryPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('save_directory', path);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/config.cfg');
    await file.writeAsString('save_directory=$path');

    setState(() {
      _directoryPath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Save Directory:'),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _directoryPath),
                    readOnly: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'No directory selected',
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _chooseDirectory,
                  child: Text('Select Directory'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/network_service.dart';

class DeviceListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final networkService = Provider.of<NetworkService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Discovered Devices'),
      ),
      body: ListView.builder(
        itemCount: networkService.devices.length,
        itemBuilder: (context, index) {
          final device = networkService.devices[index];
          return ListTile(
            title: Text(device.name),
            subtitle: Text(device.address),
            onTap: () async {
              networkService.connectToDevice(device);

              // Choose a file to send
              FilePickerResult? result = await FilePicker.platform.pickFiles();
              if (result != null) {
                String filePath = result.files.single.path!;
                networkService.sendFile(filePath);
              }
            },
          );
        },
      ),
    );
  }
}

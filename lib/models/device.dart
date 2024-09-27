import 'dart:io';

class Device {
  final String name;
  final String address;
  String? status;
  Socket? socket;

  Device({required this.name, required this.address});
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';

import 'ble_device_ext.dart';

class FirmwareMockCharacteristic extends BluetoothCharacteristic {
  @override
  final BleMockDevice device;

  @override
  List<int> lastValue = [];

  FirmwareMockCharacteristic({required this.device})
      : super.fromProto(BmBluetoothCharacteristic(
            remoteId: device.remoteId,
            characteristicUuid: Guid('660f727e-7782-7274-0000-000000000000'),
            serviceUuid: gkServiceUuid,
            primaryServiceUuid: null,
            descriptors: [],
            properties: BmCharacteristicProperties(
                broadcast: false,
                read: true,
                writeWithoutResponse: false,
                write: false,
                notify: false,
                indicate: false,
                authenticatedSignedWrites: false,
                extendedProperties: false,
                notifyEncryptionRequired: false,
                indicateEncryptionRequired: false)));

  @override
  CharacteristicProperties get properties {
    return const CharacteristicProperties(read: true, write: true);
  }

  @override
  Future<List<int>> read({int? timeout}) async {
    lastValue = "Dropper 0.8.0".codeUnits;
    return lastValue;
  }
}

class ReportMockCharacteristic extends BluetoothCharacteristic {
  @override
  final BleMockDevice device;

  Timer? _timer;

  ReportMockCharacteristic({required this.device})
      : super.fromProto(BmBluetoothCharacteristic(
            remoteId: device.remoteId,
            characteristicUuid: Guid('72067078-7276-0078-0000-000000000000'),
            serviceUuid: gkServiceUuid,
            primaryServiceUuid: null,
            descriptors: [],
            properties: BmCharacteristicProperties(
                broadcast: false,
                read: false,
                writeWithoutResponse: false,
                write: false,
                notify: true,
                indicate: false,
                authenticatedSignedWrites: false,
                extendedProperties: false,
                notifyEncryptionRequired: false,
                indicateEncryptionRequired: false)));

  @override
  CharacteristicProperties get properties {
    return const CharacteristicProperties(notify: true);
  }

  final StreamController<List<int>> _notificationController =
      StreamController.broadcast();

  @override
  Stream<List<int>> get onValueReceived => _notificationController.stream;

  @override
  Future<bool> setNotifyValue(bool notify,
      {bool forceIndications = false, int timeout = 15}) async {
    if (!device.isConnected) {
      throw Exception('Cannot set notify value on a disconnected device');
    }

    if (notify) {
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!device.isConnected) {
          _timer?.cancel();
          _timer = null;
          return;
        }
        // TODO: dynamic report data
        _notificationController.add(jsonEncode({
          "#": 27,
          "date": "20-02-14",
          "time": "16:05:04",
          "timestamp": 1644854704,
          "report": true,
          "cycles": 2445,
          "doses": 35,
          "event": 2
        }).codeUnits);
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
    return true;
  }
}

class BleMockService extends BluetoothService {
  final BleMockDevice device;
  final _characteristics = <BluetoothCharacteristic>[];

  BleMockService({required this.device})
      : super.fromProto(BmBluetoothService(
          remoteId: device.remoteId,
          serviceUuid: gkServiceUuid,
          characteristics: [],
          primaryServiceUuid: null,
        )) {
    _characteristics.add(FirmwareMockCharacteristic(device: device));
    _characteristics.add(ReportMockCharacteristic(device: device));
  }

  @override
  List<BluetoothCharacteristic> get characteristics => _characteristics;
}

class BleMockDevice extends BluetoothDevice {
  final _services = <BluetoothService>[];

  BleMockDevice(String id) : super(remoteId: DeviceIdentifier(id)) {
    _services.add(BleMockService(device: this));
  }

  final StreamController<BluetoothConnectionState> connectionStateController =
      StreamController.broadcast();

  @override
  Stream<BluetoothConnectionState> get connectionState =>
      connectionStateController.stream;

  bool _isConnected = false;

  @override
  bool get isConnected => _isConnected;

  @override
  String get platformName => remoteId.toString();

  @override
  Future<void> connect({bool? autoConnect, int? mtu, Duration? timeout}) async {
    connectionStateController.add(BluetoothConnectionState.disconnected);
    await Future.delayed(const Duration(seconds: 1));
    _isConnected = true;
    connectionStateController.add(BluetoothConnectionState.connected);
  }

  @override
  Future<void> disconnect(
      {int? androidDelay, bool? queue, int? timeout}) async {
    await Future.delayed(const Duration(seconds: 1));
    _isConnected = false;
    connectionStateController.add(BluetoothConnectionState.disconnected);
  }

  @override
  Future<List<BluetoothService>> discoverServices(
      {bool? subscribeToServicesChanged, int? timeout}) async {
    await Future.delayed(const Duration(seconds: 1));
    return _services;
  }

  @override
  Future<void> requestConnectionPriority(
      {required ConnectionPriority connectionPriorityRequest}) async {}
}

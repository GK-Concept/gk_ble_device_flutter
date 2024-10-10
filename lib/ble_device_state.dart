part of 'ble_device_cubit.dart';

class BleDeviceState {
  final BluetoothAdapterState status;

  const BleDeviceState({
    this.status = BluetoothAdapterState.unknown,
  });
}

class BleDeviceAuthorizing extends BleDeviceState {
  const BleDeviceAuthorizing({
    super.status = BluetoothAdapterState.unknown,
  });
}

class BleDeviceScanning extends BleDeviceState {
  final List<BluetoothDevice> discoveredDevices;
  final bool scanIsInProgress;

  const BleDeviceScanning({
    required this.discoveredDevices,
    required this.scanIsInProgress,
  }) : super(status: BluetoothAdapterState.on);
}

class BleDeviceConnecting extends BleDeviceState {
  final BluetoothDevice device;
  final BluetoothConnectionState connectionState;

  const BleDeviceConnecting({
    required this.device,
    required this.connectionState,
  }) : super(status: BluetoothAdapterState.on);
}

class BleDeviceGettingServices extends BleDeviceState {
  final BluetoothDevice device;

  const BleDeviceGettingServices({
    required this.device,
  }) : super(status: BluetoothAdapterState.on);
}

class BleDeviceGettingCharacteristics extends BleDeviceState {
  final BluetoothDevice device;
  final List<BluetoothService> services;

  const BleDeviceGettingCharacteristics({
    required this.device,
    required this.services,
  }) : super(status: BluetoothAdapterState.on);
}

class BleDeviceConnected extends BleDeviceState {
  final BluetoothDevice device;
  final Map<GKCharId, BluetoothCharacteristic> characteristics;
  final Map<GKCharId, Stream<List<int>>> characteristicStreams;
  final String? firmwareVersion;

  const BleDeviceConnected({
    required this.device,
    this.firmwareVersion,
    this.characteristics = const {},
    this.characteristicStreams = const {},
  }) : super(status: BluetoothAdapterState.on);
}

class BleDeviceFailedToConnect extends BleDeviceState {
  final BluetoothDevice device;
  final String errorMessage;

  const BleDeviceFailedToConnect({
    required this.device,
    required this.errorMessage,
  });
}

class BleDeviceDisconnected extends BleDeviceState {
  final BluetoothDevice device;

  const BleDeviceDisconnected({
    required this.device,
  }) : super(status: BluetoothAdapterState.on);
}

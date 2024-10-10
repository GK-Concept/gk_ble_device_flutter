import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum DeviceType { unknown, dropper, paperscent, maestroNano }

final gkServiceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");

extension DeviceTypeExtension on BluetoothDevice {
  DeviceType get deviceType {
    if (platformName.length > 4 && platformName.substring(2, 4) == 'DR') {
      return DeviceType.dropper;
    }
    if (platformName.length > 4 && platformName.substring(2, 4) == 'PS') {
      return DeviceType.paperscent;
    }
    if (platformName.length > 4 && platformName.substring(2, 4) == 'MN') {
      return DeviceType.maestroNano;
    }
    return DeviceType.unknown;
  }

  String get deviceTypeString {
    switch (deviceType) {
      case DeviceType.dropper:
        return "Dropper";
      case DeviceType.paperscent:
        return "Paperscent";
      case DeviceType.maestroNano:
        return "Maestro Nano";
      default:
        return "Unknown";
    }
  }
}

extension BleStatusExtension on BluetoothAdapterState {
  String get determineText {
    switch (this) {
      case BluetoothAdapterState.unavailable:
        return "This device does not support Bluetooth";
      case BluetoothAdapterState.unauthorized:
        return "Please authorize the app to use Bluetooth and location";
      case BluetoothAdapterState.off:
        return "Bluetooth is powered off on your device, please turn it on";
      case BluetoothAdapterState.on:
        return "Bluetooth is up and running";
      default:
        return "Waiting to fetch Bluetooth status $this";
    }
  }
}

enum GKCharId {
  unknown,
  firmwareVersion,
  report,
}

final Map<Guid, GKCharId> knownCharacteristics = {
  Guid('660f727e-7782-7274-0000-000000000000'): GKCharId.firmwareVersion,
  /** deprecated (c.f. https://github.com/GK-Concept/Dropper/pull/8) */
  Guid('660f727e-7782-7274-5674-7270697c6e78'): GKCharId.firmwareVersion,
  Guid('72067078-7276-0078-0000-000000000000'): GKCharId.report,
};

extension CharacteristicHelper on BluetoothCharacteristic {
  GKCharId get characteristicId =>
      knownCharacteristics[uuid] ?? GKCharId.unknown;
  String get name => characteristicId.name;
  String get stringValue => String.fromCharCodes(lastValue);
}

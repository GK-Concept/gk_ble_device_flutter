import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_device_ext.dart';

part 'ble_device_state.dart';

/// Cubit for BLE device management
///
/// This cubit manages BLE device scanning, connection and communication with GK Concept BLE
/// devices. It emits the following states:
///
/// - [BleDeviceAuthorizing]: when the app is waiting for the user to authorize BLE
/// - [BleDeviceScanning]: when the app is scanning for BLE devices
/// - [BleDeviceConnecting]: when the app is connecting to a BLE device
/// - [BleDeviceConnected]: when the app is connected to a BLE device
/// - [BleDeviceGettingServices]: when the app is discovering the services of a BLE device
/// - [BleDeviceGettingCharacteristics]: when the app is discovering the characteristics of a BLE device
/// - [BleDeviceFailedToConnect]: when the app failed to connect to a BLE device
/// - [BleDeviceDisconnected]: when the app is disconnected from a BLE device
class BleDeviceCubit extends Cubit<BleDeviceState> {
  static final logger = Logger("BLE");

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubs;
  StreamSubscription<List<BluetoothDevice>>? _scanSubs;
  Timer? _scanTimer;
  final _rssis = <BluetoothDevice, int>{};

  StreamSubscription<BluetoothConnectionState>? _conStateSubs;

  BleDeviceCubit()
      : super(const BleDeviceState(status: BluetoothAdapterState.off)) {
    _adapterStateSubs = FlutterBluePlus.adapterState.listen((state) {
      emit(BleDeviceAuthorizing(status: state));

      if (Platform.isMacOS) {
        return;
      }

      if (state == BluetoothAdapterState.off && Platform.isAndroid) {
        _switchOnBle();
      } else if (state == BluetoothAdapterState.unauthorized) {
        _allowBle();
        // NOTE: on Android, this is necessary, because we get BluetoothAdapterState.on
        //       even when the user denies the permissions
      } else if (state == BluetoothAdapterState.on && Platform.isAndroid) {
        _checkPermissions();
      }
    });
  }

  @override
  Future<void> close() async {
    super.close();
    _scanSubs?.cancel();
    _conStateSubs?.cancel();
    _adapterStateSubs?.cancel();
  }

  /// Start scanning for BLE devices.
  ///
  /// Starts the scanning process and sets a timer to stop the scanning process if no new devices
  /// are found.
  ///
  Future<void> startScanning() async {
    if (state.status != BluetoothAdapterState.on ||
        (state is BleDeviceScanning &&
            (state as BleDeviceScanning).scanIsInProgress)) {
      return;
    }

    if (_scanTimer != null) {
      return;
    }

    emit(const BleDeviceScanning(
      discoveredDevices: [],
      scanIsInProgress: true,
    ));

    /* clear cached RSSI values */
    _rssis.clear();

    /* instead of subscribing to the raw results, generate a sorted list of devices */
    _scanSubs = FlutterBluePlus.scanResults
        /* ignore redundant and empty scan results */
        .distinct(
            (previous, current) => (previous == current) || current.isEmpty)
        /* convert the scan results to a list of devices, storing the RSSI values */
        .map(
      (results) {
        final devices = results.map(
          (r) {
            _rssis[r.device] = r.rssi;
            return r.device;
          },
        ).toList();
        /* sort the devices by name */
        devices.sort((d1, d2) => d1.platformName.compareTo(d2.platformName));
        return devices;
      },
    ).listen(
      /* update the state with the sorted list of devices */
      (devices) => emit(BleDeviceScanning(
        discoveredDevices: devices,
        scanIsInProgress: true,
      )),
    );

    FlutterBluePlus.isScanning
        .firstWhere((isScanning) => !isScanning)
        .then((_) {
      FlutterBluePlus.startScan(
        withServices: [gkServiceUuid],
        continuousUpdates: true,
        timeout: const Duration(seconds: 10),
        removeIfGone: const Duration(seconds: 5),
      );
    });

    int previousDeviceCount = 0;
    _scanTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (state is! BleDeviceScanning) return;

      final devices = (state as BleDeviceScanning).discoveredDevices;

      if (devices.length > previousDeviceCount) {
        previousDeviceCount = devices.length;
      } else {
        await stopScanning();
      }
    });

    logger.info("Scanning started");
  }

  /// Stop scanning for BLE devices.
  ///
  /// Stops the scanning process and cancels the scan subscription.
  ///
  Future<void> stopScanning() async {
    if (state is! BleDeviceScanning) return;

    emit(BleDeviceScanning(
        discoveredDevices: (state as BleDeviceScanning).discoveredDevices,
        scanIsInProgress: false));
    await _scanSubs?.cancel();
    _scanSubs = null;
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  /// Connect to a BLE device.
  ///
  /// Connects to `device` and discovers its services.
  ///
  Future<void> connect(BluetoothDevice device) async {
    if (state is! BleDeviceScanning) {
      logger.severe("Not in scanning state");
      return;
    }

    await stopScanning();

    if (!(state as BleDeviceScanning).discoveredDevices.contains(device)) {
      logger.severe("Device not found in the list of discovered devices");
      return;
    }

    emit(BleDeviceConnecting(
      device: device,
      connectionState: BluetoothConnectionState.disconnected,
    ));

    /* skip one to avoid the initial connection state (disconnected) to
     * be emitted
     */
    _conStateSubs = device.connectionState.skip(1).listen(
      (event) => _onConnectionUpdate(device, event),
      onError: (e) {
        logger.severe("Error callback called on connectToDevice stream");
        emit(
          BleDeviceFailedToConnect(
            device: device,
            errorMessage: e.toString(),
          ),
        );
      },
    );

    final success = await _tryFbpOperation(
        device, "connecting to device ${device.platformName}", () async {
      await device.connect(timeout: const Duration(seconds: 10));
      if (!device.isConnected) {
        logger.warning("connection failed");
        emit(
          BleDeviceFailedToConnect(
            device: device,
            errorMessage: "Connection failed",
          ),
        );
      } else {
        logger.info("connected to device ${device.platformName}");
      }
      // TODO: let the firmware take care of this and check on all
      //       platforms
      if (Platform.isAndroid) {
        await device.requestConnectionPriority(
            connectionPriorityRequest: ConnectionPriority.high);
      }
    });
    if (success) {
      await discoverServices();
    }
  }

  /// Disconnect from the device
  ///
  /// Disconnects from the device and cancels the connection subscription.
  ///
  Future<void> disconnect() async {
    if (state is! BleDeviceConnected) return;

    await _conStateSubs?.cancel();
    await (state as BleDeviceConnected).device.disconnect();
  }

  /// Discover services of the connected device
  ///
  /// Discovers the services of the connected device and updates the state with the
  /// discovered services. This method also updates the characteristics from the device.
  ///
  Future<void> discoverServices() async {
    final device = state is BleDeviceConnecting
        ? (state as BleDeviceConnecting).device
        : state is BleDeviceConnected
            ? (state as BleDeviceConnected).device
            : null;
    if (device == null) {
      return;
    }
    emit(BleDeviceGettingServices(device: device));

    bool isPaired = false;
    if (Platform.isAndroid) {
      isPaired = await device.bondState.first == BluetoothBondState.bonded;
    } else {
      // NOTE: this is a workaround to check if the device is paired for macOS and iOS
      final systemDevices = await FlutterBluePlus.systemDevices;
      isPaired = systemDevices.contains(device);
    }
    logger.info("device is ${isPaired ? "" : "not "}paired");

    final success =
        await _tryFbpOperation(device, "discovering services", () async {
      final services = await device.discoverServices();
      emit(BleDeviceGettingCharacteristics(
        device: device,
        services: services,
      ));
    });
    // Android-only
    // await device.createBond(timeout: 10);
    if (success) {
      await _updateCharacteristics();
    }
  }

  /// Update the characteristics from the connected device.
  ///
  /// This method reads the characteristics from the device and updates the state with the
  /// characteristics and their values. It also subscribes to notifications of the characteristics
  /// that support it.
  ///
  Future<void> _updateCharacteristics() async {
    if (state is! BleDeviceGettingCharacteristics) return;
    final connectedState = state as BleDeviceGettingCharacteristics;
    final services = connectedState.services;
    /* create copies of characteristics and streams so that we can modify them */
    final chars = <GKCharId, BluetoothCharacteristic>{};
    final streams = <GKCharId, Stream<List<int>>>{};

    String? firmwareVersion;

    final service = services.where((s) => s.uuid == gkServiceUuid).firstOrNull;
    if (service != null) {
      logger.fine("updating characteristics of service: ${service.uuid}");
      for (BluetoothCharacteristic c in service.characteristics) {
        var canRead = c.properties.read;
        var canNotify = c.properties.notify;
        final canWrite = c.properties.write;
        if (!canWrite && !canRead && !canNotify) continue;

        /* add the characteristic to the map if it does not exist yet */
        chars.putIfAbsent(c.characteristicId, () => c);

        /* unless we are paired, we can only read the firmware version */
        if (c.characteristicId != GKCharId.firmwareVersion &&
            c.characteristicId != GKCharId.report) {
          canRead = false;
          canNotify = false;
        }

        /* subscribe to notifications */
        if (canNotify && !c.isNotifying) {
          streams[c.characteristicId] = c.onValueReceived;
          final success = await _tryFbpOperation(
              connectedState.device, "activating notification for ${c.uuid}",
              () async {
            await c.setNotifyValue(true);
          });
          if (!success) return;
        }

        /* read the value of the characteristic */
        if (canRead) {
          final success = await _tryFbpOperation(
              connectedState.device, "reading characteristic ${c.uuid}",
              () async {
            await c.read();
            switch (c.characteristicId) {
              case GKCharId.firmwareVersion:
                firmwareVersion = c.stringValue;
                break;
              default:
                break;
            }
          });
          if (!success) return;
        }

        logger.fine(
            "found characteristic ${c.uuid}, name: ${c.name}), read: $canRead, write: $canWrite${canRead ? ", value: ${c.stringValue}" : ""}");
      }
    }

    emit(BleDeviceConnected(
      device: connectedState.device,
      characteristics: chars,
      characteristicStreams: streams,
      firmwareVersion: firmwareVersion,
    ));
  }

  /// Get the cached RSSI value of a device.
  ///
  /// Returns the RSSI value of  `device`. This value is cached and updated during scanning.
  ///
  int getRssi(BluetoothDevice device) {
    return _rssis[device] ?? 0;
  }

  void _onConnectionUpdate(
      BluetoothDevice device, BluetoothConnectionState update) {
    if (update == BluetoothConnectionState.disconnected) {
      logger.info("Device disconnected");
      emit(BleDeviceDisconnected(device: device));
      return;
    }
  }

  void _fbpErrorHandler(
      String operationDescription, e, BluetoothDevice device) {
    var msg = e.toString();
    if (e is FlutterBluePlusException) {
      msg = e.description ?? e.toString();
    }
    if (e is PlatformException) {
      msg = e.message ?? e.toString();
    }
    logger.severe("Error $operationDescription: $msg");
    if (device.isConnected) {
      emit(
        BleDeviceFailedToConnect(
          device: device,
          errorMessage: "Error $operationDescription: $msg",
        ),
      );
    }
  }

  Future<bool> _tryFbpOperation(BluetoothDevice device,
      String operationDescription, Function operation) async {
    logger.info("$operationDescription...");
    try {
      await operation();
      return true;
    } on Exception catch (e) {
      _fbpErrorHandler(operationDescription, e, device);
      return false;
    }
  }

  Future<void> _switchOnBle() async {
    try {
      await FlutterBluePlus.turnOn();
    } on FlutterBluePlusException catch (e) {
      logger.severe("Error turning on BLE: $e");
      emit(const BleDeviceAuthorizing(
        status: BluetoothAdapterState.off,
      ));
    }
  }

  Future<void> _allowBle() async {
    final connectionPermission = await Permission.bluetoothConnect.request();
    final bleScanPermission = await Permission.bluetoothScan.request();
    final locationPermission = await Permission.location.request();

    logger.info("Connection permission: $connectionPermission");
    logger.info("BLE scan permission: $bleScanPermission");
    logger.info("Location permission: $locationPermission");

    if (connectionPermission.isGranted &&
        bleScanPermission.isGranted &&
        locationPermission.isGranted) {
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }
    } else {
      emit(const BleDeviceAuthorizing(
        status: BluetoothAdapterState.unauthorized,
      ));
    }
  }

  // NOTE: Android-only, on iOS the status is denied even when permissions
  //       are granted
  Future<void> _checkPermissions() async {
    final connectionPermission = await Permission.bluetoothConnect.status;
    final bleScanPermission = await Permission.bluetoothScan.status;
    final locationPermission = await Permission.location.status;

    logger.info("Connection permission: $connectionPermission");
    logger.info("BLE scan permission: $bleScanPermission");
    logger.info("Location permission: $locationPermission");

    if (connectionPermission.isDenied ||
        bleScanPermission.isDenied ||
        locationPermission.isDenied) {
      _allowBle();
      emit(const BleDeviceAuthorizing(
        status: BluetoothAdapterState.unauthorized,
      ));
    }
  }
}

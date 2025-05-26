import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gk_ble_device_flutter/ble_device_cubit.dart';
import 'package:gk_ble_device_flutter/ble_device_ext.dart';
import 'package:gk_ble_device_flutter/ble_mock_device.dart';

class BleMultiDeviceState {
  final Map<String, BleDeviceState> deviceStates;
  final Map<String, List<int>> reports;

  BleMultiDeviceState({required this.deviceStates, required this.reports});
}

class BleMultiDeviceCubit extends Cubit<BleMultiDeviceState> {
  final List<String> deviceIds;
  final Map<String, BleDeviceCubit> deviceCubits = {};
  final Map<String, StreamSubscription<BleDeviceState>> deviceSubscriptions =
      {};
  final Map<String, StreamSubscription<List<int>>> reportSubscriptions = {};
  final List<BleMockDevice> mockDevices = [];

  BleMultiDeviceCubit({required this.deviceIds})
      : super(BleMultiDeviceState(
            deviceStates: Map.fromEntries(
                deviceIds.map((id) => MapEntry(id, const BleDeviceState()))),
            reports: {}));

  void start() {
    for (var deviceId in deviceIds) {
      deviceCubits[deviceId] = BleDeviceCubit();
      deviceCubits[deviceId]!.mockDevices.addAll(mockDevices);

      // handle state transitions for each device's cubit and forward them
      // to this cubit's state
      deviceSubscriptions[deviceId] =
          deviceCubits[deviceId]!.stream.listen((state) async {
        if (state is BleDeviceAuthorizing) {
          await deviceCubits[deviceId]!.startScanning();
        } else if (state is BleDeviceScanning) {
          final device = state.discoveredDevices
              .where((d) => d.platformName == deviceId)
              .firstOrNull;
          if (device != null) {
            await deviceCubits[deviceId]!.connect(device);
          } else if (!state.scanIsInProgress) {
            await Future.delayed(const Duration(seconds: 5));
            await deviceCubits[deviceId]!.startScanning();
          }
        } else if (state is BleDeviceConnected) {
          if (state.characteristicStreams.containsKey(GKCharId.report)) {
            reportSubscriptions[deviceId] =
                state.characteristicStreams[GKCharId.report]!.listen((report) {
              emit(BleMultiDeviceState(
                  deviceStates:
                      deviceCubits.map((k, v) => MapEntry(k, v.state)),
                  reports: {deviceId: report}));
            });
          }
        } else if (state is BleDeviceDisconnected) {
          reportSubscriptions[deviceId]?.cancel();
          reportSubscriptions.remove(deviceId);
          await deviceCubits[deviceId]!.startScanning();
        }

        emit(BleMultiDeviceState(
            deviceStates: deviceCubits.map((k, v) => MapEntry(k, v.state)),
            reports: {}));
      });
    }
  }

  // TODO: add stop to clean up subscriptions etc.
}

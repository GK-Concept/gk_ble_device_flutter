import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';

import 'package:gk_ble_device_flutter/ble_device_ext.dart';
import 'package:gk_ble_device_flutter/ble_device_cubit.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.info);
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(
        '${record.loggerName}: ${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(BlocProvider(
      create: (_) => BleDeviceCubit(),
      child: const MaterialApp(home: DropperDemoApp())));
}

class DropperDemoApp extends StatefulWidget {
  const DropperDemoApp({super.key});

  @override
  State<DropperDemoApp> createState() => _DropperDemoAppState();
}

final Map<Type, Function(BleDeviceState state)> _stateMessages = {
  BleDeviceAuthorizing: (state) => 'Authorizing Bluetooth...',
  BleDeviceConnecting: (state) =>
      'Connecting to ${(state as BleDeviceConnecting).device.platformName}...',
  BleDeviceGettingServices: (state) =>
      'Retrieving services from ${(state as BleDeviceGettingServices).device.platformName}...',
  BleDeviceGettingCharacteristics: (state) =>
      'Retrieving characteristics from ${(state as BleDeviceGettingCharacteristics).device.platformName}...',
  BleDeviceDisconnected: (state) =>
      'Disconnected from ${(state as BleDeviceDisconnected).device.platformName}',
  BleDeviceFailedToConnect: (state) =>
      'Failed to connect to ${(state as BleDeviceFailedToConnect).device.platformName}',
};

final Map<Type, Function(BleDeviceState state)> _stateSymbols = {
  BleDeviceAuthorizing: (state) => const CircularProgressIndicator(),
  BleDeviceConnecting: (state) => const CircularProgressIndicator(),
  BleDeviceGettingServices: (state) => const CircularProgressIndicator(),
  BleDeviceGettingCharacteristics: (state) => const CircularProgressIndicator(),
  BleDeviceDisconnected: (state) => const Icon(Icons.error),
  BleDeviceFailedToConnect: (state) => const Icon(Icons.error),
};

class _DropperDemoAppState extends State<DropperDemoApp> {
  List<BluetoothDevice> _devices = [];
  StreamSubscription? _reportSubscription;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _reportSubscription?.cancel();
    super.dispose();
  }

  Widget _scanScreen(BuildContext context, BleDeviceState state) {
    return Center(
        child: Column(children: [
      if (state is BleDeviceScanning && state.scanIsInProgress)
        const Column(children: [
          SizedBox(
            height: 20,
          ),
          CircularProgressIndicator(),
          SizedBox(
            height: 20,
          ),
          Text('Scanning for devices...'),
        ]),
      if (state is BleDeviceScanning && !state.scanIsInProgress)
        ElevatedButton(
            onPressed: () {
              context.read<BleDeviceCubit>().startScanning();
            },
            child: const Text('Scan for devices')),
      if (_devices.isEmpty)
        const Text('No devices found')
      else
        Expanded(
            child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  return ListTile(
                      title: Row(children: [
                        const Icon(Icons.router),
                        const SizedBox(width: 10),
                        Text(_devices[index].platformName)
                      ]),
                      onTap: () {
                        context.read<BleDeviceCubit>().connect(_devices[index]);
                      });
                }))
    ]));
  }

  Widget _connectedScreen(BuildContext context, BleDeviceConnected state) {
    return Center(
        child: Column(children: [
      const SizedBox(height: 20),
      const Icon(Icons.check),
      const SizedBox(height: 20),
      Text('Connected to ${state.device.platformName}'),
      const SizedBox(height: 20),
      if (state.characteristics.containsKey(GKCharId.firmwareVersion))
        ...[Text('Firmware version: ${state.characteristics[GKCharId.firmwareVersion]!.stringValue}'),
        const SizedBox(height: 20)],
      ElevatedButton(
          onPressed: () async {
            final cubit = context.read<BleDeviceCubit>();
            await cubit.disconnect();
            await cubit.startScanning();
          },
          child: const Text("Disconnect"))
    ]));
  }

  Widget _buildScreen(BuildContext context, BleDeviceState state) {
    if (state is BleDeviceScanning) {
      return _scanScreen(context, state);
    }
    if (state is BleDeviceConnected) {
      return _connectedScreen(context, state);
    }

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          if (_stateSymbols.containsKey(state.runtimeType))
            _stateSymbols[state.runtimeType]!(state)
          else
            const SizedBox.shrink(),
          const SizedBox(height: 20),
          Text(_stateMessages.containsKey(state.runtimeType)
              ? _stateMessages[state.runtimeType]!(state)
              : ''),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BleDeviceCubit, BleDeviceState>(
      listener: (context, state) {
        if (state is BleDeviceAuthorizing &&
            state.status == BluetoothAdapterState.on) {
          context.read<BleDeviceCubit>().startScanning();
        }
        if (state is BleDeviceScanning) {
          setState(() {
            _devices = state.discoveredDevices;
          });
        }
        if (state is BleDeviceConnected &&
            state.characteristicStreams.containsKey(GKCharId.report)) {
          if (_reportSubscription != null) {
            _reportSubscription!.cancel();
          }
          _reportSubscription = state.characteristicStreams[GKCharId.report]!
              .listen((List<int> report) {
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Report: ${String.fromCharCodes(report)}')));
          });
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Dropper Demo"),
          ),
          body: _buildScreen(context, state),
        );
      },
    );
  }
}

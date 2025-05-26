import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:gk_ble_device_flutter/ble_device_cubit.dart';
import 'package:gk_ble_device_flutter/ble_multi_device_cubit.dart';
import 'package:logging/logging.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.info);
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(
        '${record.loggerName}: ${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(BlocProvider(
      create: (_) {
        final cubit = BleMultiDeviceCubit(deviceIds: [
          'GKDR-DMGCXKJX3EBA',
          'GKDR-DMGCXKJX3EDA',
          'GKDR-DMGCXKJX3EFQ',
          'GKDR-DMGCXKJX3ERQ',
          'GKDR-DMGCXKJXE76A',
          'GKDR-DMGCXKJXE7MQ',
          'GKDR-DMGCXKJXE7OQ',
          'GKDR-DMGCXKJXFAFQ',
          'GKDR-DMGCXKJXFCIA',
          'GKDR-DMGCXKJXFLFQ',
        ]);
        cubit.start();
        return cubit;
      },
      child: const MaterialApp(home: DropperDemoApp())));
}

class DropperDemoApp extends StatefulWidget {
  const DropperDemoApp({super.key});

  @override
  State<DropperDemoApp> createState() => _DropperDemoAppState();
}

class _DropperDemoAppState extends State<DropperDemoApp> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BleMultiDeviceCubit, BleMultiDeviceState>(
      listener: (context, state) {
        state.reports.forEach((deviceId, report) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Report from $deviceId: ${String.fromCharCodes(report)}"),
              duration: const Duration(seconds: 2),
            ),
          );
        });
      },
      builder: (context, state) {
        return Scaffold(
            appBar: AppBar(
              title: const Text("Dropper Multi Device Demo"),
            ),
            body: ListView(
                children: state.deviceStates.keys
                    .map((deviceId) => ListTile(
                          leading:
                              state.deviceStates[deviceId] is BleDeviceConnected
                                  ? const Icon(Icons.bluetooth_connected,
                                      color: Colors.green)
                                  : const Icon(Icons.bluetooth,
                                      color: Colors.orange),
                          title: Text(deviceId),
                          subtitle: Text(state
                              .deviceStates[deviceId].runtimeType
                              .toString()),
                        ))
                    .toList()));
      },
    );
  }
}

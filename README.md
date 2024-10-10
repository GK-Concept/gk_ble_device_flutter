[![Build](https://github.com/GK-Concept/gk_ble_device_flutter/actions/workflows/build.yml/badge.svg)](https://github.com/GK-Concept/gk_ble_device_flutter/actions/workflows/build.yml)
[![Code format](https://github.com/GK-Concept/gk_ble_device_flutter/actions/workflows/codeformat.yml/badge.svg)](https://github.com/GK-Concept/gk_ble_device_flutter/actions/workflows/codeformat.yml)
[![Linting](https://github.com/GK-Concept/gk_ble_device_flutter/actions/workflows/linting.yml/badge.svg)](https://github.com/GK-Concept/gk_ble_device_flutter/actions/workflows/linting.yml)

This library enables the user to connect to a GK Concept device via Bluetooth Low
Energy (BLE), to discover devices in the proximity and to subscribe to the device's
report stream, notifying the application of the device's activity.

Currently, this library only supports [Dropper](https://www.gkconcept.co/dropper/)
devices with firmware 0.8.0 and later.

## Getting started

When using this library, please make sure to follow the
[FlutterBluePlus guide](https://pub.dev/packages/flutter_blue_plus#getting-started),
in particular concerning the required permissions for your app.

## Usage

All the core functionality is implemented in
[`BleDeviceCubit`](https://pub.dev/documentation/gk_ble_device_flutter/latest/gk_ble_device_flutter/BleDeviceCubit-class.html).

## Permissions for macOS

For macOS, put the following in your `Info.plist`:

```
	<key>NSBluetoothAlwaysUsageDescription</key>
	<string>The app uses bluetooth to find, connect and transfer data between different devices</string>
	<key>NSBluetoothPeripheralUsageDescription</key>
	<string>The app uses bluetooth to find, connect and transfer data between different devices</string>
```

Also, add this to `DebugProfile.entitlements` and `Release.entitlements`:

```
	<key>com.apple.security.device.bluetooth</key>
	<true/>
```

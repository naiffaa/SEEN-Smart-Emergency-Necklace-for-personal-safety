import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/seen_ble_message.dart';

class SeenBleService {
  SeenBleService._();
  static final SeenBleService instance = SeenBleService._();

  static const String serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String commandUuid = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String statusUuid = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

  final StreamController<List<ScanResult>> _scanResultsController =
      StreamController<List<ScanResult>>.broadcast();

  final StreamController<SeenBleMessage> _messageController =
      StreamController<SeenBleMessage>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandCharacteristic;
  BluetoothCharacteristic? _statusCharacteristic;

  bool _isScanning = false;
  bool _isConnecting = false;

  List<ScanResult> _latestResults = [];

  Stream<List<ScanResult>> get scanResultsStream =>
      _scanResultsController.stream;
  Stream<SeenBleMessage> get messageStream => _messageController.stream;

  BluetoothDevice? get connectedDevice => _device;

  bool get isConnected =>
      _device != null &&
      _commandCharacteristic != null &&
      _statusCharacteristic != null;

  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;

  String? get connectedDeviceId => _device?.remoteId.str;

  bool isConnectedTo(String deviceId) {
    return isConnected && _device?.remoteId.str == deviceId;
  }

  Future<void> ensurePermissions() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();
      final locationStatus = await Permission.locationWhenInUse.request();

      if (!scanStatus.isGranted ||
          !connectStatus.isGranted ||
          !locationStatus.isGranted) {
        throw Exception("Bluetooth/location permissions are required");
      }
    }
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    await ensurePermissions();

    _isScanning = true;
    _latestResults = [];
    _scanResultsController.add(_latestResults);

    await _scanSubscription?.cancel();
    await FlutterBluePlus.stopScan();

    if (await FlutterBluePlus.isSupported == false) {
      _isScanning = false;
      throw Exception("Bluetooth LE is not supported on this device");
    }

    await _ensureBluetoothOn();

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        final deduped = <String, ScanResult>{};
        for (final result in results) {
          deduped[result.device.remoteId.str] = result;
        }

        final devices = deduped.values.toList()
          ..sort((a, b) {
            final aSeen = _looksLikeSeen(a) ? 1 : 0;
            final bSeen = _looksLikeSeen(b) ? 1 : 0;
            return bSeen.compareTo(aSeen);
          });

        _latestResults = devices;
        _scanResultsController.add(_latestResults);
      },
      onError: (e) {
        _scanResultsController.addError(e);
      },
    );

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );
      await FlutterBluePlus.isScanning.where((v) => v == false).first;
    } finally {
      _isScanning = false;
      await FlutterBluePlus.stopScan();
    }
  }

  Future<ScanResult?> findDeviceById(
    String deviceId, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await ensurePermissions();

    final completer = Completer<ScanResult?>();

    StreamSubscription<List<ScanResult>>? tempSub;
    tempSub = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        if (result.device.remoteId.str == deviceId) {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
          break;
        }
      }
    });

    try {
      await FlutterBluePlus.stopScan();
      await _ensureBluetoothOn();
      await FlutterBluePlus.startScan(timeout: timeout);

      final result = await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );

      return result;
    } finally {
      await FlutterBluePlus.stopScan();
      await tempSub.cancel();
    }
  }

  Future<void> reconnectToSavedDevice(String deviceId) async {
    if (_isConnecting) return;

    if (isConnectedTo(deviceId)) return;

    final found = await findDeviceById(deviceId);
    if (found == null) {
      throw Exception("Saved device not found nearby");
    }

    await connect(found.device);
  }

  Future<void> _ensureBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;

    if (state == BluetoothAdapterState.on) return;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {}
    }

    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw Exception("Bluetooth is off or permission is not granted"),
        );
  }

  bool _looksLikeSeen(ScanResult r) {
    final deviceName = r.device.platformName.trim().toUpperCase();
    final advName = r.advertisementData.advName.trim().toUpperCase();

    final serviceMatches = r.advertisementData.serviceUuids
        .map((e) => e.toString().toUpperCase())
        .contains(serviceUuid.toUpperCase());

    return deviceName.contains('SEEN') ||
        advName.contains('SEEN') ||
        serviceMatches;
  }

  Future<void> stopScan() async {
    _isScanning = false;
    await FlutterBluePlus.stopScan();
  }

  Future<void> connect(BluetoothDevice device) async {
    if (_isConnecting) return;

    _isConnecting = true;

    try {
      await stopScan();

      await _notifySubscription?.cancel();
      await _connectionStateSubscription?.cancel();

      if (_device != null && _device!.remoteId != device.remoteId) {
        try {
          await _device!.disconnect();
        } catch (_) {}
      }

      try {
        await device.connect(timeout: const Duration(seconds: 12));
      } catch (_) {}

      _device = device;

      _connectionStateSubscription =
          device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          await _clearConnectionState();
        }
      });

      await _discoverCharacteristics(device);
      await _subscribeToNotifications();

      await sendCommand("PING");
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _discoverCharacteristics(BluetoothDevice device) async {
    _commandCharacteristic = null;
    _statusCharacteristic = null;

    final services = await device.discoverServices();

    for (final service in services) {
      if (_normalizeUuid(service.uuid.str128) == _normalizeUuid(serviceUuid)) {
        for (final characteristic in service.characteristics) {
          final uuid = _normalizeUuid(characteristic.uuid.str128);

          if (uuid == _normalizeUuid(commandUuid)) {
            _commandCharacteristic = characteristic;
          } else if (uuid == _normalizeUuid(statusUuid)) {
            _statusCharacteristic = characteristic;
          }
        }
      }
    }

    if (_commandCharacteristic == null || _statusCharacteristic == null) {
      throw Exception("SEEN BLE service not found on the connected device");
    }
  }

  Future<void> _subscribeToNotifications() async {
    if (_statusCharacteristic == null) {
      throw Exception("Status characteristic is missing");
    }

    await _notifySubscription?.cancel();

    final characteristic = _statusCharacteristic!;
    await characteristic.setNotifyValue(true);

    _notifySubscription = characteristic.lastValueStream.listen((value) {
      if (value.isEmpty) return;

      final raw = utf8.decode(value, allowMalformed: true).trim();
      if (raw.isEmpty) return;

      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _messageController.add(SeenBleMessage.fromJson(decoded));
          return;
        }
      } catch (_) {}

      _messageController.add(
        SeenBleMessage(
          type: 'raw',
          value: raw,
        ),
      );
    });
  }

  Future<void> sendCommand(String command) async {
    if (_commandCharacteristic == null) {
      throw Exception("No connected SEEN device");
    }

    await _commandCharacteristic!.write(
      utf8.encode(command),
      withoutResponse: true,
    );
  }

  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    _notifySubscription = null;

    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
    }

    await _clearConnectionState();
  }

  Future<void> _clearConnectionState() async {
    _commandCharacteristic = null;
    _statusCharacteristic = null;
    _device = null;
  }

  String _normalizeUuid(String input) => input.trim().toUpperCase();

  void dispose() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _scanResultsController.close();
    _messageController.close();
  }
}
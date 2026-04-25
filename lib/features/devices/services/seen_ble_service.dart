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
  bool _autoReconnect = true;

  String? _lastDeviceId;

  List<ScanResult> _latestResults = [];
  final StringBuffer _notifyBuffer = StringBuffer();

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

  String? get connectedDeviceId => _device?.remoteId.str ?? _lastDeviceId;

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

        debugPrint("SEEN BLE scan results: ${devices.length}");
      },
      onError: (e) {
        debugPrint("SEEN BLE scan error: $e");
        _scanResultsController.addError(e);
      },
    );

    try {
      debugPrint("SEEN BLE start scan");
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await FlutterBluePlus.isScanning.where((v) => v == false).first;
    } finally {
      _isScanning = false;
      await FlutterBluePlus.stopScan();
      debugPrint("SEEN BLE scan stopped");
    }
  }

  Future<ScanResult?> findDeviceById(
    String deviceId, {
    Duration timeout = const Duration(seconds: 10),
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

      return await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
    } finally {
      await FlutterBluePlus.stopScan();
      await tempSub.cancel();
    }
  }

  Future<void> reconnectToSavedDevice(String deviceId) async {
    if (_isConnecting) return;
    if (isConnectedTo(deviceId)) return;

    _lastDeviceId = deviceId;
    debugPrint("SEEN BLE reconnecting to saved device: $deviceId");

    final found = await findDeviceById(deviceId);
    if (found == null) {
      throw Exception("Saved device not found nearby");
    }

    await connect(found.device);
  }

  Future<void> _tryAutoReconnect() async {
    if (!_autoReconnect) return;
    if (_lastDeviceId == null || _lastDeviceId!.isEmpty) return;
    if (_isConnecting || isConnected) return;

    try {
      debugPrint("SEEN BLE auto reconnect trying...");
      await reconnectToSavedDevice(_lastDeviceId!);
    } catch (e) {
      debugPrint("SEEN BLE auto reconnect failed: $e");
    }
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
    _autoReconnect = true;

    try {
      await stopScan();

      await _notifySubscription?.cancel();
      await _connectionStateSubscription?.cancel();

      if (_device != null && _device!.remoteId != device.remoteId) {
        try {
          await _device!.disconnect();
        } catch (_) {}
      }

      debugPrint("SEEN BLE connecting to ${device.remoteId.str}");

      try {
        await device.connect(
          timeout: const Duration(seconds: 12),
          autoConnect: false,
        );
      } catch (e) {
        debugPrint("SEEN BLE connect note: $e");
      }

      _device = device;
      _lastDeviceId = device.remoteId.str;

      _connectionStateSubscription =
          device.connectionState.listen((state) async {
        debugPrint("SEEN BLE connection state: $state");

        if (state == BluetoothConnectionState.disconnected) {
          await _clearConnectionState(keepLastDevice: true);
          Future.delayed(const Duration(seconds: 2), _tryAutoReconnect);
        }
      });

      await _discoverCharacteristics(device);
      await _subscribeToNotifications();

      await ping();
      await Future.delayed(const Duration(milliseconds: 250));
      await getBattery();
      await Future.delayed(const Duration(milliseconds: 250));
      await getGps();
      await Future.delayed(const Duration(milliseconds: 250));
      await getMic();

      debugPrint("SEEN BLE connected successfully");
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

    debugPrint("SEEN BLE characteristics discovered");
  }

  Future<void> _subscribeToNotifications() async {
    if (_statusCharacteristic == null) {
      throw Exception("Status characteristic is missing");
    }

    await _notifySubscription?.cancel();

    final characteristic = _statusCharacteristic!;
    await characteristic.setNotifyValue(true);

    _notifySubscription = characteristic.lastValueStream.listen(
      (value) {
        if (value.isEmpty) return;

        final chunk = utf8.decode(value, allowMalformed: true);
        if (chunk.trim().isEmpty) return;

        debugPrint("SEEN BLE chunk: $chunk");

        _notifyBuffer.write(chunk);

        final current = _notifyBuffer.toString();
        if (!current.contains('\n')) return;

        final messages = current.split('\n');
        _notifyBuffer.clear();

        if (messages.isNotEmpty && messages.last.trim().isNotEmpty) {
          _notifyBuffer.write(messages.last);
        }

        for (int i = 0; i < messages.length - 1; i++) {
          final raw = messages[i].trim();
          if (raw.isEmpty) continue;

          final parsed = _parseIncomingMessage(raw);
          debugPrint("SEEN BLE parsed: $parsed");
          _messageController.add(parsed);
        }
      },
      onError: (e) {
        debugPrint("SEEN BLE notification error: $e");
      },
    );
  }

  SeenBleMessage _parseIncomingMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SeenBleMessage.fromJson(decoded);
      }
    } catch (_) {}

    if (raw.contains('|')) {
      return SeenBleMessage.fromRaw(raw);
    }

    final lowered = raw.trim().toLowerCase();

    if (lowered == 'ready') {
      return SeenBleMessage(type: 'ready', value: raw, raw: raw);
    }

    if (lowered == 'pong') {
      return SeenBleMessage(type: 'pong', value: raw, raw: raw);
    }

    if (lowered == 'armed') {
      return SeenBleMessage(type: 'armed', value: raw, raw: raw);
    }

    if (lowered == 'disarmed') {
      return SeenBleMessage(type: 'disarmed', value: raw, raw: raw);
    }

    return SeenBleMessage(type: 'raw', value: raw, raw: raw);
  }

  Future<void> sendCommand(String command) async {
    if (_commandCharacteristic == null) {
      throw Exception("No connected SEEN device");
    }

    final cleanCommand = command.trim();
    debugPrint("SEEN BLE send command: $cleanCommand");

    await _commandCharacteristic!.write(
      utf8.encode("$cleanCommand\n"),
      withoutResponse: true,
    );
  }

  Future<void> ping() => sendCommand("PING");

  Future<void> getGps() => sendCommand("GET_GPS");

  Future<void> getBattery() => sendCommand("GET_BAT");

  Future<void> getMic() => sendCommand("GET_MIC");

  Future<void> arm() => sendCommand("ARM");

  Future<void> disarm() => sendCommand("DISARM");

  Future<void> disconnect() async {
    debugPrint("SEEN BLE disconnect");
    _autoReconnect = false;

    await _notifySubscription?.cancel();
    _notifySubscription = null;

    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
    }

    await _clearConnectionState(keepLastDevice: false);
  }

  Future<void> _clearConnectionState({bool keepLastDevice = true}) async {
    _commandCharacteristic = null;
    _statusCharacteristic = null;
    _device = null;
    _notifyBuffer.clear();

    if (!keepLastDevice) {
      _lastDeviceId = null;
    }

    debugPrint("SEEN BLE connection cleared");
  }

  String _normalizeUuid(String input) => input.trim().toUpperCase();

  void dispose() {
    _autoReconnect = false;
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _scanResultsController.close();
    _messageController.close();
  }
}
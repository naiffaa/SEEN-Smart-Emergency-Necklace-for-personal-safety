import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/theme/colors.dart';
import 'device_setup_screen.dart';
import 'services/ble_sync_service.dart';
import 'services/seen_ble_service.dart';

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  final SeenBleService _ble = SeenBleService.instance;
  final TextEditingController _manualIdController = TextEditingController();

  List<ScanResult> _results = [];
  ScanResult? _selected;
  bool _isScanning = false;
  bool _isConnecting = false;
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();

    _scanSub = _ble.scanResultsStream.listen((results) {
      if (!mounted) return;
      setState(() => _results = results);
    });

    _startScan();
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _results = [];
      _selected = null;
    });

    try {
      await _ble.startScan();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Scan failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectSelectedDevice() async {
    if (_selected == null || _isConnecting) return;
    await _connectAndSave(_selected!);
  }

  Future<void> _connectManualDevice() async {
    if (_isConnecting) return;

    final manualId = _manualIdController.text.trim();
    if (manualId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a device ID")),
      );
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final found = await _ble.findDeviceById(manualId);

      if (found == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Device not found nearby")),
        );
        return;
      }

      await _connectAndSave(found, alreadyLoading: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Manual connection failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _connectAndSave(
    ScanResult result, {
    bool alreadyLoading = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!alreadyLoading) {
      setState(() => _isConnecting = true);
    }

    try {
      await _ble.connect(result.device);
      BleSyncService.instance.start();

      final deviceName = _displayName(result);
      final deviceId = result.device.remoteId.str;

      final deviceData = {
        'name': deviceName,
        'deviceId': deviceId,
        'bleName': deviceName,
        'status': 'Connected',
        'connectionStatus': 'Paired',
        'isPaired': true,
        'source': 'ble',
        'pairedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .set(deviceData, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pairedDeviceId': deviceId,
        'pairedDeviceName': deviceName,
        'pairedVia': 'ble',
        'bleConnected': true,
        'bleDeviceId': deviceId,
        'status': 'Safe',
        'pairedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await Future.delayed(const Duration(milliseconds: 250));
      await _ble.getBattery();
      await Future.delayed(const Duration(milliseconds: 250));
      await _ble.getGps();
      await Future.delayed(const Duration(milliseconds: 250));
      await _ble.getMic();

      if (!mounted) return;

      final setupResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeviceSetupScreen(deviceName: deviceName),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, setupResult ?? true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection failed: $e")),
      );
    } finally {
      if (mounted && !alreadyLoading) {
        setState(() => _isConnecting = false);
      }
    }
  }

  String _displayName(ScanResult result) {
    final platformName = result.device.platformName.trim();
    final advName = result.advertisementData.advName.trim();

    if (platformName.isNotEmpty) return platformName;
    if (advName.isNotEmpty) return advName;

    return "SEEN Device";
  }

  bool _isLikelySeen(ScanResult result) {
    final platformName = result.device.platformName.trim().toUpperCase();
    final advName = result.advertisementData.advName.trim().toUpperCase();

    final serviceMatches = result.advertisementData.serviceUuids
        .map((e) => e.toString().toUpperCase())
        .contains(SeenBleService.serviceUuid.toUpperCase());

    return platformName.contains('SEEN') ||
        advName.contains('SEEN') ||
        serviceMatches;
  }

  String _subtitleText(ScanResult result) {
    final advName = result.advertisementData.advName.trim();
    final isLikelySeen = _isLikelySeen(result);

    if (isLikelySeen && advName.isNotEmpty) {
      return "${result.device.remoteId.str} • likely SEEN";
    }

    if (isLikelySeen) {
      return "${result.device.remoteId.str} • matches service";
    }

    return "${result.device.remoteId.str} • ${advName.isEmpty ? "no name" : advName}";
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _manualIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Connect Device",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isScanning ? null : _startScan,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: _isScanning
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildConnectHeader(theme),
              const SizedBox(height: 20),
              Text(
                "Nearby Devices — tap to select",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_results.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _isScanning
                        ? "Searching..."
                        : "No devices found. Make sure the SEEN ESP32-S3 is powered on.",
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ..._results.map(_buildDeviceTile),
              const SizedBox(height: 20),
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "or enter manually",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Device ID",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _manualIdController,
                decoration: const InputDecoration(
                  hintText: "Enter Device ID",
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isConnecting ? null : _connectManualDevice,
                  child: Text(
                    _isConnecting ? "Connecting..." : "Connect by Device ID",
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selected == null || _isConnecting)
                      ? null
                      : _connectSelectedDevice,
                  child: Text(_isConnecting ? "Connecting..." : "Pair Device"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.bluetooth_searching_rounded,
              size: 40,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Connect Your Wearable",
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isScanning
                ? "Scanning nearby Bluetooth devices..."
                : "Scan for your SEEN device or connect manually using the Device ID.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth),
              label: Text(
                _isScanning ? "Scanning..." : "Scan Bluetooth Devices",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(ScanResult result) {
    final name = _displayName(result);
    final subtitle = _subtitleText(result);
    final isSelected = _selected?.device.remoteId == result.device.remoteId;
    final isLikelySeen = _isLikelySeen(result);
    final rssi = result.rssi;

    return GestureDetector(
      onTap: () => setState(() => _selected = result),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isLikelySeen ? AppColors.success : AppColors.border),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Radio<String>(
              value: result.device.remoteId.str,
              groupValue: _selected?.device.remoteId.str,
              activeColor: AppColors.primary,
              onChanged: (_) => setState(() => _selected = result),
            ),
            const SizedBox(width: 4),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isLikelySeen
                    ? AppColors.successSoft
                    : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isLikelySeen
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_rounded,
                color:
                    isLikelySeen ? AppColors.success : AppColors.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        "$rssi dBm",
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (isLikelySeen) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Likely your SEEN device",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
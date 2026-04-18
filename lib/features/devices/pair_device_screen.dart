import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/theme/colors.dart';
import 'device_setup_screen.dart';
import 'services/seen_ble_service.dart';

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  final SeenBleService _ble = SeenBleService.instance;

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
      setState(() {
        _results = results;
      });
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
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _connectSelectedDevice() async {
    if (_selected == null || _isConnecting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isConnecting = true);

    try {
      await _ble.connect(_selected!.device);

      final deviceName = _displayName(_selected!);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(_selected!.device.remoteId.str)
          .set({
        'name': deviceName,
        'deviceId': _selected!.device.remoteId.str,
        'bleName': deviceName,
        'status': 'Connected',
        'battery': 0,
        'location': 'Unknown',
        'isPaired': true,
        'source': 'ble',
        'pairedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeviceSetupScreen(deviceName: deviceName),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, result ?? true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  String _displayName(ScanResult result) {
    final platformName = result.device.platformName.trim();
    final advName = result.advertisementData.advName.trim();

    if (platformName.isNotEmpty) return platformName;
    if (advName.isNotEmpty) return advName;

    return "Unknown BLE Device";
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
    final hasAdvName = advName.isNotEmpty;
    final isLikelySeen = _isLikelySeen(result);

    if (isLikelySeen && hasAdvName) {
      return "${result.device.remoteId.str} • likely SEEN";
    }

    if (isLikelySeen) {
      return "${result.device.remoteId.str} • matches service";
    }

    if (hasAdvName) {
      return result.device.remoteId.str;
    }

    return "${result.device.remoteId.str} • no name";
  }

  @override
  void dispose() {
    _scanSub?.cancel();
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
                      "Pair Device",
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
              Container(
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
                          : "Scan for nearby Bluetooth devices or enter the Device ID manually.",
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
                        icon: const Icon(Icons.bluetooth),
                        label: Text(
                          _isScanning
                              ? "Scanning..."
                              : "Connect Bluetooth Devices",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                        : "No devices found. If your ESP appears as N/A in other apps, it may still show here as Unknown BLE Device.",
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
              const TextField(
                decoration: InputDecoration(
                  hintText: "Enter Device ID",
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

  Widget _buildDeviceTile(ScanResult result) {
    final name = _displayName(result);
    final subtitle = _subtitleText(result);
    final isSelected = _selected?.device.remoteId == result.device.remoteId;
    final isLikelySeen = _isLikelySeen(result);
    final rssi = result.rssi;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selected = result;
        });
      },
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
              onChanged: (_) {
                setState(() {
                  _selected = result;
                });
              },
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
                color: isLikelySeen
                    ? AppColors.success
                    : AppColors.textPrimary,
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
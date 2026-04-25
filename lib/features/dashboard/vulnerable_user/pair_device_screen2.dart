import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import '../../devices/services/ble_sync_service.dart';
import '../../devices/services/seen_ble_service.dart';
import 'setup_device_screen.dart';

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
  bool _isForgetting = false;
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();

    _scanSub = _ble.scanResultsStream.listen((results) {
      if (!mounted) return;
      setState(() => _results = results);
    });
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

  String _displayNameFromScan(ScanResult result) {
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

  Future<void> _requestInitialDeviceStatus() async {
    try {
      await Future.delayed(const Duration(milliseconds: 250));
      await _ble.getBattery();
      await Future.delayed(const Duration(milliseconds: 250));
      await _ble.getGps();
      await Future.delayed(const Duration(milliseconds: 250));
      await _ble.getMic();
    } catch (_) {}
  }

  Future<void> _pairFirstTime() async {
    if (_selected == null || _isConnecting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isConnecting = true);

    try {
      await _ble.connect(_selected!.device);
      BleSyncService.instance.start();

      final deviceName = _displayNameFromScan(_selected!);
      final deviceId = _selected!.device.remoteId.str;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .set({
        'name': deviceName,
        'deviceId': deviceId,
        'bleName': deviceName,
        'status': 'Connected',
        'connectionStatus': 'Paired',
        'battery': 0,
        'batteryVoltage': null,
        'location': 'Waiting GPS...',
        'lat': null,
        'lng': null,
        'gpsFix': false,
        'sat': 0,
        'micLevel': 0,
        'micOk': false,
        'streamUrl': '',
        'isPaired': true,
        'source': 'ble',
        'pairedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pairedDeviceId': deviceId,
        'pairedDeviceName': deviceName,
        'pairedVia': 'ble',
        'bleConnected': true,
        'bleDeviceId': deviceId,
        'status': 'Safe',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _requestInitialDeviceStatus();

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetupDeviceScreen(deviceId: deviceId),
        ),
      );

      if (!mounted) return;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appLanguage.text(
                en: "Device paired successfully.",
                ar: "تم اقتران الجهاز بنجاح.",
              ),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnectSavedDevice(String userId, String deviceId) async {
    try {
      await _ble.disconnect();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .set({
        'status': 'Disconnected',
        'connectionStatus': 'Disconnected',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'bleConnected': false,
        'status': 'Safe',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appLanguage.text(
              en: "Device disconnected.",
              ar: "تم فصل الجهاز.",
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Disconnect failed: $e")),
      );
    }
  }

  Future<void> _forgetSavedDevice({
    required String userId,
    required String deviceId,
  }) async {
    if (_isForgetting) return;

    final lang = appLanguage;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          lang.text(en: "Forget device?", ar: "هل تريد نسيان الجهاز؟"),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          lang.text(
            en: "This will remove the saved device and let you connect a new one.",
            ar: "سيتم حذف الجهاز المحفوظ لتتمكن من ربط جهاز جديد.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.text(en: "Cancel", ar: "إلغاء")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.text(en: "Forget", ar: "نسيان"),
              style: const TextStyle(color: AppColors.emergencyRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isForgetting = true);

    try {
      await _ble.disconnect();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .delete();

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'pairedDeviceId': FieldValue.delete(),
        'pairedDeviceName': FieldValue.delete(),
        'pairedVia': FieldValue.delete(),
        'bleConnected': false,
        'bleDeviceId': FieldValue.delete(),
        'status': 'Safe',
        'streamUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _results = [];
        _selected = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Device forgotten. You can connect a new device now.",
              ar: "تم نسيان الجهاز. يمكنك ربط جهاز جديد الآن.",
            ),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Forget device failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isForgetting = false);
    }
  }

  Future<void> _reconnectSavedDevice({
    required String userId,
    required String savedDeviceId,
    required String savedDeviceName,
  }) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _results = [];
      _selected = null;
    });

    try {
      final found = await _ble.findDeviceById(savedDeviceId);

      if (found == null) {
        throw Exception("Saved device not found nearby");
      }

      await _ble.connect(found.device);
      BleSyncService.instance.start();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(savedDeviceId)
          .set({
        'name': savedDeviceName,
        'deviceId': savedDeviceId,
        'status': 'Connected',
        'connectionStatus': 'Paired',
        'isPaired': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'pairedDeviceId': savedDeviceId,
        'pairedDeviceName': savedDeviceName,
        'pairedVia': 'ble',
        'bleConnected': true,
        'bleDeviceId': savedDeviceId,
        'status': 'Safe',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _requestInitialDeviceStatus();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appLanguage.text(
              en: "Device reconnected successfully.",
              ar: "تمت إعادة اتصال الجهاز بنجاح.",
            ),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reconnect failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            lang.text(
              en: "No user logged in.",
              ar: "لا يوجد مستخدم مسجل الدخول.",
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          lang.text(en: "Pair Device", ar: "اقتران الجهاز"),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          final hasSavedDevice =
              snapshot.hasData && snapshot.data!.docs.isNotEmpty;

          Map<String, dynamic>? savedDevice;
          String? savedDeviceDocId;

          if (hasSavedDevice) {
            savedDevice =
                snapshot.data!.docs.first.data() as Map<String, dynamic>;
            savedDeviceDocId = snapshot.data!.docs.first.id;
          }

          final currentlyConnected = savedDeviceDocId != null &&
              _ble.connectedDevice != null &&
              _ble.connectedDevice!.remoteId.str == savedDeviceDocId &&
              _ble.isConnected;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasSavedDevice)
                  _buildSavedDeviceCard(
                    context: context,
                    savedDevice: savedDevice!,
                    savedDeviceDocId: savedDeviceDocId!,
                    currentlyConnected: currentlyConnected,
                    userId: user.uid,
                  )
                else
                  _buildFirstTimePairingCard(context),
                if (!hasSavedDevice) ...[
                  const SizedBox(height: 20),
                  Text(
                    lang.text(
                      en: "Nearby Devices — tap to select",
                      ar: "الأجهزة القريبة — اضغط للاختيار",
                    ),
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
                            ? lang.text(en: "Searching...", ar: "جارٍ البحث...")
                            : lang.text(
                                en:
                                    "No devices found yet. Make sure your SEEN device is powered on and nearby.",
                                ar:
                                    "لم يتم العثور على أجهزة بعد. تأكد أن جهاز SEEN يعمل وقريب.",
                              ),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ..._results.map(_buildDeviceTile),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_selected == null || _isConnecting)
                          ? null
                          : _pairFirstTime,
                      child: Text(
                        _isConnecting
                            ? lang.text(en: "Connecting...", ar: "جارٍ الاتصال...")
                            : lang.text(en: "Pair Device", ar: "اقتران الجهاز"),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _infoCard(hasSavedDevice, theme, lang),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFirstTimePairingCard(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(24),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.sensors_rounded,
              size: 40,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            lang.text(
              en: "Connect Your Wearable",
              ar: "اربط جهازك القابل للارتداء",
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isScanning
                ? lang.text(
                    en: "Scanning nearby Bluetooth devices...",
                    ar: "جارٍ البحث عن أجهزة البلوتوث القريبة...",
                  )
                : lang.text(
                    en: "Search for your SEEN device and pair it for the first time.",
                    ar: "ابحث عن جهاز SEEN الخاص بك واربطه لأول مرة.",
                  ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
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
                  : const Icon(Icons.bluetooth_searching_rounded),
              label: Text(
                _isScanning
                    ? lang.text(en: "Scanning...", ar: "جارٍ البحث...")
                    : lang.text(
                        en: "Search Bluetooth Devices",
                        ar: "البحث عن أجهزة البلوتوث",
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedDeviceCard({
    required BuildContext context,
    required Map<String, dynamic> savedDevice,
    required String savedDeviceDocId,
    required bool currentlyConnected,
    required String userId,
  }) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    final deviceName =
        (savedDevice['name'] ?? savedDevice['bleName'] ?? 'SEEN Device')
            .toString();

    final statusText = currentlyConnected
        ? lang.text(en: "Connected", ar: "متصل")
        : lang.text(en: "Saved Device", ar: "جهاز محفوظ");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(24),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: currentlyConnected
                  ? AppColors.successSoft
                  : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              currentlyConnected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.sensors_rounded,
              size: 40,
              color: currentlyConnected
                  ? AppColors.success
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            deviceName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            savedDeviceDocId,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: currentlyConnected
                  ? AppColors.successSoft
                  : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: currentlyConnected
                    ? AppColors.success
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (currentlyConnected)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _disconnectSavedDevice(userId, savedDeviceDocId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                ),
                child: Text(lang.text(en: "Disconnect", ar: "فصل الاتصال")),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isConnecting
                    ? null
                    : () => _reconnectSavedDevice(
                          userId: userId,
                          savedDeviceId: savedDeviceDocId,
                          savedDeviceName: deviceName,
                        ),
                child: Text(
                  _isConnecting
                      ? lang.text(en: "Reconnecting...", ar: "جارٍ إعادة الاتصال...")
                      : lang.text(en: "Reconnect", ar: "إعادة الاتصال"),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isForgetting
                  ? null
                  : () => _forgetSavedDevice(
                        userId: userId,
                        deviceId: savedDeviceDocId,
                      ),
              icon: _isForgetting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(
                _isForgetting
                    ? lang.text(en: "Forgetting...", ar: "جارٍ الحذف...")
                    : lang.text(en: "Forget Device", ar: "نسيان الجهاز"),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emergencyRed,
                side: const BorderSide(color: AppColors.emergencyRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(ScanResult result) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    final name = _displayNameFromScan(result);
    final isSelected = _selected?.device.remoteId == result.device.remoteId;
    final isLikelySeen = _isLikelySeen(result);
    final rssi = result.rssi;

    return GestureDetector(
      onTap: () => setState(() => _selected = result),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            Icon(
              isLikelySeen
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_rounded,
              color: isLikelySeen ? AppColors.success : AppColors.textPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.device.remoteId.str,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (isLikelySeen) ...[
                    const SizedBox(height: 6),
                    Text(
                      lang.text(
                        en: "Likely your SEEN device",
                        ar: "غالبًا هذا جهاز SEEN الخاص بك",
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              "$rssi dBm",
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(bool hasSavedDevice, ThemeData theme, dynamic lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasSavedDevice
                  ? lang.text(
                      en:
                          "Your device is saved. Use Reconnect to connect again, or Forget Device to pair a different SEEN device.",
                      ar:
                          "جهازك محفوظ. استخدم إعادة الاتصال للاتصال مجددًا، أو نسيان الجهاز لربط جهاز SEEN آخر.",
                    )
                  : lang.text(
                      en:
                          "Make sure Bluetooth is enabled and your SEEN device is nearby before scanning.",
                      ar:
                          "تأكد من تفعيل البلوتوث وأن جهاز SEEN قريب منك قبل البحث.",
                    ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(double radius) {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    );
  }
}
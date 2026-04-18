import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
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

  String _displayNameFromScan(ScanResult result) {
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

  Future<void> _pairFirstTime() async {
    if (_selected == null || _isConnecting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isConnecting = true);

    try {
      await _ble.connect(_selected!.device);

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
      if (mounted) {
        setState(() => _isConnecting = false);
      }
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
      await _ble.startScan();

      final matched = _results.where((r) {
        return r.device.remoteId.str == savedDeviceId;
      }).toList();

      if (matched.isEmpty) {
        throw Exception("Saved device not found nearby");
      }

      final target = matched.first;
      await _ble.connect(target.device);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(savedDeviceId)
          .set({
        'name': savedDeviceName,
        'deviceId': savedDeviceId,
        'status': 'Connected',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
      if (mounted) {
        setState(() => _isConnecting = false);
      }
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
            lang.text(en: "No user logged in.", ar: "لا يوجد مستخدم مسجل الدخول."),
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

          final bool currentlyConnected = savedDeviceDocId != null &&
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
                            ? lang.text(
                                en: "Searching...",
                                ar: "جارٍ البحث...",
                              )
                            : lang.text(
                                en: "No devices found yet. Make sure your SEEN device is powered on and nearby.",
                                ar: "لم يتم العثور على أجهزة بعد. تأكد أن جهاز SEEN يعمل وقريب.",
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
                            ? lang.text(
                                en: "Connecting...",
                                ar: "جارٍ الاتصال...",
                              )
                            : lang.text(
                                en: "Pair Device",
                                ar: "اقتران الجهاز",
                              ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                Container(
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
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasSavedDevice
                              ? lang.text(
                                  en: "Your saved device will stay linked to your account. You can reconnect or disconnect it anytime.",
                                  ar: "سيبقى جهازك المحفوظ مرتبطًا بحسابك. يمكنك إعادة اتصاله أو فصله في أي وقت.",
                                )
                              : lang.text(
                                  en: "Make sure Bluetooth is enabled and your SEEN device is nearby before scanning.",
                                  ar: "تأكد من تفعيل البلوتوث وأن جهاز SEEN قريب منك قبل البحث.",
                                ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.textPrimary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : const Icon(
                      Icons.bluetooth_searching_rounded,
                      color: AppColors.textPrimary,
                    ),
              label: Text(
                _isScanning
                    ? lang.text(
                        en: "Scanning...",
                        ar: "جارٍ البحث...",
                      )
                    : lang.text(
                        en: "Search Bluetooth Devices",
                        ar: "البحث عن أجهزة البلوتوث",
                      ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
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
                child: Text(
                  lang.text(en: "Disconnect", ar: "فصل الاتصال"),
                ),
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
                      ? lang.text(
                          en: "Reconnecting...",
                          ar: "جارٍ إعادة الاتصال...",
                        )
                      : lang.text(
                          en: "Reconnect",
                          ar: "إعادة الاتصال",
                        ),
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

    final platformName = result.device.platformName.trim();
    final advName = result.advertisementData.advName.trim();

    final name = platformName.isNotEmpty
        ? platformName
        : advName.isNotEmpty
            ? advName
            : lang.text(
                en: "Unknown BLE Device",
                ar: "جهاز بلوتوث غير معروف",
              );

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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
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
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
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

}
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import '../../devices/device_history_screen.dart';
import '../../devices/device_location_screen.dart';
import '../../devices/models/seen_ble_message.dart';
import '../../devices/services/seen_ble_service.dart';

class VUDashboard extends StatefulWidget {
  const VUDashboard({super.key});

  @override
  State<VUDashboard> createState() => _VUDashboardState();
}

class _VUDashboardState extends State<VUDashboard> {
  bool isCountingDown = false;
  int countdown = 5;
  Timer? timer;

  final SeenBleService _ble = SeenBleService.instance;
  StreamSubscription<SeenBleMessage>? _bleSub;

  double? _liveLat;
  double? _liveLng;
  String _liveDeviceStatus = "Safe";

  @override
  void initState() {
    super.initState();

    _bleSub = _ble.messageStream.listen((message) async {
      await _handleBleMessage(message);
    });
  }

  Future<void> _handleBleMessage(SeenBleMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final String userName = (userData['name'] ??
            user.displayName ??
            appLanguage.text(en: 'Unknown User', ar: 'مستخدم غير معروف'))
        .toString();

    final deviceDocId = _ble.connectedDevice?.remoteId.str ?? 'seen_device';
    final String deviceName = message.deviceId ?? 'SEEN Device';

    if (message.type == 'ready' ||
        message.type == 'armed' ||
        message.type == 'pong') {
      _liveDeviceStatus = "Connected";

      await _upsertDevice(
        userId: user.uid,
        deviceDocId: deviceDocId,
        data: {
          'name': deviceName,
          'deviceId': deviceDocId,
          'bleName': _ble.connectedDevice?.platformName ?? deviceName,
          'status': _liveDeviceStatus,
          'source': 'ble',
          'isPaired': true,
          'lastMessageType': message.type,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      );

      await _addDeviceHistory(
        userId: user.uid,
        deviceDocId: deviceDocId,
        eventType: message.type,
        title: 'Device Connected',
        status: 'Uploaded',
        details: 'Device responded successfully over BLE.',
      );

      if (mounted) setState(() {});
      return;
    }

    if (message.type == 'gps') {
      _liveLat = message.lat;
      _liveLng = message.lng;

      await _upsertDevice(
        userId: user.uid,
        deviceDocId: deviceDocId,
        data: {
          'name': deviceName,
          'deviceId': deviceDocId,
          'status': _liveDeviceStatus,
          'location': (message.lat != null && message.lng != null)
              ? '${message.lat}, ${message.lng}'
              : 'Unknown',
          'lat': message.lat,
          'lng': message.lng,
          'gpsFix': message.gpsFix ?? false,
          'sat': message.sat ?? 0,
          'lastMessageType': 'gps',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      );

      await _addDeviceHistory(
        userId: user.uid,
        deviceDocId: deviceDocId,
        eventType: 'gps',
        title: 'GPS Update',
        status: (message.gpsFix ?? false) ? 'Uploaded' : 'Pending',
        details: (message.lat != null && message.lng != null)
            ? 'Lat: ${message.lat}, Lng: ${message.lng}'
            : 'GPS available but no fix yet.',
      );

      if (mounted) setState(() {});
      return;
    }

    if (message.type == 'camera') {
      await _addDeviceHistory(
        userId: user.uid,
        deviceDocId: deviceDocId,
        eventType: 'camera',
        title: 'Camera Capture',
        status: (message.ok ?? false) ? 'Uploaded' : 'Pending',
        details: (message.ok ?? false)
            ? 'Camera captured image successfully.'
            : 'Camera capture failed.',
        meta: {
          'ok': message.ok,
          'bytes': message.bytes,
        },
      );

      await _upsertDevice(
        userId: user.uid,
        deviceDocId: deviceDocId,
        data: {
          'lastMessageType': 'camera',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      );

      return;
    }

    if (message.type == 'mic') {
      await _addDeviceHistory(
        userId: user.uid,
        deviceDocId: deviceDocId,
        eventType: 'mic',
        title: 'Microphone Activity',
        status: (message.ok ?? true) ? 'Uploaded' : 'Pending',
        details: 'Microphone activity detected from device.',
        meta: {
          'ok': message.ok,
          'bytes': message.bytes,
          'level': message.level,
        },
      );

      await _upsertDevice(
        userId: user.uid,
        deviceDocId: deviceDocId,
        data: {
          'lastMessageType': 'mic',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      );

      return;
    }

    if (message.type == 'sos') {
      _liveDeviceStatus = "Emergency";

      final String locationText = (message.lat != null && message.lng != null)
          ? '${message.lat}, ${message.lng}'
          : 'Unknown Location';

      await _upsertDevice(
        userId: user.uid,
        deviceDocId: deviceDocId,
        data: {
          'name': deviceName,
          'deviceId': deviceDocId,
          'status': _liveDeviceStatus,
          'location': locationText,
          'lat': message.lat,
          'lng': message.lng,
          'gpsFix': message.gpsFix ?? false,
          'lastMessageType': 'sos',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      );

      await _addDeviceHistory(
        userId: user.uid,
        deviceDocId: deviceDocId,
        eventType: 'sos',
        title: 'SOS Triggered',
        status: 'Uploaded',
        details: (message.lat != null && message.lng != null)
            ? 'Emergency triggered with location: $locationText'
            : 'Emergency triggered from device.',
        meta: {
          'button': message.button,
          'ts': message.ts,
        },
      );

      final contactIds = await _loadEmergencyContactIds(user.uid);

      final alertRef = await FirebaseFirestore.instance.collection('alerts').add({
        'vulnerableId': user.uid,
        'userId': user.uid,
        'userName': userName,
        'deviceId': deviceDocId,
        'source': 'esp_ble',
        'status': 'Triggered',
        'location': locationText,
        'lat': message.lat,
        'lng': message.lng,
        'gpsFix': message.gpsFix ?? false,
        'triggeredAt': FieldValue.serverTimestamp(),
        'emergencyContactIds': contactIds,
      });

      await _fanOutIncidentToEmergencyContacts(
        vulnerableUserId: user.uid,
        vulnerableUserName: userName,
        alertId: alertRef.id,
        locationText: locationText,
        emergencyContactIds: contactIds,
      );

      if (!mounted) return;
      setState(() {});

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "SOS received from device",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            (message.lat != null && message.lng != null)
                ? "Emergency sent with location: ${message.lat}, ${message.lng}"
                : "Emergency sent from the device.",
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _upsertDevice({
    required String userId,
    required String deviceDocId,
    required Map<String, dynamic> data,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceDocId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> _addDeviceHistory({
    required String userId,
    required String deviceDocId,
    required String eventType,
    required String title,
    required String status,
    required String details,
    Map<String, dynamic>? meta,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceDocId)
        .collection('history')
        .add({
      'eventType': eventType,
      'title': title,
      'status': status,
      'details': details,
      'meta': meta ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> _loadEmergencyContactIds(String vulnerableUserId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(vulnerableUserId)
        .collection('contacts')
        .get();

    final ids = <String>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final candidates = [
        data['contactUserId'],
        data['uid'],
        data['userId'],
        data['contactId'],
        doc.id,
      ];

      for (final candidate in candidates) {
        final value = candidate?.toString();
        if (value != null && value.isNotEmpty && !ids.contains(value)) {
          ids.add(value);
          break;
        }
      }
    }

    return ids;
  }

  Future<void> _fanOutIncidentToEmergencyContacts({
    required String vulnerableUserId,
    required String vulnerableUserName,
    required String alertId,
    required String locationText,
    required List<String> emergencyContactIds,
  }) async {
    final nowText = DateTime.now().toString();

    for (final ecUid in emergencyContactIds) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ecUid)
          .collection('linkedUsers')
          .doc(vulnerableUserId)
          .set({
        'name': vulnerableUserName,
        'status': 'Alert',
        'lastUpdate': nowText,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(ecUid)
          .collection('incidents')
          .add({
        'alertId': alertId,
        'title': 'Emergency Alert',
        'status': 'Triggered',
        'location': locationText,
        'vulnerableId': vulnerableUserId,
        'userName': vulnerableUserName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void startEmergencyCountdown() {
    setState(() {
      isCountingDown = true;
      countdown = 5;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => countdown--);

      if (countdown == 0) {
        t.cancel();
        triggerEmergency();
      }
    });
  }

  void cancelEmergency() {
    timer?.cancel();
    setState(() => isCountingDown = false);
  }

  Future<void> triggerEmergency() async {
    final lang = appLanguage;
    setState(() => isCountingDown = false);

    try {
      if (_ble.isConnected) {
        await _ble.sendCommand("ARM");
        await _ble.sendCommand("GET_GPS");

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              lang.text(
                en: "Emergency Request Sent",
                ar: "تم إرسال طلب الطوارئ",
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              lang.text(
                en: "Your device has been asked to send the latest status.",
                ar: "تم طلب آخر حالة من الجهاز.",
              ),
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  lang.text(en: "OK", ar: "حسنًا"),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final userData = userDoc.data() ?? {};
          final userName = (userData['name'] ??
                  user.displayName ??
                  appLanguage.text(en: 'Unknown User', ar: 'مستخدم غير معروف'))
              .toString();

          final contactIds = await _loadEmergencyContactIds(user.uid);

          final alertRef =
              await FirebaseFirestore.instance.collection('alerts').add({
            'vulnerableId': user.uid,
            'userId': user.uid,
            'userName': userName,
            'deviceId': null,
            'source': 'app',
            'status': 'Triggered',
            'location': 'Unknown Location',
            'lat': null,
            'lng': null,
            'gpsFix': false,
            'triggeredAt': FieldValue.serverTimestamp(),
            'emergencyContactIds': contactIds,
          });

          await _fanOutIncidentToEmergencyContacts(
            vulnerableUserId: user.uid,
            vulnerableUserName: userName,
            alertId: alertRef.id,
            locationText: 'Unknown Location',
            emergencyContactIds: contactIds,
          );
        }

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              lang.text(
                en: "Emergency Alert Sent",
                ar: "تم إرسال تنبيه الطوارئ",
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              lang.text(
                en: "Your emergency contacts have been notified from the app.",
                ar: "تم إخطار جهات اتصال الطوارئ من التطبيق.",
              ),
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  lang.text(en: "OK", ar: "حسنًا"),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("BLE error: $e")),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _bleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(lang.text(en: "Not logged in", ar: "غير مسجل الدخول")),
        ),
      );
    }

    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : lang.text(en: "there", ar: "");

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.text(en: "Good morning", ar: "صباح الخير"),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lang.text(
                en: "Stay safe, $displayName",
                ar: "ابقَ بأمان، $displayName",
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .snapshots(),
        builder: (context, snapshot) {
          final bool hasDevice =
              snapshot.hasData && snapshot.data!.docs.isNotEmpty;

          final deviceData = hasDevice
              ? snapshot.data!.docs.first.data() as Map<String, dynamic>
              : null;

          final String deviceName = (deviceData?['name'] ??
                  lang.text(en: "No Device Paired", ar: "لا يوجد جهاز مقترن"))
              .toString();

          final String deviceStatus =
              (deviceData?['status'] ?? _liveDeviceStatus).toString();

          final int batteryLevel = deviceData?['battery'] ?? 0;

          final String lastKnownPlace = (deviceData?['location'] ??
                  ((_liveLat != null && _liveLng != null)
                      ? '$_liveLat, $_liveLng'
                      : lang.text(en: "Unknown", ar: "غير معروف")))
              .toString();

          final bool isSafe = deviceStatus.toLowerCase() == "safe" ||
              deviceStatus.toLowerCase() == "connected";

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasDevice)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.device_unknown_rounded,
                          color: AppColors.textPrimary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            lang.text(
                              en: "No device paired yet. Go to the Device tab to pair your SEEN necklace.",
                              ar: "لم يتم اقتران أي جهاز بعد. انتقل إلى تبويب الجهاز لاقتران قلادة SEEN.",
                            ),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasDevice)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceLocationScreen(
                            deviceName: deviceName,
                            lat: _liveLat,
                            lng: _liveLng,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.sensors_rounded,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.text(
                                        en: "Device Status",
                                        ar: "حالة الجهاز",
                                      ),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSafe
                                            ? AppColors.successSoft
                                            : AppColors.dangerSoft,
                                        borderRadius:
                                            BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        deviceStatus,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isSafe
                                              ? AppColors.success
                                              : AppColors.emergencyRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (batteryLevel > 0)
                                Text(
                                  "$batteryLevel%",
                                  style: TextStyle(
                                    color: batteryLevel > 20
                                        ? AppColors.success
                                        : AppColors.emergencyRed,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            deviceName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _miniInfoCard(
                                  icon: Icons.battery_charging_full_rounded,
                                  label: lang.text(
                                    en: "Battery",
                                    ar: "البطارية",
                                  ),
                                  value: "$batteryLevel%",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _miniInfoCard(
                                  icon: Icons.location_on_outlined,
                                  label: lang.text(
                                    en: "Location",
                                    ar: "الموقع",
                                  ),
                                  value: (_liveLat != null && _liveLng != null)
                                      ? lang.text(en: "Available", ar: "متوفر")
                                      : lang.text(en: "Live", ar: "مباشر"),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    lastKnownPlace,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: !isCountingDown
                        ? GestureDetector(
                            key: const ValueKey('sos_button'),
                            onTap: startEmergencyCountdown,
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.emergencyRed,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.emergencyRed.withOpacity(0.25),
                                    blurRadius: 30,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "SOS",
                                    style: TextStyle(
                                      fontSize: 34,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lang.text(
                                      en: "Tap to alert",
                                      ar: "اضغط للتنبيه",
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            key: const ValueKey('countdown_card'),
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.dangerSoft,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.emergencyRed.withOpacity(0.15),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "$countdown",
                                  style: const TextStyle(
                                    fontSize: 56,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emergencyRed,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  lang.text(
                                    en: "Sending alert soon...",
                                    ar: "جارٍ إرسال التنبيه...",
                                  ),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.emergencyRed,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  lang.text(
                                    en: "Your emergency contacts will be notified.",
                                    ar: "سيتم إخطار جهات اتصال الطوارئ الخاصة بك.",
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                OutlinedButton(
                                  onPressed: cancelEmergency,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.emergencyRed,
                                    side: const BorderSide(
                                      color: AppColors.emergencyRed,
                                    ),
                                  ),
                                  child: Text(
                                    lang.text(en: "Cancel", ar: "إلغاء"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  lang.text(en: "Quick Actions", ar: "الإجراءات السريعة"),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _actionCard(
                        context,
                        icon: Icons.map_outlined,
                        title: lang.text(
                          en: "View Location",
                          ar: "عرض الموقع",
                        ),
                        subtitle: lang.text(
                          en: "Track in real time",
                          ar: "تتبع في الوقت الفعلي",
                        ),
                        onTap: hasDevice
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DeviceLocationScreen(
                                      deviceName: deviceName,
                                      lat: _liveLat,
                                      lng: _liveLng,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _actionCard(
                        context,
                        icon: Icons.history_rounded,
                        title: lang.text(
                          en: "View History",
                          ar: "عرض السجل",
                        ),
                        subtitle: lang.text(
                          en: "Device activity",
                          ar: "نشاط الجهاز",
                        ),
                        onTap: hasDevice
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DeviceHistoryScreen(
                                      deviceName: deviceName,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _miniInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.textPrimary, size: 20),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
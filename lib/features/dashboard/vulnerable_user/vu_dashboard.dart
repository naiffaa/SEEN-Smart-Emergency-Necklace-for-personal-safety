import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import '../../devices/device_history_screen.dart';
import '../../devices/device_location_screen.dart';
import '../../devices/models/seen_ble_message.dart';
import '../../devices/services/ble_sync_service.dart';
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
  Timer? _statusTimer;

  final SeenBleService _ble = SeenBleService.instance;
  StreamSubscription<SeenBleMessage>? _bleSub;

  double? _liveLat;
  double? _liveLng;
  String _liveDeviceStatus = "Safe";
  String? _lastStreamUrl;

  bool _hasValidCoords(double? lat, double? lng) {
    return lat != null && lng != null && lat != 0 && lng != 0;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  void initState() {
    super.initState();

    BleSyncService.instance.start();
    _bleSub = _ble.messageStream.listen(_handleBleMessageForUi);

    _statusTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!_ble.isConnected) return;
      try {
        await _ble.getBattery();
        await Future.delayed(const Duration(milliseconds: 200));
        await _ble.getGps();
        await Future.delayed(const Duration(milliseconds: 200));
        await _ble.getMic();
      } catch (_) {}
    });
  }

  void _handleBleMessageForUi(SeenBleMessage message) {
    if (!mounted) return;

    if (message.isReady || message.isArmed || message.isPong) {
      setState(() => _liveDeviceStatus = "Connected");
      return;
    }

    if (message.isDisarmed) {
      setState(() => _liveDeviceStatus = "Safe");
      return;
    }

    if (message.isGps) {
      setState(() {
        if (_hasValidCoords(message.lat, message.lng)) {
          _liveLat = message.lat;
          _liveLng = message.lng;
        }
      });
      return;
    }

    if (message.isSos) {
      setState(() {
        _liveDeviceStatus = "Emergency";
        if (_hasValidCoords(message.lat, message.lng)) {
          _liveLat = message.lat;
          _liveLng = message.lng;
        }
        _lastStreamUrl = message.streamUrl;
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            appLanguage.text(
              en: "SOS received from device",
              ar: "تم استلام إشارة SOS من الجهاز",
            ),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            appLanguage.text(
              en: "The alert was sent to your emergency contacts.",
              ar: "تم إرسال التنبيه إلى جهات اتصال الطوارئ.",
            ),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(appLanguage.text(en: "OK", ar: "حسنًا")),
            ),
          ],
        ),
      );
    }
  }

  void startEmergencyCountdown() {
    setState(() {
      isCountingDown = true;
      countdown = 5;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
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
        await _ble.arm();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.text(
                en: "SOS command sent to SEEN device.",
                ar: "تم إرسال أمر SOS إلى جهاز SEEN.",
              ),
            ),
          ),
        );
      } else {
        await _createAppOnlyAlert();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.text(
                en: "Emergency alert sent from the app.",
                ar: "تم إرسال تنبيه الطوارئ من التطبيق.",
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Emergency error: $e")),
      );
    }
  }

  Future<void> _createAppOnlyAlert() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final userName =
        (userData['name'] ?? user.displayName ?? 'Unknown User').toString();
    final contactIds = await _loadEmergencyContactIds(user.uid);

    await FirebaseFirestore.instance.collection('alerts').add({
      'vulnerableId': user.uid,
      'userId': user.uid,
      'userName': userName,
      'source': 'app',
      'status': 'Triggered',
      'location': 'Unknown Location',
      'lat': null,
      'lng': null,
      'gpsFix': false,
      'triggeredAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'durationSeconds': 60,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 1))),
      'emergencyContactIds': contactIds,
      'streamStatus': 'unavailable',
      'streamUrl': null,
      'audioEnabled': false,
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

  @override
  void dispose() {
    timer?.cancel();
    _statusTimer?.cancel();
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
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnapshot) {
          final userData = userSnapshot.data?.data() ?? {};

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('devices')
                .snapshots(),
            builder: (context, snapshot) {
              final hasDevice = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              final deviceDoc = hasDevice ? snapshot.data!.docs.first : null;
              final deviceData =
                  hasDevice ? deviceDoc!.data() as Map<String, dynamic> : null;

              final deviceId = deviceDoc?.id ?? userData['pairedDeviceId']?.toString();

              final deviceName = (deviceData?['name'] ??
                      userData['pairedDeviceName'] ??
                      lang.text(en: "No Device Paired", ar: "لا يوجد جهاز مقترن"))
                  .toString();

              final deviceStatus = _ble.isConnected
                  ? "Connected"
                  : (deviceData?['status'] ?? userData['status'] ?? _liveDeviceStatus)
                      .toString();

              final batteryLevel =
                  _toInt(deviceData?['battery'] ?? userData['battery']);

              final lat = _toDouble(userData['lat']) ??
                  _toDouble(deviceData?['lat']) ??
                  _liveLat;
              final lng = _toDouble(userData['lng']) ??
                  _toDouble(deviceData?['lng']) ??
                  _liveLng;

              final hasLocation = _hasValidCoords(lat, lng);
              final locationText = hasLocation
                  ? "${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}"
                  : lang.text(en: "Waiting GPS...", ar: "بانتظار GPS...");

              final isSafe = deviceStatus.toLowerCase() == "safe" ||
                  deviceStatus.toLowerCase() == "connected";

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasDevice) _noDeviceCard(lang),
                    if (hasDevice)
                      _deviceStatusCard(
                        context: context,
                        theme: theme,
                        lang: lang,
                        deviceName: deviceName,
                        deviceStatus: deviceStatus,
                        batteryLevel: batteryLevel,
                        locationText: locationText,
                        hasLocation: hasLocation,
                        isSafe: isSafe,
                        lat: lat,
                        lng: lng,
                        userId: user.uid,
                      ),
                    const SizedBox(height: 24),
                    _sosButton(lang),
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
                            icon: Icons.map_outlined,
                            title: lang.text(en: "Location", ar: "الموقع"),
                            subtitle: hasLocation
                                ? lang.text(en: "Open live map", ar: "فتح الخريطة")
                                : lang.text(en: "Waiting GPS", ar: "بانتظار GPS"),
                            onTap: hasDevice
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DeviceLocationScreen(
                                          deviceName: deviceName,
                                          lat: hasLocation ? lat : null,
                                          lng: hasLocation ? lng : null,
                                          userId: user.uid,
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
                            icon: Icons.history_rounded,
                            title: lang.text(en: "Evidence", ar: "الأدلة"),
                            subtitle: lang.text(
                              en: "Audio & stream history",
                              ar: "سجل الصوت والبث",
                            ),
                            onTap: hasDevice
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DeviceHistoryScreen(
                                          deviceName: deviceName,
                                          deviceId: deviceId,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if ((_lastStreamUrl ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _streamCard(lang, _lastStreamUrl!),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _noDeviceCard(dynamic lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.device_unknown_rounded, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lang.text(
                en: "No device paired yet. Go to the Device tab to pair your SEEN necklace.",
                ar: "لم يتم اقتران أي جهاز بعد. انتقل إلى تبويب الجهاز لاقتران قلادة SEEN.",
              ),
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceStatusCard({
    required BuildContext context,
    required ThemeData theme,
    required dynamic lang,
    required String deviceName,
    required String deviceStatus,
    required int batteryLevel,
    required String locationText,
    required bool hasLocation,
    required bool isSafe,
    required double? lat,
    required double? lng,
    required String userId,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                icon: Icons.sensors_rounded,
                color: isSafe ? AppColors.success : AppColors.emergencyRed,
                bg: isSafe ? AppColors.successSoft : AppColors.dangerSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  deviceName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _statusPill(
                text: deviceStatus,
                isSafe: isSafe,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _cleanMetric(
                  icon: Icons.battery_charging_full_rounded,
                  label: lang.text(en: "Battery", ar: "البطارية"),
                  value: "$batteryLevel%",
                  color: batteryLevel > 20
                      ? AppColors.success
                      : AppColors.emergencyRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _cleanMetric(
                  icon: hasLocation
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_not_fixed_rounded,
                  label: lang.text(en: "GPS", ar: "GPS"),
                  value: hasLocation
                      ? lang.text(en: "Fixed", ar: "ثابت")
                      : lang.text(en: "Waiting", ar: "انتظار"),
                  color: hasLocation
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeviceLocationScreen(
                    deviceName: deviceName,
                    lat: hasLocation ? lat : null,
                    lng: hasLocation ? lng : null,
                    userId: userId,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    hasLocation
                        ? Icons.location_on_rounded
                        : Icons.location_searching_rounded,
                    color: hasLocation
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      locationText,
                      style: TextStyle(
                        color: hasLocation
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sosButton(dynamic lang) {
    return Center(
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
                        color: AppColors.emergencyRed.withOpacity(0.25),
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
                        lang.text(en: "Tap to alert", ar: "اضغط للتنبيه"),
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
                ),
                child: Column(
                  children: [
                    Text(
                      "$countdown",
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emergencyRed,
                      ),
                    ),
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
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: cancelEmergency,
                      child: Text(lang.text(en: "Cancel", ar: "إلغاء")),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _streamCard(dynamic lang, String url) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.text(en: "Latest Camera Stream", ar: "آخر بث كاميرا"),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            url,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _iconBox({
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _statusPill({
    required String text,
    required bool isSafe,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSafe ? AppColors.successSoft : AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isSafe ? AppColors.success : AppColors.emergencyRed,
        ),
      ),
    );
  }

  Widget _cleanMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
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
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 24),
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
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
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/colors.dart';
import '../../main.dart';
import '../devices/services/seen_ble_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _isSending = false;

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

  Future<void> _createAppAlert(User user) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final String userName = (userData['name'] ??
            user.displayName ??
            appLanguage.text(en: 'Unknown User', ar: 'مستخدم غير معروف'))
        .toString();

    final contactIds = await _loadEmergencyContactIds(user.uid);

    final alertRef = await FirebaseFirestore.instance.collection('alerts').add({
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

  Future<void> _triggerSOS() async {
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You are not logged in.")),
          );
        }
        return;
      }

      final ble = SeenBleService.instance;

      if (ble.isConnected) {
        await ble.sendCommand("ARM");
        await ble.sendCommand("GET_GPS");

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("SOS sent to device via BLE")),
        );
      } else {
        await _createAppAlert(user);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("SOS sent from app 🚨")),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return Scaffold(
      backgroundColor: AppColors.emergencyRed,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _isSending ? null : () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: GestureDetector(
                    onTap: _isSending ? null : _triggerSOS,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isSending
                            ? const SizedBox(
                                height: 34,
                                width: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppColors.emergencyRed,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'SOS',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.emergencyRed,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tap to send',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.emergencyRed,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _isSending
                    ? lang.text(
                        en: "Sending emergency alert...",
                        ar: "جارٍ إرسال تنبيه الطوارئ...",
                      )
                    : lang.text(
                        en: "Emergency SOS",
                        ar: "طوارئ SOS",
                      ),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isSending
                    ? lang.text(
                        en: "Your emergency alert is being sent to the system.",
                        ar: "يتم الآن إرسال تنبيه الطوارئ إلى النظام.",
                      )
                    : lang.text(
                        en: "Tap the SOS button to instantly send an emergency alert.",
                        ar: "اضغط زر SOS لإرسال تنبيه طوارئ فورًا.",
                      ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  height: 1.6,
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        lang.text(
                          en: "Use this only in emergencies. Your alert will be marked as active immediately.",
                          ar: "استخدم هذا فقط في حالات الطوارئ. سيتم تفعيل التنبيه فورًا.",
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          height: 1.5,
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
    );
  }
}
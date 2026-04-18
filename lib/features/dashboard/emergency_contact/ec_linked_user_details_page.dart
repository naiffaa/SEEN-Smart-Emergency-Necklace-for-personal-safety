import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import '../../devices/device_history_screen.dart';
import '../../devices/device_location_screen.dart';

class ECLinkedUserDetailsPage extends StatelessWidget {
  final Map<String, dynamic> user;

  const ECLinkedUserDetailsPage({
    super.key,
    required this.user,
  });

  Future<void> _callUser(BuildContext context, String phone) async {
    final lang = appLanguage;

    if (phone.trim().isEmpty || phone.trim() == "-") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "No phone number available.",
              ar: "لا يوجد رقم هاتف متاح.",
            ),
          ),
        ),
      );
      return;
    }

    final Uri uri = Uri.parse('tel:$phone');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Could not open the dialer.",
              ar: "تعذر فتح تطبيق الاتصال.",
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String vulnerableUserUid = (user["uid"] ?? "").toString();
    final status = (user["status"] ?? "Safe").toString();
    final bool isAlert = status == "Alert";
    final theme = Theme.of(context);
    final lang = appLanguage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          lang.text(en: "User Details", ar: "تفاصيل المستخدم"),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(vulnerableUserUid)
            .collection('devices')
            .snapshots(),
        builder: (context, snapshot) {
          Map<String, dynamic>? deviceData;
          String deviceId = "-";

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            deviceData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
            deviceId = snapshot.data!.docs.first.id;
          }

          final String deviceName = (deviceData?['name'] ??
                  lang.text(en: "No Device", ar: "لا يوجد جهاز"))
              .toString();

          final String location =
              (deviceData?['location'] ?? user["location"] ?? "-").toString();

          final int battery = deviceData?['battery'] is num
              ? (deviceData!['battery'] as num).toInt()
              : (user["battery"] is num ? (user["battery"] as num).toInt() : 0);

          final double? lat =
              deviceData?['lat'] is num ? (deviceData!['lat'] as num).toDouble() : null;

          final double? lng =
              deviceData?['lng'] is num ? (deviceData!['lng'] as num).toDouble() : null;

          final String phone = (user["phone"] ?? "-").toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isAlert
                          ? AppColors.emergencyRed.withOpacity(0.3)
                          : AppColors.border,
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
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isAlert
                              ? AppColors.dangerSoft
                              : AppColors.surfaceSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: isAlert
                              ? AppColors.emergencyRed
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (user["name"] ?? "").toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${user["relation"] ?? lang.text(en: "Linked User", ar: "مستخدم مرتبط")} • $deviceName",
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${lang.text(en: "Last update", ar: "آخر تحديث")}: ${user["lastUpdate"] ?? lang.text(en: "Unknown", ar: "غير معروف")}",
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isAlert
                              ? AppColors.dangerSoft
                              : AppColors.successSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAlert
                              ? lang.text(en: "Alert", ar: "تنبيه")
                              : lang.text(en: "Safe", ar: "آمن"),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isAlert
                                ? AppColors.emergencyRed
                                : AppColors.success,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _infoTile(
                  label: lang.text(en: "Device ID", ar: "معرّف الجهاز"),
                  value: deviceId,
                ),
                _infoTile(
                  label: lang.text(en: "Phone", ar: "الهاتف"),
                  value: phone,
                ),
                _infoTile(
                  label: lang.text(en: "Location", ar: "الموقع"),
                  value: location,
                ),
                _infoTile(
                  label: lang.text(en: "Battery", ar: "البطارية"),
                  value: battery > 0 ? "$battery%" : "-",
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _callUser(context, phone),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emergencyRed,
                    ),
                    icon: const Icon(Icons.call, color: Colors.white),
                    label: Text(lang.text(en: "Call", ar: "اتصال")),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceLocationScreen(
                          deviceName: deviceName,
                          lat: lat,
                          lng: lng,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.location_on, color: Colors.white),
                    label: Text(
                      lang.text(
                        en: "View Live Location",
                        ar: "عرض الموقع المباشر",
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceHistoryScreen(
                          deviceName: deviceName,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                    ),
                    icon: const Icon(Icons.history, color: Colors.white),
                    label: Text(
                      lang.text(en: "View History", ar: "عرض السجل"),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile({
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
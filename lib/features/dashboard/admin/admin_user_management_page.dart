import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import 'admin_user_details_page.dart';

class AdminUserManagementPage extends StatelessWidget {
  const AdminUserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          lang.text(
            en: "User Management",
            ar: "إدارة المستخدمين",
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                lang.text(
                  en: "Something went wrong.",
                  ar: "حدث خطأ ما.",
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                lang.text(
                  en: "No users found.",
                  ar: "لم يتم العثور على مستخدمين.",
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                lang.text(
                  en: "View and manage all users in the system.",
                  ar: "عرض وإدارة جميع المستخدمين في النظام.",
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['uid'] = doc.id;
                return _userTile(context, data);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _userTile(BuildContext context, Map<String, dynamic> user) {
    final lang = appLanguage;

    final String uid = (user["uid"] ?? "").toString();
    final String rawRole = (user["role"] ?? "").toString();

    final String displayRole = rawRole == "vulnerableUser"
        ? lang.text(en: "Vulnerable User", ar: "مستخدم معرّض للخطر")
        : rawRole == "emergencyContact"
            ? lang.text(en: "Emergency Contact", ar: "جهة اتصال للطوارئ")
            : rawRole == "admin"
                ? lang.text(en: "Admin", ar: "مشرف")
                : rawRole;

    final String status = (user["status"] ?? "Active").toString();
    final bool isActive = status == "Active";

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('devices')
          .limit(1)
          .get(),
      builder: (context, deviceSnapshot) {
        Map<String, dynamic>? deviceData;
        String deviceId = "N/A";

        if (deviceSnapshot.hasData && deviceSnapshot.data!.docs.isNotEmpty) {
          deviceData =
              deviceSnapshot.data!.docs.first.data() as Map<String, dynamic>;
          deviceId = deviceSnapshot.data!.docs.first.id;
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('alerts')
              .where('userId', isEqualTo: uid)
              .get(),
          builder: (context, alertsSnapshot) {
            final int alertsCount = alertsSnapshot.hasData
                ? alertsSnapshot.data!.docs.length
                : 0;

            final String lastLogin = _formatLastLogin(
              user["lastLogin"],
              lang,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive
                      ? AppColors.border
                      : AppColors.emergencyRed.withOpacity(0.35),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color:
                        isActive ? AppColors.surfaceSoft : AppColors.dangerSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.emergencyRed,
                  ),
                ),
                title: Text(
                  (user["name"] ?? lang.text(en: "Unknown", ar: "غير معروف"))
                      .toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    displayRole,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _statusChip(status),
                    const SizedBox(height: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminUserDetailsPage(
                        user: {
                          "uid": uid,
                          "name": user["name"] ?? "",
                          "role": displayRole,
                          "email": user["email"] ?? "",
                          "phone": user["phone"] ?? "",
                          "status": status,
                          "deviceId": deviceId,
                          "deviceName": deviceData?["name"] ?? "N/A",
                          "deviceStatus": deviceData?["status"] ?? "N/A",
                          "location": deviceData?["location"] ?? "N/A",
                          "battery": deviceData?["battery"] ?? 0,
                          "lastLogin": lastLogin,
                          "alerts": alertsCount,
                          "age": user["age"] ?? "",
                          "gender": user["gender"] ?? "",
                        },
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatLastLogin(dynamic value, dynamic lang) {
    if (value is Timestamp) {
      final dt = value.toDate();
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }

    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }

    return lang.text(en: "N/A", ar: "غير متوفر");
  }

  Widget _statusChip(String status) {
    final lang = appLanguage;
    final bool isActive = status == "Active";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successSoft : AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive
            ? lang.text(en: "Active", ar: "نشط")
            : lang.text(en: "Inactive", ar: "غير نشط"),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isActive ? AppColors.success : AppColors.emergencyRed,
        ),
      ),
    );
  }
}
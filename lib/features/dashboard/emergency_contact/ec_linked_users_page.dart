import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import 'ec_linked_user_details_page.dart';

class ECLinkedUsersPage extends StatelessWidget {
  const ECLinkedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final lang = appLanguage;

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(lang.text(en: "Not logged in", ar: "غير مسجل الدخول")),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          lang.text(en: "Linked Users", ar: "المستخدمون المرتبطون"),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('linkedUsers')
            .orderBy('linkedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final linkedDocs = snapshot.data?.docs ?? [];

          if (linkedDocs.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  lang.text(
                    en: "No linked users found",
                    ar: "لم يتم العثور على مستخدمين مرتبطين",
                  ),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            itemCount: linkedDocs.length,
            itemBuilder: (context, index) {
              final linkedUser =
                  linkedDocs[index].data() as Map<String, dynamic>;
              final linkedUserUid = linkedDocs[index].id;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(linkedUserUid)
                    .collection('devices')
                    .snapshots(),
                builder: (context, deviceSnapshot) {
                  Map<String, dynamic>? deviceData;
                  if (deviceSnapshot.hasData &&
                      deviceSnapshot.data!.docs.isNotEmpty) {
                    deviceData = deviceSnapshot.data!.docs.first.data()
                        as Map<String, dynamic>;
                  }

                  final String status =
                      _getUserStatus(deviceData, linkedUser["status"]);

                  final String lastUpdate = _formatLastUpdate(
                    deviceData?["updatedAt"] ?? deviceData?["lastSeenAt"],
                    lang,
                  );

                  final String relation = (linkedUser["relation"] ??
                          linkedUser["relationship"] ??
                          lang.text(en: "Linked User", ar: "مستخدم مرتبط"))
                      .toString();

                  final userData = {
                    "uid": linkedUserUid,
                    "name": (linkedUser["name"] ??
                            lang.text(en: "Unknown User", ar: "مستخدم غير معروف"))
                        .toString(),
                    "phone": (linkedUser["phone"] ?? "").toString(),
                    "relation": relation,
                    "status": status,
                    "lastUpdate": lastUpdate,
                    "deviceId": deviceSnapshot.hasData &&
                            deviceSnapshot.data!.docs.isNotEmpty
                        ? deviceSnapshot.data!.docs.first.id
                        : "-",
                    "location": (deviceData?["location"] ??
                            lang.text(
                              en: "Unknown Location",
                              ar: "موقع غير معروف",
                            ))
                        .toString(),
                    "battery": (deviceData?["battery"] ?? 0),
                  };

                  final bool isAlert = status == "Alert";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      leading: Container(
                        width: 46,
                        height: 46,
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
                      title: Text(
                        userData["name"],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "$relation • $lastUpdate",
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      trailing: _statusChip(status, lang),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ECLinkedUserDetailsPage(user: userData),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static Widget _statusChip(String status, dynamic lang) {
    final bool isAlert = status == "Alert";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isAlert ? AppColors.dangerSoft : AppColors.successSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAlert
            ? lang.text(en: "Alert", ar: "تنبيه")
            : lang.text(en: "Safe", ar: "آمن"),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isAlert ? AppColors.emergencyRed : AppColors.success,
          fontSize: 12,
        ),
      ),
    );
  }

  static String _getUserStatus(
    Map<String, dynamic>? deviceData,
    dynamic fallbackStatus,
  ) {
    final deviceStatus = (deviceData?["status"] ?? "").toString().toLowerCase();
    if (deviceStatus == "alert" ||
        deviceStatus == "triggered" ||
        deviceStatus == "emergency") {
      return "Alert";
    }

    final fallback = (fallbackStatus ?? "").toString().toLowerCase();
    if (fallback == "alert" ||
        fallback == "triggered" ||
        fallback == "emergency") {
      return "Alert";
    }

    return "Safe";
  }

  static String _formatLastUpdate(dynamic updatedAt, dynamic lang) {
    if (updatedAt is! Timestamp) {
      return lang.text(en: "Unknown", ar: "غير معروف");
    }

    final diff = DateTime.now().difference(updatedAt.toDate());

    if (diff.inSeconds < 60) {
      return lang.text(en: "Just now", ar: "الآن");
    }
    if (diff.inMinutes < 60) {
      return lang.text(
        en: "${diff.inMinutes} min ago",
        ar: "منذ ${diff.inMinutes} دقيقة",
      );
    }
    if (diff.inHours < 24) {
      return lang.text(
        en: "${diff.inHours} hr ago",
        ar: "منذ ${diff.inHours} ساعة",
      );
    }

    return lang.text(
      en: "${diff.inDays} day ago",
      ar: "منذ ${diff.inDays} يوم",
    );
  }
}
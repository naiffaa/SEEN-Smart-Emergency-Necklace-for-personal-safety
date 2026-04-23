import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import 'ec_linked_user_details_page.dart';

class ECDashboard extends StatelessWidget {
  const ECDashboard({super.key});

  bool _isActiveAlertStatus(String status) {
    return status == "Triggered" || status == "Acknowledged";
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final lang = appLanguage;

    if (currentUser == null) {
      return Center(
        child: Text(lang.text(en: "Not logged in", ar: "غير مسجل الدخول")),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.text(en: "Emergency Contact", ar: "جهة اتصال الطوارئ"),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lang.text(
                en: "Monitor linked users and alerts",
                ar: "مراقبة المستخدمين المرتبطين والتنبيهات",
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('linkedUsers')
            .snapshots(),
        builder: (context, linkedSnapshot) {
          if (linkedSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (linkedSnapshot.hasError) {
            return Center(
              child: Text(
                lang.text(en: "Something went wrong.", ar: "حدث خطأ ما."),
              ),
            );
          }

          final linkedDocs = linkedSnapshot.data?.docs ?? [];
          final linkedUserIds = linkedDocs.map((doc) => doc.id).toList();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('alerts')
                .where('emergencyContactId', isEqualTo: currentUser.uid)
                .where('status', whereIn: ['Triggered', 'Acknowledged'])
                .snapshots(),
            builder: (context, alertsSnapshot) {
              if (alertsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final activeAlertDocs = alertsSnapshot.data?.docs ?? [];

              final Map<String, Map<String, dynamic>> activeAlertsByUser = {};
              for (final doc in activeAlertDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final vulnerableUid =
                    (data['userId'] ?? data['vulnerableUserId'] ?? '')
                        .toString();
                if (vulnerableUid.isNotEmpty) {
                  activeAlertsByUser[vulnerableUid] = data;
                }
              }

              final bool hasAlert = activeAlertsByUser.isNotEmpty;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasAlert) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.emergencyRed.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.emergencyRed,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                lang.text(
                                  en: "Active Emergency Alert!",
                                  ar: "تنبيه طوارئ نشط!",
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emergencyRed,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      lang.text(
                        en: "Linked Vulnerable Individuals",
                        ar: "الأفراد المرتبطون",
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (linkedDocs.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          lang.text(
                            en: "No linked users yet.",
                            ar: "لا يوجد مستخدمون مرتبطون بعد.",
                          ),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: linkedDocs.length,
                        itemBuilder: (context, index) {
                          final doc = linkedDocs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final String vulnerableUid = doc.id;
                          final bool isAlert = activeAlertsByUser.containsKey(
                            vulnerableUid,
                          );

                          final String name =
                              (data["name"] ??
                                      lang.text(en: "Unknown", ar: "غير معروف"))
                                  .toString();

                          final String relation = (data["relation"] ?? "")
                              .toString();

                          final String lastUpdate =
                              (data["lastUpdate"] ??
                                      lang.text(en: "Unknown", ar: "غير معروف"))
                                  .toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
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
                                  Icons.person_rounded,
                                  color: isAlert
                                      ? AppColors.emergencyRed
                                      : AppColors.textPrimary,
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "$relation • ${lang.text(en: "Last update", ar: "آخر تحديث")}: $lastUpdate",
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isAlert
                                      ? AppColors.dangerSoft
                                      : AppColors.successSoft,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  isAlert
                                      ? lang.text(en: "Alert", ar: "تنبيه")
                                      : lang.text(en: "Safe", ar: "آمن"),
                                  style: TextStyle(
                                    color: isAlert
                                        ? AppColors.emergencyRed
                                        : AppColors.success,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              onTap: () async {
                                final vuDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(vulnerableUid)
                                    .get();

                                final vuData = vuDoc.data() ?? {};

                                if (!context.mounted) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ECLinkedUserDetailsPage(
                                      user: {
                                        "uid": vulnerableUid,
                                        "name": name,
                                        "relation": relation,
                                        "status": isAlert ? "Alert" : "Safe",
                                        "lastUpdate": lastUpdate,
                                        "phone": vuData["phone"] ?? "-",
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 26),
                    Text(
                      lang.text(en: "Recent Incidents", ar: "الحوادث الأخيرة"),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .collection('incidents')
                          .orderBy('createdAt', descending: true)
                          .limit(5)
                          .snapshots(),
                      builder: (context, incidentSnapshot) {
                        if (!incidentSnapshot.hasData ||
                            incidentSnapshot.data!.docs.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.history_rounded,
                                  color: AppColors.textPrimary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    lang.text(
                                      en: "No incidents yet",
                                      ar: "لا توجد حوادث بعد",
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: incidentSnapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final incident =
                                incidentSnapshot.data!.docs[index].data()
                                    as Map<String, dynamic>;

                            final Timestamp? createdAt =
                                incident["createdAt"] as Timestamp?;
                            final DateTime? dt = createdAt?.toDate();

                            final String when = dt == null
                                ? lang.text(
                                    en: "Unknown time",
                                    ar: "وقت غير معروف",
                                  )
                                : "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.history_rounded,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                title: Text(
                                  (incident["title"] ??
                                          lang.text(
                                            en: "Incident",
                                            ar: "حادثة",
                                          ))
                                      .toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "${(incident["status"] ?? "").toString()} • $when",
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

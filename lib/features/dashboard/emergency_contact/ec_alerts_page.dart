import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import 'ec_alert_details_page.dart';

class ECAlertsPage extends StatelessWidget {
  const ECAlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final lang = appLanguage;

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(
            lang.text(en: "Not logged in", ar: "غير مسجل الدخول"),
          ),
        ),
      );
    }

    final alertsStream = FirebaseFirestore.instance
        .collection('alerts')
        .where('emergencyContactIds', arrayContains: currentUser.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          lang.text(en: "Alerts", ar: "التنبيهات"),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: alertsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                lang.text(
                  en: "Firestore error:\n${snapshot.error}",
                  ar: "خطأ في قاعدة البيانات:\n${snapshot.error}",
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Text(
                lang.text(en: "No alerts found", ar: "لا توجد تنبيهات"),
              ),
            );
          }

          final sortedDocs = [...docs];
          sortedDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aTime = aData['triggeredAt'];
            final bTime = bData['triggeredAt'];

            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }
            return 0;
          });

          final activeAlerts = sortedDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['status'] ?? '') == 'Triggered';
          }).toList();

          final historyAlerts = sortedDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['status'] ?? '') != 'Triggered';
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.text(en: "Active Alerts", ar: "التنبيهات النشطة"),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                if (activeAlerts.isEmpty)
                  _emptyCard(
                    lang.text(
                      en: "No active alerts",
                      ar: "لا توجد تنبيهات نشطة",
                    ),
                  )
                else
                  ...activeAlerts.map((doc) => _buildAlertCard(context, doc)),
                const SizedBox(height: 26),
                Text(
                  lang.text(en: "History", ar: "السجل"),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                if (historyAlerts.isEmpty)
                  _emptyCard(
                    lang.text(
                      en: "No alert history",
                      ar: "لا يوجد سجل تنبيهات",
                    ),
                  )
                else
                  ...historyAlerts.map((doc) => _buildAlertCard(context, doc)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, QueryDocumentSnapshot doc) {
    final lang = appLanguage;
    final alert = doc.data() as Map<String, dynamic>;

    final String userName = (alert['userName'] ??
            lang.text(en: 'Unknown User', ar: 'مستخدم غير معروف'))
        .toString();

    final String location = (alert['location'] ??
            lang.text(en: 'Unknown Location', ar: 'موقع غير معروف'))
        .toString();

    final String status = (alert['status'] ?? 'Triggered').toString();

    final timestamp = alert['triggeredAt'];
    DateTime? dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    }

    final String formattedTime = dateTime != null
        ? "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(dateTime).format(context)}"
        : lang.text(en: 'Unknown Time', ar: 'وقت غير معروف');

    final bool isAlert = status == "Triggered";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ECAlertDetailsPage(
              alertId: doc.id,
              alert: alert,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isAlert ? AppColors.dangerSoft : AppColors.surfaceSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAlert ? Icons.warning_amber_rounded : Icons.history,
                color:
                    isAlert ? AppColors.emergencyRed : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$location • $formattedTime",
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
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
                color: _statusBg(status),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _localizedStatus(status, lang),
                style: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  String _localizedStatus(String status, dynamic lang) {
    switch (status) {
      case "Triggered":
        return lang.text(en: "Triggered", ar: "مُطلَق");
      case "Acknowledged":
        return lang.text(en: "Acknowledged", ar: "تم الاستلام");
      case "Resolved":
        return lang.text(en: "Resolved", ar: "محلول");
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Triggered":
        return AppColors.emergencyRed;
      case "Acknowledged":
        return Colors.orange;
      case "Resolved":
        return AppColors.success;
      default:
        return AppColors.textPrimary;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case "Triggered":
        return AppColors.dangerSoft;
      case "Acknowledged":
        return Colors.orange.withOpacity(0.1);
      case "Resolved":
        return AppColors.successSoft;
      default:
        return AppColors.surfaceSoft;
    }
  }
}
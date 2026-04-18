import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import 'admin_report_details_page.dart';

class AdminAlertReportsPage extends StatelessWidget {
  const AdminAlertReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final startOfWeek = startOfToday.subtract(
          Duration(days: now.weekday - 1),
        );
        final startOfMonth = DateTime(now.year, now.month, 1);

        int dailyTotal = 0, dailyResolved = 0, dailyPending = 0;
        int weeklyTotal = 0, weeklyResolved = 0, weeklyPending = 0;
        int monthlyTotal = 0, monthlyResolved = 0, monthlyPending = 0;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();
          final ts = data['triggeredAt'];
          DateTime? dt;
          if (ts is Timestamp) dt = ts.toDate();
          if (dt == null) continue;

          final isResolved = status == 'Resolved';
          final isPending = status == 'Triggered' || status == 'Acknowledged';

          if (!dt.isBefore(startOfToday)) {
            dailyTotal++;
            if (isResolved)
              dailyResolved++;
            else if (isPending)
              dailyPending++;
          }
          if (!dt.isBefore(startOfWeek)) {
            weeklyTotal++;
            if (isResolved)
              weeklyResolved++;
            else if (isPending)
              weeklyPending++;
          }
          if (!dt.isBefore(startOfMonth)) {
            monthlyTotal++;
            if (isResolved)
              monthlyResolved++;
            else if (isPending)
              monthlyPending++;
          }
        }

        final reports = [
          {
            "title": lang.text(
              en: "Daily Alerts Report",
              ar: "تقرير التنبيهات اليومية",
            ),
            "description": lang.text(
              en: "Overview of all alerts triggered today.",
              ar: "نظرة عامة على جميع التنبيهات التي حدثت اليوم.",
            ),
            "total": dailyTotal,
            "resolved": dailyResolved,
            "pending": dailyPending,
          },
          {
            "title": lang.text(
              en: "Weekly System Report",
              ar: "تقرير النظام الأسبوعي",
            ),
            "description": lang.text(
              en: "System activity and alert trends for this week.",
              ar: "نشاط النظام واتجاهات التنبيهات لهذا الأسبوع.",
            ),
            "total": weeklyTotal,
            "resolved": weeklyResolved,
            "pending": weeklyPending,
          },
          {
            "title": lang.text(
              en: "Monthly Safety Report",
              ar: "تقرير السلامة الشهري",
            ),
            "description": lang.text(
              en: "Summary of safety alerts and user activity.",
              ar: "ملخص التنبيهات الأمنية ونشاط المستخدمين.",
            ),
            "total": monthlyTotal,
            "resolved": monthlyResolved,
            "pending": monthlyPending,
          },
        ];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              lang.text(en: "Alert Reports", ar: "تقارير التنبيهات"),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminReportDetailsPage(
                                title: report["title"] as String,
                                description: report["description"] as String,
                                totalAlerts: report["total"] as int,
                                resolvedAlerts: report["resolved"] as int,
                                pendingAlerts: report["pending"] as int,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(18),
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
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.insert_chart_outlined_rounded,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      report["title"] as String,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      report["description"] as String,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "${lang.text(en: "Total", ar: "الإجمالي")}: ${report["total"]}   •   "
                                      "${lang.text(en: "Resolved", ar: "تم الحل")}: ${report["resolved"]}   •   "
                                      "${lang.text(en: "Pending", ar: "معلّق")}: ${report["pending"]}",
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        final bool isLoading =
            usersSnapshot.connectionState == ConnectionState.waiting;

        final List<QueryDocumentSnapshot> userDocs =
            usersSnapshot.data?.docs ?? [];

        final int totalUsers = userDocs.length;

        final List<QueryDocumentSnapshot> vulnerableUsers = userDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] == 'vulnerableUser';
        }).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
          builder: (context, alertsSnapshot) {
            final List<QueryDocumentSnapshot> alertDocs =
                alertsSnapshot.data?.docs ?? [];

            final int activeAlerts = alertDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['status'] ?? '').toString() == 'Triggered';
            }).length;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('devices')
                  .snapshots(),
              builder: (context, devicesSnapshot) {
                final List<QueryDocumentSnapshot> deviceDocs =
                    devicesSnapshot.data?.docs ?? [];

                final int totalDevices = deviceDocs.length;

                final int onlineDevices = deviceDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  return status == 'connected' ||
                      status == 'safe' ||
                      status == 'emergency';
                }).length;

                final int offlineDevices =
                    totalDevices >= onlineDevices ? totalDevices - onlineDevices : 0;

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
                          lang.text(
                            en: "Admin Dashboard",
                            ar: "لوحة تحكم المشرف",
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lang.text(
                            en: "System overview and monitoring",
                            ar: "نظرة عامة على النظام والمراقبة",
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (activeAlerts > 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.dangerSoft,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppColors.emergencyRed.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.emergencyRed,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    lang.text(
                                      en: "$activeAlerts Active Emergency Alerts!",
                                      ar: "$activeAlerts تنبيهات طوارئ نشطة!",
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.emergencyRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildStatCard(
                              label: lang.text(
                                en: "Total Users",
                                ar: "إجمالي المستخدمين",
                              ),
                              value: isLoading ? "..." : totalUsers.toString(),
                              icon: Icons.people_alt_rounded,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              label: lang.text(
                                en: "Active Alerts",
                                ar: "التنبيهات النشطة",
                              ),
                              value: alertsSnapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? "..."
                                  : activeAlerts.toString(),
                              icon: Icons.warning_amber_rounded,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              label: lang.text(
                                en: "Devices",
                                ar: "الأجهزة",
                              ),
                              value: devicesSnapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? "..."
                                  : totalDevices.toString(),
                              icon: Icons.sensors_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.text(
                                  en: "Device Status",
                                  ar: "حالة الأجهزة",
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _statusIndicator(
                                      lang.text(
                                        en: "Online",
                                        ar: "متصل",
                                      ),
                                      devicesSnapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? 0
                                          : onlineDevices,
                                      AppColors.success,
                                      AppColors.successSoft,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _statusIndicator(
                                      lang.text(
                                        en: "Offline",
                                        ar: "غير متصل",
                                      ),
                                      devicesSnapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? 0
                                          : offlineDevices,
                                      AppColors.emergencyRed,
                                      AppColors.dangerSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.text(
                                  en: "System Health",
                                  ar: "حالة النظام",
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _healthRow(
                                lang.text(
                                  en: "Server",
                                  ar: "الخادم",
                                ),
                                lang.text(
                                  en: "Connected",
                                  ar: "متصل",
                                ),
                              ),
                              _healthRow(
                                lang.text(
                                  en: "Database",
                                  ar: "قاعدة البيانات",
                                ),
                                usersSnapshot.hasError ||
                                        alertsSnapshot.hasError ||
                                        devicesSnapshot.hasError
                                    ? lang.text(
                                        en: "Error",
                                        ar: "خطأ",
                                      )
                                    : lang.text(
                                        en: "Active",
                                        ar: "نشطة",
                                      ),
                                isError: usersSnapshot.hasError ||
                                    alertsSnapshot.hasError ||
                                    devicesSnapshot.hasError,
                              ),
                              _healthRow(
                                lang.text(
                                  en: "Vulnerable Users",
                                  ar: "المستخدمون المعرضون للخطر",
                                ),
                                isLoading
                                    ? "..."
                                    : vulnerableUsers.length.toString(),
                              ),
                              _healthRow(
                                lang.text(
                                  en: "Last Sync",
                                  ar: "آخر مزامنة",
                                ),
                                lang.text(
                                  en: "Live",
                                  ar: "مباشر",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  static Widget _healthRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isError ? AppColors.emergencyRed : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statusIndicator(
    String label,
    int value,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 5,
            backgroundColor: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$label: $value",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
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
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
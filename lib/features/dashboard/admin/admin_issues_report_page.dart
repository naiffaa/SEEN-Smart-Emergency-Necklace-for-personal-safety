import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import 'admin_issue_details_page.dart';

class AdminIssuesReportPage extends StatelessWidget {
  const AdminIssuesReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            lang.text(en: "Issues Reports", ar: "تقارير المشكلات"),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  tabs: [
                    _IssuesTab(
                      status: 'Pending',
                      labelEn: 'Pending',
                      labelAr: 'معلقة',
                      activeColor: AppColors.emergencyRed,
                    ),
                    _IssuesTab(
                      status: 'Resolved',
                      labelEn: 'Resolved',
                      labelAr: 'محلولة',
                      activeColor: AppColors.success,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _IssuesList(status: 'Pending'),
            _IssuesList(status: 'Resolved'),
          ],
        ),
      ),
    );
  }
}

class _IssuesTab extends StatelessWidget {
  final String status;
  final String labelEn;
  final String labelAr;
  final Color activeColor;

  const _IssuesTab({
    required this.status,
    required this.labelEn,
    required this.labelAr,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final lang = appLanguage;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('issues')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        final label = lang.text(en: labelEn, ar: labelAr);

        return Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: activeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IssuesList extends StatelessWidget {
  final String status;

  const _IssuesList({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('issues')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              lang.text(
                en: "Something went wrong while loading issues.",
                ar: "حدث خطأ أثناء تحميل المشكلات.",
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        // sort by submittedAt client-side to avoid needing a composite index
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = aData['submittedAt'];
          final bTs = bData['submittedAt'];
          if (aTs is Timestamp && bTs is Timestamp) {
            return bTs.compareTo(aTs);
          }
          return 0;
        });

        if (docs.isEmpty) {
          final isPending = status == 'Pending';
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPending ? Icons.hourglass_empty : Icons.task_alt,
                  size: 64,
                  color: AppColors.textSecondary.withOpacity(0.35),
                ),
                const SizedBox(height: 14),
                Text(
                  isPending
                      ? lang.text(
                          en: "No pending issues.",
                          ar: "لا توجد مشكلات معلقة.",
                        )
                      : lang.text(
                          en: "No resolved issues.",
                          ar: "لا توجد مشكلات محلولة.",
                        ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final title = data['title'] as String? ?? 'No Title';
            final description = data['description'] as String? ?? '';
            final email = data['userEmail'] as String? ?? '';
            final currentStatus = data['status'] as String? ?? 'Pending';
            final ts = data['submittedAt'];

            String dateStr = '';
            if (ts is Timestamp) {
              final dt = ts.toDate();
              dateStr =
                  "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
            }

            final isResolved = currentStatus == 'Resolved';
            final badgeColor = isResolved
                ? AppColors.success
                : AppColors.emergencyRed;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminIssueDetailsPage(issueId: doc.id),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isResolved
                              ? Icons.check_circle_outline
                              : Icons.report_problem_outlined,
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    currentStatus,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                if (dateStr.isNotEmpty)
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

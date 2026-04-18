import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';

class AdminIssuesReportPage extends StatelessWidget {
  const AdminIssuesReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    // TODO: Replace this with a real Firestore stream when ready.
    // stream: FirebaseFirestore.instance.collection('issues').snapshots()
    final List<Map<String, dynamic>> issues = [];

    return Scaffold(
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
      ),
      body: issues.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: AppColors.textSecondary.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.text(
                      en: "No issues reported yet.",
                      ar: "لم يتم الإبلاغ عن أي مشكلات حتى الآن.",
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              itemCount: issues.length,
              itemBuilder: (context, index) {
                final issue = issues[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
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
                            Icons.report_problem_outlined,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issue["title"] as String? ?? "Issue",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                issue["description"] as String? ?? "",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
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
            ),
    );
  }
}

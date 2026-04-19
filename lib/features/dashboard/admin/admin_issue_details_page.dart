import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';

class AdminIssueDetailsPage extends StatefulWidget {
  final String issueId;

  const AdminIssueDetailsPage({super.key, required this.issueId});

  @override
  State<AdminIssueDetailsPage> createState() => _AdminIssueDetailsPageState();
}

class _AdminIssueDetailsPageState extends State<AdminIssueDetailsPage> {
  bool _isUpdating = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('issues')
          .doc(widget.issueId)
          .update({'status': newStatus});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appLanguage.text(
              en: "Status updated successfully",
              ar: "تم تحديث الحالة بنجاح",
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Update issue status error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appLanguage.text(
              en: "Failed to update status",
              ar: "فشل تحديث الحالة",
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

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
          lang.text(en: "Issue Details", ar: "تفاصيل المشكلة"),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('issues')
            .doc(widget.issueId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                lang.text(
                  en: "Failed to load issue details.",
                  ar: "فشل تحميل تفاصيل المشكلة.",
                ),
              ),
            );
          }

          if (!snapshot.hasData ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return Center(
              child: Text(
                lang.text(
                  en: "This issue no longer exists.",
                  ar: "هذه المشكلة لم تعد موجودة.",
                ),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final title = data['title'] as String? ?? 'No Title';
          final description = data['description'] as String? ?? '';
          final email = data['userEmail'] as String? ?? '';
          final userId = data['userId'] as String? ?? '';
          final status = data['status'] as String? ?? 'Pending';
          final ts = data['submittedAt'];

          String dateStr = '';
          if (ts is Timestamp) {
            final dt = ts.toDate();
            dateStr =
                "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} "
                "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
          }

          final isResolved = status == 'Resolved';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _infoRow(
                        label: lang.text(en: "Status", ar: "الحالة"),
                        value: status,
                        valueColor: isResolved
                            ? AppColors.success
                            : AppColors.emergencyRed,
                      ),
                      _infoRow(
                        label: lang.text(en: "User Email", ar: "بريد المستخدم"),
                        value: email.isEmpty ? '-' : email,
                      ),
                      _infoRow(
                        label: lang.text(en: "User ID", ar: "معرف المستخدم"),
                        value: userId.isEmpty ? '-' : userId,
                      ),
                      _infoRow(
                        label: lang.text(
                          en: "Submitted At",
                          ar: "تاريخ الإرسال",
                        ),
                        value: dateStr.isEmpty ? '-' : dateStr,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  lang.text(en: "Update Status", ar: "تحديث الحالة"),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUpdating
                            ? null
                            : () => _updateStatus('Pending'),
                        child: Text(
                          lang.text(en: "Mark as Pending", ar: "تعيين كمعلّق"),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUpdating
                            ? null
                            : () => _updateStatus('Resolved'),
                        child: _isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                lang.text(
                                  en: "Mark as Resolved",
                                  ar: "تعيين كمحلولة",
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor ?? AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

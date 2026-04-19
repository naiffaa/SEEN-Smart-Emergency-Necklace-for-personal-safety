import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/colors.dart';
import '../../main.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isFormValid =>
      _titleController.text.isNotEmpty &&
      _descriptionController.text.isNotEmpty;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_isFormValid) return;
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('issues').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
        'userId': user?.uid ?? 'unknown',
        'userEmail': user?.email ?? 'unknown',
        'status': 'Pending',
      });

      if (!mounted) return;
      final lang = appLanguage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Report submitted successfully",
              ar: "تم إرسال التقرير بنجاح",
            ),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final lang = appLanguage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Failed to submit report. Please try again.",
              ar: "فشل إرسال التقرير. يرجى المحاولة مرة أخرى.",
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        centerTitle: false,
        title: Text(
          lang.text(en: "Report a Problem", ar: "الإبلاغ عن مشكلة"),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.text(
                en: "Let us know what happened and we'll look into it.",
                ar: "أخبرنا بما حدث وسنتابع الأمر.",
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
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
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.flag_outlined,
                      color: AppColors.textPrimary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    lang.text(en: "Submit an Issue", ar: "إرسال مشكلة"),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    lang.text(
                      en: "Share the issue title and a short description so we can help you faster.",
                      ar: "شارك عنوان المشكلة ووصفًا موجزًا حتى نتمكن من مساعدتك بشكل أسرع.",
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildField(
                    context,
                    label: lang.text(en: "Issue Title", ar: "عنوان المشكلة"),
                    controller: _titleController,
                    hint: lang.text(
                      en: "Enter issue title",
                      ar: "أدخل عنوان المشكلة",
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                  _buildField(
                    context,
                    label: lang.text(en: "Description", ar: "الوصف"),
                    controller: _descriptionController,
                    hint: lang.text(
                      en: "Describe the problem in detail...",
                      ar: "صف المشكلة بالتفصيل...",
                    ),
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          lang.text(
                            en: "Attach Screenshot (optional)",
                            ar: "إرفاق لقطة شاشة (اختياري)",
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isFormValid && !_isSubmitting)
                          ? _submitReport
                          : null,
                      child: _isSubmitting
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
                                en: "Submit Report",
                                ar: "إرسال التقرير",
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            alignLabelWithHint: maxLines > 1,
          ),
        ),
      ],
    );
  }
}

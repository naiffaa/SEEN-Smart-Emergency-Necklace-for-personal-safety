import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../main.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

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
          lang.text(en: "Terms & Policies", ar: "الشروط والسياسات"),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                context,
                title: lang.text(en: "1. Introduction", ar: "١. المقدمة"),
                body: lang.text(
                  en: "SEEN is a smart emergency system designed to provide safety and real-time assistance. By using this application, you agree to the terms described below.",
                  ar: "SEEN هو نظام طوارئ ذكي مصمم لتوفير السلامة والمساعدة الفورية. باستخدام هذا التطبيق، فإنك توافق على الشروط الموضحة أدناه.",
                ),
              ),

              _buildSection(
                context,
                title: lang.text(en: "2. Data Collection", ar: "٢. جمع البيانات"),
                body: lang.text(
                  en: "We may collect basic user information such as name, email, phone number, and location data strictly for emergency and safety purposes.",
                  ar: "قد نجمع معلومات المستخدم الأساسية مثل الاسم والبريد الإلكتروني ورقم الهاتف وبيانات الموقع لأغراض الطوارئ والسلامة فقط.",
                ),
              ),

              _buildSection(
                context,
                title: lang.text(en: "3. Location Tracking", ar: "٣. تتبع الموقع"),
                body: lang.text(
                  en: "Location services are used only when emergency features are activated or when tracking paired devices.",
                  ar: "تُستخدم خدمات الموقع فقط عند تفعيل ميزات الطوارئ أو عند تتبع الأجهزة المقترنة.",
                ),
              ),

              _buildSection(
                context,
                title: lang.text(
                  en: "4. User Responsibility",
                  ar: "٤. مسؤولية المستخدم",
                ),
                body: lang.text(
                  en: "Users are responsible for keeping their account credentials secure and for using the application appropriately.",
                  ar: "يتحمل المستخدمون مسؤولية الحفاظ على أمان بيانات حساباتهم واستخدام التطبيق بشكل مناسب.",
                ),
              ),

              _buildSection(
                context,
                title: lang.text(en: "5. Updates", ar: "٥. التحديثات"),
                body: lang.text(
                  en: "SEEN may update these terms at any time. Continued use of the app means you accept the updated terms.",
                  ar: "قد يقوم SEEN بتحديث هذه الشروط في أي وقت. الاستمرار في استخدام التطبيق يعني قبولك للشروط المحدّثة.",
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
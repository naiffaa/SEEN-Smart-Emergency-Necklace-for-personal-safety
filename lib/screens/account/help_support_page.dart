import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../main.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

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
          lang.text(en: "Help & Support", ar: "المساعدة والدعم"),
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
                en: "Find answers to common questions and ways to contact support.",
                ar: "اعثر على إجابات للأسئلة الشائعة وطرق التواصل مع الدعم.",
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            _sectionTitle(
              context,
              lang.text(
                en: "Frequently Asked Questions",
                ar: "الأسئلة الشائعة",
              ),
            ),
            const SizedBox(height: 12),

            _buildFAQCard(
              context,
              lang.text(en: "How does SEEN work?", ar: "كيف يعمل تطبيق SEEN؟"),
              lang.text(
                en: "SEEN connects your smart device to provide emergency alerts, real-time location tracking, and instant notifications to saved contacts.",
                ar: "يربط SEEN جهازك الذكي لتوفير تنبيهات الطوارئ وتتبع الموقع في الوقت الفعلي وإشعارات فورية لجهات الاتصال المحفوظة.",
              ),
            ),

            _buildFAQCard(
              context,
              lang.text(
                en: "How do I add a device?",
                ar: "كيف أضيف جهازًا؟",
              ),
              lang.text(
                en: "Go to the dashboard, tap the '+' icon, and follow the pairing instructions.",
                ar: "انتقل إلى لوحة التحكم، اضغط على أيقونة '+'، واتبع تعليمات الاقتران.",
              ),
            ),

            _buildFAQCard(
              context,
              lang.text(
                en: "How does emergency alert work?",
                ar: "كيف يعمل تنبيه الطوارئ؟",
              ),
              lang.text(
                en: "When the emergency button is pressed, SEEN sends your location and alert message to your saved contacts instantly.",
                ar: "عند الضغط على زر الطوارئ، يرسل SEEN موقعك ورسالة التنبيه إلى جهات الاتصال المحفوظة فورًا.",
              ),
            ),

            const SizedBox(height: 24),

            _sectionTitle(
              context,
              lang.text(en: "Contact Support", ar: "تواصل مع الدعم"),
            ),
            const SizedBox(height: 12),

            _buildContactCard(
              icon: Icons.email_outlined,
              title: lang.text(en: "Email Support", ar: "الدعم عبر البريد"),
              subtitle: "support@seenapp.com",
            ),

            _buildContactCard(
              icon: Icons.phone_outlined,
              title: lang.text(en: "Phone Support", ar: "الدعم الهاتفي"),
              subtitle: "+966 500 000 000",
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildFAQCard(BuildContext context, String question, String answer) {
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
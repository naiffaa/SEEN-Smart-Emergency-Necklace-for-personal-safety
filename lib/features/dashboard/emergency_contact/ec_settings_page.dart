import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_settings_scaffold.dart';
import '../../../../main.dart';
import '../../../../screens/account/edit_profile_page.dart';
import '../../../../screens/account/language_page.dart';
import '../../../../screens/account/terms_page.dart';
import '../../../../screens/account/help_support_page.dart';
import '../../../../screens/account/report_problem_page.dart';
import '../../onboarding/home_screen.dart';

class ECSettingsPage extends StatelessWidget {
  const ECSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return AppSettingsScaffold(
      title: lang.text(en: "Settings", ar: "الإعدادات"),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.text(
                      en: "Manage your profile, support options, and preferences.",
                      ar: "إدارة ملفك الشخصي وخيارات الدعم والتفضيلات.",
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  _sectionTitle(context, lang.text(en: "Account", ar: "الحساب")),
                  const SizedBox(height: 12),

                  _tile(
                    icon: Icons.person_outline_rounded,
                    title: lang.text(en: "Edit Profile", ar: "تعديل الملف الشخصي"),
                    subtitle: lang.text(
                      en: "Update your personal information",
                      ar: "تحديث معلوماتك الشخصية",
                    ),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const EditProfilePage())),
                  ),

                  _tile(
                    icon: Icons.language_rounded,
                    title: lang.text(en: "Language", ar: "اللغة"),
                    subtitle: lang.text(
                      en: "Choose your preferred language",
                      ar: "اختر لغتك المفضلة",
                    ),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LanguagePage())),
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(
                    context,
                    lang.text(en: "Support & About", ar: "الدعم وحول التطبيق"),
                  ),
                  const SizedBox(height: 12),

                  _tile(
                    icon: Icons.description_outlined,
                    title: lang.text(en: "Terms & Policies", ar: "الشروط والسياسات"),
                    subtitle: lang.text(
                      en: "Read terms, privacy, and policies",
                      ar: "قراءة الشروط والخصوصية والسياسات",
                    ),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TermsPage())),
                  ),

                  _tile(
                    icon: Icons.help_outline_rounded,
                    title: lang.text(en: "Help & Support", ar: "المساعدة والدعم"),
                    subtitle: lang.text(
                      en: "Get assistance and support",
                      ar: "احصل على المساعدة والدعم",
                    ),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HelpSupportPage())),
                  ),

                  _tile(
                    icon: Icons.flag_outlined,
                    title: lang.text(en: "Report a Problem", ar: "الإبلاغ عن مشكلة"),
                    subtitle: lang.text(
                      en: "Tell us if something is not working",
                      ar: "أخبرنا إذا كان هناك شيء لا يعمل",
                    ),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ReportProblemPage())),
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(
                    context,
                    lang.text(en: "Actions", ar: "الإجراءات"),
                  ),
                  const SizedBox(height: 12),

                  _tile(
                    icon: Icons.logout_rounded,
                    title: lang.text(en: "Log Out", ar: "تسجيل الخروج"),
                    subtitle: lang.text(
                      en: "Sign out from your account",
                      ar: "تسجيل الخروج من حسابك",
                    ),
                    isRed: true,
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final lang = appLanguage;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          lang.text(en: "Log Out", ar: "تسجيل الخروج"),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          lang.text(
            en: "Are you sure you want to log out?",
            ar: "هل أنت متأكد أنك تريد تسجيل الخروج؟",
          ),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              lang.text(en: "Cancel", ar: "إلغاء"),
              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.text(en: "Log Out", ar: "تسجيل الخروج"),
              style: const TextStyle(color: AppColors.emergencyRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
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

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isRed = false,
  }) {
    final Color iconColor = isRed ? AppColors.emergencyRed : AppColors.textPrimary;
    final Color titleColor = isRed ? AppColors.emergencyRed : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: isRed ? AppColors.dangerSoft : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35)),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16,
          color: isRed ? AppColors.emergencyRed : AppColors.textSecondary),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/colors.dart';
import '../../main.dart';
import 'edit_profile_page.dart';
import 'language_page.dart';
import 'terms_page.dart';
import 'help_support_page.dart';
import 'report_problem_page.dart';
import '../../features/contacts/contacts_screen.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? name;
  String? email;
  String? role;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      setState(() {
        name = doc['name'];
        email = doc['email'];
        role = doc['role'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = appLanguage;
    final currentUser = FirebaseAuth.instance.currentUser;
    final displayName = name ?? currentUser?.displayName ?? "User";
    final displayEmail = email ?? "";
    final displayRole = role;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Text(
          lang.text(en: "Account", ar: "الحساب"),
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
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 36,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayEmail,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (displayRole != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              displayRole,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _sectionTitle(context, lang.text(en: "Account", ar: "الحساب")),
            const SizedBox(height: 12),

            _buildItem(
              context,
              icon: Icons.person_outline_rounded,
              title: lang.text(en: "Edit Profile", ar: "تعديل الملف الشخصي"),
              subtitle: lang.text(
                en: "Update your personal information",
                ar: "تحديث معلوماتك الشخصية",
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditProfilePage()),
                );
              },
            ),

            _buildItem(
              context,
              icon: Icons.language_rounded,
              title: lang.text(en: "Language", ar: "اللغة"),
              subtitle: lang.text(
                en: "Choose your preferred language",
                ar: "اختر لغتك المفضلة",
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LanguagePage()),
                );
              },
            ),

            const SizedBox(height: 24),

            _sectionTitle(
              context,
              lang.text(en: "Support & About", ar: "الدعم وحول التطبيق"),
            ),
            const SizedBox(height: 12),

            _buildItem(
              context,
              icon: Icons.info_outline_rounded,
              title: lang.text(en: "Terms and Policies", ar: "الشروط والسياسات"),
              subtitle: lang.text(
                en: "Read legal and privacy information",
                ar: "اقرأ المعلومات القانونية والخصوصية",
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TermsPage()),
                );
              },
            ),

            _buildItem(
              context,
              icon: Icons.help_outline_rounded,
              title: lang.text(en: "Help & Support", ar: "المساعدة والدعم"),
              subtitle: lang.text(
                en: "Get help and contact support",
                ar: "احصل على المساعدة وتواصل مع الدعم",
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpSupportPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            _sectionTitle(
              context,
              lang.text(en: "Actions", ar: "الإجراءات"),
            ),
            const SizedBox(height: 12),

            _buildItem(
              context,
              icon: Icons.flag_outlined,
              title: lang.text(en: "Report A Problem", ar: "الإبلاغ عن مشكلة"),
              subtitle: lang.text(
                en: "Tell us if something is wrong",
                ar: "أخبرنا إذا كان هناك شيء خاطئ",
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportProblemPage(),
                  ),
                );
              },
            ),

            _buildItem(
              context,
              icon: Icons.logout_rounded,
              title: lang.text(en: "Log Out", ar: "تسجيل الخروج"),
              subtitle: lang.text(
                en: "Sign out from your account",
                ar: "تسجيل الخروج من حسابك",
              ),
              isRed: true,
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    title: Text(
                      lang.text(en: "Log out", ar: "تسجيل الخروج"),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
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
                          lang.text(en: "No", ar: "لا"),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          lang.text(en: "Yes", ar: "نعم"),
                          style: const TextStyle(
                            color: AppColors.emergencyRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true) {
                  await FirebaseAuth.instance.signOut();
                }
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 76,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.home, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
              IconButton(
                icon: const Icon(
                  Icons.group_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContactsScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.person,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {},
              ),
              const Icon(Icons.settings, color: AppColors.primary),
            ],
          ),
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

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isRed = false,
  }) {
    final iconColor = isRed ? AppColors.emergencyRed : AppColors.textPrimary;
    final titleColor = isRed ? AppColors.emergencyRed : AppColors.textPrimary;

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
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isRed ? AppColors.dangerSoft : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: isRed ? AppColors.emergencyRed : AppColors.textSecondary,
        ),
      ),
    );
  }
}
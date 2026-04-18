import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/colors.dart';
import '../../main.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  String selectedGender = 'Female';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        nameController.text = data['name'] ?? '';
        emailController.text = data['email'] ?? user.email ?? '';
        phoneController.text = data['phone'] ?? '';
        selectedGender = data['gender'] ?? 'Female';
      } else {
        emailController.text = user.email ?? '';
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    final lang = appLanguage;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'phone': phoneController.text.trim(),
      'gender': selectedGender,
    }, SetOptions(merge: true));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang.text(en: "Profile Updated ✅", ar: "تم تحديث الملف الشخصي ✅"),
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      lang.isArabic
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      lang.text(en: "Edit Profile", ar: "تعديل الملف الشخصي"),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

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
                      width: 86,
                      height: 86,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      lang.text(en: "Update Profile", ar: "تحديث الملف الشخصي"),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      lang.text(
                        en: "Keep your personal information up to date.",
                        ar: "حافظ على تحديث معلوماتك الشخصية.",
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 28),

                    _buildField(
                      context,
                      lang.text(en: "Full Name", ar: "الاسم الكامل"),
                      nameController,
                      hint: lang.text(
                        en: "Enter your full name",
                        ar: "أدخل اسمك الكامل",
                      ),
                    ),

                    const SizedBox(height: 18),

                    _buildField(
                      context,
                      lang.text(en: "Email", ar: "البريد الإلكتروني"),
                      emailController,
                      enabled: false,
                      hint: lang.text(
                        en: "Email address",
                        ar: "عنوان البريد الإلكتروني",
                      ),
                    ),

                    const SizedBox(height: 18),

                    _buildGenderDropdown(context),

                    const SizedBox(height: 18),

                    _buildField(
                      context,
                      lang.text(en: "Phone Number", ar: "رقم الهاتف"),
                      phoneController,
                      hint: lang.text(
                        en: "Enter your phone number",
                        ar: "أدخل رقم هاتفك",
                      ),
                    ),

                    const SizedBox(height: 26),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        child: Text(
                          lang.text(en: "Save Changes", ar: "حفظ التغييرات"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    bool enabled = true,
    String? hint,
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
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? AppColors.inputFill : AppColors.surfaceSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.text(en: "Gender", ar: "الجنس"),
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedGender,
          items: [
            DropdownMenuItem(
              value: 'Female',
              child: Text(lang.text(en: 'Female', ar: 'أنثى')),
            ),
            DropdownMenuItem(
              value: 'Male',
              child: Text(lang.text(en: 'Male', ar: 'ذكر')),
            ),
            DropdownMenuItem(
              value: 'Prefer not to say',
              child: Text(
                lang.text(en: 'Prefer not to say', ar: 'أفضل عدم الإفصاح'),
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => selectedGender = val);
          },
          decoration: InputDecoration(
            hintText: lang.text(en: "Select gender", ar: "اختر الجنس"),
          ),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
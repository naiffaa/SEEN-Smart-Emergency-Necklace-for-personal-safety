// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';

class AddEmergencyContactScreen extends StatefulWidget {
  const AddEmergencyContactScreen({super.key});

  @override
  State<AddEmergencyContactScreen> createState() =>
      _AddEmergencyContactScreenState();
}

class _AddEmergencyContactScreenState
    extends State<AddEmergencyContactScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController relationController = TextEditingController();

  bool isLoading = false;

  Future<void> _addContact() async {
    final lang = appLanguage;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final relation = relationController.text.trim();

    if (name.isEmpty || email.isEmpty || relation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Please fill all fields",
              ar: "يرجى ملء جميع الحقول",
            ),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.text(en: "User not found", ar: "المستخدم غير موجود"),
            ),
          ),
        );
        return;
      }

      final contactDoc = query.docs.first;
      final contactUid = contactDoc.id;
      final contactData = contactDoc.data();

      if (contactUid == currentUser.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.text(
                en: "You can't add yourself",
                ar: "لا يمكنك إضافة نفسك",
              ),
            ),
          ),
        );
        return;
      }

      final existingContact = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('contacts')
          .doc(contactUid)
          .get();

      if (existingContact.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.text(
                en: "Contact already added",
                ar: "جهة الاتصال مضافة بالفعل",
              ),
            ),
          ),
        );
        return;
      }

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final currentUserData = currentUserDoc.data() ?? {};

      final currentUserName =
          (currentUserData['name'] ?? currentUser.displayName ?? 'Unknown User')
              .toString();

      final currentUserEmail =
          (currentUserData['email'] ?? currentUser.email ?? '').toString();

      final contactName =
          (contactData['name'] ?? name).toString();

      final contactEmail =
          (contactData['email'] ?? email).toString();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('contacts')
          .doc(contactUid)
          .set({
        'name': contactName,
        'email': contactEmail,
        'relation': relation,
        'contactUserId': contactUid,
        'linkedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(contactUid)
          .collection('linkedUsers')
          .doc(currentUser.uid)
          .set({
        'name': currentUserName,
        'email': currentUserEmail,
        'relation': relation,
        'vulnerableUserId': currentUser.uid,
        'status': 'Safe',
        'lastUpdate': 'Just linked',
        'linkedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Contact linked successfully ✅",
              ar: "تم ربط جهة الاتصال بنجاح ✅",
            ),
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(en: "Error: $e", ar: "خطأ: $e"),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    relationController.dispose();
    super.dispose();
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
        centerTitle: true,
        title: Text(
          lang.text(
            en: "Add Emergency Contact",
            ar: "إضافة جهة اتصال طوارئ",
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 38,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    lang.text(
                      en: "Link a Trusted Contact",
                      ar: "ربط جهة اتصال موثوقة",
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    lang.text(
                      en: "Add a person who will be notified during emergencies and linked to your account.",
                      ar: "أضف شخصًا سيتم إخطاره أثناء حالات الطوارئ ويرتبط بحسابك.",
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildField(
                    context,
                    lang.text(en: "Name", ar: "الاسم"),
                    nameController,
                    hint: lang.text(
                      en: "Contact full name",
                      ar: "الاسم الكامل لجهة الاتصال",
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildField(
                    context,
                    lang.text(
                      en: "Emergency Contact Email",
                      ar: "البريد الإلكتروني لجهة الاتصال",
                    ),
                    emailController,
                    hint: "contact@email.com",
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 18),
                  _buildField(
                    context,
                    lang.text(en: "Relationship", ar: "صلة القرابة"),
                    relationController,
                    hint: lang.text(
                      en: "Parent, sibling, spouse...",
                      ar: "أب/أم، أخ/أخت، زوج/زوجة...",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.text(
                        en: "The contact must already have an account in the system with the same email you enter here.",
                        ar: "يجب أن يكون لجهة الاتصال حساب موجود في النظام بنفس البريد الإلكتروني الذي تدخله هنا.",
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _addContact,
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        lang.text(
                          en: "Add Contact",
                          ar: "إضافة جهة اتصال",
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
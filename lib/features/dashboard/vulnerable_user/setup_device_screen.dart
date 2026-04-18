import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';

class SetupDeviceScreen extends StatefulWidget {
  final String deviceId;

  const SetupDeviceScreen({super.key, required this.deviceId});

  @override
  State<SetupDeviceScreen> createState() => _SetupDeviceScreenState();
}

class _SetupDeviceScreenState extends State<SetupDeviceScreen> {
  final TextEditingController nameController = TextEditingController();

  String? selectedContactId;
  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _saveDevice() async {
    final lang = appLanguage;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (nameController.text.trim().isEmpty || selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Please enter a device name and select an emergency contact.",
              ar: "الرجاء إدخال اسم الجهاز واختيار جهة اتصال الطوارئ.",
            ),
          ),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(widget.deviceId)
          .set({
        'name': nameController.text.trim(),
        'contactId': selectedContactId,
        'isSetupComplete': true,
        'isPaired': true,
        'status': 'Connected',
        'updatedAt': FieldValue.serverTimestamp(),
        'setupCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Device setup completed successfully.",
              ar: "تم إكمال إعداد الجهاز بنجاح.",
            ),
          ),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Failed to save device setup.",
              ar: "فشل حفظ إعداد الجهاز.",
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          lang.text(en: "Setup Device", ar: "إعداد الجهاز"),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                      Icons.settings_input_component_rounded,
                      size: 38,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    lang.text(
                      en: "Finalize Device Setup",
                      ar: "إتمام إعداد الجهاز",
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    lang.text(
                      en: "Give your device a name and choose the linked emergency contact.",
                      ar: "أعطِ جهازك اسمًا واختر جهة اتصال الطوارئ المرتبطة.",
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.text(en: "Device Name", ar: "اسم الجهاز"),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: lang.text(
                            en: "Enter device name",
                            ar: "أدخل اسم الجهاز",
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .collection('contacts')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final contacts = snapshot.data!.docs;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.text(
                              en: "Emergency Contact",
                              ar: "جهة اتصال الطوارئ",
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedContactId,
                            hint: Text(
                              lang.text(
                                en: "Select emergency contact",
                                ar: "اختر جهة اتصال الطوارئ",
                              ),
                            ),
                            items: contacts.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(data['name'] ?? 'No name'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedContactId = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: lang.text(
                                en: "Select",
                                ar: "اختر",
                              ),
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
                    },
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveDevice,
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              lang.text(
                                en: "Save Device",
                                ar: "حفظ الجهاز",
                              ),
                            ),
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
                        en: "This step links your paired device to one of your emergency contacts for faster response.",
                        ar: "تربط هذه الخطوة جهازك المقترن بإحدى جهات اتصال الطوارئ للاستجابة الأسرع.",
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
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
}
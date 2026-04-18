import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';

class AdminUserDetailsPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminUserDetailsPage({super.key, required this.user});

  @override
  State<AdminUserDetailsPage> createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends State<AdminUserDetailsPage> {
  late bool isActive;
  bool isSavingStatus = false;
  bool isDeleting = false;

  String get _uid => (widget.user["uid"] ?? "").toString();

  @override
  void initState() {
    super.initState();
    isActive = (widget.user["status"] ?? "Active").toString() == "Active";
  }

  Future<void> _updateAccountStatus(bool value) async {
    final lang = appLanguage;

    if (_uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "User ID is missing.",
              ar: "معرّف المستخدم غير موجود.",
            ),
          ),
        ),
      );
      return;
    }

    setState(() => isSavingStatus = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).set({
        'status': value ? 'Active' : 'Inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() => isActive = value);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: value
                  ? "User account activated."
                  : "User account deactivated.",
              ar: value
                  ? "تم تفعيل حساب المستخدم."
                  : "تم تعطيل حساب المستخدم.",
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Failed to update user status: $e",
              ar: "فشل تحديث حالة المستخدم: $e",
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSavingStatus = false);
      }
    }
  }

  Future<void> _deleteUser() async {
    final lang = appLanguage;

    if (_uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "User ID is missing.",
              ar: "معرّف المستخدم غير موجود.",
            ),
          ),
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          lang.text(
            en: "Delete User",
            ar: "حذف المستخدم",
          ),
        ),
        content: Text(
          lang.text(
            en: "This will remove the user document from Firestore only. It will not delete the Firebase Authentication account.",
            ar: "سيؤدي هذا إلى حذف مستند المستخدم من Firestore فقط. ولن يحذف حساب Firebase Authentication.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              lang.text(en: "Cancel", ar: "إلغاء"),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.text(en: "Delete", ar: "حذف"),
              style: const TextStyle(color: AppColors.emergencyRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isDeleting = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "User document removed from Firestore.",
              ar: "تم حذف مستند المستخدم من Firestore.",
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
            lang.text(
              en: "Failed to delete user: $e",
              ar: "فشل حذف المستخدم: $e",
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isDeleting = false);
      }
    }
  }

  void _showResetPasswordInfo() {
    final lang = appLanguage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang.text(
            en: "Password reset for other users needs backend/admin support. This button is not connected yet.",
            ar: "إعادة تعيين كلمة مرور مستخدم آخر تحتاج backend أو صلاحيات admin. هذا الزر غير مربوط بعد.",
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final theme = Theme.of(context);
    final lang = appLanguage;

    final String deviceName = (user["deviceName"] ?? "N/A").toString();
    final String deviceStatus = (user["deviceStatus"] ?? "N/A").toString();
    final String location = (user["location"] ?? "N/A").toString();
    final int battery = user["battery"] is num ? (user["battery"] as num).toInt() : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          lang.text(
            en: "User Details",
            ar: "تفاصيل المستخدم",
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
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
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (user["name"] ?? "").toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (user["role"] ?? "").toString(),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _infoCard([
              _infoRow(
                lang.text(en: "Email", ar: "البريد الإلكتروني"),
                (user["email"] ?? "-").toString(),
              ),
              _infoRow(
                lang.text(en: "Phone", ar: "رقم الجوال"),
                (user["phone"] ?? "-").toString(),
              ),
              _infoRow(
                lang.text(en: "Device ID", ar: "معرّف الجهاز"),
                (user["deviceId"] ?? "-").toString(),
              ),
              _infoRow(
                lang.text(en: "Device Name", ar: "اسم الجهاز"),
                deviceName,
              ),
              _infoRow(
                lang.text(en: "Device Status", ar: "حالة الجهاز"),
                deviceStatus,
              ),
              _infoRow(
                lang.text(en: "Location", ar: "الموقع"),
                location,
              ),
              _infoRow(
                lang.text(en: "Battery", ar: "البطارية"),
                battery > 0 ? "$battery%" : "-",
              ),
              _infoRow(
                lang.text(en: "Last Login", ar: "آخر تسجيل دخول"),
                (user["lastLogin"] ?? "-").toString(),
              ),
              _infoRow(
                lang.text(en: "Total Alerts", ar: "إجمالي التنبيهات"),
                (user["alerts"] ?? 0).toString(),
              ),
            ]),
            const SizedBox(height: 20),
            _infoCard([
              SwitchListTile(
                value: isActive,
                activeColor: AppColors.primary,
                title: Text(
                  lang.text(
                    en: "Account Active",
                    ar: "الحساب نشط",
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  lang.text(
                    en: "Enable or disable this user",
                    ar: "تفعيل أو تعطيل هذا المستخدم",
                  ),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                onChanged: isSavingStatus ? null : _updateAccountStatus,
              ),
              if (isSavingStatus)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
            ]),
            const SizedBox(height: 20),
            _actionButton(
              label: lang.text(
                en: "Reset Password",
                ar: "إعادة تعيين كلمة المرور",
              ),
              icon: Icons.lock_reset_rounded,
              color: Colors.orange,
              onTap: _showResetPasswordInfo,
            ),
            const SizedBox(height: 12),
            _actionButton(
              label: isDeleting
                  ? lang.text(en: "Deleting...", ar: "جارٍ الحذف...")
                  : lang.text(
                      en: "Delete User",
                      ar: "حذف المستخدم",
                    ),
              icon: Icons.delete_outline_rounded,
              color: AppColors.emergencyRed,
              onTap: isDeleting ? () {} : _deleteUser,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
        ),
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
      ),
    );
  }
}
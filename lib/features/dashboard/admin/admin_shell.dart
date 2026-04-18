import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';
import 'admin_dashboard.dart';
import 'admin_user_management_page.dart';
import 'admin_reports_page.dart';
import 'admin_settings_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const AdminDashboard(),
    const AdminUserManagementPage(),
    const AdminAlertReportsPage(),
    const AdminSettingsPage(),
  ];

  void _onTap(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final lang = appLanguage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            _item(Icons.home_rounded, lang.text(en: "Home", ar: "الرئيسية"), 0),
            _item(
              Icons.people_rounded,
              lang.text(en: "Users", ar: "المستخدمون"),
              1,
            ),
            _item(
              Icons.bar_chart_rounded,
              lang.text(en: "Reports", ar: "التقارير"),
              2,
            ),
            _item(
              Icons.settings_rounded,
              lang.text(en: "Settings", ar: "الإعدادات"),
              3,
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _item(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;

    return BottomNavigationBarItem(
      label: label,
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }
}

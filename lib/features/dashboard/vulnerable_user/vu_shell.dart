import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../contacts/contacts_screen.dart';
import '../../devices/services/ble_sync_service.dart';
import 'pair_device_screen2.dart';
import 'vu_dashboard.dart';
import 'vulnerable_settings_page.dart';

class VUShell extends StatefulWidget {
  const VUShell({super.key});

  @override
  State<VUShell> createState() => _VUShellState();
}

class _VUShellState extends State<VUShell> {
  int _currentIndex = 0;

  final pages = const [
    VUDashboard(),
    PairDeviceScreen(),
    ContactsScreen(),
    VulnerableSettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    BleSyncService.instance.start();
  }

  @override
  void dispose() {
    BleSyncService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = appLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: lang.text(en: "Home", ar: "الرئيسية"),
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.bluetooth_connected_rounded,
                label: lang.text(en: "Device", ar: "الجهاز"),
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.group_rounded,
                label: lang.text(en: "Contacts", ar: "جهات الاتصال"),
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.settings,
                label: lang.text(en: "Settings", ar: "الإعدادات"),
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF9E3E3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected
                    ? const Color(0xFFE53935)
                    : const Color(0xFF7C8494),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFFE53935)
                    : const Color(0xFF7C8494),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
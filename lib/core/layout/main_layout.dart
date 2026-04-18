import 'package:flutter/material.dart';
import '../theme/colors.dart';

class MainLayout extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<Widget> pages;
  final List<BottomNavigationBarItem> items;

  const MainLayout({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.pages,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
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
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            items: items,
          ),
        ),
      ),
    );
  }
}
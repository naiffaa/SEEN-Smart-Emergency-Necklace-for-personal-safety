import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppSettingsScaffold extends StatelessWidget {
  final Widget body;
  final String title;

  const AppSettingsScaffold({
    super.key,
    required this.body,
    this.title = 'Settings',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: body,
        ),
      ),
    );
  }
}
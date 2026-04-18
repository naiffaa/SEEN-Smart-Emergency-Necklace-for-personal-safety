import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../main.dart';
// ignore: unused_import
import 'signup_screen.dart';
import 'signin_screen.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignInScreen(),
                      ),
                    );
                  },
                  child: Text(
                    lang.text(en: 'Sign In', ar: 'تسجيل الدخول'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assests/images/logo.JPG',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                lang.text(en: 'Welcome to SEEN', ar: 'مرحبًا بك في SEEN'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                lang.text(
                  en: 'Your personal safety companion. Stay connected and protected with real-time emergency alerts.',
                  ar: 'رفيقك الشخصي للسلامة. ابقَ متصلًا ومحميًا مع تنبيهات الطوارئ الفورية.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OnboardingScreen(),
                      ),
                    );
                  },
                  child: Text(lang.text(en: 'Get Started', ar: 'ابدأ الآن')),
                ),
              ),

              const SizedBox(height: 14),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: lang.text(
                        en: 'By continuing, you agree to our ',
                        ar: 'بالمتابعة، أنت توافق على ',
                      ),
                    ),
                    TextSpan(
                      text: lang.text(
                        en: 'Terms of Service',
                        ar: 'شروط الخدمة',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
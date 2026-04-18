import 'dart:ui';
import 'package:flutter/material.dart';

import '../../main.dart';
// ignore: unused_import
import 'signin_screen.dart';
import 'signup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  List<Map<String, dynamic>> get pages {
    final lang = appLanguage;
    return [
      {
        "icon": Icons.warning_amber_rounded,
        "title": lang.text(
          en: "SOS Emergency System",
          ar: "نظام طوارئ SOS",
        ),
        "desc": lang.text(
          en: "Instantly alert your emergency contacts with one tap. They will receive your location and status in real-time.",
          ar: "أرسل تنبيهًا فوريًا لجهات اتصال الطوارئ بنقرة واحدة. سيتلقون موقعك وحالتك في الوقت الفعلي.",
        ),
      },
      {
        "icon": Icons.phone_iphone_rounded,
        "title": lang.text(
          en: "Wearable Connection",
          ar: "الاتصال بالجهاز القابل للارتداء",
        ),
        "desc": lang.text(
          en: "Connect your safety wearable device for hands-free emergency alerts when you need them most.",
          ar: "اربط جهازك القابل للارتداء للأمان وأرسل تنبيهات الطوارئ بدون استخدام يديك عند الحاجة.",
        ),
      },
      {
        "icon": Icons.notifications_active_outlined,
        "title": lang.text(
          en: "Real-time Alerts",
          ar: "تنبيهات فورية",
        ),
        "desc": lang.text(
          en: "Receive instant notifications when your loved ones need help. Track their location and respond quickly.",
          ar: "تلقَّ إشعارات فورية عندما يحتاج أحباؤك للمساعدة. تتبع موقعهم واستجب بسرعة.",
        ),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lang = appLanguage;
    final currentPages = pages;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SignUpScreen(),
                    ),
                  );
                },
                child: Text(lang.text(en: "Skip", ar: "تخطي")),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: currentPages.length,
                onPageChanged: (index) {
                  setState(() => currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final page = currentPages[index];

                  return Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.55,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 36,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 30,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  page["icon"] as IconData,
                                  size: 55,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 30),

                              Text(
                                page["title"] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),

                              const SizedBox(height: 16),

                              Text(
                                page["desc"] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                currentPages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentIndex == index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentIndex == index
                        ? Colors.black
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    if (currentIndex == currentPages.length - 1) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignUpScreen(),
                        ),
                      );
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(
                    currentIndex == currentPages.length - 1
                        ? lang.text(en: "Continue", ar: "متابعة")
                        : lang.text(en: "Next", ar: "التالي"),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
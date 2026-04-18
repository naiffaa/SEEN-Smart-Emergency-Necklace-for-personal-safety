import 'package:flutter/material.dart';
import '../devices/device_location_screen.dart';
import '../../core/theme/colors.dart';
import '../../main.dart';

class EmergencyHistoryScreen extends StatelessWidget {
  const EmergencyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      lang.isArabic
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.arrow_back,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lang.text(
                      en: "Emergency History",
                      ar: "سجل الطوارئ",
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  buildIncidentCard(
                    context,
                    title: lang.text(en: "Incident (1)", ar: "حادثة (1)"),
                    device: "Ahmed",
                    date: "27/10/2025",
                    status: "Received",
                    lat: 24.7136,
                    lng: 46.6753,
                  ),
                  buildIncidentCard(
                    context,
                    title: lang.text(en: "Incident (2)", ar: "حادثة (2)"),
                    device: "Noura",
                    date: "10/10/2025",
                    status: "Missed",
                    lat: 24.774265,
                    lng: 46.738586,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildIncidentCard(
    BuildContext context, {
    required String title,
    required String device,
    required String date,
    required String status,
    required double lat,
    required double lng,
  }) {
    final lang = appLanguage;
    final isReceived = status == "Received";

    final localizedStatus = isReceived
        ? lang.text(en: "Received", ar: "تم الاستلام")
        : lang.text(en: "Missed", ar: "لم يُستلم");

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isReceived
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  localizedStatus,
                  style: TextStyle(
                    color: isReceived ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(lang.text(en: "Device: $device", ar: "الجهاز: $device")),
          Text(lang.text(en: "Date: $date", ar: "التاريخ: $date")),

          const SizedBox(height: 12),

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceLocationScreen(
                    deviceName: device,
                    lat: lat,
                    lng: lng,
                  ),
                ),
              );
            },
            child: Text(
              lang.text(en: "View on Map", ar: "عرض على الخريطة"),
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
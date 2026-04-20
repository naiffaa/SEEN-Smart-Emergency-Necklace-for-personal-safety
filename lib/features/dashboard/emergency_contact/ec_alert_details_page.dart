import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';

class ECAlertDetailsPage extends StatefulWidget {
  final String alertId;
  final Map<String, dynamic> alert;

  const ECAlertDetailsPage({
    super.key,
    required this.alertId,
    required this.alert,
  });

  @override
  State<ECAlertDetailsPage> createState() => _ECAlertDetailsPageState();
}

class _ECAlertDetailsPageState extends State<ECAlertDetailsPage> {
  bool isUpdating = false;

  Future<void> _updateStatus(String newStatus) async {
    final lang = appLanguage;
    try {
      setState(() => isUpdating = true);
      await FirebaseFirestore.instance
          .collection('alerts')
          .doc(widget.alertId)
          .update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Alert marked as $newStatus",
              ar: "تم تحديث التنبيه إلى $newStatus",
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
              en: "Failed to update alert: $e",
              ar: "فشل تحديث التنبيه: $e",
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  Future<void> _callUser(String phone) async {
    final lang = appLanguage;
    final cleaned = phone.trim();

    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "No phone number available.",
              ar: "لا يوجد رقم هاتف متاح.",
            ),
          ),
        ),
      );
      return;
    }

    final Uri uri = Uri(scheme: 'tel', path: cleaned);
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Could not open the dialer.",
              ar: "تعذر فتح تطبيق الاتصال.",
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openLiveLocation(double? lat, double? lng) async {
    final lang = appLanguage;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "No valid live location available.",
              ar: "لا يوجد موقع مباشر صالح متاح.",
            ),
          ),
        ),
      );
      return;
    }

    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Could not open Google Maps.",
              ar: "تعذر فتح خرائط Google.",
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openWebStream(String url) async {
    final lang = appLanguage;
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "No stream link available.",
              ar: "لا يوجد رابط بث متاح.",
            ),
          ),
        ),
      );
      return;
    }

    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "Could not open the stream link.",
              ar: "تعذر فتح رابط البث.",
            ),
          ),
        ),
      );
    }
  }

  Future<void> _copyStreamLink(String url) async {
    final lang = appLanguage;
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.text(
              en: "No stream link available.",
              ar: "لا يوجد رابط بث متاح.",
            ),
          ),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang.text(en: "Stream link copied.", ar: "تم نسخ رابط البث."),
        ),
      ),
    );
  }

  String _extractPhone(Map<String, dynamic> alert) {
    final candidates = [
      alert['userPhone'],
      alert['phone'],
      alert['phoneNumber'],
      alert['user_number'],
    ];

    for (final value in candidates) {
      final phone = (value ?? '').toString().trim();
      if (phone.isNotEmpty) return phone;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .doc(widget.alertId)
          .snapshots(),
      builder: (context, alertSnapshot) {
        if (alertSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final latestAlert =
            (alertSnapshot.data?.data() as Map<String, dynamic>?) ??
            widget.alert;

        final String userName =
            (latestAlert["userName"] ??
                    lang.text(en: "Unknown User", ar: "مستخدم غير معروف"))
                .toString();

        final String location =
            (latestAlert["location"] ??
                    lang.text(en: "Unknown Location", ar: "موقع غير معروف"))
                .toString();

        final String status = (latestAlert["status"] ?? "Triggered").toString();

        final String phone = _extractPhone(latestAlert);

        final double? lat = latestAlert["lat"] is num
            ? (latestAlert["lat"] as num).toDouble()
            : null;

        final double? lng = latestAlert["lng"] is num
            ? (latestAlert["lng"] as num).toDouble()
            : null;

        final bool gpsFix = latestAlert["gpsFix"] == true;

        final Timestamp? timestamp = latestAlert["triggeredAt"] as Timestamp?;
        final DateTime? dateTime = timestamp?.toDate();

        final String formattedTime = dateTime != null
            ? "${dateTime.day}/${dateTime.month}/${dateTime.year} ${TimeOfDay.fromDateTime(dateTime).format(context)}"
            : lang.text(en: "Unknown Time", ar: "وقت غير معروف");

        final Color statusColor = _statusColor(status);
        final Color statusBg = _statusBg(status);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('live_sessions')
              .where('alertId', isEqualTo: widget.alertId)
              .limit(1)
              .snapshots(),
          builder: (context, liveSnapshot) {
            Map<String, dynamic>? liveData;
            if (liveSnapshot.hasData && liveSnapshot.data!.docs.isNotEmpty) {
              liveData =
                  liveSnapshot.data!.docs.first.data() as Map<String, dynamic>;
            }

            final String streamUrl =
                (liveData?['streamUrl'] ?? latestAlert['streamUrl'] ?? '')
                    .toString();

            final String streamStatus =
                (liveData?['streamStatus'] ??
                        latestAlert['streamStatus'] ??
                        (streamUrl.isNotEmpty ? 'ready' : 'unavailable'))
                    .toString();

            final bool isLive =
                liveData?['isLive'] == true || streamUrl.isNotEmpty;

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: Text(
                  lang.text(en: "Alert Details", ar: "تفاصيل التنبيه"),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            status == "Resolved"
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            color: statusColor,
                            size: 42,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _localizedStatus(status, lang),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _info(
                            lang.text(en: "User", ar: "المستخدم"),
                            userName,
                          ),
                          _info(
                            lang.text(en: "Location", ar: "الموقع"),
                            location,
                          ),
                          _info(
                            lang.text(en: "Time", ar: "الوقت"),
                            formattedTime,
                          ),
                          _info(
                            lang.text(en: "GPS", ar: "نظام GPS"),
                            gpsFix
                                ? lang.text(en: "Available", ar: "متوفر")
                                : lang.text(en: "Not fixed", ar: "غير مثبت"),
                          ),
                          if (phone.isNotEmpty)
                            _info(lang.text(en: "Phone", ar: "الهاتف"), phone),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.text(en: "Live Stream", ar: "البث المباشر"),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _info(
                            lang.text(en: "Status", ar: "الحالة"),
                            _localizedStreamStatus(streamStatus, lang),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            streamUrl.isNotEmpty
                                ? streamUrl
                                : lang.text(
                                    en: "No live stream link available yet.",
                                    ar: "لا يوجد رابط بث مباشر متاح حتى الآن.",
                                  ),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: streamUrl.isEmpty
                                  ? null
                                  : () => _openWebStream(streamUrl),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(
                                lang.text(
                                  en: "Open Web Stream",
                                  ar: "فتح رابط البث",
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: streamUrl.isEmpty
                                  ? null
                                  : () => _copyStreamLink(streamUrl),
                              icon: const Icon(Icons.link_rounded),
                              label: Text(
                                lang.text(
                                  en: "Copy Stream Link",
                                  ar: "نسخ رابط البث",
                                ),
                              ),
                            ),
                          ),
                          if (isLive && streamUrl.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.successSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                lang.text(
                                  en: "Live stream link is ready.",
                                  ar: "رابط البث المباشر جاهز.",
                                ),
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (status != "Resolved")
                      _actionButton(
                        label: lang.text(
                          en: "Mark as Resolved",
                          ar: "تحديد كمحلول",
                        ),
                        color: AppColors.success,
                        onTap: () => _updateStatus("Resolved"),
                      ),
                    _actionButton(
                      label: lang.text(
                        en: "Call User",
                        ar: "الاتصال بالمستخدم",
                      ),
                      color: AppColors.emergencyRed,
                      onTap: () => _callUser(phone),
                    ),
                    _actionButton(
                      label: lang.text(
                        en: "View Live Location",
                        ar: "عرض الموقع المباشر",
                      ),
                      color: AppColors.primary,
                      onTap: () => _openLiveLocation(lat, lng),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _info(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isUpdating ? null : onTap,
          style: ElevatedButton.styleFrom(backgroundColor: color),
          child: isUpdating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Text(label),
        ),
      ),
    );
  }

  String _localizedStatus(String status, dynamic lang) {
    switch (status) {
      case "Triggered":
        return lang.text(en: "Triggered", ar: "مُطلَق");
      case "Acknowledged":
        return lang.text(en: "Acknowledged", ar: "تم الاستلام");
      case "Resolved":
        return lang.text(en: "Resolved", ar: "محلول");
      default:
        return status;
    }
  }

  String _localizedStreamStatus(String status, dynamic lang) {
    switch (status.toLowerCase()) {
      case "starting":
        return lang.text(en: "Starting", ar: "جارٍ البدء");
      case "ready":
        return lang.text(en: "Ready", ar: "جاهز");
      case "live":
        return lang.text(en: "Live", ar: "مباشر");
      case "ended":
        return lang.text(en: "Ended", ar: "انتهى");
      case "unavailable":
        return lang.text(en: "Unavailable", ar: "غير متاح");
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Triggered":
        return AppColors.emergencyRed;
      case "Acknowledged":
        return Colors.orange;
      case "Resolved":
        return AppColors.success;
      default:
        return AppColors.textPrimary;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case "Triggered":
        return AppColors.dangerSoft;
      case "Acknowledged":
        return Colors.orange.withOpacity(0.1);
      case "Resolved":
        return AppColors.successSoft;
      default:
        return AppColors.surfaceSoft;
    }
  }
}

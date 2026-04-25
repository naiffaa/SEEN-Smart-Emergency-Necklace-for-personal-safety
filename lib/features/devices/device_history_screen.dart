import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';

class DeviceHistoryScreen extends StatefulWidget {
  final String deviceName;
  final String? deviceId;

  const DeviceHistoryScreen({
    super.key,
    required this.deviceName,
    this.deviceId,
  });

  @override
  State<DeviceHistoryScreen> createState() => _DeviceHistoryScreenState();
}

class _DeviceHistoryScreenState extends State<DeviceHistoryScreen> {
  String sortBy = "Newest";
  String statusFilter = "All";

  Future<void> _openUrl(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No audio available.")),
      );
      return;
    }

    final uri = Uri.parse(url.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyText(BuildContext context, String? text) async {
    if (text == null || text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text.trim()));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Audio link copied.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: Text(
                      "${widget.deviceName} Audio History",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (user == null)
              const Expanded(child: Center(child: Text("Not logged in")))
            else
              Expanded(
                child: FutureBuilder<String?>(
                  future: _resolveDeviceId(user.uid),
                  builder: (context, deviceSnapshot) {
                    if (deviceSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final deviceId = deviceSnapshot.data;
                    if (deviceId == null) return _buildEmpty();

                    Query query = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('devices')
                        .doc(deviceId)
                        .collection('history');

                    query = sortBy == "Newest"
                        ? query.orderBy('createdAt', descending: true)
                        : query.orderBy('createdAt', descending: false);

                    return StreamBuilder<QuerySnapshot>(
                      stream: query.snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];

                        // 🔥 فلترة الصوت فقط
                        final audioDocs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final audio =
                              (data['audioUrl'] ?? '').toString().trim();
                          return audio.isNotEmpty;
                        }).toList();

                        if (audioDocs.isEmpty) return _buildEmpty();

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: audioDocs.length,
                          itemBuilder: (context, index) {
                            final data =
                                audioDocs[index].data() as Map<String, dynamic>;
                            return _audioCard(context, data);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _audioCard(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);

    final audioUrl = (data['audioUrl'] ?? '').toString();

    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final dt = ts?.toDate();

    final time = dt == null
        ? "Unknown time"
        : "${dt.hour}:${dt.minute} - ${dt.day}/${dt.month}";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                "Audio Evidence",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(time, style: const TextStyle(color: Colors.grey)),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openUrl(context, audioUrl),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Play Audio"),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _copyText(context, audioUrl),
                icon: const Icon(Icons.copy),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text("No audio evidence yet"),
    );
  }

  Future<String?> _resolveDeviceId(String uid) async {
    if (widget.deviceId != null) return widget.deviceId;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return doc.data()?['pairedDeviceId'];
  }
}

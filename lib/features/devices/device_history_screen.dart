import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

class DeviceHistoryScreen extends StatefulWidget {
  final String deviceName;

  const DeviceHistoryScreen({super.key, required this.deviceName});

  @override
  State<DeviceHistoryScreen> createState() => _DeviceHistoryScreenState();
}

class _DeviceHistoryScreenState extends State<DeviceHistoryScreen> {
  String sortBy = "Newest";
  String statusFilter = "All";

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
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "${widget.deviceName} History",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (user == null)
              const Expanded(
                child: Center(
                  child: Text("Not logged in"),
                ),
              )
            else
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('devices')
                      .where('name', isEqualTo: widget.deviceName)
                      .limit(1)
                      .get(),
                  builder: (context, deviceSnapshot) {
                    if (deviceSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (deviceSnapshot.hasError) {
                      return Center(
                        child: Text("Error: ${deviceSnapshot.error}"),
                      );
                    }

                    if (!deviceSnapshot.hasData ||
                        deviceSnapshot.data!.docs.isEmpty) {
                      return _buildNoDeviceFound();
                    }

                    final deviceDoc = deviceSnapshot.data!.docs.first;
                    final deviceId = deviceDoc.id;

                    Query historyQuery = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('devices')
                        .doc(deviceId)
                        .collection('history');

                    historyQuery = sortBy == "Newest"
                        ? historyQuery.orderBy('createdAt', descending: true)
                        : historyQuery.orderBy('createdAt', descending: false);

                    return StreamBuilder<QuerySnapshot>(
                      stream: historyQuery.snapshots(),
                      builder: (context, historySnapshot) {
                        if (historySnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (historySnapshot.hasError) {
                          return Center(
                            child: Text("Error: ${historySnapshot.error}"),
                          );
                        }

                        final docs = historySnapshot.data?.docs ?? [];

                        final filteredDocs = docs.where((doc) {
                          if (statusFilter == "All") return true;
                          final data = doc.data() as Map<String, dynamic>;
                          return (data['status'] ?? '').toString() ==
                              statusFilter;
                        }).toList();

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                      width: 82,
                                      height: 82,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSoft,
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: const Icon(
                                        Icons.history_rounded,
                                        color: AppColors.textPrimary,
                                        size: 38,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      "Device Activity History",
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "Review real device events captured from your SEEN hardware.",
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textSecondary,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Sort by Date",
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: sortBy,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: "Newest",
                                          child: Text("Newest"),
                                        ),
                                        DropdownMenuItem(
                                          value: "Oldest",
                                          child: Text("Oldest"),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          sortBy = value!;
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        hintText: "Select",
                                      ),
                                      dropdownColor: AppColors.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      "Status",
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: statusFilter,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: "All",
                                          child: Text("All"),
                                        ),
                                        DropdownMenuItem(
                                          value: "Uploaded",
                                          child: Text("Uploaded"),
                                        ),
                                        DropdownMenuItem(
                                          value: "Pending",
                                          child: Text("Pending"),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          statusFilter = value!;
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        hintText: "Select",
                                      ),
                                      dropdownColor: AppColors.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                "Records",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (filteredDocs.isEmpty)
                                _buildEmptyHistoryCard()
                              else
                                ...filteredDocs.map(
                                  (doc) => _buildHistoryCard(
                                    context,
                                    doc.data() as Map<String, dynamic>,
                                  ),
                                ),
                            ],
                          ),
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

  Widget _buildNoDeviceFound() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          "No matching paired device was found for this history screen.",
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: const Row(
        children: [
          Icon(Icons.history_rounded, color: AppColors.textPrimary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "No device history records yet.",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);

    final String title = (data['title'] ?? 'Device Event').toString();
    final String details = (data['details'] ?? '').toString();
    final String status = (data['status'] ?? 'Uploaded').toString();
    final String eventType = (data['eventType'] ?? 'event').toString();
    final Map<String, dynamic> meta =
        (data['meta'] as Map<String, dynamic>?) ?? {};

    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final DateTime? dt = ts?.toDate();

    final String formattedTime = dt == null
        ? "Unknown time"
        : "${dt.year}-${_two(dt.month)}-${_two(dt.day)}  ${_two(dt.hour)}:${_two(dt.minute)}";

    final IconData icon = _eventIcon(eventType);

    final int? bytes = meta['bytes'] is num ? (meta['bytes'] as num).toInt() : null;
    final int? level = meta['level'] is num ? (meta['level'] as num).toInt() : null;

    String extra = details;
    if (bytes != null) {
      extra += extra.isEmpty ? "" : "\n";
      extra += "Bytes: $bytes";
    }
    if (level != null) {
      extra += extra.isEmpty ? "" : "\n";
      extra += "Level: $level";
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _statusBg(status),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: _statusColor(status),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  extra.isEmpty ? "No extra details" : extra,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formattedTime,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusBg(status),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: _statusColor(status),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'sos':
        return Icons.warning_amber_rounded;
      case 'camera':
        return Icons.camera_alt_rounded;
      case 'mic':
        return Icons.mic_rounded;
      case 'gps':
        return Icons.location_on_rounded;
      case 'ready':
      case 'armed':
      case 'pong':
        return Icons.bluetooth_connected_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Uploaded':
        return AppColors.success;
      case 'Pending':
        return AppColors.emergencyRed;
      default:
        return AppColors.textPrimary;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'Uploaded':
        return AppColors.successSoft;
      case 'Pending':
        return AppColors.dangerSoft;
      default:
        return AppColors.surfaceSoft;
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
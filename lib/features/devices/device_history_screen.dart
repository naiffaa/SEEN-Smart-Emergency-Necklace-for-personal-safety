import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingAudioUrl;
  bool _audioLoading = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String url) async {
    if (url.trim().isEmpty) return;

    try {
      setState(() {
        _audioLoading = true;
      });

      if (_playingAudioUrl == url) {
        await _audioPlayer.stop();
        setState(() {
          _playingAudioUrl = null;
          _audioLoading = false;
        });
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));

      setState(() {
        _playingAudioUrl = url;
        _audioLoading = false;
      });
    } catch (e) {
      setState(() {
        _audioLoading = false;
        _playingAudioUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not play audio: $e")),
      );
    }
  }

  Future<void> _openLocation(
    BuildContext context,
    double? lat,
    double? lng,
  ) async {
    if (lat == null || lng == null || lat == 0 || lng == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No GPS location available.")),
      );
      return;
    }

    final url =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyText(
    BuildContext context,
    String? text, {
    String success = "Copied.",
  }) async {
    if (text == null || text.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text.trim()));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success)),
    );
  }

  Future<void> _openVideo(String videoUrl) async {
    if (videoUrl.trim().isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvidenceVideoPlayerPage(videoUrl: videoUrl),
      ),
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
                      "${widget.deviceName} Evidence History",
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
                child: Center(child: Text("Not logged in")),
              )
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

                    if (deviceId == null || deviceId.trim().isEmpty) {
                      return _buildEmpty();
                    }

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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];

                        final evidenceDocs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          final audio =
                              (data['audioUrl'] ?? '').toString().trim();
                          final video =
                              (data['videoUrl'] ?? '').toString().trim();

                          return audio.isNotEmpty || video.isNotEmpty;
                        }).toList();

                        if (evidenceDocs.isEmpty) {
                          return _buildEmpty();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: evidenceDocs.length,
                          itemBuilder: (context, index) {
                            final data = evidenceDocs[index].data()
                                as Map<String, dynamic>;

                            return _evidenceCard(context, data);
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

  Widget _evidenceCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final theme = Theme.of(context);

    final audioUrl = (data['audioUrl'] ?? '').toString().trim();
    final videoUrl = (data['videoUrl'] ?? '').toString().trim();

    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();

    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final dt = ts?.toDate();

    final time = dt == null
        ? "Unknown time"
        : "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}";

    final hasVideo = videoUrl.isNotEmpty;
    final hasAudio = audioUrl.isNotEmpty;
    final hasLocation = lat != null && lng != null && lat != 0 && lng != 0;

    final isPlayingThisAudio = _playingAudioUrl == audioUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              Icon(
                hasVideo ? Icons.videocam_rounded : Icons.mic_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasVideo ? "Audio & Video Evidence" : "Audio Evidence",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            time,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (hasAudio)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _audioLoading ? null : () => _playAudio(audioUrl),
                icon: _audioLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isPlayingThisAudio
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                label: Text(
                  isPlayingThisAudio ? "Stop Audio" : "Play Audio",
                ),
              ),
            ),
          if (hasAudio) const SizedBox(height: 10),
          if (hasVideo)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openVideo(videoUrl),
                icon: const Icon(Icons.movie_rounded),
                label: const Text("Play Video"),
              ),
            ),
          if (hasVideo) const SizedBox(height: 10),
          if (hasLocation)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openLocation(context, lat, lng),
                icon: const Icon(Icons.location_on_rounded),
                label: const Text("Open Location"),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (hasAudio)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyText(
                      context,
                      audioUrl,
                      success: "Audio link copied.",
                    ),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text("Copy Audio"),
                  ),
                ),
              if (hasAudio && hasVideo) const SizedBox(width: 10),
              if (hasVideo)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyText(
                      context,
                      videoUrl,
                      success: "Video link copied.",
                    ),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text("Copy Video"),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text(
        "No evidence available yet",
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Future<String?> _resolveDeviceId(String uid) async {
    if (widget.deviceId != null && widget.deviceId!.trim().isNotEmpty) {
      return widget.deviceId;
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    return doc.data()?['pairedDeviceId']?.toString();
  }
}

class EvidenceVideoPlayerPage extends StatefulWidget {
  final String videoUrl;

  const EvidenceVideoPlayerPage({
    super.key,
    required this.videoUrl,
  });

  @override
  State<EvidenceVideoPlayerPage> createState() =>
      _EvidenceVideoPlayerPageState();
}

class _EvidenceVideoPlayerPageState extends State<EvidenceVideoPlayerPage> {
  late VideoPlayerController _controller;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _controller.initialize();
      await _controller.play();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    if (!_loading && _error == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("Video Evidence"),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      "Could not play video:\n$_error",
                      textAlign: TextAlign.center,
                    ),
                  )
                : AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
      ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
    );
  }
}
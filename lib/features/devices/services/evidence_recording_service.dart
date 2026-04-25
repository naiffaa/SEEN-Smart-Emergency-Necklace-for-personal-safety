import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class EvidenceRecordingService {
  EvidenceRecordingService._();
  static final EvidenceRecordingService instance = EvidenceRecordingService._();

  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  FirebaseStorage get _storage => FirebaseStorage.instanceFor(
        bucket: 'seen-e1615.firebasestorage.app',
      );

  Future<bool> startAudioRecording(String alertId) async {
    try {
      if (_isRecording) {
        debugPrint('AUDIO RECORDING: already recording');
        return true;
      }

      final hasPermission = await _recorder.hasPermission();
      debugPrint('AUDIO RECORDING: permission=$hasPermission');

      if (!hasPermission) {
        debugPrint('AUDIO RECORDING: microphone permission denied');
        return false;
      }

      final dir = await getTemporaryDirectory();
      final safeAlertId = alertId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      _currentPath = '${dir.path}/seen_audio_$safeAlertId.m4a';

      final oldFile = File(_currentPath!);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentPath!,
      );

      _isRecording = true;
      debugPrint('AUDIO RECORDING: started path=$_currentPath');
      return true;
    } catch (e) {
      _isRecording = false;
      debugPrint('AUDIO RECORDING START ERROR: $e');
      return false;
    }
  }

  Future<String?> stopAndUploadAudio({
    required String uid,
    required String alertId,
  }) async {
    try {
      if (!_isRecording) {
        debugPrint('AUDIO RECORDING: stop skipped, not recording');
        return null;
      }

      final stoppedPath = await _recorder.stop();
      _isRecording = false;

      final audioPath = stoppedPath ?? _currentPath;

      debugPrint('AUDIO RECORDING: stoppedPath=$stoppedPath');
      debugPrint('AUDIO RECORDING: fallbackPath=$_currentPath');
      debugPrint('AUDIO RECORDING: finalPath=$audioPath');

      if (audioPath == null || audioPath.trim().isEmpty) {
        debugPrint('AUDIO RECORDING: audioPath is null/empty');
        return null;
      }

      final file = File(audioPath);
      final exists = await file.exists();
      debugPrint('AUDIO RECORDING: file exists=$exists');

      if (!exists) return null;

      final size = await file.length();
      debugPrint('AUDIO RECORDING: file size=$size bytes');

      if (size <= 0) {
        debugPrint('AUDIO RECORDING: file is empty');
        return null;
      }

      final safeUid = uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final safeAlertId = alertId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      final ref = _storage
          .ref()
          .child('evidence')
          .child(safeUid)
          .child(safeAlertId)
          .child('audio.m4a');

      debugPrint('AUDIO UPLOAD: bucket=${_storage.bucket}');
      debugPrint('AUDIO UPLOAD: uploading to ${ref.fullPath}');

      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'audio/mp4',
          customMetadata: {
            'uid': uid,
            'alertId': alertId,
            'type': 'sos_audio',
          },
        ),
      );

      debugPrint('AUDIO UPLOAD: state=${uploadTask.state}');

      final downloadUrl = await ref.getDownloadURL();
      debugPrint('AUDIO UPLOAD: downloadUrl=$downloadUrl');

      return downloadUrl;
    } catch (e) {
      debugPrint('AUDIO UPLOAD ERROR: $e');
      return null;
    } finally {
      _isRecording = false;
      _currentPath = null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
      }
    } catch (_) {
    } finally {
      _isRecording = false;
      _currentPath = null;
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
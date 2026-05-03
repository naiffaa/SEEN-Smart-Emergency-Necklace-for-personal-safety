import 'package:flutter/foundation.dart';

class EvidenceRecordingService {
  EvidenceRecordingService._();
  static final EvidenceRecordingService instance = EvidenceRecordingService._();

  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// ❌ تم تعطيل التسجيل من الجوال
  Future<bool> startAudioRecording(String alertId) async {
    debugPrint('AUDIO RECORDING DISABLED: using ESP microphone instead');
    _isRecording = false;
    return false;
  }

  /// ❌ تم تعطيل الرفع من الجوال
  Future<String?> stopAndUploadAudio({
    required String uid,
    required String alertId,
  }) async {
    debugPrint('AUDIO UPLOAD DISABLED: handled by ESP + BLE');
    _isRecording = false;
    return null;
  }

  Future<void> cancelRecording() async {
    _isRecording = false;
  }

  Future<void> dispose() async {}
}
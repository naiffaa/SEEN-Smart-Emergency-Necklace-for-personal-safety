import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/seen_ble_message.dart';
import 'seen_ble_service.dart';

class BleSyncService {
  BleSyncService._();
  static final BleSyncService instance = BleSyncService._();

  StreamSubscription<SeenBleMessage>? _sub;
  bool _started = false;

  SeenBleMessage? _lastGps;
  SeenBleMessage? _lastBattery;
  SeenBleMessage? _lastMic;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void start() {
    if (_started) return;
    _started = true;

    debugPrint('BLE SYNC: started');

    _sub = SeenBleService.instance.messageStream.listen(
      _onMessage,
      onError: (e) => debugPrint('BLE SYNC ERROR: $e'),
    );
  }

  void stop() {
    debugPrint('BLE SYNC: stopped');
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _onMessage(SeenBleMessage msg) async {
    debugPrint('BLE SYNC RECEIVED: $msg');

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('BLE SYNC: ignored, no logged-in user');
      return;
    }

    final uid = user.uid;

    if (msg.isGps) {
      _lastGps = msg;
      await _saveGps(uid, msg);
      return;
    }

    if (msg.isMic) {
      _lastMic = msg;
      await _saveMic(uid, msg);
      return;
    }

    if (msg.isBattery) {
      _lastBattery = msg;
      await _saveBattery(uid, msg);
      return;
    }

    if (msg.isReady ||
        msg.isPong ||
        msg.isArmed ||
        msg.isDisarmed ||
        msg.isRaw) {
      await _saveDeviceStatus(uid, msg);
      return;
    }

    if (msg.isSos) {
      await _handleSos(uid, user, msg);
      return;
    }
  }

  Future<void> _saveGps(String uid, SeenBleMessage msg) async {
    final lat = msg.lat;
    final lng = msg.lng;
    final validGps = lat != null && lng != null && lat != 0 && lng != 0;

    await _db.collection('users').doc(uid).set({
      'lat': validGps ? lat : null,
      'lng': validGps ? lng : null,
      'gpsFix': validGps ? (msg.gpsFix ?? true) : false,
      'sat': msg.sat,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('BLE SYNC GPS SAVED: lat=$lat lng=$lng valid=$validGps');
  }

  Future<void> _saveMic(String uid, SeenBleMessage msg) async {
    await _db.collection('users').doc(uid).set({
      'micLevel': msg.micLevel ?? msg.level ?? 0,
      'micOk': msg.ok ?? msg.audio ?? false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('BLE SYNC MIC SAVED: level=${msg.micLevel ?? msg.level}');
  }

  Future<void> _saveBattery(String uid, SeenBleMessage msg) async {
    await _db.collection('users').doc(uid).set({
      'battery': msg.battery ?? 0,
      'batteryVoltage': msg.voltage,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint(
      'BLE SYNC BATTERY SAVED: battery=${msg.battery} voltage=${msg.voltage}',
    );
  }

  Future<void> _saveDeviceStatus(String uid, SeenBleMessage msg) async {
    await _db.collection('users').doc(uid).set({
      'bleConnected': SeenBleService.instance.isConnected,
      'bleDeviceId': SeenBleService.instance.connectedDeviceId,
      'lastBleMessageType': msg.type,
      'lastBleRaw': msg.raw ?? msg.value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('BLE SYNC STATUS SAVED: ${msg.type}');
  }

  Future<void> _handleSos(
    String uid,
    User user,
    SeenBleMessage msg,
  ) async {
    final now = DateTime.now();

    final lat = msg.lat ?? _lastGps?.lat;
    final lng = msg.lng ?? _lastGps?.lng;
    final validGps = lat != null && lng != null && lat != 0 && lng != 0;

    final gpsFix = validGps ? (msg.gpsFix ?? _lastGps?.gpsFix ?? true) : false;
    final sat = msg.sat ?? _lastGps?.sat ?? 0;

    final streamUrl = msg.streamUrl ?? "";
    final espAudioUrl = _extractFieldFromRaw(msg.raw ?? msg.value, 'audioUrl') ??
        _extractFieldFromRaw(msg.raw ?? msg.value, 'audio') ??
        "";

    final battery = msg.battery ?? _lastBattery?.battery;
    final voltage = msg.voltage ?? _lastBattery?.voltage;
    final micLevel =
        msg.micLevel ?? msg.level ?? _lastMic?.micLevel ?? _lastMic?.level;

    final expiresAt = now.add(const Duration(seconds: 60));

    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    final userName =
        (userData['name'] ?? user.displayName ?? "User").toString();
    final userPhone =
        (userData['phone'] ?? user.phoneNumber ?? "").toString();

    final deviceId = _resolveDeviceIdFromUserData(userData);
    final contactIds = await _loadEmergencyContactIds(uid);

    final alertRef = _db.collection('alerts').doc();

    final locationText = validGps
        ? "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}"
        : "Waiting GPS...";

    final audioStatus = espAudioUrl.isNotEmpty ? 'recording' : 'unavailable';

    debugPrint('BLE SYNC SOS STARTED alertId=${alertRef.id}');
    debugPrint('ESP AUDIO URL: $espAudioUrl');

    await alertRef.set({
      'alertId': alertRef.id,
      'userId': uid,
      'vulnerableId': uid,
      'vulnerableUserId': uid,
      'userName': userName,
      'userPhone': userPhone,
      'lat': validGps ? lat : null,
      'lng': validGps ? lng : null,
      'gpsFix': gpsFix,
      'sat': sat,
      'location': locationText,
      'status': 'Triggered',
      'triggeredAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'streamUrl': streamUrl,
      'streamStatus': streamUrl.isNotEmpty ? 'ready' : 'starting',
      'espAudioUrl': espAudioUrl,
      'audioEnabled': espAudioUrl.isNotEmpty,
      'audioSource': 'necklace',
      'audioRecordingStatus': audioStatus,
      'battery': battery,
      'batteryVoltage': voltage,
      'micLevel': micLevel,
      'emergencyContactIds': contactIds,
      'source': msg.source ?? 'button',
      'raw': msg.raw,
    });

    await _db.collection('live_sessions').add({
      'alertId': alertRef.id,
      'userId': uid,
      'vulnerableId': uid,
      'streamUrl': streamUrl,
      'streamStatus': streamUrl.isNotEmpty ? 'live' : 'starting',
      'espAudioUrl': espAudioUrl,
      'lat': validGps ? lat : null,
      'lng': validGps ? lng : null,
      'gpsFix': gpsFix,
      'sat': sat,
      'audioEnabled': espAudioUrl.isNotEmpty,
      'audioSource': 'necklace',
      'audioRecordingStatus': audioStatus,
      'battery': battery,
      'batteryVoltage': voltage,
      'micLevel': micLevel,
      'isLive': true,
      'startedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'durationSeconds': 60,
    });

    await _db.collection('users').doc(uid).set({
      'status': 'Alert',
      'lastAlertId': alertRef.id,
      'lat': validGps ? lat : null,
      'lng': validGps ? lng : null,
      'gpsFix': gpsFix,
      'sat': sat,
      'battery': battery,
      'batteryVoltage': voltage,
      'micLevel': micLevel,
      'streamUrl': streamUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _fanOutIncidentToEmergencyContacts(
      vulnerableUserId: uid,
      vulnerableUserName: userName,
      vulnerableUserPhone: userPhone,
      alertId: alertRef.id,
      locationText: locationText,
      emergencyContactIds: contactIds,
      streamUrl: streamUrl,
      hasStream: streamUrl.isNotEmpty,
      lat: validGps ? lat : null,
      lng: validGps ? lng : null,
      gpsFix: gpsFix,
      sat: sat,
      expiresAt: Timestamp.fromDate(expiresAt),
      battery: battery,
      batteryVoltage: voltage,
      micLevel: micLevel,
      audioEnabled: espAudioUrl.isNotEmpty,
      audioRecordingStatus: audioStatus,
      espAudioUrl: espAudioUrl,
    );

    if (espAudioUrl.isNotEmpty) {
      _finishEspAudioEvidenceUpload(
        uid: uid,
        deviceId: deviceId,
        alertId: alertRef.id,
        alertRef: alertRef,
        espAudioUrl: espAudioUrl,
        lat: validGps ? lat : null,
        lng: validGps ? lng : null,
        gpsFix: gpsFix,
        sat: sat,
        battery: battery,
        batteryVoltage: voltage,
        micLevel: micLevel,
        source: msg.source ?? 'button',
        raw: msg.raw,
        emergencyContactIds: contactIds,
      );
    }

    debugPrint('BLE SYNC SOS DONE: alertId=${alertRef.id}');
  }

  String? _extractFieldFromRaw(String? raw, String key) {
    if (raw == null || raw.trim().isEmpty) return null;

    final parts = raw.split('|');

    for (final part in parts) {
      final index = part.indexOf('=');
      if (index == -1) continue;

      final k = part.substring(0, index).trim();
      final v = part.substring(index + 1).trim();

      if (k == key && v.isNotEmpty) return v;
    }

    return null;
  }

  String _resolveDeviceIdFromUserData(Map<String, dynamic> userData) {
    final fromFirestore = userData['pairedDeviceId']?.toString();
    if (fromFirestore != null && fromFirestore.isNotEmpty) {
      return fromFirestore;
    }

    final fromBle = SeenBleService.instance.connectedDeviceId;
    if (fromBle != null && fromBle.isNotEmpty) {
      return fromBle;
    }

    return 'SEEN_DEVICE';
  }

  void _finishEspAudioEvidenceUpload({
    required String uid,
    required String deviceId,
    required String alertId,
    required DocumentReference<Map<String, dynamic>> alertRef,
    required String espAudioUrl,
    required double? lat,
    required double? lng,
    required bool gpsFix,
    required int sat,
    required int? battery,
    required double? batteryVoltage,
    required int? micLevel,
    required String source,
    required String? raw,
    required List<String> emergencyContactIds,
  }) {
    Future.delayed(const Duration(seconds: 18), () async {
      try {
        debugPrint('ESP AUDIO: downloading from $espAudioUrl');

        final firebaseAudioUrl = await _downloadAndUploadEspAudio(
          uid: uid,
          alertId: alertId,
          espAudioUrl: espAudioUrl,
        );

        if (firebaseAudioUrl == null || firebaseAudioUrl.isEmpty) {
          debugPrint('ESP AUDIO: upload failed');

          await alertRef.set({
            'audioRecordingStatus': 'failed',
            'audioUploadError': 'ESP audio download/upload failed',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return;
        }

        await alertRef.set({
          'audioUrl': firebaseAudioUrl,
          'espAudioUrl': espAudioUrl,
          'audioSource': 'necklace',
          'audioRecordingStatus': 'uploaded',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final liveSnap = await _db
            .collection('live_sessions')
            .where('alertId', isEqualTo: alertId)
            .get();

        for (final doc in liveSnap.docs) {
          await doc.reference.set({
            'audioUrl': firebaseAudioUrl,
            'espAudioUrl': espAudioUrl,
            'audioSource': 'necklace',
            'audioRecordingStatus': 'uploaded',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        await _db
            .collection('users')
            .doc(uid)
            .collection('devices')
            .doc(deviceId)
            .collection('history')
            .add({
          'title': 'Audio Evidence',
          'eventType': 'audio',
          'status': 'Uploaded',
          'details': 'SOS audio recording from SEEN necklace saved.',
          'alertId': alertId,
          'audioUrl': firebaseAudioUrl,
          'espAudioUrl': espAudioUrl,
          'audioSource': 'necklace',
          'lat': lat,
          'lng': lng,
          'gpsFix': gpsFix,
          'sat': sat,
          'battery': battery,
          'batteryVoltage': batteryVoltage,
          'micLevel': micLevel,
          'source': source,
          'raw': raw,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        for (final ecUid in emergencyContactIds) {
          final incidents = await _db
              .collection('users')
              .doc(ecUid)
              .collection('incidents')
              .where('alertId', isEqualTo: alertId)
              .get();

          for (final doc in incidents.docs) {
            await doc.reference.set({
              'audioUrl': firebaseAudioUrl,
              'espAudioUrl': espAudioUrl,
              'audioSource': 'necklace',
              'audioRecordingStatus': 'uploaded',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          await _db
              .collection('users')
              .doc(ecUid)
              .collection('linkedUsers')
              .doc(uid)
              .set({
            'audioUrl': firebaseAudioUrl,
            'espAudioUrl': espAudioUrl,
            'audioSource': 'necklace',
            'audioRecordingStatus': 'uploaded',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        debugPrint('ESP AUDIO: uploaded and saved');
      } catch (e) {
        debugPrint('ESP AUDIO ERROR: $e');

        await alertRef.set({
          'audioRecordingStatus': 'failed',
          'audioUploadError': e.toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<String?> _downloadAndUploadEspAudio({
    required String uid,
    required String alertId,
    required String espAudioUrl,
  }) async {
    HttpClient? client;

    try {
      final uri = Uri.parse(espAudioUrl);
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        debugPrint('ESP AUDIO: HTTP status ${response.statusCode}');
        return null;
      }

      final bytes = await consolidateHttpClientResponseBytes(response);

      if (bytes.isEmpty) {
        debugPrint('ESP AUDIO: empty audio file');
        return null;
      }

      debugPrint('ESP AUDIO: downloaded ${bytes.length} bytes');

      final safeUid = uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final safeAlertId = alertId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('evidence')
          .child(safeUid)
          .child(safeAlertId)
          .child('audio.wav');

      await storageRef.putData(
        bytes,
        SettableMetadata(
          contentType: 'audio/wav',
          customMetadata: {
            'uid': uid,
            'alertId': alertId,
            'source': 'necklace',
            'type': 'sos_audio',
            'espAudioUrl': espAudioUrl,
          },
        ),
      );

      final downloadUrl = await storageRef.getDownloadURL();
      debugPrint('ESP AUDIO: Firebase URL=$downloadUrl');

      return downloadUrl;
    } catch (e) {
      debugPrint('ESP AUDIO DOWNLOAD/UPLOAD ERROR: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  Future<List<String>> _loadEmergencyContactIds(String vulnerableUserId) async {
    final snapshot = await _db
        .collection('users')
        .doc(vulnerableUserId)
        .collection('contacts')
        .get();

    final ids = <String>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final candidates = [
        data['contactUserId'],
        data['uid'],
        data['userId'],
        data['contactId'],
        doc.id,
      ];

      for (final candidate in candidates) {
        final value = candidate?.toString();
        if (value != null && value.isNotEmpty && !ids.contains(value)) {
          ids.add(value);
          break;
        }
      }
    }

    return ids;
  }

  Future<void> _fanOutIncidentToEmergencyContacts({
    required String vulnerableUserId,
    required String vulnerableUserName,
    required String vulnerableUserPhone,
    required String alertId,
    required String locationText,
    required List<String> emergencyContactIds,
    required String streamUrl,
    required bool hasStream,
    required double? lat,
    required double? lng,
    required bool gpsFix,
    required int sat,
    required Timestamp expiresAt,
    required int? battery,
    required double? batteryVoltage,
    required int? micLevel,
    required bool audioEnabled,
    required String audioRecordingStatus,
    required String espAudioUrl,
  }) async {
    final nowText = DateTime.now().toString();

    for (final ecUid in emergencyContactIds) {
      await _db
          .collection('users')
          .doc(ecUid)
          .collection('linkedUsers')
          .doc(vulnerableUserId)
          .set({
        'name': vulnerableUserName,
        'phone': vulnerableUserPhone,
        'status': 'Alert',
        'lastAlertId': alertId,
        'lastUpdate': nowText,
        'lat': lat,
        'lng': lng,
        'gpsFix': gpsFix,
        'location': locationText,
        'streamUrl': streamUrl,
        'streamStatus': hasStream ? 'ready' : 'unavailable',
        'espAudioUrl': espAudioUrl,
        'battery': battery,
        'batteryVoltage': batteryVoltage,
        'micLevel': micLevel,
        'audioEnabled': audioEnabled,
        'audioSource': 'necklace',
        'audioRecordingStatus': audioRecordingStatus,
        'expiresAt': expiresAt,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('users').doc(ecUid).collection('incidents').add({
        'alertId': alertId,
        'title': 'Emergency Alert',
        'status': 'Triggered',
        'location': locationText,
        'lat': lat,
        'lng': lng,
        'gpsFix': gpsFix,
        'sat': sat,
        'vulnerableId': vulnerableUserId,
        'vulnerableUserId': vulnerableUserId,
        'userName': vulnerableUserName,
        'userPhone': vulnerableUserPhone,
        'streamUrl': streamUrl,
        'streamStatus': hasStream ? 'ready' : 'unavailable',
        'espAudioUrl': espAudioUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,
        'durationSeconds': 60,
        'audioEnabled': audioEnabled,
        'audioSource': 'necklace',
        'audioRecordingStatus': audioRecordingStatus,
        'battery': battery,
        'batteryVoltage': batteryVoltage,
        'micLevel': micLevel,
      });
    }
  }
}
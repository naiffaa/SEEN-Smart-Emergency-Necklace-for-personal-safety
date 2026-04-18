import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/seen_ble_message.dart';
import 'seen_ble_service.dart';

class BleSyncService {
  BleSyncService._();
  static final BleSyncService instance = BleSyncService._();

  final SeenBleService _ble = SeenBleService.instance;
  StreamSubscription<SeenBleMessage>? _sub;

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    _sub = _ble.messageStream.listen((message) async {
      try {
        await _handleMessage(message);
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _handleMessage(SeenBleMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final String userName =
        (userData['name'] ?? user.displayName ?? 'Unknown User').toString();

    final deviceDocId =
        _ble.connectedDevice?.remoteId.str ?? message.deviceId ?? 'seen_device';

    final String deviceName = message.deviceId ?? 'SEEN Device';
    final String streamUrl = (message.streamUrl ?? '').trim();

    if (message.type == 'ready' ||
        message.type == 'armed' ||
        message.type == 'pong' ||
        message.type == 'disarmed') {
      await _upsertDevice(
        userId: user.uid,
        deviceDocId: deviceDocId,
        data: {
          'name': deviceName,
          'deviceId': deviceDocId,
          'bleName': _ble.connectedDevice?.platformName ?? deviceName,
          'status': message.type == 'disarmed' ? 'Safe' : 'Connected',
          'source': 'ble',
          'isPaired': true,
          'lastMessageType': message.type,
          'streamUrl': streamUrl,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      );
      return;
    }

    if (message.type == 'gps') {
      await _upsertDevice(
        userId: user.uid,
        deviceDocId: deviceDocId,
        data: {
          'name': deviceName,
          'deviceId': deviceDocId,
          'status': 'Connected',
          'location': (message.lat != null && message.lng != null)
              ? '${message.lat}, ${message.lng}'
              : 'Unknown',
          'lat': message.lat,
          'lng': message.lng,
          'gpsFix': message.gpsFix ?? false,
          'sat': message.sat ?? 0,
          'streamUrl': streamUrl,
          'lastMessageType': 'gps',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      );

      await _addDeviceHistory(
        userId: user.uid,
        deviceDocId: deviceDocId,
        eventType: 'gps',
        title: 'GPS Update',
        status: (message.gpsFix ?? false) ? 'Uploaded' : 'Pending',
        details: (message.lat != null && message.lng != null)
            ? 'Lat: ${message.lat}, Lng: ${message.lng}'
            : 'GPS available but no fix yet.',
        meta: {
          'lat': message.lat,
          'lng': message.lng,
          'gpsFix': message.gpsFix,
          'sat': message.sat,
          'streamUrl': streamUrl,
          'ts': message.ts,
        },
      );
      return;
    }

    if (message.type == 'camera') {
      await _addDeviceHistory(
        userId: user.uid,
        deviceDocId: deviceDocId,
        eventType: 'camera',
        title: 'Camera Capture',
        status: (message.ok ?? false) ? 'Uploaded' : 'Pending',
        details: (message.ok ?? false)
            ? 'Camera captured successfully.'
            : 'Camera capture failed.',
        meta: {
          'ok': message.ok,
          'bytes': message.bytes,
          'streamUrl': streamUrl,
          'ts': message.ts,
        },
      );

      await _upsertDevice(
        userId: user.uid,
        deviceDocId: deviceDocId,
        data: {
          'streamUrl': streamUrl,
          'lastMessageType': 'camera',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      );
      return;
    }

    if (message.type == 'mic') {
      await _addDeviceHistory(
        userId: user.uid,
        deviceDocId: deviceDocId,
        eventType: 'mic',
        title: 'Microphone Activity',
        status: (message.ok ?? true) ? 'Uploaded' : 'Pending',
        details: 'Microphone activity detected.',
        meta: {
          'ok': message.ok,
          'bytes': message.bytes,
          'level': message.level,
          'streamUrl': streamUrl,
          'ts': message.ts,
        },
      );

      await _upsertDevice(
        userId: user.uid,
        deviceDocId: deviceDocId,
        data: {
          'streamUrl': streamUrl,
          'lastMessageType': 'mic',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      );
      return;
    }

    if (message.type == 'sos') {
      final String locationText = (message.lat != null && message.lng != null)
          ? '${message.lat}, ${message.lng}'
          : 'Unknown Location';

      final bool hasStream = streamUrl.isNotEmpty;

      await _upsertDevice(
        userId: user.uid,
        deviceDocId: deviceDocId,
        data: {
          'name': deviceName,
          'deviceId': deviceDocId,
          'status': 'Emergency',
          'location': locationText,
          'lat': message.lat,
          'lng': message.lng,
          'gpsFix': message.gpsFix ?? false,
          'streamUrl': streamUrl,
          'lastMessageType': 'sos',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      );

      await _addDeviceHistory(
        userId: user.uid,
        deviceDocId: deviceDocId,
        eventType: 'sos',
        title: 'SOS Triggered',
        status: 'Uploaded',
        details: locationText,
        meta: {
          'button': message.button,
          'lat': message.lat,
          'lng': message.lng,
          'gpsFix': message.gpsFix,
          'streamUrl': streamUrl,
          'source': message.source,
          'ts': message.ts,
        },
      );

      final contactIds = await _loadEmergencyContactIds(user.uid);

      final alertRef = await FirebaseFirestore.instance.collection('alerts').add({
        'vulnerableId': user.uid,
        'userId': user.uid,
        'userName': userName,
        'deviceId': deviceDocId,
        'source': 'esp_ble',
        'status': 'Triggered',
        'location': locationText,
        'lat': message.lat,
        'lng': message.lng,
        'gpsFix': message.gpsFix ?? false,
        'triggeredAt': FieldValue.serverTimestamp(),
        'emergencyContactIds': contactIds,
        'streamStatus': hasStream ? 'ready' : 'unavailable',
        'streamUrl': streamUrl,
      });

      await FirebaseFirestore.instance
          .collection('live_sessions')
          .doc(alertRef.id)
          .set({
        'alertId': alertRef.id,
        'userId': user.uid,
        'userName': userName,
        'deviceId': deviceDocId,
        'isLive': hasStream,
        'streamStatus': hasStream ? 'ready' : 'unavailable',
        'streamUrl': streamUrl,
        'source': message.source ?? 'esp32_wifi_camera',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _fanOutIncidentToEmergencyContacts(
        vulnerableUserId: user.uid,
        vulnerableUserName: userName,
        alertId: alertRef.id,
        locationText: locationText,
        emergencyContactIds: contactIds,
        streamUrl: streamUrl,
        hasStream: hasStream,
      );
    }
  }

  Future<void> _upsertDevice({
    required String userId,
    required String deviceDocId,
    required Map<String, dynamic> data,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceDocId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> _addDeviceHistory({
    required String userId,
    required String deviceDocId,
    required String eventType,
    required String title,
    required String status,
    required String details,
    Map<String, dynamic>? meta,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceDocId)
        .collection('history')
        .add({
      'eventType': eventType,
      'title': title,
      'status': status,
      'details': details,
      'meta': meta ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> _loadEmergencyContactIds(String vulnerableUserId) async {
    final snapshot = await FirebaseFirestore.instance
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
    required String alertId,
    required String locationText,
    required List<String> emergencyContactIds,
    required String streamUrl,
    required bool hasStream,
  }) async {
    final nowText = DateTime.now().toString();

    for (final ecUid in emergencyContactIds) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ecUid)
          .collection('linkedUsers')
          .doc(vulnerableUserId)
          .set({
        'name': vulnerableUserName,
        'status': 'Alert',
        'lastUpdate': nowText,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(ecUid)
          .collection('incidents')
          .add({
        'alertId': alertId,
        'title': 'Emergency Alert',
        'status': 'Triggered',
        'location': locationText,
        'vulnerableId': vulnerableUserId,
        'userName': vulnerableUserName,
        'streamUrl': streamUrl,
        'streamStatus': hasStream ? 'ready' : 'unavailable',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
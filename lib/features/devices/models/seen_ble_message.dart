class SeenBleMessage {
  final String type;
  final String? deviceId;
  final double? lat;
  final double? lng;
  final bool? gpsFix;
  final int? sat;
  final bool? ok;
  final String? value;
  final int? ts;

  final int? bytes;
  final int? level;
  final bool? button;

  final String? streamUrl;
  final String? source;

  const SeenBleMessage({
    required this.type,
    this.deviceId,
    this.lat,
    this.lng,
    this.gpsFix,
    this.sat,
    this.ok,
    this.value,
    this.ts,
    this.bytes,
    this.level,
    this.button,
    this.streamUrl,
    this.source,
  });

  factory SeenBleMessage.fromJson(Map<String, dynamic> json) {
    return SeenBleMessage(
      type: json['type']?.toString() ?? 'unknown',
      deviceId: json['deviceId']?.toString(),
      lat: json['lat'] is num ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] is num ? (json['lng'] as num).toDouble() : null,
      gpsFix: json['gpsFix'] is bool ? json['gpsFix'] as bool : null,
      sat: json['sat'] is num ? (json['sat'] as num).toInt() : null,
      ok: json['ok'] is bool ? json['ok'] as bool : null,
      value: json['value']?.toString(),
      ts: json['ts'] is num ? (json['ts'] as num).toInt() : null,
      bytes: json['bytes'] is num ? (json['bytes'] as num).toInt() : null,
      level: json['level'] is num ? (json['level'] as num).toInt() : null,
      button: json['button'] is bool ? json['button'] as bool : null,
      streamUrl: json['streamUrl']?.toString(),
      source: json['source']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'deviceId': deviceId,
      'lat': lat,
      'lng': lng,
      'gpsFix': gpsFix,
      'sat': sat,
      'ok': ok,
      'value': value,
      'ts': ts,
      'bytes': bytes,
      'level': level,
      'button': button,
      'streamUrl': streamUrl,
      'source': source,
    };
  }

  bool get isSos => type == 'sos';
  bool get isGps => type == 'gps';
  bool get isCamera => type == 'camera';
  bool get isMic => type == 'mic';
  bool get isReady => type == 'ready';
  bool get isPong => type == 'pong';
  bool get isArmed => type == 'armed';
  bool get isDisarmed => type == 'disarmed';
  bool get isRaw => type == 'raw';

  @override
  String toString() {
    return 'SeenBleMessage('
        'type: $type, '
        'deviceId: $deviceId, '
        'lat: $lat, lng: $lng, '
        'gpsFix: $gpsFix, sat: $sat, '
        'ok: $ok, bytes: $bytes, level: $level, '
        'button: $button, ts: $ts, '
        'streamUrl: $streamUrl, source: $source, '
        'value: $value'
        ')';
  }
}
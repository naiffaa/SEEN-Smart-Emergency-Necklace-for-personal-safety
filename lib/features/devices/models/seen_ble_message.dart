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
  final String? raw;

  final bool? audio;
  final int? battery;
  final double? voltage;
  final int? micLevel;

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
    this.raw,
    this.audio,
    this.battery,
    this.voltage,
    this.micLevel,
  });

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static bool? _toBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;

    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'ok') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'fail') return false;
    return null;
  }

  static Map<String, dynamic> _parsePipeMessage(String input) {
    final raw = input.trim();
    final parts = raw.split('|');

    final map = <String, dynamic>{
      'type': parts.isNotEmpty ? parts.first.trim().toLowerCase() : 'raw',
      'raw': raw,
    };

    for (final part in parts.skip(1)) {
      final index = part.indexOf('=');
      if (index == -1) continue;

      final key = part.substring(0, index).trim();
      final value = part.substring(index + 1).trim();

      if (key.isNotEmpty) {
        map[key] = value;
      }
    }

    return map;
  }

  factory SeenBleMessage.fromRaw(String rawMessage) {
    return SeenBleMessage.fromJson(_parsePipeMessage(rawMessage));
  }

  factory SeenBleMessage.fromJson(Map<String, dynamic> json) {
    final normalizedType =
        json['type']?.toString().trim().toLowerCase() ?? 'unknown';

    return SeenBleMessage(
      type: normalizedType,
      deviceId: json['deviceId']?.toString() ??
          json['device_id']?.toString() ??
          json['id']?.toString(),
      lat: _toDouble(json['lat'] ?? json['latitude']),
      lng: _toDouble(json['lng'] ?? json['lon'] ?? json['longitude']),
      gpsFix: _toBool(json['gpsFix'] ?? json['gps_fix'] ?? json['fix']),
      sat: _toInt(json['sat'] ?? json['satellites']),
      ok: _toBool(json['ok']),
      value: json['value']?.toString(),
      ts: _toInt(json['ts'] ?? json['timestamp']),
      bytes: _toInt(json['bytes']),
      level: _toInt(json['level']),
      button: _toBool(json['button']),
      streamUrl: json['streamUrl']?.toString() ??
          json['stream_url']?.toString() ??
          json['stream']?.toString() ??
          json['url']?.toString(),
      source: json['source']?.toString(),
      raw: json['raw']?.toString(),
      audio: _toBool(json['audio'] ?? json['mic']),
      battery: _toInt(json['battery'] ?? json['bat']),
      voltage: _toDouble(json['voltage'] ?? json['volt']),
      micLevel: _toInt(json['micLevel'] ?? json['mic_level'] ?? json['micLevelDb']),
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
      'raw': raw,
      'audio': audio,
      'battery': battery,
      'voltage': voltage,
      'micLevel': micLevel,
    };
  }

  bool get isSos => type == 'sos';
  bool get isGps => type == 'gps';
  bool get isCamera => type == 'camera' || type == 'cam';
  bool get isMic => type == 'mic';
  bool get isBattery => type == 'bat' || type == 'battery';
  bool get isReady => type == 'ready';
  bool get isPong => type == 'pong';
  bool get isArmed => type == 'armed';
  bool get isDisarmed => type == 'disarmed';
  bool get isRaw => type == 'raw';

  bool get hasLocation =>
      lat != null && lng != null && lat != 0 && lng != 0;

  bool get hasStreamUrl =>
      streamUrl != null && streamUrl!.trim().isNotEmpty;

  SeenBleMessage copyWith({
    String? type,
    String? deviceId,
    double? lat,
    double? lng,
    bool? gpsFix,
    int? sat,
    bool? ok,
    String? value,
    int? ts,
    int? bytes,
    int? level,
    bool? button,
    String? streamUrl,
    String? source,
    String? raw,
    bool? audio,
    int? battery,
    double? voltage,
    int? micLevel,
  }) {
    return SeenBleMessage(
      type: type ?? this.type,
      deviceId: deviceId ?? this.deviceId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      gpsFix: gpsFix ?? this.gpsFix,
      sat: sat ?? this.sat,
      ok: ok ?? this.ok,
      value: value ?? this.value,
      ts: ts ?? this.ts,
      bytes: bytes ?? this.bytes,
      level: level ?? this.level,
      button: button ?? this.button,
      streamUrl: streamUrl ?? this.streamUrl,
      source: source ?? this.source,
      raw: raw ?? this.raw,
      audio: audio ?? this.audio,
      battery: battery ?? this.battery,
      voltage: voltage ?? this.voltage,
      micLevel: micLevel ?? this.micLevel,
    );
  }

  @override
  String toString() {
    return 'SeenBleMessage('
        'type: $type, '
        'deviceId: $deviceId, '
        'lat: $lat, lng: $lng, '
        'gpsFix: $gpsFix, sat: $sat, '
        'ok: $ok, bytes: $bytes, level: $level, '
        'button: $button, ts: $ts, '
        'streamUrl: $streamUrl, source: $source, raw: $raw, '
        'audio: $audio, battery: $battery, voltage: $voltage, micLevel: $micLevel, '
        'value: $value'
        ')';
  }
}
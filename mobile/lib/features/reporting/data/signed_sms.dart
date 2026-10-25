import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/responda_api_client.dart';
import '../domain/models/report_draft.dart';

abstract interface class SmsKeyStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSmsKeyStore implements SmsKeyStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'responda_sms_credential_v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class SmsSetup {
  const SmsSetup({
    required this.deviceId,
    required this.owner,
    required this.backend,
    this.key,
    this.gateway,
    this.expiresAt,
  });
  final String deviceId;
  final String owner;
  final String backend;
  final String? key;
  final String? gateway;
  final DateTime? expiresAt;
  bool get ready =>
      key != null &&
      gateway != null &&
      RegExp(r'^\+639[0-9]{9}$').hasMatch(gateway!) &&
      (expiresAt?.isAfter(DateTime.now()) ?? false);
  String encode() => jsonEncode({
    'device': deviceId,
    'owner': owner,
    'backend': backend,
    'key': key,
    'gateway': gateway,
    'expires': expiresAt?.toIso8601String(),
  });
  factory SmsSetup.decode(String value) {
    final json = jsonDecode(value) as Map;
    return SmsSetup(
      deviceId: json['device'] as String,
      owner: json['owner'] as String,
      backend: json['backend'] as String,
      key: json['key'] as String?,
      gateway: json['gateway'] as String?,
      expiresAt: DateTime.tryParse(json['expires'] as String? ?? ''),
    );
  }
}

String signSms({
  required SmsSetup setup,
  required ReportDraft draft,
  required String clientId,
  required DateTime createdAt,
}) {
  if (!setup.ready) {
    throw const RespondaApiException(
      'Connect to the internet and set up Offline SMS in Account Management first.',
    );
  }
  final description = draft.description.trim().replaceAll(RegExp(r'\s+'), ' ');
  final landmark = draft.landmark.trim();
  if (description.runes.length < 10 ||
      description.runes.length > 300 ||
      landmark.runes.length > 100) {
    throw const RespondaApiException(
      'SMS needs 10–300 characters of details and a landmark of at most 100 characters. Shorten the report and try again.',
    );
  }
  if ((!draft.hasLocation && landmark.isEmpty) ||
      ((draft.latitude == null) != (draft.longitude == null)) ||
      (draft.latitude != null &&
          (!draft.latitude!.isFinite || draft.latitude!.abs() > 90)) ||
      (draft.longitude != null &&
          (!draft.longitude!.isFinite || draft.longitude!.abs() > 180)) ||
      (draft.locationAccuracy != null &&
          (!draft.locationAccuracy!.isFinite ||
              draft.locationAccuracy! < 0 ||
              draft.locationAccuracy! > 100000))) {
    throw const RespondaApiException(
      'Add a valid GPS location or landmark before sending SMS.',
    );
  }
  if (draft.photoPath != null) {
    throw const RespondaApiException(
      'SMS cannot include photos. Remove the photo to continue.',
    );
  }
  final id = clientId.replaceAll('-', '').toLowerCase();
  final device = setup.deviceId.replaceAll('-', '').toLowerCase();
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id) ||
      !RegExp(r'^[0-9a-f]{32}$').hasMatch(device)) {
    throw const RespondaApiException(
      'SMS setup is invalid. Connect online and set it up again.',
    );
  }
  String b64(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');
  final payload = {
    'c': id,
    't': createdAt.toUtc().millisecondsSinceEpoch ~/ 1000,
    if (draft.locationCapturedAt != null)
      'k': draft.locationCapturedAt!.toUtc().millisecondsSinceEpoch ~/ 1000,
    'i': draft.incidentType.apiValue,
    'd': description,
    if (landmark.isNotEmpty) 'l': landmark,
    if (draft.hasLocation) 'x': draft.latitude,
    if (draft.hasLocation) 'y': draft.longitude,
    if (draft.locationAccuracy != null) 'm': draft.locationAccuracy,
    'p': draft.morePeople ?? false,
    'a': draft.additionalAssistance ?? false,
    'g': draft.stillDangerous ?? false,
  };
  final unsigned = 'RSP1.$device.${b64(utf8.encode(jsonEncode(payload)))}';
  final key = base64Url.decode(base64Url.normalize(setup.key!));
  if (key.length != 32) throw const FormatException('Invalid SMS credential');
  final body =
      '$unsigned.${b64(Hmac(sha256, key).convert(ascii.encode(unsigned)).bytes)}';
  if (body.length > 2048) {
    throw const RespondaApiException(
      'This SMS is too long. Shorten the details and landmark; no text has been removed.',
    );
  }
  return body;
}

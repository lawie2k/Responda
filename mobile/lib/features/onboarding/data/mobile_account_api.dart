import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/responda_api_client.dart';

abstract interface class SessionTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureSessionTokenStore implements SessionTokenStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'responda_mobile_session_v1';

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MobileAccountApi {
  MobileAccountApi({http.Client? client, this.baseUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;
  final http.Client _client;
  final bool _ownsClient;
  final String? baseUrl;

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    String? token,
    Map<String, Object?>? body,
  }) async {
    return _request(
      ApiConfig.endpoint('/api/v1/mobile/auth/$path', overrideBaseUrl: baseUrl),
      method: method,
      token: token,
      body: body,
    );
  }

  Future<Map<String, dynamic>> submitReport({
    required String token,
    required Map<String, Object?> body,
  }) {
    return _request(
      ApiConfig.endpoint('/api/v1/mobile/reports', overrideBaseUrl: baseUrl),
      method: 'POST',
      token: token,
      body: body,
    );
  }

  Future<Map<String, dynamic>> smsDevice(
    String deviceId, {
    required String token,
    bool revoke = false,
  }) => _request(
    ApiConfig.endpoint(
      '/api/v1/mobile/sms-devices${revoke ? '/$deviceId' : ''}',
      overrideBaseUrl: baseUrl,
    ),
    method: revoke ? 'DELETE' : 'POST',
    token: token,
    body: revoke ? null : {'device_id': deviceId},
  );

  Future<Map<String, dynamic>> readReports({
    required String token,
    String? reportId,
    bool completed = false,
    int page = 1,
  }) {
    final endpoint = ApiConfig.endpoint(
      '/api/v1/mobile/reports${reportId == null ? '' : '/${Uri.encodeComponent(reportId)}'}',
      overrideBaseUrl: baseUrl,
    );
    return _request(
      reportId == null
          ? endpoint.replace(
              queryParameters: {
                'category': completed ? 'completed' : 'active',
                'page': '$page',
                'page_size': '20',
              },
            )
          : endpoint,
      method: 'GET',
      token: token,
    );
  }

  Future<Map<String, dynamic>> _request(
    Uri uri, {
    required String method,
    String? token,
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, uri);
    request.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    });
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    final response = await (() async {
      return http.Response.fromStream(await _client.send(request));
    })().timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Unable to connect. Please try again.';
      String? code;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map &&
            decoded['error'] is Map &&
            decoded['error']['message'] is String) {
          message = decoded['error']['message'] as String;
          code = decoded['error']['code'] as String?;
        }
      } catch (_) {
        /* Keep the safe fallback for non-JSON server errors. */
      }
      throw RespondaApiException(
        message,
        statusCode: response.statusCode,
        code: code,
      );
    }
    if (response.statusCode == 204) return {};
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

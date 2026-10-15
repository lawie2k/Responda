import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class BackendHealth {
  const BackendHealth({
    required this.status,
    required this.service,
    required this.environment,
    required this.apiVersion,
    required this.database,
  });

  final String status;
  final String service;
  final String environment;
  final String apiVersion;
  final String database;

  bool get isHealthy => status == 'ok' && database == 'ok';

  factory BackendHealth.fromJson(Map<String, Object?> json) {
    return BackendHealth(
      status: _requiredString(json, 'status'),
      service: _requiredString(json, 'service'),
      environment: _requiredString(json, 'environment'),
      apiVersion: _requiredString(json, 'api_version'),
      database: _requiredString(json, 'database'),
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Backend health response is missing "$key".');
    }
    return value;
  }
}

class RespondaApiException implements Exception {
  const RespondaApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'RespondaApiException: $message';
}

class RespondaApiClient {
  RespondaApiClient({
    http.Client? client,
    this.baseUrl,
    this.requestTimeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final String? baseUrl;
  final Duration requestTimeout;

  Future<BackendHealth> getHealth() async {
    final response = await _client
        .get(
          ApiConfig.endpoint('/api/v1/shared/health', overrideBaseUrl: baseUrl),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(requestTimeout);

    if (response.statusCode != 200) {
      throw RespondaApiException(
        'Backend health check failed.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Backend health response must be an object.');
    }
    return BackendHealth.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<bool> isAvailable() async {
    try {
      return (await getHealth()).isHealthy;
    } catch (_) {
      return false;
    }
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

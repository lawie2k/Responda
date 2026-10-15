import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:responda/core/network/responda_api_client.dart';

void main() {
  test('health check connects to the FastAPI health endpoint', () async {
    late Uri requestedUri;
    final client = RespondaApiClient(
      baseUrl: 'http://backend.test:8000/',
      client: MockClient((request) async {
        requestedUri = request.url;
        expect(request.headers['Accept'], 'application/json');
        return http.Response(
          '{'
          '"status":"ok",'
          '"service":"Responda API",'
          '"environment":"testing",'
          '"api_version":"1.0.0",'
          '"database":"ok"'
          '}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final health = await client.getHealth();

    expect(
      requestedUri,
      Uri.parse('http://backend.test:8000/api/v1/shared/health'),
    );
    expect(health.service, 'Responda API');
    expect(health.apiVersion, '1.0.0');
    expect(health.isHealthy, isTrue);
  });

  test('backend is unavailable when health returns an error', () async {
    final client = RespondaApiClient(
      baseUrl: 'http://backend.test:8000',
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );

    expect(await client.isAvailable(), isFalse);
  });

  test('backend is unavailable when the database is not healthy', () async {
    final client = RespondaApiClient(
      baseUrl: 'http://backend.test:8000',
      client: MockClient(
        (_) async => http.Response(
          '{'
          '"status":"degraded",'
          '"service":"Responda API",'
          '"environment":"testing",'
          '"api_version":"1.0.0",'
          '"database":"unavailable"'
          '}',
          200,
        ),
      ),
    );

    expect(await client.isAvailable(), isFalse);
  });
}

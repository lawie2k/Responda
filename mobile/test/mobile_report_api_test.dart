import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:responda/features/onboarding/data/mobile_account_api.dart';
import 'package:responda/features/reporting/data/mobile_report_api.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';

void main() {
  test(
    'submits the authenticated app report and parses server receipt',
    () async {
      final api = MobileAccountApi(
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/mobile/reports');
          expect(request.headers['authorization'], 'Bearer mobile-session');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['client_report_id'], 'client-uuid');
          expect(body['incident_type_code'], 'road_accident');
          expect(body['people_need_help'], isTrue);
          expect(body['latitude'], 7.135421);
          expect(body['longitude'], 125.9123);
          return http.Response(
            jsonEncode({
              'report_id': 'server-report-uuid',
              'client_report_id': 'client-uuid',
              'verification_status': 'pending',
              'report_status': 'new',
              'received_at': '2026-10-20T05:00:00Z',
            }),
            201,
          );
        }),
      );
      final receipt = await MobileReportApi(api).submit(
        token: 'mobile-session',
        clientReportId: 'client-uuid',
        draft: const ReportDraft(
          incidentType: IncidentType.accident,
          latitude: 7.135421,
          longitude: 125.9123,
          locationAccuracy: 8,
          landmark: 'Kingking Highway',
          description: 'A person needs help near the highway.',
          morePeople: true,
        ),
      );
      expect(receipt.reportId, 'server-report-uuid');
      expect(receipt.receivedAt, DateTime.utc(2026, 10, 20, 5));
      api.close();
    },
  );

  test('client report IDs are UUID v4 values', () {
    final id = MobileReportApi.createClientReportId();
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}

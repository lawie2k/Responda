import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responda/features/onboarding/data/mobile_account_api.dart';
import 'package:responda/features/reporting/data/mobile_report_api.dart';
import 'package:responda/features/reporting/data/online_report_store.dart';

void main() {
  const id = '00000000-0000-4000-8000-000000000401';
  Map<String, Object> tracking(String status) => {
    'report_id': id,
    'incident_type_code': 'fire',
    'description': 'Synthetic report.',
    'landmark': 'Synthetic location',
    'received_at': '2026-10-21T01:00:00Z',
    'updated_at': '2026-10-21T01:08:00Z',
    'tracking_status': status,
    'milestones': {
      'received': '2026-10-21T01:00:00Z',
      'responding': '2026-10-21T01:08:00Z',
    },
  };

  test(
    'list and detail use private bearer reads and preserve server times',
    () async {
      final requests = <Uri>[];
      final api = MobileAccountApi(
        baseUrl: 'http://localhost:8000',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer mobile_synthetic');
          requests.add(request.url);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith(id)
                  ? tracking('responding')
                  : {
                      'items': [tracking('resolved')],
                      'page': 2,
                      'total': 21,
                      'total_pages': 2,
                      'active_count': 3,
                    },
            ),
            200,
          );
        }),
      );
      final service = MobileReportApi(api);
      final page = await service.list(
        token: 'mobile_synthetic',
        completed: true,
        page: 2,
      );
      expect(page.items.single.status, OnlineReportStatus.resolved);
      expect(page.activeCount, 3);
      expect(requests.first.queryParameters, {
        'category': 'completed',
        'page': '2',
        'page_size': '20',
      });
      final report = await service.tracking(
        token: 'mobile_synthetic',
        reportId: id,
      );
      expect(report.status, OnlineReportStatus.responding);
      expect(report.updatedAt!.toUtc(), DateTime.utc(2026, 10, 21, 1, 8));
      expect(
        report.milestones['responding']!.toUtc(),
        report.updatedAt!.toUtc(),
      );
      expect(report.milestones.containsKey('resolved'), false);
      expect(requests.last.path, '/api/v1/mobile/reports/$id');
      api.close();
    },
  );

  test(
    'unknown server status fails rather than claiming a verification state',
    () {
      expect(
        () => MobileReportApi.trackingReport(
          Map<String, dynamic>.from(tracking('unknown')),
        ),
        throwsFormatException,
      );
    },
  );
}

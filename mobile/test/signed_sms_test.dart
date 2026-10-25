import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:responda/features/reporting/data/signed_sms.dart';
import 'package:responda/features/reporting/data/offline_report_store.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';

void main() {
  final vector =
      jsonDecode(File('test/fixtures/rsp1.json').readAsStringSync()) as Map;
  final setup = SmsSetup(
    deviceId: vector['device'] as String,
    owner: '+639000000001',
    backend: 'https://example.invalid',
    key: vector['key'] as String,
    gateway: '+639000000002',
    expiresAt: DateTime.now().add(const Duration(days: 1)),
  );
  const draft = ReportDraft(
    incidentType: IncidentType.fire,
    description: 'Synthetic smoke report: ñ is preserved.',
    landmark: 'Synthetic test area',
    latitude: 7.1,
    longitude: 125.9,
    locationAccuracy: 8.0,
    morePeople: true,
    additionalAssistance: false,
    stillDangerous: true,
  );
  test(
    'Dart signing matches the Python protocol vector including UTF8 and tag',
    () {
      final body = signSms(
        setup: setup,
        draft: draft,
        clientId: vector['client'] as String,
        createdAt: DateTime.parse(vector['created'] as String),
      );
      expect(body, vector['body']);
      expect(body, isNot(contains(vector['key'] as String)));
    },
  );
  test(
    'SMS preserves stable UUID and signed bytes across saved-report retries',
    () async {
      SharedPreferences.setMockInitialValues({});
      final id = vector['client'] as String;
      const store = OfflineReportStore();
      final first = await store.save(
        draft.copyWith(clientReportId: id),
        signedMessage: vector['body'] as String,
        smsRecipient: setup.gateway,
      );
      final again = await store.save(
        draft.copyWith(clientReportId: id),
        signedMessage: 'changed',
      );
      expect(again.signedMessage, first.signedMessage);
      expect((await store.loadAll()).single.draft.clientReportId, id);
    },
  );
  test('missing setup, expired keys, invalid locations, photos and oversized details fail closed', () {
    for (final invalid in [
      draft.copyWith(description: 'short'),
      draft.copyWith(description: 'x' * 301),
      draft.copyWith(photoPath: 'synthetic.jpg'),
      const ReportDraft(
        incidentType: IncidentType.fire,
        description: 'Synthetic text without location',
      ),
    ]) {
      expect(
        () => signSms(
          setup: setup,
          draft: invalid,
          clientId: vector['client'] as String,
          createdAt: DateTime.now(),
        ),
        throwsException,
      );
    }
    final expired = SmsSetup(
      deviceId: setup.deviceId,
      owner: setup.owner,
      backend: setup.backend,
      key: setup.key,
      gateway: setup.gateway,
      expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(
      () => signSms(
        setup: expired,
        draft: draft,
        clientId: vector['client'] as String,
        createdAt: DateTime.now(),
      ),
      throwsException,
    );
  });
}

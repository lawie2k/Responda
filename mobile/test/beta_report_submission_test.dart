import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responda/core/config/beta_features.dart';
import 'package:responda/core/network/responda_api_client.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/data/mobile_account_api.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';

import 'support/mobile_account_fakes.dart';

class _AccountStore implements AccountStore {
  AccountProfile? profile;
  @override
  Future<AccountProfile?> read() async => profile;
  @override
  Future<void> write(AccountProfile value) async => profile = value;
  @override
  Future<void> clear() async => profile = null;
}

void main() {
  const clientId = '00000000-0000-4000-8000-000000000101';
  const serverId = '00000000-0000-4000-8000-000000000102';
  final draft = ReportDraft(
    incidentType: IncidentType.fire,
    description: 'Synthetic report for automated verification.',
    landmark: 'Synthetic test area',
  );

  test(
    'beta submission obtains a session once and restores it without OTP',
    () async {
      final calls = <String>[];
      final expiresAt = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String();
      final response = {
        'access_token': 'mobile_beta_synthetic',
        'expires_at': expiresAt,
        'user': {
          'phone_number': null,
          'phone_verified_at': null,
          'privacy_notice_accepted_at': '2026-10-20T09:00:00Z',
          'full_name': 'Synthetic tester',
          'barangay': 'Kingking',
        },
      };
      final client = MockClient((request) async {
        calls.add(request.url.path);
        if (request.url.path.endsWith('/beta/register')) {
          final body = jsonDecode(request.body) as Map;
          expect(body['privacy_notice_accepted'], isTrue);
          expect(body['full_name'], 'Synthetic tester');
          expect(body.containsKey('phone_number'), isFalse);
          return http.Response(jsonEncode(response), 201);
        }
        expect(
          request.headers['Authorization'],
          'Bearer mobile_beta_synthetic',
        );
        if (request.url.path.endsWith('/me')) {
          return http.Response(jsonEncode(response), 200);
        }
        return http.Response(
          jsonEncode({
            'report_id': serverId,
            'received_at': '2026-10-20T09:00:00Z',
          }),
          201,
        );
      });
      final store = _AccountStore();
      final tokens = MemoryTokenStore();
      AccountController controller() => AccountController(
        store: store,
        tokenStore: tokens,
        api: MobileAccountApi(client: client),
      );
      final first = controller();
      addTearDown(first.dispose);
      await first.completeBetaProfile(
        privacyNoticeAcceptedAt: DateTime.now(),
        fullName: 'Synthetic tester',
        barangay: 'Kingking',
      );
      final receipt = await first.submitReport(draft, clientReportId: clientId);
      expect(receipt.reportId, serverId);
      expect(await tokens.read(), 'mobile_beta_synthetic');
      expect(first.profile?.status, AccountVerificationStatus.pending);
      expect(first.profile?.isBetaLocal, isFalse);
      final restarted = controller();
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.hasAccount, isTrue);
      await restarted.submitReport(draft, clientReportId: clientId);
      expect(calls.where((path) => path.endsWith('/beta/register')).length, 1);
      expect(calls.any((path) => path.contains('/otp/')), isFalse);
    },
    skip: !betaSkipMobileVerification,
  );

  test(
    'disabled beta registration never sends a report or claims verification',
    () async {
      final calls = <String>[];
      final client = MockClient((request) async {
        calls.add(request.url.path);
        return http.Response(
          '{"error":{"message":"Beta registration is unavailable."}}',
          403,
        );
      });
      final tokens = MemoryTokenStore();
      final controller = AccountController(
        store: _AccountStore(),
        tokenStore: tokens,
        api: MobileAccountApi(client: client),
      );
      addTearDown(controller.dispose);
      await controller.completeBetaProfile(
        privacyNoticeAcceptedAt: DateTime.now(),
      );
      await expectLater(
        controller.submitReport(draft, clientReportId: clientId),
        throwsA(isA<RespondaApiException>()),
      );
      expect(await tokens.read(), isNull);
      expect(controller.profile?.status, AccountVerificationStatus.pending);
      expect(calls.any((path) => path.endsWith('/reports')), isFalse);
      expect(calls.length, betaSkipMobileVerification ? 1 : 0);
    },
  );
}

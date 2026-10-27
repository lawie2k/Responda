import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:responda/core/network/responda_api_client.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/reporting/data/signed_sms.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';

import 'support/mobile_account_fakes.dart';

class _Accounts implements AccountStore {
  AccountProfile? value;
  @override
  Future<AccountProfile?> read() async => value;
  @override
  Future<void> write(AccountProfile profile) async {
    value = profile;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _Keys implements SmsKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    value = data;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _Api extends FakeMobileAccountApi {
  bool configured = true;
  int? failure;
  String origin = 'https://synthetic.invalid';
  @override
  String get baseUrl => origin;
  final calls = <String>[];
  final revoked = <String>[];
  @override
  Future<Map<String, dynamic>> smsDevice(
    String deviceId, {
    required String token,
    bool revoke = false,
  }) async {
    if (revoke) {
      revoked.add(deviceId);
      return {};
    }
    calls.add(deviceId);
    if (failure != null) {
      throw RespondaApiException('Synthetic failure', statusCode: failure);
    }
    final vector =
        jsonDecode(File('test/fixtures/rsp1.json').readAsStringSync()) as Map;
    return {
      'device_id': deviceId,
      'signing_key': vector['key'],
      'gateway_number': configured ? '+639000000002' : null,
      'expires_at': DateTime.now()
          .add(const Duration(days: 180))
          .toIso8601String(),
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const phone = '+639000000001';
  const draft = ReportDraft(
    incidentType: IncidentType.fire,
    description: 'Synthetic signed offline report.',
    landmark: 'Synthetic area',
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'setup stores keys securely, restores offline and revokes before logout',
    () async {
      final api = _Api();
      final keys = _Keys();
      final accounts = _Accounts();
      final tokens = MemoryTokenStore();
      AccountController make() => AccountController(
        api: api,
        store: accounts,
        tokenStore: tokens,
        smsKeyStore: keys,
      );
      final account = make();
      await account.sendCode(phone);
      await account.verifyCode(phone, '123456');
      await account.enableOfflineSms();
      expect(account.offlineSmsReady, isTrue);
      final saved = await account.saveSignedOfflineReport(draft);
      expect(saved.signedMessage, startsWith('RSP1.'));
      final key = SmsSetup.decode(keys.value!).key!;
      expect(jsonEncode(saved.toJson()), isNot(contains(key)));
      expect(jsonEncode(accounts.value!.toJson()), isNot(contains(key)));
      final restarted = make();
      await restarted.load();
      await restarted.restoreOfflineSms();
      expect(restarted.offlineSmsReady, isTrue);
      await restarted.clearLocalSession();
      expect(api.revoked, [api.calls.single]);
      expect(keys.value, isNull);
      account.dispose();
      restarted.dispose();
    },
  );
  test(
    'unconfigured gateway can retry setup without allocating another device ID',
    () async {
      final api = _Api()..configured = false;
      final keys = _Keys();
      final account = AccountController(
        api: api,
        store: _Accounts(),
        tokenStore: MemoryTokenStore(),
        smsKeyStore: keys,
      );
      addTearDown(account.dispose);
      await account.sendCode(phone);
      await account.verifyCode(phone, '123456');
      await expectLater(account.enableOfflineSms(), throwsException);
      expect(account.offlineSmsReady, isFalse);
      api.configured = true;
      await account.enableOfflineSms();
      expect(api.calls.toSet(), hasLength(1));
      expect(account.offlineSmsReady, isTrue);
      api.origin = 'https://different.invalid';
      expect(account.offlineSmsReady, isFalse);
      await expectLater(
        account.saveSignedOfflineReport(draft),
        throwsException,
      );
    },
  );
  test('network failure preserves cached SMS setup but revoked credentials clear it', () async {
    final api = _Api();
    final keys = _Keys();
    final account = AccountController(
      api: api,
      store: _Accounts(),
      tokenStore: MemoryTokenStore(),
      smsKeyStore: keys,
    );
    addTearDown(account.dispose);
    await account.sendCode(phone);
    await account.verifyCode(phone, '123456');
    await account.enableOfflineSms();
    api.failure = 503;
    await expectLater(account.enableOfflineSms(), throwsException);
    expect(account.offlineSmsReady, isTrue);
    api.failure = 409;
    await expectLater(account.enableOfflineSms(), throwsException);
    expect(account.offlineSmsReady, isFalse);
    expect(keys.value, isNull);
  });

  test('beta profiles cannot provision or send signed SMS', () async {
    final api = _Api();
    final account = AccountController(
      api: api,
      store: _Accounts(),
      tokenStore: MemoryTokenStore(),
      smsKeyStore: _Keys(),
    );
    addTearDown(account.dispose);
    await account.completeBetaProfile(
      privacyNoticeAcceptedAt: DateTime.now(),
      fullName: 'SMS Tester',
      barangay: 'Kingking',
    );
    await expectLater(account.enableOfflineSms(), throwsException);
    await expectLater(account.saveSignedOfflineReport(draft), throwsException);
    expect(api.calls, isEmpty);
  });
}

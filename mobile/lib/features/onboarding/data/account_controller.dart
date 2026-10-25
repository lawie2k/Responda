import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:responda/core/config/beta_features.dart';

import '../../../core/network/api_config.dart';
import '../../reporting/data/signed_sms.dart';
import '../../reporting/data/offline_report_store.dart';

import '../domain/account_profile.dart';
import '../../../core/network/responda_api_client.dart';
import 'identity_otp_service.dart';
import 'mobile_account_api.dart';
import '../../reporting/data/mobile_report_api.dart';
import '../../reporting/data/online_report_store.dart';
import '../../reporting/domain/models/report_draft.dart';

abstract interface class AccountStore {
  Future<AccountProfile?> read();

  Future<void> write(AccountProfile profile);

  Future<void> clear();
}

class SharedPreferencesAccountStore implements AccountStore {
  SharedPreferencesAccountStore({SharedPreferencesAsync? client})
    : _preferences = client;

  static const _accountKey = 'responda_account_profile_v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _client =>
      _preferences ?? SharedPreferencesAsync();

  @override
  Future<AccountProfile?> read() async {
    final encoded = await _client.getString(_accountKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return AccountProfile.fromJson(
        Map<String, Object?>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(AccountProfile profile) {
    return _client.setString(_accountKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<void> clear() => _client.remove(_accountKey);
}

class AccountController extends ChangeNotifier implements IdentityOtpService {
  AccountController({
    AccountStore? store,
    MobileAccountApi? api,
    SessionTokenStore? tokenStore,
    SmsKeyStore? smsKeyStore,
  }) : _store = store ?? SharedPreferencesAccountStore(),
       _api = api ?? MobileAccountApi(),
       _tokenStore = tokenStore ?? SecureSessionTokenStore(),
       _smsStore = smsKeyStore ?? SecureSmsKeyStore();

  final AccountStore _store;
  final MobileAccountApi _api;
  final SessionTokenStore _tokenStore;
  final SmsKeyStore _smsStore;
  SmsSetup? _sms;
  Future<void>? _smsProvisioning;
  String get _smsBackend => _api.baseUrl ?? ApiConfig.baseUrl;
  bool get offlineSmsReady =>
      _sms?.ready == true &&
      _sms?.owner == _profile?.phoneNumber &&
      _sms?.backend == _smsBackend;
  String? _token;
  String? _challengeId;
  String? developmentCode;
  DateTime? resendAt;
  String? resendPhoneNumber;
  DateTime? _expiresAt;

  AccountProfile? _profile;
  bool _isLoaded = false;

  AccountProfile? get profile => _profile;
  bool get hasAccount =>
      _profile?.isBetaLocal == true ||
      (_profile != null &&
          _token != null &&
          (_expiresAt?.isAfter(DateTime.now()) ?? false));
  bool get isLoaded => _isLoaded;

  Future<void> refreshSession() async {
    if (_token == null) return;
    if (!(_expiresAt?.isAfter(DateTime.now()) ?? false)) {
      await _discard();
      notifyListeners();
      return;
    }
    try {
      await _accept(await _api.request('me', token: _token));
    } on RespondaApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _discard();
        notifyListeners();
      }
    } catch (_) {
      // Network loss must not erase a valid cached account used by offline screens.
    }
  }

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }
    try {
      _token = await _tokenStore.read();
      final cached = await _store.read();
      _expiresAt = cached?.sessionExpiresAt;
      if (_token != null) {
        try {
          await _accept(await _api.request('me', token: _token));
        } on RespondaApiException catch (error) {
          if (error.statusCode == 401 || error.statusCode == 403) {
            await _discard();
          } else {
            _profile = cached;
          }
        } catch (_) {
          // Cached identity supports offline UI only; API authorization stays server-side.
          _profile = cached;
        }
      } else {
        if (cached?.isBetaLocal == true) {
          _profile = cached;
        } else {
          await _store.clear();
        }
      }
    } catch (_) {
      _profile = null;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  @override
  Future<void> sendCode(String phoneNumber) async {
    final result = await _api.request(
      'otp/request',
      method: 'POST',
      body: {'phone_number': phoneNumber},
    );
    _challengeId = result['challenge_id'] as String;
    developmentCode = result['development_code'] as String?;
    resendPhoneNumber = phoneNumber;
    resendAt = DateTime.now().add(
      Duration(seconds: result['resend_after_seconds'] as int),
    );
    notifyListeners();
  }

  @override
  Future<bool> verifyCode(String phoneNumber, String code) async {
    if (_challengeId == null) return false;
    final result = await _api.request(
      'otp/verify',
      method: 'POST',
      body: {
        'phone_number': phoneNumber,
        'challenge_id': _challengeId,
        'code': code,
        'privacy_notice_accepted': true,
      },
    );
    await _acceptLogin(result);
    _challengeId = null;
    developmentCode = null;
    resendAt = null;
    resendPhoneNumber = null;
    return true;
  }

  Future<void> _accept(Map<String, dynamic> result) async {
    final user = result['user'] as Map;
    final verifiedAt = user['phone_verified_at'] as String?;
    _expiresAt = DateTime.parse(result['expires_at'] as String);
    final profile = AccountProfile(
      phoneNumber: user['phone_number'] as String? ?? '',
      status: verifiedAt == null
          ? AccountVerificationStatus.pending
          : AccountVerificationStatus.verified,
      submittedAt: DateTime.parse(
        verifiedAt ?? user['privacy_notice_accepted_at'] as String,
      ),
      privacyNoticeAcceptedAt: DateTime.parse(
        user['privacy_notice_accepted_at'] as String,
      ),
      fullName: user['full_name'] as String,
      barangay: user['barangay'] as String? ?? '',
      sessionExpiresAt: _expiresAt,
    );
    await _store.write(profile);
    _profile = profile;
    notifyListeners();
  }

  Future<void> _acceptLogin(Map<String, dynamic> result) async {
    final token = result['access_token'] as String;
    await _tokenStore.write(token);
    _token = token;
    await _accept(result);
  }

  Future<void> completePhoneVerification({
    required String phoneNumber,
    required DateTime privacyNoticeAcceptedAt,
    String fullName = '',
    String barangay = '',
  }) async {
    if (_token == null || _profile?.phoneNumber != phoneNumber) {
      throw const RespondaApiException('Verify your phone number first.');
    }
    await _accept(
      await _api.request(
        'profile',
        method: 'PATCH',
        token: _token,
        body: {'full_name': fullName.trim(), 'barangay': barangay.trim()},
      ),
    );
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> completeBetaProfile({
    required DateTime privacyNoticeAcceptedAt,
    String fullName = '',
    String barangay = '',
  }) async {
    final profile = AccountProfile(
      phoneNumber: '',
      status: AccountVerificationStatus.pending,
      submittedAt: DateTime.now(),
      privacyNoticeAcceptedAt: privacyNoticeAcceptedAt,
      fullName: fullName.trim(),
      barangay: barangay.trim(),
      isBetaLocal: true,
    );
    await _store.write(profile);
    _profile = profile;
    _isLoaded = true;
    notifyListeners();
  }

  Future<MobileReportReceipt> submitReport(
    ReportDraft draft, {
    required String clientReportId,
  }) async {
    if (draft.photoPath != null) {
      throw const RespondaApiException(
        'Remove the attached photo to submit this report. Photo uploads are not available yet.',
      );
    }
    final profile = _profile;
    if (betaSkipMobileVerification &&
        profile?.isBetaLocal == true &&
        _token == null) {
      await _acceptLogin(
        await _api.request(
          'beta/register',
          method: 'POST',
          body: {
            'full_name': profile!.fullName,
            'barangay': profile.barangay,
            'privacy_notice_accepted': true,
          },
        ),
      );
    }
    final token = _token;
    if (!hasAccount || token == null) {
      throw const RespondaApiException('Sign in with your phone number first.');
    }
    return MobileReportApi(_api)
        .submit(token: token, clientReportId: clientReportId, draft: draft);
  }

  Future<void> restoreOfflineSms() => _restoreSms();

  Future<void> _restoreSms() async {
    if (_profile?.status != AccountVerificationStatus.verified) return;
    try {
      final stored = await _smsStore.read();
      if (stored != null) _sms = SmsSetup.decode(stored);
    } catch (_) {
      _sms = null;
    }
  }

  Future<void> enableOfflineSms() {
    return _smsProvisioning ??= _enableOfflineSms().whenComplete(
      () => _smsProvisioning = null,
    );
  }

  Future<void> _enableOfflineSms() async {
    final token = _token;
    final phone = _profile?.phoneNumber;
    if (token == null ||
        _profile?.status != AccountVerificationStatus.verified ||
        phone == null) {
      throw const RespondaApiException(
        'Verify your phone number online before setting up Offline SMS.',
      );
    }
    await _restoreSms();
    final previous = _sms;
    final reuse =
        previous?.owner == phone &&
        previous?.backend == _smsBackend &&
        (previous?.expiresAt == null ||
            previous!.expiresAt!.isAfter(DateTime.now()));
    _sms = reuse
        ? previous!
        : SmsSetup(
            deviceId: reuse
                ? previous!.deviceId
                : MobileReportApi.createClientReportId(),
            owner: phone,
            backend: _smsBackend,
          );
    await _smsStore.write(_sms!.encode());
    late final Map<String, dynamic> result;
    try {
      result = await _api.smsDevice(_sms!.deviceId, token: token);
    } on RespondaApiException catch (error) {
      if ([401, 403, 409].contains(error.statusCode)) {
        await _smsStore.clear();
        _sms = null;
        notifyListeners();
      }
      rethrow;
    }
    if (_token != token || _profile?.phoneNumber != phone) {
      throw const RespondaApiException(
        'Your account changed. Set up Offline SMS again.',
      );
    }
    _sms = SmsSetup(
      deviceId: result['device_id'] as String,
      owner: phone,
      backend: _smsBackend,
      key: result['signing_key'] as String,
      gateway: result['gateway_number'] as String?,
      expiresAt: DateTime.parse(result['expires_at'] as String),
    );
    await _smsStore.write(_sms!.encode());
    notifyListeners();
    if (!offlineSmsReady) {
      throw const RespondaApiException(
        'MDRRMO has not configured an active SMS gateway yet. Try setup again after it is configured.',
      );
    }
  }

  Future<SavedOfflineReport> saveSignedOfflineReport(ReportDraft draft) async {
    await _restoreSms();
    if (!offlineSmsReady ||
        _profile?.status != AccountVerificationStatus.verified) {
      await const OfflineReportStore().save(draft);
      throw const RespondaApiException(
        'A copy is saved on this phone. Connect online and set up Offline SMS in Account Management before sending it.',
      );
    }
    final clientId =
        draft.clientReportId ?? MobileReportApi.createClientReportId();
    final createdAt = DateTime.now().toUtc();
    final body = signSms(
      setup: _sms!,
      draft: draft,
      clientId: clientId,
      createdAt: createdAt,
    );
    return const OfflineReportStore().save(
      draft.copyWith(clientReportId: clientId),
      signedMessage: body,
      smsRecipient: _sms!.gateway,
      createdAt: createdAt,
    );
  }

  Future<SavedOfflineReport> prepareSmsRetry(SavedOfflineReport report) async {
    if (report.signedMessage == null) {
      return saveSignedOfflineReport(report.draft);
    }
    await _restoreSms();
    final device = _sms?.deviceId.replaceAll('-', '').toLowerCase();
    if (!offlineSmsReady ||
        _profile?.status != AccountVerificationStatus.verified ||
        !report.signedMessage!.startsWith('RSP1.$device.')) {
      throw const RespondaApiException(
        'This SMS belongs to another or expired setup. Sign in to the original account or create a new report.',
      );
    }
    if (DateTime.now().difference(report.savedAt).inSeconds >
        const Duration(days: 7).inSeconds) {
      throw const RespondaApiException(
        'This saved SMS has expired. Create a new report with current emergency details.',
      );
    }
    return report;
  }

  Future<void> clearLocalSession() async {
    try {
      await _smsProvisioning;
    } catch (_) {
      /* Keep logout usable after setup failure. */
    }
    final token = _token;
    if (token != null) {
      if (_sms != null &&
          _sms!.owner == _profile?.phoneNumber &&
          _sms!.backend == _smsBackend) {
        try {
          await _api.smsDevice(_sms!.deviceId, token: token, revoke: true);
        } on RespondaApiException catch (error) {
          if (![401, 403, 404].contains(error.statusCode)) rethrow;
        }
      }
      try {
        await _api.request('logout', method: 'POST', token: token);
      } on RespondaApiException catch (error) {
        if (error.statusCode != 401) rethrow;
      }
    }
    await _discard();
    notifyListeners();
  }

  Future<MobileReportsPage> fetchReports({
    bool completed = false,
    int page = 1,
  }) async {
    final token = _token;
    if (token == null && _profile?.isBetaLocal == true) {
      return const MobileReportsPage();
    }
    if (!hasAccount || token == null) {
      throw const RespondaApiException(
        'Sign in to track your reports.',
        statusCode: 401,
      );
    }
    return MobileReportApi(_api)
        .list(token: token, completed: completed, page: page);
  }

  Future<SavedOnlineReport> fetchReport(String reportId) async {
    final token = _token;
    if (!hasAccount || token == null) {
      throw const RespondaApiException(
        'Sign in to track your reports.',
        statusCode: 401,
      );
    }
    return MobileReportApi(_api).tracking(token: token, reportId: reportId);
  }

  Future<void> _discard() async {
    _profile = null;
    _token = null;
    _expiresAt = null;
    _challengeId = null;
    developmentCode = null;
    _isLoaded = true;
    try {
      await _smsProvisioning;
    } catch (_) {
      /* Invalidate an in-flight setup before clearing keys. */
    }
    if (_sms != null) await _smsStore.clear();
    _sms = null;
    await _tokenStore.clear();
    await _store.clear();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }
}

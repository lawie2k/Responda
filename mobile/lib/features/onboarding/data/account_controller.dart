import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:responda/core/config/beta_features.dart';

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
  }) : _store = store ?? SharedPreferencesAccountStore(),
       _api = api ?? MobileAccountApi(),
       _tokenStore = tokenStore ?? SecureSessionTokenStore();

  final AccountStore _store;
  final MobileAccountApi _api;
  final SessionTokenStore _tokenStore;
  String? _token;
  String? _challengeId;
  String? developmentCode;
  DateTime? resendAt;
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

  Future<void> clearLocalSession() async {
    final token = _token;
    if (token != null) {
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
    await _tokenStore.clear();
    await _store.clear();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }
}

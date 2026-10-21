import 'package:responda/features/onboarding/data/mobile_account_api.dart';

class MemoryTokenStore implements SessionTokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String token) async {
    this.token = token;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class FakeMobileAccountApi extends MobileAccountApi {
  String fullName = '';
  String barangay = '';
  String phone = '';
  String? verifiedCode;
  @override
  Future<Map<String, dynamic>> readReports({
    required String token,
    String? reportId,
    bool completed = false,
    int page = 1,
  }) async => {
    'items': [],
    'total': 0,
    'page': page,
    'total_pages': 0,
    'active_count': 0,
  };
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    String? token,
    Map<String, Object?>? body,
  }) async {
    if (path == 'otp/request') {
      phone = body!['phone_number'] as String;
      return {
        'challenge_id': 'synthetic-challenge',
        'resend_after_seconds': 60,
        'development_code': '123456',
      };
    }
    if (path == 'otp/verify') {
      verifiedCode = body!['code'] as String;
    }
    if (path == 'profile') {
      fullName = body!['full_name'] as String;
      barangay = body['barangay'] as String;
    }
    return {
      'access_token': 'mobile_synthetic_token',
      'expires_at': DateTime.now()
          .add(const Duration(days: 30))
          .toUtc()
          .toIso8601String(),
      'user': {
        'phone_number': phone,
        'full_name': fullName,
        'barangay': barangay,
        'phone_verified_at': '2026-10-08T09:30:00.000',
        'privacy_notice_accepted_at': '2026-10-08T09:30:00.000',
      },
    };
  }
}

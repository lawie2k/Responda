abstract interface class IdentityOtpService {
  Future<void> sendCode(String phoneNumber);

  Future<bool> verifyCode(String phoneNumber, String code);
}

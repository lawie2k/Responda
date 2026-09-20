abstract interface class IdentityOtpService {
  Future<void> sendCode(String phoneNumber);

  Future<bool> verifyCode(String phoneNumber, String code);
}

class PrototypeIdentityOtpService implements IdentityOtpService {
  const PrototypeIdentityOtpService();

  static const verificationCode = '123456';

  @override
  Future<void> sendCode(String phoneNumber) async {}

  @override
  Future<bool> verifyCode(String phoneNumber, String code) async {
    return code == verificationCode;
  }
}

enum AccountVerificationStatus {
  pending,
  verified,
  rejected;

  String get label => switch (this) {
    pending => 'Pending verification',
    verified => 'Phone verified',
    rejected => 'Needs attention',
  };

  static AccountVerificationStatus fromName(String? value) {
    return AccountVerificationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AccountVerificationStatus.pending,
    );
  }
}

class AccountProfile {
  const AccountProfile({
    required this.phoneNumber,
    required this.status,
    required this.submittedAt,
    required this.privacyNoticeAcceptedAt,
    this.fullName = '',
    this.barangay = '',
    this.sessionExpiresAt,
  });

  final String phoneNumber;
  final AccountVerificationStatus status;
  final DateTime submittedAt;
  final DateTime privacyNoticeAcceptedAt;
  final String fullName;
  final String barangay;
  final DateTime? sessionExpiresAt;

  Map<String, Object?> toJson() => {
    'phoneNumber': phoneNumber,
    'status': status.name,
    'submittedAt': submittedAt.toIso8601String(),
    'privacyNoticeAcceptedAt': privacyNoticeAcceptedAt.toIso8601String(),
    'fullName': fullName,
    'barangay': barangay,
    'sessionExpiresAt': sessionExpiresAt?.toIso8601String(),
  };

  factory AccountProfile.fromJson(Map<String, Object?> json) {
    final submittedAt =
        DateTime.tryParse(json['submittedAt'] as String? ?? '') ??
        DateTime.now();
    final storedStatus = AccountVerificationStatus.fromName(
      json['status'] as String?,
    );
    final isLegacyIdentityProfile =
        json.containsKey('idSubmitted') || json.containsKey('faceCaptured');
    return AccountProfile(
      phoneNumber: json['phoneNumber'] as String? ?? '',
      status:
          isLegacyIdentityProfile &&
              storedStatus == AccountVerificationStatus.pending
          ? AccountVerificationStatus.verified
          : storedStatus,
      submittedAt: submittedAt,
      privacyNoticeAcceptedAt:
          DateTime.tryParse(json['privacyNoticeAcceptedAt'] as String? ?? '') ??
          submittedAt,
      fullName: json['fullName'] as String? ?? '',
      barangay: json['barangay'] as String? ?? '',
      sessionExpiresAt: DateTime.tryParse(
        json['sessionExpiresAt'] as String? ?? '',
      ),
    );
  }
}

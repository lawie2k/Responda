enum AccountVerificationStatus {
  pending,
  verified,
  rejected;

  String get label => switch (this) {
    pending => 'Pending verification',
    verified => 'Verified',
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
    required this.idSubmitted,
    required this.faceCaptured,
  });

  final String phoneNumber;
  final AccountVerificationStatus status;
  final DateTime submittedAt;
  final bool idSubmitted;
  final bool faceCaptured;

  Map<String, Object?> toJson() => {
    'phoneNumber': phoneNumber,
    'status': status.name,
    'submittedAt': submittedAt.toIso8601String(),
    'idSubmitted': idSubmitted,
    'faceCaptured': faceCaptured,
  };

  factory AccountProfile.fromJson(Map<String, Object?> json) {
    return AccountProfile(
      phoneNumber: json['phoneNumber'] as String? ?? '',
      status: AccountVerificationStatus.fromName(json['status'] as String?),
      submittedAt:
          DateTime.tryParse(json['submittedAt'] as String? ?? '') ??
          DateTime.now(),
      idSubmitted: json['idSubmitted'] as bool? ?? false,
      faceCaptured: json['faceCaptured'] as bool? ?? false,
    );
  }
}

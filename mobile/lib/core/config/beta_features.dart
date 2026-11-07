const bool betaSkipMobileVerification = bool.fromEnvironment(
  'RESPONDA_BETA_SKIP_MOBILE_VERIFICATION',
  defaultValue: false,
);

/// Shows the OTP screen without contacting the authentication backend.
/// Enable only for a local UI preview with --dart-define.
const bool otpUiPreviewMode = bool.fromEnvironment(
  'RESPONDA_OTP_UI_PREVIEW',
  defaultValue: false,
);

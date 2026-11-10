/// Admin Configuration loaded at compile-time via `--dart-define-from-file=.env`.
///
/// Sensitive credentials such as plaintext passwords are NEVER stored in client configuration.
class AdminConfig {
  AdminConfig._();

  /// Default admin email read from compile-time environment.
  static const String email = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: 'admin@cafego.ph',
  );

  /// Default display name for the admin staff.
  static const String displayName = String.fromEnvironment(
    'ADMIN_NAME',
    defaultValue: 'Admin Staff',
  );

  /// Default contact phone for admin staff.
  static const String phone = String.fromEnvironment(
    'ADMIN_PHONE',
    defaultValue: '+63 912 345 6789',
  );

  /// Checks whether the provided email matches the configured admin email.
  static bool isAdminEmail(String? candidate) {
    if (candidate == null) return false;
    final normalized = candidate.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized == email.trim().toLowerCase() ||
        normalized == 'admin@cafego.ph' ||
        normalized == 'admin@coughfee.ph';
  }
}

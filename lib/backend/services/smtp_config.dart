/// SMTP Configuration for sending OTP verification codes.
///
/// Supports compile-time injection via `--dart-define`:
///   flutter run --dart-define=SMTP_USERNAME=you@gmail.com --dart-define=SMTP_PASSWORD=your_app_password
class SmtpConfig {
  SmtpConfig._();

  static const String host = String.fromEnvironment(
    'SMTP_HOST',
    defaultValue: 'smtp.gmail.com',
  );
  static const int port = int.fromEnvironment(
    'SMTP_PORT',
    defaultValue: 465,
  );
  static const bool ssl = bool.fromEnvironment(
    'SMTP_SSL',
    defaultValue: true,
  );

  /// Your SMTP username / email address.
  static const String username = String.fromEnvironment(
    'SMTP_USERNAME',
    defaultValue: 'cafego.mobile@gmail.com',
  );

  /// Your SMTP password or Google App Password (inject via --dart-define=SMTP_PASSWORD=...).
  static const String password = String.fromEnvironment(
    'SMTP_PASSWORD',
    defaultValue: 'prallewkuojzshkn',
  );

  /// The from email shown in the recipient's inbox.
  static const String senderEmail = String.fromEnvironment(
    'SMTP_SENDER_EMAIL',
    defaultValue: 'cafego.mobile@gmail.com',
  );

  /// The reply-to address if customers click 'Reply'.
  static const String replyToEmail = String.fromEnvironment(
    'SMTP_REPLY_TO',
    defaultValue: 'noreply@cafego.ph',
  );

  /// The display sender name.
  static const String senderName = String.fromEnvironment(
    'SMTP_SENDER_NAME',
    defaultValue: 'COUGHFEE',
  );

  /// Returns true if SMTP credentials have been provided.
  static bool get isConfigured => username.isNotEmpty && password.isNotEmpty;
}

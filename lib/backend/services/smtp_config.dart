/// SMTP Configuration for sending OTP verification codes.
///
/// Setup guide:
/// 1. Gmail:
///    - Set [host] to 'smtp.gmail.com' and [port] to 587 (or 465 with [ssl] = true).
///    - Set [username] to your Gmail address.
///    - Set [password] to your 16-character Google App Password
///      (Generate at: https://myaccount.google.com/apppasswords).
/// 2. SendGrid / Brevo / Mailgun / Outlook:
///    - Set [host] to your provider's SMTP host.
///    - Set [port] to 587 or 465.
///    - Set [username] and [password] to your SMTP API key / credentials.
class SmtpConfig {
  SmtpConfig._();

  static const String host = 'smtp.gmail.com';
  static const int port = 465;
  static const bool ssl = true;

  /// Your SMTP username / email address.
  /// Replace with your sender email (e.g. 'coughfeecoffee@gmail.com').
  static const String username = 'cafego.mobile@gmail.com';

  /// Your SMTP password or Google App Password (16 characters, no spaces).
  /// Replace with your Google App Password or SMTP key.
  static const String password = 'prallewkuojzshkn';

  /// The from email shown in the recipient's inbox.
  /// Note: When using Gmail SMTP, this MUST match [username] (or a verified
  /// Google Send-As alias) so that SPF and DKIM pass and the email lands in
  /// the recipient's Inbox rather than Spam/Junk.
  static const String senderEmail = 'cafego.mobile@gmail.com';

  /// The reply-to address if customers click 'Reply'.
  static const String replyToEmail = 'noreply@cafego.ph';

  /// The display sender name.
  static const String senderName = 'COUGHFEE';

  /// Returns true if SMTP credentials have been provided.
  static bool get isConfigured => username.isNotEmpty && password.isNotEmpty;
}

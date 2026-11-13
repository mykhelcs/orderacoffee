import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'smtp_config.dart';

/// Service responsible for delivering 6-digit OTP verification codes via SMTP.
class SmtpService {
  SmtpService({
    Future<SendReport> Function(Message message, SmtpServer server)? sendFunction,
    String? username,
    String? password,
    String? senderEmail,
  })  : _sendFunction = sendFunction ?? send,
        _username = (username ?? SmtpConfig.username).trim(),
        _password = (password ?? SmtpConfig.cleanPassword).replaceAll(' ', '').trim(),
        _senderEmail = (senderEmail ?? SmtpConfig.senderEmail).trim();

  final Future<SendReport> Function(Message message, SmtpServer server) _sendFunction;
  final String _username;
  final String _password;
  final String _senderEmail;

  bool get _isConfigured => _username.isNotEmpty && _password.isNotEmpty;

  SmtpServer _resolvePrimarySmtpServer() {
    if (SmtpConfig.host.contains('gmail') && _username.isNotEmpty) {
      return gmail(_username, _password);
    }

    return SmtpServer(
      SmtpConfig.host,
      port: SmtpConfig.port,
      ssl: SmtpConfig.ssl,
      username: _username.isNotEmpty ? _username : null,
      password: _password.isNotEmpty ? _password : null,
      allowInsecure: false,
    );
  }

  SmtpServer _resolveFallbackSslServer() {
    return SmtpServer(
      SmtpConfig.host,
      port: 465,
      ssl: true,
      username: _username.isNotEmpty ? _username : null,
      password: _password.isNotEmpty ? _password : null,
      allowInsecure: false,
    );
  }

  /// Sends a 6-digit OTP code to [recipientEmail] via SMTP.
  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
  }) async {
    final cleanRecipient = recipientEmail.trim();

    if (kIsWeb) {
      debugPrint(
        '\n'
        '========================================================================\n'
        '[COUGHFEE Web Notice] Direct SMTP (raw TCP sockets) cannot run in browsers.\n'
        'Target Email: $cleanRecipient\n'
        'Verification Code: $otpCode\n'
        '\n'
        'To send real emails to your inbox via Gmail SMTP, run on Android:\n'
        '  flutter emulators --launch Medium_Phone_API_36.1\n'
        '  flutter run -d Medium_Phone_API_36.1\n'
        '========================================================================\n',
      );
      return true;
    }

    if (!_isConfigured) {
      debugPrint(
        '[SMTP Note] SMTP credentials not configured (check your .env file or --dart-define-from-file=.env). '
        'Email to $cleanRecipient will not be dispatched over network until credentials are provided.',
      );
      return false;
    }

    // When sending through Gmail, the 'From' address must be the authenticated
    // Gmail address to ensure SPF and DKIM alignment; otherwise destination
    // mail servers (Gmail, Yahoo, Outlook) mark the email as spam or discard it.
    final fromAddress = (SmtpConfig.host.contains('gmail') && _username.isNotEmpty)
        ? _username
        : (_senderEmail.isNotEmpty ? _senderEmail : _username);

    final message = Message()
      ..from = Address(fromAddress, SmtpConfig.senderName)
      ..recipients.add(cleanRecipient)
      ..subject = 'Your COUGHFEE Verification Code: $otpCode'
      ..text = 'Your 6-digit verification code is: $otpCode. It expires in 10 minutes.';

    if (SmtpConfig.replyToEmail.isNotEmpty) {
      message.headers['Reply-To'] = const Address(SmtpConfig.replyToEmail, SmtpConfig.senderName);
    }

    message.html = '''
        <div style="font-family: Arial, Helvetica, sans-serif; max-width: 520px; margin: 0 auto; padding: 28px; border: 1px solid #e3e6f0; border-radius: 16px; background-color: #ffffff;">
          <div style="text-align: center; margin-bottom: 20px;">
            <h1 style="color: #2441FF; margin: 0; font-size: 26px; letter-spacing: -0.5px;">COUGHFEE</h1>
            <p style="color: #6A7188; font-size: 13px; margin: 4px 0 0 0;">Mobile Ordering & Specialty Coffee</p>
          </div>
          <hr style="border: none; border-top: 1px solid #f0f2f8; margin: 20px 0;" />
          <h2 style="color: #12182B; font-size: 18px; margin-top: 0;">Verify your account</h2>
          <p style="color: #6A7188; font-size: 14px; line-height: 1.5;">
            Thank you for creating an account with COUGHFEE. Please use the 6-digit verification code below to verify your email address:
          </p>
          <div style="margin: 24px 0; text-align: center;">
            <div style="display: inline-block; background-color: #F4F5FA; border: 1px solid #E3E6F0; border-radius: 12px; padding: 18px 36px; font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #2441FF;">
              $otpCode
            </div>
          </div>
          <p style="color: #98A0BA; font-size: 12px; line-height: 1.5; margin-bottom: 0;">
            This code will expire in <strong>10 minutes</strong>. If you did not request this verification, you can safely ignore this email.
          </p>
        </div>
      ''';

    try {
      final primaryServer = _resolvePrimarySmtpServer();
      await _sendFunction(message, primaryServer);
      debugPrint('[SMTP Success] Verification email dispatched to $cleanRecipient (port ${primaryServer.port})');
      return true;
    } catch (primaryError) {
      debugPrint('[SMTP Notice] Primary SMTP port failed ($primaryError). Retrying via explicit SSL port 465...');
      try {
        final fallbackServer = _resolveFallbackSslServer();
        await _sendFunction(message, fallbackServer);
        debugPrint('[SMTP Success] Verification email dispatched to $cleanRecipient via SSL port 465');
        return true;
      } catch (fallbackError) {
        debugPrint('[SMTP Error] Failed to send email to $cleanRecipient via SMTP: $fallbackError');
        return false;
      }
    }
  }
}

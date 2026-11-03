import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'smtp_config.dart';

/// Service responsible for delivering 6-digit OTP verification codes via SMTP.
class SmtpService {
  SmtpService({
    Future<SendReport> Function(Message message, SmtpServer server)? sendFunction,
  }) : _sendFunction = sendFunction ?? send;

  final Future<SendReport> Function(Message message, SmtpServer server) _sendFunction;

  SmtpServer _resolveSmtpServer() {
    if (SmtpConfig.host.contains('gmail') && SmtpConfig.username.isNotEmpty) {
      return gmail(SmtpConfig.username, SmtpConfig.password);
    }

    return SmtpServer(
      SmtpConfig.host,
      port: SmtpConfig.port,
      ssl: SmtpConfig.ssl,
      username: SmtpConfig.username.isNotEmpty ? SmtpConfig.username : null,
      password: SmtpConfig.password.isNotEmpty ? SmtpConfig.password : null,
      allowInsecure: true,
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

    if (!SmtpConfig.isConfigured) {
      debugPrint(
        '[SMTP Note] SMTP credentials not set in lib/core/smtp_config.dart. '
        'Email to $cleanRecipient will not be dispatched over network until credentials are provided.',
      );
      return false;
    }

    // When sending through Gmail, the 'From' address must be the authenticated
    // Gmail address to ensure SPF and DKIM alignment; otherwise destination
    // mail servers (Gmail, Yahoo, Outlook) mark the email as spam or discard it.
    final fromAddress = (SmtpConfig.host.contains('gmail') && SmtpConfig.username.isNotEmpty)
        ? SmtpConfig.username
        : (SmtpConfig.senderEmail.isNotEmpty ? SmtpConfig.senderEmail : SmtpConfig.username);

    final message = Message()
      ..from = Address(fromAddress, SmtpConfig.senderName)
      ..recipients.add(cleanRecipient)
      ..subject = 'Your COUGHFEE Verification Code: $otpCode'
      ..text = 'Your 6-digit verification code is: $otpCode. It expires in 10 minutes.';

    if (SmtpConfig.replyToEmail.isNotEmpty) {
      message.headers['Reply-To'] = Address(SmtpConfig.replyToEmail, SmtpConfig.senderName);
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
      final server = _resolveSmtpServer();
      await _sendFunction(message, server);
      debugPrint('[SMTP Success] Verification email dispatched to $cleanRecipient');
      return true;
    } catch (e) {
      debugPrint('[SMTP Error] Failed to send email to $cleanRecipient via SMTP: $e');
      return false;
    }
  }
}

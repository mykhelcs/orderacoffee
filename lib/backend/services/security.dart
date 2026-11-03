import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Produces a salted SHA-256 hash of [password] with [salt].
///
/// Ensures plaintext passwords are never stored in Firestore documents.
String hashPassword(String password, {required String salt}) {
  final bytes = utf8.encode('$salt:$password');
  final digest = sha256.convert(bytes);
  return digest.toString();
}

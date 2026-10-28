import 'package:intl/intl.dart';

/// Formats [amount] as Philippine Peso string, e.g. ₱1,250.
String peso(num amount) {
  final f = NumberFormat('#,##0', 'en_PH');
  return '₱${f.format(amount)}';
}

/// Returns the next order status after [current], or [current] if already at the end.
String nextStatus(String current) {
  const steps = ['received', 'preparing', 'ready', 'completed'];
  final idx = steps.indexOf(current);
  if (idx < 0 || idx >= steps.length - 1) return current;
  return steps[idx + 1];
}

/// Returns true if [email] is a syntactically valid e-mail address.
bool isValidEmail(String email) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
}

/// Returns true if [phone] matches a Philippine mobile number (+63 or 09xx).
bool isValidPhone(String phone) {
  return RegExp(r'^(\+63|0)9\d{9}$').hasMatch(phone.trim().replaceAll(' ', ''));
}

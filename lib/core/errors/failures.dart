abstract class AppException implements Exception {
  const AppException(this.message, [this.code]);
  final String message;
  final String? code;

  @override
  String toString() => code != null ? '$runtimeType ($code): $message' : '$runtimeType: $message';
}

class AuthFailure extends AppException {
  const AuthFailure(super.message, [super.code]);
}

class ValidationFailure extends AppException {
  const ValidationFailure(super.message, [super.code]);
}

class NotFoundFailure extends AppException {
  const NotFoundFailure(super.message, [super.code]);
}

class OrderStateFailure extends AppException {
  const OrderStateFailure(super.message, [super.code]);
}

class PermissionFailure extends AppException {
  const PermissionFailure(super.message, [super.code]);
}

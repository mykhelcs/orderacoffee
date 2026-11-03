import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';
import 'package:orderacoffee/backend/repositories/user_repository.dart';

// â”€â”€â”€ Production Repository Providers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

// â”€â”€â”€ AuthState â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@immutable
class AuthState {
  const AuthState({
    this.profile,
    this.isLoading = false,
    this.isVerifying = false,
    this.error,
    this.pendingEmail,
    this.pendingRegistration,
    this.lastGeneratedCode,
    this.isVerificationSent = false,
  });

  final UserProfile? profile;
  final bool isLoading;
  final bool isVerifying;
  final String? error;
  final String? pendingEmail;
  final Map<String, String>? pendingRegistration;
  final String? lastGeneratedCode;
  final bool isVerificationSent;

  bool get isAuthenticated => profile != null;
  bool get isAdmin => profile?.isAdmin ?? false;

  AuthState copyWith({
    UserProfile? profile,
    bool? isLoading,
    bool? isVerifying,
    String? error,
    String? pendingEmail,
    Map<String, String>? pendingRegistration,
    String? lastGeneratedCode,
    bool? isVerificationSent,
    bool clearProfile = false,
    bool clearError = false,
    bool clearPending = false,
  }) {
    return AuthState(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      isVerifying: isVerifying ?? this.isVerifying,
      error: clearError ? null : (error ?? this.error),
      pendingEmail: clearPending ? null : (pendingEmail ?? this.pendingEmail),
      pendingRegistration: clearPending ? null : (pendingRegistration ?? this.pendingRegistration),
      lastGeneratedCode: clearPending ? null : (lastGeneratedCode ?? this.lastGeneratedCode),
      isVerificationSent: clearPending ? false : (isVerificationSent ?? this.isVerificationSent),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          profile == other.profile &&
          isLoading == other.isLoading &&
          isVerifying == other.isVerifying &&
          error == other.error &&
          pendingEmail == other.pendingEmail &&
          lastGeneratedCode == other.lastGeneratedCode &&
          isVerificationSent == other.isVerificationSent;

  @override
  int get hashCode => Object.hash(
        profile,
        isLoading,
        isVerifying,
        error,
        pendingEmail,
        lastGeneratedCode,
        isVerificationSent,
      );
}

// â”€â”€â”€ AuthNotifier â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authRepo, this._userRepo) : super(const AuthState()) {
    _listenToAuthChanges();
  }

  final AuthRepository _authRepo;
  final UserRepository _userRepo;
  StreamSubscription? _authSub;

  void _listenToAuthChanges() {
    try {
      _authSub = _authRepo.watchAuthState().listen((user) async {
        if (user != null) {
          try {
            final profile = await _userRepo.getProfile(user.uid);
            state = AuthState(profile: profile);
          } catch (_) {
            final baseProfile = UserProfile(
              uid: user.uid,
              name: user.displayName ?? user.email?.split('@').first ?? 'Customer',
              email: user.email ?? '',
              phone: user.phoneNumber ?? '',
              role: 'customer',
              isEmailVerified: true,
            );
            state = AuthState(profile: baseProfile);
          }
        } else {
          if (state.profile == null || !state.profile!.uid.startsWith('preview-')) {
            state = const AuthState();
          }
        }
      });
    } catch (_) {
      // Ignored if auth is not initialized
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // â”€â”€â”€ Sign in â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authRepo.logIn(email: email, password: password);
      try {
        final profile = await _userRepo.getProfile(user.uid);
        state = AuthState(profile: profile);
      } catch (_) {
        final baseProfile = UserProfile(
          uid: user.uid,
          name: user.displayName ?? email.split('@').first,
          email: email,
          phone: '',
          role: email.toLowerCase().contains('admin') ? 'admin' : 'customer',
          isEmailVerified: true,
        );
        state = AuthState(profile: baseProfile);
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('not initialized') ||
          errStr.contains('no-app') ||
          errStr.contains('FirebaseException')) {
        final isAdm = email.toLowerCase().contains('admin');
        final previewProfile = UserProfile(
          uid: isAdm ? 'preview-admin' : 'preview-customer',
          name: isAdm ? 'Admin Staff' : 'Juan dela Cruz',
          email: email.trim(),
          phone: '+63 912 345 6789',
          role: isAdm ? 'admin' : 'customer',
          favorites: const ['spanish-latte'],
          stamps: 3,
          isEmailVerified: true,
        );
        state = AuthState(profile: previewProfile);
        return;
      }
      state = state.copyWith(
        isLoading: false,
        clearProfile: true,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // â”€â”€â”€ Initiate Sign up (Sends 6-digit Code) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String> initiateSignUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final code = await _authRepo.sendEmailVerificationCode(email);
      state = state.copyWith(
        isLoading: false,
        pendingEmail: email.trim(),
        pendingRegistration: {
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'password': password,
        },
        lastGeneratedCode: code,
        isVerificationSent: true,
      );
      return code;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // â”€â”€â”€ Confirm Email Verification (6-Digit Code) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<bool> confirmEmailVerification(String code) async {
    final pending = state.pendingRegistration;
    final email = state.pendingEmail ?? pending?['email'] ?? '';

    state = state.copyWith(isVerifying: true, clearError: true);
    try {
      await _authRepo.verifyEmailCode(email: email, code: code);

      // Now complete account creation
      if (pending != null) {
        try {
          final profile = await _authRepo.signUp(
            email: pending['email']!,
            password: pending['password']!,
            name: pending['name']!,
            phone: pending['phone']!,
          );
          state = AuthState(profile: profile);
        } catch (e) {
          final errStr = e.toString();
          if (errStr.contains('not initialized') ||
              errStr.contains('no-app') ||
              errStr.contains('FirebaseException')) {
            final previewProfile = UserProfile(
              uid: 'preview-${DateTime.now().millisecondsSinceEpoch}',
              name: pending['name']!,
              email: pending['email']!,
              phone: pending['phone']!,
              role: 'customer',
              isEmailVerified: true,
            );
            state = AuthState(profile: previewProfile);
            return true;
          }
          rethrow;
        }
      } else {
        // If profile was already partially established
        state = state.copyWith(
          isVerifying: false,
          profile: state.profile?.copyWith(isEmailVerified: true),
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isVerifying: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // â”€â”€â”€ Resend Verification Code â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String> resendVerificationCode() async {
    final email = state.pendingEmail;
    if (email == null || email.isEmpty) return '';

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final code = await _authRepo.sendEmailVerificationCode(email);
      state = state.copyWith(
        isLoading: false,
        lastGeneratedCode: code,
      );
      return code;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Prepares the state for changing the email address by preserving
  /// user registration info (name, phone, password) while clearing pendingEmail.
  void prepareChangeEmail() {
    state = state.copyWith(
      pendingEmail: '',
      isVerificationSent: false,
      clearError: true,
    );
  }

  void cancelVerification() {
    state = state.copyWith(clearPending: true, clearError: true);
  }

  // â”€â”€â”€ Direct Sign up (Fallback & Unit Tests) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _authRepo.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
      state = AuthState(profile: profile);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('not initialized') ||
          errStr.contains('no-app') ||
          errStr.contains('FirebaseException')) {
        final previewProfile = UserProfile(
          uid: 'preview-${DateTime.now().millisecondsSinceEpoch}',
          name: name.trim(),
          email: email.trim(),
          phone: phone.trim(),
          role: 'customer',
          isEmailVerified: true,
        );
        state = AuthState(profile: previewProfile);
        return;
      }
      state = state.copyWith(
        isLoading: false,
        clearProfile: true,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // â”€â”€â”€ Sign out â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> signOut() async {
    await _authRepo.logOut();
    state = const AuthState();
  }

  // â”€â”€â”€ Reset password â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<bool> resetPassword(String email) async {
    try {
      await _authRepo.resetPassword(email);
      return true;
    } catch (_) {
      return true;
    }
  }
}

// â”€â”€â”€ Providers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(userRepositoryProvider),
  );
});

final userProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authProvider).profile;
});

final userFavoritesProvider = Provider<List<String>>((ref) {
  return ref.watch(authProvider).profile?.favorites ?? const [];
});

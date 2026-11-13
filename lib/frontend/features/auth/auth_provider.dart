import 'dart:async';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:orderacoffee/backend/config/admin_config.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';
import 'package:orderacoffee/backend/repositories/favorites_repository.dart';
import 'package:orderacoffee/backend/repositories/loyalty_repository.dart';
import 'package:orderacoffee/backend/repositories/notification_repository.dart';
import 'package:orderacoffee/backend/repositories/user_repository.dart';
import 'package:orderacoffee/backend/services/notification_service.dart';
import 'package:orderacoffee/core/errors/failures.dart';

// ─── Production Repository Providers ──────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository();
});

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  return LoyaltyRepository();
});

// ─── AuthState ────────────────────────────────────────────────────────────────

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
    this.activeRewardCode,
    this.lastLoginMethod,
  });

  final UserProfile? profile;
  final bool isLoading;
  final bool isVerifying;
  final String? error;
  final String? pendingEmail;
  final Map<String, String>? pendingRegistration;
  final String? lastGeneratedCode;
  final bool isVerificationSent;
  final String? activeRewardCode;
  final String? lastLoginMethod;

  bool get isAuthenticated => profile != null;
  bool get isAdmin => profile?.isAdmin ?? false;
  bool get isGoogleLastUsed => lastLoginMethod == 'google';

  AuthState copyWith({
    UserProfile? profile,
    bool? isLoading,
    bool? isVerifying,
    String? error,
    String? pendingEmail,
    Map<String, String>? pendingRegistration,
    String? lastGeneratedCode,
    bool? isVerificationSent,
    String? activeRewardCode,
    String? lastLoginMethod,
    bool clearProfile = false,
    bool clearError = false,
    bool clearPending = false,
    bool clearRewardCode = false,
  }) {
    return AuthState(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      isVerifying: isVerifying ?? this.isVerifying,
      error: clearError ? null : (error ?? this.error),
      pendingEmail: clearPending ? null : (pendingEmail ?? this.pendingEmail),
      pendingRegistration: clearPending
          ? null
          : (pendingRegistration ?? this.pendingRegistration),
      lastGeneratedCode: clearPending
          ? null
          : (lastGeneratedCode ?? this.lastGeneratedCode),
      isVerificationSent: clearPending
          ? false
          : (isVerificationSent ?? this.isVerificationSent),
      activeRewardCode: clearRewardCode
          ? null
          : (activeRewardCode ?? this.activeRewardCode),
      lastLoginMethod: lastLoginMethod ?? this.lastLoginMethod,
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
          isVerificationSent == other.isVerificationSent &&
          activeRewardCode == other.activeRewardCode &&
          lastLoginMethod == other.lastLoginMethod;

  @override
  int get hashCode => Object.hash(
        profile,
        isLoading,
        isVerifying,
        error,
        pendingEmail,
        lastGeneratedCode,
        isVerificationSent,
        activeRewardCode,
        lastLoginMethod,
      );
}

// ─── AuthNotifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(
    this._authRepo,
    this._userRepo, {
    FavoritesRepository? favoritesRepo,
    LoyaltyRepository? loyaltyRepo,
    NotificationRepository? notificationRepo,
  })  : _favoritesRepo = favoritesRepo,
        _loyaltyRepo = loyaltyRepo,
        _notificationRepo = notificationRepo,
        super(const AuthState()) {
    _loadLastLoginMethod();
    _listenToAuthChanges();
  }

  static const String _lastLoginMethodKey = 'last_login_method';

  final AuthRepository _authRepo;
  final UserRepository _userRepo;
  final FavoritesRepository? _favoritesRepo;
  final LoyaltyRepository? _loyaltyRepo;
  final NotificationRepository? _notificationRepo;
  StreamSubscription? _authSub;

  Future<void> _loadLastLoginMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMethod = prefs.getString(_lastLoginMethodKey);
      if (savedMethod != null && savedMethod.isNotEmpty && mounted) {
        state = state.copyWith(lastLoginMethod: savedMethod);
      }
    } catch (_) {}
  }

  Future<void> _saveLastLoginMethod(String method) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastLoginMethodKey, method);
    } catch (_) {}
  }

  void _listenToAuthChanges() {
    try {
      _authSub = _authRepo.watchAuthState().listen((user) async {
        if (user != null) {
          try {
            final profile = await _userRepo.getProfile(user.uid);
            state = AuthState(
              profile: profile,
              lastLoginMethod: state.lastLoginMethod,
            );
            _registerPushNotifications(user.uid);
          } catch (_) {
            final baseProfile = UserProfile(
              uid: user.uid,
              name: user.displayName ??
                  user.email?.split('@').first ??
                  'Customer',
              email: user.email ?? '',
              phone: user.phoneNumber ?? '',
              role: 'customer',
              isEmailVerified: true,
            );
            state = AuthState(
              profile: baseProfile,
              lastLoginMethod: state.lastLoginMethod,
            );
          }
        } else {
          final currentUid = state.profile?.uid ?? '';
          final isBypassUser = state.lastLoginMethod == 'google' ||
              currentUid.startsWith('preview-') ||
              currentUid.startsWith('google-') ||
              currentUid.startsWith('admin-');
          if (state.profile == null || !isBypassUser) {
            state = AuthState(lastLoginMethod: state.lastLoginMethod);
          }
        }
      });
    } catch (_) {
      // Ignored if auth is not initialized
    }
  }

  Future<void> _registerPushNotifications(String uid) async {
    if (uid.isEmpty || uid.startsWith('preview-')) return;
    try {
      final repo = _notificationRepo ??
          NotificationRepository(userRepository: _userRepo);
      await repo.requestPermission();
      await repo.registerToken(uid);
    } catch (_) {
      // Safe no-op in tests or browsers without FCM
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // ─── Sign in ────────────────────────────────────────────────────────────

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final isAdm = AdminConfig.isAdminEmail(email);

    try {
      final user = await _authRepo.logIn(email: email, password: password);
      await _saveLastLoginMethod('email');
      try {
        final profile = await _userRepo.getProfile(user.uid);
        state = AuthState(profile: profile, lastLoginMethod: 'email');
        unawaited(_registerPushNotifications(user.uid));
      } catch (_) {
        final baseProfile = UserProfile(
          uid: user.uid,
          name: isAdm ? AdminConfig.displayName : (user.displayName ?? email.split('@').first),
          email: email,
          phone: isAdm ? AdminConfig.phone : '',
          role: isAdm ? 'admin' : 'customer',
          isEmailVerified: true,
        );
        state = AuthState(profile: baseProfile, lastLoginMethod: 'email');
      }
    } catch (e) {
      final errStr = e.toString();

      // Allow offline/preview fallback ONLY when Firebase is uninitialized (e.g. unit tests
      // or local preview without Firebase setup), never on invalid credentials.
      final isFirebaseUnavailable = errStr.contains('not initialized') ||
          errStr.contains('no-app') ||
          (kDebugMode && !isAdm && errStr.contains('network-request-failed'));

      if (isFirebaseUnavailable) {
        await _saveLastLoginMethod('email');
        final previewProfile = UserProfile(
          uid: isAdm ? 'preview-admin' : 'preview-customer',
          name: isAdm ? AdminConfig.displayName : 'Juan dela Cruz',
          email: email.trim(),
          phone: isAdm ? AdminConfig.phone : '+63 912 345 6789',
          role: isAdm ? 'admin' : 'customer',
          favorites: isAdm ? const [] : const ['spanish-latte'],
          stamps: isAdm ? 0 : 3,
          addresses: isAdm
              ? const []
              : const [
                  UserAddress(
                    id: 'addr-home',
                    label: 'Home',
                    line1: 'Unit 12B One Serendra, 11th Ave',
                    city: 'Taguig City',
                    notes: 'Lobby concierge drop-off',
                    lat: 14.5489,
                    lng: 121.0548,
                  ),
                  UserAddress(
                    id: 'addr-office',
                    label: 'Office',
                    line1: 'Ayala Tower One, Ayala Ave',
                    city: 'Makati City',
                    notes: 'Call upon arrival at reception',
                    lat: 14.5547,
                    lng: 121.0244,
                  ),
                ],
          isEmailVerified: true,
        );
        state = AuthState(profile: previewProfile, lastLoginMethod: 'email');
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

  // ─── Sign in with Google ────────────────────────────────────────────────

  Future<void> signInWithGoogle({
    String? fallbackEmail,
    String? fallbackName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _authRepo.signInWithGoogle(
        fallbackEmail: fallbackEmail,
        fallbackName: fallbackName,
      );
      await _saveLastLoginMethod('google');
      state = AuthState(
        profile: profile,
        lastLoginMethod: 'google',
      );
      unawaited(_registerPushNotifications(profile.uid));
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Convenience 1-tap admin login using pre-configured administrative credentials
  Future<void> signInAsAdmin() async {
    await signIn(AuthRepository.defaultAdminEmail, AuthRepository.defaultAdminPassword);
  }

  // ─── Initiate Sign up (Sends 6-digit Code) ──────────────────────────────

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

  // ─── Confirm Email Verification (6-Digit Code) ──────────────────────────

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

  // ─── Resend Verification Code ───────────────────────────────────────────

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

  // ─── Direct Sign up (Fallback & Unit Tests) ─────────────────────────────

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

  // ─── Favorites Management (FavoritesRepository) ─────────────────────────

  Future<bool> toggleFavorite(String itemId) async {
    final currentProfile = state.profile;
    if (currentProfile == null) return false;

    final favs = List<String>.from(currentProfile.favorites);
    final isAdding = !favs.contains(itemId);
    if (isAdding) {
      favs.add(itemId);
    } else {
      favs.remove(itemId);
    }

    state = state.copyWith(
      profile: currentProfile.copyWith(favorites: favs),
    );

    if (!currentProfile.uid.startsWith('preview-')) {
      try {
        final repo = _favoritesRepo ?? FavoritesRepository();
        if (isAdding) {
          await repo.addFavorite(currentProfile.uid, itemId);
        } else {
          await repo.removeFavorite(currentProfile.uid, itemId);
        }
      } catch (_) {}
    }

    return isAdding;
  }

  // ─── Profile & Address Management (UserRepository) ──────────────────────

  Future<void> updateProfileDetails({
    required String name,
    required String phone,
  }) async {
    final currentProfile = state.profile;
    if (currentProfile == null) return;

    final updated = currentProfile.copyWith(
      name: name.trim(),
      phone: phone.trim(),
    );
    state = state.copyWith(profile: updated);

    if (!currentProfile.uid.startsWith('preview-')) {
      try {
        await _userRepo.updateProfile(
          currentProfile.uid,
          name: name.trim(),
          phone: phone.trim(),
        );
      } catch (_) {}
    }
  }

  Future<void> uploadProfilePhoto(XFile image) async {
    final currentProfile = state.profile;
    if (currentProfile == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final bytes = await image.readAsBytes();
      String? downloadUrl;

      // Try uploading to Firebase Storage if not a local preview/admin account
      if (!currentProfile.uid.startsWith('preview-') && !currentProfile.uid.startsWith('admin-')) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_photos')
              .child('${currentProfile.uid}.jpg');

          final uploadTask = await storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          downloadUrl = await uploadTask.ref.getDownloadURL();
        } catch (storageErr) {
          debugPrint('[Profile Photo] Firebase Storage upload failed: $storageErr. Falling back to Data URI.');
        }
      }

      // If Firebase Storage failed, is 404, or account is preview/offline,
      // encode as a compact Data URI so the image persists across sessions and syncs to Firestore
      if (downloadUrl == null || downloadUrl.isEmpty) {
        if (bytes.lengthInBytes <= 500 * 1024) {
          downloadUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        } else {
          downloadUrl = image.path;
        }
      }

      // Update Firestore profile document if possible
      if (!currentProfile.uid.startsWith('preview-') && !currentProfile.uid.startsWith('admin-')) {
        try {
          await _userRepo.updatePhotoUrl(currentProfile.uid, downloadUrl);
        } catch (dbErr) {
          debugPrint('[Profile Photo] Firestore photo URL update: $dbErr');
        }
      }

      state = state.copyWith(
        isLoading: false,
        profile: currentProfile.copyWith(photoUrl: downloadUrl),
      );
    } catch (e) {
      // Even if file reading threw an error, fall back to local image path
      state = state.copyWith(
        isLoading: false,
        profile: currentProfile.copyWith(photoUrl: image.path),
      );
    }
  }

  Future<void> addDeliveryAddress(UserAddress address) async {
    final currentProfile = state.profile;
    if (currentProfile == null) return;

    final updatedAddresses = [...currentProfile.addresses, address];
    state = state.copyWith(
      profile: currentProfile.copyWith(addresses: updatedAddresses),
    );

    if (!currentProfile.uid.startsWith('preview-')) {
      try {
        await _userRepo.addAddress(currentProfile.uid, address);
      } catch (_) {}
    }
  }

  Future<void> removeDeliveryAddress(UserAddress address) async {
    final currentProfile = state.profile;
    if (currentProfile == null) return;

    final updatedAddresses = currentProfile.addresses
        .where((a) => a.id != address.id)
        .toList();
    state = state.copyWith(
      profile: currentProfile.copyWith(addresses: updatedAddresses),
    );

    if (!currentProfile.uid.startsWith('preview-')) {
      try {
        await _userRepo.removeAddress(currentProfile.uid, address);
      } catch (_) {}
    }
  }

  // ─── Loyalty Stamps & Rewards (LoyaltyRepository) ───────────────────────

  Future<void> earnStamp() async {
    final currentProfile = state.profile;
    if (currentProfile == null) return;

    final nextStamps = currentProfile.stamps + 1;
    state = state.copyWith(
      profile: currentProfile.copyWith(stamps: nextStamps),
    );

    if (nextStamps == 4 || (nextStamps > 0 && nextStamps % 8 == 0)) {
      try {
        await NotificationService.showLoyaltyMilestoneNotification(
          stamps: nextStamps,
        );
      } catch (_) {}
    }

    if (!currentProfile.uid.startsWith('preview-')) {
      try {
        final repo = _loyaltyRepo ?? LoyaltyRepository();
        await repo.earnStamp(currentProfile.uid);
      } catch (_) {}
    }
  }

  Future<String> redeemStamps() async {
    final currentProfile = state.profile;
    if (currentProfile == null) {
      throw const AuthFailure('Please sign in to redeem stamps');
    }
    if (currentProfile.stamps < 8) {
      throw ValidationFailure(
        'Need at least 8 stamps to redeem a Free Drink (current: ${currentProfile.stamps}).',
      );
    }

    String rewardCode =
        'REWARD-${const Uuid().v4().substring(0, 8).toUpperCase()}';

    if (!currentProfile.uid.startsWith('preview-')) {
      try {
        final repo = _loyaltyRepo ?? LoyaltyRepository();
        rewardCode = await repo.redeemStamps(currentProfile.uid);
      } catch (_) {}
    }

    state = state.copyWith(
      profile: currentProfile.copyWith(stamps: currentProfile.stamps - 8),
      activeRewardCode: rewardCode,
    );
    return rewardCode;
  }

  void clearActiveRewardCode() {
    state = state.copyWith(clearRewardCode: true);
  }

  // ─── Sign out & Delete Account ──────────────────────────────────────────

  Future<void> signOut() async {
    final prevMethod = state.lastLoginMethod;
    await _authRepo.logOut();
    state = AuthState(lastLoginMethod: prevMethod);
  }

  Future<void> deleteAccount() async {
    final prevMethod = state.lastLoginMethod;
    try {
      await _authRepo.deleteAccount();
    } catch (_) {}
    state = AuthState(lastLoginMethod: prevMethod);
  }

  // ─── Reset password ─────────────────────────────────────────────────────

  Future<bool> resetPassword(String email) async {
    try {
      await _authRepo.resetPassword(email);
      return true;
    } catch (_) {
      return true;
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

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

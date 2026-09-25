import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/config/app_config.dart';
import '../core/database/profile_repository.dart';
import '../core/database/schedule_repository.dart';
import '../core/database/user_sync_service.dart';
import '../core/notifications/notification_service.dart';
import 'profile_provider.dart';
import 'schedule_provider.dart';

class AuthState {
  final bool isOnboarded;
  final bool isLoggedIn;
  final bool isGuest;
  final bool isLoading;
  final String? errorMessage;
  final String? userId;
  final String userName;
  final String userEmail;
  final String? userPhotoUrl;

  const AuthState({
    this.isOnboarded = false,
    this.isLoggedIn = false,
    this.isGuest = false,
    this.isLoading = false,
    this.errorMessage,
    this.userId,
    this.userName = 'Guest User',
    this.userEmail = '',
    this.userPhotoUrl,
  });

  AuthState copyWith({
    bool? isOnboarded,
    bool? isLoggedIn,
    bool? isGuest,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhotoUrl,
  }) {
    return AuthState(
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isGuest: isGuest ?? this.isGuest,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const String settingsBox = 'app_settings_box';
  late Box _box;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: AppConfig.googleOAuthClientId.isNotEmpty
        ? AppConfig.googleOAuthClientId
        : null,
  );
  final Ref _ref;
  StreamSubscription<User?>? _authSubscription;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(settingsBox);
    final onboarded = _box.get('isOnboarded', defaultValue: false) as bool;
    final isGuestMode = _box.get('isGuestLogin', defaultValue: false) as bool;
    final cachedName = _box.get('userName', defaultValue: isGuestMode ? 'Guest User' : 'User') as String;
    final cachedEmail = _box.get('userEmail', defaultValue: '') as String;
    final customPhoto = _box.get('userCustomPhotoUrl') as String?;
    final cachedPhoto = _box.get('userPhotoUrl') as String?;

    final currentUser = _firebaseAuth.currentUser;
    final loggedIn = isGuestMode || currentUser != null;
    if (!loggedIn && !isGuestMode) {
      await _box.put('isLoggedIn', false);
    }

    state = AuthState(
      isOnboarded: onboarded,
      isLoggedIn: loggedIn,
      isGuest: isGuestMode,
      userId: currentUser?.uid,
      userName: currentUser?.displayName ?? (cachedName.isNotEmpty ? cachedName : 'User'),
      userEmail: currentUser?.email ?? cachedEmail,
      userPhotoUrl: (customPhoto != null && customPhoto.isNotEmpty)
          ? customPhoto
          : (currentUser?.photoURL ?? cachedPhoto),
    );

    // Listen to Firebase Auth state changes in realtime
    _authSubscription = _firebaseAuth.authStateChanges().listen((user) async {
      if (user != null) {
        final name = user.displayName ?? (user.email?.split('@').first ?? 'User');
        final email = user.email ?? 'user@example.com';
        final savedCustomPhoto = _box.get('userCustomPhotoUrl') as String?;
        final effectivePhoto =
            (savedCustomPhoto != null && savedCustomPhoto.isNotEmpty)
                ? savedCustomPhoto
                : user.photoURL;

        await _box.put('isGuestLogin', false);
        await _box.put('isLoggedIn', true);
        await _box.put('isOnboarded', true);
        await _box.put('userName', name);
        await _box.put('userEmail', email);
        if (effectivePhoto != null) await _box.put('userPhotoUrl', effectivePhoto);

        state = state.copyWith(
          isLoggedIn: true,
          isGuest: false,
          isOnboarded: true,
          userId: user.uid,
          userName: name,
          userEmail: email,
          userPhotoUrl: effectivePhoto,
          isLoading: false,
          clearError: true,
        );
        UserSyncService.instance.syncCurrentUser();
      } else {
        final isGuest = _box.get('isGuestLogin', defaultValue: false) as bool;

        // When Firebase session expires or user logs out (and not guest), clear loggedIn state
        if (!isGuest) {
          await _box.put('isLoggedIn', false);
          state = state.copyWith(
            isLoggedIn: false,
            isGuest: false,
            userId: null,
            isLoading: false,
          );
        }
      }
    });
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> completeOnboarding() async {
    await _box.put('isOnboarded', true);
    state = state.copyWith(isOnboarded: true);
  }

  /// Sign In with Email & Password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        final name = user.displayName ?? (user.email?.split('@').first ?? 'User');
        await _box.put('isGuestLogin', false);
        await _box.put('isLoggedIn', true);
        await _box.put('isOnboarded', true);
        await _box.put('userName', name);
        await _box.put('userEmail', user.email ?? email);

        state = state.copyWith(
          isLoggedIn: true,
          isGuest: false,
          isOnboarded: true,
          userId: user.uid,
          userName: name,
          userEmail: user.email ?? email,
          userPhotoUrl: user.photoURL,
          isLoading: false,
          clearError: true,
        );
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseError(e.code, e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Register new user with Email, Password, and Display Name
  Future<bool> registerWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        final name = displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : (user.email?.split('@').first ?? 'User');

        await user.updateDisplayName(name);
        await _box.put('isGuestLogin', false);
        await _box.put('isLoggedIn', true);
        await _box.put('isOnboarded', true);
        await _box.put('userName', name);
        await _box.put('userEmail', user.email ?? email);

        state = state.copyWith(
          isLoggedIn: true,
          isGuest: false,
          isOnboarded: true,
          userId: user.uid,
          userName: name,
          userEmail: user.email ?? email,
          isLoading: false,
          clearError: true,
        );
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseError(e.code, e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create account. Please try again.',
      );
      return false;
    }
  }

  /// Sign In with Google OAuth
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled Google picker
        state = state.copyWith(isLoading: false);
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final name = user.displayName ?? googleUser.displayName ?? 'Google User';
        final email = user.email ?? googleUser.email;
        final photo = user.photoURL ?? googleUser.photoUrl;

        await _box.put('isGuestLogin', false);
        await _box.put('isLoggedIn', true);
        await _box.put('isOnboarded', true);
        await _box.put('userName', name);
        await _box.put('userEmail', email);
        if (photo != null) await _box.put('userPhotoUrl', photo);

        state = state.copyWith(
          isLoggedIn: true,
          isGuest: false,
          isOnboarded: true,
          userId: user.uid,
          userName: name,
          userEmail: email,
          userPhotoUrl: photo,
          isLoading: false,
          clearError: true,
        );
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      final msg = _mapFirebaseError(e.code, e.message);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg.isNotEmpty ? msg : null,
      );
      return false;
    } catch (e) {
      final msg = _mapGoogleSignInError(e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg.isNotEmpty ? msg : null,
      );
      return false;
    }
  }

  /// Offline / Guest Login Mode
  Future<void> loginAsGuest({String? name, String? email}) async {
    final finalName = name ?? 'Guest User';
    final finalEmail = email ?? '';
    await _box.put('isGuestLogin', true);
    await _box.put('isLoggedIn', true);
    await _box.put('isOnboarded', true);
    await _box.put('userName', finalName);
    await _box.put('userEmail', finalEmail);

    state = state.copyWith(
      isLoggedIn: true,
      isGuest: true,
      isOnboarded: true,
      userName: finalName,
      userEmail: finalEmail,
      userId: null,
      userPhotoUrl: null,
      isLoading: false,
      clearError: true,
    );
  }

  /// Update user display name across local Hive and Firebase
  Future<void> updateDisplayName(String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    try {
      await _firebaseAuth.currentUser?.updateDisplayName(name);
    } catch (_) {}
    await _box.put('userName', name);
    state = state.copyWith(userName: name);
    UserSyncService.instance.syncCurrentUser();
  }

  /// Update user profile photo (supports Data URI base64 or HTTPS URL) across Hive and Firestore
  Future<void> updateProfilePhoto(String? photoDataOrUrl) async {
    if (photoDataOrUrl == null || photoDataOrUrl.trim().isEmpty) {
      await _box.delete('userCustomPhotoUrl');
      final fallbackPhoto = _firebaseAuth.currentUser?.photoURL;
      if (fallbackPhoto != null) {
        await _box.put('userPhotoUrl', fallbackPhoto);
      } else {
        await _box.delete('userPhotoUrl');
      }
      state = AuthState(
        isOnboarded: state.isOnboarded,
        isLoggedIn: state.isLoggedIn,
        isGuest: state.isGuest,
        isLoading: state.isLoading,
        errorMessage: state.errorMessage,
        userId: state.userId,
        userName: state.userName,
        userEmail: state.userEmail,
        userPhotoUrl: fallbackPhoto,
      );
    } else {
      final cleanPhoto = photoDataOrUrl.trim();
      await _box.put('userCustomPhotoUrl', cleanPhoto);
      await _box.put('userPhotoUrl', cleanPhoto);
      if (cleanPhoto.startsWith('http')) {
        try {
          await _firebaseAuth.currentUser?.updatePhotoURL(cleanPhoto);
        } catch (_) {}
      }
      state = state.copyWith(userPhotoUrl: cleanPhoto);
    }
    UserSyncService.instance.syncCurrentUser();
  }

  /// Logout from Firebase and local state
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}

    await _box.put('isGuestLogin', false);
    await _box.put('isLoggedIn', false);
    await _box.delete('userName');
    await _box.delete('userEmail');
    await _box.delete('userPhotoUrl');
    await _box.delete('userCustomPhotoUrl');

    // Wipe local schedule and profile caches so old account data doesn't leak
    try {
      final scheduleRepo = ScheduleRepository();
      await scheduleRepo.init();
      await scheduleRepo.clearAll();

      final profileRepo = ProfileRepository();
      await profileRepo.init();
      await profileRepo.clearAll();

      final notifService = NotificationService();
      await notifService.cancelAllNotifications();

      // Clear in-memory Riverpod provider state so old user's data isn't visible in UI
      _ref.invalidate(scheduleListProvider);
      _ref.invalidate(profileListProvider);
    } catch (e) {
      // Ignored
    }

    state = state.copyWith(
      isLoggedIn: false,
      isGuest: false,
      userId: null,
      userName: 'Guest User',
      userEmail: '',
      userPhotoUrl: null,
      isLoading: false,
      clearError: true,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String _mapGoogleSignInError(dynamic error) {
    final errStr = error.toString().toLowerCase();

    // 1. User intentionally cancelled
    if (errStr.contains('canceled') ||
        errStr.contains('cancelled') ||
        errStr.contains('12501') ||
        errStr.contains('popup_closed') ||
        errStr.contains('sign_in_canceled')) {
      return ''; // Silent cancel, no error banner
    }

    // 2. Network / Offline
    if (errStr.contains('network_error') ||
        errStr.contains('network') ||
        errStr.contains('socketexception') ||
        errStr.contains('timeout') ||
        errStr.contains(': 7:') ||
        errStr.contains('connection_failed')) {
      return 'No internet connection. Please check your Wi-Fi or Mobile Data, or tap Continue as Guest.';
    }

    // 3. Google Play Services unavailable
    if (errStr.contains('play_services') || errStr.contains('api_not_available')) {
      return 'Google Play Services is not available. Please try Email login or Guest Mode.';
    }

    // 4. Default clean fallback
    return 'Google Sign-In could not connect. Please check your connection or Continue as Guest.';
  }

  String _mapFirebaseError(String code, String? defaultMsg) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network or Continue as Guest.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many login attempts. Please wait a moment and try again.';
      default:
        return 'Authentication failed. Please check your connection and try again.';
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

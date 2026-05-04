// Local-only auth — no Supabase. Profiles are stored locally.
// Supports guest/local mode (no cloud account needed)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth state
sealed class AuthState {
  const AuthState();
}
class AuthLoading extends AuthState {
  const AuthLoading();
}
class AuthNotAuthenticated extends AuthState {
  const AuthNotAuthenticated();
}
class AuthAuthenticated extends AuthState {
  final String userId;
  final String email;
  final bool isGuest;
  const AuthAuthenticated({required this.userId, required this.email, this.isGuest = false});
}
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

class AuthRepository {
  final SharedPreferences _prefs;

  static const String _guestModeKey = 'auth_guest_mode';
  static const String _guestIdKey = 'auth_guest_id';

  AuthRepository(SharedPreferences prefs)
      : _prefs = prefs;

  bool get isGuestMode => _prefs.getBool(_guestModeKey) ?? false;

  /// Check current auth state — always local
  Future<AuthState> checkAuthState() async {
    // Guest mode takes priority
    if (isGuestMode) {
      var guestId = _prefs.getString(_guestIdKey) ?? 'local_${DateTime.now().millisecondsSinceEpoch}';
      if (_prefs.getString(_guestIdKey) == null) {
        await _prefs.setString(_guestIdKey, guestId);
      }
      return AuthAuthenticated(userId: guestId, email: 'Local User', isGuest: true);
    }

    // Not in guest mode — check for existing local user
    final localId = _prefs.getString(_guestIdKey);
    if (localId != null) {
      return AuthAuthenticated(userId: localId, email: 'Local User', isGuest: true);
    }

    return const AuthNotAuthenticated();
  }

  /// Sign in — local only (no cloud)
  Future<AuthState> signIn(String email, String password) async {
    // Local auth: just enter local mode
    return enterGuestMode();
  }

  /// Sign up — local only (no cloud)
  Future<AuthState> signUp(String email, String password) async {
    // Local auth: just enter local mode
    return enterGuestMode();
  }

  /// Enter guest / local mode
  Future<AuthState> enterGuestMode() async {
    await _prefs.setBool(_guestModeKey, true);
    var guestId = _prefs.getString(_guestIdKey);
    if (guestId == null) {
      guestId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      await _prefs.setString(_guestIdKey, guestId);
    }
    return AuthAuthenticated(userId: guestId, email: 'Local User', isGuest: true);
  }

  /// Sign out
  Future<void> signOut() async {
    await _prefs.setBool(_guestModeKey, false);
    await _prefs.remove(_guestIdKey);
  }
}

// ─── Providers ───

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError('Initialize in main with SharedPreferences');
});

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref.watch(authRepositoryProvider));
});

class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthStateNotifier(this._repo) : super(const AuthLoading()) {
    _init();
  }

  Future<void> _init() async {
    final authState = await _repo.checkAuthState();
    if (mounted) state = authState;
  }

  Future<void> signIn(String email, String password) async {
    state = const AuthLoading();
    final result = await _repo.signIn(email, password);
    if (mounted) state = result;
  }

  Future<void> signUp(String email, String password) async {
    state = const AuthLoading();
    final result = await _repo.signUp(email, password);
    if (mounted) state = result;
  }

  Future<void> enterGuestMode() async {
    state = const AuthLoading();
    final result = await _repo.enterGuestMode();
    if (mounted) state = result;
  }

  Future<void> signOut() async {
    await _repo.signOut();
    if (mounted) state = const AuthNotAuthenticated();
  }
}

final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState is AuthAuthenticated ? authState.userId : null;
});

final isGuestProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState is AuthAuthenticated && authState.isGuest;
});

import '../models/devo.dart';
import '../models/user_preferences.dart';

abstract class DevoRepository {
  Future<List<Devo>> devosForDate(DateTime date);

  Future<Devo?> devoById(String id);

  Future<List<Devo>> search({String text = '', DateTime? date});

  /// Newest edition first.
  Future<List<DateTime>> editionDates();
}

abstract class FavoritesRepository {
  Future<Set<String>> load();

  Future<void> setFavorite(String devoId, bool favorite);
}

abstract class PreferencesRepository {
  Future<UserPreferences> load();

  Future<void> save(UserPreferences preferences);
}

class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

class AuthUnavailable implements Exception {
  const AuthUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  AuthUser? get currentUser;

  Stream<AuthUser?> authState();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> signOut();
}

class UnavailableAuthRepository implements AuthRepository {
  static const _message =
      'Sign-in needs SUPABASE_URL and SUPABASE_ANON_KEY. Sample devotions stay available without an account.';

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authState() => Stream<AuthUser?>.value(null);

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw const AuthUnavailable(_message);
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) {
    throw const AuthUnavailable(_message);
  }

  @override
  Future<void> signInWithGoogle() {
    throw const AuthUnavailable(_message);
  }

  @override
  Future<void> signInWithApple() {
    throw const AuthUnavailable(_message);
  }

  @override
  Future<void> signOut() async {}
}

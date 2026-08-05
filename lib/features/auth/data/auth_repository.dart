import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client.auth);
});

class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  User? get currentUser => _auth.currentUser;

  Future<void> sendOtp(String email) {
    return _auth.signInWithOtp(email: email);
  }

  Future<void> verifyOtp({required String email, required String token}) {
    return _auth.verifyOTP(email: email, token: token, type: OtpType.email);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(Supabase.instance.client);
});

class AccountRepository {
  AccountRepository(this._client);

  final SupabaseClient _client;

  /// Calls the `delete-account` Edge Function, which verifies the caller's
  /// own JWT and uses the service-role key (never present client-side) to
  /// delete the auth user. Cascading FK deletes clean up every related
  /// table automatically. Throws [FunctionException] on failure.
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account');
  }
}

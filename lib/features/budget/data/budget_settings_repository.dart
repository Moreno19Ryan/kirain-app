import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final budgetSettingsRepositoryProvider = Provider<BudgetSettingsRepository>((ref) {
  return BudgetSettingsRepository(Supabase.instance.client);
});

final budgetSettingsProvider = FutureProvider<BudgetSettings>((ref) {
  return ref.watch(budgetSettingsRepositoryProvider).fetch();
});

class BudgetSettings {
  const BudgetSettings({required this.cycleStartDay, required this.rolloverEnabled});

  final int cycleStartDay;
  final bool rolloverEnabled;

  factory BudgetSettings.fromJson(Map<String, dynamic> json) {
    return BudgetSettings(
      cycleStartDay: json['cycle_start_day'] as int,
      rolloverEnabled: json['rollover_enabled'] as bool,
    );
  }
}

class BudgetSettingsRepository {
  BudgetSettingsRepository(this._client);

  final SupabaseClient _client;

  Future<BudgetSettings> fetch() async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client.from('budget_settings').select().eq('user_id', userId).single();
    return BudgetSettings.fromJson(row);
  }
}

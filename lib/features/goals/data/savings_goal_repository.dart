import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'savings_goal.dart';

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  return SavingsGoalRepository(Supabase.instance.client);
});

final savingsGoalsProvider = FutureProvider<List<SavingsGoal>>((ref) {
  return ref.watch(savingsGoalRepositoryProvider).fetchGoals();
});

class SavingsGoalRepository {
  SavingsGoalRepository(this._client);

  final SupabaseClient _client;

  /// RLS already scopes this to the signed-in user's own goals.
  Future<List<SavingsGoal>> fetchGoals() async {
    final rows = await _client.from('savings_goals').select().order('priority_order');
    return rows.map(SavingsGoal.fromJson).toList();
  }

  Future<void> createGoal({
    required String name,
    required num targetAmount,
    bool isEmergencyFund = false,
    DateTime? targetDate,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final existing = await _client
        .from('savings_goals')
        .select('priority_order')
        .eq('user_id', userId)
        .order('priority_order', ascending: false)
        .limit(1);
    final nextOrder = existing.isEmpty ? 0 : (existing.first['priority_order'] as int) + 1;

    await _client.from('savings_goals').insert({
      'user_id': userId,
      'name': name,
      'target_amount': targetAmount,
      'is_emergency_fund': isEmergencyFund,
      'priority_order': nextOrder,
      'target_date': targetDate == null ? null : _isoDate(targetDate),
    });
  }

  Future<void> updateGoal({
    required String goalId,
    required String name,
    required num targetAmount,
    required bool isEmergencyFund,
    DateTime? targetDate,
  }) {
    return _client
        .from('savings_goals')
        .update({
          'name': name,
          'target_amount': targetAmount,
          'is_emergency_fund': isEmergencyFund,
          'target_date': targetDate == null ? null : _isoDate(targetDate),
        })
        .eq('id', goalId);
  }

  Future<void> deleteGoal(String goalId) {
    return _client.from('savings_goals').delete().eq('id', goalId);
  }

  /// Simple read-modify-write; fine for a single-user mobile app doing one
  /// action at a time, not worth a DB-side atomic increment for V1.
  Future<void> adjustAmount(String goalId, num delta) async {
    final row = await _client
        .from('savings_goals')
        .select('current_amount')
        .eq('id', goalId)
        .single();
    final current = row['current_amount'] as num;
    final next = current + delta < 0 ? 0 : current + delta;
    await _client.from('savings_goals').update({'current_amount': next}).eq('id', goalId);
  }

  Future<void> reorder(List<String> orderedGoalIds) async {
    for (var i = 0; i < orderedGoalIds.length; i++) {
      await _client.from('savings_goals').update({'priority_order': i}).eq('id', orderedGoalIds[i]);
    }
  }
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

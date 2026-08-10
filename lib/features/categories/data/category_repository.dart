import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'category.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(Supabase.instance.client);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).fetchCategories();
});

class CategoryRepository {
  CategoryRepository(this._client);

  final SupabaseClient _client;

  /// RLS already scopes this to the signed-in user's own categories.
  Future<List<Category>> fetchCategories() async {
    final rows = await _client.from('categories').select().order('name');
    return rows.map(Category.fromJson).toList();
  }

  Future<void> updateBudgetLimit(String categoryId, num? limit) {
    return _client.from('categories').update({'budget_limit': limit}).eq('id', categoryId);
  }

  /// Returns the newly created row (not just void) so callers like Catat's
  /// inline "+ Tambah kategori" shortcut can immediately select it without
  /// waiting on a full [categoriesProvider] refetch.
  Future<Category> createCategory({
    required String name,
    required CategoryKind kind,
    ExpenseType? expenseType,
    num? budgetLimit,
    int alertThresholdPct = 80,
    String? icon,
    String? color,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final row = await _client
        .from('categories')
        .insert({
          'user_id': userId,
          'name': name,
          'kind': kind.name,
          'expense_type': expenseType?.name,
          'budget_limit': budgetLimit,
          'alert_threshold_pct': alertThresholdPct,
          'icon': icon,
          'color': color,
        })
        .select()
        .single();
    return Category.fromJson(row);
  }

  Future<void> updateCategory({
    required String categoryId,
    required String name,
    ExpenseType? expenseType,
    num? budgetLimit,
    int alertThresholdPct = 80,
    String? icon,
    String? color,
  }) {
    return _client
        .from('categories')
        .update({
          'name': name,
          'expense_type': expenseType?.name,
          'budget_limit': budgetLimit,
          'alert_threshold_pct': alertThresholdPct,
          'icon': icon,
          'color': color,
        })
        .eq('id', categoryId);
  }

  /// Categories referenced by existing transactions can't be deleted
  /// (`on delete restrict`) — throws [PostgrestException] with code
  /// `23503` in that case, which the UI turns into a friendly message.
  Future<void> deleteCategory(String categoryId) {
    return _client.from('categories').delete().eq('id', categoryId);
  }
}

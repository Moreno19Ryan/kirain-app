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
}

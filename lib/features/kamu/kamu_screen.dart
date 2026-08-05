import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/data/auth_repository.dart';

class KamuScreen extends ConsumerWidget {
  const KamuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '-';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text('Kamu'),
            const SizedBox(height: 8),
            Text(email),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Kelola Kategori'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/kelola-kategori'),
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Target Nabung'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/target-nabung'),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Keluar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

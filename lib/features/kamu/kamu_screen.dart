import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/data/auth_repository.dart';

class KamuScreen extends ConsumerWidget {
  const KamuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '-';

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Kamu'),
            const SizedBox(height: 8),
            Text(email),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }
}

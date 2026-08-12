import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/data/energy_saver_repository.dart';
import '../app_lock/data/app_lock_repository.dart';
import '../auth/data/auth_repository.dart';
import 'data/account_repository.dart';

class KamuScreen extends ConsumerWidget {
  const KamuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '-';
    final lockEnabledAsync = ref.watch(appLockEnabledProvider);
    final energySaverAsync = ref.watch(energySaverEnabledProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text('Kamu'),
            const SizedBox(height: 8),
            Text(email),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
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
                  ListTile(
                    leading: const Icon(Icons.repeat_outlined),
                    title: const Text('Transaksi Berulang'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/transaksi-berulang'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.event_repeat_outlined),
                    title: const Text('Siklus Budget'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/siklus-budget'),
                  ),
                  lockEnabledAsync.when(
                    data: (enabled) => SwitchListTile(
                      secondary: const Icon(Icons.lock_outline),
                      title: const Text('Kunci Aplikasi'),
                      subtitle: const Text('PIN + biometrik (kalau device support)'),
                      value: enabled,
                      onChanged: (value) =>
                          value ? _setupAppLock(context, ref) : _disableAppLock(context, ref),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  energySaverAsync.when(
                    data: (enabled) => SwitchListTile(
                      secondary: const Icon(Icons.battery_saver_outlined),
                      title: const Text('Mode Hemat Energi'),
                      subtitle: const Text('Matiin efek blur kaca biar HP kamu tetap enteng dipake'),
                      value: enabled,
                      onChanged: (value) async {
                        await ref.read(energySaverRepositoryProvider).setEnabled(value);
                        ref.invalidate(energySaverEnabledProvider);
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Bantuan'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/bantuan'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Kebijakan Privasi'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/kebijakan-privasi'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Syarat & Ketentuan'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/syarat-ketentuan'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Hapus Akun',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    subtitle: const Text('Permanen, gak bisa dikembalikan lagi'),
                    onTap: () => _confirmDeleteAccount(context, ref),
                  ),
                ],
              ),
            ),
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

Future<void> _setupAppLock(BuildContext context, WidgetRef ref) async {
  final pinController = TextEditingController();
  final confirmController = TextEditingController();
  String? error;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Bikin PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('PIN ini jadi fallback kalau biometrik gak kepakai.'),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'PIN (6 digit)'),
                ),
                TextField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: InputDecoration(labelText: 'Ulangi PIN', errorText: error),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (pin.length != 6) {
                    setDialogState(() => error = 'PIN harus 6 digit');
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(() => error = 'PIN gak cocok, coba lagi');
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true) return;

  await ref.read(appLockRepositoryProvider).setPin(pinController.text.trim());
  ref.invalidate(appLockEnabledProvider);
}

Future<void> _disableAppLock(BuildContext context, WidgetRef ref) async {
  final pinController = TextEditingController();
  String? error;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Matiin Kunci Aplikasi?'),
            content: TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(labelText: 'Masukin PIN buat konfirmasi', errorText: error),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final ok = await ref
                      .read(appLockRepositoryProvider)
                      .verifyPin(pinController.text.trim());
                  if (!ok) {
                    setDialogState(() => error = 'PIN salah');
                    return;
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                },
                child: const Text('Matiin'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true) return;

  await ref.read(appLockRepositoryProvider).disable();
  ref.invalidate(appLockEnabledProvider);
}

/// Irreversible, so this asks for more than a tap — typing the exact
/// confirmation word, same pattern many apps use for destructive account
/// actions, on top of CLAUDE.md's usual "Yakin nih?" dialog.
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmController = TextEditingController();
  var isDeleting = false;
  String? error;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final canConfirm = confirmController.text.trim().toUpperCase() == 'HAPUS';

          return AlertDialog(
            title: const Text('Yakin banget nih?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Semua data kamu — transaksi, kategori, target nabung, '
                  'semuanya — bakal dihapus permanen. Ini gak bisa '
                  'dikembalikan lagi.',
                ),
                const SizedBox(height: 12),
                Text('Ketik HAPUS buat konfirmasi.'),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(labelText: 'Ketik HAPUS', errorText: error),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: !canConfirm || isDeleting
                    ? null
                    : () async {
                        setDialogState(() {
                          isDeleting = true;
                          error = null;
                        });
                        try {
                          await ref.read(accountRepositoryProvider).deleteAccount();
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          await ref.read(authRepositoryProvider).signOut();
                        } catch (_) {
                          setDialogState(() {
                            isDeleting = false;
                            error = 'Yah, gagal hapus akun. Coba lagi ya.';
                          });
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Hapus Akun Aku'),
              ),
            ],
          );
        },
      );
    },
  );
}

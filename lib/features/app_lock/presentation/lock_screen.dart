import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_lock_repository.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _checkingBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final repository = ref.read(appLockRepositoryProvider);
    if (!await repository.canUseBiometrics()) return;

    if (!mounted) return;
    setState(() => _checkingBiometric = true);

    final ok = await repository.authenticateWithBiometrics();

    if (!mounted) return;
    setState(() => _checkingBiometric = false);
    if (ok) widget.onUnlocked();
  }

  Future<void> _submitPin() async {
    final repository = ref.read(appLockRepositoryProvider);
    final ok = await repository.verifyPin(_pinController.text.trim());

    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'PIN salah, coba lagi ya');
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text(
                  'KIRAIN Terkunci',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Masukin PIN',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submitPin(),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _submitPin, child: const Text('Buka')),
                const SizedBox(height: 12),
                if (_checkingBiometric)
                  const CircularProgressIndicator()
                else
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Coba biometrik lagi'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_retry_view.dart';
import '../../home/data/dashboard_summary.dart';
import '../data/budget_settings_repository.dart';

class BudgetCycleSettingsScreen extends ConsumerWidget {
  const BudgetCycleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(budgetSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Siklus Budget')),
      body: settingsAsync.when(
        data: (settings) => _SettingsForm(settings: settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorRetryView(
          message: 'Gagal muat pengaturan. Coba lagi ya.',
          onRetry: () => ref.invalidate(budgetSettingsProvider),
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings});

  final BudgetSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late int _cycleStartDay = widget.settings.cycleStartDay;
  late bool _rolloverEnabled = widget.settings.rolloverEnabled;
  bool _isSaving = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(budgetSettingsRepositoryProvider)
          .update(cycleStartDay: _cycleStartDay, rolloverEnabled: _rolloverEnabled);
      ref.invalidate(budgetSettingsProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oke, siklus budget kamu udah diupdate.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Kapan siklus budget kamu mulai? Gak harus tanggal 1 kalau gajian kamu beda hari.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _cycleStartDay,
          decoration: const InputDecoration(
            labelText: 'Tanggal mulai siklus',
            border: OutlineInputBorder(),
          ),
          items: [
            for (var day = 1; day <= 31; day++)
              DropdownMenuItem(value: day, child: Text('Tanggal $day')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _cycleStartDay = value);
          },
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Rollover Budget'),
          subtitle: const Text(
            'Sisa atau kelebihan limit bulan ini kebawa ke siklus berikutnya, per kategori.',
          ),
          value: _rolloverEnabled,
          onChanged: (value) => setState(() => _rolloverEnabled = value),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }
}

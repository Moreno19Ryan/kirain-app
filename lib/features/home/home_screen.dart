import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../core/widgets/skeleton_box.dart';
import '../categories/data/category.dart';
import '../categories/data/category_repository.dart';
import '../tips/data/tip_provider.dart';
import '../tips/presentation/tip_card.dart';
import '../transactions/data/transaction_repository.dart';
import 'data/dashboard_summary.dart';
import 'data/home_widget_sync.dart';
import 'presentation/retroactive_entry_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    // Keeps the Android home-screen widget in step with whatever Home itself
    // just loaded — same freshness Home already has, no extra fetching.
    ref.listen(dashboardSummaryProvider, (_, next) => next.whenData(syncHomeWidget));
    final tip = ref.watch(dailyTipProvider);
    final isNewAccount = ref
        .watch(hasAnyTransactionsProvider)
        .maybeWhen(data: (hasAny) => !hasAny, orElse: () => false);

    return Scaffold(
      appBar: AppBar(title: const Text('KIRAIN')),
      body: SafeArea(
        child: summaryAsync.when(
          data: (summary) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isNewAccount) ...[
                  const RetroactiveEntryBanner(),
                  const SizedBox(height: 16),
                ],
                TipCard(tip: tip),
                const SizedBox(height: 16),
                _BudgetSection(title: 'Progress Cukup', summary: summary.wajib),
                const SizedBox(height: 24),
                _BudgetSection(title: 'Keinginan', summary: summary.keinginan),
              ],
            ),
          ),
          loading: () => const _HomeSkeleton(),
          error: (_, _) => ErrorRetryView(
            message: 'Gagal muat data. Coba lagi ya.',
            onRetry: () => ref.invalidate(dashboardSummaryProvider),
          ),
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [_SectionSkeleton(), SizedBox(height: 24), _SectionSkeleton()],
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(width: 120, height: 18),
            SizedBox(height: 12),
            SkeletonBox(height: 10),
            SizedBox(height: 8),
            SkeletonBox(width: 160, height: 14),
          ],
        ),
      ),
    );
  }
}

class _BudgetSection extends StatelessWidget {
  const _BudgetSection({required this.title, required this.summary});

  final String title;
  final BudgetGroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasLimit = summary.hasLimit;
    final isOver = hasLimit && summary.ratio >= 1.0;
    final zoneLabel = hasLimit ? (isOver ? 'Zona Kirain' : 'Zona Aman') : null;
    final zoneColor = isOver
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (zoneLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      zoneLabel,
                      style: TextStyle(color: zoneColor, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            _PeriodComparisonLabel(summary: summary),
            const SizedBox(height: 8),
            if (!hasLimit)
              const Text('Belum ada limit yang diset buat kategori ini.')
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: summary.ratio.clamp(0, 1).toDouble(),
                  minHeight: 10,
                  color: zoneColor,
                  backgroundColor: zoneColor.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                summary.totalLimit > 0
                    ? 'Rp ${formatRupiahShort(summary.totalSpent)} dari Rp ${formatRupiahShort(summary.totalLimit)}'
                    : 'Rp ${formatRupiahShort(summary.totalSpent)} dari Rp 0 (limit abis kepake defisit bulan lalu)',
              ),
              if (summary.totalRollover != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    summary.totalRollover > 0
                        ? 'Termasuk bawaan bulan lalu: +Rp ${formatRupiahShort(summary.totalRollover)}'
                        : 'Termasuk bawaan defisit bulan lalu: -Rp ${formatRupiahShort(summary.totalRollover.abs())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (isOver)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Bulan ini kebablasan nih, gapapa. Yuk kita rapiin lagi bulan depan 💪',
                    style: TextStyle(color: zoneColor),
                  ),
                ),
            ],
            if (summary.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Rincian per kategori'),
                children: summary.items.map((item) => _CategoryTile(item: item)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodComparisonLabel extends StatelessWidget {
  const _PeriodComparisonLabel({required this.summary});

  final BudgetGroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final change = summary.percentChangeFromPrevious;
    if (change == null) return const SizedBox.shrink();

    final rounded = change.abs().round();
    final String text;
    final IconData icon;
    if (rounded == 0) {
      text = 'Sama kayak bulan lalu';
      icon = Icons.horizontal_rule;
    } else if (change > 0) {
      text = 'Naik $rounded% dari bulan lalu';
      icon = Icons.arrow_upward;
    } else {
      text = 'Turun $rounded% dari bulan lalu';
      icon = Icons.arrow_downward;
    }

    final color = Theme.of(context).textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.item});

  final CategorySpend item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = item.category.budgetLimit;
    final hasLimit = limit != null && limit > 0;
    final over = hasLimit && item.spent > item.effectiveLimit;
    final ratio = hasLimit && item.effectiveLimit > 0 ? item.spent / item.effectiveLimit : 0.0;
    final isWarning = !over && hasLimit && ratio >= item.category.alertThresholdPct / 100;
    const warningColor = Colors.orange;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.category.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !hasLimit
                ? 'Rp ${formatRupiah(item.spent)} · belum ada limit'
                : 'Rp ${formatRupiah(item.spent)} dari Rp ${formatRupiah(item.effectiveLimit)}',
            style: over
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : isWarning
                ? const TextStyle(color: warningColor)
                : null,
          ),
          if (isWarning)
            const Text(
              'Zona Waspada — udah mendekati limit nih',
              style: TextStyle(color: warningColor, fontSize: 12),
            ),
          if (item.rollover != 0)
            Text(
              item.rollover > 0
                  ? 'Bawaan bulan lalu: +Rp ${formatRupiah(item.rollover)}'
                  : 'Bawaan defisit bulan lalu: -Rp ${formatRupiah(item.rollover.abs())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => _showEditLimitDialog(context, ref, item.category),
    );
  }
}

Future<void> _showEditLimitDialog(BuildContext context, WidgetRef ref, Category category) async {
  final controller = TextEditingController(
    text: category.budgetLimit == null ? '' : category.budgetLimit!.toStringAsFixed(0),
  );

  final result = await showDialog<num>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Limit ${category.name}'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Limit per siklus (Rp)'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final value = num.tryParse(controller.text.trim());
            Navigator.pop(dialogContext, value ?? 0);
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );

  if (result == null) return;

  await ref.read(categoryRepositoryProvider).updateBudgetLimit(category.id, result);
  ref.invalidate(categoriesProvider);
  ref.invalidate(dashboardSummaryProvider);
}

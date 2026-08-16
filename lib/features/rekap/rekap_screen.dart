import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/local_outbox_table.dart';
import '../../core/sync/sync_worker.dart';
import '../../core/theme/kirain_colors.dart';
import '../../core/utils/format.dart';
import '../categories/data/category.dart';
import '../categories/data/category_icons.dart';
import '../categories/data/category_repository.dart';
import '../home/data/dashboard_summary.dart';
import '../transactions/data/transaction_repository.dart';
import 'data/csv_export.dart';

class RekapScreen extends ConsumerStatefulWidget {
  const RekapScreen({super.key});

  @override
  ConsumerState<RekapScreen> createState() => _RekapScreenState();
}

class _RekapScreenState extends ConsumerState<RekapScreen> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  final List<TransactionHistoryItem> _items = [];

  /// How many *confirmed-synced* items have been loaded so far — the
  /// Supabase page offset for the next [_loadMore] call. Deliberately not
  /// `_items.length`: OFFLINE-003's pending overlay (injected only on the
  /// `reset: true` / first page) adds extra rows on top of the page without
  /// consuming a page slot (see `fetchHistoryWithPending`'s doc comment), so
  /// counting them into the offset would skip that many real Supabase rows
  /// on the next page.
  int _syncedCount = 0;
  Category? _categoryFilter;
  DateTimeRange? _dateFilter;
  String _search = '';
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_isLoading) return;
    if (!reset && !_hasMore) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _items.clear();
        _syncedCount = 0;
        _hasMore = true;
      }
    });

    try {
      final page = await ref
          .read(transactionRepositoryProvider)
          .fetchHistoryWithPending(
            limit: _pageSize,
            offset: _syncedCount,
            categoryId: _categoryFilter?.id,
            startDate: _dateFilter?.start,
            endDate: _dateFilter?.end.add(const Duration(days: 1)),
            searchText: _search,
          );
      // Pending rows never came from a Supabase page, so they don't count
      // toward the offset/hasMore math below — see [_syncedCount]'s doc.
      final syncedPageLength = page.where((item) => item.pendingStatus == null).length;

      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _syncedCount += syncedPageLength;
        _hasMore = syncedPageLength == _pageSize;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _export() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final items = await ref
          .read(transactionRepositoryProvider)
          .fetchForExport(
            categoryId: _categoryFilter?.id,
            startDate: _dateFilter?.start,
            endDate: _dateFilter?.end.add(const Duration(days: 1)),
            searchText: _search,
          );

      if (!mounted) return;

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gak ada transaksi buat diekspor nih.')),
        );
        return;
      }

      await shareTransactionsCsv(items);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yah, gagal bikin file ekspornya. Coba lagi ya.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _applyFilters() => _loadMore(reset: true);

  void _clearCategoryFilter() {
    setState(() => _categoryFilter = null);
    _applyFilters();
  }

  void _clearDateFilter() {
    setState(() => _dateFilter = null);
    _applyFilters();
  }

  Future<void> _openFilterSheet(List<Category> categories) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Filter', style: Theme.of(sheetContext).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Category?>(
                    initialValue: _categoryFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua kategori')),
                      ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
                    ],
                    onChanged: (value) {
                      setSheetState(() => _categoryFilter = value);
                      setState(() {});
                      _applyFilters();
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: sheetContext,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _dateFilter,
                      );
                      if (range == null) return;
                      setSheetState(() => _dateFilter = range);
                      setState(() {});
                      _applyFilters();
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      _dateFilter == null
                          ? 'Pilih rentang tanggal'
                          : '${formatDate(_dateFilter!.start)} - ${formatDate(_dateFilter!.end)}',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Selesai'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.maybeWhen(data: (c) => c, orElse: () => const <Category>[]);
    final categoryById = {for (final c in categories) c.id: c};
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final hasActiveFilter = _categoryFilter != null || _dateFilter != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Kirain'),
        actions: [
          IconButton(
            onPressed: _isExporting ? null : _export,
            icon: _isExporting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
            tooltip: 'Ekspor CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Cari transaksi...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          _search = value.trim();
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: () => _openFilterSheet(categories),
                      icon: const Icon(Icons.tune),
                      tooltip: 'Filter',
                    ),
                  ],
                ),
                if (hasActiveFilter) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_categoryFilter != null)
                        InputChip(
                          label: Text('Kategori: ${_categoryFilter!.name}'),
                          onDeleted: _clearCategoryFilter,
                        ),
                      if (_dateFilter != null)
                        InputChip(
                          label: Text(
                            '${formatDate(_dateFilter!.start)} - ${formatDate(_dateFilter!.end)}',
                          ),
                          onDeleted: _clearDateFilter,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                summaryAsync.maybeWhen(
                  data: (summary) => _PeriodComparisonCard(summary: summary),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty && !_isLoading
                ? Center(
                    child: Text(
                      hasActiveFilter || _search.isNotEmpty
                          ? 'Gak ada transaksi yang cocok sama filter ini.'
                          : 'Belum ada catatan nih. Yuk mulai dari transaksi pertama, biar gak kirain-kirain lagi 👀',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    children: [
                      ..._buildGroupedRows(categoryById),
                      if (_hasMore)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Groups the already date-descending [_items] into "Hari ini" / "Kemarin"
  /// / specific-date sections, in one pass since the query already sorts by
  /// transaction_date desc.
  List<Widget> _buildGroupedRows(Map<String, Category> categoryById) {
    final widgets = <Widget>[];
    String? currentLabel;

    for (final item in _items) {
      final label = _groupLabel(item.transactionDate);
      if (label != currentLabel) {
        if (currentLabel != null) widgets.add(const SizedBox(height: 16));
        widgets.add(_DateGroupHeader(label: label));
        widgets.add(const SizedBox(height: 8));
        currentLabel = label;
      } else {
        widgets.add(const SizedBox(height: 8));
      }
      widgets.add(_TransactionCard(item: item, category: categoryById[item.categoryId]));
    }

    return widgets;
  }

  String _groupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(date.year, date.month, date.day);

    if (day == today) return 'Hari ini';
    if (day == yesterday) return 'Kemarin';
    return formatDate(date);
  }
}

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({required this.item, required this.category});

  final TransactionHistoryItem item;

  /// Null for savings contributions (goal-linked, no category) or while
  /// [categoriesProvider] hasn't resolved yet — falls back to a generic
  /// icon/neutral color in that case.
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kirainColors = theme.extension<KirainColors>();
    final mintStrong = kirainColors?.mintStrong ?? theme.colorScheme.onPrimaryContainer;
    final coralStrong = kirainColors?.coralStrong ?? theme.colorScheme.onSecondaryContainer;
    final neutral = theme.colorScheme.onSurfaceVariant;

    final IconData icon;
    final Color iconColor;
    if (item.isSavingsContribution) {
      icon = Icons.savings_outlined;
      iconColor = neutral;
    } else if (category != null) {
      icon = categoryIcon(category!);
      iconColor = categoryIconColor(
        category: category!,
        mintStrong: mintStrong,
        coralStrong: coralStrong,
        neutral: neutral,
        brightness: theme.brightness,
      );
    } else {
      icon = Icons.receipt_long_outlined;
      iconColor = neutral;
    }

    final sign = item.isIncome ? '+' : '-';
    final amountColor = item.isIncome ? mintStrong : theme.colorScheme.onSurface;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isSavingsContribution) ...[
                        const SizedBox(width: 6),
                        _NabungBadge(color: neutral),
                      ],
                      if (item.pendingStatus != null) ...[
                        const SizedBox(width: 6),
                        _SyncStatusBadge(
                          status: item.pendingStatus!,
                          onRetry: item.pendingStatus == OutboxSyncStatus.failed
                              ? () => ref.read(syncWorkerProvider).retryFailedItem(item.id)
                              : null,
                        ),
                      ],
                    ],
                  ),
                  if (item.note != null && item.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.note!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$sign Rp ${formatRupiah(item.amount)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: amountColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _NabungBadge extends StatelessWidget {
  const _NabungBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
      child: Text(
        'NABUNG',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// OFFLINE-003's optimistic-overlay indicator — shown only on
/// [TransactionHistoryItem]s with a non-null `pendingStatus`, i.e. rows that
/// only exist on-device so far (see that field's doc comment). PENDING and
/// SYNCING both read as "belum tersinkron" (the user doesn't need to
/// distinguish "queued" from "sending right now"); FAILED gets its own
/// label plus a tap target that retries — the "ketuk buat coba lagi"
/// CLAUDE.md calls for.
class _SyncStatusBadge extends StatelessWidget {
  const _SyncStatusBadge({required this.status, this.onRetry});

  final OutboxSyncStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = status == OutboxSyncStatus.failed;
    final color = isFailed
        ? (theme.extension<KirainColors>()?.coralStrong ?? theme.colorScheme.error)
        : theme.colorScheme.onSurfaceVariant;
    final label = isFailed ? 'Gagal disinkron' : 'Belum tersinkron';

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );

    if (onRetry == null) return badge;
    return Tooltip(
      message: 'Ketuk buat coba lagi',
      child: InkWell(onTap: onRetry, borderRadius: BorderRadius.circular(6), child: badge),
    );
  }
}

/// "Naik/turun X% dari bulan lalu" per group, reusing the same
/// [BudgetGroupSummary.percentChangeFromPrevious] Home's hero card already
/// computes — shown here per kirain-rekap-mockup.jsx so the comparison is
/// visible while browsing history, not just on Home.
class _PeriodComparisonCard extends StatelessWidget {
  const _PeriodComparisonCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _buildRow(context, 'Wajib', summary.wajib),
      _buildRow(context, 'Keinginan', summary.keinginan),
    ].whereType<Widget>().toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
      ),
    );
  }

  Widget? _buildRow(BuildContext context, String label, BudgetGroupSummary group) {
    final change = group.percentChangeFromPrevious;
    if (change == null) return null;

    final theme = Theme.of(context);
    final mintStrong = theme.extension<KirainColors>()?.mintStrong ?? theme.colorScheme.onPrimaryContainer;
    final rounded = change.abs().round();

    final IconData icon;
    final String phrase;
    if (rounded == 0) {
      icon = Icons.horizontal_rule;
      phrase = 'sama';
    } else if (change > 0) {
      icon = Icons.arrow_upward;
      phrase = 'naik $rounded%';
    } else {
      icon = Icons.arrow_downward;
      phrase = 'turun $rounded%';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: mintStrong),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodySmall,
                children: [
                  TextSpan(text: 'Pengeluaran $label kamu '),
                  TextSpan(text: phrase, style: TextStyle(color: mintStrong, fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' dari bulan lalu'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

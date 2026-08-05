import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../categories/data/category.dart';
import '../categories/data/category_repository.dart';
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
        _hasMore = true;
      }
    });

    try {
      final page = await ref
          .read(transactionRepositoryProvider)
          .fetchHistory(
            limit: _pageSize,
            offset: _items.length,
            categoryId: _categoryFilter?.id,
            startDate: _dateFilter?.start,
            endDate: _dateFilter?.end.add(const Duration(days: 1)),
            searchText: _search,
          );

      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
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

  void _resetFilters() {
    setState(() {
      _categoryFilter = null;
      _dateFilter = null;
      _search = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final hasActiveFilter = _categoryFilter != null || _dateFilter != null || _search.isNotEmpty;

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
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cari catatan...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    _search = value.trim();
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: categoriesAsync.maybeWhen(
                        data: (categories) => DropdownButtonFormField<Category?>(
                          initialValue: _categoryFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Semua kategori')),
                            ...categories.map(
                              (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _categoryFilter = value);
                            _applyFilters();
                          },
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: _dateFilter,
                        );
                        if (range == null) return;
                        setState(() => _dateFilter = range);
                        _applyFilters();
                      },
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                        _dateFilter == null
                            ? 'Tanggal'
                            : '${formatDate(_dateFilter!.start)} - ${formatDate(_dateFilter!.end)}',
                      ),
                    ),
                  ],
                ),
                if (hasActiveFilter)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset filter'),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty && !_isLoading
                ? Center(
                    child: Text(
                      hasActiveFilter
                          ? 'Gak ada transaksi yang cocok sama filter ini.'
                          : 'Belum ada catatan nih. Yuk mulai dari transaksi pertama, biar gak kirain-kirain lagi 👀',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final item = _items[index];
                      return ListTile(
                        leading: item.isSavingsContribution
                            ? const Icon(Icons.savings_outlined)
                            : null,
                        title: Text(item.displayName),
                        subtitle: Text(
                          [
                            formatDate(item.transactionDate),
                            if (item.isSavingsContribution) 'Tabungan',
                            if (item.note != null && item.note!.isNotEmpty) item.note!,
                          ].join(' · '),
                        ),
                        trailing: Text('Rp ${formatRupiah(item.amount)}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/local_first_transaction_service.dart';
import '../../core/sync/sync_lifecycle_gate.dart';
import '../../core/theme/kirain_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../core/widgets/skeleton_box.dart';
import '../categories/data/category.dart';
import '../categories/data/category_icons.dart';
import '../categories/data/category_repository.dart';
import '../categories/presentation/category_form_dialog.dart';
import '../goals/data/savings_goal.dart';
import '../goals/data/savings_goal_repository.dart';
import '../home/data/dashboard_summary.dart';
import '../transactions/data/transaction_repository.dart';
import 'data/riba_detector.dart';

enum _CatatMode { transaksi, nabung }

class CatatScreen extends ConsumerStatefulWidget {
  const CatatScreen({super.key});

  @override
  ConsumerState<CatatScreen> createState() => _CatatScreenState();
}

class _CatatScreenState extends ConsumerState<CatatScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  _CatatMode _mode = _CatatMode.transaksi;
  Category? _selectedCategory;
  ExpenseType? _expenseType;
  SavingsGoal? _selectedGoal;
  DateTime _transactionDate = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;
  _SavedSummary? _lastSaved;

  /// OFFLINE-003's double-tap guard. Deliberately *not* the same thing as
  /// [_isSaving]: that one only takes effect once `setState` has actually
  /// rebuilt the button as disabled, which happens on the next frame — a
  /// second tap landing in the gap between the first tap and that rebuild
  /// (e.g. during the checkout-warning/duplicate dialogs' `await`s, which
  /// run *before* [_isSaving] is ever set) would still slip through and
  /// re-enter [_submit]. This field is checked and set synchronously, as
  /// the very first thing [_submit] does, so a second call sees it already
  /// `true` immediately — no frame, no `await`, no race window.
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Drives the inline riba banner live as the user types, per CLAUDE.md's
    // "soft warning inline" requirement — no dialog gate at submit anymore.
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() => setState(() {});

  void _onCategorySelected(Category category) {
    setState(() {
      _selectedCategory = category;
      _expenseType = category.expenseType;
    });
  }

  /// "+ Tambah kategori" shortcut per CLAUDE.md 6.5 — same dialog Kelola
  /// Kategori uses, but without leaving the recording flow. Selects the new
  /// category right away so the user can keep going.
  Future<void> _onAddCategory() async {
    final created = await showCategoryFormDialog(context, ref);
    if (created != null) _onCategorySelected(created);
  }

  Future<void> _submit() async {
    // Synchronous guard — see [_isSubmitting]'s doc comment for why this has
    // to be the very first line, before even `_formKey.currentState!.validate()`.
    if (_isSubmitting) return;
    _isSubmitting = true;
    try {
      await _doSubmit();
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> _doSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_mode == _CatatMode.nabung) {
      await _submitSavingsContribution();
      return;
    }

    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Pilih kategori dulu ya');
      return;
    }

    // Whole Rupiah only — the amount field's keyboard is decimal-disabled,
    // and `LocalFirstTransactionService.recordTransaction` requires an int
    // (see its doc comment for why the local-first path is int, not num).
    final amount = num.parse(_amountController.text.trim()).round();
    final category = _selectedCategory!;
    final effectiveType = category.kind == CategoryKind.expense ? _expenseType : null;

    if (effectiveType == ExpenseType.keinginan) {
      final wajib = ref.read(dashboardSummaryProvider).value?.wajib;
      if (wajib != null && wajib.hasLimit && wajib.ratio < 1.0) {
        final proceed = await _showCheckoutWarning(wajib.ratio);
        if (proceed != true) return;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Soft, non-blocking check per CLAUDE.md — a failure here (e.g.
      // offline, no Supabase reachable) must never stop the save itself,
      // so it's treated the same as "not a duplicate" rather than
      // surfaced as an error.
      var isDuplicate = false;
      try {
        isDuplicate = await ref
            .read(transactionRepositoryProvider)
            .hasPossibleDuplicate(categoryId: category.id, amount: amount, date: DateTime.now());
      } catch (_) {
        isDuplicate = false;
      }

      if (isDuplicate) {
        if (!mounted) return;
        final proceed = await _confirmDuplicate(category, amount);
        if (proceed != true) return;
      }

      final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

      // Local-first (OFFLINE-003): lands in the local DB instantly, works
      // offline, and syncs to Supabase in the background — see
      // LocalFirstTransactionService's doc comment. Goals/Recurring stay on
      // the direct-to-Supabase `TransactionRepository.addTransaction` path;
      // this is Catat-only, per the approved design's scope.
      await ref
          .read(localFirstTransactionServiceProvider)
          .recordTransaction(
            id: newId(),
            categoryId: category.id,
            amount: amount,
            note: note,
            expenseType: effectiveType?.name,
            transactionDate: _transactionDate,
          );
      triggerSyncAfterOutboxInsertion(ref);

      setState(() {
        _lastSaved = _SavedSummary(category: category.name, amount: amount);
      });
      ref.invalidate(dashboardSummaryProvider);
    } catch (_) {
      setState(() {
        _errorMessage = 'Yah, gagal kesimpen. Coba cek internet kamu ya 🔌';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submitSavingsContribution() async {
    final goal = _selectedGoal;
    if (goal == null) {
      setState(() => _errorMessage = 'Pilih target nabung dulu ya');
      return;
    }

    final amount = num.parse(_amountController.text.trim());

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(savingsGoalRepositoryProvider)
          .contribute(
            goalId: goal.id,
            amount: amount,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );

      setState(() {
        _lastSaved = _SavedSummary(category: goal.name, amount: amount);
      });
      ref.invalidate(savingsGoalsProvider);
    } catch (_) {
      setState(() {
        _errorMessage = 'Yah, gagal kesimpen. Coba cek internet kamu ya 🔌';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Soft warning per CLAUDE.md — never blocks, just double-checks.
  Future<bool?> _confirmDuplicate(Category category, num amount) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transaksi mirip nih'),
        content: Text(
          'Kamu udah catat Rp ${formatRupiah(amount)} di kategori ${category.name} hari ini. '
          'Mau catat lagi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tetap Catat'),
          ),
        ],
      ),
    );
  }

  /// Soft, non-blocking checkout warning from kirain-states-mockup.jsx —
  /// shown only when this transaction would land in Keinginan while Wajib
  /// still isn't fully covered. The two buttons carry different visual
  /// weight on purpose ("Cek lagi" neutral, "Lanjut Catat" positive/mint) so
  /// proceeding never feels like being punished.
  Future<bool?> _showCheckoutWarning(double wajibRatio) {
    final theme = Theme.of(context);
    final coral = theme.extension<KirainColors>()?.coral ?? theme.colorScheme.secondary;
    final coralStrong = theme.extension<KirainColors>()?.coralStrong ?? theme.colorScheme.onSecondaryContainer;
    final pct = (wajibRatio * 100).round();

    return showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: coral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.warning_amber_rounded, color: coralStrong, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Eh tunggu dulu', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Kebutuhan wajib bulan ini belum full nih (masih $pct%). '
                          'Yakin mau lanjut catat yang ini?',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('Cek lagi'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Lanjut Catat'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bounded the same way as Rekap's date-range filter. Kept selected across
  /// "Tambah Lagi" taps (not reset to today) — the point of retroactive
  /// entry is backfilling several past transactions in a row, so forcing a
  /// re-pick on every single one would defeat that.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _transactionDate = picked);
  }

  void _addAnother() {
    setState(() {
      _amountController.clear();
      _noteController.clear();
      _lastSaved = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    // Warmed here (not just read at submit time) so it's already resolved
    // by the time the user taps "Oke, Catat" — the checkout-warning check
    // needs the data synchronously at that point.
    ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catat')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _lastSaved != null
              ? _SuccessState(saved: _lastSaved!, onAddAnother: _addAnother)
              : categoriesAsync.when(
                  data: _buildForm,
                  loading: () => const _CatatSkeleton(),
                  error: (_, _) => ErrorRetryView(
                    message: 'Gagal muat kategori. Coba lagi ya.',
                    onRetry: () => ref.invalidate(categoriesProvider),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildForm(List<Category> categories) {
    final wajibCategories = categories
        .where((c) => c.kind == CategoryKind.expense && c.expenseType == ExpenseType.wajib)
        .toList();
    final keinginanCategories = categories
        .where((c) => c.kind == CategoryKind.expense && c.expenseType == ExpenseType.keinginan)
        .toList();
    final incomeCategories = categories.where((c) => c.kind == CategoryKind.income).toList();
    final theme = Theme.of(context);
    final kirainColors = theme.extension<KirainColors>();
    final mint = kirainColors?.mint ?? theme.colorScheme.primary;
    final coral = kirainColors?.coral ?? theme.colorScheme.secondary;
    final mintStrong = kirainColors?.mintStrong ?? theme.colorScheme.onPrimaryContainer;
    final coralStrong = kirainColors?.coralStrong ?? theme.colorScheme.onSecondaryContainer;
    final neutral = theme.colorScheme.onSurfaceVariant;

    return Form(
      key: _formKey,
      child: ListView(
        children: [
          // Reflects the exclusive category_id / goal_id constraint on the
          // transactions table — the two modes are mutually exclusive, never
          // shown at once.
          SegmentedButton<_CatatMode>(
            segments: const [
              ButtonSegment(value: _CatatMode.transaksi, label: Text('Transaksi')),
              ButtonSegment(value: _CatatMode.nabung, label: Text('Nabung')),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => setState(() => _mode = selection.first),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: const InputDecoration(labelText: 'Jumlah (Rp)', border: OutlineInputBorder()),
            validator: (value) {
              final amount = num.tryParse(value?.trim() ?? '');
              if (amount == null || amount <= 0) return 'Masukin jumlah yang valid';
              return null;
            },
          ),
          const SizedBox(height: 20),
          if (_mode == _CatatMode.transaksi) ...[
            Text('Kategori', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _CategorySection(
              title: 'Wajib',
              categories: wajibCategories,
              color: mint,
              strongColor: mintStrong,
              selected: _selectedCategory,
              onSelected: _onCategorySelected,
            ),
            _CategorySection(
              title: 'Keinginan',
              categories: keinginanCategories,
              color: coral,
              strongColor: coralStrong,
              selected: _selectedCategory,
              onSelected: _onCategorySelected,
            ),
            _CategorySection(
              title: 'Pemasukan',
              categories: incomeCategories,
              color: neutral,
              strongColor: neutral,
              selected: _selectedCategory,
              onSelected: _onCategorySelected,
              // Shortcut per CLAUDE.md 6.5 — lives on this section rather
              // than all three so it doesn't repeat, and this one's
              // guaranteed to render (see showAddButton) even for a
              // brand-new account with no income categories yet.
              showAddButton: true,
              onAddCategory: _onAddCategory,
            ),
            if (_selectedCategory?.kind == CategoryKind.expense) ...[
              const SizedBox(height: 4),
              Text(
                'Ini termasuk yang mana? (bisa diubah dari default kategori)',
                style: theme.textTheme.bodySmall?.copyWith(color: neutral),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TypeTogglePill(
                      label: 'Wajib',
                      color: mint,
                      strongColor: mintStrong,
                      active: _expenseType == ExpenseType.wajib,
                      onTap: () => setState(() => _expenseType = ExpenseType.wajib),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeTogglePill(
                      label: 'Keinginan',
                      color: coral,
                      strongColor: coralStrong,
                      active: _expenseType == ExpenseType.keinginan,
                      onTap: () => setState(() => _expenseType = ExpenseType.keinginan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ] else
            _GoalPicker(selected: _selectedGoal, onSelected: (g) => setState(() => _selectedGoal = g)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('Tanggal: ${formatDate(_transactionDate)}'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_mode == _CatatMode.transaksi && looksLikeRiba(_noteController.text)) ...[
            const SizedBox(height: 12),
            _RibaBanner(coral: coral, coralStrong: coralStrong),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Oke, Catat'),
          ),
        ],
      ),
    );
  }
}

/// One Wajib/Keinginan/Pemasukan group of horizontally-scrollable category
/// chips — hides itself entirely when the user has no categories of that
/// kind, same auto-collapse spirit as Home's empty-category handling.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.categories,
    required this.color,
    required this.strongColor,
    required this.selected,
    required this.onSelected,
    this.showAddButton = false,
    this.onAddCategory,
  });

  final String title;
  final List<Category> categories;
  final Color color;

  /// Used for the inactive chip's icon — see [_CategoryChip].
  final Color strongColor;
  final Category? selected;
  final ValueChanged<Category> onSelected;

  /// Renders a trailing "+ Tambah kategori" chip and keeps this section
  /// visible even when [categories] is empty, so a brand-new account
  /// (nothing in this group yet) still has a guaranteed way to add one —
  /// unlike the other sections, which auto-collapse when empty.
  final bool showAddButton;
  final VoidCallback? onAddCategory;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty && !showAddButton) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final itemCount = categories.length + (showAddButton ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index >= categories.length) {
                  return _AddCategoryChip(onTap: onAddCategory!);
                }
                final category = categories[index];
                return _CategoryChip(
                  category: category,
                  color: color,
                  strongColor: strongColor,
                  active: selected?.id == category.id,
                  onTap: () => onSelected(category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "+ Tambah kategori" — same footprint as [_CategoryChip] so it reads as
/// part of the row, not a bolted-on extra.
class _AddCategoryChip extends StatelessWidget {
  const _AddCategoryChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Icon(Icons.add, color: theme.colorScheme.onSurfaceVariant, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambah',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.color,
    required this.strongColor,
    required this.active,
    required this.onTap,
  });

  final Category category;
  final Color color;

  /// Icon color while inactive — [color] itself is a bright fill tone, which
  /// on the near-transparent inactive background (`color` at 12% alpha) is
  /// exactly the low-contrast "mint-on-pale-mint" case CLAUDE.md's fill-vs-
  /// strong principle warns about, so this needs the darker strong variant.
  final Color strongColor;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A category-level custom color (CLAUDE.md "Kustomisasi Icon & Warna
    // Kategori") overrides the section's default mint/coral/neutral fill.
    final resolvedColor = categoryFillColor(category) ?? color;
    final iconColor = active
        ? categoryIconColor(
            category: category,
            mintStrong: theme.colorScheme.onPrimary,
            coralStrong: theme.colorScheme.onSecondary,
            neutral: theme.colorScheme.onSurface,
            brightness: theme.brightness,
          )
        : categoryIconColor(
            category: category,
            mintStrong: strongColor,
            coralStrong: strongColor,
            neutral: strongColor,
            brightness: theme.brightness,
          );

    const duration = Duration(milliseconds: 200);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: active ? resolvedColor : resolvedColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? resolvedColor : theme.colorScheme.outline,
                  width: active ? 2 : 1,
                ),
              ),
              child: AnimatedSwitcher(
                duration: duration,
                child: Icon(categoryIcon(category), color: iconColor, size: 20, key: ValueKey(active)),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: duration,
              curve: Curves.easeOut,
              style: theme.textTheme.labelSmall!.copyWith(
                color: active ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTogglePill extends StatelessWidget {
  const _TypeTogglePill({
    required this.label,
    required this.color,
    required this.strongColor,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color color;

  /// Used for the label text when active — [color] alone reads too pale as
  /// text on the light tint background (same fill-vs-strong issue as
  /// [_CategoryChip]).
  final Color strongColor;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const duration = Duration(milliseconds: 200);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.16) : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? color : theme.colorScheme.outline, width: active ? 2 : 1),
        ),
        child: AnimatedDefaultTextStyle(
          duration: duration,
          curve: Curves.easeOut,
          style: theme.textTheme.bodyMedium!.copyWith(
            color: active ? strongColor : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Inline, non-blocking — replaces the old submit-time dialog so the notice
/// shows up live as the user types instead of gating the save.
class _RibaBanner extends StatelessWidget {
  const _RibaBanner({required this.coral, required this.coralStrong});

  final Color coral;
  final Color coralStrong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: coral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: coral.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: coralStrong),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Eh, ini kedengerannya kayak transaksi berbunga (riba) ya? Yuk coba '
              'dipikir ulang, atau kalau emang udah jalan, yuk kita bantu lunasin '
              'secepatnya 🙏',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalPicker extends ConsumerWidget {
  const _GoalPicker({required this.selected, required this.onSelected});

  final SavingsGoal? selected;
  final ValueChanged<SavingsGoal?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsProvider);

    return goalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return const Text(
            'Belum ada Target Nabung nih. Yuk bikin dulu dari menu Kamu > Target Nabung 👀',
          );
        }
        return DropdownButtonFormField<SavingsGoal>(
          initialValue: selected,
          decoration: const InputDecoration(labelText: 'Target Nabung', border: OutlineInputBorder()),
          items: goals
              .map(
                (g) => DropdownMenuItem(
                  value: g,
                  child: Text('${g.name} (${(g.progress * 100).round()}%)'),
                ),
              )
              .toList(),
          onChanged: onSelected,
        );
      },
      loading: () => const SkeletonBox(height: 56),
      error: (_, _) => ErrorRetryView(
        message: 'Gagal muat target nabung. Coba lagi ya.',
        onRetry: () => ref.invalidate(savingsGoalsProvider),
      ),
    );
  }
}

class _CatatSkeleton extends StatelessWidget {
  const _CatatSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SkeletonBox(height: 40),
        SizedBox(height: 20),
        SkeletonBox(height: 56),
        SizedBox(height: 20),
        SkeletonBox(height: 92),
        SizedBox(height: 16),
        SkeletonBox(height: 56),
        SizedBox(height: 24),
        SkeletonBox(height: 48),
      ],
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.saved, required this.onAddAnother});

  final _SavedSummary saved;
  final VoidCallback onAddAnother;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('Tercatat! ${saved.category} · Rp ${formatRupiah(saved.amount)}'),
          const SizedBox(height: 24),
          FilledButton(onPressed: onAddAnother, child: const Text('Tambah Lagi')),
        ],
      ),
    );
  }
}

class _SavedSummary {
  const _SavedSummary({required this.category, required this.amount});

  final String category;
  final num amount;
}

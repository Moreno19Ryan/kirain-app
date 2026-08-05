import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/skeleton_box.dart';
import '../categories/data/category.dart';
import '../categories/data/category_repository.dart';
import '../transactions/data/transaction_repository.dart';

class CatatScreen extends ConsumerStatefulWidget {
  const CatatScreen({super.key});

  @override
  ConsumerState<CatatScreen> createState() => _CatatScreenState();
}

class _CatatScreenState extends ConsumerState<CatatScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  Category? _selectedCategory;
  ExpenseType? _expenseType;
  bool _isSaving = false;
  String? _errorMessage;
  _SavedSummary? _lastSaved;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(Category? category) {
    setState(() {
      _selectedCategory = category;
      _expenseType = category?.expenseType;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Pilih kategori dulu ya');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final amount = num.parse(_amountController.text.trim());
    final category = _selectedCategory!;

    try {
      await ref
          .read(transactionRepositoryProvider)
          .addTransaction(
            categoryId: category.id,
            amount: amount,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            expenseType: category.kind == CategoryKind.expense ? _expenseType : null,
          );

      setState(() {
        _lastSaved = _SavedSummary(category: category.name, amount: amount);
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Yah, gagal kesimpen. Coba cek internet kamu ya 🔌';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                  error: (_, _) =>
                      const Center(child: Text('Gagal muat kategori. Coba lagi ya.')),
                ),
        ),
      ),
    );
  }

  Widget _buildForm(List<Category> categories) {
    final expenseCategories = categories.where((c) => c.kind == CategoryKind.expense).toList();
    final incomeCategories = categories.where((c) => c.kind == CategoryKind.income).toList();

    return Form(
      key: _formKey,
      child: ListView(
        children: [
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
          const SizedBox(height: 16),
          DropdownButtonFormField<Category>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
            items: [
              ...expenseCategories.map(
                (c) => DropdownMenuItem(value: c, child: Text(c.name)),
              ),
              ...incomeCategories.map(
                (c) => DropdownMenuItem(value: c, child: Text('${c.name} (Pemasukan)')),
              ),
            ],
            onChanged: _onCategoryChanged,
          ),
          if (_selectedCategory?.kind == CategoryKind.expense) ...[
            const SizedBox(height: 16),
            SegmentedButton<ExpenseType>(
              segments: const [
                ButtonSegment(value: ExpenseType.wajib, label: Text('Wajib')),
                ButtonSegment(value: ExpenseType.keinginan, label: Text('Keinginan')),
              ],
              selected: {_expenseType ?? ExpenseType.keinginan},
              onSelectionChanged: (selection) => setState(() => _expenseType = selection.first),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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

class _CatatSkeleton extends StatelessWidget {
  const _CatatSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SkeletonBox(height: 56),
        SizedBox(height: 16),
        SkeletonBox(height: 56),
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
          Text('Tercatat! ${saved.category} · Rp ${_formatAmount(saved.amount)}'),
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

String _formatAmount(num amount) {
  final digits = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

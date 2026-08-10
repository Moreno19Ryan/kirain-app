import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category.dart';
import '../data/category_repository.dart';
import '../data/category_style_options.dart';

/// Shared "Kategori Baru"/"Edit Kategori" dialog — used by
/// ManageCategoriesScreen and Catat's inline "+ Tambah kategori" shortcut
/// (CLAUDE.md 6.5: user harus bisa menambah kategori sendiri dari kedua
/// tempat itu), so both stay in sync with a single implementation.
///
/// Returns the newly created [Category] so a caller like Catat can select
/// it immediately; returns null if the dialog was cancelled, or when
/// editing an existing category (the caller doesn't need the updated row
/// back, just needs to know a save happened via [categoriesProvider] having
/// been invalidated, which this function always does on a successful save).
Future<Category?> showCategoryFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Category? existing,
}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final limitController = TextEditingController(
    text: existing?.budgetLimit == null ? '' : existing!.budgetLimit!.toStringAsFixed(0),
  );
  var kind = existing?.kind ?? CategoryKind.expense;
  var expenseType = existing?.expenseType ?? ExpenseType.keinginan;
  var alertThresholdPct = existing?.alertThresholdPct ?? 80;
  var icon = existing?.icon;
  var color = existing?.color;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Kategori Baru' : 'Edit Kategori'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nama kategori'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  if (existing == null) ...[
                    SegmentedButton<CategoryKind>(
                      segments: const [
                        ButtonSegment(value: CategoryKind.expense, label: Text('Pengeluaran')),
                        ButtonSegment(value: CategoryKind.income, label: Text('Pemasukan')),
                      ],
                      selected: {kind},
                      onSelectionChanged: (selection) =>
                          setDialogState(() => kind = selection.first),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (kind == CategoryKind.expense) ...[
                    SegmentedButton<ExpenseType>(
                      segments: const [
                        ButtonSegment(value: ExpenseType.wajib, label: Text('Wajib')),
                        ButtonSegment(value: ExpenseType.keinginan, label: Text('Keinginan')),
                      ],
                      selected: {expenseType},
                      onSelectionChanged: (selection) =>
                          setDialogState(() => expenseType = selection.first),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Limit per siklus (Rp, opsional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Alert Zona Waspada di $alertThresholdPct% dari limit'),
                    Slider(
                      value: alertThresholdPct.toDouble(),
                      min: 50,
                      max: 100,
                      divisions: 10,
                      label: '$alertThresholdPct%',
                      onChanged: (value) =>
                          setDialogState(() => alertThresholdPct = value.round()),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Icon (opsional)', style: Theme.of(dialogContext).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  _IconPicker(
                    selected: icon,
                    onSelected: (key) => setDialogState(() => icon = key),
                  ),
                  const SizedBox(height: 16),
                  Text('Warna (opsional)', style: Theme.of(dialogContext).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  _ColorPicker(
                    selected: color,
                    onSelected: (key) => setDialogState(() => color = key),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      );
    },
  );

  if (saved != true) return null;

  final name = nameController.text.trim();
  if (name.isEmpty) return null;

  final limit = num.tryParse(limitController.text.trim());
  final repository = ref.read(categoryRepositoryProvider);

  Category? created;
  if (existing == null) {
    created = await repository.createCategory(
      name: name,
      kind: kind,
      expenseType: kind == CategoryKind.expense ? expenseType : null,
      budgetLimit: kind == CategoryKind.expense ? limit : null,
      alertThresholdPct: alertThresholdPct,
      icon: icon,
      color: color,
    );
  } else {
    await repository.updateCategory(
      categoryId: existing.id,
      name: name,
      expenseType: existing.kind == CategoryKind.expense ? expenseType : null,
      budgetLimit: existing.kind == CategoryKind.expense ? limit : null,
      alertThresholdPct: alertThresholdPct,
      icon: icon,
      color: color,
    );
  }

  ref.invalidate(categoriesProvider);
  return created;
}

/// Grid of curated icon choices (see category_style_options.dart) plus a
/// leading "Bawaan" option that clears back to null — i.e. the category
/// falls back to [categoryIcon]'s existing name/kind-based default.
class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Tooltip(
          message: 'Pakai bawaan',
          child: _OptionCircle(
            selected: selected == null,
            onTap: () => onSelected(null),
            child: Icon(Icons.auto_awesome_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        for (final option in kCategoryIconOptions)
          Tooltip(
            message: option.label,
            child: _OptionCircle(
              selected: selected == option.key,
              onTap: () => onSelected(option.key),
              child: Icon(option.icon, size: 18, color: theme.colorScheme.onSurface),
            ),
          ),
      ],
    );
  }
}

/// Row of preset color swatches (see category_style_options.dart) plus a
/// leading "Bawaan" option that clears back to null — i.e. the category
/// falls back to the Wajib/Keinginan/Pemasukan group's default mint/coral/
/// neutral tone.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        Tooltip(
          message: 'Pakai bawaan',
          child: _OptionCircle(
            selected: selected == null,
            onTap: () => onSelected(null),
            border: Border.all(color: theme.colorScheme.outline, width: 1.5),
            child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        for (final option in kCategoryColorOptions)
          Tooltip(
            message: option.label,
            child: _OptionCircle(
              selected: selected == option.key,
              onTap: () => onSelected(option.key),
              fillColor: option.fill,
            ),
          ),
      ],
    );
  }
}

/// Shared 40x40 selectable circle for both pickers — [selected] draws a
/// highlighted ring so the current pick is obvious without extra text.
class _OptionCircle extends StatelessWidget {
  const _OptionCircle({required this.selected, required this.onTap, this.child, this.fillColor, this.border});

  final bool selected;
  final VoidCallback onTap;
  final Widget? child;
  final Color? fillColor;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fillColor ?? theme.colorScheme.surfaceContainerHighest,
          border: border ?? Border.all(color: theme.colorScheme.outline, width: 1),
        ),
        foregroundDecoration: selected
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary, width: 2.5),
              )
            : null,
        child: child,
      ),
    );
  }
}

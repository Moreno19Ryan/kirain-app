import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/format.dart';
import '../../categories/data/category.dart';
import '../../transactions/data/transaction_repository.dart';

const _csvHeader = 'Tanggal,Kategori/Target,Jenis,Jumlah,Catatan';

String buildTransactionsCsv(List<TransactionHistoryItem> items) {
  final buffer = StringBuffer(_csvHeader);

  for (final item in items) {
    final jenis = item.isSavingsContribution
        ? 'Tabungan'
        : switch (item.expenseType) {
            ExpenseType.wajib => 'Wajib',
            ExpenseType.keinginan => 'Keinginan',
            null => '-',
          };

    buffer
      ..write('\r\n')
      ..write(
        [
          isoDate(item.transactionDate),
          item.displayName,
          jenis,
          item.amount.toStringAsFixed(0),
          item.note ?? '',
        ].map(_csvField).join(','),
      );
  }

  return buffer.toString();
}

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Writes the CSV to a temp file and opens the OS share sheet. The file
/// lives in the temp dir, not app storage — it's a one-off export artifact,
/// not something KIRAIN needs to keep track of afterwards.
Future<void> shareTransactionsCsv(List<TransactionHistoryItem> items) async {
  final csv = buildTransactionsCsv(items);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/kirain-rekap-${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csv);

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: 'Rekap transaksi KIRAIN'),
  );
}

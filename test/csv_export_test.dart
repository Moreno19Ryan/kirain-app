import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/features/categories/data/category.dart';
import 'package:kirain/features/rekap/data/csv_export.dart';
import 'package:kirain/features/transactions/data/transaction_repository.dart';

void main() {
  group('buildTransactionsCsv', () {
    test('writes a header row plus one row per transaction', () {
      final items = [
        TransactionHistoryItem(
          id: 't1',
          amount: 15000,
          categoryId: 'c1',
          categoryName: 'Makan & Minum',
          transactionDate: DateTime(2026, 8, 5),
          note: 'Nasi goreng',
          expenseType: ExpenseType.wajib,
        ),
        TransactionHistoryItem(
          id: 't2',
          amount: 50000,
          goalId: 'g1',
          goalName: 'Dana Darurat',
          transactionDate: DateTime(2026, 8, 4),
        ),
      ];

      final csv = buildTransactionsCsv(items);
      final lines = csv.split('\r\n');

      expect(lines[0], 'Tanggal,Kategori/Target,Jenis,Jumlah,Catatan');
      expect(lines[1], '2026-08-05,Makan & Minum,Wajib,15000,Nasi goreng');
      expect(lines[2], '2026-08-04,Dana Darurat,Tabungan,50000,');
    });

    test('quotes fields that contain a comma', () {
      final items = [
        TransactionHistoryItem(
          id: 't1',
          amount: 20000,
          categoryId: 'c1',
          categoryName: 'Jajan & Nongkrong',
          transactionDate: DateTime(2026, 8, 5),
          note: 'Kopi, roti',
          expenseType: ExpenseType.keinginan,
        ),
      ];

      final csv = buildTransactionsCsv(items);

      expect(csv, contains('"Kopi, roti"'));
    });

    test('returns just the header when there are no transactions', () {
      expect(buildTransactionsCsv([]), 'Tanggal,Kategori/Target,Jenis,Jumlah,Catatan');
    });
  });
}

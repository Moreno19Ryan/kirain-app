import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/features/budget/data/budget_cycle.dart';

void main() {
  group('BudgetCycle.current', () {
    test('starts on the custom cycle day within the current month', () {
      final cycle = BudgetCycle.current(DateTime(2026, 8, 15), 10);
      expect(cycle.start, DateTime(2026, 8, 10));
      expect(cycle.end, DateTime(2026, 9, 10));
    });

    test('falls back to the previous month if the cycle day hasn\'t hit yet', () {
      final cycle = BudgetCycle.current(DateTime(2026, 8, 5), 10);
      expect(cycle.start, DateTime(2026, 7, 10));
      expect(cycle.end, DateTime(2026, 8, 10));
    });

    test('clamps to the last day of a shorter month', () {
      // Cycle day 31 clamps to Feb 28 in February; Feb 20 hasn't reached
      // that yet, so it's still in the cycle that started Jan 31.
      final cycle = BudgetCycle.current(DateTime(2026, 2, 20), 31);
      expect(cycle.start, DateTime(2026, 1, 31));
      expect(cycle.end, DateTime(2026, 2, 28));
    });
  });

  group('BudgetCycle.previous', () {
    test('is the cycle immediately before, ending where this one starts', () {
      final current = BudgetCycle.current(DateTime(2026, 8, 15), 10);
      final previous = current.previous(10);

      expect(previous.start, DateTime(2026, 7, 10));
      expect(previous.end, current.start);
    });

    test('clamps correctly across a shorter previous month', () {
      final current = BudgetCycle.current(DateTime(2026, 3, 31), 31);
      final previous = current.previous(31);

      expect(previous.start, DateTime(2026, 2, 28));
      expect(previous.end, current.start);
    });
  });
}

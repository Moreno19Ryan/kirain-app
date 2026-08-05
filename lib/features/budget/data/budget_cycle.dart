/// A budget cycle's date range, computed from the user's custom cycle start
/// day (e.g. gajian tanggal 25, not necessarily the 1st).
class BudgetCycle {
  const BudgetCycle({required this.start, required this.end});

  /// Inclusive.
  final DateTime start;

  /// Exclusive (start of the next cycle).
  final DateTime end;

  static BudgetCycle current(DateTime now, int cycleStartDay) {
    var start = _clampedStart(now, cycleStartDay);
    if (start.isAfter(now)) {
      final previousMonth = DateTime(now.year, now.month - 1, 1);
      start = _clampedStart(previousMonth, cycleStartDay);
    }

    final nextMonth = DateTime(start.year, start.month + 1, 1);
    final end = _clampedStart(nextMonth, cycleStartDay);

    return BudgetCycle(start: start, end: end);
  }

  /// The cycle immediately before this one — used for rollover calculations.
  BudgetCycle previous(int cycleStartDay) {
    final previousMonth = DateTime(start.year, start.month - 1, 1);
    return BudgetCycle(start: _clampedStart(previousMonth, cycleStartDay), end: start);
  }

  static DateTime _clampedStart(DateTime monthDate, int cycleStartDay) {
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final day = cycleStartDay > lastDayOfMonth ? lastDayOfMonth : cycleStartDay;
    return DateTime(monthDate.year, monthDate.month, day);
  }
}

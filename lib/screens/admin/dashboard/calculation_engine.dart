class DurationParts {
  final int years;
  final int months;
  final int days;

  const DurationParts({
    required this.years,
    required this.months,
    required this.days,
  });
}

class EngineCalculationResult {
  final double principal;
  final double interest;
  final double total;

  final int years;
  final int months;
  final int days;

  final double yearlyInterest;
  final double monthlyInterest;
  final double dailyInterest;

  final bool isCompound;
  final double rate;

  final DateTime startDate;
  final DateTime closingDate;

  const EngineCalculationResult({
    required this.principal,
    required this.interest,
    required this.total,
    required this.years,
    required this.months,
    required this.days,
    required this.yearlyInterest,
    required this.monthlyInterest,
    required this.dailyInterest,
    required this.isCompound,
    required this.rate,
    required this.startDate,
    required this.closingDate,
  });

  String get durationText {
    return '${years}Y-${months}M-${days}D';
  }
}

class CalculationEngine {
  CalculationEngine._();

  static EngineCalculationResult calculate({
    required double amount,
    required double rate,
    required DateTime startDate,
    required DateTime closingDate,
    bool isCompound = true,
  }) {
    if (amount < 0) {
      throw ArgumentError(
        'Amount cannot be negative.',
      );
    }

    if (rate < 0) {
      throw ArgumentError(
        'Rate cannot be negative.',
      );
    }

    if (closingDate.isBefore(startDate)) {
      throw ArgumentError(
        'Closing date cannot be before start date.',
      );
    }

    final duration = _getDuration(
      startDate,
      closingDate,
    );

    final monthlyRate = rate / 100;

    double yearlyInterest = 0;
    double monthlyInterest = 0;
    double dailyInterest = 0;
    double interest = 0;
    double total = amount;

    if (!isCompound) {
      // SIMPLE INTEREST
      yearlyInterest =
          amount *
              monthlyRate *
              (duration.years * 12);

      monthlyInterest =
          amount *
              monthlyRate *
              duration.months;

      dailyInterest =
          amount *
              monthlyRate *
              (duration.days / 30);

      interest =
          yearlyInterest +
              monthlyInterest +
              dailyInterest;

      total = amount + interest;
    } else {
      // COMPOUND INTEREST
      //
      // Rule:
      // Compound only after COMPLETE years.
      // Remaining months and days do NOT compound separately.
      // Both remaining months and remaining days use the
      // amount after the last completed year's compounding.

      double currentAmount = amount;

      // Complete years
      for (int i = 0; i < duration.years; i++) {
        final yearInterest =
            currentAmount *
                (monthlyRate * 12);

        yearlyInterest += yearInterest;

        currentAmount += yearInterest;
      }

      // IMPORTANT:
      // Remaining months and days are both calculated
      // on the SAME currentAmount.
      //
      // Example:
      // ₹40,000
      // 2 complete years -> ₹67,600
      // Remaining 1 month + 12 days:
      // both are calculated on ₹67,600.
      monthlyInterest =
          currentAmount *
              monthlyRate *
              duration.months;

      dailyInterest =
          currentAmount *
              monthlyRate *
              (duration.days / 30);

      interest =
          yearlyInterest +
              monthlyInterest +
              dailyInterest;

      total = amount + interest;
    }

    return EngineCalculationResult(
      principal: amount,
      interest: interest,
      total: total,
      years: duration.years,
      months: duration.months,
      days: duration.days,
      yearlyInterest: yearlyInterest,
      monthlyInterest: monthlyInterest,
      dailyInterest: dailyInterest,
      isCompound: isCompound,
      rate: rate,
      startDate: startDate,
      closingDate: closingDate,
    );
  }

  static DurationParts _getDuration(
      DateTime start,
      DateTime end,
      ) {
    int years = end.year - start.year;

    DateTime cursor = _addYears(
      start,
      years,
    );

    if (cursor.isAfter(end)) {
      years--;
      cursor = _addYears(
        start,
        years,
      );
    }

    int months = 0;

    while (true) {
      final next =
      _addMonths(cursor, 1);

      if (next.isAfter(end)) {
        break;
      }

      cursor = next;
      months++;
    }

    final days =
        end.difference(cursor).inDays;

    return DurationParts(
      years: years,
      months: months,
      days: days,
    );
  }

  static DateTime _addYears(
      DateTime date,
      int years,
      ) {
    final targetYear =
        date.year + years;

    final lastDay =
        DateTime(
          targetYear,
          date.month + 1,
          0,
        ).day;

    final day =
    date.day > lastDay
        ? lastDay
        : date.day;

    return DateTime(
      targetYear,
      date.month,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  static DateTime _addMonths(
      DateTime date,
      int months,
      ) {
    final totalMonths =
        date.year * 12 +
            (date.month - 1) +
            months;

    final targetYear =
        totalMonths ~/ 12;

    final targetMonth =
        (totalMonths % 12) + 1;

    final lastDay =
        DateTime(
          targetYear,
          targetMonth + 1,
          0,
        ).day;

    final day =
    date.day > lastDay
        ? lastDay
        : date.day;

    return DateTime(
      targetYear,
      targetMonth,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
}
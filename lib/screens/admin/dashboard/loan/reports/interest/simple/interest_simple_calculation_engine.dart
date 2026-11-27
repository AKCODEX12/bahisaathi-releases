
import 'dart:math';


/// One deposit belonging to a loan.
class InterestSimpleDeposit {
  final String id;
  final double amount;
  final DateTime depositDate;
  final String description;

  const InterestSimpleDeposit({
    required this.id,
    required this.amount,
    required this.depositDate,
    this.description = '',
  });
}

/// One loan's input data.
class InterestSimpleLoanInput {
  final String loanId;
  final String loanName;

  final double principal;
  final double monthlyRate;

  final DateTime openingDate;

  final List<InterestSimpleDeposit> deposits;

  const InterestSimpleLoanInput({
    required this.loanId,
    required this.loanName,
    required this.principal,
    required this.monthlyRate,
    required this.openingDate,
    required this.deposits,
  });
}

/// Duration between opening date and report date.
class InterestSimpleDuration {
  final int years;
  final int months;
  final int days;

  const InterestSimpleDuration({
    required this.years,
    required this.months,
    required this.days,
  });

  @override
  String toString() => '$years Years, $months Months, $days Days';
}

/// Result for one loan.
class InterestSimpleLoanResult {
  final String loanId;
  final String loanName;

  final double principal;
  final double monthlyRate;

  final DateTime openingDate;
  final DateTime tillDate;

  final InterestSimpleDuration duration;

  final double interest;
  final double total;

  final List<InterestSimpleDeposit> deposits;

  const InterestSimpleLoanResult({
    required this.loanId,
    required this.loanName,
    required this.principal,
    required this.monthlyRate,
    required this.openingDate,
    required this.tillDate,
    required this.duration,
    required this.interest,
    required this.total,
    required this.deposits,
  });

  double get totalDeposit {
    return deposits.fold(
      0.0,
          (sum, deposit) => sum + deposit.amount,
    );
  }
}

/// Complete report result for all selected loans.
class InterestSimpleCalculationResult {
  final DateTime reportDate;

  final List<InterestSimpleLoanResult> loans;

  const InterestSimpleCalculationResult({
    required this.reportDate,
    required this.loans,
  });

  double get totalPrincipal {
    return loans.fold(
      0.0,
          (sum, loan) => sum + loan.principal,
    );
  }

  double get totalInterest {
    return loans.fold(
      0.0,
          (sum, loan) => sum + loan.interest,
    );
  }

  double get totalPrincipalSide {
    return totalPrincipal + totalInterest;
  }

  double get totalDeposit {
    return loans.fold(
      0.0,
          (sum, loan) => sum + loan.totalDeposit,
    );
  }

  double get finalDue {
    return totalPrincipalSide - totalDeposit;
  }
}

class InterestSimpleCalculationEngine {
  InterestSimpleCalculationEngine._();

  /// Calculates Simple Interest for all selected loans.
  ///
  /// Important:
  /// - Interest is calculated on each loan's original principal.
  /// - Opening Date to Till Date is used.
  /// - Deposits do NOT reduce principal for interest calculation.
  /// - All deposits are subtracted together at the end.
  static InterestSimpleCalculationResult calculate({
    required List<InterestSimpleLoanInput> loans,
    required DateTime tillDate,
  }) {
    final reportDate = _dateOnly(tillDate);

    final loanResults = <InterestSimpleLoanResult>[];

    for (final loan in loans) {
      _validateLoan(loan, reportDate);

      final openingDate = _dateOnly(loan.openingDate);

      // A loan opened after the report date is not included.
      if (openingDate.isAfter(reportDate)) {
        continue;
      }

      // Only deposits dated on or before the report date
      // are included in the final deposit total.
      final validDeposits = loan.deposits.where((deposit) {
        return !_dateOnly(deposit.depositDate).isAfter(reportDate);
      }).toList();

      final duration = _getDuration(
        openingDate,
        reportDate,
      );

      // Interest is always calculated on original principal.
      final interest = _calculateInterest(
        principal: loan.principal,
        monthlyRate: loan.monthlyRate,
        duration: duration,
      );

      final total = loan.principal + interest;

      loanResults.add(
        InterestSimpleLoanResult(
          loanId: loan.loanId,
          loanName: loan.loanName,
          principal: loan.principal,
          monthlyRate: loan.monthlyRate,
          openingDate: openingDate,
          tillDate: reportDate,
          duration: duration,
          interest: interest,
          total: total,
          deposits: List.unmodifiable(validDeposits),
        ),
      );
    }

    return InterestSimpleCalculationResult(
      reportDate: reportDate,
      loans: List.unmodifiable(loanResults),
    );
  }

  /// Simple Interest formula:
  ///
  /// Interest = Principal * (Monthly Rate / 100) * Months
  ///
  /// Days are calculated using a 30-day month.
  static double _calculateInterest({
    required double principal,
    required double monthlyRate,
    required InterestSimpleDuration duration,
  }) {
    if (principal == 0 || monthlyRate == 0) {
      return 0;
    }

    final totalMonths =
        duration.years * 12 +
            duration.months +
            duration.days / 30;

    return principal *
        (monthlyRate / 100) *
        totalMonths;
  }

  static void _validateLoan(
      InterestSimpleLoanInput loan,
      DateTime reportDate,
      ) {
    if (!loan.principal.isFinite || loan.principal < 0) {
      throw ArgumentError(
        'Invalid principal for loan ${loan.loanId}.',
      );
    }

    if (!loan.monthlyRate.isFinite || loan.monthlyRate < 0) {
      throw ArgumentError(
        'Invalid monthly rate for loan ${loan.loanId}.',
      );
    }

    for (final deposit in loan.deposits) {
      if (!deposit.amount.isFinite || deposit.amount < 0) {
        throw ArgumentError(
          'Invalid deposit amount in loan ${loan.loanId}.',
        );
      }
    }
  }

  /// Calculates calendar years, months and remaining days.
  static InterestSimpleDuration _getDuration(
      DateTime start,
      DateTime end,
      ) {
    final from = _dateOnly(start);
    final to = _dateOnly(end);

    if (to.isBefore(from)) {
      throw ArgumentError(
        'Report date cannot be before loan opening date.',
      );
    }

    int years = to.year - from.year;

    DateTime cursor = _addYears(from, years);

    if (cursor.isAfter(to)) {
      years--;
      cursor = _addYears(from, years);
    }

    int months =
        (to.year - cursor.year) * 12 +
            (to.month - cursor.month);

    cursor = _addMonths(cursor, months);

    if (cursor.isAfter(to)) {
      months--;
      cursor = _addMonths(
        _addYears(from, years),
        months,
      );
    }

    final days = to.difference(cursor).inDays;

    return InterestSimpleDuration(
      years: years,
      months: months,
      days: days,
    );
  }

  static DateTime _addYears(DateTime date, int years) {
    final targetYear = date.year + years;

    final lastDay = DateTime(
      targetYear,
      date.month + 1,
      0,
    ).day;

    return DateTime(
      targetYear,
      date.month,
      min(date.day, lastDay),
    );
  }

  static DateTime _addMonths(DateTime date, int months) {
    final totalMonths =
        date.year * 12 + date.month - 1 + months;

    final targetYear = totalMonths ~/ 12;
    final targetMonth = totalMonths % 12 + 1;

    final lastDay = DateTime(
      targetYear,
      targetMonth + 1,
      0,
    ).day;

    return DateTime(
      targetYear,
      targetMonth,
      min(date.day, lastDay),
    );
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }
}

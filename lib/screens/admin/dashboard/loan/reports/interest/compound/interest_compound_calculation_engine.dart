
import 'dart:math';
import 'interest_compound_calculation_engine.dart';


/// Deposit entry used by Interest Compound Engine.
class InterestCompoundDeposit {
  final String id;
  final double amount;
  final DateTime depositDate;
  final String description;

  const InterestCompoundDeposit({
    required this.id,
    required this.amount,
    required this.depositDate,
    this.description = '',
  });
}

/// Duration between two dates.
class InterestCompoundDuration {
  final int years;
  final int months;
  final int days;

  const InterestCompoundDuration({
    required this.years,
    required this.months,
    required this.days,
  });

  @override
  String toString() => '$years Years, $months Months, $days Days';
}

/// Result of one calculation cycle.
class InterestCompoundCycle {
  final int cycleNumber;

  final DateTime adjustmentDate;
  final DateTime closingDate;

  final double openingPrincipal;
  final double monthlyRate;

  final InterestCompoundDuration duration;

  /// True means compound interest was applied.
  /// False means simple interest was applied.
  final bool isCompound;

  final double interest;
  final double totalBeforeDeposit;

  final double depositAmount;
  final double remainingPrincipal;

  final String? depositId;
  final String description;

  const InterestCompoundCycle({
    required this.cycleNumber,
    required this.adjustmentDate,
    required this.closingDate,
    required this.openingPrincipal,
    required this.monthlyRate,
    required this.duration,
    required this.isCompound,
    required this.interest,
    required this.totalBeforeDeposit,
    required this.depositAmount,
    required this.remainingPrincipal,
    this.depositId,
    this.description = '',
  });

  bool get isFinalCycle => depositId == null;

  String get interestType => isCompound ? 'Compound' : 'Simple';
}

/// Complete calculation result.
class InterestCompoundResult {
  final double openingAmount;
  final double monthlyRate;

  final DateTime openingDate;
  final DateTime tillDate;

  final List<InterestCompoundCycle> cycles;

  const InterestCompoundResult({
    required this.openingAmount,
    required this.monthlyRate,
    required this.openingDate,
    required this.tillDate,
    required this.cycles,
  });

  double get totalDeposit {
    return cycles
        .where((cycle) => !cycle.isFinalCycle)
        .fold(0.0, (sum, cycle) => sum + cycle.depositAmount);
  }

  double get totalInterest {
    return cycles.fold(
      0.0,
          (sum, cycle) => sum + cycle.interest,
    );
  }

  double get finalDue {
    return cycles.isEmpty
        ? openingAmount
        : cycles.last.totalBeforeDeposit;
  }

  double get finalPrincipal {
    return cycles.isEmpty
        ? openingAmount
        : cycles.last.remainingPrincipal;
  }
}

class InterestCompoundCalculationEngine {
  InterestCompoundCalculationEngine._();

  /// Main calculation method.
  static InterestCompoundResult calculate({
    required double amount,
    required double monthlyRate,
    required DateTime openingDate,
    required DateTime tillDate,
    required List<InterestCompoundDeposit> deposits,
  }) {
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError('Opening amount must be non-negative.');
    }

    if (!monthlyRate.isFinite || monthlyRate < 0) {
      throw ArgumentError('Monthly rate must be non-negative.');
    }

    final startDate = _dateOnly(openingDate);
    final endDate = _dateOnly(tillDate);

    if (endDate.isBefore(startDate)) {
      throw ArgumentError(
        'Till Date cannot be before Opening Date.',
      );
    }

    // Keep only deposits within the report period.
    final validDeposits = <InterestCompoundDeposit>[];

    for (final deposit in deposits) {
      if (!deposit.amount.isFinite || deposit.amount < 0) {
        throw ArgumentError(
          'Deposit amount must be non-negative.',
        );
      }

      final date = _dateOnly(deposit.depositDate);

      if (date.isBefore(startDate)) {
        throw ArgumentError(
          'Deposit date cannot be before Opening Date.',
        );
      }

      if (!date.isAfter(endDate)) {
        validDeposits.add(deposit);
      }
    }

    // Sort by actual deposit date.
    validDeposits.sort((a, b) {
      final result = _dateOnly(a.depositDate)
          .compareTo(_dateOnly(b.depositDate));

      if (result != 0) return result;

      return a.id.compareTo(b.id);
    });

    double principal = amount;
    DateTime adjustmentDate = startDate;

    final cycles = <InterestCompoundCycle>[];

    for (int i = 0; i < validDeposits.length; i++) {
      final deposit = validDeposits[i];
      final depositDate = _dateOnly(deposit.depositDate);

      final duration = _getDuration(
        adjustmentDate,
        depositDate,
      );

      // Less than one complete year = Simple.
      // One complete year or more = Compound.
      final bool useCompound = duration.years >= 1;

      final interest = _calculateCycleInterest(
        principal: principal,
        monthlyRate: monthlyRate,
        duration: duration,
        isCompound: useCompound,
      );

      final total = principal + interest;

      if (deposit.amount > total) {
        throw ArgumentError(
          'Deposit ${deposit.id} amount is greater than '
              'the available balance in cycle ${i + 1}.',
        );
      }

      final remaining = total - deposit.amount;

      cycles.add(
        InterestCompoundCycle(
          cycleNumber: i + 1,
          adjustmentDate: adjustmentDate,
          closingDate: depositDate,
          openingPrincipal: principal,
          monthlyRate: monthlyRate,
          duration: duration,
          isCompound: useCompound,
          interest: interest,
          totalBeforeDeposit: total,
          depositAmount: deposit.amount,
          remainingPrincipal: remaining,
          depositId: deposit.id,
          description: deposit.description,
        ),
      );

      // Actual deposit date becomes next adjustment date.
      principal = remaining;
      adjustmentDate = depositDate;
    }

    // Final cycle: last adjustment date to Till Date.
    final finalDuration = _getDuration(
      adjustmentDate,
      endDate,
    );

    final finalCompound = finalDuration.years >= 1;

    final finalInterest = _calculateCycleInterest(
      principal: principal,
      monthlyRate: monthlyRate,
      duration: finalDuration,
      isCompound: finalCompound,
    );

    final finalTotal = principal + finalInterest;

    cycles.add(
      InterestCompoundCycle(
        cycleNumber: cycles.length + 1,
        adjustmentDate: adjustmentDate,
        closingDate: endDate,
        openingPrincipal: principal,
        monthlyRate: monthlyRate,
        duration: finalDuration,
        isCompound: finalCompound,
        interest: finalInterest,
        totalBeforeDeposit: finalTotal,
        depositAmount: 0,
        remainingPrincipal: finalTotal,
      ),
    );

    return InterestCompoundResult(
      openingAmount: amount,
      monthlyRate: monthlyRate,
      openingDate: startDate,
      tillDate: endDate,
      cycles: List.unmodifiable(cycles),
    );
  }

  /// Calculate interest for one cycle.
  ///
  /// Simple:
  /// Principal * Monthly Rate * Duration in months.
  ///
  /// Compound:
  /// Complete years are compounded at monthlyRate * 12.
  /// Remaining months and days use simple interest.
  static double _calculateCycleInterest({
    required double principal,
    required double monthlyRate,
    required InterestCompoundDuration duration,
    required bool isCompound,
  }) {
    if (principal == 0 || monthlyRate == 0) return 0;

    final monthlyRateDecimal = monthlyRate / 100;

    if (!isCompound) {
      final months =
          duration.years * 12 +
              duration.months +
              duration.days / 30;

      return principal * monthlyRateDecimal * months;
    }

    final yearlyRate = monthlyRateDecimal * 12;

    double compoundedAmount = principal;

    // Compound for completed years only.
    for (int i = 0; i < duration.years; i++) {
      compoundedAmount *= (1 + yearlyRate);
    }

    // Remaining months and days: simple interest.
    final remainingMonths =
        duration.months + duration.days / 30;

    final remainingInterest =
        compoundedAmount *
            monthlyRateDecimal *
            remainingMonths;

    return (compoundedAmount - principal) + remainingInterest;
  }

  /// Calculate years, months and days.
  static InterestCompoundDuration _getDuration(
      DateTime start,
      DateTime end,
      ) {
    final from = _dateOnly(start);
    final to = _dateOnly(end);

    if (to.isBefore(from)) {
      throw ArgumentError('End date cannot be before start date.');
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

    return InterestCompoundDuration(
      years: years,
      months: months,
      days: days,
    );
  }

  static DateTime _addYears(DateTime date, int years) {
    final year = date.year + years;
    final lastDay = DateTime(year, date.month + 1, 0).day;

    return DateTime(
      year,
      date.month,
      min(date.day, lastDay),
    );
  }

  static DateTime _addMonths(DateTime date, int months) {
    final totalMonths =
        date.year * 12 + date.month - 1 + months;

    final year = totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;

    final lastDay = DateTime(year, month + 1, 0).day;

    return DateTime(
      year,
      month,
      min(date.day, lastDay),
    );
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

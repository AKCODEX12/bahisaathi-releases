
import 'package:cloud_firestore/cloud_firestore.dart';

import 'compound/interest_compound_calculation_engine.dart';
import 'simple/interest_simple_calculation_engine.dart';

/// Report mein deposit ki basic information.
class InterestReportDepositEntry {
  final String depositId;
  final double amount;
  final DateTime depositDate;
  final String description;

  const InterestReportDepositEntry({
    required this.depositId,
    required this.amount,
    required this.depositDate,
    this.description = '',
  });
}

/// Ek loan ka complete Interest Report Result.
class InterestReportLoanEntry {
  final String loanId;
  final String loanName;
  final double principal;
  final double monthlyRate;
  final DateTime openingDate;

  /// Simple Interest calculation ke liye.
  final InterestSimpleLoanResult? simpleCalculation;

  /// Compound Interest calculation ke liye.
  final InterestCompoundResult? compoundCalculation;

  final List<InterestReportDepositEntry> deposits;

  const InterestReportLoanEntry({
    required this.loanId,
    required this.loanName,
    required this.principal,
    required this.monthlyRate,
    required this.openingDate,
    this.simpleCalculation,
    this.compoundCalculation,
    required this.deposits,
  });

  double get totalDeposit {
    return deposits.fold(
      0.0,
          (sum, deposit) => sum + deposit.amount,
    );
  }

  double get totalInterest {
    if (simpleCalculation != null) {
      return simpleCalculation!.interest;
    }

    return compoundCalculation?.totalInterest ?? 0.0;
  }

  double get principalSideTotal {
    return principal + totalInterest;
  }

  double get finalDue {
    if (simpleCalculation != null) {
      return simpleCalculation!.total - totalDeposit;
    }

    return compoundCalculation?.finalDue ?? 0.0;
  }
}

/// Complete Interest Report Result.
class InterestReportCalculationResult {
  final String customerId;
  final String customerName;
  final String customerEmail;

  final DateTime reportDate;

  /// true = Compound, false = Simple.
  final bool isCompound;

  /// Agar override diya gaya hai to wahi value rahegi.
  /// Nahi diya gaya to null rahega.
  final double? overrideRatePM;

  final List<InterestReportLoanEntry> loans;

  const InterestReportCalculationResult({
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.reportDate,
    required this.isCompound,
    required this.overrideRatePM,
    required this.loans,
  });

  String get interestType {
    return isCompound ? 'compound' : 'simple';
  }

  double get totalPrincipal {
    return loans.fold(
      0.0,
          (sum, loan) => sum + loan.principal,
    );
  }

  double get totalInterest {
    return loans.fold(
      0.0,
          (sum, loan) => sum + loan.totalInterest,
    );
  }

  double get totalPrincipalSide {
    return loans.fold(
      0.0,
          (sum, loan) => sum + loan.principalSideTotal,
    );
  }

  double get totalDeposit {
    return loans.fold(
      0.0,
          (sum, loan) => sum + loan.totalDeposit,
    );
  }

  double get finalDue {
    return loans.fold(
      0.0,
          (sum, loan) => sum + loan.finalDue,
    );
  }
}

class InterestReportCalculationService {
  final FirebaseFirestore _firestore;

  InterestReportCalculationService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Selected loans ka Interest Report calculate karta hai.
  ///
  /// isCompound:
  /// true  = Compound Interest Engine
  /// false = Simple Interest Engine
  ///
  /// overrideRatePM:
  /// null = Har loan ka original ratePM
  /// value = Sabhi selected loans ke liye report-only override
  Future<InterestReportCalculationResult> calculateReport({
    required List<String> loanIds,
    required String customerId,
    required String customerName,
    required String customerEmail,
    required DateTime reportDate,
    required bool isCompound,
    double? overrideRatePM,
  }) async {
    if (loanIds.isEmpty) {
      throw StateError('Koi loan select nahi kiya gaya hai.');
    }

    if (overrideRatePM != null &&
        (!overrideRatePM.isFinite || overrideRatePM < 0)) {
      throw ArgumentError('Rate PM valid hona chahiye.');
    }

    final tillDate = DateTime(
      reportDate.year,
      reportDate.month,
      reportDate.day,
      23,
      59,
      59,
    );

    final List<InterestReportLoanEntry> loanEntries = [];

    // Simple engine ko sabhi selected loans ek saath chahiye.
    final List<InterestSimpleLoanInput> simpleLoanInputs = [];

    for (final loanId in loanIds) {
      final loanSnapshot =
      await _firestore.collection('loans').doc(loanId).get();

      if (!loanSnapshot.exists) {
        continue;
      }

      final loanData = loanSnapshot.data();

      if (loanData == null) {
        continue;
      }

      // Sirf active loans calculate honge.
      final status = (loanData['status'] ?? 'active')
          .toString()
          .toLowerCase();

      if (status != 'active') {
        continue;
      }

      // Customer ownership verify.
      final loanCustomerId =
      (loanData['customerId'] ?? '').toString();

      final loanCustomerEmail =
      (loanData['customerEmail'] ?? '').toString();

      final matchesCustomer =
          loanCustomerId == customerId ||
              (customerEmail.isNotEmpty &&
                  loanCustomerEmail == customerEmail);

      if (!matchesCustomer) {
        continue;
      }

      final principal = _toDouble(loanData['amount']);
      final originalRate = _toDouble(loanData['ratePM']);

      final monthlyRate = overrideRatePM ?? originalRate;

      final openingDate = _toDateTime(loanData['openingDate']);

      if (openingDate == null) {
        continue;
      }

      if (openingDate.isAfter(tillDate)) {
        continue;
      }

      final loanName =
      (loanData['loanName'] ??
          loanData['name'] ??
          'Loan')
          .toString();

      if (!principal.isFinite ||
          !monthlyRate.isFinite ||
          principal < 0 ||
          monthlyRate < 0) {
        throw StateError(
          'Loan $loanName mein principal ya rate valid nahi hai.',
        );
      }

      // Is loan ke deposits fetch karo.
      final depositSnapshot = await _firestore
          .collection('loans')
          .doc(loanId)
          .collection('deposits')
          .get();

      final List<InterestReportDepositEntry> deposits = [];

      for (final depositDoc in depositSnapshot.docs) {
        final depositData = depositDoc.data();

        final depositDate = _toDateTime(
          depositData['date'],
        );

        if (depositDate == null) {
          continue;
        }

        // Till Date ke baad ke deposits include nahi honge.
        if (depositDate.isAfter(tillDate)) {
          continue;
        }

        // Opening Date se pehle ke deposits include nahi honge.
        if (depositDate.isBefore(openingDate)) {
          continue;
        }

        final depositAmount = _toDouble(
          depositData['amount'],
        );

        if (!depositAmount.isFinite || depositAmount < 0) {
          throw StateError(
            'Loan $loanName mein deposit amount valid nahi hai.',
          );
        }

        deposits.add(
          InterestReportDepositEntry(
            depositId: depositDoc.id,
            amount: depositAmount,
            depositDate: depositDate,
            description:
            (depositData['description'] ?? '').toString(),
          ),
        );
      }

      deposits.sort(
            (a, b) => a.depositDate.compareTo(b.depositDate),
      );

      if (isCompound) {
        // COMPOUND ENGINE
        final compoundDeposits = deposits.map((deposit) {
          return InterestCompoundDeposit(
            id: deposit.depositId,
            amount: deposit.amount,
            depositDate: deposit.depositDate,
            description: deposit.description,
          );
        }).toList();

        final compoundResult =
        InterestCompoundCalculationEngine.calculate(
          amount: principal,
          monthlyRate: monthlyRate,
          openingDate: openingDate,
          tillDate: tillDate,
          deposits: compoundDeposits,
        );

        loanEntries.add(
          InterestReportLoanEntry(
            loanId: loanId,
            loanName: loanName,
            principal: principal,
            monthlyRate: monthlyRate,
            openingDate: openingDate,
            compoundCalculation: compoundResult,
            deposits: deposits,
          ),
        );
      } else {
        // SIMPLE ENGINE INPUT
        simpleLoanInputs.add(
          InterestSimpleLoanInput(
            loanId: loanId,
            loanName: loanName,
            principal: principal,
            monthlyRate: monthlyRate,
            openingDate: openingDate,
            deposits: deposits.map((deposit) {
              return InterestSimpleDeposit(
                id: deposit.depositId,
                amount: deposit.amount,
                depositDate: deposit.depositDate,
                description: deposit.description,
              );
            }).toList(),
          ),
        );
      }
    }

    if (isCompound) {
      return InterestReportCalculationResult(
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        reportDate: tillDate,
        isCompound: true,
        overrideRatePM: overrideRatePM,
        loans: loanEntries,
      );
    }

    // SIMPLE ENGINE: Sabhi loans ka combined calculation.
    final simpleResult =
    InterestSimpleCalculationEngine.calculate(
      loans: simpleLoanInputs,
      tillDate: tillDate,
    );

    // Simple engine ke individual results ko report entries mein
    // convert kar rahe hain.
    for (final simpleLoan in simpleResult.loans) {
      final originalInput = simpleLoanInputs.firstWhere(
            (input) => input.loanId == simpleLoan.loanId,
      );

      final deposits = originalInput.deposits.map((deposit) {
        return InterestReportDepositEntry(
          depositId: deposit.id,
          amount: deposit.amount,
          depositDate: deposit.depositDate,
          description: deposit.description,
        );
      }).toList();

      loanEntries.add(
        InterestReportLoanEntry(
          loanId: simpleLoan.loanId,
          loanName: simpleLoan.loanName,
          principal: simpleLoan.principal,
          monthlyRate: simpleLoan.monthlyRate,
          openingDate: simpleLoan.openingDate,
          simpleCalculation: simpleLoan,
          deposits: deposits,
        ),
      );
    }

    return InterestReportCalculationResult(
      customerId: customerId,
      customerName: customerName,
      customerEmail: customerEmail,
      reportDate: tillDate,
      isCompound: false,
      overrideRatePM: overrideRatePM,
      loans: loanEntries,
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim()) ?? 0.0;
    }

    return 0.0;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}

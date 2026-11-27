import 'package:cloud_firestore/cloud_firestore.dart';

import 'calculation_engine.dart';

class ReportPrincipalEntry {
  final String loanId;
  final String loanName;
  final double amount;
  final double rate;
  final DateTime openingDate;
  final EngineCalculationResult calculation;

  const ReportPrincipalEntry({
    required this.loanId,
    required this.loanName,
    required this.amount,
    required this.rate,
    required this.openingDate,
    required this.calculation,
  });
}

class ReportDepositEntry {
  final String loanId;
  final String loanName;
  final String depositId;
  final double amount;
  final double rate;
  final DateTime depositDate;
  final EngineCalculationResult calculation;

  const ReportDepositEntry({
    required this.loanId,
    required this.loanName,
    required this.depositId,
    required this.amount,
    required this.rate,
    required this.depositDate,
    required this.calculation,
  });
}

class LoanReportCalculationResult {
  // Customer ID is needed for History Reports filtering.
  final String customerId;

  final String customerName;
  final String customerEmail;

  final DateTime reportDate;

  final bool isCompound;
  final double? overrideRatePM;

  final List<ReportPrincipalEntry> principals;
  final List<ReportDepositEntry> deposits;

  const LoanReportCalculationResult({
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.reportDate,
    required this.isCompound,
    required this.overrideRatePM,
    required this.principals,
    required this.deposits,
  });

  double get totalPrincipal {
    return principals.fold(
      0,
          (sum, item) => sum + item.amount,
    );
  }

  double get totalPrincipalInterest {
    return principals.fold(
      0,
          (sum, item) => sum + item.calculation.interest,
    );
  }

  double get principalSideTotal {
    return totalPrincipal + totalPrincipalInterest;
  }

  double get totalDeposit {
    return deposits.fold(
      0,
          (sum, item) => sum + item.amount,
    );
  }

  double get totalDepositInterest {
    return deposits.fold(
      0,
          (sum, item) => sum + item.calculation.interest,
    );
  }

  double get depositSideTotal {
    return totalDeposit + totalDepositInterest;
  }

  double get finalDue {
    return principalSideTotal - depositSideTotal;
  }
}

class ReportCalculationService {
  final FirebaseFirestore firestore;

  ReportCalculationService({
    FirebaseFirestore? firestore,
  }) : firestore =
      firestore ?? FirebaseFirestore.instance;

  Future<LoanReportCalculationResult> calculateReport({
    required List<String> loanIds,

    // NEW
    required String customerId,

    required String customerName,
    required String customerEmail,
    required DateTime reportDate,
    required bool isCompound,
    double? overrideRatePM,
  }) async {
    if (loanIds.isEmpty) {
      throw Exception(
        'No loans selected.',
      );
    }

    final principals = <ReportPrincipalEntry>[];

    final deposits = <ReportDepositEntry>[];

    // Report date ko day ke end tak rakhenge.
    final calculationEndDate = DateTime(
      reportDate.year,
      reportDate.month,
      reportDate.day,
      23,
      59,
      59,
    );

    for (final loanId in loanIds) {
      final loanSnapshot = await firestore
          .collection('loans')
          .doc(loanId)
          .get();

      if (!loanSnapshot.exists) {
        continue;
      }

      final data = loanSnapshot.data();

      if (data == null) {
        continue;
      }

      // Sirf ACTIVE loan report me calculate hoga.
      final status = (data['status'] ?? 'active')
          .toString()
          .toLowerCase();

      if (status != 'active') {
        continue;
      }

      final loanName = (data['name'] ?? 'Loan').toString();

      final amount = _toDouble(
        data['amount'],
      );

      final originalRate = _toDouble(
        data['ratePM'],
      );

      // Agar report settings me Rate PM diya hai,
      // to wahi rate use hoga.
      // Original loan rate Firestore me change nahi hoga.
      final rate = overrideRatePM ?? originalRate;

      final openingDate = _toDateTime(
        data['openingDate'],
      );

      if (openingDate == null) {
        continue;
      }

      // Agar loan report date ke baad start hua hai
      // to uska calculation nahi karenge.
      if (openingDate.isAfter(
        calculationEndDate,
      )) {
        continue;
      }

      // ==============================
      // PRINCIPAL CALCULATION
      // ==============================

      final principalCalculation =
      CalculationEngine.calculate(
        amount: amount,
        rate: rate,
        startDate: openingDate,
        closingDate: calculationEndDate,
        isCompound: isCompound,
      );

      principals.add(
        ReportPrincipalEntry(
          loanId: loanId,
          loanName: loanName,
          amount: amount,
          rate: rate,
          openingDate: openingDate,
          calculation: principalCalculation,
        ),
      );

      // ==============================
      // DEPOSITS
      // ==============================

      final depositSnapshot = await firestore
          .collection('loans')
          .doc(loanId)
          .collection('deposits')
          .orderBy('date')
          .get();

      for (final depositDoc in depositSnapshot.docs) {
        final depositData = depositDoc.data();

        final depositAmount = _toDouble(
          depositData['amount'],
        );

        final depositDate = _toDateTime(
          depositData['date'],
        );

        if (depositDate == null) {
          continue;
        }

        // Future deposit ko report me include nahi karenge.
        if (depositDate.isAfter(
          calculationEndDate,
        )) {
          continue;
        }

        final depositCalculation =
        CalculationEngine.calculate(
          amount: depositAmount,
          rate: rate,
          startDate: depositDate,
          closingDate: calculationEndDate,
          isCompound: isCompound,
        );

        deposits.add(
          ReportDepositEntry(
            loanId: loanId,
            loanName: loanName,
            depositId: depositDoc.id,
            amount: depositAmount,
            rate: rate,
            depositDate: depositDate,
            calculation: depositCalculation,
          ),
        );
      }
    }

    return LoanReportCalculationResult(
      customerId: customerId,
      customerName: customerName,
      customerEmail: customerEmail,
      reportDate: reportDate,
      isCompound: isCompound,
      overrideRatePM: overrideRatePM,
      principals: principals,
      deposits: deposits,
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}
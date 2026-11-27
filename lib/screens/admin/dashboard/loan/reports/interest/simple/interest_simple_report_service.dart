
import 'package:cloud_firestore/cloud_firestore.dart';

import 'interest_simple_calculation_engine.dart';

/// Simple Interest report ke customer details aur calculation result.
class InterestSimpleReportResult {
  final String customerId;
  final String customerName;
  final String customerEmail;
  final DateTime reportDate;
  final double? overrideRatePM;
  final InterestSimpleCalculationResult calculation;

  const InterestSimpleReportResult({
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.reportDate,
    required this.overrideRatePM,
    required this.calculation,
  });

  double get totalPrincipal => calculation.totalPrincipal;

  double get totalInterest => calculation.totalInterest;

  double get totalPrincipalSide => calculation.totalPrincipalSide;

  double get totalDeposit => calculation.totalDeposit;

  double get finalDue => calculation.finalDue;
}

class InterestSimpleReportService {
  final FirebaseFirestore firestore;

  InterestSimpleReportService({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  Future<InterestSimpleReportResult> calculateReport({
    required List<String> loanIds,
    required String customerId,
    required String customerName,
    required String customerEmail,
    required DateTime reportDate,
    double? overrideRatePM,
  }) async {
    if (loanIds.isEmpty) {
      throw Exception('No loans selected.');
    }

    final loans = <InterestSimpleLoanInput>[];

    // Report date ke din ke end tak calculation hogi.
    final calculationEndDate = DateTime(
      reportDate.year,
      reportDate.month,
      reportDate.day,
      23,
      59,
      59,
      999,
    );

    for (final loanId in loanIds) {
      final loanSnapshot = await firestore
          .collection('loans')
          .doc(loanId)
          .get();

      if (!loanSnapshot.exists) continue;

      final data = loanSnapshot.data();

      if (data == null) continue;

      // Sirf ACTIVE loans include honge.
      final status = (data['status'] ?? 'active')
          .toString()
          .toLowerCase();

      if (status != 'active') continue;

      final loanName = (data['name'] ?? 'Loan').toString();

      final amount = _toDouble(data['amount']);

      final originalRate = _toDouble(data['ratePM']);

      // Override rate diya hai to wahi use hoga.
      // Nahi diya hai to loan ka original rate use hoga.
      final rate = overrideRatePM ?? originalRate;

      final openingDate = _toDateTime(data['openingDate']);

      if (openingDate == null) continue;

      // Report date ke baad open hua loan include nahi hoga.
      if (openingDate.isAfter(calculationEndDate)) {
        continue;
      }

      // Deposits sirf amount ke liye fetch honge.
      // Deposit par alag se interest calculate nahi hoga.
      final depositSnapshot = await firestore
          .collection('loans')
          .doc(loanId)
          .collection('deposits')
          .orderBy('date')
          .get();

      final deposits = <InterestSimpleDeposit>[];

      for (final depositDoc in depositSnapshot.docs) {
        final depositData = depositDoc.data();

        final depositAmount = _toDouble(
          depositData['amount'],
        );

        final depositDate = _toDateTime(
          depositData['date'],
        );

        if (depositDate == null) continue;

        // Report date ke baad ke deposits exclude honge.
        if (depositDate.isAfter(calculationEndDate)) {
          continue;
        }

        deposits.add(
          InterestSimpleDeposit(
            id: depositDoc.id,
            amount: depositAmount,
            depositDate: depositDate,
            description: '',
          ),
        );
      }

      loans.add(
        InterestSimpleLoanInput(
          loanId: loanId,
          loanName: loanName,
          principal: amount,
          monthlyRate: rate,
          openingDate: openingDate,
          deposits: deposits,
        ),
      );
    }

    final calculation = InterestSimpleCalculationEngine.calculate(
      loans: loans,
      tillDate: calculationEndDate,
    );

    return InterestSimpleReportResult(
      customerId: customerId,
      customerName: customerName,
      customerEmail: customerEmail,
      reportDate: reportDate,
      overrideRatePM: overrideRatePM,
      calculation: calculation,
    );
  }

  // Simple Interest report ko alag History collection mein save karta hai.
  Future<String> saveReportToHistory({
    required InterestSimpleReportResult result,
    required String adminUid,
    required List<String> selectedLoanIds,
  }) async {
    if (adminUid.trim().isEmpty) {
      throw ArgumentError('Admin UID is required.');
    }

    if (selectedLoanIds.isEmpty) {
      throw ArgumentError('Selected loan IDs cannot be empty.');
    }

    final loansData = result.calculation.loans.map((loan) {
      return {
        'loanId': loan.loanId,
        'loanName': loan.loanName,
        'principal': loan.principal,
        'monthlyRate': loan.monthlyRate,
        'openingDate': Timestamp.fromDate(loan.openingDate),
        'tillDate': Timestamp.fromDate(loan.tillDate),

        'duration': {
          'years': loan.duration.years,
          'months': loan.duration.months,
          'days': loan.duration.days,
        },

        'interest': loan.interest,
        'total': loan.total,
        'totalDeposit': loan.totalDeposit,

        'deposits': loan.deposits.map((deposit) {
          return {
            'depositId': deposit.id,
            'amount': deposit.amount,
            'depositDate': Timestamp.fromDate(
              deposit.depositDate,
            ),
            'description': deposit.description,
          };
        }).toList(),
      };
    }).toList();

    final reportData = <String, dynamic>{
      'adminUid': adminUid,
      'customerId': result.customerId,
      'customerName': result.customerName,
      'customerEmail': result.customerEmail,

      'depositType': 'interest',
      'interestType': 'simple',

      'reportDate': Timestamp.fromDate(result.reportDate),
      'generatedAt': FieldValue.serverTimestamp(),

      'overrideRatePM': result.overrideRatePM,

      'totalPrincipal': result.totalPrincipal,
      'totalInterest': result.totalInterest,
      'totalPrincipalSide': result.totalPrincipalSide,
      'totalDeposit': result.totalDeposit,
      'finalDue': result.finalDue,

      'selectedLoanIds': selectedLoanIds,
      'loans': loansData,
    };

    final doc = await firestore
        .collection('interest_simple_reports')
        .add(reportData);

    return doc.id;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }
}

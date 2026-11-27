
import 'package:cloud_firestore/cloud_firestore.dart';

import 'interest_compound_calculation_engine.dart';

/// Ek loan ka complete Compound Interest report data.
class InterestCompoundReportLoan {
  final String loanId;
  final String loanName;
  final double principal;
  final double monthlyRate;
  final DateTime openingDate;

  final InterestCompoundResult calculation;

  const InterestCompoundReportLoan({
    required this.loanId,
    required this.loanName,
    required this.principal,
    required this.monthlyRate,
    required this.openingDate,
    required this.calculation,
  });

  double get totalInterest => calculation.totalInterest;

  double get totalDeposit => calculation.totalDeposit;

  double get finalDue => calculation.finalDue;
}

/// Compound Interest ki complete customer report.
class InterestCompoundReportResult {
  final String customerId;
  final String customerName;
  final String customerEmail;
  final DateTime reportDate;
  final double? overrideRatePM;

  final List<InterestCompoundReportLoan> loans;

  const InterestCompoundReportResult({
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.reportDate,
    required this.overrideRatePM,
    required this.loans,
  });

  double get totalPrincipal {
    return loans.fold(0.0, (sum, loan) => sum + loan.principal);
  }

  double get totalInterest {
    return loans.fold(0.0, (sum, loan) => sum + loan.totalInterest);
  }

  double get totalPrincipalSide {
    return totalPrincipal + totalInterest;
  }

  double get totalDeposit {
    return loans.fold(0.0, (sum, loan) => sum + loan.totalDeposit);
  }

  double get finalDue {
    return loans.fold(0.0, (sum, loan) => sum + loan.finalDue);
  }
}

/// Firestore se Compound Interest report ka data fetch karke
/// Compound Calculation Engine ko provide karta hai.
class InterestCompoundReportService {
  final FirebaseFirestore _firestore;

  InterestCompoundReportService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<InterestCompoundReportResult> calculateReport({
    required List<String> loanIds,
    required String customerId,
    required String customerName,
    required String customerEmail,
    required DateTime reportDate,
    double? overrideRatePM,
  }) async {
    if (loanIds.isEmpty) {
      throw Exception('Report ke liye koi loan select nahi kiya gaya.');
    }

    if (overrideRatePM != null &&
        (!overrideRatePM.isFinite || overrideRatePM < 0)) {
      throw Exception('Rate PM valid hona chahiye.');
    }

    final tillDate = DateTime(
      reportDate.year,
      reportDate.month,
      reportDate.day,
      23,
      59,
      59,
    );

    final List<InterestCompoundReportLoan> reportLoans = [];

    for (final loanId in loanIds.toSet()) {
      final loanDoc = await _firestore
          .collection('loans')
          .doc(loanId)
          .get();

      if (!loanDoc.exists) continue;

      final loanData = loanDoc.data();
      if (loanData == null) continue;

      // Sirf active loans report mein include honge.
      final status = (loanData['status'] ?? 'active').toString();

      if (status != 'active') continue;

      // Customer ownership check.
      final loanCustomerId =
      (loanData['customerId'] ?? '').toString();

      final loanCustomerEmail =
      (loanData['customerEmail'] ?? '').toString();

      final belongsToCustomer =
          loanCustomerId == customerId ||
              loanCustomerEmail == customerEmail;

      if (!belongsToCustomer) continue;

      final principal = _toDouble(loanData['amount']);
      final originalRate = _toDouble(loanData['ratePM']);

      final openingDate = _toDateTime(loanData['openingDate']);

      if (openingDate == null) continue;

      // Report date se baad open hua loan include nahi hoga.
      if (_dateOnly(openingDate).isAfter(_dateOnly(tillDate))) {
        continue;
      }

      if (!principal.isFinite || principal < 0) {
        throw Exception('Loan $loanId ka principal amount valid nahi hai.');
      }

      if (!originalRate.isFinite || originalRate < 0) {
        throw Exception('Loan $loanId ka Rate PM valid nahi hai.');
      }

      // Override diya hai to sabhi selected loans mein wahi rate lagega.
      // Blank hone par original Firestore ratePM use hoga.
      final effectiveRate = overrideRatePM ?? originalRate;

      // Loan ke deposits fetch karna.
      final depositsSnapshot = await _firestore
          .collection('loans')
          .doc(loanId)
          .collection('deposits')
          .get();

      final List<InterestCompoundDeposit> deposits = [];

      for (final depositDoc in depositsSnapshot.docs) {
        final depositData = depositDoc.data();

        final depositAmount = _toDouble(depositData['amount']);
        final depositDate = _toDateTime(depositData['date']);

        if (depositDate == null) continue;

        // Till Date ke baad ke deposits report mein nahi aayenge.
        if (_dateOnly(depositDate).isAfter(_dateOnly(tillDate))) {
          continue;
        }

        if (!depositAmount.isFinite || depositAmount < 0) {
          throw Exception(
            'Deposit ${depositDoc.id} ka amount valid nahi hai.',
          );
        }

        deposits.add(
          InterestCompoundDeposit(
            id: depositDoc.id,
            amount: depositAmount,
            depositDate: depositDate,
            description:
            (depositData['description'] ?? '').toString(),
          ),
        );
      }

      // Compound Calculation Engine.
      final calculation = InterestCompoundCalculationEngine.calculate(
        amount: principal,
        monthlyRate: effectiveRate,
        openingDate: openingDate,
        tillDate: tillDate,
        deposits: deposits,
      );

      reportLoans.add(
        InterestCompoundReportLoan(
          loanId: loanId,
          loanName: _getLoanName(loanData, loanId),
          principal: principal,
          monthlyRate: effectiveRate,
          openingDate: openingDate,
          calculation: calculation,
        ),
      );
    }

    if (reportLoans.isEmpty) {
      throw Exception(
        'Selected customer ke liye koi eligible active loan nahi mila.',
      );
    }

    return InterestCompoundReportResult(
      customerId: customerId,
      customerName: customerName,
      customerEmail: customerEmail,
      reportDate: tillDate,
      overrideRatePM: overrideRatePM,
      loans: reportLoans,
    );
  }
  // Compound report ko Firestore History mein save karna.
  Future<String> saveReportToHistory({
    required InterestCompoundReportResult result,
    required String adminUid,
  }) async {
    if (adminUid.trim().isEmpty) {
      throw Exception('Admin UID nahi mila.');
    }

    final reportData = {
      'adminUid': adminUid,
      'customerId': result.customerId,
      'customerName': result.customerName,
      'customerEmail': result.customerEmail,

      'interestType': 'compound',
      'reportDate': Timestamp.fromDate(result.reportDate),
      'generatedAt': FieldValue.serverTimestamp(),

      'overrideRatePM': result.overrideRatePM,

      'totalPrincipal': result.totalPrincipal,
      'totalInterest': result.totalInterest,
      'totalPrincipalSide': result.totalPrincipalSide,
      'totalDeposit': result.totalDeposit,
      'finalDue': result.finalDue,

      'selectedLoanIds': result.loans.map((loan) => loan.loanId).toList(),

      'loans': result.loans.map((loan) {
        final calculation = loan.calculation;

        return {
          'loanId': loan.loanId,
          'loanName': loan.loanName,
          'principal': loan.principal,
          'monthlyRate': loan.monthlyRate,
          'openingDate': Timestamp.fromDate(loan.openingDate),

          'totalInterest': loan.totalInterest,
          'totalDeposit': loan.totalDeposit,
          'finalDue': loan.finalDue,

          'calculation': {
            'openingAmount': calculation.openingAmount,
            'monthlyRate': calculation.monthlyRate,
            'openingDate': Timestamp.fromDate(calculation.openingDate),
            'tillDate': Timestamp.fromDate(calculation.tillDate),

            'totalInterest': calculation.totalInterest,
            'totalDeposit': calculation.totalDeposit,
            'finalDue': calculation.finalDue,
            'finalPrincipal': calculation.finalPrincipal,

            'cycles': calculation.cycles.map((cycle) {
              return {
                'cycleNumber': cycle.cycleNumber,
                'adjustmentDate':
                Timestamp.fromDate(cycle.adjustmentDate),
                'closingDate':
                Timestamp.fromDate(cycle.closingDate),

                'openingPrincipal': cycle.openingPrincipal,
                'monthlyRate': cycle.monthlyRate,

                'duration': {
                  'years': cycle.duration.years,
                  'months': cycle.duration.months,
                  'days': cycle.duration.days,
                },

                'isCompound': cycle.isCompound,
                'interestType': cycle.interestType,

                'interest': cycle.interest,
                'totalBeforeDeposit': cycle.totalBeforeDeposit,
                'depositAmount': cycle.depositAmount,
                'remainingPrincipal': cycle.remainingPrincipal,

                'depositId': cycle.depositId,
                'description': cycle.description,
                'isFinalCycle': cycle.isFinalCycle,
              };
            }).toList(),
          },
        };
      }).toList(),
    };

    final doc = await _firestore
        .collection('interest_compound_reports')
        .add(reportData);

    return doc.id;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

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

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _getLoanName(
      Map<String, dynamic> loanData,
      String loanId,
      ) {
    final name = loanData['loanName'] ??
        loanData['name'] ??
        loanData['title'];

    if (name == null || name.toString().trim().isEmpty) {
      return 'Loan $loanId';
    }

    return name.toString();
  }
}

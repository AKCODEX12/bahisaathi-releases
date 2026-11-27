
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Bearing reports
import 'report_calculation_service.dart';
import 'loan_report_preview_screen.dart';
import 'calculation_engine.dart';

// Interest Compound reports
import 'loan/reports/interest/compound/interest_compound_calculation_engine.dart';
import 'loan/reports/interest/compound/interest_compound_report_service.dart';
import 'loan/reports/interest/compound/interest_compound_preview_screen.dart';

// Interest Simple reports
import 'loan/reports/interest/simple/interest_simple_calculation_engine.dart';
import 'loan/reports/interest/simple/interest_simple_report_service.dart';
import 'loan/reports/interest/simple/interest_simple_preview_screen.dart';

class HistoryReportsScreen extends StatelessWidget {
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String adminUid;

  const HistoryReportsScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.adminUid,
  });

  String formatAmount(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    final fixed = number % 1 == 0
        ? number.toInt().toString()
        : number.toStringAsFixed(2);

    final parts = fixed.split('.');
    final integer = parts[0];

    String formatted;

    if (integer.length <= 3) {
      formatted = integer;
    } else {
      final lastThree = integer.substring(integer.length - 3);
      var rest = integer.substring(0, integer.length - 3);

      final groups = <String>[];

      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }

      if (rest.isNotEmpty) {
        groups.insert(0, rest);
      }

      formatted = '${groups.join(',')},$lastThree';
    }

    return '₹$formatted${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  String formatDate(dynamic value) {
    final date = _toDateTime(value);

    if (date == null) return '-';

    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  String formatDateTime(dynamic value) {
    final date = _toDateTime(value);

    if (date == null) return '-';

    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // --------------------------------------------------
  // BEARING: OLD REPORT RECONSTRUCTION (UNCHANGED)
  // --------------------------------------------------

  Future<LoanReportCalculationResult?> loadSavedReport(
      DocumentSnapshot<Map<String, dynamic>> reportDoc,
      ) async {
    final data = reportDoc.data();

    if (data == null) return null;

    final principals = <ReportPrincipalEntry>[];
    final deposits = <ReportDepositEntry>[];

    final reportDate = _toDateTime(data['reportDate']);

    if (reportDate == null) return null;

    final isCompound =
        (data['interestType'] ?? 'Compound')
            .toString()
            .toLowerCase() ==
            'compound';

    final overrideRateValue = data['overrideRatePM'];

    final double? overrideRatePM = overrideRateValue == null
        ? null
        : _toDouble(overrideRateValue);

    final principalList =
    data['principals'] is List ? data['principals'] as List : [];

    for (final item in principalList) {
      if (item is! Map) continue;

      final amount = _toDouble(item['amount']);
      final rate = _toDouble(item['rate']);

      final openingDate = _toDateTime(item['openingDate']);

      if (openingDate == null) continue;

      final years = _toInt(item['years']);
      final months = _toInt(item['months']);
      final days = _toInt(item['days']);

      final interest = _toDouble(item['interest']);
      final total = _toDouble(item['total']);

      final calculation = EngineCalculationResult(
        principal: amount,
        interest: interest,
        total: total,
        years: years,
        months: months,
        days: days,
        yearlyInterest: _toDouble(item['yearlyInterest']),
        monthlyInterest: _toDouble(item['monthlyInterest']),
        dailyInterest: _toDouble(item['dailyInterest']),
        isCompound: isCompound,
        rate: rate,
        startDate: openingDate,
        closingDate: reportDate,
      );

      principals.add(
        ReportPrincipalEntry(
          loanId: (item['loanId'] ?? '').toString(),
          loanName: (item['loanName'] ?? 'Loan').toString(),
          amount: amount,
          rate: rate,
          openingDate: openingDate,
          calculation: calculation,
        ),
      );
    }

    final depositList =
    data['deposits'] is List ? data['deposits'] as List : [];

    for (final item in depositList) {
      if (item is! Map) continue;

      final amount = _toDouble(item['amount']);
      final rate = _toDouble(item['rate']);

      final depositDate = _toDateTime(item['depositDate']);

      if (depositDate == null) continue;

      final years = _toInt(item['years']);
      final months = _toInt(item['months']);
      final days = _toInt(item['days']);

      final interest = _toDouble(item['interest']);
      final total = _toDouble(item['total']);

      final calculation = EngineCalculationResult(
        principal: amount,
        interest: interest,
        total: total,
        years: years,
        months: months,
        days: days,
        yearlyInterest: _toDouble(item['yearlyInterest']),
        monthlyInterest: _toDouble(item['monthlyInterest']),
        dailyInterest: _toDouble(item['dailyInterest']),
        isCompound: isCompound,
        rate: rate,
        startDate: depositDate,
        closingDate: reportDate,
      );

      deposits.add(
        ReportDepositEntry(
          loanId: (item['loanId'] ?? '').toString(),
          loanName: (item['loanName'] ?? 'Loan').toString(),
          depositId: (item['depositId'] ?? '').toString(),
          amount: amount,
          rate: rate,
          depositDate: depositDate,
          calculation: calculation,
        ),
      );
    }

    return LoanReportCalculationResult(
      customerId: (data['customerId'] ?? customerId).toString(),
      customerName: (data['customerName'] ?? customerName).toString(),
      customerEmail: (data['customerEmail'] ?? customerEmail).toString(),
      reportDate: reportDate,
      isCompound: isCompound,
      overrideRatePM: overrideRatePM,
      principals: principals,
      deposits: deposits,
    );
  }

  // --------------------------------------------------
  // INTEREST SIMPLE: SAVED REPORT RECONSTRUCTION
  // --------------------------------------------------

  Future<InterestSimpleReportResult?> loadSavedSimpleReport(
      DocumentSnapshot<Map<String, dynamic>> reportDoc,
      ) async {
    final data = reportDoc.data();

    if (data == null) return null;

    final reportDate = _toDateTime(data['reportDate']);

    if (reportDate == null) return null;

    final loans = <InterestSimpleLoanResult>[];

    final loanList = data['loans'] is List
        ? data['loans'] as List
        : [];

    for (final item in loanList) {
      if (item is! Map) continue;

      final openingDate = _toDateTime(item['openingDate']);
      final tillDate = _toDateTime(item['tillDate']);

      if (openingDate == null || tillDate == null) continue;

      final durationData = _asMap(item['duration']);

      final duration = InterestSimpleDuration(
        years: _toInt(durationData['years']),
        months: _toInt(durationData['months']),
        days: _toInt(durationData['days']),
      );

      final deposits = <InterestSimpleDeposit>[];

      final depositList = item['deposits'] is List
          ? item['deposits'] as List
          : [];

      for (final deposit in depositList) {
        if (deposit is! Map) continue;

        final depositDate = _toDateTime(deposit['depositDate']);

        if (depositDate == null) continue;

        deposits.add(
          InterestSimpleDeposit(
            id: (deposit['depositId'] ?? '').toString(),
            amount: _toDouble(deposit['amount']),
            depositDate: depositDate,
            description: (deposit['description'] ?? '').toString(),
          ),
        );
      }

      loans.add(
        InterestSimpleLoanResult(
          loanId: (item['loanId'] ?? '').toString(),
          loanName: (item['loanName'] ?? 'Loan').toString(),
          principal: _toDouble(item['principal']),
          monthlyRate: _toDouble(item['monthlyRate']),
          openingDate: openingDate,
          tillDate: tillDate,
          duration: duration,
          interest: _toDouble(item['interest']),
          total: _toDouble(item['total']),
          deposits: deposits,
        ),
      );
    }

    final calculation = InterestSimpleCalculationResult(
      reportDate: reportDate,
      loans: loans,
    );

    return InterestSimpleReportResult(
      customerId: (data['customerId'] ?? customerId).toString(),
      customerName: (data['customerName'] ?? customerName).toString(),
      customerEmail: (data['customerEmail'] ?? customerEmail).toString(),
      reportDate: reportDate,
      overrideRatePM: data['overrideRatePM'] == null
          ? null
          : _toDouble(data['overrideRatePM']),
      calculation: calculation,
    );
  }

  // --------------------------------------------------
  // INTEREST COMPOUND: SAVED REPORT RECONSTRUCTION
  // --------------------------------------------------

  Future<InterestCompoundReportResult?> loadSavedCompoundReport(
      DocumentSnapshot<Map<String, dynamic>> reportDoc,
      ) async {
    final data = reportDoc.data();

    if (data == null) return null;

    final reportDate = _toDateTime(data['reportDate']);

    if (reportDate == null) return null;

    final loans = <InterestCompoundReportLoan>[];

    final loanList = data['loans'] is List
        ? data['loans'] as List
        : [];

    for (final item in loanList) {
      if (item is! Map) continue;

      final openingDate = _toDateTime(item['openingDate']);

      if (openingDate == null) continue;

      final calculationData = _asMap(item['calculation']);

      final calculationOpeningDate =
      _toDateTime(calculationData['openingDate']);

      final tillDate = _toDateTime(calculationData['tillDate']);

      if (calculationOpeningDate == null || tillDate == null) {
        continue;
      }

      final cycles = <InterestCompoundCycle>[];

      final cycleList = calculationData['cycles'] is List
          ? calculationData['cycles'] as List
          : [];

      for (final cycle in cycleList) {
        if (cycle is! Map) continue;

        final adjustmentDate =
        _toDateTime(cycle['adjustmentDate']);

        final closingDate =
        _toDateTime(cycle['closingDate']);

        if (adjustmentDate == null || closingDate == null) {
          continue;
        }

        final durationData = _asMap(cycle['duration']);

        cycles.add(
          InterestCompoundCycle(
            cycleNumber: _toInt(cycle['cycleNumber']),
            adjustmentDate: adjustmentDate,
            closingDate: closingDate,
            openingPrincipal: _toDouble(cycle['openingPrincipal']),
            monthlyRate: _toDouble(cycle['monthlyRate']),
            duration: InterestCompoundDuration(
              years: _toInt(durationData['years']),
              months: _toInt(durationData['months']),
              days: _toInt(durationData['days']),
            ),
            isCompound: cycle['isCompound'] == true,
            interest: _toDouble(cycle['interest']),
            totalBeforeDeposit: _toDouble(cycle['totalBeforeDeposit']),
            depositAmount: _toDouble(cycle['depositAmount']),
            remainingPrincipal: _toDouble(cycle['remainingPrincipal']),
            depositId: cycle['depositId']?.toString(),
            description: (cycle['description'] ?? '').toString(),
          ),
        );
      }

      final calculation = InterestCompoundResult(
        openingAmount: _toDouble(calculationData['openingAmount']),
        monthlyRate: _toDouble(calculationData['monthlyRate']),
        openingDate: calculationOpeningDate,
        tillDate: tillDate,
        cycles: cycles,
      );

      loans.add(
        InterestCompoundReportLoan(
          loanId: (item['loanId'] ?? '').toString(),
          loanName: (item['loanName'] ?? 'Loan').toString(),
          principal: _toDouble(item['principal']),
          monthlyRate: _toDouble(item['monthlyRate']),
          openingDate: openingDate,
          calculation: calculation,
        ),
      );
    }

    return InterestCompoundReportResult(
      customerId: (data['customerId'] ?? customerId).toString(),
      customerName: (data['customerName'] ?? customerName).toString(),
      customerEmail: (data['customerEmail'] ?? customerEmail).toString(),
      reportDate: reportDate,
      overrideRatePM: data['overrideRatePM'] == null
          ? null
          : _toDouble(data['overrideRatePM']),
      loans: loans,
    );
  }

  // --------------------------------------------------
  // OPEN CORRECT PREVIEW ACCORDING TO COLLECTION
  // --------------------------------------------------

  Future<void> openReport(
      BuildContext context,
      DocumentSnapshot<Map<String, dynamic>> reportDoc,
      ) async {
    try {
      final collectionName = reportDoc.reference.parent.id;

      if (collectionName == 'interest_simple_reports') {
        final result = await loadSavedSimpleReport(reportDoc);

        if (result == null) {
          throw Exception('Unable to reconstruct Interest Simple report.');
        }

        if (!context.mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InterestSimplePreviewScreen(result: result),
          ),
        );

        return;
      }

      if (collectionName == 'interest_compound_reports') {
        final result = await loadSavedCompoundReport(reportDoc);

        if (result == null) {
          throw Exception('Unable to reconstruct Interest Compound report.');
        }

        if (!context.mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InterestCompoundPreviewScreen(result: result),
          ),
        );

        return;
      }

      // Bearing Simple and Bearing Compound remain on their old preview.
      final result = await loadSavedReport(reportDoc);

      if (result == null) {
        throw Exception('Unable to open Bearing report.');
      }

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoanReportPreviewScreen(result: result),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open report: $e'),
          ),
        );
      }
    }
  }

  // --------------------------------------------------
  // COMMON HELPERS
  // --------------------------------------------------

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) return value.toDate();

    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }

  Widget _summaryRow(
      String title,
      String value, {
        bool bold = false,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: bold ? FontWeight.bold : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: bold
                ? const Color(0xFF143C2C)
                : const Color(0xFF34454F),
          ),
        ),
      ],
    );
  }

  void _checkHistoryUid() {
    debugPrint('HISTORY adminUid: $adminUid');
    debugPrint('HISTORY customerId: $customerId');
    debugPrint(
      'LOGIN UID: ${FirebaseAuth.instance.currentUser?.uid}',
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _historyStream(
      String collectionName,
      ) {
    return FirebaseFirestore.instance
        .collection(collectionName)
        .where('adminUid', isEqualTo: adminUid)
        .where('customerId', isEqualTo: customerId)
        .orderBy('generatedAt', descending: true)
        .snapshots();
  }

  // --------------------------------------------------
  // HISTORY SCREEN
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _checkHistoryUid();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F8),
      appBar: AppBar(
        title: const Text(
          'History Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _historyStream('reports'),
        builder: (context, bearingSnapshot) {
          if (bearingSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bearingSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load Bearing reports.\n\n'
                      '${bearingSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _historyStream('interest_compound_reports'),
            builder: (context, compoundSnapshot) {
              if (compoundSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (compoundSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load Interest Compound reports.\n\n'
                          '${compoundSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _historyStream('interest_simple_reports'),
                builder: (context, simpleSnapshot) {
                  if (simpleSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (simpleSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Unable to load Interest Simple reports.\n\n'
                              '${simpleSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final reports = [
                    ...?bearingSnapshot.data?.docs,
                    ...?compoundSnapshot.data?.docs,
                    ...?simpleSnapshot.data?.docs,
                  ];

                  reports.sort((a, b) {
                    final aDate = _toDateTime(a.data()['generatedAt']) ??
                        DateTime.fromMillisecondsSinceEpoch(0);

                    final bDate = _toDateTime(b.data()['generatedAt']) ??
                        DateTime.fromMillisecondsSinceEpoch(0);

                    return bDate.compareTo(aDate);
                  });

                  if (reports.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No History Reports',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Generated reports for $customerName '
                                  'will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final doc = reports[index];
                      final data = doc.data();

                      final collectionName = doc.reference.parent.id;

                      final depositType =
                      collectionName == 'reports'
                          ? 'Bearing'
                          : 'Interest';

                      final interestType =
                      (data['interestType'] ?? 'Compound')
                          .toString()
                          .toLowerCase();

                      final reportType =
                          '$depositType - '
                          '${interestType[0].toUpperCase()}'
                          '${interestType.substring(1)}';

                      final finalDue = _toDouble(data['finalDue']);
                      final totalPrincipal =
                      _toDouble(data['totalPrincipal']);
                      final totalDeposit =
                      _toDouble(data['totalDeposit']);

                      final generatedAt = data['generatedAt'];
                      final reportDate = data['reportDate'];

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => openReport(context, doc),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE0E9E4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.025),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F5EA),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      Icons.description_outlined,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Loan & Interest Report',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF143C2C),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Report Date: ${formatDate(reportDate)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: Colors.green.shade700,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: Colors.grey.shade200),
                              const SizedBox(height: 10),
                              _summaryRow(
                                'Generated',
                                formatDateTime(generatedAt),
                              ),
                              const SizedBox(height: 7),
                              _summaryRow('Report Type', reportType),
                              const SizedBox(height: 7),
                              _summaryRow(
                                'Principal',
                                formatAmount(totalPrincipal),
                              ),
                              const SizedBox(height: 7),
                              _summaryRow(
                                'Deposits',
                                formatAmount(totalDeposit),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F8F5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: _summaryRow(
                                  'FINAL DUE',
                                  formatAmount(finalDue),
                                  bold: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}


import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'interest_simple_report_service.dart';

class InterestSimplePdfService {
  static Future<Uint8List> generatePdf(
      InterestSimpleReportResult result,
      ) async {
    final pdf = pw.Document();

    final loans = result.calculation.loans;

    final allDeposits = loans
        .expand((loan) => loan.deposits)
        .toList()
      ..sort((a, b) => a.depositDate.compareTo(b.depositDate));

    final principalRows = <List<String>>[];

    for (int i = 0; i < loans.length; i++) {
      final loan = loans[i];

      principalRows.add([
        _loanNumber(loan.loanId),
        _money(loan.principal),
        _date(loan.openingDate),
        '${loan.monthlyRate.toStringAsFixed(2)}%',
        _money(loan.interest),
        loan.duration.toString(),
      ]);
    }

    final depositRows = <List<String>>[];

    for (int i = 0; i < allDeposits.length; i++) {
      final deposit = allDeposits[i];

      depositRows.add([
        '${i + 1}',
        _money(deposit.amount),
        _date(deposit.depositDate),
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            pw.Center(
              child: pw.Text(
                'SIMPLE INTEREST REPORT',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 18),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _detail('Customer Name', result.customerName),
                  _detail('Customer Email', result.customerEmail),
                  _detail('Till Date', _date(result.reportDate)),
                  _detail('Interest Type', 'Simple Interest'),
                ],
              ),
            ),

            pw.SizedBox(height: 18),

            pw.Center(
              child: pw.Text(
                'PRINCIPAL',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: [
                'Loan No.',
                'Principal',
                'Opening Date',
                'Rate PM',
                'Interest',
                'Duration',
              ],
              data: principalRows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              border: pw.TableBorder.all(
                color: PdfColors.grey600,
                width: 0.5,
              ),
              cellAlignment: pw.Alignment.center,
              headerAlignment: pw.Alignment.center,
              cellPadding: const pw.EdgeInsets.all(5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8),
                1: const pw.FlexColumnWidth(1.1),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(0.8),
                4: const pw.FlexColumnWidth(1.1),
                5: const pw.FlexColumnWidth(1.5),
              },
            ),

            pw.SizedBox(height: 12),

            pw.Center(
              child: pw.Column(
                children: [
                  _summary(
                    'Total Principal',
                    result.totalPrincipal,
                  ),
                  _summary(
                    'Total Interest',
                    result.totalInterest,
                  ),
                  _summary(
                    'Total Principal Side',
                    result.totalPrincipalSide,
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            pw.Center(
              child: pw.Text(
                'DEPOSIT',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: [
                'Deposit No.',
                'Deposit',
                'Deposit Date',
              ],
              data: depositRows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              border: pw.TableBorder.all(
                color: PdfColors.grey600,
                width: 0.5,
              ),
              cellAlignment: pw.Alignment.center,
              headerAlignment: pw.Alignment.center,
              cellPadding: const pw.EdgeInsets.all(6),
            ),

            pw.SizedBox(height: 12),

            pw.Center(
              child: _summary(
                'Total Deposit',
                result.totalDeposit,
              ),
            ),

            pw.SizedBox(height: 20),

            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.black,
                  width: 1.2,
                ),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'FINAL DUE',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    _money(result.finalDue),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> savePdf(
      InterestSimpleReportResult result,
      ) async {
    final bytes = await generatePdf(result);

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Simple_Interest_Report.pdf',
    );
  }

  static Future<void> sharePdf(
      InterestSimpleReportResult result,
      ) async {
    final bytes = await generatePdf(result);

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Simple_Interest_Report.pdf',
    );
  }

  static pw.Widget _detail(String title, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              title,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static pw.Widget _summary(String title, double amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(
        '$title = ${_money(amount)}',
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static String _loanNumber(String loanId) {
    final match = RegExp(r'\d+').firstMatch(loanId);
    return match?.group(0) ?? loanId;
  }

  static String _money(double amount) {
    return 'Rs. ${amount.toStringAsFixed(2)}';
  }

  static String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }
}

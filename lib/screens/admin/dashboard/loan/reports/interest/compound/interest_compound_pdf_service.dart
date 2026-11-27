
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'interest_compound_report_service.dart';

class InterestCompoundPdfService {
  static Future<Uint8List> generatePdf(
      InterestCompoundReportResult result,
      ) async {
    final pdf = pw.Document();

    final regularFont = await _loadFont(
      'assets/fonts/NotoSans-Regular.ttf',
    );

    final boldFont = await _loadFont(
      'assets/fonts/NotoSans-Bold.ttf',
    );

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    final totalPrincipal = result.totalPrincipal;

    final totalDueInterest = result.totalInterest;

    final totalPrincipalSide =
        totalPrincipal + totalDueInterest;

    final totalAdjustedDeposit = result.totalDeposit;

    final finalDue = result.finalDue;

    final deposits = <_PdfDepositRow>[];

    for (final loan in result.loans) {
      for (final cycle in loan.calculation.cycles) {
        if (cycle.depositAmount <= 0) continue;

        deposits.add(
          _PdfDepositRow(
            amount: cycle.depositAmount,
            date: cycle.closingDate,
          ),
        );
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            pw.Center(
              child: pw.Text(
                'COMPOUND INTEREST REPORT',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 18),

            _customerDetails(result),

            pw.SizedBox(height: 22),

            _sectionTitle('PRINCIPAL'),

            pw.SizedBox(height: 8),

            _principalTable(result),

            pw.SizedBox(height: 18),

            _summaryRow('Total Principal', totalPrincipal),
            pw.SizedBox(height: 6),

            _summaryRow('Total Due Interest', totalDueInterest),
            pw.SizedBox(height: 6),

            _summaryRow(
              'Total Principal Side',
              totalPrincipalSide,
              bold: true,
            ),

            pw.SizedBox(height: 24),

            _sectionTitle('INTEREST DEPOSIT'),

            pw.SizedBox(height: 8),

            _depositTable(deposits),

            pw.SizedBox(height: 16),

            _adjustedDepositBox(totalAdjustedDeposit),

            pw.SizedBox(height: 24),

            _finalDueBox(finalDue),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<pw.Font> _loadFont(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);

      return pw.Font.ttf(data);
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  static pw.Widget _customerDetails(
      InterestCompoundReportResult result,
      ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey600,
        ),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CUSTOMER DETAILS',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 10),

          _detailRow('Customer Name', result.customerName),
          _detailRow('Customer Email', result.customerEmail),
          _detailRow('Report Till Date', _date(result.reportDate)),
          _detailRow('Interest Type', 'Compound'),
        ],
      ),
    );
  }

  static pw.Widget _detailRow(
      String title,
      String value,
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(title),
          ),
          pw.Text(':  '),
          pw.Expanded(
            flex: 6,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Center(
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  static pw.Widget _principalTable(
      InterestCompoundReportResult result,
      ) {
    final headers = [
      'Loan No.',
      'Principal',
      'Opening Date',
      'Rate PM',
      'Interest',
      'Duration',
    ];

    final rows = <List<String>>[];

    for (int i = 0; i < result.loans.length; i++) {
      final loan = result.loans[i];

      final interest = loan.calculation.totalInterest;

      rows.add([
        '${i + 1}',
        _money(loan.principal),
        _date(loan.openingDate),
        '${loan.monthlyRate}%',
        _money(interest),
        _duration(loan.openingDate, result.reportDate),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(
        color: PdfColors.grey600,
        width: 0.5,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
      ),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.all(5),
    );
  }

  static pw.Widget _depositTable(
      List<_PdfDepositRow> deposits,
      ) {
    if (deposits.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600),
        ),
        child: pw.Center(
          child: pw.Text('No Deposit Found'),
        ),
      );
    }

    final rows = <List<String>>[];

    for (int i = 0; i < deposits.length; i++) {
      final deposit = deposits[i];

      rows.add([
        '${i + 1}',
        _money(deposit.amount),
        _date(deposit.date),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: [
        'Deposit No.',
        'Deposit Amount',
        'Deposit Date',
      ],
      data: rows,
      border: pw.TableBorder.all(
        color: PdfColors.grey600,
        width: 0.5,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
      ),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.all(6),
    );
  }

  static pw.Widget _summaryRow(
      String title,
      double amount, {
        bool bold = false,
      }) {
    return pw.Center(
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$title = ',
              style: pw.TextStyle(
                fontWeight: bold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                fontSize: 11,
              ),
            ),
            pw.TextSpan(
              text: _money(amount),
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _adjustedDepositBox(double amount) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'TOTAL DEPOSIT (Adjusted in interest)',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 8),

          pw.Text(
            _money(amount),
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 6),

          pw.Text(
            'Ye amount BYAAJ me adjust ho chuka hai. '
                'Final Due mein ise dobara minus nahi karna hai.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _finalDueBox(double amount) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 12,
      ),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.blueGrey800,
          width: 2,
        ),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'FINAL DUE',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 10),

          pw.Text(
            _money(amount),
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static String _money(double amount) {
    final value = amount.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      buffer.write(value[i]);

      final remaining = value.length - i - 1;

      if (remaining > 0) {
        if (remaining == 3 ||
            (remaining > 3 && (remaining - 3) % 2 == 0)) {
          buffer.write(',');
        }
      }
    }

    return '₹$buffer';
  }

  static String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day-$month-${date.year}';
  }

  static String _duration(DateTime start, DateTime end) {
    DateTime first = DateTime(start.year, start.month, start.day);
    DateTime last = DateTime(end.year, end.month, end.day);

    if (last.isBefore(first)) return '0 Days';

    int years = last.year - first.year;
    int months = last.month - first.month;
    int days = last.day - first.day;

    if (days < 0) {
      months--;
      days += DateTime(last.year, last.month, 0).day;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    final parts = <String>[];

    if (years > 0) parts.add('$years Y');

    if (months > 0) parts.add('$months M');

    if (days > 0 || parts.isEmpty) parts.add('$days D');

    return parts.join(' ');
  }

  static Future<void> sharePdf(
      InterestCompoundReportResult result,
      ) async {
    final bytes = await generatePdf(result);

    await Printing.sharePdf(
      bytes: bytes,
      filename:
      'compound_interest_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> savePdf(
      InterestCompoundReportResult result,
      ) async {
    final bytes = await generatePdf(result);

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Compound Interest Report',
    );
  }
}

class _PdfDepositRow {
  final double amount;
  final DateTime date;

  const _PdfDepositRow({
    required this.amount,
    required this.date,
  });
}

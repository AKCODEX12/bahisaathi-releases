
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;

import 'interest_compound_report_service.dart';
import 'interest_compound_pdf_service.dart';

class InterestCompoundPreviewScreen extends StatefulWidget {
  final InterestCompoundReportResult result;

  const InterestCompoundPreviewScreen({
    super.key,
    required this.result,
  });

  @override
  State<InterestCompoundPreviewScreen> createState() =>
      _InterestCompoundPreviewScreenState();
}

class _InterestCompoundPreviewScreenState
    extends State<InterestCompoundPreviewScreen> {
  bool _isProcessing = false;

  InterestCompoundReportResult get result => widget.result;

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _money(num amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _duration(DateTime start, DateTime end) {
    int years = end.year - start.year;
    int months = end.month - start.month;
    int days = end.day - start.day;

    if (days < 0) {
      months--;
      final previousMonth = DateTime(end.year, end.month, 0);
      days += previousMonth.day;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    return '$years Y, $months M, $days D';
  }

  Future<void> _sharePdf() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await InterestCompoundPdfService.sharePdf(result);
    } catch (e) {
      _showMessage('PDF share nahi ho paya: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _savePdf() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await InterestCompoundPdfService.savePdf(result);
    } catch (e) {
      _showMessage('PDF save nahi ho paya: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveJpg() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final pdfBytes =
      await InterestCompoundPdfService.generatePdf(result);

      final List<img.Image> pages = [];

      await for (final page in Printing.raster(
        pdfBytes,
        dpi: 120,
      )) {
        final pngBytes = await page.toPng();
        final decoded = img.decodeImage(pngBytes);

        if (decoded != null) {
          pages.add(decoded);
        }
      }

      if (pages.isEmpty) {
        throw Exception('JPG image generate nahi ho payi.');
      }

      final maxWidth = pages
          .map((page) => page.width)
          .reduce((a, b) => a > b ? a : b);

      final totalHeight =
      pages.fold<int>(0, (sum, page) => sum + page.height);

      final combinedImage = img.Image(
        width: maxWidth,
        height: totalHeight,
      );

      int currentY = 0;

      for (final page in pages) {
        img.compositeImage(
          combinedImage,
          page,
          dstX: 0,
          dstY: currentY,
        );

        currentY += page.height;
      }

      final Uint8List jpgBytes = Uint8List.fromList(
        img.encodeJpg(combinedImage, quality: 90),
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              jpgBytes,
              mimeType: 'image/jpeg',
              name: 'compound_interest_report.jpg',
            ),
          ],
          text: 'Compound Interest Report',
        ),
      );
    } catch (e) {
      _showMessage('JPG generate nahi ho payi: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loans = result.loans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compound Interest Report'),
        actions: [
          IconButton(
            tooltip: 'Share PDF',
            onPressed: _isProcessing ? null : _sharePdf,
            icon: const Icon(Icons.share),
          ),
          IconButton(
            tooltip: 'Save PDF',
            onPressed: _isProcessing ? null : _savePdf,
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _customerDetails(),
                  const SizedBox(height: 20),

                  _sectionTitle('PRINCIPAL'),
                  const SizedBox(height: 8),

                  _principalTable(loans),

                  const SizedBox(height: 16),
                  _principalSummary(),

                  const SizedBox(height: 24),
                  _sectionTitle('INTEREST DEPOSIT'),
                  const SizedBox(height: 8),

                  _depositTable(loans),

                  const SizedBox(height: 20),
                  _adjustedDepositBox(),

                  const SizedBox(height: 20),
                  _finalDueBox(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          _bottomActions(),
        ],
      ),
    );
  }

  Widget _customerDetails() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CUSTOMER DETAILS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _detailRow('Customer Name', result.customerName),
            _detailRow('Email', result.customerEmail),
            _detailRow('Report Till Date', _date(result.reportDate)),
            _detailRow('Interest Type', 'Compound'),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': '),
          Expanded(
            flex: 5,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  Widget _principalTable(List<InterestCompoundReportLoan> loans) {
    if (loans.isEmpty) {
      return const Center(child: Text('No Loan Found'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowColor: WidgetStateProperty.all(
          Colors.blueGrey.shade100,
        ),
        columns: const [
          DataColumn(label: Text('Loan No.')),
          DataColumn(label: Text('Principal')),
          DataColumn(label: Text('Opening Date')),
          DataColumn(label: Text('Rate PM')),
          DataColumn(label: Text('Interest')),
          DataColumn(label: Text('Duration')),
        ],
        rows: List.generate(loans.length, (index) {
          final loan = loans[index];

          final interest = loan.calculation.totalInterest;

          return DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(_money(loan.principal))),
              DataCell(Text(_date(loan.openingDate))),
              DataCell(Text('${loan.monthlyRate}%')),
              DataCell(Text(_money(interest))),
              DataCell(
                Text(_duration(
                  loan.openingDate,
                  result.reportDate,
                )),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _principalSummary() {
    return Column(
      children: [
        _summaryRow('Total Principal', result.totalPrincipal),
        _summaryRow('Total Due Interest', result.totalInterest),
        const Divider(),
        _summaryRow(
          'Total Principal Side',
          result.totalPrincipalSide,
          bold: true,
        ),
      ],
    );
  }

  Widget _summaryRow(
      String title,
      num amount, {
        bool bold = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            _money(amount),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _depositTable(List<InterestCompoundReportLoan> loans) {
    final deposits = <Map<String, dynamic>>[];

    for (final loan in loans) {
      for (final cycle in loan.calculation.cycles) {
        if (cycle.depositAmount > 0) {
          deposits.add({
            'amount': cycle.depositAmount,
            'date': cycle.closingDate,
          });
        }
      }
    }

    deposits.sort((a, b) =>
        (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    if (deposits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No Deposit Found'),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 35,
        headingRowColor: WidgetStateProperty.all(
          Colors.blueGrey.shade100,
        ),
        columns: const [
          DataColumn(label: Text('Deposit No.')),
          DataColumn(label: Text('Deposit Amount')),
          DataColumn(label: Text('Deposit Date')),
        ],
        rows: List.generate(deposits.length, (index) {
          final deposit = deposits[index];

          return DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(_money(deposit['amount'] as num))),
              DataCell(Text(_date(deposit['date'] as DateTime))),
            ],
          );
        }),
      ),
    );
  }

  Widget _adjustedDepositBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text(
            'TOTAL ADJUST DEPOSIT IN INTEREST',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _money(result.totalDeposit),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ye Amount BYAAJ me adjust ho chuka hai.'
                ,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _finalDueBox() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.blueGrey.shade800,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text(
            'FINAL DUE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _money(result.finalDue),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isProcessing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _sharePdf,
                    icon: const Icon(Icons.share),
                    label: const Text('Share PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _savePdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Save PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _saveJpg,
                icon: const Icon(Icons.image),
                label: const Text('Save / Share JPG'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

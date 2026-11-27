
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;

import 'interest_simple_calculation_engine.dart';
import 'interest_simple_report_service.dart';
import 'interest_simple_pdf_service.dart';

class InterestSimplePreviewScreen extends StatefulWidget {
  final InterestSimpleReportResult result;

  const InterestSimplePreviewScreen({
    super.key,
    required this.result,
  });

  @override
  State<InterestSimplePreviewScreen> createState() =>
      _InterestSimplePreviewScreenState();
}

class _InterestSimplePreviewScreenState
    extends State<InterestSimplePreviewScreen> {
  bool _isProcessing = false;

  InterestSimpleReportResult get result => widget.result;

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _money(num amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _sharePdf() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await InterestSimplePdfService.sharePdf(result);
    } catch (e) {
      _showMessage('PDF share nahi ho paya: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _savePdf() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await InterestSimplePdfService.savePdf(result);
    } catch (e) {
      _showMessage('PDF save nahi ho paya: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _saveJpg() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final pdfBytes =
      await InterestSimplePdfService.generatePdf(result);

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

      final totalHeight = pages.fold<int>(
        0,
            (sum, page) => sum + page.height,
      );

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
              name: 'simple_interest_report.jpg',
            ),
          ],
          text: 'Simple Interest Report',
        ),
      );
    } catch (e) {
      _showMessage('JPG generate nahi ho payi: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loans = result.calculation.loans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Interest Report'),
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
                  _loanDetails(),

                  const SizedBox(height: 20),

                  _sectionTitle('PRINCIPAL'),

                  const SizedBox(height: 8),

                  _principalTable(loans),

                  const SizedBox(height: 16),

                  _principalSummary(),

                  const SizedBox(height: 24),

                  _sectionTitle('DEPOSIT'),

                  const SizedBox(height: 8),

                  _depositTable(loans),

                  const SizedBox(height: 20),

                  _depositSummary(),

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

  Widget _loanDetails() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LOAN DETAILS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _detailRow('Customer Name', result.customerName),
            _detailRow('Customer Email', result.customerEmail),
            _detailRow('Till Date', _date(result.reportDate)),
            _detailRow('Interest Type', 'Simple Interest'),
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
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

  Widget _principalTable(List<InterestSimpleLoanResult> loans) {
    if (loans.isEmpty) {
      return const Center(
        child: Text('No Loan Found'),
      );
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

          return DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(_money(loan.principal))),
              DataCell(Text(_date(loan.openingDate))),
              DataCell(Text('${loan.monthlyRate}%')),
              DataCell(Text(_money(loan.interest))),
              DataCell(Text(loan.duration.toString())),
            ],
          );
        }),
      ),
    );
  }

  Widget _principalSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _summaryRow('Total Principal', result.totalPrincipal),
        _summaryRow('Total Interest', result.totalInterest),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$title = ',
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

  Widget _depositTable(List<InterestSimpleLoanResult> loans) {
    final deposits = <InterestSimpleDeposit>[];

    for (final loan in loans) {
      deposits.addAll(loan.deposits);
    }

    deposits.sort(
          (a, b) => a.depositDate.compareTo(b.depositDate),
    );

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
        columnSpacing: 30,
        headingRowColor: WidgetStateProperty.all(
          Colors.blueGrey.shade100,
        ),
        columns: const [
          DataColumn(label: Text('Deposit No.')),
          DataColumn(label: Text('Deposit')),
          DataColumn(label: Text('Deposit Date')),
        ],
        rows: List.generate(deposits.length, (index) {
          final deposit = deposits[index];

          return DataRow(
            cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(_money(deposit.amount))),
              DataCell(Text(_date(deposit.depositDate))),
            ],
          );
        }),
      ),
    );
  }

  Widget _depositSummary() {
    return Column(
      children: [
        _summaryRow(
          'Total Deposit',
          result.totalDeposit,
          bold: true,
        ),
      ],
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

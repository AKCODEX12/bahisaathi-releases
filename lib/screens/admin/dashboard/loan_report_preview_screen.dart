
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import 'report_calculation_service.dart';
import 'calculation_engine.dart';

class LoanReportPreviewScreen extends StatelessWidget {
  final LoanReportCalculationResult result;

  const LoanReportPreviewScreen({
    super.key,
    required this.result,
  });

  String _formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  String _formatRate(double rate) {
    return '${rate.toStringAsFixed(2)}%';
  }

  String _durationText(EngineCalculationResult calculation) {
    final totalMonths =
        (calculation.years * 12) + calculation.months;

    return '${totalMonths.toString().padLeft(2, '0')}M-'
        '${calculation.days.toString().padLeft(2, '0')}D';
  }

  // PDF TABLE CELL
  pw.Widget _pdfCell(
      String text, {
        bool bold = false,
        bool center = false,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 9,
      ),
      child: pw.Align(
        alignment:
        center ? pw.Alignment.center : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight:
            bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // PDF PRINCIPAL TABLE
  pw.Widget _principalPdfTable() {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey500,
        width: 0.7,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.75),
        1: const pw.FlexColumnWidth(1.35),
        2: const pw.FlexColumnWidth(1.25),
        3: const pw.FlexColumnWidth(0.85),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          children: [
            _pdfCell('Loan No.', bold: true),
            _pdfCell('Principal', bold: true),
            _pdfCell('Opening Date', bold: true),
            _pdfCell('Rate PM', bold: true),
            _pdfCell('Interest', bold: true),
            _pdfCell('Duration', bold: true),
          ],
        ),
        ...result.principals.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;

          return pw.TableRow(
            children: [
              _pdfCell('$index'),
              _pdfCell(_formatAmount(item.amount)),
              _pdfCell(_formatDate(item.openingDate)),
              _pdfCell(_formatRate(item.rate)),
              _pdfCell(_formatAmount(item.calculation.interest)),
              _pdfCell(_durationText(item.calculation)),
            ],
          );
        }),
      ],
    );
  }

  // PDF DEPOSIT TABLE
  pw.Widget _depositPdfTable() {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey500,
        width: 0.7,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.75),
        1: const pw.FlexColumnWidth(1.35),
        2: const pw.FlexColumnWidth(1.25),
        3: const pw.FlexColumnWidth(0.85),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          children: [
            _pdfCell('Deposit No.', bold: true),
            _pdfCell('Deposit', bold: true),
            _pdfCell('Deposit Date', bold: true),
            _pdfCell('Rate PM', bold: true),
            _pdfCell('Interest', bold: true),
            _pdfCell('Duration', bold: true),
          ],
        ),
        ...result.deposits.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;

          return pw.TableRow(
            children: [
              _pdfCell('$index'),
              _pdfCell(_formatAmount(item.amount)),
              _pdfCell(_formatDate(item.depositDate)),
              _pdfCell(_formatRate(item.rate)),
              _pdfCell(_formatAmount(item.calculation.interest)),
              _pdfCell(_durationText(item.calculation)),
            ],
          );
        }),
      ],
    );
  }

  // CENTERED PDF TOTAL
  pw.Widget _pdfTotal(
      String title,
      double amount, {
        bool bold = false,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Center(
        child: pw.Text(
          '$title: ${_formatAmount(amount)}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: bold ? 12 : 11,
            fontWeight:
            bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generatePdf() async {
    // LOAD PDF FONTS
    final regularFont = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      ),
    );

    final boldFont = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/NotoSans-Bold.ttf',
      ),
    );

    final pdfTheme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    final pdf = pw.Document();
    final generatedReportDate = DateTime.now();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: pdfTheme,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 30,
          ),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              color: PdfColors.white,
            ),
          ),
        ),
        build: (context) {
          return [
            // REPORT HEADER
            pw.SizedBox(height: 8),

            pw.Center(
              child: pw.Text(
                'BAHISAATHI REPORT',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
            ),

            pw.SizedBox(height: 5),

            pw.Center(
              child: pw.Text(
                'Loan & Interest Statement',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ),

            pw.SizedBox(height: 5),

            pw.Center(
              child: pw.Text(
                'Report Date: ${_formatDate(generatedReportDate)}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ),

            pw.SizedBox(height: 22),

            // CUSTOMER DETAILS
            pw.Center(
              child: pw.Container(
                width: 460,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey500,
                  ),
                  borderRadius: pw.BorderRadius.circular(9),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Customer Name: ${result.customerName}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 7),
                    pw.Text(
                      'Gmail: ${result.customerEmail}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 7),
                    pw.Text(
                      'Till Date: ${_formatDate(result.reportDate)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 7),
                    pw.Text(
                      'Interest Type: '
                          '${result.isCompound ? 'Compound' : 'Simple'}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    if (result.overrideRatePM != null) ...[
                      pw.SizedBox(height: 7),
                      pw.Text(
                        'Report Rate: '
                            '${result.overrideRatePM!.toStringAsFixed(2)}% PM',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 25),

            // PRINCIPAL HEADING
            pw.Text(
              'PRINCIPAL',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),

            pw.SizedBox(height: 10),

            if (result.principals.isEmpty)
              pw.Center(
                child: pw.Text(
                  'No active principal records found.',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              )
            else
              _principalPdfTable(),

            pw.SizedBox(height: 14),

            // PRINCIPAL TOTALS
            _pdfTotal(
              'Principal Total',
              result.totalPrincipal,
            ),
            _pdfTotal(
              'Principal Interest',
              result.totalPrincipalInterest,
            ),
            _pdfTotal(
              'Principal Side Total',
              result.principalSideTotal,
              bold: true,
            ),

            pw.SizedBox(height: 25),

            // DEPOSIT HEADING
            pw.Text(
              'DEPOSIT',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),

            pw.SizedBox(height: 10),

            if (result.deposits.isEmpty)
              pw.Center(
                child: pw.Text(
                  'No deposits found.',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              )
            else
              _depositPdfTable(),

            pw.SizedBox(height: 14),

            // DEPOSIT TOTALS
            _pdfTotal(
              'Deposit Total',
              result.totalDeposit,
            ),
            _pdfTotal(
              'Deposit Interest',
              result.totalDepositInterest,
            ),
            _pdfTotal(
              'Deposit Side Total',
              result.depositSideTotal,
              bold: true,
            ),

            pw.SizedBox(height: 28),

            // FINAL DUE BOX
            pw.Center(
              child: pw.Container(
                width: 460,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 18,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.black,
                    width: 1.5,
                  ),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'FINAL DUE',
                      style: pw.TextStyle(
                        fontSize: 19,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      _formatAmount(result.finalDue),
                      style: pw.TextStyle(
                        fontSize: 25,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 25),

            pw.Center(
              child: pw.Text(
                'Generated by BahiSaathi',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // GENERATE ONE LONG JPG FROM THE SAME PDF

  Future<Uint8List> _generateJpg() async {
    // Generate the existing PDF without changing its design.
    final pdfBytes = await _generatePdf();

    final pageImages = <img.Image>[];

    await for (final page in Printing.raster(
      pdfBytes,
      dpi: 120,
    )) {
      final pngBytes = await page.toPng();
      final decodedImage = img.decodeImage(pngBytes);

      if (decodedImage == null) continue;

      // Create a white background to prevent black JPG output.
      final whiteImage = img.Image(
        width: decodedImage.width,
        height: decodedImage.height,
        numChannels: 3,
      );

      img.fill(
        whiteImage,
        color: img.ColorRgb8(255, 255, 255),
      );

      img.compositeImage(
        whiteImage,
        decodedImage,
      );

      // Find actual content boundaries.
      int minX = whiteImage.width;
      int minY = whiteImage.height;
      int maxX = -1;
      int maxY = -1;

      for (int y = 0; y < whiteImage.height; y++) {
        for (int x = 0; x < whiteImage.width; x++) {
          final pixel = whiteImage.getPixel(x, y);

          if (pixel.r < 245 ||
              pixel.g < 245 ||
              pixel.b < 245) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      if (maxX < 0 || maxY < 0) continue;

      // Crop unnecessary blank space.
      final croppedImage = img.copyCrop(
        whiteImage,
        x: minX,
        y: minY,
        width: maxX - minX + 1,
        height: maxY - minY + 1,
      );

      pageImages.add(croppedImage);
    }

    if (pageImages.isEmpty) {
      throw Exception('Report image could not be generated.');
    }

    // Calculate the size of one combined image.
    final imageWidth = pageImages
        .map((page) => page.width)
        .reduce((a, b) => a > b ? a : b);

    final totalHeight = pageImages.fold<int>(
      0,
          (total, page) => total + page.height,
    );

    // Create white combined image.
    final combinedImage = img.Image(
      width: imageWidth,
      height: totalHeight,
      numChannels: 3,
    );

    img.fill(
      combinedImage,
      color: img.ColorRgb8(255, 255, 255),
    );

    // Join all cropped pages vertically.
    var currentY = 0;

    for (final pageImage in pageImages) {
      img.compositeImage(
        combinedImage,
        pageImage,
        dstX: 0,
        dstY: currentY,
      );

      currentY += pageImage.height;
    }

    // Generate one JPG.
    final jpgBytes = img.encodeJpg(
      combinedImage,
      quality: 95,
    );

    return Uint8List.fromList(jpgBytes);
  }


  // PRINCIPAL PREVIEW TABLE
  Widget _buildPrincipalTable() {
    return DataTable(
      border: TableBorder.all(color: Colors.grey),
      columns: const [
        DataColumn(label: Text('Loan No.')),
        DataColumn(label: Text('Principal')),
        DataColumn(label: Text('Opening Date')),
        DataColumn(label: Text('Rate PM')),
        DataColumn(label: Text('Interest')),
        DataColumn(label: Text('Duration')),
      ],
      rows: result.principals.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;

        return DataRow(
          cells: [
            DataCell(Text('$index')),
            DataCell(Text(_formatAmount(item.amount))),
            DataCell(Text(_formatDate(item.openingDate))),
            DataCell(Text(_formatRate(item.rate))),
            DataCell(Text(_formatAmount(item.calculation.interest))),
            DataCell(Text(_durationText(item.calculation))),
          ],
        );
      }).toList(),
    );
  }

  // DEPOSIT PREVIEW TABLE
  Widget _buildDepositTable() {
    return DataTable(
      border: TableBorder.all(color: Colors.grey),
      columns: const [
        DataColumn(label: Text('Deposit No.')),
        DataColumn(label: Text('Deposit')),
        DataColumn(label: Text('Deposit Date')),
        DataColumn(label: Text('Rate PM')),
        DataColumn(label: Text('Interest')),
        DataColumn(label: Text('Duration')),
      ],
      rows: result.deposits.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;

        return DataRow(
          cells: [
            DataCell(Text('$index')),
            DataCell(Text(_formatAmount(item.amount))),
            DataCell(Text(_formatDate(item.depositDate))),
            DataCell(Text(_formatRate(item.rate))),
            DataCell(Text(_formatAmount(item.calculation.interest))),
            DataCell(Text(_durationText(item.calculation))),
          ],
        );
      }).toList(),
    );
  }

  // TOTAL ROW
  Widget _totalRow(
      String title,
      double amount, {
        bool bold = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Center(
        child: Text(
          '$title: ${_formatAmount(amount)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: bold ? 15 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final generatedReportDate = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Loan Report Preview',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // REPORT HEADER
            Center(
              child: Column(
                children: [
                  const Text(
                    'BAHISAATHI REPORT',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Loan & Interest Statement',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Report Date: ${_formatDate(generatedReportDate)}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // CUSTOMER INFO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade400,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Name: ${result.customerName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text('Gmail: ${result.customerEmail}'),
                  const SizedBox(height: 5),
                  Text(
                    'Till Date: ${_formatDate(result.reportDate)}',
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Interest Type: '
                        '${result.isCompound ? 'Compound' : 'Simple'}',
                  ),
                  if (result.overrideRatePM != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Report Rate: '
                          '${result.overrideRatePM!.toStringAsFixed(2)}% PM',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // PRINCIPAL
            const Text(
              'PRINCIPAL (मूलधन)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            if (result.principals.isEmpty)
              const Text('No active principal records found.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: _buildPrincipalTable(),
                    ),
                  );
                },
              ),

            const SizedBox(height: 10),

            _totalRow('Principal Total', result.totalPrincipal),
            _totalRow(
              'Principal Interest',
              result.totalPrincipalInterest,
            ),
            _totalRow(
              'Principal Side Total',
              result.principalSideTotal,
              bold: true,
            ),

            const SizedBox(height: 22),

            // DEPOSIT
            const Text(
              'DEPOSIT (जमा)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            if (result.deposits.isEmpty)
              const Text('No deposits found.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: _buildDepositTable(),
                    ),
                  );
                },
              ),

            const SizedBox(height: 10),

            _totalRow('Deposit Total', result.totalDeposit),
            _totalRow(
              'Deposit Interest',
              result.totalDepositInterest,
            ),
            _totalRow(
              'Deposit Side Total',
              result.depositSideTotal,
              bold: true,
            ),

            const SizedBox(height: 24),

            // FINAL DUE
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text(
                    'FINAL DUE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatAmount(result.finalDue),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // SHARE AND PDF BUTTONS
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final bytes = await _generatePdf();

                        await Printing.sharePdf(
                          bytes: bytes,
                          filename: 'BahiSaathi_Report.pdf',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text('Share failed: $e'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final bytes = await _generatePdf();

                        await Printing.layoutPdf(
                          onLayout: (format) async => bytes,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text('PDF failed: $e'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // SAVE AS JPG - REPLACES OLD SAVE REPORT BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Creating JPG report...'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    final jpgBytes = await _generateJpg();

                    if (!context.mounted) return;

                    await SharePlus.instance.share(
                      ShareParams(
                        files: [
                          XFile.fromData(
                            jpgBytes,
                            mimeType: 'image/jpeg',
                          ),
                        ],
                        fileNameOverrides: [
                          'BahiSaathi_Report.jpg',
                        ],
                        title: 'BahiSaathi Report',
                      ),
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text('JPG failed: $e'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.image),
                label: const Text('Save as JPG'),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

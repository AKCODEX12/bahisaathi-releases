
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum LoanMarkType {
  signature,
  thumb,
}

class CustomerLoanAcceptanceScreen extends StatefulWidget {
  final String loanId;
  final LoanMarkType markType;

  const CustomerLoanAcceptanceScreen({
    super.key,
    required this.loanId,
    required this.markType,
  });

  @override
  State<CustomerLoanAcceptanceScreen> createState() =>
      _CustomerLoanAcceptanceScreenState();
}

class _CustomerLoanAcceptanceScreenState
    extends State<CustomerLoanAcceptanceScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<Offset?> _points = [];

  bool _isSaving = false;

  // Thumb impression size.
  double _thumbWidth = 86;
  double _thumbHeight = 112;

  String get _title {
    return widget.markType == LoanMarkType.signature
        ? 'हस्ताक्षर करें'
        : 'अंगूठे का निशान लगाएँ';
  }

  // ============================================================
  // SUBMIT ACCEPTANCE
  // ============================================================

  Future<void> _submitMark() async {
    if (_isSaving) return;

    final int requiredPoints =
    widget.markType == LoanMarkType.thumb ? 1 : 2;

    if (_points.whereType<Offset>().length < requiredPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया पहले अपना निशान बनाएँ।'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('कृपया पहले अपने खाते में लॉगिन करें।');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final loanRef = FirebaseFirestore.instance
          .collection('loans')
          .doc(widget.loanId);

      final loanSnapshot = await loanRef.get();

      if (!loanSnapshot.exists) {
        throw Exception('Loan record नहीं मिला।');
      }

      final loanData = loanSnapshot.data()!;

      if (loanData['customerId'] != user.uid) {
        throw Exception('आप इस Loan को स्वीकार नहीं कर सकते।');
      }

      if ((loanData['status'] ?? '')
          .toString()
          .toLowerCase() ==
          'closed') {
        throw Exception('Closed Loan स्वीकार नहीं किया जा सकता।');
      }

      if (loanData['customerAcceptanceStatus'] == 'accepted') {
        throw Exception('यह Loan पहले ही स्वीकार किया जा चुका है।');
      }

      // Capture drawing as PNG.
      final renderObject =
      _canvasKey.currentContext?.findRenderObject();

      if (renderObject is! RenderRepaintBoundary) {
        throw Exception('निशान की फोटो तैयार नहीं हो सकी।');
      }

      const double pixelRatio = 1.5;

      final ui.Image image = await renderObject.toImage(
        pixelRatio: pixelRatio,
      );

      final validPoints = _points.whereType<Offset>().toList();

      double minX;
      double maxX;
      double minY;
      double maxY;

      if (widget.markType == LoanMarkType.signature) {
        // Signature की वास्तविक सीमा।
        minX = validPoints
            .map((p) => p.dx)
            .reduce((a, b) => a < b ? a : b);

        maxX = validPoints
            .map((p) => p.dx)
            .reduce((a, b) => a > b ? a : b);

        minY = validPoints
            .map((p) => p.dy)
            .reduce((a, b) => a < b ? a : b);

        maxY = validPoints
            .map((p) => p.dy)
            .reduce((a, b) => a > b ? a : b);

        minX *= pixelRatio;
        maxX *= pixelRatio;
        minY *= pixelRatio;
        maxY *= pixelRatio;
      } else {
        // Thumb impression की वास्तविक सीमा।
        final Offset center = validPoints.first;

        final double logicalWidth = image.width / pixelRatio;
        final double logicalHeight = image.height / pixelRatio;

        final double thumbWidth =
        _thumbWidth.clamp(1.0, logicalWidth).toDouble();

        final double thumbHeight =
        _thumbHeight.clamp(1.0, logicalHeight).toDouble();

        final double left = (center.dx - thumbWidth / 2)
            .clamp(0.0, logicalWidth - thumbWidth)
            .toDouble();

        final double top = (center.dy - thumbHeight / 2)
            .clamp(0.0, logicalHeight - thumbHeight)
            .toDouble();

        minX = left * pixelRatio;
        maxX = (left + thumbWidth) * pixelRatio;
        minY = top * pixelRatio;
        maxY = (top + thumbHeight) * pixelRatio;
      }

      // निशान के चारों तरफ थोड़ी खाली जगह रखें।
      final double padding =
      widget.markType == LoanMarkType.signature ? 30.0 : 8.0;

      final double left = (minX - padding)
          .clamp(0.0, image.width.toDouble())
          .toDouble();

      final double top = (minY - padding)
          .clamp(0.0, image.height.toDouble())
          .toDouble();

      final double right = (maxX + padding)
          .clamp(0.0, image.width.toDouble())
          .toDouble();

      final double bottom = (maxY + padding)
          .clamp(0.0, image.height.toDouble())
          .toDouble();

      final Rect sourceRect = Rect.fromLTRB(
        left,
        top,
        right,
        bottom,
      );

      final int cropWidth = sourceRect.width.ceil().clamp(
        1,
        image.width,
      ).toInt();

      final int cropHeight = sourceRect.height.ceil().clamp(
        1,
        image.height,
      ).toInt();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawImageRect(
        image,
        sourceRect,
        Rect.fromLTWH(
          0,
          0,
          cropWidth.toDouble(),
          cropHeight.toDouble(),
        ),
        Paint(),
      );

      final picture = recorder.endRecording();

      final croppedImage = await picture.toImage(
        cropWidth,
        cropHeight,
      );

      final byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      croppedImage.dispose();
      image.dispose();

      if (byteData == null) {
        throw Exception('निशान की फोटो तैयार नहीं हो सकी।');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Keep image small for Firestore document limit.
      if (pngBytes.length > 250 * 1024) {
        throw Exception(
          'निशान की फोटो बड़ी है। कृपया छोटा निशान बनाएँ और दोबारा Submit करें।',
        );
      }

      final String signatureBase64 = base64Encode(pngBytes);

      final String method =
      widget.markType == LoanMarkType.signature
          ? 'finger_signature'
          : 'thumb_impression';

      // Recheck loan and save acceptance atomically.
      await FirebaseFirestore.instance.runTransaction(
            (transaction) async {
          final latestSnapshot = await transaction.get(loanRef);

          if (!latestSnapshot.exists) {
            throw Exception('Loan record नहीं मिला।');
          }

          final latestData = latestSnapshot.data()!;

          if (latestData['customerId'] != user.uid) {
            throw Exception('आप इस Loan को स्वीकार नहीं कर सकते।');
          }

          if ((latestData['status'] ?? '')
              .toString()
              .toLowerCase() ==
              'closed') {
            throw Exception('यह Loan बंद हो चुका है।');
          }

          if (latestData['customerAcceptanceStatus'] == 'accepted') {
            throw Exception('यह Loan पहले ही स्वीकार किया जा चुका है।');
          }

          transaction.update(loanRef, {
            'customerSignatureBase64': signatureBase64,
            'customerSignatureContentType': 'image/png',
            'customerSigningMethod': method,
            'customerAcceptanceStatus': 'accepted',
            'customerAcceptedBy': user.uid,
            'customerAcceptedAt': FieldValue.serverTimestamp(),
          });
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan सफलतापूर्वक स्वीकार हो गया।'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // CLEAR DRAWING
  // ============================================================

  void _clearDrawing() {
    if (_isSaving) return;

    setState(() {
      _points.clear();

      // Reset thumb size.
      _thumbWidth = 86;
      _thumbHeight = 112;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isThumb =
        widget.markType == LoanMarkType.thumb;

    final Widget markCanvas = CustomPaint(
      painter: _MarkPainter(
        List<Offset?>.from(_points),
        isThumb: isThumb,
        thumbWidth: _thumbWidth,
        thumbHeight: _thumbHeight,
      ),
      child: SizedBox.expand(
        child: Center(
          child: _points.isEmpty
              ? Text(
            isThumb
                ? 'यहाँ अंगूठे का निशान बनाएँ'
                : 'यहाँ हस्ताक्षर करें',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 17,
            ),
          )
              : const SizedBox.shrink(),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const SizedBox(height: 15),

              Text(
                isThumb
                    ? 'नीचे दिए गए बॉक्स में अंगूठे से अपना निशान बनाएँ।'
                    : 'नीचे दिए गए बॉक्स में अपना हस्ताक्षर करें।',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF174B38),
                ),
              ),

              const SizedBox(height: 22),

              // DRAWING AREA
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.green.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: RepaintBoundary(
                      key: _canvasKey,
                      child: Container(
                        color: Colors.white,

                        // Thumb: one stationary touch.
                        // Signature: normal drawing.
                        child: isThumb
                            ? Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) {
                            if (_isSaving || _points.isNotEmpty) {
                              return;
                            }

                            setState(() {
                              _points.add(event.localPosition);

                              _thumbWidth = 86;
                              _thumbHeight = 112;
                            });
                          },
                          child: markCanvas,
                        )
                            : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) {
                            if (_isSaving) return;

                            setState(() {
                              _points.add(details.localPosition);
                            });
                          },
                          onPanUpdate: (details) {
                            if (_isSaving) return;

                            setState(() {
                              _points.add(details.localPosition);
                            });
                          },
                          onPanEnd: (_) {
                            if (_isSaving) return;

                            setState(() {
                              _points.add(null);
                            });
                          },
                          child: markCanvas,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                      _isSaving ? null : _clearDrawing,
                      icon: const Icon(Icons.refresh),
                      label: const Text('दोबारा करें'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                      _isSaving ? null : _submitMark,
                      icon: _isSaving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.check),
                      label: Text(
                        _isSaving
                            ? 'जमा हो रहा है...'
                            : 'Submit',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DRAWING PAINTER
// ============================================================



class _MarkPainter extends CustomPainter {
  final List<Offset?> points;
  final bool isThumb;
  final double thumbWidth;
  final double thumbHeight;

  _MarkPainter(
      this.points, {
        required this.isThumb,
        required this.thumbWidth,
        required this.thumbHeight,
      });

  @override
  void paint(Canvas canvas, Size size) {
    final validPoints = points.whereType<Offset>().toList();
    if (validPoints.isEmpty) return;

    if (isThumb) {
      final center = validPoints.first;

      final double w = thumbWidth.clamp(20.0, size.width).toDouble();
      final double h = thumbHeight.clamp(20.0, size.height).toDouble();

      final double left =
      (center.dx - w / 2).clamp(0.0, size.width - w).toDouble();
      final double top =
      (center.dy - h / 2).clamp(0.0, size.height - h).toDouble();

      final Rect bounds = Rect.fromLTWH(left, top, w, h);

      canvas.save();
      canvas.clipPath(Path()..addOval(bounds));

      // Fingerprint ridges: flowing, curved and slightly irregular.
      const int lineCount = 39;
      const int steps = 150;

      for (int i = 0; i < lineCount; i++) {
        final double row = -0.91 + i * 0.0478;
        final Path ridge = Path();

        bool started = false;

        for (int step = 0; step <= steps; step++) {
          final double t = step / steps;
          final double x = -0.97 + t * 1.94;

          final double edge =
          math.sqrt(math.max(0.0, 1 - x * x));

          final double baseY = row * edge;

          final double distance = x - 0.12;

          final double influence = math.exp(
            -math.pow(distance / 0.48, 2).toDouble(),
          );

          final double curve =
              influence *
                  (0.23 * math.sin(distance * 3.8 + row * 1.5) +
                      0.09 * math.sin(distance * 7.0 - row * 2.0));

          final double wave =
              0.012 * math.sin(x * 12 + i * 0.35) +
                  0.008 * math.sin(x * 21 - i * 0.22);

          final double normalizedY = baseY + curve + wave;

          final double px = left + w * (0.5 + x * 0.48);
          final double py = top + h * (0.5 + normalizedY * 0.48);

          // Small natural breaks in the ink ridges.
          final int gap = (step * 3 + i * 19) % 157;
          final bool isGap = gap == 0 || gap == 1 || gap == 2;

          if (isGap) {
            started = false;
            continue;
          }

          if (!started) {
            ridge.moveTo(px, py);
            started = true;
          } else {
            ridge.lineTo(px, py);
          }
        }

        canvas.drawPath(
          ridge,
          Paint()
            ..color = Colors.black.withOpacity(
              0.78 + (i % 4) * 0.045,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0 + (i % 3) * 0.13
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }

      // Open curved ridges around the fingerprint core.
      final Offset core = Offset(
        left + w * 0.54,
        top + h * 0.64,
      );

      for (int i = 0; i < 13; i++) {
        final Path curve = Path();

        final double rx = w * (0.035 + i * 0.027);
        final double ry = h * (0.025 + i * 0.024);

        for (int step = 0; step <= 120; step++) {
          final double angle =
              -math.pi * 0.12 + (step / 120) * math.pi * 1.62;

          final double irregular =
              1 + 0.025 * math.sin(angle * 4 + i * 0.4);

          final double x =
              core.dx + math.cos(angle) * rx * irregular;

          final double y =
              core.dy + math.sin(angle) * ry * irregular;

          if (step == 0) {
            curve.moveTo(x, y);
          } else {
            curve.lineTo(x, y);
          }
        }

        canvas.drawPath(
          curve,
          Paint()
            ..color = Colors.black.withOpacity(0.82)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.95
            ..strokeCap = StrokeCap.round,
        );
      }

      canvas.restore();
      return;
    }

    // Signature drawing remains unchanged.
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }

    for (final point in points) {
      if (point != null) {
        canvas.drawCircle(
          point,
          1.7,
          Paint()..color = Colors.black,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) {
    return true;
  }
}

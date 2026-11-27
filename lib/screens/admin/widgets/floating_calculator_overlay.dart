
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FloatingCalculatorOverlay extends StatefulWidget {
  final Widget child;

  const FloatingCalculatorOverlay({
    super.key,
    required this.child,
  });

  @override
  State<FloatingCalculatorOverlay> createState() =>
      _FloatingCalculatorOverlayState();
}

class _FloatingCalculatorOverlayState
    extends State<FloatingCalculatorOverlay> {
       bool _isSidenHidden = false;
  double _left = 16;
  double _top = 200;

       bool _isSideHidden = false;
       bool _hideToLeft = false;

  double _popupWidth = 300;
  double _popupHeight = 440;

  bool _positionInitialized = false;
  bool _isOpen = false;
  bool _justCalculated = false;

  String _expression = '0';
  String _result = '0';

  static const Color _green = Color(0xFF168653);
  static const Color _dark = Color(0xFF26332C);
  static const Color _red = Color(0xFFE45B5B);

  bool _isOperator(String value) {
    return ['+', '−', '-', '×', '÷'].contains(value);
  }

  String _format(double value) {
    if (!value.isFinite) return 'Error';
    if (value == 0) return '0';

    if (value.abs() >= 1e12 || value.abs() < 1e-8) {
      return value.toStringAsExponential(6);
    }

    return value
        .toStringAsFixed(8)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _calculate() {
    try {
      final value = _CalculatorParser(_expression).parse();
      _result = _format(value);
    } catch (_) {
      _result = '';
    }
  }

  String _lastNumber() {
    final match = RegExp(r'(\d+\.?\d*|\.\d+)%?$')
        .firstMatch(_expression);
    return match?.group(0) ?? '';
  }

  void _press(String key) {
    setState(() {
      if (key == 'AC') {
        _expression = '0';
        _result = '0';
        _justCalculated = false;
        return;
      }

      if (key == 'DEL') {
        if (_justCalculated) {
          _expression = '0';
          _result = '0';
          _justCalculated = false;
          return;
        }

        if (_expression.length <= 1) {
          _expression = '0';
        } else {
          _expression =
              _expression.substring(0, _expression.length - 1);
        }

        _calculate();
        return;
      }

      if (key == '=') {
        try {
          final value = _CalculatorParser(_expression).parse();
          _expression = _format(value);
          _result = _expression;
          _justCalculated = true;
        } catch (_) {
          _result = 'Error';
        }
        return;
      }

      if (key == '±') {
        _toggleSign();
        _calculate();
        return;
      }

      if (key == '.') {
        if (_justCalculated) {
          _expression = '0.';
          _justCalculated = false;
          _calculate();
          return;
        }

        final last = _lastNumber();
        if (last.contains('.')) return;

        if (_expression == '0') {
          _expression = '0.';
        } else if (_expression == '-0') {
          _expression = '-0.';
        } else if (_expression.isNotEmpty &&
            (_isOperator(_expression.substring(_expression.length - 1)) ||
                _expression.endsWith('('))) {
          _expression += '0.';
        } else {
          _expression += '.';
        }

        _calculate();
        return;
      }

      if (key == '%') {
        if (_justCalculated) {
          _expression += '%';
          _justCalculated = false;
        } else if (_expression.isNotEmpty &&
            (RegExp(r'\d$').hasMatch(_expression) ||
                _expression.endsWith(')'))) {
          _expression += '%';
        }

        _calculate();
        return;
      }

      if (_isOperator(key)) {
        if (_justCalculated) {
          _justCalculated = false;
        }

        if (_expression == '0' && key != '−' && key != '-') {
          return;
        }

        if (_expression.isNotEmpty &&
            _isOperator(_expression.substring(_expression.length - 1))) {
          _expression =
              _expression.substring(0, _expression.length - 1);
        }

        _expression += key;
        _calculate();
        return;
      }

      if (key == '(') {
        if (_justCalculated) {
          _expression = '0';
          _justCalculated = false;
        }

        if (_expression == '0') {
          _expression = '(';
        } else if (_expression.isNotEmpty &&
            (RegExp(r'\d$').hasMatch(_expression) ||
                _expression.endsWith(')') ||
                _expression.endsWith('%'))) {
          _expression += '×(';
        } else {
          _expression += '(';
        }

        _calculate();
        return;
      }

      if (key == ')') {
        if (_expression.isNotEmpty &&
            (RegExp(r'\d$').hasMatch(_expression) ||
                _expression.endsWith(')') ||
                _expression.endsWith('%'))) {
          _expression += ')';
          _calculate();
        }
        return;
      }

      if (key == '00') {
        if (_justCalculated) {
          _expression = '0';
          _justCalculated = false;
        }

        if (_expression == '0') {
          _expression = '0';
        } else if (_expression.isNotEmpty &&
            (_isOperator(_expression.substring(_expression.length - 1)) ||
                _expression.endsWith('('))) {
          _expression += '0';
        } else {
          _expression += '00';
        }

        _calculate();
        return;
      }

      if (RegExp(r'^\d$').hasMatch(key)) {
        if (_justCalculated) {
          _expression = key;
          _justCalculated = false;
        } else if (_expression == '0') {
          _expression = key;
        } else if (_expression == '-0') {
          _expression = '-$key';
        } else {
          _expression += key;
        }

        _calculate();
      }
    });
  }

  void _toggleSign() {
    if (_justCalculated) {
      final value = double.tryParse(_expression);
      if (value != null) {
        _expression = _format(-value);
      }
      _justCalculated = false;
      return;
    }

    final match = RegExp(r'(\d+\.?\d*|\.\d+)(%?)$')
        .firstMatch(_expression);

    if (match == null) {
      if (_expression == '0') {
        _expression = '-0';
      }
      return;
    }

    final number = match.group(1)!;
    final percent = match.group(2) ?? '';
    final start = match.start;
    final before = _expression.substring(0, start);

    final hasUnaryMinus = before.endsWith('-') &&
        (before.length == 1 ||
            _isOperator(before.substring(before.length - 2, before.length - 1)) ||
            before.endsWith('(-'));

    if (hasUnaryMinus) {
      _expression =
          before.substring(0, before.length - 1) + number + percent;
    } else {
      _expression = '$before-$number$percent';
    }
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  Widget _key(
      String label, {
        Color? background,
        Color? foreground,
      }) {
    return Material(
      color: background ?? const Color(0xFFF1F3F1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _press(label),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: label.length > 2 ? 15 : 21,
                  fontWeight: FontWeight.w600,
                  color: foreground ?? _dark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalculator(double width, double height) {
    final keys = [
      ['AC', 'DEL', '(', ')', '÷'],
      ['7', '8', '9', '%', '×'],
      ['4', '5', '6', '±', '−'],
      ['1', '2', '3', '00', '+'],
      ['0', '.', '', '=', ''],
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _left += details.delta.dx;
                    _top += details.delta.dy;
                  });
                },
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  color: const Color(0xFFFCFCFC),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.drag_indicator_rounded,
                        size: 20,
                        color: Color(0xFF9AA39D),
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Calculator',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF69766F),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: _toggle,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 21,
                          color: Color(0xFF78837D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
                child: Container(
                  height: math.max(65.0, height * 0.19),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F4),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          _expression,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF89938D),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(
                          _result.isEmpty ? ' ' : _result,
                          style: TextStyle(
                            fontSize: math.min(28.0, width * 0.10),
                            fontWeight: FontWeight.w700,
                            color: _result == 'Error' ? _red : _dark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 25,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 1.08,
                    ),
                    itemBuilder: (context, index) {
                      final label = keys[index ~/ 5][index % 5];

                      if (label.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final isOperator =
                      ['÷', '×', '−', '+', '%'].contains(label);
                      final isAction =
                      ['AC', 'DEL', '(', ')', '±'].contains(label);
                      final isEqual = label == '=';

                      return _key(
                        label,
                        background: isEqual
                            ? _green
                            : isOperator
                            ? const Color(0xFFEAF5EF)
                            : isAction
                            ? const Color(0xFFFCEBEC)
                            : const Color(0xFFF1F3F1),
                        foreground: isEqual
                            ? Colors.white
                            : isOperator
                            ? _green
                            : isAction
                            ? _red
                            : _dark,
                      );
                    },
                  ),
                ),
              ),

              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _popupWidth = (_popupWidth + details.delta.dx)
                        .clamp(260.0, 420.0)
                        .toDouble();

                    _popupHeight = (_popupHeight + details.delta.dy)
                        .clamp(360.0, 620.0)
                        .toDouble();
                  });
                },
                child: Container(
                  height: 22,
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.only(right: 8, bottom: 5),
                  child: const Icon(
                    Icons.open_in_full_rounded,
                    size: 15,
                    color: Color(0xFF9AA39D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        if (!width.isFinite ||
            !height.isFinite ||
            width < 80 ||
            height < 80) {
          return widget.child;
        }

        const iconSize = 56.0;

        if (!_positionInitialized) {
          _left = math.max(8.0, width - iconSize - 16);
          _top = math.max(8.0, height - iconSize - 100);
          _positionInitialized = true;
        }

        _left = _left.clamp(0.0, math.max(0.0, width - iconSize));
        _top = _top.clamp(0.0, math.max(0.0, height - iconSize));

        final popupWidth =
        math.min(_popupWidth, math.max(240.0, width - 16));
        final popupHeight =
        math.min(_popupHeight, math.max(320.0, height - 16));

        final popupLeft = _left
            .clamp(8.0, math.max(8.0, width - popupWidth - 8))
            .toDouble();

        final popupTop = (_top > popupHeight + 20
            ? _top - popupHeight - 12
            : _top + iconSize + 10)
            .clamp(8.0, math.max(8.0, height - popupHeight - 8))
            .toDouble();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,

            if (_isOpen)
              Positioned(
                left: popupLeft,
                top: popupTop,
                width: popupWidth,
                height: popupHeight,
                child: _buildCalculator(
                  popupWidth,
                  popupHeight,
                ),
              ),


            Positioned(
              left: _isSideHidden
                  ? (_hideToLeft ? -iconSize * 0.55 : width - iconSize * 0.55)
                  : _left,
              top: _top,
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (_isSideHidden) return;

                  setState(() {
                    _left = (_left + details.delta.dx)
                        .clamp(0.0, math.max(0.0, width - iconSize))
                        .toDouble();

                    _top = (_top + details.delta.dy)
                        .clamp(0.0, math.max(0.0, height - iconSize))
                        .toDouble();
                  });
                },

                onPanEnd: (details) {
                  if (_isSideHidden) return;

                  final leftEdge = _left;
                  final rightEdge = width - iconSize - _left;

                  // Icon ko screen ke side par le jaakar
                  // chhodne par hide kar do.
                  if (leftEdge <= 20 || rightEdge <= 20) {
                    setState(() {
                      _hideToLeft = leftEdge <= rightEdge;
                      _isSideHidden = true;
                    });
                  }
                },

                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withOpacity(0.30),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (_isSideHidden) {
                          setState(() {
                            _isSideHidden = false;
                          });
                        } else {
                          _toggle();
                        }
                      },
                      child: const Icon(
                        Icons.calculate_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          ],
        );
      },
    );
  }
}

class _CalculatorParser {
  final String input;
  int position = 0;

  _CalculatorParser(this.input);

  double parse() {
    final value = _expression();

    if (position != input.length) {
      throw const FormatException('Invalid expression');
    }

    if (!value.isFinite) {
      throw const FormatException('Invalid result');
    }

    return value;
  }

  double _expression() {
    var value = _term();

    while (position < input.length) {
      final operator = input[position];

      if (operator == '+') {
        position++;
        value += _term();
      } else if (operator == '−' || operator == '-') {
        position++;
        value -= _term();
      } else {
        break;
      }
    }

    return value;
  }

  double _term() {
    var value = _unary();

    while (position < input.length) {
      final operator = input[position];

      if (operator == '×' || operator == '*') {
        position++;
        value *= _unary();
      } else if (operator == '÷' || operator == '/') {
        position++;
        final divisor = _unary();

        if (divisor == 0) {
          throw const FormatException('Division by zero');
        }

        value /= divisor;
      } else {
        break;
      }
    }

    return value;
  }

  double _unary() {
    if (position < input.length &&
        (input[position] == '-' || input[position] == '−')) {
      position++;
      return -_unary();
    }

    if (position < input.length && input[position] == '+') {
      position++;
      return _unary();
    }

    return _postfix();
  }

  double _postfix() {
    var value = _primary();

    while (position < input.length && input[position] == '%') {
      value /= 100;
      position++;
    }

    return value;
  }

  double _primary() {
    if (position >= input.length) {
      throw const FormatException('Invalid number');
    }

    if (input[position] == '(') {
      position++;
      final value = _expression();

      if (position >= input.length || input[position] != ')') {
        throw const FormatException('Missing parenthesis');
      }

      position++;
      return value;
    }

    final start = position;

    while (position < input.length &&
        RegExp(r'[0-9.]').hasMatch(input[position])) {
      position++;
    }

    if (start == position) {
      throw const FormatException('Invalid number');
    }

    final number = input.substring(start, position);

    if (number.split('.').length > 2) {
      throw const FormatException('Invalid decimal');
    }

    return double.parse(number);
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class CalculatorTab extends StatefulWidget {
  const CalculatorTab({super.key});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  // ------------------------------------------------------------
  // Controllers
  // ------------------------------------------------------------

  final amountController = TextEditingController();
  final rateController = TextEditingController();

  // Default = Compound Interest
  bool isCompound = true;

  DateTime startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  DateTime closingDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  CalculationResult? result;

  // ------------------------------------------------------------
  // Dispose
  // ------------------------------------------------------------

  @override
  void dispose() {
    amountController.dispose();
    rateController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Date Helpers
  // ------------------------------------------------------------

  DateTime _addYears(DateTime date, int years) {
    final targetYear = date.year + years;

    final lastDayOfMonth =
        DateTime(targetYear, date.month + 1, 0).day;

    final day =
    date.day > lastDayOfMonth ? lastDayOfMonth : date.day;

    return DateTime(
      targetYear,
      date.month,
      day,
    );
  }

  DateTime _addMonths(DateTime date, int months) {
    final totalMonths =
        date.year * 12 + (date.month - 1) + months;

    final year = totalMonths ~/ 12;
    final month = (totalMonths % 12) + 1;

    final lastDayOfMonth =
        DateTime(year, month + 1, 0).day;

    final day =
    date.day > lastDayOfMonth ? lastDayOfMonth : date.day;

    return DateTime(
      year,
      month,
      day,
    );
  }

  DurationParts _getDuration(
      DateTime start,
      DateTime end,
      ) {
    if (end.isBefore(start)) {
      return const DurationParts(
        years: 0,
        months: 0,
        days: 0,
      );
    }

    int years = 0;
    DateTime cursor = start;

    while (true) {
      final next = _addYears(cursor, 1);

      if (next.isAfter(end)) {
        break;
      }

      years++;
      cursor = next;
    }

    int months = 0;

    while (true) {
      final next = _addMonths(cursor, 1);

      if (next.isAfter(end)) {
        break;
      }

      months++;
      cursor = next;
    }

    final days = end.difference(cursor).inDays;

    return DurationParts(
      years: years,
      months: months,
      days: days,
    );
  }

  // ------------------------------------------------------------
  // Date Picker
  // ------------------------------------------------------------

  Future<void> selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      startDate = picked;

      if (closingDate.isBefore(startDate)) {
        closingDate = startDate;
      }

      result = null;
    });
  }

  Future<void> selectClosingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: closingDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      closingDate = picked;
      result = null;
    });
  }

  // Calendar icon = full calendar.
  Future<void> selectFullStartDate() => selectStartDate();

  Future<void> selectFullClosingDate() => selectClosingDate();

  // Day / Month / Year boxes open a number-only popup.
  Future<int?> _showNumberPicker({
    required String title,
    required int value,
    required int min,
    required int max,
  }) async {
    int selected = value.clamp(min, max).toInt();

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              contentPadding:
              const EdgeInsets.fromLTRB(8, 12, 8, 8),
              content: SizedBox(
                width: 330,
                height: 560,
                child: Column(
                  children: [
                    if (title.isNotEmpty)
                      Padding(
                        padding:
                        const EdgeInsets.only(bottom: 8),
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: max - min + 1,
                        itemBuilder: (context, index) {
                          final number = min + index;

                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selected = number;
                              });

                              Navigator.pop(
                                dialogContext,
                                number,
                              );
                            },
                            child: SizedBox(
                              height: 72,
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  Icon(
                                    selected == number
                                        ? Icons
                                        .radio_button_checked
                                        : Icons
                                        .radio_button_unchecked,
                                    color:
                                    selected == number
                                        ? Colors.teal
                                        : Colors.grey,
                                    size: 36,
                                  ),
                                  const Spacer(),
                                  Text(
                                    number
                                        .toString()
                                        .padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight:
                                      FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 28),
                                ],
                              ),
                            ),
                          );
                        },
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
  }

  Future<void> selectStartDay() async {
    final maxDay =
        DateTime(startDate.year, startDate.month + 1, 0).day;

    final picked = await _showNumberPicker(
      title: 'Day',
      value: startDate.day,
      min: 1,
      max: maxDay,
    );

    if (picked == null) return;

    setState(() {
      startDate =
          DateTime(startDate.year, startDate.month, picked);

      if (closingDate.isBefore(startDate)) {
        closingDate = startDate;
      }

      result = null;
    });
  }

  Future<void> selectStartMonth() async {
    final picked = await _showNumberPicker(
      title: 'Month',
      value: startDate.month,
      min: 1,
      max: 12,
    );

    if (picked == null) return;

    final maxDay =
        DateTime(startDate.year, picked + 1, 0).day;

    final day =
    startDate.day > maxDay ? maxDay : startDate.day;

    setState(() {
      startDate =
          DateTime(startDate.year, picked, day);

      if (closingDate.isBefore(startDate)) {
        closingDate = startDate;
      }

      result = null;
    });
  }

  Future<void> selectStartYear() async {
    final picked = await _showNumberPicker(
      title: 'Year',
      value: startDate.year,
      min: 1900,
      max: 2100,
    );

    if (picked == null) return;

    final maxDay =
        DateTime(picked, startDate.month + 1, 0).day;

    final day =
    startDate.day > maxDay ? maxDay : startDate.day;

    setState(() {
      startDate =
          DateTime(picked, startDate.month, day);

      if (closingDate.isBefore(startDate)) {
        closingDate = startDate;
      }

      result = null;
    });
  }

  Future<void> selectClosingDay() async {
    final maxDay =
        DateTime(
          closingDate.year,
          closingDate.month + 1,
          0,
        ).day;

    final picked = await _showNumberPicker(
      title: 'Day',
      value: closingDate.day,
      min: 1,
      max: maxDay,
    );

    if (picked == null) return;

    setState(() {
      closingDate =
          DateTime(
            closingDate.year,
            closingDate.month,
            picked,
          );

      result = null;
    });
  }

  Future<void> selectClosingMonth() async {
    final picked = await _showNumberPicker(
      title: 'Month',
      value: closingDate.month,
      min: 1,
      max: 12,
    );

    if (picked == null) return;

    final maxDay =
        DateTime(closingDate.year, picked + 1, 0).day;

    final day =
    closingDate.day > maxDay
        ? maxDay
        : closingDate.day;

    setState(() {
      closingDate =
          DateTime(closingDate.year, picked, day);

      result = null;
    });
  }

  Future<void> selectClosingYear() async {
    final picked = await _showNumberPicker(
      title: 'Year',
      value: closingDate.year,
      min: 1900,
      max: 2100,
    );

    if (picked == null) return;

    final maxDay =
        DateTime(picked, closingDate.month + 1, 0).day;

    final day =
    closingDate.day > maxDay
        ? maxDay
        : closingDate.day;

    setState(() {
      closingDate =
          DateTime(picked, closingDate.month, day);

      result = null;
    });
  }

  // ------------------------------------------------------------
  // Calculate
  // ------------------------------------------------------------

  void calculate() {
    FocusScope.of(context).unfocus();

    final amount =
    double.tryParse(amountController.text.trim());

    final rate =
    double.tryParse(rateController.text.trim());

    if (amount == null || amount <= 0) {
      _showMessage(
        'Please enter a valid amount',
      );
      return;
    }

    if (rate == null || rate < 0) {
      _showMessage(
        'Please enter a valid interest rate',
      );
      return;
    }

    if (closingDate.isBefore(startDate)) {
      _showMessage(
        'Closing date cannot be before opening date',
      );
      return;
    }

    final duration = _getDuration(
      startDate,
      closingDate,
    );

    final years = duration.years;
    final months = duration.months;
    final days = duration.days;

    // Rate is RatePM = Rate Per Month.
    // One month = 30 days for the remaining-day calculation.

    final monthlyRate = rate / 100;

    double interest;
    double total;

    double yearlyInterest = 0;
    double monthlyInterest = 0;
    double dailyInterest = 0;

    // ----------------------------------------------------------
    // SIMPLE INTEREST
    // ----------------------------------------------------------
    // RatePM is applied to the original principal throughout
    // the complete duration.
    // ----------------------------------------------------------

    if (!isCompound) {
      yearlyInterest =
          amount * monthlyRate * (years * 12);

      monthlyInterest =
          amount * monthlyRate * months;

      dailyInterest =
          amount * monthlyRate * (days / 30.0);

      interest =
          yearlyInterest +
              monthlyInterest +
              dailyInterest;

      total = amount + interest;
    }

    // ----------------------------------------------------------
    // YEARLY COMPOUND INTEREST
    // ----------------------------------------------------------
    //
    // IMPORTANT RULE:
    //
    // RatePM = Rate Per Month.
    //
    // Compound interest happens ONLY when a COMPLETE YEAR
    // is finished.
    //
    // Example:
    //
    // 2 Years 1 Month 12 Days
    //
    // Year 1:
    // Interest is calculated and added to principal.
    //
    // Year 2:
    // Interest is calculated on the new principal and
    // added again.
    //
    // Remaining 1 Month + 12 Days:
    // NO new compounding.
    //
    // Both remaining month and day interest are calculated
    // from the amount after the 2 complete years.
    //
    // A third compounding happens ONLY if a COMPLETE
    // third year exists.
    //
    // 30 Days = 1 Month.
    // ----------------------------------------------------------

    else {
      // RatePM -> yearly rate.
      final annualRate = monthlyRate * 12;

      // Principal used for yearly compounding.
      double currentAmount = amount;

      // --------------------------------------------------------
      // COMPLETE YEARS ONLY
      // --------------------------------------------------------
      //
      // Each completed year compounds exactly once.
      // The resulting amount becomes the principal for
      // the next complete year.
      // --------------------------------------------------------

      for (int year = 1; year <= years; year++) {
        final yearInterest =
            currentAmount * annualRate;

        yearlyInterest += yearInterest;

        // Compound only after the complete year.
        currentAmount += yearInterest;
      }

      // --------------------------------------------------------
      // REMAINING MONTHS
      // --------------------------------------------------------
      //
      // Remaining months do NOT compound.
      // They use the amount after the last complete year.
      // --------------------------------------------------------

      final remainingMonthsInterest =
          currentAmount *
              monthlyRate *
              months;

      // --------------------------------------------------------
      // REMAINING DAYS
      // --------------------------------------------------------
      //
      // Remaining days also use the SAME amount after the
      // last complete year.
      //
      // Month interest is NOT added to currentAmount before
      // calculating day interest.
      //
      // Therefore:
      //
      // 2 Years + 1 Month + 12 Days
      //
      // = 2 yearly compounds
      // + 1 month simple interest
      // + 12 day simple interest
      //
      // No third compound occurs.
      // --------------------------------------------------------

      final remainingDaysInterest =
          currentAmount *
              monthlyRate *
              (days / 30.0);

      monthlyInterest =
          remainingMonthsInterest;

      dailyInterest =
          remainingDaysInterest;

      // Add the remaining simple-interest portions.
      currentAmount +=
          remainingMonthsInterest +
              remainingDaysInterest;

      total = currentAmount;

      interest = total - amount;
    }

    setState(() {
      result = CalculationResult(
        principal: amount,
        interest: interest,
        total: total,
        years: years,
        months: months,
        days: days,
        yearlyInterest: yearlyInterest,
        monthlyInterest: monthlyInterest,
        dailyInterest: dailyInterest,
        isCompound: isCompound,
        rate: rate,
        startDate: startDate,
        closingDate: closingDate,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && result != null) {
        _showCalculationPopup();
      }
    });
  }

  void _showCalculationPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CalculationPopup(
          result: result!,
          onSave: saveResult,
          onShare: shareResult,
        );
      },
    );
  }

  double _pow(
      double base,
      int exponent,
      ) {
    double answer = 1;

    for (int i = 0; i < exponent; i++) {
      answer *= base;
    }

    return answer;
  }

  // ------------------------------------------------------------
  // Save History
  // ------------------------------------------------------------

  Future<void> saveResult() async {
    if (result == null) {
      _showMessage('Please calculate first');
      return;
    }

    final nameController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Save Calculation',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Person Name *',
              hintText: 'Enter person name',
              helperText: '* Optional',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      nameController.dispose();
      return;
    }

    final name = nameController.text.trim();
    nameController.dispose();

    final savedResult = result!.copyWith(
      personName: name,
      savedAt: DateTime.now(),
    );

    final prefs =
    await SharedPreferences.getInstance();

    final oldHistory =
        prefs.getStringList('interest_history') ?? [];

    oldHistory.insert(
      0,
      jsonEncode(savedResult.toJson()),
    );

    await prefs.setStringList(
      'interest_history',
      oldHistory,
    );

    if (!mounted) return;

    _showMessage(
      'Calculation saved to History',
    );
  }

  // ------------------------------------------------------------
  // History
  // ------------------------------------------------------------

  Future<void> openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const InterestHistoryScreen(),
      ),
    );
  }

  // ------------------------------------------------------------
  // Share
  // ------------------------------------------------------------

  Future<void> shareResult() async {
    if (result == null) {
      _showMessage(
        'Please calculate first',
      );
      return;
    }

    final r = result!;

    final text = '''
Interest Calculator

${r.isCompound ? 'Compound Interest' : 'Simple Interest'}

${formatDate(r.startDate)} TO ${formatDate(r.closingDate)}

Duration: ${r.years} Years ${r.months} Months ${r.days} Days

Principal Amount: ${formatMoney(r.principal)}

${r.isCompound ? 'Compound Interest' : 'Simple Interest'}: ${formatMoney(r.interest)}

Total Amount: ${formatMoney(r.total)}

RatePM: ${r.rate.toStringAsFixed(2)}% Per Month
''';

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Interest Calculation',
      ),
    );
  }

  // ------------------------------------------------------------
  // Message
  // ------------------------------------------------------------

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ------------------------------------------------------------
  // Format Date
  // ------------------------------------------------------------

  String formatDate(DateTime date) {
    final d =
    date.day.toString().padLeft(2, '0');

    final m =
    date.month.toString().padLeft(2, '0');

    return '$d-$m-${date.year}';
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // CalculatorTab is also used inside the User Dashboard.
    // Material is required by InkWell/InkResponse widgets used by
    // the calculator date boxes and buttons.
    return Material(
      color: const Color(0xffeeeeee),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              12,
              10,
              12,
              24,
            ),
            child: Column(
              children: [
                // ------------------------------------------------
                // Closing Date Card
                // ------------------------------------------------

                _buildClosingDateCard(),

                const SizedBox(height: 10),

                // ------------------------------------------------
                // Interest Card
                // ------------------------------------------------

                _buildInterestCard(),

                const SizedBox(height: 10),

                // ------------------------------------------------
                // Start Date Card
                // ------------------------------------------------

                _buildStartDateCard(),

                const SizedBox(height: 14),

                // ------------------------------------------------
                // Calculate Button
                // ------------------------------------------------

                _blackButton(
                  title: 'CALCULATE NOW',
                  onPressed: calculate,
                ),

                const SizedBox(height: 14),

                // ------------------------------------------------
                // History Button
                // ------------------------------------------------

                _blackButton(
                  title: 'HISTORY',
                  onPressed: openHistory,
                ),

                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Closing Date Card
  // ------------------------------------------------------------

  Widget _buildClosingDateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        12,
        14,
        12,
        14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            offset: Offset(0, 3),
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Today { Closing Date }',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              InkWell(
                onTap: selectFullClosingDate,
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 60,
                  height: 60,
                  child: Icon(
                    Icons.calendar_month,
                    size: 52,
                  ),
                ),
              ),

              Expanded(
                child: _dateBox(
                  closingDate.day,
                  'Day',
                  Colors.red,
                  selectClosingDay,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _dateBox(
                  closingDate.month,
                  'Month',
                  Colors.red,
                  selectClosingMonth,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _dateBox(
                  closingDate.year,
                  'Year',
                  Colors.red,
                  selectClosingYear,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Interest Card
  // ------------------------------------------------------------

  Widget _buildInterestCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            offset: Offset(0, 3),
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isCompound
                      ? 'Compound Interest'
                      : 'Simple Interest',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: isCompound
                        ? Colors.green
                        : Colors.blue,
                  ),
                ),
              ),

              Switch(
                value: isCompound,
                activeThumbColor: Colors.green,
                inactiveThumbColor: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    isCompound = value;
                    result = null;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _inputBox(
                  controller: amountController,
                  label: 'Amount',
                  hint: '10,000',
                  keyboardType:
                  const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: _inputBox(
                  controller: rateController,
                  label: 'RatePM',
                  hint: '10',
                  showPercent: true,
                  keyboardType:
                  const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            isCompound
                ? 'Compounding: Yearly • RatePM'
                : 'Interest: Simple',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Start Date Card
  // ------------------------------------------------------------

  Widget _buildStartDateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        12,
        14,
        12,
        14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            offset: Offset(0, 3),
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Start { Opening Date }',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              InkWell(
                onTap: selectFullStartDate,
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 60,
                  height: 60,
                  child: Icon(
                    Icons.calendar_month,
                    size: 52,
                    color: Colors.green,
                  ),
                ),
              ),

              Expanded(
                child: _dateBox(
                  startDate.day,
                  'Day',
                  Colors.green,
                  selectStartDay,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _dateBox(
                  startDate.month,
                  'Month',
                  Colors.green,
                  selectStartMonth,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _dateBox(
                  startDate.year,
                  'Year',
                  Colors.green,
                  selectStartYear,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Date Box
  // ------------------------------------------------------------

  Widget _dateBox(
      int value,
      String label,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade400,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Input Box
  // ------------------------------------------------------------

  Widget _inputBox({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
    bool showPercent = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: showPercent ? '%' : null,
        suffixStyle: showPercent
            ? const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        )
            : null,
        labelStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.grey,
            width: 1.5,
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.blue,
            width: 2,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Black Button
  // ------------------------------------------------------------

  Widget _blackButton({
    required String title,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Result Card
  // ------------------------------------------------------------

  Widget _buildResultCard() {
    final r = result!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            offset: Offset(0, 3),
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _durationItem(
                  r.days,
                  'Days',
                ),
              ),
              Expanded(
                child: _durationItem(
                  r.months,
                  'Months',
                ),
              ),
              Expanded(
                child: _durationItem(
                  r.years,
                  'Years',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Divider(),

          const SizedBox(height: 10),

          _resultRow(
            'Principal Amount',
            formatMoney(r.principal),
            Colors.green,
          ),

          const SizedBox(height: 20),

          _resultRow(
            r.isCompound
                ? 'Compound Interest'
                : 'Simple Interest',
            formatMoney(r.interest),
            Colors.blue,
          ),

          const SizedBox(height: 10),

          Text(
            '{ Y. ${formatMoney(r.yearlyInterest)} } + '
                '{ M. ${formatMoney(r.monthlyInterest)} } + '
                '{ D. ${formatMoney(r.dailyInterest)} }',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 18),

          const Divider(),

          const SizedBox(height: 10),

          _resultRow(
            'Total Amount',
            formatMoney(r.total),
            Colors.red,
            large: true,
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _smallBlackButton(
                  title: 'SAVE',
                  onPressed: saveResult,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _smallBlackButton(
                  title: 'SHARE',
                  onPressed: shareResult,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _durationItem(
      int value,
      String label,
      ) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _resultRow(
      String title,
      String value,
      Color color, {
        bool large = false,
      }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: large ? 26 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 30 : 27,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _smallBlackButton({
    required String title,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// CALCULATION POPUP
// ==================================================================

class _CalculationPopup extends StatelessWidget {
  final CalculationResult result;
  final Future<void> Function() onSave;
  final Future<void> Function() onShare;

  const _CalculationPopup({
    required this.result,
    required this.onSave,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height:
      MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding:
        const EdgeInsets.fromLTRB(
          18,
          14,
          18,
          28,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius:
                  BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Text(
                    result.isCompound
                        ? 'Compound Interest'
                        : 'Simple Interest',
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              '${formatDate(result.startDate)} TO ${formatDate(result.closingDate)}',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Duration – ${result.years.toString().padLeft(2, '0')} Years ${result.months.toString().padLeft(2, '0')} Months ${result.days.toString().padLeft(2, '0')} Days',
              style: const TextStyle(
                fontSize: 17,
              ),
            ),

            const Divider(height: 28),

            _row(
              'Principal Amount:',
              formatMoney(result.principal),
              Colors.green,
            ),

            const SizedBox(height: 14),

            _row(
              result.isCompound
                  ? 'Compound Interest:'
                  : 'Simple Interest:',
              formatMoney(result.interest),
              Colors.blue,
            ),

            const SizedBox(height: 8),

            Text(
              '{ Y. ${formatMoney(result.yearlyInterest)} } + '
                  '{ M. ${formatMoney(result.monthlyInterest)} } + '
                  '{ D. ${formatMoney(result.dailyInterest)} }',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(height: 28),

            _row(
              'Total Amount',
              formatMoney(result.total),
              Colors.red,
              large: true,
            ),

            const SizedBox(height: 12),

            Text(
              'Rate: ${result.rate.toStringAsFixed(2)}% Per Month',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _button(
                    'SAVE',
                    onSave,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _button(
                    'SHARE',
                    onShare,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
      String title,
      String value,
      Color color, {
        bool large = false,
      }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: large ? 25 : 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 29 : 26,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _button(
      String title,
      Future<void> Function() action,
      ) {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: () async => action(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(14),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// DURATION PARTS
// ==================================================================

class DurationParts {
  final int years;
  final int months;
  final int days;

  const DurationParts({
    required this.years,
    required this.months,
    required this.days,
  });
}

// ==================================================================
// CALCULATION RESULT
// ==================================================================

class CalculationResult {
  final double principal;
  final double interest;
  final double total;

  final int years;
  final int months;
  final int days;

  final double yearlyInterest;
  final double monthlyInterest;
  final double dailyInterest;

  final bool isCompound;
  final double rate;

  final DateTime startDate;
  final DateTime closingDate;
  final String personName;
  final DateTime? savedAt;

  CalculationResult({
    required this.principal,
    required this.interest,
    required this.total,
    required this.years,
    required this.months,
    required this.days,
    required this.yearlyInterest,
    required this.monthlyInterest,
    required this.dailyInterest,
    required this.isCompound,
    required this.rate,
    required this.startDate,
    required this.closingDate,
    this.personName = '',
    this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'principal': principal,
      'interest': interest,
      'total': total,
      'years': years,
      'months': months,
      'days': days,
      'yearlyInterest': yearlyInterest,
      'monthlyInterest': monthlyInterest,
      'dailyInterest': dailyInterest,
      'isCompound': isCompound,
      'rate': rate,
      'startDate':
      startDate.toIso8601String(),
      'closingDate':
      closingDate.toIso8601String(),
      'personName': personName,
      'savedAt':
      (savedAt ?? DateTime.now())
          .toIso8601String(),
    };
  }

  factory CalculationResult.fromJson(
      Map<String, dynamic> json,
      ) {
    return CalculationResult(
      principal:
      (json['principal'] as num).toDouble(),
      interest:
      (json['interest'] as num).toDouble(),
      total:
      (json['total'] as num).toDouble(),
      years:
      (json['years'] as num).toInt(),
      months:
      (json['months'] as num).toInt(),
      days:
      (json['days'] as num).toInt(),
      yearlyInterest:
      (json['yearlyInterest'] as num)
          .toDouble(),
      monthlyInterest:
      (json['monthlyInterest'] as num)
          .toDouble(),
      dailyInterest:
      (json['dailyInterest'] as num)
          .toDouble(),
      isCompound:
      json['isCompound'] as bool,
      rate:
      (json['rate'] as num).toDouble(),
      startDate:
      DateTime.parse(json['startDate']),
      closingDate:
      DateTime.parse(json['closingDate']),
      personName:
      (json['personName'] ?? '').toString(),
      savedAt: json['savedAt'] != null
          ? DateTime.tryParse(
        json['savedAt'].toString(),
      )
          : null,
    );
  }

  CalculationResult copyWith({
    String? personName,
    DateTime? savedAt,
  }) {
    return CalculationResult(
      principal: principal,
      interest: interest,
      total: total,
      years: years,
      months: months,
      days: days,
      yearlyInterest: yearlyInterest,
      monthlyInterest: monthlyInterest,
      dailyInterest: dailyInterest,
      isCompound: isCompound,
      rate: rate,
      startDate: startDate,
      closingDate: closingDate,
      personName:
      personName ?? this.personName,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}

// ==================================================================
// HISTORY SCREEN
// ==================================================================

class InterestHistoryScreen extends StatefulWidget {
  const InterestHistoryScreen({
    super.key,
  });

  @override
  State<InterestHistoryScreen> createState() =>
      _InterestHistoryScreenState();
}

class _InterestHistoryScreenState
    extends State<InterestHistoryScreen> {
  List<CalculationResult> history = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  // ------------------------------------------------------------
  // Load History
  // ------------------------------------------------------------

  Future<void> loadHistory() async {
    final prefs =
    await SharedPreferences.getInstance();

    final list =
        prefs.getStringList('interest_history') ?? [];

    final loaded =
    <CalculationResult>[];

    for (final item in list) {
      try {
        final json =
        jsonDecode(item)
        as Map<String, dynamic>;

        loaded.add(
          CalculationResult.fromJson(json),
        );
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      history = loaded;
    });
  }

  // ------------------------------------------------------------
  // Delete One
  // ------------------------------------------------------------

  Future<void> deleteOne(int index) async {
    final prefs =
    await SharedPreferences.getInstance();

    final list =
        prefs.getStringList('interest_history') ?? [];

    if (index >= 0 && index < list.length) {
      list.removeAt(index);

      await prefs.setStringList(
        'interest_history',
        list,
      );
    }

    await loadHistory();
  }

  // ------------------------------------------------------------
  // Clear All
  // ------------------------------------------------------------

  Future<void> clearAll() async {
    if (history.isEmpty) return;

    final confirm =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Clear History?',
          ),
          content: const Text(
            'All saved calculations will be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final prefs =
    await SharedPreferences.getInstance();

    await prefs.remove(
      'interest_history',
    );

    if (!mounted) return;

    setState(() {
      history.clear();
    });
  }

  // ------------------------------------------------------------
  // Share History Item
  // ------------------------------------------------------------

  Future<void> shareHistory(
      CalculationResult r,
      ) async {
    final text = '''
Interest Calculator

${r.isCompound ? 'Compound Interest' : 'Simple Interest'}

${formatDate(r.startDate)} TO ${formatDate(r.closingDate)}

Duration:
${r.years} Years ${r.months} Months ${r.days} Days

Principal Amount:
${formatMoney(r.principal)}

${r.isCompound ? 'Compound Interest' : 'Simple Interest'}:
${formatMoney(r.interest)}

Total Amount:
${formatMoney(r.total)}

Rate:
${r.rate.toStringAsFixed(2)}% Per Month
''';

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Interest Calculation',
      ),
    );
  }

  // ------------------------------------------------------------
  // Open Detail
  // ------------------------------------------------------------

  void openDetail(
      CalculationResult r,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _HistoryDetailSheet(
          result: r,
        );
      },
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xffeeeeee),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            size: 32,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete,
              size: 30,
            ),
            onPressed: clearAll,
          ),
        ],
      ),
      body: history.isEmpty
          ? const Center(
        child: Text(
          'No saved calculations',
          style: TextStyle(
            fontSize: 20,
            color: Colors.grey,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      )
          : ListView.builder(
        padding:
        const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder:
            (context, index) {
          final item =
          history[index];

          return _historyCard(
            item,
            index,
          );
        },
      ),
    );
  }

  Widget _historyCard(
      CalculationResult r,
      int index,
      ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            offset: Offset(0, 3),
            color: Colors.black12,
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          openDetail(r);
        },
        borderRadius:
        BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${index + 1}. ₹ ${formatMoney(r.principal)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.blue,
                      size: 30,
                    ),
                    onPressed: () {
                      shareHistory(r);
                    },
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 30,
                    ),
                    onPressed: () {
                      deleteOne(index);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 4),

              if (r.personName.isNotEmpty)
                Text(
                  r.personName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

              if (r.personName.isNotEmpty)
                const SizedBox(height: 4),

              Text(
                'Saved calculation',
                style: TextStyle(
                  fontSize: 17,
                  color:
                  Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                '${formatDate(r.startDate)} TO '
                    '${formatDate(r.closingDate)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                r.isCompound
                    ? 'Compound Interest • Yearly'
                    : 'Simple Interest',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.w600,
                  color: r.isCompound
                      ? Colors.green
                      : Colors.blue,
                ),
              ),

              if (r.savedAt != null)
                Padding(
                  padding:
                  const EdgeInsets.only(
                    top: 6,
                  ),
                  child: Text(
                    formatDateTime(
                      r.savedAt!,
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      color:
                      Colors.grey.shade700,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              Text(
                'Tap to view full details',
                style: TextStyle(
                  color:
                  Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// HISTORY DETAIL SHEET
// ==================================================================

class _HistoryDetailSheet
    extends StatelessWidget {
  final CalculationResult result;

  const _HistoryDetailSheet({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height:
      MediaQuery.of(context).size.height *
          0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding:
        const EdgeInsets.fromLTRB(
          20,
          22,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color:
                  Colors.grey.shade400,
                  borderRadius:
                  BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (result.personName.isNotEmpty)
              Text(
                result.personName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

            if (result.personName.isNotEmpty)
              const SizedBox(height: 8),

            Text(
              result.isCompound
                  ? 'Compound Interest'
                  : 'Simple Interest',
              style: const TextStyle(
                fontSize: 27,
                fontWeight:
                FontWeight.bold,
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              '${formatDate(result.startDate)} TO '
                  '${formatDate(result.closingDate)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Duration – '
                  '${result.years.toString().padLeft(2, '0')} '
                  'Years '
                  '${result.months.toString().padLeft(2, '0')} '
                  'Months '
                  '${result.days.toString().padLeft(2, '0')} '
                  'Days',
              style: const TextStyle(
                fontSize: 18,
              ),
            ),

            const Divider(
              height: 30,
            ),

            _detailRow(
              'Principal Amount:',
              formatMoney(result.principal),
              Colors.green,
            ),

            const SizedBox(height: 15),

            _detailRow(
              result.isCompound
                  ? 'Compound Interest:'
                  : 'Simple Interest:',
              formatMoney(result.interest),
              Colors.blue,
            ),

            const SizedBox(height: 10),

            Text(
              '{ Y. ${formatMoney(result.yearlyInterest)} } + '
                  '{ M. ${formatMoney(result.monthlyInterest)} } + '
                  '{ D. ${formatMoney(result.dailyInterest)} }',
              style: const TextStyle(
                fontSize: 16,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const Divider(
              height: 30,
            ),

            _detailRow(
              'Total Amount',
              formatMoney(result.total),
              Colors.red,
              large: true,
            ),

            const SizedBox(height: 18),

            Text(
              'Rate: ${result.rate.toStringAsFixed(2)}% Per Month',
              style: const TextStyle(
                fontSize: 17,
                color: Colors.grey,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            if (result.savedAt != null)
              Padding(
                padding:
                const EdgeInsets.only(
                  top: 10,
                ),
                child: Text(
                  'Calculated on: ${formatDateTime(result.savedAt!)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      String title,
      String value,
      Color color, {
        bool large = false,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: large ? 25 : 21,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 29 : 26,
            fontWeight:
            FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ==================================================================
// NUMBER FORMAT
// ==================================================================

String formatMoney(double value) {
  final rounded = value.round();

  final negative = rounded < 0;

  final digits =
  rounded.abs().toString();

  String result = '';

  if (digits.length <= 3) {
    result = digits;
  } else {
    final lastThree =
    digits.substring(
      digits.length - 3,
    );

    final remaining =
    digits.substring(
      0,
      digits.length - 3,
    );

    final parts = <String>[];

    for (
    int i = remaining.length;
    i > 0;
    i -= 2
    ) {
      final start =
      i - 2 < 0 ? 0 : i - 2;

      parts.insert(
        0,
        remaining.substring(
          start,
          i,
        ),
      );
    }

    result =
    '${parts.join("'")}\'$lastThree';
  }

  return negative ? '-$result' : result;
}

// ==================================================================
// DATE FORMAT
// ==================================================================

String formatDate(DateTime date) {
  final day =
  date.day.toString().padLeft(2, '0');

  final month =
  date.month.toString().padLeft(2, '0');

  return '$day-$month-${date.year}';
}

String formatDateTime(DateTime date) {
  final day =
  date.day.toString().padLeft(2, '0');

  final month =
  date.month.toString().padLeft(2, '0');

  var hour = date.hour;

  final minute =
  date.minute.toString().padLeft(2, '0');

  final period =
  hour >= 12 ? 'PM' : 'AM';

  hour %= 12;

  if (hour == 0) {
    hour = 12;
  }

  return '$day-$month-${date.year} • '
      '${hour.toString().padLeft(2, '0')}:'
      '$minute $period';
}
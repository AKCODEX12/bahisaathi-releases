
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'report_calculation_service.dart';
import 'loan_report_preview_screen.dart';
import 'loan/reports/interest/compound/interest_compound_report_service.dart';
import 'loan/reports/interest/compound/interest_compound_preview_screen.dart';
import 'loan/reports/interest/simple/interest_simple_report_service.dart';
import 'loan/reports/interest/simple/interest_simple_preview_screen.dart';

class ReportSettingsScreen extends StatefulWidget {
final String customerId;
final String customerName;
final String customerEmail;
final List<String> selectedLoanIds;

const ReportSettingsScreen({
super.key,
required this.customerId,
required this.customerName,
required this.customerEmail,
required this.selectedLoanIds,
});

@override
State<ReportSettingsScreen> createState() =>
_ReportSettingsScreenState();
}

class _ReportSettingsScreenState
extends State<ReportSettingsScreen> {
final TextEditingController rateController =
TextEditingController();

DateTime reportDate = DateTime.now();

// Compound default
bool isCompound = true;

bool isCalculating = false;

// Customer ka depositType customers collection se load hoga.
// Purane customer records mein field na ho to Bearing default rahega.
String depositType = 'bearing';
bool isLoadingDepositType = true;
String? depositTypeLoadError;

@override
void initState() {
super.initState();
_loadCustomerDepositType();
}

Future<void> _loadCustomerDepositType() async {
try {
final customerDoc = await FirebaseFirestore.instance
    .collection('customers')
    .doc(widget.customerId)
    .get();

final customerData = customerDoc.data();
final savedType = (customerData?['depositType'] ?? 'bearing')
    .toString()
    .trim()
    .toLowerCase();

if (savedType != 'bearing' && savedType != 'interest') {
throw Exception('Customer ka depositType valid nahi hai: $savedType');
}

if (!mounted) return;
setState(() {
depositType = savedType;
isLoadingDepositType = false;
depositTypeLoadError = null;
});
} catch (e) {
if (!mounted) return;
setState(() {
isLoadingDepositType = false;
depositTypeLoadError = e.toString();
});
}
}

@override
void dispose() {
rateController.dispose();
super.dispose();
}

Future<void> _selectReportDate() async {
final pickedDate = await showDatePicker(
context: context,
initialDate: reportDate,
firstDate: DateTime(2000),
lastDate: DateTime(2100),
);

if (pickedDate != null) {
setState(() {
reportDate = pickedDate;
});
}
}

// ================================================================
// SAVE GENERATED REPORT AUTOMATICALLY TO HISTORY
// ================================================================

Future<void> _saveReportToHistory(
LoanReportCalculationResult result,
) async {
final user = FirebaseAuth.instance.currentUser;

if (user == null) {
throw Exception(
'Admin is not logged in.',
);
}

if (widget.selectedLoanIds.isEmpty) {
throw Exception(
'No loan selected.',
);
}

final firestore =
FirebaseFirestore.instance;

// ============================================================
// SAVE COMPLETE GENERATED REPORT
// ============================================================

await firestore.collection('reports').add({
// ============================================================
// OWNER / CUSTOMER IDENTIFICATION
// ============================================================

'adminUid': user.uid,

'customerId': widget.customerId,

'customerName': result.customerName,

'customerEmail': result.customerEmail,

// ============================================================
// REPORT DATES
// ============================================================

// Till Date / calculation end date
'reportDate': Timestamp.fromDate(
result.reportDate,
),

// Actual date/time when report was generated
'generatedAt': FieldValue.serverTimestamp(),

// ============================================================
// REPORT SETTINGS
// ============================================================

'interestType': result.isCompound
? 'Compound'
    : 'Simple',

'overrideRatePM': result.overrideRatePM,

// ============================================================
// SUMMARY TOTALS
// ============================================================

'totalPrincipal':
result.totalPrincipal,

'totalPrincipalInterest':
result.totalPrincipalInterest,

'principalSideTotal':
result.principalSideTotal,

'totalDeposit':
result.totalDeposit,

'totalDepositInterest':
result.totalDepositInterest,

'depositSideTotal':
result.depositSideTotal,

'finalDue':
result.finalDue,

// ============================================================
// PRINCIPAL DETAILS
// ============================================================

'principals':
result.principals.map((item) {
return {
'loanId': item.loanId,
'loanName': item.loanName,
'amount': item.amount,
'rate': item.rate,

'openingDate':
Timestamp.fromDate(
item.openingDate,
),

'interest':
item.calculation.interest,

'total':
item.calculation.total,

'years':
item.calculation.years,

'months':
item.calculation.months,

'days':
item.calculation.days,

'yearlyInterest':
item.calculation.yearlyInterest,

'monthlyInterest':
item.calculation.monthlyInterest,

'dailyInterest':
item.calculation.dailyInterest,
};
}).toList(),

// ============================================================
// DEPOSIT DETAILS
// ============================================================

'deposits':
result.deposits.map((item) {
return {
'loanId': item.loanId,
'loanName': item.loanName,
'depositId': item.depositId,
'amount': item.amount,
'rate': item.rate,

'depositDate':
Timestamp.fromDate(
item.depositDate,
),

'interest':
item.calculation.interest,

'total':
item.calculation.total,

'years':
item.calculation.years,

'months':
item.calculation.months,

'days':
item.calculation.days,

'yearlyInterest':
item.calculation.yearlyInterest,

'monthlyInterest':
item.calculation.monthlyInterest,

'dailyInterest':
item.calculation.dailyInterest,
};
}).toList(),

// ============================================================
// SELECTED LOANS
// ============================================================

'selectedLoanIds':
widget.selectedLoanIds,
});
}

// ================================================================
// CALCULATE REPORT
// ================================================================

Future<void> _calculateReport() async {
final rateText =
rateController.text.trim();

double? overrideRate;

if (rateText.isNotEmpty) {
overrideRate =
double.tryParse(rateText);

if (overrideRate == null ||
overrideRate < 0) {
ScaffoldMessenger.of(context)
    .showSnackBar(
const SnackBar(
content: Text(
'Please enter a valid Rate PM.',
),
),
);
return;
}
}

if (widget.selectedLoanIds.isEmpty) {
ScaffoldMessenger.of(context)
    .showSnackBar(
const SnackBar(
content: Text(
'Please select at least one loan.',
),
),
);
return;
}

if (widget.customerId.trim().isEmpty) {
ScaffoldMessenger.of(context)
    .showSnackBar(
const SnackBar(
content: Text(
'Customer ID is missing.',
),
),
);
return;
}

setState(() {
isCalculating = true;
});

try {
// ============================================================
// INTEREST CUSTOMER: COMPOUND REPORT FLOW
// ============================================================

// ============================================================
// INTEREST CUSTOMER: SIMPLE / COMPOUND REPORT FLOW
// ============================================================

  if (depositType == 'interest') {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    if (adminUid == null || adminUid.trim().isEmpty) {
      throw Exception('Admin is not logged in.');
    }

    // SIMPLE INTEREST

    if (!isCompound) {
      final simpleService = InterestSimpleReportService();

      final simpleResult = await simpleService.calculateReport(
        loanIds: widget.selectedLoanIds,
        customerId: widget.customerId,
        customerName: widget.customerName,
        customerEmail: widget.customerEmail,
        reportDate: reportDate,
        overrideRatePM: overrideRate,
      );

      // Simple Interest report History mein save hogi.
      await simpleService.saveReportToHistory(
        result: simpleResult,
        adminUid: adminUid,
        selectedLoanIds: widget.selectedLoanIds,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InterestSimplePreviewScreen(
            result: simpleResult,
          ),
        ),
      );

      return;
    }


    // COMPOUND INTEREST — EXISTING FLOW UNCHANGED
    final interestService = InterestCompoundReportService();

    final interestResult = await interestService.calculateReport(
      loanIds: widget.selectedLoanIds,
      customerId: widget.customerId,
      customerName: widget.customerName,
      customerEmail: widget.customerEmail,
      reportDate: reportDate,
      overrideRatePM: overrideRate,
    );

    await interestService.saveReportToHistory(
      result: interestResult,
      adminUid: adminUid,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InterestCompoundPreviewScreen(
          result: interestResult,
        ),
      ),
    );

    return;
  }

// ============================================================
// BEARING CUSTOMER: EXISTING FLOW (UNCHANGED)
// ============================================================

final service =
ReportCalculationService();

final result =
await service.calculateReport(
loanIds:
widget.selectedLoanIds,

// NEW
customerId:
widget.customerId,

customerName:
widget.customerName,

customerEmail:
widget.customerEmail,

reportDate:
reportDate,

isCompound:
isCompound,

overrideRatePM:
overrideRate,
);

// ============================================================
// 2. AUTOMATICALLY SAVE TO HISTORY
// ============================================================

await _saveReportToHistory(
result,
);

if (!mounted) return;

// ============================================================
// 3. OPEN REPORT PREVIEW
// ============================================================

Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
LoanReportPreviewScreen(
result: result,
),
),
);
} catch (e) {
if (!mounted) return;

ScaffoldMessenger.of(context)
    .showSnackBar(
SnackBar(
content: Text(
'Unable to generate report: $e',
),
),
);
} finally {
if (mounted) {
setState(() {
isCalculating = false;
});
}
}
}

String _formatDate(DateTime date) {
return '${date.day.toString().padLeft(2, '0')}/'
'${date.month.toString().padLeft(2, '0')}/'
'${date.year}';
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text(
'Report Settings',
style: TextStyle(
fontWeight: FontWeight.bold,
),
),
centerTitle: true,
backgroundColor: Colors.green,
foregroundColor: Colors.white,
),
body: SafeArea(
child: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(
16,
18,
16,
30,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
// ====================================================
// CUSTOMER
// ====================================================

Container(
width: double.infinity,
padding:
const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(16),
border: Border.all(
color:
Colors.grey.shade300,
),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Customer',
style: TextStyle(
fontSize: 13,
color:
Colors.grey.shade600,
),
),
const SizedBox(
height: 7,
),
Text(
widget.customerName,
style:
const TextStyle(
fontSize: 19,
fontWeight:
FontWeight.bold,
),
),
const SizedBox(
height: 5,
),
Text(
widget.customerEmail,
style: TextStyle(
fontSize: 14,
color:
Colors.grey.shade700,
),
),
],
),
),

const SizedBox(
height: 20,
),

// ====================================================
// SELECTED LOANS
// ====================================================

Container(
width: double.infinity,
padding:
const EdgeInsets.all(16),
decoration: BoxDecoration(
color:
Colors.green.withOpacity(
0.06,
),
borderRadius:
BorderRadius.circular(
14,
),
border: Border.all(
color:
Colors.green.withOpacity(
0.25,
),
),
),
child: Row(
children: [
const Icon(
Icons
    .description_outlined,
color: Colors.green,
),
const SizedBox(
width: 12,
),
Expanded(
child: Text(
'${widget.selectedLoanIds.length} active loan'
'${widget.selectedLoanIds.length == 1 ? '' : 's'} selected',
style:
const TextStyle(
fontSize: 15,
fontWeight:
FontWeight.w600,
),
),
),
],
),
),

const SizedBox(
height: 24,
),

// ====================================================
// REPORT DATE
// ====================================================

const Text(
'Report Date',
style: TextStyle(
fontSize: 16,
fontWeight:
FontWeight.bold,
),
),

const SizedBox(
height: 8,
),

InkWell(
onTap:
_selectReportDate,
borderRadius:
BorderRadius.circular(
12,
),
child: Container(
width: double.infinity,
padding:
const EdgeInsets
    .symmetric(
horizontal: 15,
vertical: 16,
),
decoration:
BoxDecoration(
border: Border.all(
color:
Colors.grey.shade400,
),
borderRadius:
BorderRadius.circular(
12,
),
),
child: Row(
children: [
const Icon(
Icons
    .calendar_today_outlined,
color: Colors.green,
),
const SizedBox(
width: 12,
),
Expanded(
child: Text(
_formatDate(
reportDate,
),
style:
const TextStyle(
fontSize: 16,
),
),
),
const Icon(
Icons.arrow_drop_down,
color: Colors.grey,
),
],
),
),
),

const SizedBox(
height: 24,
),

// ====================================================
// RATE PM
// ====================================================

const Text(
'Rate PM',
style: TextStyle(
fontSize: 16,
fontWeight:
FontWeight.bold,
),
),

const SizedBox(
height: 5,
),

Text(
'Optional. Leave blank to use each loan\'s original Rate PM.',
style: TextStyle(
fontSize: 13,
color:
Colors.grey.shade600,
),
),

const SizedBox(
height: 9,
),

TextField(
controller:
rateController,
keyboardType:
const TextInputType
    .numberWithOptions(
decimal: true,
),
decoration:
InputDecoration(
hintText: 'Example: 3',
suffixText: '%',
prefixIcon:
const Icon(
Icons.percent,
color: Colors.green,
),
border:
OutlineInputBorder(
borderRadius:
BorderRadius.circular(
12,
),
),
focusedBorder:
OutlineInputBorder(
borderRadius:
BorderRadius.circular(
12,
),
borderSide:
const BorderSide(
color: Colors.green,
width: 2,
),
),
),
),

const SizedBox(
height: 26,
),

// ====================================================
// INTEREST TYPE
// ====================================================

const Text(
'Interest Type',
style: TextStyle(
fontSize: 16,
fontWeight:
FontWeight.bold,
),
),

const SizedBox(
height: 10,
),

Container(
width: double.infinity,
decoration:
BoxDecoration(
border: Border.all(
color:
Colors.grey.shade300,
),
borderRadius:
BorderRadius.circular(
14,
),
),
child: Column(
children: [
RadioListTile<bool>(
value: true,
groupValue:
isCompound,
activeColor:
Colors.green,
onChanged:
(value) {
if (value ==
null) {
return;
}

setState(() {
isCompound =
value;
});
},
title:
const Text(
'Compound Interest',
style:
TextStyle(
fontWeight:
FontWeight
    .w600,
),
),
subtitle:
const Text(
'Default',
),
),

  Divider(
    height: 1,
    color: Colors.grey.shade300,
  ),
  RadioListTile<bool>(
    value: false,
    groupValue: isCompound,
    activeColor: Colors.green,
    onChanged: (value) {
      if (value == null) return;
      setState(() {
        isCompound = value;
      });
    },
    title: const Text(
      'Simple Interest',
      style: TextStyle(
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
],
),
),

if (depositTypeLoadError != null) ...[
const SizedBox(height: 12),
Text(
'Customer type load nahi hua: $depositTypeLoadError',
style: const TextStyle(color: Colors.red),
),
],

const SizedBox(
height: 32,
),

// ====================================================
// CALCULATE REPORT
// ====================================================

SizedBox(
width: double.infinity,
height: 54,
child:
ElevatedButton.icon(
onPressed:
(isCalculating ||
isLoadingDepositType ||
depositTypeLoadError != null)
? null
    : _calculateReport,
icon:
isCalculating
? const SizedBox(
width: 20,
height: 20,
child:
CircularProgressIndicator(
strokeWidth:
2,
color:
Colors.white,
),
)
    : const Icon(
Icons
    .calculate_outlined,
),
label: Text(
isLoadingDepositType
? 'Loading Customer...'
    : isCalculating
? 'Generating & Saving...'
    : 'Calculate Report',
style:
const TextStyle(
fontSize: 16,
fontWeight:
FontWeight.bold,
),
),
style:
ElevatedButton.styleFrom(
backgroundColor:
Colors.green,
foregroundColor:
Colors.white,
disabledBackgroundColor:
Colors.grey,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(
14,
),
),
),
),
),
],
),
),
),
);
}
}

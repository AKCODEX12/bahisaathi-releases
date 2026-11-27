
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:bahisaathi/screens/admin/dashboard/report_calculation_service.dart';
import 'package:bahisaathi/screens/admin/dashboard/loan/reports/interest/compound/interest_compound_report_service.dart';
import 'package:bahisaathi/screens/admin/dashboard/loan_report_preview_screen.dart';
import 'package:bahisaathi/screens/admin/dashboard/loan/reports/interest/compound/interest_compound_preview_screen.dart';

import 'user_loan_list_screen.dart';

class CustomerReportsScreen extends StatefulWidget {
  final String customerUid;
  final String customerEmail;
  final String adminUid;

  const CustomerReportsScreen({
    super.key,
    required this.customerUid,
    required this.customerEmail,
    required this.adminUid,
  });

  @override
  State<CustomerReportsScreen> createState() =>
      _CustomerReportsScreenState();
}

class _CustomerReportsScreenState
    extends State<CustomerReportsScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _loading = true;
  bool _generating = false;
  bool _detailsExpanded = false;

  String? _error;

  String _customerName = 'Customer';
  String _depositType = 'bearing';

  List<String> _activeLoanIds = [];

  int _totalLoans = 0;
  int _closedLoans = 0;

  double _totalPrincipal = 0;
  double _totalDeposit = 0;
  double _totalInterest = 0;
  double _totalDue = 0;

  static const Color _green = Color(0xFF167548);
  static const Color _darkGreen = Color(0xFF105C39);
  static const Color _background = Color(0xFFF5F8F6);
  static const Color _border = Color(0xFFE4EAE6);
  static const Color _textDark = Color(0xFF1D3026);
  static const Color _textGrey = Color(0xFF758078);

  @override
  void initState() {
    super.initState();
    _loadReportsOverview();
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _loadReportsOverview() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Verify customer-admin connection.
      final relationshipSnapshot = await _firestore
          .collection('admin_customers')
          .where(
        'adminUid',
        isEqualTo: widget.adminUid,
      )
          .where(
        'customerUid',
        isEqualTo: widget.customerUid,
      )
          .get();

      if (relationshipSnapshot.docs.isEmpty) {
        throw Exception(
          'This customer is not linked with the selected admin.',
        );
      }

      final relationship =
      relationshipSnapshot.docs.first.data();

      if (relationship['active'] == false) {
        throw Exception(
          'Customer-admin connection is inactive.',
        );
      }

      final accountStatus =
      (relationship['accountStatus'] ?? 'active')
          .toString()
          .toLowerCase()
          .trim();

      // Load customer details.
      final customerSnapshot = await _firestore
          .collection('customers')
          .doc(widget.customerUid)
          .get();

      final customerData = customerSnapshot.data() ?? {};

      _customerName = (
          customerData['name'] ??
              customerData['customerName'] ??
              'Customer'
      ).toString();

      _depositType =
          (customerData['depositType'] ?? 'bearing')
              .toString()
              .toLowerCase()
              .trim();

      if (_depositType != 'bearing' &&
          _depositType != 'interest') {
        _depositType = 'bearing';
      }

      // Fetch this customer's loans under this admin.
      final loanSnapshot = await _firestore
          .collection('loans')
          .where(
        'customerId',
        isEqualTo: widget.customerUid,
      )
          .where(
        'adminUid',
        isEqualTo: widget.adminUid,
      )
          .get();

      final activeLoans =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      int closedCount = 0;

      for (final loanDoc in loanSnapshot.docs) {
        final loan = loanDoc.data();

        final status = (loan['status'] ?? 'active')
            .toString()
            .toLowerCase()
            .trim();

        if (status == 'closed') {
          closedCount++;
          continue;
        }

        if (status != 'active') {
          continue;
        }

        // Only active customer accounts are eligible.
        if (accountStatus != 'active') {
          continue;
        }

        activeLoans.add(loanDoc);
      }

      final activeIds =
      activeLoans.map((loan) => loan.id).toList();

      double principal = 0;
      double deposit = 0;
      double interest = 0;
      double due = 0;

      for (final loanDoc in activeLoans) {
        principal += _toDouble(
          loanDoc.data()['amount'],
        );
      }

      // Use existing report services for calculations.
      if (activeIds.isNotEmpty) {
        final reportDate = DateTime.now();

        if (_depositType == 'interest') {
          final service =
          InterestCompoundReportService();

          final result = await service.calculateReport(
            loanIds: activeIds,
            customerId: widget.customerUid,
            customerName: _customerName,
            customerEmail: widget.customerEmail,
            reportDate: reportDate,
          );

          deposit = result.totalDeposit;
          interest = result.totalInterest;
          due = result.finalDue;
        } else {
          final service = ReportCalculationService();

          final result = await service.calculateReport(
            loanIds: activeIds,
            customerId: widget.customerUid,
            customerName: _customerName,
            customerEmail: widget.customerEmail,
            reportDate: reportDate,
            isCompound: true,
          );

          deposit = result.totalDeposit;

          interest = result.totalPrincipalInterest -
              result.totalDepositInterest;

          due = result.finalDue;
        }
      }

      if (!mounted) return;

      setState(() {
        _activeLoanIds = activeIds;
        _totalLoans = activeIds.length;
        _closedLoans = closedCount;

        _totalPrincipal = principal;
        _totalDeposit = deposit;
        _totalInterest = interest;
        _totalDue = due;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Customer report generation.
  // History is not saved from this customer screen.
  // Admin report workflow is not changed.
  Future<void> _generateReport() async {
    if (_generating) return;

    if (_activeLoanIds.isEmpty) {
      _message('No active loans available for report.');
      return;
    }

    setState(() {
      _generating = true;
    });

    try {
      final reportDate = DateTime.now();

      if (_depositType == 'interest') {
        final service =
        InterestCompoundReportService();

        final result = await service.calculateReport(
          loanIds: _activeLoanIds,
          customerId: widget.customerUid,
          customerName: _customerName,
          customerEmail: widget.customerEmail,
          reportDate: reportDate,
        );

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                InterestCompoundPreviewScreen(
                  result: result,
                ),
          ),
        );
      } else {
        final service = ReportCalculationService();

        final result = await service.calculateReport(
          loanIds: _activeLoanIds,
          customerId: widget.customerUid,
          customerName: _customerName,
          customerEmail: widget.customerEmail,
          reportDate: reportDate,
          isCompound: true,
        );

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoanReportPreviewScreen(
              result: result,
            ),
          ),
        );
      }
    } catch (e) {
      _message('Unable to generate report: $e');
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _money(double value) {
    return '₹ ${value.toStringAsFixed(2)}';
  }

  // View Details shows/hides the Generate Report button.
  void _showDetails() {
    setState(() {
      _detailsExpanded = !_detailsExpanded;
    });
  }
  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required Color iconBackground,
    bool isTotalDue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: isTotalDue
            ? const Color(0xFFFFF3E1)
            : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isTotalDue
              ? const Color(0xFFE4BC80)
              : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: isTotalDue
                  ? const Color(0xFFFBE2BD)
                  : iconBackground,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: isTotalDue
                  ? const Color(0xFF89551A)
                  : iconColor,
              size: 17,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isTotalDue
                  ? const Color(0xFF89551A)
                  : _textGrey,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isTotalDue
                  ? const Color(0xFF5B370D)
                  : _textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: _green,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _depositType == 'interest'
                      ? 'Interest Deposit'
                      : 'Bearing Deposit',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textGrey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 7,
                  color: _green,
                ),
                SizedBox(width: 4),
                Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 10,
                    color: _green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyLoansCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserLoanListScreen(
              customerUid: widget.customerUid,
              customerEmail: widget.customerEmail,
              adminUid: widget.adminUid,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                color: Color(0xFF315EAB),
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Loans',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'View your loan details',
                    style: TextStyle(
                      fontSize: 11,
                      color: _textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _textGrey,
              size: 23,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _generating ? null : _generateReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_generating)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(
                Icons.description_outlined,
                size: 20,
              ),
            const SizedBox(width: 8),
            Text(
              _generating
                  ? 'Generating Report...'
                  : 'Generate Report',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!_generating) ...[
              const SizedBox(width: 7),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Your financial summary',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReportsOverview,
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadReportsOverview,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadReportsOverview,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            13,
            11,
            13,
            13,
          ),
          children: [
            _buildCustomerCard(),

            const SizedBox(height: 10),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics:
              const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 1.72,
              children: [
                // 1. Total Loans
                _summaryCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'कुल लोन',
                  value: '$_totalLoans',
                  iconColor: const Color(0xFF315EAB),
                  iconBackground: const Color(0xFFEAF1FF),
                ),

                // 2. Closed Loans
                _summaryCard(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'बंद लोन',
                  value: '$_closedLoans',
                  iconColor: const Color(0xFF52616B),
                  iconBackground: const Color(0xFFEDF1F4),
                ),

                // 3. Total Principal
                _summaryCard(
                  icon: Icons.currency_rupee_rounded,
                  title: 'कुल मूलधन',
                  value: _money(_totalPrincipal),
                  iconColor: const Color(0xFF167548),
                  iconBackground: const Color(0xFFEAF5EE),
                ),

                // 4. Total Deposit
                _summaryCard(
                  icon: Icons.savings_outlined,
                  title: 'कुल जमा',
                  value: _money(_totalDeposit),
                  iconColor: const Color(0xFF8B5E16),
                  iconBackground: const Color(0xFFFFF4DE),
                ),

                // 5. Total Interest
                _summaryCard(
                  icon: Icons.trending_up_rounded,
                  title: 'कुल ब्याज',
                  value: _money(_totalInterest),
                  iconColor: const Color(0xFF7A48B8),
                  iconBackground: const Color(0xFFF2EAFE),
                ),

                // 6. Total Due - last box with separate presence
                _summaryCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'कुल बकाया',
                  value: _money(_totalDue),
                  iconColor: const Color(0xFFB34A3A),
                  iconBackground: const Color(0xFFFFECE8),
                  isTotalDue: true,
                ),
              ],
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 38,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _generating
                    ? null
                    : _showDetails,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(
                    color: Color(0xFFB9D7C5),
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(11),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            if (_detailsExpanded) ...[
              const SizedBox(height: 10),
              _buildGenerateButton(),
            ],

            const SizedBox(height: 10),

            _buildMyLoansCard(),

            const SizedBox(height: 8),

            const Center(
              child: Text(
                'Your loan details and report are available here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: _textGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'report_calculation_service.dart';
import 'package:bahisaathi/screens/admin/dashboard/loan/reports/interest/compound/interest_compound_report_service.dart';
import 'history_reports_screen.dart';
import 'package:bahisaathi/screens/admin/dashboard/loan/reports/reports_pin_security.dart';
import 'dart:async';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}
class _ReportsTabState extends State<ReportsTab>
    with WidgetsBindingObserver {
  bool _showAmounts = false;
  bool _isLoading = true;
  String? _error;

  double _totalPrincipal = 0;
  double _totalDeposit = 0;
  double _totalInterest = 0;
  double _totalOutstanding = 0;

  int _activeLoans = 0;
  int _totalCustomers = 0;
  Timer? _amountsTimer;

  void _unlockAmounts() {
    if (!mounted) return;

    _amountsTimer?.cancel();

    setState(() {
      _showAmounts = true;
    });

    // 1 minute बाद amounts अपने आप hide होंगे।
    _amountsTimer = Timer(
      const Duration(minutes: 1),
      _hideAmounts,
    );
  }

  void _hideAmounts() {
    _amountsTimer?.cancel();

    if (!mounted) return;

    if (_showAmounts) {
      setState(() {
        _showAmounts = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state != AppLifecycleState.resumed) {
      _hideAmounts();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Admin login नहीं है।');
      }

      final firestore = FirebaseFirestore.instance;
      final adminUid = user.uid;

      // ---------------------------------------------------------
      // 1. ADMIN KE LINKED CUSTOMERS
      // ---------------------------------------------------------

      final relationshipSnapshot = await firestore
          .collection('admin_customers')
          .where('adminUid', isEqualTo: adminUid)
          .where('active', isEqualTo: true)
          .get();

      final Map<String, Map<String, dynamic>> linkedCustomers = {};

      for (final doc in relationshipSnapshot.docs) {
        final data = doc.data();

        final customerId =
        (data['customerUid'] ?? '').toString().trim();

        if (customerId.isEmpty) continue;

        linkedCustomers[customerId] = {
          '_relationshipId': doc.id,
          '_customerId': customerId,
          '_accountStatus':
          (data['accountStatus'] ?? 'active')
              .toString()
              .toLowerCase()
              .trim(),
        };
      }

      _totalCustomers = linkedCustomers.length;

      // ---------------------------------------------------------
      // 2. ADMIN KE LOANS
      // ---------------------------------------------------------

      final loanSnapshot = await firestore
          .collection('loans')
          .where('adminUid', isEqualTo: adminUid)
          .get();

      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      loansByCustomer = {};

      for (final loanDoc in loanSnapshot.docs) {
        final loan = loanDoc.data();

        final customerId =
        (loan['customerId'] ?? '').toString().trim();

        if (customerId.isEmpty) continue;

        if (!linkedCustomers.containsKey(customerId)) {
          continue;
        }

        final loanStatus =
        (loan['status'] ?? '').toString().toLowerCase().trim();

        if (loanStatus != 'active') continue;

        final customerStatus =
        linkedCustomers[customerId]!['_accountStatus'];

        // Inactive/disabled customer ke loans overview mein
        // active nahi maane jayenge.
        if (customerStatus != 'active') continue;

        loansByCustomer.putIfAbsent(
          customerId,
              () => [],
        );

        loansByCustomer[customerId]!.add(loanDoc);
      }

      // ---------------------------------------------------------
      // 3. OVERVIEW TOTALS
      // ---------------------------------------------------------

      double principal = 0;
      double deposit = 0;
      double interest = 0;
      double outstanding = 0;
      int activeLoanCount = 0;

      final reportDate = DateTime.now();

      for (final entry in loansByCustomer.entries) {
        final customerId = entry.key;
        final customerLoans = entry.value;

        if (customerLoans.isEmpty) continue;

        final customerDoc = await firestore
            .collection('customers')
            .doc(customerId)
            .get();

        final customerData = customerDoc.data() ?? {};

        final customerName =
        (customerData['name'] ??
            customerData['customerName'] ??
            customerLoans.first.data()['customerName'] ??
            'Customer')
            .toString();

        final customerEmail =
        (customerData['email'] ??
            customerData['customerEmail'] ??
            customerLoans.first.data()['customerEmail'] ??
            '')
            .toString();

        final depositType =
        (customerData['depositType'] ?? 'bearing')
            .toString()
            .toLowerCase()
            .trim();

        final loanIds =
        customerLoans.map((loan) => loan.id).toList();

        // Original principal amount.
        for (final loanDoc in customerLoans) {
          final loan = loanDoc.data();

          principal += _toDouble(loan['amount']);
        }

        activeLoanCount += customerLoans.length;

        // -------------------------------------------------------
        // INTEREST DEPOSIT TYPE
        // Default report calculation: Compound.
        // -------------------------------------------------------

        if (depositType == 'interest') {
          final service = InterestCompoundReportService();

          final result = await service.calculateReport(
            loanIds: loanIds,
            customerId: customerId,
            customerName: customerName,
            customerEmail: customerEmail,
            reportDate: reportDate,
            overrideRatePM: null,
          );

          deposit += _toDouble(result.totalDeposit);
          interest += _toDouble(result.totalInterest);
          outstanding += _toDouble(result.finalDue);
        } else {
          // -----------------------------------------------------
          // BEARING DEPOSIT TYPE
          // Existing Bearing Compound calculation.
          // -----------------------------------------------------

          final service = ReportCalculationService();

          final result = await service.calculateReport(
            loanIds: loanIds,
            customerId: customerId,
            customerName: customerName,
            customerEmail: customerEmail,
            reportDate: reportDate,
            isCompound: true,
            overrideRatePM: null,
          );

          deposit += _toDouble(result.totalDeposit);

          // Bearing Interest = Principal Side Interest
          //                     - Deposit Side Interest
          interest +=
              _toDouble(result.totalPrincipalInterest) -
                  _toDouble(result.totalDepositInterest);

          // Final Due already includes deposit adjustment.
          // Deposit ko dobara subtract nahi karna.
          outstanding += _toDouble(result.finalDue);
        }
      }

      if (!mounted) return;

      setState(() {
        _totalPrincipal = principal;
        _totalDeposit = deposit;
        _totalInterest = interest;
        _totalOutstanding = outstanding;
        _activeLoans = activeLoanCount;
        _totalCustomers = linkedCustomers.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountsTimer?.cancel();

    super.dispose();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatAmount(double amount) {
    return '₹ ${amount.toStringAsFixed(2)}';
  }

  String _displayAmount(double amount) {
    if (!_showAmounts) return '••••••';
    return _formatAmount(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOverview,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              // ---------------------------------------------------
              // HEADER
              // ---------------------------------------------------

              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reports',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF172B4D),
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Your business overview',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _showAmounts
                        ? 'Hide amounts'
                        : 'Show amounts',
                    onPressed: () {
                      if (_showAmounts) {
                        _hideAmounts();
                        return;
                      }

                      ReportsPinSecurity.open(
                        context: context,
                        onUnlocked: _unlockAmounts,
                      );
                    },
                    icon: Icon(
                      _showAmounts
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF2457A6),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loadOverview,
                    icon: const Icon(
                      Icons.refresh,
                      color: Color(0xFF2457A6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ---------------------------------------------------
              // LOADING / ERROR
              // ---------------------------------------------------

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 45),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 32,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Reports load नहीं हो पाए।',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadOverview,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    // ------------------------------------------------
                    // SUMMARY CARDS
                    // ------------------------------------------------

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.38,
                      children: [
                        _SummaryCard(
                          title: 'Total Principal',
                          amount: _displayAmount(_totalPrincipal),
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: const Color(0xFF2457A6),
                        ),
                        _SummaryCard(
                          title: 'Total Deposit',
                          amount: _displayAmount(_totalDeposit),
                          icon: Icons.savings_outlined,
                          iconColor: const Color(0xFF16845B),
                        ),
                        _SummaryCard(
                          title: 'Total Interest',
                          amount: _displayAmount(_totalInterest),
                          icon: Icons.trending_up,
                          iconColor: const Color(0xFF9A6A13),
                        ),
                        _SummaryCard(
                          title: 'Total Outstanding',
                          amount: _displayAmount(_totalOutstanding),
                          icon: Icons.receipt_long_outlined,
                          iconColor: const Color(0xFFB54747),
                        ),
                        _SummaryCard(
                          title: 'Active Loans',
                          amount: _activeLoans.toString(),
                          icon: Icons.description_outlined,
                          iconColor: const Color(0xFF6C4AB6),
                        ),
                        _SummaryCard(
                          title: 'Total Customers',
                          amount: _totalCustomers.toString(),
                          icon: Icons.people_outline,
                          iconColor: const Color(0xFF287D91),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ------------------------------------------------
                    // CUSTOMER-WISE REPORTS
                    // ------------------------------------------------

                    _ReportNavigationTile(
                      icon: Icons.people_alt_outlined,
                      title: 'Customer-wise Reports',
                      subtitle: 'View customer reports',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _CustomerReportsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // ------------------------------------------------
                    // REPORT HISTORY
                    // ------------------------------------------------

                    _ReportNavigationTile(
                      icon: Icons.history,
                      title: 'Report History',
                      subtitle: 'View previously generated reports',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _AdminReportHistoryScreen(),
                          ),
                        );
                      },
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

// =================================================================
// SUMMARY CARD
// =================================================================

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color iconColor;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8ECF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 19,
            ),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF697586),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172B4D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// NAVIGATION TILE
// =================================================================

class _ReportNavigationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportNavigationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 17,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFE8ECF2),
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 43,
                width: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF2457A6),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF172B4D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================
// CUSTOMER-WISE REPORTS
// =================================================================

class _CustomerReportsScreen extends StatelessWidget {
  const _CustomerReportsScreen();

  @override
  Widget build(BuildContext context) {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    if (adminUid == null) {
      return const Scaffold(
        body: Center(child: Text('Admin login नहीं है।')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer-wise Reports'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('admin_customers')
            .where('adminUid', isEqualTo: adminUid)
            .where('active', isEqualTo: true)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load customers: ${snapshot.error}'),
            );
          }

          final relationships = snapshot.data?.docs ?? [];

          if (relationships.isEmpty) {
            return const Center(
              child: Text('No customers found.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: relationships.length,
            itemBuilder: (context, index) {
              final relationship = relationships[index].data();

              final customerId =
              (relationship['customerUid'] ?? '').toString();

              final status =
              (relationship['accountStatus'] ?? 'active')
                  .toString()
                  .toLowerCase();

              return FutureBuilder<
                  DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('customers')
                    .doc(customerId)
                    .get(),
                builder: (context, customerSnapshot) {
                  if (!customerSnapshot.hasData) {
                    return const SizedBox(
                      height: 70,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  final customer =
                      customerSnapshot.data?.data() ?? {};

                  final name =
                  (customer['name'] ??
                      customer['customerName'] ??
                      'Customer')
                      .toString();

                  final email =
                  (customer['email'] ??
                      customer['customerEmail'] ??
                      '')
                      .toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade50,
                        child: const Icon(
                          Icons.person_outline,
                          color: Colors.green,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$email\nStatus: ${status.toUpperCase()}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistoryReportsScreen(
                              customerId: customerId,
                              customerName: name,
                              customerEmail: email,
                              adminUid: adminUid,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// =================================================================
// ADMIN REPORT HISTORY
// =================================================================

class _AdminReportHistoryScreen extends StatelessWidget {
  const _AdminReportHistoryScreen();

  Future<List<Map<String, dynamic>>> _loadHistory(
      String adminUid,
      ) async {
    final firestore = FirebaseFirestore.instance;

    final collections = [
      'reports',
      'interest_compound_reports',
      'interest_simple_reports',
    ];

    final results = await Future.wait(
      collections.map(
            (collection) => firestore
            .collection(collection)
            .where('adminUid', isEqualTo: adminUid)
            .orderBy('generatedAt', descending: true)
            .limit(50)
            .get(),
      ),
    );

    final List<Map<String, dynamic>> allReports = [];

    for (int i = 0; i < results.length; i++) {
      for (final doc in results[i].docs) {
        final data = doc.data();

        allReports.add({
          ...data,
          '_docId': doc.id,
          '_collection': collections[i],
        });
      }
    }

    allReports.sort((a, b) {
      final aDate = a['generatedAt'];
      final bDate = b['generatedAt'];

      final aMillis = aDate is Timestamp
          ? aDate.millisecondsSinceEpoch
          : 0;

      final bMillis = bDate is Timestamp
          ? bDate.millisecondsSinceEpoch
          : 0;

      return bMillis.compareTo(aMillis);
    });

    return allReports;
  }

  String _dateText(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return 'Date not available';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    if (adminUid == null) {
      return const Scaffold(
        body: Center(child: Text('Admin login नहीं है।')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report History'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadHistory(adminUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load history: ${snapshot.error}'),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(
              child: Text('No saved reports found.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];

              final customerId =
              (report['customerId'] ?? '').toString();

              final customerName =
              (report['customerName'] ?? 'Customer').toString();

              final customerEmail =
              (report['customerEmail'] ?? '').toString();

              final collection =
              (report['_collection'] ?? '').toString();

              final reportType = collection == 'reports'
                  ? 'Bearing'
                  : collection == 'interest_simple_reports'
                  ? 'Interest Simple'
                  : 'Interest Compound';

              final finalDue =
              report['finalDue'] is num
                  ? (report['finalDue'] as num).toDouble()
                  : 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.description_outlined),
                  ),
                  title: Text(
                    customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '$reportType • ${_dateText(report['reportDate'])}\n'
                        'Final Due: ₹ ${finalDue.toStringAsFixed(2)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryReportsScreen(
                          customerId: customerId,
                          customerName: customerName,
                          customerEmail: customerEmail,
                          adminUid: adminUid,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

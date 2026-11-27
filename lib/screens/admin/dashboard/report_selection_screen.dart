import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'report_settings_screen.dart';

class ReportSelectionScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String adminUid;

  const ReportSelectionScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.adminUid,
  });

  @override
  State<ReportSelectionScreen> createState() =>
      _ReportSelectionScreenState();
}

class _ReportSelectionScreenState
    extends State<ReportSelectionScreen> {
  final Set<String> selectedLoanIds = <String>{};

  bool selectAllActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report Selection',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('loans')
            .where(
          'adminUid',
          isEqualTo: widget.adminUid,
        )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Unable to load loans.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Current customer ke loans only
          final customerLoans = allDocs.where((doc) {
            final data =
            doc.data() as Map<String, dynamic>;

            final loanCustomerId =
            (data['customerId'] ?? '').toString();

            final loanCustomerEmail =
            (data['customerEmail'] ?? '').toString();

            return loanCustomerId == widget.customerId ||
                loanCustomerEmail == widget.customerEmail;
          }).toList();

          // Active loans
          final activeLoans = customerLoans.where((doc) {
            final data =
            doc.data() as Map<String, dynamic>;

            final status =
            (data['status'] ?? 'active')
                .toString()
                .toLowerCase();

            return status == 'active';
          }).toList();

          // Closed loans
          final closedLoans = customerLoans.where((doc) {
            final data =
            doc.data() as Map<String, dynamic>;

            final status =
            (data['status'] ?? 'active')
                .toString()
                .toLowerCase();

            return status == 'closed';
          }).toList();

          // Safety: agar koi selected loan ab active nahi raha
          final activeLoanIds =
          activeLoans.map((doc) => doc.id).toSet();

          selectedLoanIds.removeWhere(
                (id) => !activeLoanIds.contains(id),
          );

          // Select All state ko current active loans
          // ke according maintain karna
          selectAllActive = activeLoans.isNotEmpty &&
              selectedLoanIds.length ==
                  activeLoans.length;

          return Column(
            children: [
              // CUSTOMER INFORMATION
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius:
                  BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.customerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.customerEmail,
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // SELECT ALL ACTIVE LOANS
              if (activeLoans.isNotEmpty)
                CheckboxListTile(
                  title: const Text(
                    'Select All Active Loans',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${activeLoans.length} active loan(s)',
                  ),
                  value: selectAllActive,
                  activeColor: Colors.green,
                  onChanged: (value) {
                    setState(() {
                      selectAllActive =
                          value ?? false;

                      if (selectAllActive) {
                        selectedLoanIds.clear();

                        for (final loan
                        in activeLoans) {
                          selectedLoanIds.add(
                            loan.id,
                          );
                        }
                      } else {
                        selectedLoanIds.clear();
                      }
                    });
                  },
                ),

              const Divider(height: 1),

              // LOAN LIST
              Expanded(
                child: customerLoans.isEmpty
                    ? const Center(
                  child: Text(
                    'No loans found for this customer.',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                )
                    : ListView(
                  padding:
                  const EdgeInsets.only(
                    top: 8,
                    bottom: 100,
                  ),
                  children: [
                    // ACTIVE LOANS
                    if (activeLoans.isNotEmpty)
                      const Padding(
                        padding:
                        EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          8,
                        ),
                        child: Text(
                          'Active Loans',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),

                    ...activeLoans.map(
                          (doc) => _loanTile(
                        doc,
                        isActive: true,
                        activeLoanCount:
                        activeLoans.length,
                      ),
                    ),

                    // CLOSED LOANS
                    if (closedLoans.isNotEmpty)
                      const Padding(
                        padding:
                        EdgeInsets.fromLTRB(
                          16,
                          20,
                          16,
                          8,
                        ),
                        child: Text(
                          'Closed Loans',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                    ...closedLoans.map(
                          (doc) => _loanTile(
                        doc,
                        isActive: false,
                        activeLoanCount:
                        activeLoans.length,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // GENERATE REPORT BUTTON
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
              selectedLoanIds.isEmpty
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReportSettingsScreen(
                          // IMPORTANT:
                          // Customer ID ab Settings
                          // screen ko bhi milega.
                          customerId:
                          widget.customerId,

                          customerName:
                          widget.customerName,

                          customerEmail:
                          widget.customerEmail,

                          selectedLoanIds:
                          selectedLoanIds
                              .toList(),
                        ),
                  ),
                );
              },
              icon: const Icon(
                Icons.description_outlined,
              ),
              label: Text(
                selectedLoanIds.isEmpty
                    ? 'Select Active Loans'
                    : 'Generate Report (${selectedLoanIds.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                Colors.grey.shade300,
                disabledForegroundColor:
                Colors.grey.shade600,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // LOAN TILE
  // ================================================================

  Widget _loanTile(
      QueryDocumentSnapshot doc, {
        required bool isActive,
        required int activeLoanCount,
      }) {
    final data =
    doc.data() as Map<String, dynamic>;

    final loanName =
    (data['name'] ?? 'Loan').toString();

    final amount =
    _formatAmount(data['amount']);

    final rate =
    (data['ratePM'] ?? 0).toString();

    final status =
    (data['status'] ?? 'active')
        .toString();

    final isSelected =
    selectedLoanIds.contains(doc.id);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      elevation: 1,
      child: CheckboxListTile(
        value:
        isActive ? isSelected : false,

        activeColor: Colors.green,

        // Closed loan disabled hai
        onChanged: isActive
            ? (value) {
          setState(() {
            if (value == true) {
              selectedLoanIds.add(
                doc.id,
              );
            } else {
              selectedLoanIds.remove(
                doc.id,
              );
            }

            selectAllActive =
                selectedLoanIds.length ==
                    activeLoanCount &&
                    activeLoanCount > 0;
          });
        }
            : null,

        title: Text(
          loanName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive
                ? Colors.black
                : Colors.grey,
          ),
        ),

        subtitle: Text(
          'Amount: $amount\n'
              'Rate PM: $rate%\n'
              'Status: $status',
          style: TextStyle(
            color: isActive
                ? Colors.black87
                : Colors.grey,
          ),
        ),

        secondary: Icon(
          isActive
              ? Icons
              .account_balance_wallet_outlined
              : Icons.lock_outline,
          color: isActive
              ? Colors.green
              : Colors.grey,
        ),
      ),
    );
  }

  String _formatAmount(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(
      value.toString(),
    ) ??
        0;

    return '₹${number.toStringAsFixed(0)}';
  }
}
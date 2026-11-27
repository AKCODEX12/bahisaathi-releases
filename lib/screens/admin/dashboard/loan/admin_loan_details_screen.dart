import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../deposit_section.dart';


// ====================================================================
// ADMIN LOAN DETAILS SCREEN
// ====================================================================

class AdminLoanDetailsScreen extends StatelessWidget {
  final String loanId;
  final Map<String, dynamic> data;
  final int loanNumber;
  final String recordId;

  final VoidCallback onEdit;
  final VoidCallback onClose;
  final VoidCallback onReopen;

  const AdminLoanDetailsScreen({
    super.key,
    required this.loanId,
    required this.data,
    required this.loanNumber,
    required this.recordId,
    required this.onEdit,
    required this.onClose,
    required this.onReopen,
  });

  String formatDate(dynamic value) {
    if (value is! Timestamp) {
      return '-';
    }

    final date = value.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String formatAmount(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    final fixed = number % 1 == 0
        ? number.toInt().toString()
        : number.toStringAsFixed(2);

    final parts = fixed.split('.');
    final integer = parts[0];

    String formatted;

    if (integer.length <= 3) {
      formatted = integer;
    } else {
      final lastThree = integer.substring(integer.length - 3);
      var rest = integer.substring(0, integer.length - 3);

      final groups = <String>[];

      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }

      if (rest.isNotEmpty) {
        groups.insert(0, rest);
      }

      formatted = '${groups.join(',')},$lastThree';
    }

    return '₹$formatted'
        '${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  String formatRate(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    return number % 1 == 0
        ? '${number.toInt()}% per month'
        : '$number% per month';
  }

  Widget statusBadge(bool isClosed) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: isClosed ? Colors.grey.shade200 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClosed
              ? Colors.grey.shade400
              : Colors.green.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isClosed ? Icons.lock_outline : Icons.verified,
            size: 17,
            color: isClosed
                ? Colors.grey.shade700
                : Colors.green.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            isClosed ? 'CLOSED' : 'ACTIVE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isClosed
                  ? Colors.grey.shade700
                  : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle({
    required IconData icon,
    required String title,
    required bool isClosed,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isClosed
              ? const Color(0xFF687782)
              : Colors.green.shade700,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isClosed
                ? const Color(0xFF53636E)
                : const Color(0xFF143C2C),
          ),
        ),
      ],
    );
  }

  Widget detailRow(
      String title,
      String value,
      bool isClosed, {
        bool boldValue = false,
      }) {
    if (value.trim().isEmpty || value.trim() == '-') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isClosed
                    ? const Color(0xFF687782)
                    : const Color(0xFF60788A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                boldValue ? FontWeight.bold : FontWeight.w500,
                color: isClosed
                    ? const Color(0xFF596A76)
                    : const Color(0xFF1D2F27),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isClosed =
        (data['status'] ?? '').toString().toLowerCase() == 'closed';

    final name = (data['name'] ?? data['customerName'] ?? '')
        .toString()
        .trim();

    final email = (data['customerEmail'] ?? '').toString().trim();

    final purpose = (data['forWork'] ?? '').toString().trim();

    final relation = (data['relationName'] ?? '').toString().trim();

    final address = (data['address'] ?? '').toString().trim();

    final description =
    (data['description'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: isClosed
          ? const Color(0xFFEEF1F3)
          : const Color(0xFFF7FAF9),
      appBar: AppBar(
        title: const Text(
          'Loan Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isClosed
            ? const Color(0xFF71808C)
            : Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Edit Loan',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Opacity(
              opacity: isClosed ? 0.78 : 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isClosed
                      ? Colors.grey.shade100
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isClosed
                        ? const Color(0xFFD4DBDF)
                        : const Color(0xFFE0E9E4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.035),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isClosed
                                ? const Color(0xFFE0E5E8)
                                : const Color(0xFFE0F5EA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            color: isClosed
                                ? const Color(0xFF657582)
                                : Colors.green.shade700,
                            size: 29,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LOAN #${loanNumber.toString().padLeft(3, '0')}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isClosed
                                      ? const Color(0xFF596A76)
                                      : const Color(0xFF143C2C),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Record ID: $recordId',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isClosed
                                      ? const Color(0xFF849099)
                                      : const Color(0xFF60788A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        statusBadge(isClosed),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Divider(
                      color: isClosed
                          ? const Color(0xFFD6DCE0)
                          : const Color(0xFFE1E9E5),
                    ),

                    const SizedBox(height: 16),

                    // BORROWER DETAILS

                    sectionTitle(
                      icon: Icons.person_outline,
                      title: 'Borrower Details',
                      isClosed: isClosed,
                    ),

                    const SizedBox(height: 12),

                    detailRow('Name', name, isClosed),
                    detailRow('Email', email, isClosed),
                    detailRow('Purpose', purpose, isClosed),
                    detailRow('Father / Relation', relation, isClosed),
                    detailRow('Address', address, isClosed),

                    const SizedBox(height: 8),

                    Divider(
                      color: isClosed
                          ? const Color(0xFFD6DCE0)
                          : const Color(0xFFE1E9E5),
                    ),

                    const SizedBox(height: 16),

                    // LOAN DETAILS

                    sectionTitle(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Loan Details',
                      isClosed: isClosed,
                    ),

                    const SizedBox(height: 12),

                    detailRow(
                      'Principal Amount',
                      formatAmount(data['amount']),
                      isClosed,
                      boldValue: true,
                    ),

                    detailRow(
                      'Interest Rate',
                      formatRate(data['ratePM']),
                      isClosed,
                    ),

                    detailRow(
                      'Opening Date',
                      formatDate(data['openingDate']),
                      isClosed,
                    ),

                    if (data['dueDate'] is Timestamp)
                      detailRow(
                        'Due Date',
                        formatDate(data['dueDate']),
                        isClosed,
                      ),

                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      detailRow('Description', description, isClosed),
                    ],



                    const SizedBox(height: 18),

                    // ADMIN CONTROL BOX

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isClosed
                            ? const Color(0xFFE8ECEE)
                            : const Color(0xFFF1F8F5),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: isClosed
                              ? const Color(0xFFD1D8DC)
                              : const Color(0xFFD7EAE2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            color: isClosed
                                ? const Color(0xFF697984)
                                : Colors.green.shade700,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Admin controlled loan record\n'
                                  'Customer Gmail is read-only.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF47675A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ACTION BUTTONS

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('EDIT LOAN'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: isClosed
                              ? OutlinedButton.icon(
                            onPressed: onReopen,
                            icon: const Icon(
                              Icons.lock_open_outlined,
                            ),
                            label: const Text('REOPEN'),
                          )
                              : OutlinedButton.icon(
                            onPressed: onClose,
                            icon: const Icon(
                              Icons.lock_outline,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'CLOSE LOAN',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Center(
                      child: Text(
                        'Loan Record • Admin Controlled • Digitally Recorded',
                        style: TextStyle(
                          fontSize: 11,
                          color: isClosed
                              ? const Color(0xFF849099)
                              : const Color(0xFF789085),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            DepositSection(
              loanId: loanId,
            ),
          ],
        ),
      ),
    );
  }
}
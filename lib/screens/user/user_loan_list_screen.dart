import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'loan_details_screen.dart';

class UserLoanListScreen extends StatelessWidget {
  final String customerUid;
  final String customerEmail;
  final String adminUid;

  const UserLoanListScreen({
    super.key,
    required this.customerUid,
    required this.customerEmail,
    required this.adminUid,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F8),
      appBar: AppBar(
        title: const Text(
          'My Loans',
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
          'customerId',
          isEqualTo: customerUid,
        )
            .where(
          'adminUid',
          isEqualTo: adminUid,
        )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load loans.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final loans = snapshot.data?.docs ?? [];

          if (loans.isEmpty) {
            return const Center(
              child: Text(
                'No loans found.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          // Newest loan first
          final sortedLoans = [...loans];

          sortedLoans.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aTime = aData['createdAt'];
            final bTime = bData['createdAt'];

            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }

            if (aTime is Timestamp) return -1;
            if (bTime is Timestamp) return 1;

            return 0;
          });

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              14,
              16,
              14,
              25,
            ),
            children: [
              _securityBanner(),
              const SizedBox(height: 14),
              ...List.generate(
                sortedLoans.length,
                    (index) {
                  final doc = sortedLoans[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return _compactLoanCard(
                    context,
                    data,
                    index + 1,
                    doc.id,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // TOP SECURITY / RECORD BANNER
  // ============================================================

  Widget _securityBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD1EDE0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user,
              color: Colors.green,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your loan records are securely maintained by your admin.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF174D39),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SMALL LOAN CARD
  // ============================================================

  Widget _compactLoanCard(
      BuildContext context,
      Map<String, dynamic> data,
      int loanNumber,
      String documentId,
      ) {
    final bool isClosed =
        (data['status'] ?? '').toString().toLowerCase() == 'closed';

    final recordId = _recordId(
      data,
      loanNumber,
      documentId,
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoanDetailsScreen(
              data: data,
              loanNumber: loanNumber,
              recordId: recordId,
              loanDocumentId: documentId,
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isClosed
              ? const Color(0xFFF0F3F5)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isClosed
                ? const Color(0xFFD5DCE0)
                : const Color(0xFFDCE9E4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Loan icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isClosed
                    ? const Color(0xFFE0E6EA)
                    : const Color(0xFFE3F6ED),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.description_outlined,
                color: isClosed
                    ? const Color(0xFF667785)
                    : Colors.green.shade700,
                size: 27,
              ),
            ),

            const SizedBox(width: 12),

            // Loan number + Record ID
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOAN #${loanNumber.toString().padLeft(3, '0')}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isClosed
                          ? const Color(0xFF596B78)
                          : const Color(0xFF173B2D),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Record ID: $recordId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isClosed
                          ? const Color(0xFF84919A)
                          : const Color(0xFF637889),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Status
            _statusBadge(isClosed),

            const SizedBox(width: 7),

            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isClosed
                  ? const Color(0xFF7C8992)
                  : Colors.green.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(bool isClosed) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: isClosed
            ? const Color(0xFFE0E7EB)
            : const Color(0xFFDDF5E9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isClosed
                  ? const Color(0xFF637887)
                  : Colors.green.shade700,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isClosed ? 'CLOSED' : 'ACTIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isClosed
                  ? const Color(0xFF526674)
                  : Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }

  String _recordId(
      Map<String, dynamic> data,
      int loanNumber,
      String documentId,
      ) {
    final existing =
    (data['recordId'] ?? '').toString().trim();

    if (existing.isNotEmpty) {
      return existing;
    }

    final openingDate = data['openingDate'];

    if (openingDate is Timestamp) {
      final date = openingDate.toDate();

      final datePart =
          '${date.year}'
          '${date.month.toString().padLeft(2, '0')}'
          '${date.day.toString().padLeft(2, '0')}';

      return 'L${loanNumber.toString().padLeft(3, '0')}'
          '-$datePart';
    }

    return 'L${loanNumber.toString().padLeft(3, '0')}'
        '-${documentId.substring(0, documentId.length > 6 ? 6 : documentId.length)}';
  }
}
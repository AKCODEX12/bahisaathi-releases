
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LoanCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final int loanNumber;
  final String recordId;
  final String name;
  final String amount;
  final Timestamp? openingDate;
  final bool isClosed;
  final String formattedDate;
  final VoidCallback onTap;

  const LoanCard({
    super.key,
    required this.doc,
    required this.loanNumber,
    required this.recordId,
    required this.name,
    required this.amount,
    required this.openingDate,
    required this.isClosed,
    required this.formattedDate,
    required this.onTap,
  });

  Widget _statusBadge(bool isClosed) {
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isClosed
              ? const Color(0xFFF2F4F5)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isClosed
                ? const Color(0xFFD9DEE1)
                : const Color(0xFFE0E9E4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
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
                size: 27,
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
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isClosed
                          ? const Color(0xFF596A76)
                          : const Color(0xFF143C2C),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Record ID: $recordId',
                    style: TextStyle(
                      fontSize: 11,
                      color: isClosed
                          ? const Color(0xFF849099)
                          : const Color(0xFF60788A),
                    ),
                  ),
                  if (name.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    '$formattedDate • $amount',
                    style: TextStyle(
                      fontSize: 11,
                      color: isClosed
                          ? const Color(0xFF849099)
                          : const Color(0xFF60788A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusBadge(isClosed),
                const SizedBox(height: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: isClosed
                      ? const Color(0xFF849099)
                      : Colors.green.shade700,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

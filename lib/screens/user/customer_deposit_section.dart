
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerDepositSection extends StatelessWidget {
  final String loanId;

  const CustomerDepositSection({
    super.key,
    required this.loanId,
  });

  CollectionReference<Map<String, dynamic>> get _deposits =>
      FirebaseFirestore.instance
          .collection('loans')
          .doc(loanId)
          .collection('deposits');

  String formatAmount(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return '₹${amount.toStringAsFixed(0)}';
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    return '-';
  }

  double getAmount(Map<String, dynamic> data) {
    final value = data['amount'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _deposits
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
              ),
            ),
            child: const Text(
              'Unable to load deposits.',
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        double total = 0;

        for (final doc in documents) {
          total += getAmount(doc.data());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.green.withOpacity(0.18),
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.45),
                    shape: BoxShape.rectangle,
                  ),
                  transform: Matrix4.rotationZ(0.785398),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.green.withOpacity(0.18),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Text(
              'Deposit (जमा) Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF143C2C),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                16,
                15,
                16,
                16,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.green.withOpacity(0.18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Text(
                      'TOTAL जमा',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      formatAmount(total),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Deposit History',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            if (documents.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'No deposits added yet.',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ...documents.map((doc) {
                final data = doc.data();

                final description =
                    data['description']?.toString().trim() ?? '';

                return Container(
                  margin: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '₹',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatAmount(data['amount']),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              'Date: ${formatDate(data['date'])}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),

                              Text(
                                'Description: $description',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

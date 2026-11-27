
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DepositSection extends StatelessWidget {
  final String loanId;

  const DepositSection({
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

  Future<void> showDepositDialog(
      BuildContext context, {
        DocumentSnapshot<Map<String, dynamic>>? deposit,
      }) async {
    final data = deposit?.data();

    final amountController = TextEditingController(
      text: data != null ? getAmount(data).toStringAsFixed(0) : '',
    );

    final descriptionController = TextEditingController(
      text: data?['description']?.toString() ?? '',
    );

    DateTime selectedDate =
    data != null && data['date'] is Timestamp
        ? (data['date'] as Timestamp).toDate()
        : DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                deposit == null
                    ? 'Add Deposit / Jama'
                    : 'Edit Deposit / Jama',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter deposit details...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 16),

                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${selectedDate.day.toString().padLeft(2, '0')}/'
                            '${selectedDate.month.toString().padLeft(2, '0')}/'
                            '${selectedDate.year}',
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                        ),
                      );
                      return;
                    }

                    final depositData = {
                      'amount': amount,
                      'date': Timestamp.fromDate(selectedDate),
                      'description':
                      descriptionController.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    try {
                      if (deposit == null) {
                        await _deposits.add({
                          ...depositData,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      } else {
                        await _deposits
                            .doc(deposit.id)
                            .update(depositData);
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to save deposit: $e',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    deposit == null ? 'Add' : 'Save',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    descriptionController.dispose();
  }

  Future<void> deleteDeposit(
      BuildContext context,
      String depositId,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Deposit'),
          content: const Text(
            'Are you sure you want to delete this deposit?',
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _deposits.doc(depositId).delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete deposit: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
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

        final documents = snapshot.data?.docs ?? [];

        double total = 0;

        for (final doc in documents) {
          total += getAmount(doc.data());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SEPARATOR BETWEEN LOAN CARD AND DEPOSIT CARD

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

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Deposit (जमा) Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF143C2C),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // DEPOSIT / JAMA SEPARATE CARD

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
              child: Column(
                children: [
                  // Deposit Header

                  Row(
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
                          'Deposit / Jama',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      Text(
                        formatAmount(total),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Add Deposit Button

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDepositDialog(context);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Add Deposit',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        side: BorderSide(
                          color: Colors.green.withOpacity(1.00),
                        ),
                        foregroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // DEPOSIT HISTORY

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
              ...documents.map(
                    (doc) {
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

                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              showDepositDialog(
                                context,
                                deposit: doc,
                              );
                            } else if (value == 'delete') {
                              deleteDeposit(
                                context,
                                doc.id,
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined),
                                  SizedBox(width: 10),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline),
                                  SizedBox(width: 10),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

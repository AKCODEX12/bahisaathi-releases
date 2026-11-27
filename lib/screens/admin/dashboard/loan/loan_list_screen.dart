import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../deposit_section.dart';
import '../report_selection_screen.dart';
import '../history_reports_screen.dart';
import 'admin_loan_details_screen.dart';
import 'loan_card.dart';

class LoanListScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String accountStatus;

  const LoanListScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    this.accountStatus = 'active',
  });

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> {
  // ================================================================
  // BASIC HELPERS
  // ================================================================

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';

    final date = timestamp.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
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
        ? '${number.toInt()}%'
        : '$number%';
  }

  String recordIdFor(
      Map<String, dynamic> data,
      int loanNumber,
      ) {
    final existing = (data['recordId'] ?? '').toString().trim();

    if (existing.isNotEmpty) {
      return existing;
    }

    final openingDate = data['openingDate'];

    if (openingDate is Timestamp) {
      final date = openingDate.toDate();

      return 'L${loanNumber.toString().padLeft(3, '0')}-'
          '${date.year}'
          '${date.month.toString().padLeft(2, '0')}'
          '${date.day.toString().padLeft(2, '0')}';
    }

    return 'L${loanNumber.toString().padLeft(3, '0')}';
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ================================================================
  // CHANGE CUSTOMER DEPOSIT TYPE
  // ================================================================

  Future<void> changeDepositType(String currentType) async {
    String selectedType =
    currentType == 'interest' ? 'interest' : 'bearing';

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Change Deposit Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: 'bearing',
                    groupValue: selectedType,
                    title: const Text('Bearing Deposit'),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedType = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    value: 'interest',
                    groupValue: selectedType,
                    title: const Text('Interest Deposit'),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedType = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, selectedType);
                  },
                  child: const Text('CONTINUE'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null || selected == currentType) return;

    final oldLabel = currentType == 'interest'
        ? 'Interest Deposit'
        : 'Bearing Deposit';

    final newLabel = selected == 'interest'
        ? 'Interest Deposit'
        : 'Bearing Deposit';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deposit Type Change'),
          content: Text(
            'Old Deposit Type: $oldLabel\n\n'
                'New Deposit Type: $newLabel\n\n'
                'This change will apply to all loans of this customer. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('CONFIRM'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .update({
        'depositType': selected,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showMessage('Deposit Type updated successfully');
      }
    } catch (e) {
      if (mounted) {
        showMessage('Unable to update Deposit Type: $e');
      }
    }
  }

  // ================================================================
  // ADD LOAN
  // ================================================================

  Future<void> showAddLoanDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final rateController = TextEditingController();
    final relationController = TextEditingController();
    final workController = TextEditingController();
    final addressController = TextEditingController();
    final descriptionController = TextEditingController();

    DateTime? openingDate;
    DateTime? dueDate;

    bool isSaving = false;

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> selectOpeningDate() async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: openingDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );

                if (selected != null) {
                  setDialogState(() {
                    openingDate = selected;
                  });
                }
              }

              Future<void> selectDueDate() async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: dueDate ?? openingDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );

                if (selected != null) {
                  setDialogState(() {
                    dueDate = selected;
                  });
                }
              }

              return AlertDialog(
                title: const Text(
                  'Add Loan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _customerReadonlyBox(
                          widget.customerName,
                          widget.customerEmail,
                        ),
                        const SizedBox(height: 16),
                        _inputField(
                          controller: nameController,
                          label: 'Name',
                          hint: 'Loan name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: amountController,
                          label: 'Amount *',
                          hint: 'Enter loan amount',
                          icon: Icons.currency_rupee,
                          number: true,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: rateController,
                          label: 'RatePM *',
                          hint: 'Monthly interest rate',
                          icon: Icons.percent,
                          number: true,
                          suffix: '%',
                        ),
                        const SizedBox(height: 12),
                        _dateField(
                          label: 'OP Date *',
                          value: openingDate,
                          onTap: selectOpeningDate,
                        ),
                        const SizedBox(height: 12),
                        _dateField(
                          label: 'Due Date (Optional)',
                          value: dueDate,
                          onTap: selectDueDate,
                          onClear: dueDate == null
                              ? null
                              : () {
                            setDialogState(() {
                              dueDate = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: relationController,
                          label: "Father's Name / Any Relation",
                          hint: 'Enter relation name',
                          icon: Icons.family_restroom,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: workController,
                          label: 'For Work? *',
                          hint: 'e.g. Business, Personal',
                          icon: Icons.work_outline,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: addressController,
                          label: 'Address',
                          hint: 'Enter address',
                          icon: Icons.location_on_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: descriptionController,
                          label: 'Description',
                          hint: 'Enter loan description',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                      final amountText =
                      amountController.text.trim();

                      final rateText =
                      rateController.text.trim();

                      final work =
                      workController.text.trim();

                      final amount =
                      double.tryParse(amountText);

                      final rate =
                      double.tryParse(rateText);

                      if (amount == null || amount <= 0) {
                        showMessage('Please enter a valid Amount');
                        return;
                      }

                      if (rate == null || rate < 0) {
                        showMessage('Please enter a valid RatePM');
                        return;
                      }

                      if (openingDate == null) {
                        showMessage('Please select OP Date');
                        return;
                      }

                      if (work.isEmpty) {
                        showMessage('Please enter For Work?');
                        return;
                      }

                      if (dueDate != null &&
                          dueDate!.isBefore(openingDate!)) {
                        showMessage(
                          'Due Date cannot be before OP Date',
                        );
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                      });

                      try {
                        final adminUid = FirebaseAuth
                            .instance
                            .currentUser
                            ?.uid;

                        if (adminUid == null) {
                          throw Exception('Admin is not logged in');
                        }

                        await FirebaseFirestore.instance
                            .collection('loans')
                            .add({
                          'adminUid': adminUid,
                          'customerId': widget.customerId,
                          'customerName': widget.customerName,
                          'customerEmail': widget.customerEmail,
                          'name': nameController.text.trim(),
                          'amount': amount,
                          'ratePM': rate,
                          'openingDate':
                          Timestamp.fromDate(openingDate!),
                          'dueDate': dueDate == null
                              ? null
                              : Timestamp.fromDate(dueDate!),
                          'relationName':
                          relationController.text.trim(),
                          'forWork': work,
                          'address': addressController.text.trim(),
                          'description':
                          descriptionController.text.trim(),
                          'status': 'active',
                          'createdAt':
                          FieldValue.serverTimestamp(),
                        });

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (mounted) {
                          showMessage('Loan added successfully');
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                        });

                        if (mounted) {
                          showMessage('Error: $e');
                        }
                      }
                    },
                    child: isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('ADD LOAN'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      amountController.dispose();
      rateController.dispose();
      relationController.dispose();
      workController.dispose();
      addressController.dispose();
      descriptionController.dispose();
    }
  }

  // ================================================================
  // EDIT LOAN
  // ================================================================

  Future<void> showEditLoanDialog(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    final nameController = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );

    final amountController = TextEditingController(
      text: (data['amount'] ?? '').toString(),
    );

    final rateController = TextEditingController(
      text: (data['ratePM'] ?? '').toString(),
    );

    final relationController = TextEditingController(
      text: (data['relationName'] ?? '').toString(),
    );

    final workController = TextEditingController(
      text: (data['forWork'] ?? '').toString(),
    );

    final addressController = TextEditingController(
      text: (data['address'] ?? '').toString(),
    );

    final descriptionController = TextEditingController(
      text: (data['description'] ?? '').toString(),
    );

    DateTime? openingDate;

    if (data['openingDate'] is Timestamp) {
      openingDate = (data['openingDate'] as Timestamp).toDate();
    }

    DateTime? dueDate;

    if (data['dueDate'] is Timestamp) {
      dueDate = (data['dueDate'] as Timestamp).toDate();
    }

    bool isSaving = false;

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> selectOpeningDate() async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: openingDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );

                if (selected != null) {
                  setDialogState(() {
                    openingDate = selected;
                  });
                }
              }

              Future<void> selectDueDate() async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: dueDate ?? openingDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );

                if (selected != null) {
                  setDialogState(() {
                    dueDate = selected;
                  });
                }
              }

              return AlertDialog(
                title: const Text(
                  'Edit Loan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _customerReadonlyBox(
                          (data['customerName'] ?? widget.customerName)
                              .toString(),
                          (data['customerEmail'] ?? widget.customerEmail)
                              .toString(),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Customer Gmail cannot be edited.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _inputField(
                          controller: nameController,
                          label: 'Name',
                          hint: 'Loan name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: amountController,
                          label: 'Amount *',
                          hint: 'Enter loan amount',
                          icon: Icons.currency_rupee,
                          number: true,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: rateController,
                          label: 'RatePM *',
                          hint: 'Monthly interest rate',
                          icon: Icons.percent,
                          number: true,
                          suffix: '%',
                        ),
                        const SizedBox(height: 12),
                        _dateField(
                          label: 'OP Date *',
                          value: openingDate,
                          onTap: selectOpeningDate,
                        ),
                        const SizedBox(height: 12),
                        _dateField(
                          label: 'Due Date (Optional)',
                          value: dueDate,
                          onTap: selectDueDate,
                          onClear: dueDate == null
                              ? null
                              : () {
                            setDialogState(() {
                              dueDate = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: relationController,
                          label: "Father's Name / Any Relation",
                          hint: 'Enter relation name',
                          icon: Icons.family_restroom,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: workController,
                          label: 'For Work? *',
                          hint: 'e.g. Business, Personal',
                          icon: Icons.work_outline,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: addressController,
                          label: 'Address',
                          hint: 'Enter address',
                          icon: Icons.location_on_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        _inputField(
                          controller: descriptionController,
                          label: 'Description',
                          hint: 'Enter loan description',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                      final amount = double.tryParse(
                        amountController.text.trim(),
                      );

                      final rate = double.tryParse(
                        rateController.text.trim(),
                      );

                      final work = workController.text.trim();

                      if (amount == null || amount <= 0) {
                        showMessage('Please enter a valid Amount');
                        return;
                      }

                      if (rate == null || rate < 0) {
                        showMessage('Please enter a valid RatePM');
                        return;
                      }

                      if (openingDate == null) {
                        showMessage('Please select OP Date');
                        return;
                      }

                      if (work.isEmpty) {
                        showMessage('Please enter For Work?');
                        return;
                      }

                      if (dueDate != null &&
                          dueDate!.isBefore(openingDate!)) {
                        showMessage(
                          'Due Date cannot be before OP Date',
                        );
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                      });

                      try {
                        final adminUid = FirebaseAuth
                            .instance
                            .currentUser
                            ?.uid;

                        if (adminUid == null) {
                          throw Exception('Admin is not logged in');
                        }

                        await FirebaseFirestore.instance
                            .collection('loans')
                            .doc(doc.id)
                            .update({
                          'name': nameController.text.trim(),
                          'amount': amount,
                          'ratePM': rate,
                          'openingDate':
                          Timestamp.fromDate(openingDate!),
                          'dueDate': dueDate == null
                              ? null
                              : Timestamp.fromDate(dueDate!),
                          'relationName':
                          relationController.text.trim(),
                          'forWork': work,
                          'address': addressController.text.trim(),
                          'description':
                          descriptionController.text.trim(),
                          'updatedAt':
                          FieldValue.serverTimestamp(),
                        });

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (mounted) {
                          showMessage('Loan updated successfully');
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                        });

                        if (mounted) {
                          showMessage('Error: $e');
                        }
                      }
                    },
                    child: isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('SAVE CHANGES'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      amountController.dispose();
      rateController.dispose();
      relationController.dispose();
      workController.dispose();
      addressController.dispose();
      descriptionController.dispose();
    }
  }

  // ================================================================
  // CLOSE LOAN
  // ================================================================

  Future<void> closeLoan(String loanId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Close Loan?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to close this loan?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('NO'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('YES, CLOSE'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('loans')
          .doc(loanId)
          .update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showMessage('Loan closed successfully');
      }
    } catch (e) {
      if (mounted) {
        showMessage('Unable to close loan: $e');
      }
    }
  }

  // ================================================================
  // REOPEN LOAN
  // ================================================================

  Future<void> reopenLoan(String loanId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Reopen Loan?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'This will change the loan status back to ACTIVE.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('NO'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('YES, REOPEN'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('loans')
          .doc(loanId)
          .update({
        'status': 'active',
        'closedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showMessage('Loan reopened successfully');
      }
    } catch (e) {
      if (mounted) {
        showMessage('Unable to reopen loan: $e');
      }
    }
  }

  // ================================================================
  // COMMON UI
  // ================================================================

  Widget _customerReadonlyBox(String name, String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDCE8E2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.email_outlined,
                size: 15,
                color: Colors.grey,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              const Icon(
                Icons.lock_outline,
                size: 15,
                color: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool number = false,
    String? suffix,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month),
          border: const OutlineInputBorder(),
          suffixIcon: onClear == null
              ? null
              : IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.clear),
          ),
        ),
        child: Text(
          value == null ? 'Select date' : formatDateTime(value),
        ),
      ),
    );
  }

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

  // ================================================================
  // SECTION TITLE
  // ================================================================

  Widget _sectionTitle({
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

  Widget _detailRow(
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

  // ================================================================
  // COMPACT LOAN CARD
  // ================================================================

  Widget _compactLoanCard(
      QueryDocumentSnapshot doc,
      int loanNumber,
      ) {
    final data = doc.data() as Map<String, dynamic>;

    final isClosed =
        (data['status'] ?? 'active').toString().toLowerCase() ==
            'closed';

    final recordId = recordIdFor(data, loanNumber);

    final name = (data['name'] ?? data['customerName'] ?? '')
        .toString()
        .trim();

    final amount = formatAmount(data['amount']);

    final openingDate = data['openingDate'] is Timestamp
        ? data['openingDate'] as Timestamp
        : null;

    return LoanCard(
      doc: doc,
      loanNumber: loanNumber,
      recordId: recordId,
      name: name,
      amount: amount,
      openingDate: openingDate,
      isClosed: isClosed,
      formattedDate: formatDate(openingDate),
      onTap: () {
        openLoanDetails(doc, loanNumber);
      },
    );
  }
  // ================================================================
  // OPEN DETAILS
  // ================================================================

  void openLoanDetails(
      QueryDocumentSnapshot doc,
      int loanNumber,
      ) {
    final data = doc.data() as Map<String, dynamic>;

    final recordId = recordIdFor(data, loanNumber);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return AdminLoanDetailsScreen(
            loanId: doc.id,
            data: data,
            loanNumber: loanNumber,
            recordId: recordId,
            onEdit: () {
              showEditLoanDialog(doc);
            },
            onClose: () {
              closeLoan(doc.id);
            },
            onReopen: () {
              reopenLoan(doc.id);
            },
          );
        },
      ),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    if (adminUid == null) {
      return const Scaffold(
        body: Center(
          child: Text('Admin login required'),
        ),
      );
    }

    final accountStatus = widget.accountStatus.toLowerCase();

    final isInactive = accountStatus == 'inactive';
    final isDisabled = accountStatus == 'disabled';

    final screenOpacity = isDisabled
        ? 0.55
        : isInactive
        ? 0.75
        : 1.0;

    return Scaffold(
      backgroundColor: isDisabled
          ? const Color(0xFFE1E3E5)
          : isInactive
          ? const Color(0xFFECEEEF)
          : const Color(0xFFF6F9F8),

      appBar: AppBar(
        title: const Text(
          'Loan List',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDisabled
            ? Colors.blueGrey.shade800
            : isInactive
            ? Colors.blueGrey.shade600
            : Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onSelected: (value) {
              if (value == 'generate_report') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportSelectionScreen(
                      customerId: widget.customerId,
                      customerName: widget.customerName,
                      customerEmail: widget.customerEmail,
                      adminUid: adminUid,
                    ),
                  ),
                );
              }

              if (value == 'history_reports') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistoryReportsScreen(
                      customerId: widget.customerId,
                      customerName: widget.customerName,
                      customerEmail: widget.customerEmail,
                      adminUid: adminUid,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'generate_report',
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: Colors.green,
                    ),
                    SizedBox(width: 10),
                    Text('Generate Loan Report'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'history_reports',
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Colors.blueGrey,
                    ),
                    SizedBox(width: 10),
                    Text('History Reports'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddLoanDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Loan'),
      ),

      body: Opacity(
        opacity: screenOpacity,
        child: Column(
          children: [
            // ========================================================
            // CUSTOMER HEADER
            // ========================================================

            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .doc(widget.customerId)
                  .snapshots(),
              builder: (context, customerSnapshot) {
                final customerData =
                    customerSnapshot.data?.data() ?? {};

                final depositType =
                (customerData['depositType'] ?? 'bearing')
                    .toString()
                    .toLowerCase() ==
                    'interest'
                    ? 'interest'
                    : 'bearing';

                final depositLabel = depositType == 'interest'
                    ? 'Interest Deposit'
                    : 'Bearing Deposit';

                final status = widget.accountStatus.toLowerCase();

                final statusLabel = status == 'disabled'
                    ? 'DISABLED'
                    : status == 'inactive'
                    ? 'INACTIVE'
                    : 'ACTIVE';

                final statusColor = status == 'disabled'
                    ? Colors.red.shade700
                    : status == 'inactive'
                    ? Colors.orange.shade800
                    : Colors.green.shade700;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE0E9E4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F5EA),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.person_outline,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.customerName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF143C2C),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.customerEmail,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment:
                                WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                      statusColor.withOpacity(0.10),
                                      borderRadius:
                                      BorderRadius.circular(20),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.35),
                                      ),
                                    ),
                                    child: Text(
                                      'ACCOUNT: $statusLabel',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF3EE),
                                      borderRadius:
                                      BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      depositLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Change Deposit Type',
                          onPressed: customerSnapshot.connectionState ==
                              ConnectionState.waiting
                              ? null
                              : () => changeDepositType(depositType),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'LOAN LIST',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF143C2C),
                  ),
                ),
              ),
            ),

            // ========================================================
            // LOAN STREAM
            // ========================================================

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('loans')
                    .where('adminUid', isEqualTo: adminUid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Something went wrong:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final allLoans = snapshot.data?.docs ?? [];

                  final customerLoans = allLoans.where((doc) {
                    final data =
                    doc.data() as Map<String, dynamic>;

                    final customerId =
                    (data['customerId'] ?? '').toString();

                    final customerEmail =
                    (data['customerEmail'] ?? '').toString();

                    return customerId == widget.customerId ||
                        customerEmail == widget.customerEmail;
                  }).toList();

                  // Latest loan first.
                  customerLoans.sort((a, b) {
                    final aData =
                    a.data() as Map<String, dynamic>;

                    final bData =
                    b.data() as Map<String, dynamic>;

                    final aTime = aData['createdAt'] is Timestamp
                        ? (aData['createdAt'] as Timestamp)
                        .millisecondsSinceEpoch
                        : 0;

                    final bTime = bData['createdAt'] is Timestamp
                        ? (bData['createdAt'] as Timestamp)
                        .millisecondsSinceEpoch
                        : 0;

                    return bTime.compareTo(aTime);
                  });

                  if (customerLoans.isEmpty) {
                    return const Center(
                      child: Text(
                        'No loan added yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 100),
                    itemCount: customerLoans.length,
                    itemBuilder: (context, index) {
                      return _compactLoanCard(
                        customerLoans[index],
                        index + 1,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

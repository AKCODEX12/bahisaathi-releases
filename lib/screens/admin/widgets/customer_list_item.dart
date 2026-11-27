
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../dashboard/loan/loan_list_screen.dart';

class CustomerListItem extends StatefulWidget {
  final Map<String, dynamic> customer;
  final int serialNumber;

  const CustomerListItem({
    super.key,
    required this.customer,
    required this.serialNumber,
  });

  @override
  State<CustomerListItem> createState() => _CustomerListItemState();
}

class _CustomerListItemState extends State<CustomerListItem> {
  static const Color _green = Color(0xFF168653);
  static const Color _dark = Color(0xFF19352A);

  bool _isUpdatingStatus = false;

  String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'inactive':
        return 'Inactive';
      case 'disabled':
        return 'Disabled';
      default:
        return 'Active';
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'inactive':
        return const Color(0xFFB7791F);
      case 'disabled':
        return const Color(0xFFC74747);
      default:
        return _green;
    }
  }

  Color getStatusBackground(String status) {
    switch (status.toLowerCase()) {
      case 'inactive':
        return const Color(0xFFFFF4E2);
      case 'disabled':
        return const Color(0xFFFFEAEA);
      default:
        return const Color(0xFFE7F4EC);
    }
  }

  Future<void> _changeAccountStatus() async {
    debugPrint('STATUS: Edit button tapped');

    final relationshipId =
    widget.customer['_relationshipId']?.toString();

    if (relationshipId == null || relationshipId.isEmpty) {
      _showMessage('Customer relationship not found');
      return;
    }

    final currentStatus =
        widget.customer['_accountStatus']?.toString().toLowerCase() ??
            'active';

    final selectedStatus = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text(
            'Change Account Status',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          children: [
            _statusOption(
              dialogContext,
              'active',
              'Active',
              currentStatus,
            ),
            _statusOption(
              dialogContext,
              'inactive',
              'Inactive',
              currentStatus,
            ),
            _statusOption(
              dialogContext,
              'disabled',
              'Disabled',
              currentStatus,
            ),
          ],
        );
      },
    );

    if (!mounted || selectedStatus == null) {
      return;
    }
    debugPrint('STATUS: Selected = $selectedStatus');

    if (selectedStatus == currentStatus) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Confirm Status Change',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Change account status from '
                '${getStatusLabel(currentStatus)} to '
                '${getStatusLabel(selectedStatus)}?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 15),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Confirm',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }
    debugPrint('STATUS: Confirmed');

    setState(() {
      _isUpdatingStatus = true;
    });

    try {

      await FirebaseFirestore.instance
          .collection('admin_customers')
          .doc(relationshipId)
          .update({
        'accountStatus': selectedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final check = await FirebaseFirestore.instance
          .collection('admin_customers')
          .doc(relationshipId)
          .get();

      debugPrint('UPDATED RELATIONSHIP: ${check.data()}');
      debugPrint('STATUS: Firestore update successful');

      if (!mounted) return;

// Update successful hone par local status bhi badlo.
      setState(() {
        widget.customer['_accountStatus'] = selectedStatus;
      });

      _showMessage(
        'Account status changed to '
            '${getStatusLabel(selectedStatus)}',
      );

    } catch (e) {
      debugPrint('STATUS ERROR: $e');
      if (!mounted) return;

      _showMessage('Unable to update status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  SimpleDialogOption _statusOption(
      BuildContext dialogContext,
      String value,
      String label,
      String currentStatus,
      ) {
    final selected = value == currentStatus;

    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(dialogContext, value);
      },
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? _green : const Color(0xFF9AA79F),
            size: 22,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight:
              selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? _green : _dark,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 15),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: getStatusBackground(status),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: getStatusColor(status).withOpacity(0.12),
        ),
      ),
      child: Text(
        getStatusLabel(status),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: getStatusColor(status),
        ),
      ),
    );
  }

  Widget _buildStatusEditButton() {
    return SizedBox(
      height: 32,
      width: 32,
      child: _isUpdatingStatus
          ? const Padding(
        padding: EdgeInsets.all(7),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _green,
        ),
      )
          : IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: 'Change status',
        onPressed: _changeAccountStatus,
        icon: const Icon(
          Icons.edit_rounded,
          size: 18,
          color: _green,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String value,
  }) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: const Color(0xFF83948A),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF53645A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;

    final customerId =
        customer['_customerId']?.toString() ?? '';

    final customerName =
        customer['name']?.toString() ?? '';

    final customerEmail =
        customer['email']?.toString() ?? '';

    final optionalName =
        customer['optionalName']?.toString() ?? '';

    final mobile =
        customer['mobile']?.toString() ?? '';

    final accountStatus =
        customer['_accountStatus']?.toString().toLowerCase() ??
            'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE1E9E3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF19352A).withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LoanListScreen(
                  customerId: customerId,
                  customerName: customerName,
                  customerEmail: customerEmail,
                  accountStatus: accountStatus,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 10, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 29,
                      width: 29,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4EC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.serialNumber.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName.isEmpty
                                ? 'Unnamed Customer'
                                : customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (optionalName.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              optionalName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF83948A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    _buildStatusBadge(accountStatus),
                    _buildStatusEditButton(),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: Color(0xFF7C9385),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.mail_outline_rounded,
                  value: customerEmail,
                ),
                if (customerEmail.isNotEmpty && mobile.isNotEmpty)
                  const SizedBox(height: 7),
                _buildDetailRow(
                  icon: Icons.phone_rounded,
                  value: mobile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

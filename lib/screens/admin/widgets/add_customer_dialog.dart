
import 'package:flutter/material.dart';

import '../../../services/customer_service.dart';

class AddCustomerDialog extends StatefulWidget {
  final String adminUid;

  const AddCustomerDialog({
    super.key,
    required this.adminUid,
  });

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final CustomerService _customerService = CustomerService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController optionalNameController =
  TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController descriptionController =
  TextEditingController();

  bool isLoading = false;

  // Default Deposit Type.
  String selectedDepositType = 'bearing';

  @override
  void dispose() {
    nameController.dispose();
    optionalNameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    addressController.dispose();
    descriptionController.dispose();

    super.dispose();
  }

  void showMessage(String message) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
      entry.dispose();
    });
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  Future<void> submitCustomer() async {
    if (isLoading) return;

    final name = nameController.text.trim();
    final optionalName = optionalNameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final mobile = mobileController.text.trim();
    final address = addressController.text.trim();
    final description = descriptionController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      showMessage('Name and Email are required.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final result = await _customerService.addCustomer(
      adminUid: widget.adminUid,
      name: name,
      optionalName: optionalName,
      email: email,
      mobile: mobile,
      address: address,
      description: description,
      depositType: selectedDepositType,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (!result.success) {
      showMessage(result.message);
      return;
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildDepositTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deposit Type',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                title: const Text('Bearing Deposit'),
                value: 'bearing',
                groupValue: selectedDepositType,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: isLoading
                    ? null
                    : (value) {
                  if (value == null) return;
                  setState(() {
                    selectedDepositType = value;
                  });
                },
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              RadioListTile<String>(
                title: const Text('Interest Deposit'),
                value: 'interest',
                groupValue: selectedDepositType,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: isLoading
                    ? null
                    : (value) {
                  if (value == null) return;
                  setState(() {
                    selectedDepositType = value;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add Customer',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              enabled: !isLoading,
              decoration: _decoration('Name'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: optionalNameController,
              enabled: !isLoading,
              decoration: _decoration('Optional Name'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: emailController,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              decoration: _decoration('Email'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: mobileController,
              enabled: !isLoading,
              keyboardType: TextInputType.phone,
              decoration: _decoration('Mobile No.'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: addressController,
              enabled: !isLoading,
              maxLines: 2,
              decoration: _decoration('Address'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: descriptionController,
              enabled: !isLoading,
              maxLines: 3,
              decoration: _decoration('Description'),
            ),
            const SizedBox(height: 16),

            _buildDepositTypeSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : submitCustomer,
          child: isLoading
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Text('Add'),
        ),
      ],
    );
  }
}

Future<void> showAddCustomerDialog(
    BuildContext context,
    String adminUid,
    ) async {
  await showDialog(
    context: context,
    builder: (dialogContext) {
      return AddCustomerDialog(adminUid: adminUid);
    },
  );
}

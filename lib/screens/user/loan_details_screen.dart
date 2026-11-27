import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'customer_loan_acceptance_screen.dart';
import 'dart:convert';
import 'customer_deposit_section.dart';

// ================================================================
// LOAN DETAILS SCREEN
// ================================================================

class LoanDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final int loanNumber;
  final String recordId;
  final String loanDocumentId;

  const LoanDetailsScreen({
    super.key,
    required this.data,
    required this.loanNumber,
    required this.recordId,
    required this.loanDocumentId,
  });

  Widget _statusBadge(bool isClosed) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: isClosed
            ? Colors.grey.shade200
            : Colors.green.shade50,
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
            isClosed
                ? Icons.lock_outline
                : Icons.verified,
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
    final bool isClosed =
        (data['status'] ?? '').toString().toLowerCase() == 'closed';

    return Scaffold(
      backgroundColor: isClosed
          ? const Color(0xFFEEF1F3)
          : const Color(0xFFF7FAF9),
      appBar: AppBar(
        title: const Text(
          'Loan Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: isClosed
            ? const Color(0xFF71808C)
            : Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Existing Customer Loan Details card
            _fullLoanCard(
              context,
              isClosed,
            ),

            const SizedBox(height: 18),

            // Customer Deposit Details
            CustomerDepositSection(
              loanId: loanDocumentId,
            ),
          ],
        ),
      ),

    );
  }

  Widget _fullLoanCard(
      BuildContext context,
      bool isClosed,
      ) {
    final String name =
    (data['name'] ?? data['customerName'] ?? '')
        .toString()
        .trim();

    final String email =
    (data['customerEmail'] ?? '')
        .toString()
        .trim();

    final String purpose =
    (data['forWork'] ?? '')
        .toString()
        .trim();

    final String address =
    (data['address'] ?? '')
        .toString()
        .trim();

    final String relationName =
    (data['relationName'] ?? '')
        .toString()
        .trim();

    final String description =
    (data['description'] ?? '')
        .toString()
        .trim();

    final String amount =
    _formatAmount(data['amount']);

    final String rate =
    _formatRate(data['ratePM']);

    final String openingDate =
    _formatDate(data['openingDate']);

    final String dueDate =
    _formatDate(data['dueDate']);

    final String adminId =
    (data['adminUid'] ?? '').toString();

    final String adminName =
    (data['adminName'] ?? 'Admin').toString().trim();

    return Opacity(
      opacity: isClosed ? 0.78 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          14,
        ),
        decoration: BoxDecoration(
          color: isClosed
              ? const Color(0xFFF2F4F5)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isClosed
                ? const Color(0xFFD1D8DD)
                : const Color(0xFFDCE8E3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                isClosed ? 0.025 : 0.055,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // HEADER
            // ==================================================

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

                _statusBadge(isClosed),
              ],
            ),

            const SizedBox(height: 14),

            Divider(
              color: isClosed
                  ? const Color(0xFFD6DCE0)
                  : const Color(0xFFE1E9E5),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // BORROWER DETAILS
            // ==================================================

            _sectionTitle(
              icon: Icons.person_outline,
              title: 'Borrower Details',
              isClosed: isClosed,
            ),

            const SizedBox(height: 12),

            if (name.isNotEmpty)
              _detailRow('Name', name, isClosed),

            if (email.isNotEmpty)
              _detailRow('Email', email, isClosed),

            if (purpose.isNotEmpty)
              _detailRow('Purpose', purpose, isClosed),

            if (relationName.isNotEmpty)
              _detailRow('Father / Relation', relationName, isClosed),

            if (address.isNotEmpty)
              _detailRow('Address', address, isClosed),

            const SizedBox(height: 8),

            Divider(
              color: isClosed
                  ? const Color(0xFFD6DCE0)
                  : const Color(0xFFE1E9E5),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // LOAN DETAILS + VERIFIED SEAL
            // ==================================================

            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 82),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Loan Details',
                        isClosed: isClosed,
                      ),

                      const SizedBox(height: 12),

                      _detailRow(
                        'Principal Amount',
                        amount,
                        isClosed,
                        boldValue: true,
                      ),

                      _detailRow(
                        'Interest Rate',
                        rate,
                        isClosed,
                      ),

                      _detailRow(
                        'Opening Date',
                        openingDate,
                        isClosed,
                      ),

                      if (dueDate.isNotEmpty && dueDate != '-')
                        _detailRow(
                          'Due Date',
                          dueDate,
                          isClosed,
                        ),
                    ],
                  ),
                ),

                // VERIFIED SEAL
                Positioned(
                  top: 10,
                  right: 0,
                  child: _verifiedSeal(isClosed),
                ),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              _detailRow(
                'Description',
                description,
                isClosed,
              ),
            ],

            const SizedBox(height: 18),

            // ==================================================
            // ADMIN + CUSTOMER SIGNATURE
            // ==================================================

            Container(
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
                  // ADMIN
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isClosed
                                ? const Color(0xFFDCE2E5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings_outlined,
                            color: isClosed
                                ? const Color(0xFF697984)
                                : Colors.green.shade700,
                            size: 22,
                          ),
                        ),

                        const SizedBox(width: 9),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'By Admin',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isClosed
                                      ? const Color(0xFF65747E)
                                      : const Color(0xFF1A4B39),
                                ),
                              ),

                              const SizedBox(height: 5),

                              if (adminName.isNotEmpty)
                                Text(
                                  adminName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isClosed
                                        ? const Color(0xFF72808A)
                                        : const Color(0xFF476678),
                                  ),
                                ),

                              const SizedBox(height: 3),

                              Text(
                                'Admin ID: ${_shortAdminId(adminId)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isClosed
                                      ? const Color(0xFF849098)
                                      : const Color(0xFF718797),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    width: 1,
                    height: 58,
                    color: isClosed
                        ? const Color(0xFFC8D0D5)
                        : const Color(0xFFD1E2DB),
                  ),

                  const SizedBox(width: 12),

                  // CUSTOMER SIGNATURE - ACCEPTANCE SYSTEM
                  _customerSignatureBox(context, isClosed),
                ],
              ),
            ),

            const SizedBox(height: 13),

            // ==================================================
            // FOOTER
            // ==================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 10,
              ),
              decoration: BoxDecoration(
                color: isClosed
                    ? const Color(0xFFE7EBED)
                    : const Color(0xFFEAF7F2),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 17,
                    color: isClosed
                        ? const Color(0xFF6A7984)
                        : Colors.green.shade700,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Loan Record  •  View Only  •  Digitally Recorded',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isClosed
                            ? const Color(0xFF657580)
                            : const Color(0xFF4E6E62),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOMER SIGNATURE BOX
  // ============================================================


  Widget _customerSignatureBox(
      BuildContext context,
      bool isClosed,
      ) {
    final loanRef = FirebaseFirestore.instance
        .collection('loans')
        .doc(loanDocumentId);

    return SizedBox(
      width: 112,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: loanRef.snapshots(),
        builder: (context, snapshot) {
          final latestData = snapshot.data?.data();

          final String signatureBase64 =
          (latestData?['customerSignatureBase64'] ?? '')
              .toString()
              .trim();

          final bool isAccepted =
              latestData?['customerAcceptanceStatus'] == 'accepted';

          Widget signatureContent;

          if (isAccepted && signatureBase64.isNotEmpty) {
            try {
              signatureContent = ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.memory(
                  base64Decode(signatureBase64),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) {
                    return _signaturePlaceholder(isClosed);
                  },
                ),
              );
            } catch (_) {
              signatureContent = _signaturePlaceholder(isClosed);
            }
          } else {
            signatureContent = _signaturePlaceholder(isClosed);
          }

          return Column(
            children: [
              Text(
                'Customer Signature',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isClosed
                      ? const Color(0xFF72808A)
                      : const Color(0xFF537184),
                ),
              ),

              const SizedBox(height: 5),

              GestureDetector(
                onTap: isClosed || isAccepted
                    ? null
                    : () => _showAcceptanceOptions(context),
                child: Container(
                  height: 45,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isClosed
                        ? const Color(0xFFEFF1F2)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: isClosed
                          ? const Color(0xFFC8D0D4)
                          : const Color(0xFFD1E0E5),
                    ),
                  ),
                  child: signatureContent,
                ),
              ),

              if (isAccepted) ...[
                const SizedBox(height: 4),
                const Text(
                  'Accepted',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  isClosed ? 'Closed' : 'Tap to accept',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }


  // ============================================================
  // ACCEPTANCE OPTIONS POPUP
  // ============================================================

  void _showAcceptanceOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'लोन स्वीकार करें',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.draw,
                  color: Colors.green,
                ),
                title: const Text('हस्ताक्षर करें'),
                onTap: () {
                  Navigator.pop(dialogContext);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerLoanAcceptanceScreen(
                        loanId: loanDocumentId,
                        markType: LoanMarkType.signature,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.fingerprint,
                  color: Colors.green,
                ),
                title: const Text('अंगूठे का निशान लगाएँ'),
                onTap: () {
                  Navigator.pop(dialogContext);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerLoanAcceptanceScreen(
                        loanId: loanDocumentId,
                        markType: LoanMarkType.thumb,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required bool isClosed,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 26,
          color: isClosed
              ? const Color(0xFF687985)
              : Colors.green.shade700,
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isClosed
                ? const Color(0xFF596A76)
                : const Color(0xFF174B38),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow(
      String title,
      String value,
      bool isClosed, {
        bool boldValue = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isClosed
                    ? const Color(0xFF7A8790)
                    : const Color(0xFF657B8B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const Text(
            ':',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: boldValue
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: isClosed
                    ? const Color(0xFF697780)
                    : const Color(0xFF172C3D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VERIFIED SEAL
  // ============================================================

  Widget _verifiedSeal(bool isClosed) {
    return Transform.rotate(
      angle: -0.12,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isClosed
                ? const Color(0xFF8495A1)
                : Colors.green.shade700,
            width: 2,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isClosed
                  ? const Color(0xFF9BA8B0)
                  : Colors.green.shade400,
              width: 1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified,
                  size: 17,
                  color: isClosed
                      ? const Color(0xFF788A96)
                      : Colors.green.shade700,
                ),
                const SizedBox(height: 1),
                Text(
                  'VERIFIED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: isClosed
                        ? const Color(0xFF667985)
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SIGNATURE PLACEHOLDER
  // ============================================================

  Widget _signaturePlaceholder(bool isClosed) {
    return Center(
      child: Text(
        'Signature pending',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 8,
          fontStyle: FontStyle.italic,
          color: isClosed
              ? const Color(0xFF929DA3)
              : const Color(0xFF91A0A8),
        ),
      ),
    );
  }

  // ============================================================
  // AMOUNT FORMAT
  // ============================================================

  String _formatAmount(dynamic value) {
    if (value == null) {
      return '₹0';
    }

    double? number;

    if (value is num) {
      number = value.toDouble();
    } else {
      number = double.tryParse(
        value.toString().replaceAll(',', ''),
      );
    }

    if (number == null) {
      return '₹${value.toString()}';
    }

    final int amount = number.round();

    final formatted = _indianNumberFormat(amount);
    final hindi = _numberToHindi(amount);

    return '₹$formatted ($hindi)';
  }

  // ============================================================
  // INDIAN NUMBER FORMAT
  // ============================================================

  String _indianNumberFormat(int number) {
    final String value = number.toString();

    if (value.length <= 3) {
      return value;
    }

    String lastThree =
    value.substring(value.length - 3);

    String remaining =
    value.substring(0, value.length - 3);

    final List<String> parts = [];

    while (remaining.length > 2) {
      parts.insert(
        0,
        remaining.substring(
          remaining.length - 2,
        ),
      );

      remaining = remaining.substring(
        0,
        remaining.length - 2,
      );
    }

    if (remaining.isNotEmpty) {
      parts.insert(0, remaining);
    }

    return '${parts.join(',')},$lastThree';
  }

  // ============================================================
  // HINDI NUMBER WORDS
  // ============================================================

  String _numberToHindi(int number) {
    if (number == 0) {
      return 'शून्य';
    }

    if (number < 0) {
      return 'माइनस ${_numberToHindi(-number)}';
    }

    final List<String> ones = [
      '',
      'एक',
      'दो',
      'तीन',
      'चार',
      'पाँच',
      'छह',
      'सात',
      'आठ',
      'नौ',
      'दस',
      'ग्यारह',
      'बारह',
      'तेरह',
      'चौदह',
      'पंद्रह',
      'सोलह',
      'सत्रह',
      'अठारह',
      'उन्नीस',
      'बीस',
      'इक्कीस',
      'बाईस',
      'तेईस',
      'चौबीस',
      'पच्चीस',
      'छब्बीस',
      'सत्ताईस',
      'अट्ठाईस',
      'उनतीस',
      'तीस',
      'इकतीस',
      'बत्तीस',
      'तैंतीस',
      'चौंतीस',
      'पैंतीस',
      'छत्तीस',
      'सैंतीस',
      'अड़तीस',
      'उनतालीस',
      'चालीस',
      'इकतालीस',
      'बयालीस',
      'तैंतालीस',
      'चवालीस',
      'पैंतालीस',
      'छियालीस',
      'सैंतालीस',
      'अड़तालीस',
      'उनचास',
      'पचास',
      'इक्यावन',
      'बावन',
      'तिरेपन',
      'चौवन',
      'पचपन',
      'छप्पन',
      'सत्तावन',
      'अट्ठावन',
      'उनसठ',
      'साठ',
      'इकसठ',
      'बासठ',
      'तिरसठ',
      'चौंसठ',
      'पैंसठ',
      'छियासठ',
      'सड़सठ',
      'अड़सठ',
      'उनहत्तर',
      'सत्तर',
      'इकहत्तर',
      'बहत्तर',
      'तिहत्तर',
      'चौहत्तर',
      'पचहत्तर',
      'छिहत्तर',
      'सतहत्तर',
      'अठहत्तर',
      'उनासी',
      'अस्सी',
      'इक्यासी',
      'बयासी',
      'तिरासी',
      'चौरासी',
      'पचासी',
      'छियासी',
      'सतासी',
      'अट्ठासी',
      'नवासी',
      'नब्बे',
      'इक्यानवे',
      'बानवे',
      'तिरानवे',
      'चौरानवे',
      'पंचानवे',
      'छियानवे',
      'सत्तानवे',
      'अट्ठानवे',
      'निन्यानवे',
    ];

    String convertBelow100(int n) {
      return ones[n];
    }

    String convertBelow1000(int n) {
      final List<String> parts = [];

      if (n >= 100) {
        parts.add('${ones[n ~/ 100]} सौ');
        n %= 100;
      }

      if (n > 0) {
        parts.add(convertBelow100(n));
      }

      return parts.join(' ');
    }

    final List<String> parts = [];

    if (number >= 10000000) {
      final crore = number ~/ 10000000;
      parts.add('${_numberToHindi(crore)} करोड़');
      number %= 10000000;
    }

    if (number >= 100000) {
      final lakh = number ~/ 100000;
      parts.add('${_numberToHindi(lakh)} लाख');
      number %= 100000;
    }

    if (number >= 1000) {
      final thousand = number ~/ 1000;
      parts.add('${_numberToHindi(thousand)} हजार');
      number %= 1000;
    }

    if (number > 0) {
      parts.add(convertBelow1000(number));
    }

    return parts.join(' ');
  }

  // ============================================================
  // RATE
  // ============================================================

  String _formatRate(dynamic value) {
    if (value == null) {
      return '-';
    }

    final String rate = value.toString();

    return '$rate% per month';
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(dynamic value) {
    if (value == null) {
      return '-';
    }

    if (value is Timestamp) {
      final date = value.toDate();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    if (value is DateTime) {
      return '${value.day.toString().padLeft(2, '0')}/'
          '${value.month.toString().padLeft(2, '0')}/'
          '${value.year}';
    }

    final String text = value.toString().trim();

    return text.isEmpty ? '-' : text;
  }

  String _shortAdminId(String id) {
    if (id.isEmpty) {
      return '-';
    }

    if (id.length <= 18) {
      return id;
    }

    return '${id.substring(0, 10)}...';
  }
}
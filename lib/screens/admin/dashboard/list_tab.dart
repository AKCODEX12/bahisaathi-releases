
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/add_customer_dialog.dart';
import '../widgets/customer_list_item.dart';

class ListTab extends StatefulWidget {
  const ListTab({super.key});

  @override
  State<ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<ListTab> {
  static const Color _green = Color(0xFF168653);
  static const Color _dark = Color(0xFF19352A);
  static const Color _background = Color(0xFFF3F7F4);

  final TextEditingController searchController =
  TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  String searchText = '';
  bool _searchFocused = false;

  String _selectedStatus = 'all';

  int _totalCustomerCount = 0;

  String? _relationshipKey;
  Future<List<Map<String, dynamic>>>? _customersFuture;

  @override
  void initState() {
    super.initState();

    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _searchFocused = _searchFocusNode.hasFocus;
        });
      }
    });
  }

  bool matchesSearch(Map<String, dynamic> customer) {
    if (searchText.isEmpty) {
      return true;
    }

    final name =
        customer['name']?.toString().toLowerCase() ?? '';

    final optionalName =
        customer['optionalName']?.toString().toLowerCase() ?? '';

    final email =
        customer['email']?.toString().toLowerCase() ?? '';

    final mobile =
        customer['mobile']?.toString().toLowerCase() ?? '';

    final serial =
        customer['_serial']?.toString().toLowerCase() ?? '';

    return name.contains(searchText) ||
        optionalName.contains(searchText) ||
        email.contains(searchText) ||
        mobile.contains(searchText) ||
        serial.contains(searchText);
  }

  bool matchesStatus(Map<String, dynamic> customer) {
    if (_selectedStatus == 'all') {
      return true;
    }

    final status =
        customer['_accountStatus']?.toString().toLowerCase() ??
            'active';

    return status == _selectedStatus;
  }

  Future<List<Map<String, dynamic>>> _loadCustomers(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      relationships,
      ) async {
    final results = await Future.wait(
      relationships.asMap().entries.map((entry) async {
        final index = entry.key;
        final relationship = entry.value;
        final relationshipData = relationship.data();

        final customerUid =
        relationshipData['customerUid']?.toString();

        if (customerUid == null || customerUid.isEmpty) {
          return null;
        }

        final customerDocument = await FirebaseFirestore.instance
            .collection('customers')
            .doc(customerUid)
            .get();

        if (!customerDocument.exists) {
          return null;
        }

        final customerData = customerDocument.data();

        if (customerData == null) {
          return null;
        }

        final savedStatus =
        relationshipData['accountStatus']
            ?.toString()
            .toLowerCase();

        final accountStatus =
        ['active', 'inactive', 'disabled'].contains(savedStatus)
            ? savedStatus!
            : 'active';

        return <String, dynamic>{
          ...customerData,
          '_serial': index + 1,
          '_customerId': customerUid,
          '_relationshipId': relationship.id,
          '_accountStatus': accountStatus,
        };
      }),
    );

    return results.whereType<Map<String, dynamic>>().toList();
  }


  Future<List<Map<String, dynamic>>> _getCustomersFuture(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> relationships,
      ) {
    final newKey = relationships.map((document) {
      final data = document.data();
      final status = data['accountStatus'] ?? 'active';

      return '${document.id}:$status';
    }).join('|');

    if (_customersFuture == null || _relationshipKey != newKey) {
      _relationshipKey = newKey;

      _customersFuture = _loadCustomers(relationships);

      _customersFuture!.then((customers) {
        if (mounted && _relationshipKey == newKey) {
          setState(() {
            _totalCustomerCount = customers.length;
          });
        }
      });
    }

    return _customersFuture!;
  }


  @override
  void dispose() {
    searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // TOP SUMMARY CARD
  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE1E9E3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF19352A).withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TOTAL CUSTOMERS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF718078),
                  ),
                ),
              ),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: _green,
                  size: 21,
                ),
              ),
            ],
          ),

          const SizedBox(height: 2),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_totalCustomerCount',
                style: const TextStyle(
                  fontSize: 29,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: _dark,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Accounts',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: _buildSearchField(),
              ),
              const SizedBox(width: 8),
              _buildStatusFilter(),
            ],
          ),
        ],
      ),
    );
  }

  // SEARCH FIELD
  Widget _buildSearchField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _searchFocused
              ? _green.withOpacity(0.55)
              : const Color(0xFFE4EAE5),
          width: _searchFocused ? 1.3 : 1,
        ),
      ),
      child: TextField(
        controller: searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) {
          setState(() {
            searchText = value.trim().toLowerCase();
          });
        },
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _dark,
        ),
        decoration: InputDecoration(
          hintText: 'Search customers...',
          hintStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8A9890),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _green,
            size: 21,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
          ),
          suffixIcon: searchText.isNotEmpty
              ? IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              searchController.clear();
              setState(() {
                searchText = '';
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 19,
              color: Color(0xFF82918A),
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // STATUS FILTER
  Widget _buildStatusFilter() {
    final isFiltered = _selectedStatus != 'all';

    return PopupMenuButton<String>(
      tooltip: 'Filter customers by status',
      onSelected: (value) {
        setState(() {
          _selectedStatus = value;
        });
      },
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      itemBuilder: (context) => [
        _buildFilterItem('all', 'All Customers'),
        _buildFilterItem('active', 'Active'),
        _buildFilterItem('inactive', 'Inactive'),
        _buildFilterItem('disabled', 'Disabled'),
      ],
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: isFiltered
              ? const Color(0xFFE8F4EC)
              : const Color(0xFFF7F9F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFiltered
                ? _green.withOpacity(0.45)
                : const Color(0xFFE4EAE5),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              color: isFiltered
                  ? _green
                  : const Color(0xFF64756C),
              size: 22,
            ),
            if (isFiltered)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  height: 7,
                  width: 7,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildFilterItem(
      String value,
      String label,
      ) {
    final selected = _selectedStatus == value;

    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: selected ? _green : const Color(0xFF9AA79F),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight:
              selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? _green : _dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    Key? key,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: SizedBox(
        height: 26,
        width: 26,
        child: CircularProgressIndicator(
          color: _green,
          strokeWidth: 2.4,
        ),
      ),
    );
  }


  // ADD CUSTOMER BUTTON
  Widget _buildAddCustomerButton(String adminUid) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 20, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Material(
              color: Colors.transparent,
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () {
                  showAddCustomerDialog(context, adminUid);
                },
                child: SizedBox(
                  height: 52,
                  width: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        color: _green,
                        size: 30,
                      ),
                      Positioned(
                        right: 7,
                        bottom: 7,
                        child: Container(
                          height: 18,
                          width: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _green,
                              width: 1.4,
                            ),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: _green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    if (adminUid == null) {
      return const Center(
        child: Text(
          'Admin not logged in',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSummaryCard(),

            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('admin_customers')
                    .where('adminUid', isEqualTo: adminUid)
                    .where('active', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return _buildLoading();
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    );
                  }

                  final relationships = snapshot.data?.docs ?? [];

                  if (relationships.isEmpty) {
                    _relationshipKey = '';
                    _customersFuture = Future.value([]);
                    _totalCustomerCount = 0;

                    return _buildEmptyState(
                      title: 'No customers yet',
                      subtitle:
                      'Add your first customer to start managing their accounts.',
                      icon: Icons.person_add_alt_1_rounded,
                    );
                  }

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getCustomersFuture(relationships),
                    builder: (context, customerSnapshot) {
                      if (customerSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return _buildLoading();
                      }

                      if (customerSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${customerSnapshot.error}',
                            style: const TextStyle(fontSize: 15),
                          ),
                        );
                      }

                      final allCustomers =
                          customerSnapshot.data ?? [];

                      final customers = allCustomers
                          .where(matchesSearch)
                          .where(matchesStatus)
                          .toList();

                      return AnimatedSwitcher(
                        duration:
                        const Duration(milliseconds: 200),
                        child: customers.isEmpty
                            ? _buildEmptyState(
                          key: const ValueKey('empty-list'),
                          title: 'No customers found',
                          subtitle: _selectedStatus == 'all'
                              ? 'Try searching with a different name, mobile number or email.'
                              : 'No customers found with this status.',
                          icon: Icons.search_off_rounded,
                        )
                            : ListView.builder(
                          key: const ValueKey('customer-list'),
                          padding:
                          const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            14,
                          ),
                          physics:
                          const BouncingScrollPhysics(),
                          itemCount: customers.length,
                          itemBuilder: (context, index) {
                            final customer = customers[index];

                            return CustomerListItem(
                              key: ValueKey(
                                customer['_relationshipId'],
                              ),
                              customer: customer,
                              serialNumber:
                              customer['_serial'] as int,
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildAddCustomerButton(adminUid),
    );
  }
}

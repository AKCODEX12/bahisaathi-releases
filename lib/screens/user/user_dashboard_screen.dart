import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:bahisaathi/screens/admin/widgets/floating_calculator_overlay.dart';
import '../../services/app_update_service.dart';

import 'user_loan_list_screen.dart';
import 'user_calculator_screen.dart';
import 'user_profile_screen.dart';
import 'customer_reports_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  final String customerUid;
  final String customerEmail;
  final String adminUid;

  const UserDashboardScreen({
    super.key,
    required this.customerUid,
    required this.customerEmail,
    required this.adminUid,
  });

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FloatingCalculatorOverlay(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.customerEmail,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 25),

              // MY LOANS
              _dashboardCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'My Loans',
                subtitle: 'View your loans',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserLoanListScreen(
                        customerUid: widget.customerUid,
                        customerEmail: widget.customerEmail,
                        adminUid: widget.adminUid,
                      ),
                    ),
                  );
                },
              ),

              // MY BAHI / KHATA
              _dashboardCard(
                icon: Icons.menu_book_outlined,
                title: 'My Bahi / Khata',
                subtitle: 'View your account and entries',
              ),

              // MY TRANSACTIONS
              _dashboardCard(
                icon: Icons.swap_horiz,
                title: 'My Transactions',
                subtitle: 'View your transactions',
              ),

              // CALCULATOR
              _dashboardCard(
                icon: Icons.calculate_outlined,
                title: 'Calculator',
                subtitle: 'Calculate your loans',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CalculatorTab(),
                    ),
                  );
                },
              ),

              // MY EMI
              _dashboardCard(
                icon: Icons.payments_outlined,
                title: 'My EMI',
                subtitle: 'View EMI details and due payments',
              ),

              // MY PAYMENTS
              _dashboardCard(
                icon: Icons.receipt_long_outlined,
                title: 'My Payments',
                subtitle: 'View your payment history',
              ),

              // MY REPORTS
              _dashboardCard(
                icon: Icons.bar_chart_outlined,
                title: 'My Reports',
                subtitle: 'View your reports',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerReportsScreen(
                        customerUid: widget.customerUid,
                        customerEmail: widget.customerEmail,
                        adminUid: widget.adminUid,
                      ),
                    ),
                  );
                },
              ),

              // MY PROFILE
              _dashboardCard(
                icon: Icons.person_outline,
                title: 'My Profile',
                subtitle: 'View your profile',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        customerEmail: widget.customerEmail,
                        adminUid: widget.adminUid,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // LOGOUT
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();

                    if (!context.mounted) return;

                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),

              // ADMIN / CUSTOMER CONNECTION
              const SizedBox(height: 15),

              Text(
                'Admin ID: ${widget.adminUid}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),

              Text(
                'Customer ID: ${widget.customerUid}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Icon(
            icon,
            color: Colors.green,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}

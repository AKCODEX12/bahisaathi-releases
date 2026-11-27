import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/app_update_service.dart';
import 'widgets/floating_calculator_overlay.dart';

import 'dashboard/home_tab.dart';
import 'dashboard/list_tab.dart';
import 'dashboard/reports_tab.dart';
import 'dashboard/calculator_tab.dart';
import 'dashboard/account_tab.dart';
import '../../services/app_update_service.dart';


class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdate(context);
    });
  }

  final List<Widget> tabs = const [
    HomeTab(),
    ListTab(),
    ReportsTab(),
    CalculatorTab(),
    AccountTab(),
  ];

  final List<String> titles = const [
    'Home',
    'List',
    'Reports',
    'Calculator',
    'Account',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),

      body: IndexedStack(
        index: currentIndex,
        children: tabs,
      ),

      bottomNavigationBar: _ModernAdminNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          _AdminNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          _AdminNavItem(
            icon: Icons.list_alt_outlined,
            activeIcon: Icons.list_alt_rounded,
            label: 'List',
          ),
          _AdminNavItem(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart_rounded,
            label: 'Reports',
          ),
          _AdminNavItem(
            icon: Icons.calculate_outlined,
            activeIcon: Icons.calculate_rounded,
            label: 'Calculator',
          ),
          _AdminNavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class _AdminNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _AdminNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _ModernAdminNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_AdminNavItem> items;

  const _ModernAdminNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = items.length;
    const primaryColor = Color(0xFF0B5318);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 2, 6, 8),
        padding: const EdgeInsets.all(4),
        height: 60,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF172119) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : primaryColor.withValues(alpha: 0.12),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.38)
                  : Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / count;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: currentIndex * itemWidth,
                  width: itemWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E8E32) : primaryColor,
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(count, (index) {
                    final item = items[index];
                    final isSelected = index == currentIndex;

                    return SizedBox(
                      width: itemWidth,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!isSelected) {
                            HapticFeedback.lightImpact();
                            onTap(index);
                          }
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.05 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: 21,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600),
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                letterSpacing: 0.1,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700),
                              ),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

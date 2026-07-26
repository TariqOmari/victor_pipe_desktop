// dashboard_screen.dart
import 'package:flutter/material.dart';
import 'sidebar.dart';
import 'navbar.dart';
import 'pages/home_page.dart';
import 'pages/customers_page.dart';
import 'pages/admins_page.dart';
import 'pages/suppliers_page.dart';
import 'pages/raw_materials_page.dart';
import 'pages/sales_page.dart';
import 'pages/daily_expenses_page.dart';
import 'pages/customers_companies_page.dart';
import 'pages/production_management_page.dart'; // ← FIXED IMPORT NAME
import 'pages/loans_page.dart';
import 'pages/capital_Page.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  late final List<Widget> pages = [
    const HomePage(),
    const CustomersPage(),
    const SuppliersPage(),
    const RawMaterialsPage(),
    const SalesPage(),
    const DailyExpensesPage(),
    const CustomersCompaniesPage(),
    const ProductionManagementPage(),
    const Center(child: Text('صفحه گزارشات در حال ساخت ...')),
    const CapitalPage(),
    const Center(child: Text('صفحه صرافی در حال ساخت ...')),
    AdminsPage(currentUser: widget.user),
    const LoansPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                Sidebar(
                  selectedIndex: selectedIndex,
                  onItemSelected: (index) {
                    if (index >= 0 && index < pages.length) {
                      setState(() {
                        selectedIndex = index;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('صفحه مورد نظر در دسترس نیست'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  user: widget.user,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Navbar(user: widget.user),
                      Expanded(
                        child: selectedIndex < pages.length
                            ? pages[selectedIndex]
                            : const Center(
                                child: Text(
                                  'صفحه در حال ساخت...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
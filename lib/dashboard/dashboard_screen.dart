import 'package:flutter/material.dart';
import 'sidebar.dart';
import 'navbar.dart';
import 'pages/home_page.dart';
import 'pages/customers_page.dart';
import 'pages/admins_page.dart';
import 'pages/suppliers_page.dart';
import 'pages/raw_materials_page.dart';
import 'pages/sales_page.dart';
import 'pages/back_returned_sales_page.dart';
import 'pages/services_page.dart';
import 'pages/daily_expenses_page.dart';
import 'pages/wastes_page.dart';
import 'pages/customers_companies_page.dart';
import 'pages/production_management_page.dart';
import 'pages/Reports_Page.dart';
import 'pages/loans_page.dart';
import 'pages/supplier_loans_page.dart';
import 'pages/capital_Page.dart';
import 'pages/sarafi_page.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  // FIXED: Cannot use widget.user here, use a getter or late initialization
  late final List<Widget> pages = [
    const HomePage(),
    const CustomersPage(),
    const SuppliersPage(),
    const RawMaterialsPage(),
    const SalesPage(),
    const BackReturnedSalesPage(),
    const ServicesPage(),
    const DailyExpensesPage(),
    const WastesPage(),
    const CustomersCompaniesPage(),
    const ProductionManagementPage(),
    const ReportsPage(),
    const CapitalPage(),
    const SarafiPage(),
    AdminsPage(currentUser: widget.user),  // ✅ NOW widget.user is accessible inside late initialization
    const LoansPage(),
    const SupplierLoansPage(),
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
                          content: const Text('صفحه مورد نظر در دسترس نیست'),
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
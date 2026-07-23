import 'package:flutter/material.dart';
import 'sidebar.dart';
import 'navbar.dart';
import 'pages/home_page.dart';
import 'pages/customers_page.dart';
import 'pages/suppliers_page.dart';
import 'pages/raw_materials_page.dart';
import 'pages/sales_page.dart'; // Import your sales page
import 'pages/daily_expenses_page.dart'; // Import your daily expenses page
import 'pages/customers_companies_page.dart'; // Import your customers and companies page
// Import other pages as you create them

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  // Dynamic pages list - add as many as you want!
  final List<Widget> pages = [
    const HomePage(),           // index 0: Dashboard
    const CustomersPage(),      // index 1: Customers
    const SuppliersPage(),      // index 2: Suppliers
    const RawMaterialsPage(),   // index 3: Raw Materials
    const SalesPage(),          // index 4: Sales
    const DailyExpensesPage(),  // index 5: Daily Expenses
    const CustomersCompaniesPage(), // index 6: Customers and Companies
    // Add more pages here as you create them
    // const InventoryPage(),   // index 5
    // const FinancePage(),     // index 6
    // const ReportsPage(),     // index 7
    // const UsersPage(),       // index 8
    // const SettingsPage(),    // index 9
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            Sidebar(
              selectedIndex: selectedIndex,
              onItemSelected: (index) {
                // Check if index is valid
                if (index >= 0 && index < pages.length) {
                  setState(() {
                    selectedIndex = index;
                  });
                } else {
                  // Handle invalid index
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
        ),
      ),
    );
  }
}
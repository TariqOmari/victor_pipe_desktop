import 'package:flutter/material.dart';
import 'sidebar.dart';
import 'navbar.dart';
import 'pages/home_page.dart';
import 'pages/customers_page.dart';
import 'pages/suppliers_page.dart'; // ← ADD THIS
import 'pages/raw_materials_page.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const HomePage(),           // index 0: Dashboard
    const CustomersPage(),      // index 1: Customers
    const SuppliersPage(),      // index 2: Suppliers ← NEW!
    const RawMaterialsPage(),   // index 3: Raw Materials
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
                setState(() {
                  selectedIndex = index;
                });
              },
              user: widget.user,
            ),
            Expanded(
              child: Column(
                children: [
                  Navbar(user: widget.user),
                  Expanded(
                    child: pages[selectedIndex],
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
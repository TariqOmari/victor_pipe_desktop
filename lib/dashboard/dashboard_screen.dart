import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'pages/supplier_loans_page.dart';
import 'pages/customer_company_loans_page.dart';
import 'pages/capital_Page.dart';
import 'pages/sarafi_page.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;
  late List<Widget> pages;

  @override
  void initState() {
    super.initState();
    // Initialize pages here where widget is available
    pages = [
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
      AdminsPage(currentUser: widget.user),
      const SupplierLoansPage(),
      const CustomerCompanyLoansPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final isEnglish = languageProvider.isEnglish;

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
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
                          content: Text(l10n.pageNotAvailable),
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
                            : Center(
                                child: Text(
                                  l10n.pageUnderConstruction,
                                  style: const TextStyle(
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
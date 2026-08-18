// lib/screens/pages/incomes_page.dart - Updated with internationalization

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class IncomesPage extends StatefulWidget {
  const IncomesPage({super.key});

  @override
  State<IncomesPage> createState() => _IncomesPageState();
}

class _IncomesPageState extends State<IncomesPage>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  bool _isGeneratingPDF = false;

  // Data
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _producedProducts = [];
  List<Map<String, dynamic>> _dailyExpenses = [];

  // Calculated
  double _totalSales = 0;
  double _totalServices = 0;
  double _totalRawMaterialCost = 0;
  double _grossProfit = 0;
  double _profitMargin = 0;
  double _totalExpenses = 0;
  double _netProfit = 0;
  double _netProfitMargin = 0;

  // Filters
  String _selectedCurrency = 'USD';
  int _selectedYear = 1404;
  int _selectedMonth = 1;

  // Tab Controller
  late TabController _tabController;

  // Pagination
  int _currentPage = 0;
  int _rowsPerPage = 10;

  // Persian months
  final List<String> _persianMonths = [
    'حمل', 'ثور', 'جوزا', 'سرطان', 'اسد', 'سنبله',
    'میزان', 'عقرب', 'قوس', 'جدی', 'دلو', 'حوت'
  ];

  // Persian month days
  final List<int> _persianMonthDays = [
    31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setCurrentPersianDate();
    _loadData();
  }

  void _setCurrentPersianDate() {
    final now = DateTime.now();
    int persianYear = now.year - 621;
    int persianMonth = now.month + 9;
    if (persianMonth > 12) {
      persianMonth = persianMonth - 12;
      persianYear = persianYear + 1;
    }
    if (persianMonth < 1) persianMonth = 1;
    
    _selectedYear = persianYear;
    _selectedMonth = persianMonth;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await _db.getSalesInvoices();
      final services = await _db.getServiceInvoices();
      final rawMaterials = await _db.getRawMaterials();
      final producedProducts = await _db.getProducedProducts();
      final dailyExpenses = await _db.getDailyExpenses();

      setState(() {
        _sales = sales;
        _services = services;
        _rawMaterials = rawMaterials;
        _producedProducts = producedProducts;
        _dailyExpenses = dailyExpenses;
        _calculateIncomes();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateIncomes() {
    final filteredSales = _getFilteredSales();
    final filteredServices = _getFilteredServices();
    final filteredExpenses = _getFilteredExpenses();

    // Calculate Sales (Products) - STORE SEPARATELY
    _totalSales = filteredSales.fold<double>(0, (sum, sale) {
      final price = double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;
      if (sale['currency'] == 'AFN' && _selectedCurrency == 'USD') {
        final rate = double.tryParse(sale['price_rate']?.toString() ?? '1') ?? 1;
        return sum + (rate > 0 ? price / rate : 0);
      } else if (sale['currency'] == 'USD' && _selectedCurrency == 'AFN') {
        final rate = double.tryParse(sale['price_rate']?.toString() ?? '1') ?? 1;
        return sum + (price * rate);
      }
      return sum + price;
    });

    // Calculate Services - STORE SEPARATELY
    _totalServices = filteredServices.fold<double>(0, (sum, service) {
      final price = double.tryParse(service['final_price']?.toString() ?? '0') ?? 0;
      if (service['currency'] == 'AFN' && _selectedCurrency == 'USD') {
        final rate = double.tryParse(service['exchange_rate']?.toString() ?? '1') ?? 1;
        return sum + (rate > 0 ? price / rate : 0);
      } else if (service['currency'] == 'USD' && _selectedCurrency == 'AFN') {
        final rate = double.tryParse(service['exchange_rate']?.toString() ?? '1') ?? 1;
        return sum + (price * rate);
      }
      return sum + price;
    });

    // Total Income = Sales + Services
    final totalIncome = _totalSales + _totalServices;

    // Calculate Raw Material Cost (Only for products)
    _totalRawMaterialCost = _calculateRawMaterialCost(filteredSales);
    _grossProfit = totalIncome - _totalRawMaterialCost;
    _profitMargin = totalIncome > 0 ? (_grossProfit / totalIncome) * 100 : 0;

    // Calculate Expenses
    _totalExpenses = filteredExpenses.fold<double>(0, (sum, expense) {
      final price = (expense['price'] is int)
          ? (expense['price'] as int).toDouble()
          : double.tryParse(expense['price']?.toString() ?? '0') ?? 0;

      if (expense['currency'] == 'دالر' && _selectedCurrency == 'AFN') {
        final rate = double.tryParse(expense['exchangeRate']?.toString() ?? '1') ?? 1;
        return sum + (price * rate);
      } else if (expense['currency'] == 'افغانی' && _selectedCurrency == 'USD') {
        final rate = double.tryParse(expense['exchangeRate']?.toString() ?? '1') ?? 1;
        return sum + (rate > 0 ? price / rate : 0);
      }
      return sum + price;
    });

    _netProfit = _grossProfit - _totalExpenses;
    _netProfitMargin = totalIncome > 0 ? (_netProfit / totalIncome) * 100 : 0;
  }

  double _calculateRawMaterialCost(List<Map<String, dynamic>> filteredSales) {
    final Map<String, double> productCostMap = {};

    for (var material in _rawMaterials) {
      final rawCost = double.tryParse(material['final_price']?.toString() ?? '0') ?? 0;
      double cost = rawCost;
      if (material['currency'] == 'AFN' && _selectedCurrency == 'USD') {
        final rate = double.tryParse(material['exchange_rate']?.toString() ?? '1') ?? 1;
        cost = rate > 0 ? rawCost / rate : 0;
      } else if (material['currency'] == 'USD' && _selectedCurrency == 'AFN') {
        final rate = double.tryParse(material['exchange_rate']?.toString() ?? '1') ?? 1;
        cost = rawCost * rate;
      }

      final materialName = material['name']?.toString() ?? '';
      if (materialName.isNotEmpty) {
        productCostMap[materialName] = (productCostMap[materialName] ?? 0) + cost;
      }
    }

    double totalRawMaterialCost = 0;
    for (var product in _producedProducts) {
      final productName = product['product_name']?.toString() ?? '';
      final productSales = filteredSales.where((sale) {
        final saleProduct = sale['product_name']?.toString() ?? '';
        return saleProduct.toLowerCase().contains(productName.toLowerCase()) ||
               productName.toLowerCase().contains(saleProduct.toLowerCase());
      }).toList();

      if (productSales.isNotEmpty) {
        final productWeight = double.tryParse(product['total_weight']?.toString() ?? '0') ?? 0;
        if (productWeight > 0) {
          double totalCostForProduct = 0;
          for (var material in _rawMaterials) {
            final materialName = material['name']?.toString() ?? '';
            if (materialName.isNotEmpty) {
              if (materialName.toLowerCase().contains(productName.toLowerCase()) ||
                  productName.toLowerCase().contains(materialName.toLowerCase())) {
                final rawCost = double.tryParse(material['final_price']?.toString() ?? '0') ?? 0;
                double cost = rawCost;
                if (material['currency'] == 'AFN' && _selectedCurrency == 'USD') {
                  final rate = double.tryParse(material['exchange_rate']?.toString() ?? '1') ?? 1;
                  cost = rate > 0 ? rawCost / rate : 0;
                } else if (material['currency'] == 'USD' && _selectedCurrency == 'AFN') {
                  final rate = double.tryParse(material['exchange_rate']?.toString() ?? '1') ?? 1;
                  cost = rawCost * rate;
                }
                totalCostForProduct += cost;
              }
            }
          }

          final costPerUnit = totalCostForProduct / productWeight;
          for (var sale in productSales) {
            final saleWeight = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
            final saleCost = costPerUnit * saleWeight;
            totalRawMaterialCost += saleCost;
          }
        }
      }
    }

    if (totalRawMaterialCost == 0 && _rawMaterials.isNotEmpty) {
      double totalRawCost = 0;
      for (var material in _rawMaterials) {
        final rawCost = double.tryParse(material['final_price']?.toString() ?? '0') ?? 0;
        double cost = rawCost;
        if (material['currency'] == 'AFN' && _selectedCurrency == 'USD') {
          final rate = double.tryParse(material['exchange_rate']?.toString() ?? '1') ?? 1;
          cost = rate > 0 ? rawCost / rate : 0;
        } else if (material['currency'] == 'USD' && _selectedCurrency == 'AFN') {
          final rate = double.tryParse(material['exchange_rate']?.toString() ?? '1') ?? 1;
          cost = rawCost * rate;
        }
        totalRawCost += cost;
      }
      totalRawMaterialCost = totalRawCost;
    }

    return totalRawMaterialCost;
  }

  // ============ PERSIAN TO GREGORIAN CONVERSION ============
  List<DateTime> _getGregorianRangeForPersianMonth(int year, int month) {
    final Map<int, List<int>> monthStarts = {
      1: [3, 21],
      2: [4, 21],
      3: [5, 22],
      4: [6, 22],
      5: [7, 23],
      6: [8, 23],
      7: [9, 23],
      8: [10, 23],
      9: [11, 22],
      10: [12, 22],
      11: [1, 21],
      12: [2, 20],
    };

    final start = monthStarts[month]!;
    int startMonth = start[0];
    int startDay = start[1];
    int startYear = year + 621;
    
    if (month == 11 || month == 12) {
      startYear = year + 622;
    }

    int endYear = startYear;
    int endMonth = startMonth;
    int endDay = startDay + _persianMonthDays[month - 1] - 1;
    
    while (endDay > _getDaysInMonth(endYear, endMonth)) {
      endDay = endDay - _getDaysInMonth(endYear, endMonth);
      endMonth++;
      if (endMonth > 12) {
        endMonth = 1;
        endYear++;
      }
    }

    return [
      DateTime(startYear, startMonth, startDay),
      DateTime(endYear, endMonth, endDay),
    ];
  }

  int _getDaysInMonth(int year, int month) {
    const daysInMonth = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && _isLeapYear(year)) return 29;
    return daysInMonth[month];
  }

  bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  List<Map<String, dynamic>> _getFilteredSales() {
    final range = _getGregorianRangeForPersianMonth(_selectedYear, _selectedMonth);
    final startDate = range[0];
    final endDate = range[1];

    return _sales.where((sale) {
      if (sale['is_back_returned'] == 1 || sale['is_back_returned']?.toString() == '1') {
        return false;
      }

      final dateStr = sale['date_en']?.toString() ?? '';
      if (dateStr.isEmpty) return false;

      try {
        final parts = dateStr.split('-');
        if (parts.length != 3) return false;
        final year = int.tryParse(parts[0]) ?? 0;
        final month = int.tryParse(parts[1]) ?? 0;
        final day = int.tryParse(parts[2]) ?? 0;
        final saleDate = DateTime(year, month, day);

        return saleDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
               saleDate.isBefore(endDate.add(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredServices() {
    final range = _getGregorianRangeForPersianMonth(_selectedYear, _selectedMonth);
    final startDate = range[0];
    final endDate = range[1];

    return _services.where((service) {
      final dateStr = service['date_en']?.toString() ?? '';
      if (dateStr.isEmpty) return false;

      try {
        final parts = dateStr.split('-');
        if (parts.length != 3) return false;
        final year = int.tryParse(parts[0]) ?? 0;
        final month = int.tryParse(parts[1]) ?? 0;
        final day = int.tryParse(parts[2]) ?? 0;
        final serviceDate = DateTime(year, month, day);

        return serviceDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
               serviceDate.isBefore(endDate.add(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredExpenses() {
    final range = _getGregorianRangeForPersianMonth(_selectedYear, _selectedMonth);
    final startDate = range[0];
    final endDate = range[1];

    return _dailyExpenses.where((expense) {
      final dateStr = expense['date_en']?.toString() ?? '';
      if (dateStr.isEmpty) return false;

      try {
        final parts = dateStr.split('-');
        if (parts.length != 3) return false;
        final year = int.tryParse(parts[0]) ?? 0;
        final month = int.tryParse(parts[1]) ?? 0;
        final day = int.tryParse(parts[2]) ?? 0;
        final expenseDate = DateTime(year, month, day);

        return expenseDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
               expenseDate.isBefore(endDate.add(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).toList();
  }

  String _formatCurrency(double amount) {
    final symbol = _selectedCurrency == 'USD' ? '\$' : '؋';
    final formatted = amount.toStringAsFixed(0);
    final withCommas = formatted.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), 
      (m) => '${m[1]},'
    );
    return '$symbol$withCommas';
  }

  String _formatNumber(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '0') ?? 0;
    return parsed.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},'
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============ PDF REPORT GENERATION ============
  
  Future<void> _generatePDFReport() async {
    setState(() => _isGeneratingPDF = true);
    
    try {
      final pdf = await _buildPDF();
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
        name: 'Profit_Report_${_persianMonths[_selectedMonth - 1]}_$_selectedYear',
      );
      
      setState(() => _isGeneratingPDF = false);
    } catch (e) {
      setState(() => _isGeneratingPDF = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar('${l10n.error}: $e', Colors.red);
    }
  }

  Future<Uint8List> _buildPDF() async {
    final l10n = AppLocalizations.of(context)!;
    
    // Load font
    pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    // Load logo image
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/companylogo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print('Error loading logo: $e');
    }

    final filteredSales = _getFilteredSales();
    final filteredServices = _getFilteredServices();
    final filteredExpenses = _getFilteredExpenses();
    
    final monthName = _persianMonths[_selectedMonth - 1];
    final currencySymbol = _selectedCurrency == 'USD' ? '\$' : '؋';
    
    // Calculate expense breakdown
    Map<String, double> expenseByCategory = {};
    for (var expense in filteredExpenses) {
      final category = expense['category']?.toString() ?? l10n.miscellaneous;
      final price = (expense['price'] is int)
          ? (expense['price'] as int).toDouble()
          : double.tryParse(expense['price']?.toString() ?? '0') ?? 0;
      
      double convertedPrice = price;
      if (expense['currency'] == 'دالر' && _selectedCurrency == 'AFN') {
        final rate = double.tryParse(expense['exchangeRate']?.toString() ?? '1') ?? 1;
        convertedPrice = price * rate;
      } else if (expense['currency'] == 'افغانی' && _selectedCurrency == 'USD') {
        final rate = double.tryParse(expense['exchangeRate']?.toString() ?? '1') ?? 1;
        convertedPrice = rate > 0 ? price / rate : 0;
      }
      
      expenseByCategory[category] = (expenseByCategory[category] ?? 0) + convertedPrice;
    }

    final totalIncome = _totalSales + _totalServices;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ========== HEADER WITH LOGO ==========
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFCB001D), width: 2),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            l10n.companyName,
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFFCB001D),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            l10n.integratedSystem,
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 11,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            l10n.monthlyProfitLossReport,
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${l10n.month} $monthName ${l10n.year} $_selectedYear',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      if (logoImage != null)
                        pw.Container(
                          width: 80,
                          height: 80,
                          decoration: pw.BoxDecoration(
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(color: PdfColors.grey300, width: 1),
                          ),
                          child: pw.Image(
                            logoImage!,
                            width: 80,
                            height: 80,
                            fit: pw.BoxFit.contain,
                          ),
                        )
                      else
                        pw.Container(
                          width: 80,
                          height: 80,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(color: PdfColors.grey300, width: 1),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'VP',
                              style: pw.TextStyle(
                                font: ttf,
                                fontSize: 30,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFFCB001D),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),

                // ========== SUMMARY CARDS ==========
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(ttf, l10n.productSales, _formatCurrency(_totalSales), PdfColors.blue),
                      _buildSummaryItem(ttf, l10n.serviceSales, _formatCurrency(_totalServices), PdfColors.green),
                      _buildSummaryItem(ttf, l10n.rawMaterialCost, _formatCurrency(_totalRawMaterialCost), PdfColors.orange),
                      _buildSummaryItem(ttf, l10n.grossProfitLabel, _formatCurrency(_grossProfit), _grossProfit >= 0 ? PdfColors.green : PdfColors.red),
                      _buildSummaryItem(ttf, l10n.dailyExpensesLabel, _formatCurrency(_totalExpenses), PdfColors.purple),
                      _buildSummaryItem(ttf, l10n.netProfitLabel, _formatCurrency(_netProfit), _netProfit >= 0 ? PdfColors.green : PdfColors.red),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),

                // ========== SALES TABLE ==========
                pw.Text(
                  '📦 ${l10n.productSales}',
                  style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                _buildSalesTablePDF(ttf, filteredSales, currencySymbol),
                
                pw.SizedBox(height: 12),
                
                // ========== SERVICES TABLE ==========
                pw.Text(
                  '🔧 ${l10n.serviceSales}',
                  style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                _buildServicesTablePDF(ttf, filteredServices, currencySymbol),
                
                pw.SizedBox(height: 12),
                
                // ========== EXPENSES TABLE ==========
                pw.Text(
                  '🧾 ${l10n.dailyExpensesDetails}',
                  style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                _buildPDFExpensesTable(ttf, filteredExpenses, currencySymbol),
                
                pw.SizedBox(height: 12),
                
                // ========== EXPENSE BREAKDOWN ==========
                if (expenseByCategory.isNotEmpty) ...[
                  pw.Text(
                    '📈 ${l10n.expenseBreakdown}',
                    style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  _buildExpenseBreakdown(ttf, expenseByCategory, currencySymbol),
                ],
                
                pw.Spacer(),
                
                // ========== FOOTER ==========
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${l10n.printDate}: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}',
                      style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      '${l10n.companyName} © ${DateTime.now().year}',
                      style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildSummaryItem(pw.Font font, String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSalesTablePDF(pw.Font font, List<Map<String, dynamic>> sales, String currencySymbol) {
    final l10n = AppLocalizations.of(context)!;
    
    if (sales.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text(
            l10n.noSalesThisMonth,
            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
          ),
        ),
      );
    }

    List<List<String>> tableData = [];
    for (var sale in sales) {
      final amount = double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;
      tableData.add([
        sale['invoice_number']?.toString() ?? '-',
        sale['customer_name']?.toString() ?? '-',
        sale['product_name']?.toString() ?? '-',
        '${_formatNumber(amount)} $currencySymbol',
      ]);
    }

    return pw.Table.fromTextArray(
      headers: [l10n.invoiceNumber, l10n.customerName, l10n.productNameShort, l10n.amount],
      data: tableData,
      headerStyle: pw.TextStyle(
        font: font,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      cellAlignment: pw.Alignment.centerRight,
      border: pw.TableBorder.symmetric(
        outside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),
        1: const pw.FixedColumnWidth(120),
        2: const pw.FixedColumnWidth(140),
        3: const pw.FixedColumnWidth(120),
      },
    );
  }

  pw.Widget _buildServicesTablePDF(pw.Font font, List<Map<String, dynamic>> services, String currencySymbol) {
    final l10n = AppLocalizations.of(context)!;
    
    if (services.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text(
            l10n.noServicesThisMonth,
            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
          ),
        ),
      );
    }

    List<List<String>> tableData = [];
    for (var service in services) {
      final amount = double.tryParse(service['final_price']?.toString() ?? '0') ?? 0;
      tableData.add([
        service['invoice_number']?.toString() ?? '-',
        service['customer_name']?.toString() ?? '-',
        service['service_title']?.toString() ?? service['service_type']?.toString() ?? '-',
        '${_formatNumber(amount)} $currencySymbol',
      ]);
    }

    return pw.Table.fromTextArray(
      headers: [l10n.invoiceNumber, l10n.customerName, l10n.serviceTypeLabel2, l10n.amount],
      data: tableData,
      headerStyle: pw.TextStyle(
        font: font,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      cellAlignment: pw.Alignment.centerRight,
      border: pw.TableBorder.symmetric(
        outside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),
        1: const pw.FixedColumnWidth(120),
        2: const pw.FixedColumnWidth(140),
        3: const pw.FixedColumnWidth(120),
      },
    );
  }

  pw.Widget _buildPDFExpensesTable(pw.Font font, List<Map<String, dynamic>> expenses, String currencySymbol) {
    final l10n = AppLocalizations.of(context)!;
    
    if (expenses.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text(
            l10n.noExpensesThisMonth,
            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
          ),
        ),
      );
    }

    List<List<String>> tableData = [];
    for (var expense in expenses) {
      final price = (expense['price'] is int)
          ? (expense['price'] as int).toDouble()
          : double.tryParse(expense['price']?.toString() ?? '0') ?? 0;
      
      double convertedPrice = price;
      if (expense['currency'] == 'دالر' && _selectedCurrency == 'AFN') {
        final rate = double.tryParse(expense['exchangeRate']?.toString() ?? '1') ?? 1;
        convertedPrice = price * rate;
      } else if (expense['currency'] == 'افغانی' && _selectedCurrency == 'USD') {
        final rate = double.tryParse(expense['exchangeRate']?.toString() ?? '1') ?? 1;
        convertedPrice = rate > 0 ? price / rate : 0;
      }
      
      tableData.add([
        expense['registrationNumber']?.toString() ?? '-',
        expense['date']?.toString() ?? '-',
        expense['category']?.toString() ?? '-',
        expense['description']?.toString() ?? '-',
        '${_formatNumber(convertedPrice)} $currencySymbol',
      ]);
    }

    return pw.Table.fromTextArray(
      headers: [l10n.registrationNumber, l10n.date, l10n.category, l10n.description, l10n.amount],
      data: tableData,
      headerStyle: pw.TextStyle(
        font: font,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      cellAlignment: pw.Alignment.centerRight,
      border: pw.TableBorder.symmetric(
        outside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(70),
        1: const pw.FixedColumnWidth(70),
        2: const pw.FixedColumnWidth(80),
        3: const pw.FixedColumnWidth(120),
        4: const pw.FixedColumnWidth(100),
      },
    );
  }

  pw.Widget _buildExpenseBreakdown(pw.Font font, Map<String, double> expenses, String currencySymbol) {
    final l10n = AppLocalizations.of(context)!;
    
    List<List<String>> tableData = [];
    double total = 0;
    
    final sortedEntries = expenses.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    for (var entry in sortedEntries) {
      tableData.add([
        entry.key,
        '${_formatNumber(entry.value)} $currencySymbol',
        '${((entry.value / _totalExpenses) * 100).toStringAsFixed(1)}%',
      ]);
      total += entry.value;
    }
    
    tableData.add([
      l10n.totalLabel,
      '${_formatNumber(total)} $currencySymbol',
      '100%',
    ]);

    return pw.Table.fromTextArray(
      headers: [l10n.category, l10n.amount, l10n.percentage],
      data: tableData,
      headerStyle: pw.TextStyle(
        font: font,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      cellAlignment: pw.Alignment.centerRight,
      border: pw.TableBorder.symmetric(
        outside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(120),
        1: const pw.FixedColumnWidth(120),
        2: const pw.FixedColumnWidth(80),
      },
    );
  }

  // ============ UI BUILDERS ============

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
            : Column(
                crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  _buildHeader(l10n),
                  const SizedBox(height: 16),
                  _buildFilterRow(l10n),
                  const SizedBox(height: 16),
                  _buildTabBar(l10n),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGrossProfitView(l10n),
                        _buildNetProfitView(l10n),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.monetization_on, color: Color(0xFFCB001D), size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.incomesManagement,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  l10n.incomesManagementSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isGeneratingPDF ? null : _generatePDFReport,
              icon: _isGeneratingPDF
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
              label: Text(
                _isGeneratingPDF ? l10n.generating : l10n.pdfReport,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              label: Text(l10n.refresh, style: const TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterRow(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                items: List.generate(50, (index) {
                  int year = 1390 + index;
                  return DropdownMenuItem(
                    value: year,
                    child: Text(
                      year.toString(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedYear = value;
                      _calculateIncomes();
                    });
                  }
                },
                icon: Icon(Icons.arrow_drop_down,
                    color: const Color(0xFFCB001D), size: 24),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonth,
                items: List.generate(12, (index) {
                  int month = index + 1;
                  return DropdownMenuItem(
                    value: month,
                    child: Text(
                      _persianMonths[index],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMonth = value;
                      _calculateIncomes();
                    });
                  }
                },
                icon: Icon(Icons.arrow_drop_down,
                    color: const Color(0xFFCB001D), size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCB001D).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFFCB001D)),
                const SizedBox(width: 6),
                Text(
                  '${_getFilteredSales().length} ${l10n.sales} | ${_getFilteredServices().length} ${l10n.services} | ${_getFilteredExpenses().length} ${l10n.expenses}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFCB001D)),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                items: const [
                  DropdownMenuItem(value: 'USD', child: Text('USD', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'AFN', child: Text('AFN', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (value) => setState(() {
                  _selectedCurrency = value!;
                  _calculateIncomes();
                }),
                icon: Icon(Icons.arrow_drop_down,
                    color: const Color(0xFFCB001D), size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFFCB001D),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          Tab(text: '💰 ${l10n.grossProfitLabel}'),
          Tab(text: '📊 ${l10n.netProfitLabel}'),
        ],
      ),
    );
  }

  Widget _buildGrossProfitView(AppLocalizations l10n) {
    final totalIncome = _totalSales + _totalServices;
    final isProfit = _grossProfit >= 0;
    final profitColor = isProfit ? Colors.green.shade700 : Colors.red.shade700;

    return Column(
      children: [
        // SEPARATE CARDS FOR SALES AND SERVICES
        Row(
          children: [
            // Sales Card
            _buildIncomeCard(
              title: l10n.productSales,
              amount: _totalSales,
              icon: Icons.shopping_bag_outlined,
              color: Colors.blue.shade700,
              subtitle: '${_getFilteredSales().length} ${l10n.invoices}',
            ),
            const SizedBox(width: 12),
            // Services Card
            _buildIncomeCard(
              title: l10n.serviceSales,
              amount: _totalServices,
              icon: Icons.design_services_outlined,
              color: Colors.green.shade700,
              subtitle: '${_getFilteredServices().length} ${l10n.invoices}',
            ),
            const SizedBox(width: 12),
            // Raw Material Cost
            _buildIncomeCard(
              title: l10n.rawMaterialCost,
              amount: _totalRawMaterialCost,
              icon: Icons.warehouse_outlined,
              color: Colors.orange.shade700,
              subtitle: l10n.totalCost,
            ),
            const SizedBox(width: 12),
            // Gross Profit
            _buildIncomeCard(
              title: l10n.grossProfitLabel,
              amount: _grossProfit,
              icon: Icons.account_balance_rounded,
              color: _grossProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              subtitle: '${_profitMargin.toStringAsFixed(1)}% ${l10n.profitMargin}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildProfitSummary(isProfit, profitColor, _grossProfit, _profitMargin,
            totalIncome, _totalRawMaterialCost, l10n.grossProfitLabel, l10n.rawMaterialCost, l10n),
        const SizedBox(height: 12),
        Expanded(
          child: _buildSalesTable(l10n),
        ),
      ],
    );
  }

  Widget _buildIncomeCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
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

  Widget _buildNetProfitView(AppLocalizations l10n) {
    final totalIncome = _totalSales + _totalServices;
    final isProfit = _netProfit >= 0;
    final profitColor = isProfit ? Colors.green.shade700 : Colors.red.shade700;

    return Column(
      children: [
        Row(
          children: [
            _buildIncomeCard(
              title: l10n.grossProfitLabel,
              amount: _grossProfit,
              icon: Icons.trending_up_rounded,
              color: _grossProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              subtitle: l10n.beforeExpenses,
            ),
            const SizedBox(width: 12),
            _buildIncomeCard(
              title: l10n.dailyExpensesLabel,
              amount: _totalExpenses,
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.orange.shade700,
              subtitle: '${_getFilteredExpenses().length} ${l10n.items}',
            ),
            const SizedBox(width: 12),
            _buildIncomeCard(
              title: l10n.netProfitLabel,
              amount: _netProfit,
              icon: Icons.account_balance_rounded,
              color: _netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              subtitle: '${_netProfitMargin.toStringAsFixed(1)}% ${l10n.netProfitMargin}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildProfitSummary(isProfit, profitColor, _netProfit, _netProfitMargin,
            totalIncome, _totalExpenses, l10n.netProfitLabel, l10n.dailyExpensesLabel, l10n),
        const SizedBox(height: 12),
        Expanded(
          child: _buildExpensesTable(l10n),
        ),
      ],
    );
  }

  Widget _buildProfitSummary(bool isProfit, Color profitColor, double profit,
      double margin, double total, double cost, String profitLabel, String costLabel, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: profitColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: profitColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isProfit ? '💰 $profitLabel' : '📉 $profitLabel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: profitColor,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCB001D).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text('${l10n.profitMargin}: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${margin.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: profitColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final costRatio = total > 0 ? (cost / total) : 0.0;
              final profitRatio = total > 0 ? (profit / total) : 0.0;
              
              final costWidth = (costRatio * maxWidth).clamp(0.0, maxWidth);
              final profitWidth = (profitRatio * maxWidth).clamp(0.0, maxWidth);
              
              return Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    if (total > 0) ...[
                      Container(
                        width: costWidth,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),
                      Container(
                        width: profitWidth,
                        decoration: BoxDecoration(
                          color: isProfit ? Colors.green : Colors.red,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('$costLabel: ${_formatCurrency(cost)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 20),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isProfit ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('${l10n.profit}: ${_formatCurrency(profit)}', style: TextStyle(fontSize: 10, color: profitColor)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ SALES TABLE (Combined Sales + Services) ============
  Widget _buildSalesTable(AppLocalizations l10n) {
    final filteredSales = _getFilteredSales();
    final filteredServices = _getFilteredServices();

    List<Map<String, dynamic>> combinedItems = [
      ...filteredSales.map((s) => {...s, '_type': 'sale'}),
      ...filteredServices.map((s) => {...s, '_type': 'service'}),
    ];
    
    combinedItems.sort((a, b) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));

    final totalPages = (combinedItems.length / _rowsPerPage).ceil();
    final start = (_currentPage * _rowsPerPage).clamp(0, combinedItems.length);
    final paged = combinedItems.skip(start).take(_rowsPerPage).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFCB001D),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Expanded(flex: 1, child: Text('نوع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 1, child: Text('شماره', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 2, child: Text('مشتری', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 2, child: Text('محصول/خدمت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 1, child: Text('مبلغ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
                const Expanded(flex: 1, child: Text('تاریخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
              ],
            ),
          ),
          Expanded(
            child: paged.isEmpty
                ? Center(child: Text(l10n.noInvoicesFound, style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: paged.length,
                    itemBuilder: (context, index) {
                      final item = paged[index];
                      final isService = item['_type'] == 'service';
                      final amount = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
                          color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isService ? Colors.blue.shade100 : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isService ? l10n.services : l10n.sale,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isService ? Colors.blue.shade800 : Colors.green.shade800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Expanded(flex: 1, child: Text(item['invoice_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            Expanded(flex: 2, child: Text(item['customer_name']?.toString() ?? '-', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            Expanded(
                              flex: 2,
                              child: Text(
                                isService 
                                    ? (item['service_title']?.toString() ?? item['service_type']?.toString() ?? '-') 
                                    : (item['product_name']?.toString() ?? '-'),
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(flex: 1, child: Text(_formatCurrency(amount), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue), textAlign: TextAlign.center)),
                            Expanded(flex: 1, child: Text(item['date']?.toString() ?? '-', style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _buildPagination(combinedItems.length, totalPages, l10n),
        ],
      ),
    );
  }

  // ============ EXPENSES TABLE ============
  Widget _buildExpensesTable(AppLocalizations l10n) {
    final filteredExpenses = _getFilteredExpenses();
    final totalPages = (filteredExpenses.length / _rowsPerPage).ceil();
    final start = (_currentPage * _rowsPerPage).clamp(0, filteredExpenses.length);
    final paged = filteredExpenses.skip(start).take(_rowsPerPage).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFCB001D),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Expanded(flex: 1, child: Text('شماره ثبت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 1, child: Text('تاریخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 1, child: Text('دسته', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 2, child: Text('شرح', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 1, child: Text('مبلغ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
                const Expanded(flex: 1, child: Text('ارز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
              ],
            ),
          ),
          Expanded(
            child: paged.isEmpty
                ? Center(child: Text(l10n.noExpensesFound, style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: paged.length,
                    itemBuilder: (context, index) {
                      final expense = paged[index];
                      final price = (expense['price'] is int) 
                          ? (expense['price'] as int).toDouble() 
                          : double.tryParse(expense['price']?.toString() ?? '0') ?? 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
                          color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: Text(expense['registrationNumber']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            Expanded(flex: 1, child: Text(expense['date']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                            Expanded(flex: 1, child: Text(expense['category']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                            Expanded(flex: 2, child: Text(expense['description']?.toString() ?? '-', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            Expanded(flex: 1, child: Text(_formatCurrency(price), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red), textAlign: TextAlign.center)),
                            Expanded(flex: 1, child: Text(expense['currency']?.toString() ?? '-', style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _buildPagination(filteredExpenses.length, totalPages, l10n),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalItems, int totalPages, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('${l10n.page} ${_currentPage + 1} ${l10n.pageOf} ${totalPages == 0 ? 1 : totalPages}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                icon: const Icon(Icons.chevron_left, size: 18),
              ),
              IconButton(
                onPressed: (_currentPage + 1) < totalPages ? () => setState(() => _currentPage++) : null,
                icon: const Icon(Icons.chevron_right, size: 18),
              ),
            ],
          ),
          Row(
            children: [
              Text('$totalItems ${l10n.items}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _rowsPerPage,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 20, child: Text('20', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 11))),
                    ],
                    onChanged: (value) => setState(() {
                      _rowsPerPage = value ?? 10;
                      _currentPage = 0;
                    }),
                    icon: Icon(Icons.arrow_drop_down,
                        color: const Color(0xFFCB001D), size: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
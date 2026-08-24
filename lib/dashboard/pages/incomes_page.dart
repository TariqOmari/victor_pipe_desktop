// lib/dashboard/pages/incomes_page.dart - نسخه نهایی با اضافه شدن قیمت فروش ضایعات به سود خالص

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
  List<Map<String, dynamic>> _wastes = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _producedProducts = [];
  List<Map<String, dynamic>> _dailyExpenses = [];

  // Calculated
  double _totalSales = 0;
  double _totalServices = 0;
  double _totalWastes = 0;
  double _totalSoldWastes = 0; // NEW: total sold waste prices
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
  
  // Persian calendar: year starts on March 21
  // Formula: PersianYear = GregorianYear - 621 (if date >= March 21)
  //          PersianYear = GregorianYear - 622 (if date < March 21)
  
  int persianYear;
  int persianMonth = now.month + 9;
  
  if (persianMonth > 12) {
    persianMonth = persianMonth - 12;
    persianYear = now.year - 621;
  } else {
    persianYear = now.year - 622;
  }
  
  // If we're before March 21, it's still the previous Persian year
  if (now.month < 3 || (now.month == 3 && now.day < 21)) {
    persianYear = persianYear - 1;
  }
  
  // Ensure month is in valid range
  if (persianMonth < 1) persianMonth = 1;
  if (persianMonth > 12) persianMonth = 12;
  
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
      final wastes = await _db.getWasteRecords();
      final rawMaterials = await _db.getRawMaterials();
      final producedProducts = await _db.getProducedProducts();
      final dailyExpenses = await _db.getDailyExpenses();

      setState(() {
        _sales = sales;
        _services = services;
        _wastes = wastes;
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
    final filteredWastes = _getFilteredWastes();
    final filteredExpenses = _getFilteredExpenses();

    // ===== 1. TOTAL SALES (in selected currency) =====
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

    // ===== 2. TOTAL SERVICES (in selected currency) =====
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

    // ===== 3. TOTAL WASTES (in selected currency) =====
    _totalWastes = filteredWastes.fold<double>(0, (sum, waste) {
      final price = double.tryParse(waste['value']?.toString() ?? '0') ?? 0;
      final currency = waste['currency']?.toString() ?? 'USD';
      final exchangeRate = double.tryParse(waste['exchange_rate']?.toString() ?? '1') ?? 1;
      
      if (currency == 'USD' || currency == 'دلار' || currency == '\$') {
        return sum + price;
      } else if (currency == 'AFN' || currency == 'افغانی') {
        return sum + (exchangeRate > 0 ? price / exchangeRate : 0);
      }
      return sum + price;
    });

    // ===== 3.5 TOTAL SOLD WASTES (in selected currency) - NEW =====
    _totalSoldWastes = filteredWastes.fold<double>(0, (sum, waste) {
      // Only add if the waste is sold (is_sold == 1)
      if (waste['is_sold'] != 1) return sum;
      
      final sellPrice = double.tryParse(waste['sell_price']?.toString() ?? '0') ?? 0;
      final sellCurrency = waste['sell_currency']?.toString() ?? 'USD';
      final exchangeRate = double.tryParse(waste['exchange_rate']?.toString() ?? '1') ?? 1;
      
      if (sellCurrency == 'USD' || sellCurrency == 'دلار' || sellCurrency == '\$') {
        return sum + sellPrice;
      } else if (sellCurrency == 'AFN' || sellCurrency == 'افغانی') {
        return sum + (exchangeRate > 0 ? sellPrice / exchangeRate : 0);
      }
      return sum + sellPrice;
    });

    // ===== 4. TOTAL RAW MATERIAL COST (in selected currency) =====
    _totalRawMaterialCost = _calculateRawMaterialCost(filteredSales);

    // ===== 5. GROSS PROFIT = (Sales + Services) - Raw Material Cost =====
    final totalIncome = _totalSales + _totalServices;
    _grossProfit = totalIncome - _totalRawMaterialCost;
    _profitMargin = totalIncome > 0 ? (_grossProfit / totalIncome) * 100 : 0;

    // ===== 6. TOTAL DAILY EXPENSES (in selected currency) =====
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

    // ===== 7. NET PROFIT = Gross Profit - Wastes - Daily Expenses + Sold Wastes =====
    // Sold wastes are ADDED back to net profit because they are income from selling wastes
    _netProfit = _grossProfit - _totalWastes - _totalExpenses + _totalSoldWastes;
    _netProfitMargin = totalIncome > 0 ? (_netProfit / totalIncome) * 100 : 0;
  }

  // ============ FIXED RAW MATERIAL COST CALCULATION ============
  double _calculateRawMaterialCost(List<Map<String, dynamic>> filteredSales) {
    double totalRawMaterialCost = 0;

    for (var material in _rawMaterials) {
      double finalPrice = double.tryParse(material['final_price']?.toString() ?? '0') ?? 0;
      
      if (finalPrice == 0) {
        double unitPrice = double.tryParse(material['unit_price']?.toString() ?? '0') ?? 0;
        double netWeight = double.tryParse(material['net_weight']?.toString() ?? '0') ?? 0;
        
        String unit = material['unit']?.toString() ?? '';
        if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
          netWeight = netWeight / 1000;
        }
        
        finalPrice = netWeight * unitPrice;
        
        double product = double.tryParse(material['product']?.toString() ?? '0') ?? 0;
        double commission = double.tryParse(material['commission']?.toString() ?? '0') ?? 0;
        double transferCost = double.tryParse(material['transfer_cost']?.toString() ?? '0') ?? 0;
        double miscellaneous = double.tryParse(material['miscellaneous']?.toString() ?? '0') ?? 0;
        double ghurfedari = double.tryParse(material['ghurfedari']?.toString() ?? '0') ?? 0;
        double barchalani = double.tryParse(material['barchalani']?.toString() ?? '0') ?? 0;
        
        String currency = material['currency']?.toString() ?? 'AFN';
        double exchangeRate = double.tryParse(material['exchange_rate']?.toString() ?? '1') ?? 1;
        
        double totalAfnExpenses = product + commission + transferCost + miscellaneous + ghurfedari + barchalani;
        
        if (currency == 'USD' && _selectedCurrency == 'USD') {
          finalPrice += (exchangeRate > 0) ? (totalAfnExpenses / exchangeRate) : 0;
        } else if (currency == 'AFN' && _selectedCurrency == 'AFN') {
          finalPrice += totalAfnExpenses;
        } else if (currency == 'USD' && _selectedCurrency == 'AFN') {
          finalPrice = (finalPrice * exchangeRate) + totalAfnExpenses;
        } else if (currency == 'AFN' && _selectedCurrency == 'USD') {
          finalPrice = (exchangeRate > 0) ? ((finalPrice + totalAfnExpenses) / exchangeRate) : 0;
        }
      }
      
      totalRawMaterialCost += finalPrice;
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

  List<Map<String, dynamic>> _getFilteredWastes() {
    final range = _getGregorianRangeForPersianMonth(_selectedYear, _selectedMonth);
    final startDate = range[0];
    final endDate = range[1];

    return _wastes.where((waste) {
      final dateStr = waste['date_en']?.toString() ?? '';
      if (dateStr.isEmpty) return false;

      try {
        final parts = dateStr.split('-');
        if (parts.length != 3) return false;
        final year = int.tryParse(parts[0]) ?? 0;
        final month = int.tryParse(parts[1]) ?? 0;
        final day = int.tryParse(parts[2]) ?? 0;
        final wasteDate = DateTime(year, month, day);

        return wasteDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
               wasteDate.isBefore(endDate.add(const Duration(days: 1)));
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

  // ============ FORMAT FUNCTIONS - NO DECIMAL POINTS ============
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

  // ============ PDF REPORT ============
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
    
    pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/companylogo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      print('Error loading logo: $e');
    }

    final filteredSales = _getFilteredSales();
    final filteredServices = _getFilteredServices();
    final filteredWastes = _getFilteredWastes();
    final filteredExpenses = _getFilteredExpenses();
    
    final monthName = _persianMonths[_selectedMonth - 1];
    final currencySymbol = _selectedCurrency == 'USD' ? '\$' : '؋';

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
                // HEADER
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

                // SUMMARY CARDS
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
                      _buildSummaryItem(ttf, 'ضایعات', _formatCurrency(_totalWastes), PdfColors.purple),
                      _buildSummaryItem(ttf, 'فروش ضایعات', _formatCurrency(_totalSoldWastes), PdfColors.teal),
                      _buildSummaryItem(ttf, l10n.rawMaterialCost, _formatCurrency(_totalRawMaterialCost), PdfColors.orange),
                      _buildSummaryItem(ttf, l10n.grossProfitLabel, _formatCurrency(_grossProfit), _grossProfit >= 0 ? PdfColors.green : PdfColors.red),
                      _buildSummaryItem(ttf, l10n.dailyExpensesLabel, _formatCurrency(_totalExpenses), PdfColors.purple),
                      _buildSummaryItem(ttf, l10n.netProfitLabel, _formatCurrency(_netProfit), _netProfit >= 0 ? PdfColors.green : PdfColors.red),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),

                // GROSS PROFIT DETAIL
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '📊 ${l10n.grossProfitLabel}',
                        style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 8),
                      _buildProfitRow(ttf, 'فروش', _formatCurrency(_totalSales)),
                      _buildProfitRow(ttf, 'خدمات', _formatCurrency(_totalServices)),
                      _buildProfitRow(ttf, 'جمع فروش و خدمات', _formatCurrency(_totalSales + _totalServices), isBold: true),
                      _buildProfitRow(ttf, '(-) هزینه مواد خام', _formatCurrency(_totalRawMaterialCost), isRed: true),
                      pw.Divider(),
                      _buildProfitRow(ttf, '= سود ناخالص', _formatCurrency(_grossProfit), isBold: true, isGreen: _grossProfit >= 0),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),

                // NET PROFIT DETAIL
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '📊 ${l10n.netProfitLabel}',
                        style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 8),
                      _buildProfitRow(ttf, 'سود ناخالص', _formatCurrency(_grossProfit)),
                      _buildProfitRow(ttf, '(-) ضایعات', _formatCurrency(_totalWastes), isRed: true),
                      _buildProfitRow(ttf, '(+) فروش ضایعات', _formatCurrency(_totalSoldWastes), isGreen: true),
                      _buildProfitRow(ttf, '(-) مخارج روزانه', _formatCurrency(_totalExpenses), isRed: true),
                      pw.Divider(),
                      _buildProfitRow(ttf, '= سود خالص', _formatCurrency(_netProfit), isBold: true, isGreen: _netProfit >= 0),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),

                // SALES TABLE
                pw.Text(
                  '📦 ${l10n.productSales}',
                  style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                _buildSalesTablePDF(ttf, filteredSales, currencySymbol),
                
                pw.SizedBox(height: 12),
                
                // SERVICES TABLE
                pw.Text(
                  '🔧 ${l10n.serviceSales}',
                  style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                _buildServicesTablePDF(ttf, filteredServices, currencySymbol),
                
                pw.SizedBox(height: 12),
                
                // WASTES TABLE
                pw.Text(
                  '♻️ ضایعات',
                  style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                _buildWastesTablePDF(ttf, filteredWastes, currencySymbol),
                
                pw.SizedBox(height: 12),
                
                // EXPENSES TABLE
                pw.Text(
                  '🧾 ${l10n.dailyExpensesDetails}',
                  style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                _buildPDFExpensesTable(ttf, filteredExpenses, currencySymbol),
                
                pw.Spacer(),
                
                // FOOTER
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

  pw.Widget _buildProfitRow(pw.Font font, String label, String value, {bool isBold = false, bool isRed = false, bool isGreen = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: font,
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isRed ? PdfColors.red : (isGreen ? PdfColors.green : PdfColors.black),
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
      double displayAmount = amount;
      if (sale['currency'] == 'AFN' && _selectedCurrency == 'USD') {
        final rate = double.tryParse(sale['price_rate']?.toString() ?? '1') ?? 1;
        displayAmount = rate > 0 ? amount / rate : 0;
      } else if (sale['currency'] == 'USD' && _selectedCurrency == 'AFN') {
        final rate = double.tryParse(sale['price_rate']?.toString() ?? '1') ?? 1;
        displayAmount = amount * rate;
      }
      
      tableData.add([
        sale['invoice_number']?.toString() ?? '-',
        sale['customer_name']?.toString() ?? '-',
        sale['product_name']?.toString() ?? '-',
        '${_formatNumber(displayAmount)} $currencySymbol',
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
      double displayAmount = amount;
      if (service['currency'] == 'AFN' && _selectedCurrency == 'USD') {
        final rate = double.tryParse(service['exchange_rate']?.toString() ?? '1') ?? 1;
        displayAmount = rate > 0 ? amount / rate : 0;
      } else if (service['currency'] == 'USD' && _selectedCurrency == 'AFN') {
        final rate = double.tryParse(service['exchange_rate']?.toString() ?? '1') ?? 1;
        displayAmount = amount * rate;
      }
      
      tableData.add([
        service['invoice_number']?.toString() ?? '-',
        service['customer_name']?.toString() ?? '-',
        service['service_title']?.toString() ?? service['service_type']?.toString() ?? '-',
        '${_formatNumber(displayAmount)} $currencySymbol',
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
    );
  }

  pw.Widget _buildWastesTablePDF(pw.Font font, List<Map<String, dynamic>> wastes, String currencySymbol) {
    final l10n = AppLocalizations.of(context)!;
    
    if (wastes.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text(
            'هیچ ضایعاتی در این ماه ثبت نشده است',
            style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
          ),
        ),
      );
    }

    List<List<String>> tableData = [];
    for (var waste in wastes) {
      final value = double.tryParse(waste['value']?.toString() ?? '0') ?? 0;
      final currency = waste['currency']?.toString() ?? 'USD';
      final exchangeRate = double.tryParse(waste['exchange_rate']?.toString() ?? '1') ?? 1;
      
      double displayAmount;
      if (_selectedCurrency == 'USD') {
        displayAmount = currency == 'AFN' ? (exchangeRate > 0 ? value / exchangeRate : 0) : value;
      } else {
        displayAmount = currency == 'AFN' ? value : value * exchangeRate;
      }
      
      final weight = double.tryParse(waste['weight']?.toString() ?? '0') ?? 0;
      final isSold = waste['is_sold'] == 1;
      final sellPrice = double.tryParse(waste['sell_price']?.toString() ?? '0') ?? 0;
      final sellCurrency = waste['sell_currency']?.toString() ?? 'USD';
      
      double displaySellPrice = 0;
      if (isSold && sellPrice > 0) {
        if (_selectedCurrency == 'USD') {
          displaySellPrice = sellCurrency == 'AFN' ? (exchangeRate > 0 ? sellPrice / exchangeRate : 0) : sellPrice;
        } else {
          displaySellPrice = sellCurrency == 'AFN' ? sellPrice : sellPrice * exchangeRate;
        }
      }
      
      tableData.add([
        waste['invoice_number']?.toString() ?? '-',
        waste['date']?.toString() ?? '-',
        waste['waste_type']?.toString() ?? '-',
        '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 2)}',
        '${_formatNumber(displayAmount)} $currencySymbol',
        isSold ? '✅ فروخته شده' : '⬜️ فروخته نشده',
        isSold ? '${_formatNumber(displaySellPrice)} $currencySymbol' : '-',
      ]);
    }

    return pw.Table.fromTextArray(
      headers: ['شماره', 'تاریخ', 'نوع ضایعات', 'وزن', 'مبلغ', 'وضعیت', 'قیمت فروش'],
      data: tableData,
      headerStyle: pw.TextStyle(
        font: font,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.purple),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      cellAlignment: pw.Alignment.centerRight,
      border: pw.TableBorder.symmetric(
        outside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      ),
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
                  '${l10n.incomesManagementSubtitle} (شامل کالا، خدمات و ضایعات)',
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
                  '${_getFilteredSales().length} ${l10n.sales} | ${_getFilteredServices().length} ${l10n.services} | ${_getFilteredWastes().length} ضایعات | ${_getFilteredExpenses().length} ${l10n.expenses}',
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

  // ============ TAB 1: GROSS PROFIT ============
  Widget _buildGrossProfitView(AppLocalizations l10n) {
    final totalSalesAndServices = _totalSales + _totalServices;
    final isProfit = _grossProfit >= 0;

    return Column(
      children: [
        Row(
          children: [
            _buildIncomeCard(
              title: 'فروش',
              amount: _totalSales,
              icon: Icons.shopping_bag_outlined,
              color: Colors.blue.shade700,
              subtitle: '${_getFilteredSales().length} فاکتور',
            ),
            const SizedBox(width: 12),
            _buildIncomeCard(
              title: 'خدمات',
              amount: _totalServices,
              icon: Icons.design_services_outlined,
              color: Colors.green.shade700,
              subtitle: '${_getFilteredServices().length} فاکتور',
            ),
            const SizedBox(width: 12),
            _buildIncomeCard(
              title: 'هزینه مواد خام',
              amount: _totalRawMaterialCost,
              icon: Icons.warehouse_outlined,
              color: Colors.orange.shade700,
              subtitle: 'بهای تمام شده',
            ),
            const SizedBox(width: 12),
            _buildIncomeCard(
              title: 'سود ناخالص',
              amount: _grossProfit,
              icon: Icons.account_balance_rounded,
              color: isProfit ? Colors.green.shade700 : Colors.red.shade700,
              subtitle: '${_profitMargin.toStringAsFixed(1)}% حاشیه سود',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildGrossProfitDetail(totalSalesAndServices),
        const SizedBox(height: 12),
        Expanded(
          child: _buildCombinedTable(l10n),
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

  Widget _buildGrossProfitDetail(double totalSalesAndServices) {
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
          color: _grossProfit >= 0 ? Colors.green.shade200 : Colors.red.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildProfitDetailItem(
            label: 'فروش + خدمات',
            value: _formatCurrency(totalSalesAndServices),
            color: Colors.blue.shade700,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.shade200,
          ),
          _buildProfitDetailItem(
            label: '(-) هزینه مواد خام',
            value: _formatCurrency(_totalRawMaterialCost),
            color: Colors.orange.shade700,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.shade200,
          ),
          _buildProfitDetailItem(
            label: '= سود ناخالص',
            value: _formatCurrency(_grossProfit),
            color: _grossProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProfitDetailItem({
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ============ TAB 2: NET PROFIT ============
  Widget _buildNetProfitView(AppLocalizations l10n) {
    final isProfit = _netProfit >= 0;

    return Column(
      children: [
        Row(
          children: [
            _buildIncomeCard(
              title: 'سود ناخالص',
              amount: _grossProfit,
              icon: Icons.trending_up_rounded,
              color: _grossProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              subtitle: 'قبل از کسورات',
            ),
            const SizedBox(width: 12),
            _buildIncomeCard(
              title: 'ضایعات',
              amount: _totalWastes,
              icon: Icons.recycling_outlined,
              color: Colors.purple.shade700,
              subtitle: '${_getFilteredWastes().length} فاکتور',
            ),
            const SizedBox(width: 12),
            _buildIncomeCard(
              title: 'فروش ضایعات',
              amount: _totalSoldWastes,
              icon: Icons.sell_outlined,
              color: Colors.teal.shade700,
              subtitle: 'از ضایعات فروخته شده',
            ),
            const SizedBox(width: 12),
            _buildIncomeCard(
              title: 'مخارج روزانه',
              amount: _totalExpenses,
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.orange.shade700,
              subtitle: '${_getFilteredExpenses().length} مورد',
            ),
            const SizedBox(width: 12),
            _buildIncomeCard(
              title: 'سود خالص',
              amount: _netProfit,
              icon: Icons.account_balance_rounded,
              color: isProfit ? Colors.green.shade700 : Colors.red.shade700,
              subtitle: '${_netProfitMargin.toStringAsFixed(1)}% حاشیه سود',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildNetProfitDetail(),
        const SizedBox(height: 12),
        Expanded(
          child: _buildCombinedTable(l10n),
        ),
      ],
    );
  }

  Widget _buildNetProfitDetail() {
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
          color: _netProfit >= 0 ? Colors.green.shade200 : Colors.red.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildProfitDetailItem(
            label: 'سود ناخالص',
            value: _formatCurrency(_grossProfit),
            color: _grossProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.shade200,
          ),
          _buildProfitDetailItem(
            label: '(-) ضایعات',
            value: _formatCurrency(_totalWastes),
            color: Colors.purple.shade700,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.shade200,
          ),
          _buildProfitDetailItem(
            label: '(+) فروش ضایعات',
            value: _formatCurrency(_totalSoldWastes),
            color: Colors.teal.shade700,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.shade200,
          ),
          _buildProfitDetailItem(
            label: '(-) مخارج روزانه',
            value: _formatCurrency(_totalExpenses),
            color: Colors.orange.shade700,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.shade200,
          ),
          _buildProfitDetailItem(
            label: '= سود خالص',
            value: _formatCurrency(_netProfit),
            color: _netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
            isBold: true,
          ),
        ],
      ),
    );
  }

  // ============ COMBINED TABLE ============
  Widget _buildCombinedTable(AppLocalizations l10n) {
    final filteredSales = _getFilteredSales();
    final filteredServices = _getFilteredServices();
    final filteredWastes = _getFilteredWastes();

    List<Map<String, dynamic>> combinedItems = [
      ...filteredSales.map((s) => {...s, '_type': 'sale'}),
      ...filteredServices.map((s) => {...s, '_type': 'service'}),
      ...filteredWastes.map((s) => {...s, '_type': 'waste'}),
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
                const Expanded(flex: 2, child: Text('شرح', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 1, child: Text('مبلغ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
                const Expanded(flex: 1, child: Text('تاریخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
              ],
            ),
          ),
          Expanded(
            child: paged.isEmpty
                ? Center(child: Text('هیچ موردی یافت نشد', style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: paged.length,
                    itemBuilder: (context, index) {
                      final item = paged[index];
                      final type = item['_type'];
                      final isService = type == 'service';
                      final isWaste = type == 'waste';
                      
                      double amount = 0;
                      if (isWaste) {
                        final value = double.tryParse(item['value']?.toString() ?? '0') ?? 0;
                        final currency = item['currency']?.toString() ?? 'USD';
                        final exchangeRate = double.tryParse(item['exchange_rate']?.toString() ?? '1') ?? 1;
                        if (_selectedCurrency == 'USD') {
                          amount = currency == 'AFN' ? (exchangeRate > 0 ? value / exchangeRate : 0) : value;
                        } else {
                          amount = currency == 'AFN' ? value : value * exchangeRate;
                        }
                      } else {
                        final price = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0;
                        final currency = item['currency']?.toString() ?? 'USD';
                        final exchangeRate = double.tryParse(item['price_rate']?.toString() ?? '1') ?? 1;
                        if (currency == 'AFN' && _selectedCurrency == 'USD') {
                          amount = exchangeRate > 0 ? price / exchangeRate : 0;
                        } else if (currency == 'USD' && _selectedCurrency == 'AFN') {
                          amount = price * exchangeRate;
                        } else {
                          amount = price;
                        }
                      }

                      String typeLabel = 'فروش';
                      Color bgColor = Colors.green.shade100;
                      Color textColor = Colors.green.shade800;
                      
                      if (isService) {
                        typeLabel = 'خدمات';
                        bgColor = Colors.blue.shade100;
                        textColor = Colors.blue.shade800;
                      } else if (isWaste) {
                        typeLabel = 'ضایعات';
                        bgColor = Colors.purple.shade100;
                        textColor = Colors.purple.shade800;
                      }

                      String description = item['product_name']?.toString() ?? '-';
                      if (isService) {
                        description = item['service_title']?.toString() ?? item['service_type']?.toString() ?? '-';
                      } else if (isWaste) {
                        description = '${item['waste_type']?.toString() ?? ''} - ${item['party_details']?.toString() ?? ''}';
                      }

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
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Expanded(flex: 1, child: Text(item['invoice_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            Expanded(flex: 2, child: Text(
                              item['customer_name']?.toString() ?? item['party_details']?.toString() ?? '-', 
                              style: const TextStyle(fontSize: 11), 
                              overflow: TextOverflow.ellipsis
                            )),
                            Expanded(
                              flex: 2,
                              child: Text(
                                description,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(flex: 1, child: Text(
                              _formatCurrency(amount), 
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue), 
                              textAlign: TextAlign.center
                            )),
                            Expanded(flex: 1, child: Text(
                              item['date']?.toString() ?? '-', 
                              style: const TextStyle(fontSize: 10, color: Colors.grey), 
                              textAlign: TextAlign.center
                            )),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _buildPagination(combinedItems.length, totalPages),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalItems, int totalPages) {
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
              Text('صفحه ${_currentPage + 1} از ${totalPages == 0 ? 1 : totalPages}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
              Text('$totalItems مورد', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
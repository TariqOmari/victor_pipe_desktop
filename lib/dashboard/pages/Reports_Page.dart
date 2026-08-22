import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DatabaseHelper _db = DatabaseHelper();
  
  String _selectedReportId = 'raw_materials';
  String _selectedReportLabel = 'مواد خام';
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _reportData = [];
  final ScrollController _horizontalScrollController = ScrollController();

  // Date range filter variables - DROPDOWN SELECTORS
  bool _useDateRange = false;
  String _fromYear = '';
  String _fromMonth = '';
  String _fromDay = '';
  String _toYear = '';
  String _toMonth = '';
  String _toDay = '';

  Map<String, dynamic> _statsData = {
    'today_count': 0, 'today_total_afn': 0.0, 'today_total_usd': 0.0,
    'week_count': 0, 'week_total_afn': 0.0, 'week_total_usd': 0.0,
    'month_count': 0, 'month_total_afn': 0.0, 'month_total_usd': 0.0,
    'total_weight_tons': 0.0,
    'total_net_weight_tons': 0.0,
    'total_gross_weight_tons': 0.0,
  };

  final List<String> _persianMonths = [
    'حمل', 'ثور', 'جوزا', 'سرطان', 
    'اسد', 'سنبله', 'میزان', 'عقرب', 
    'قوس', 'جدی', 'دلو', 'حوت'
  ];

  final Map<String, String> _persianMonthToNumber = {
    'حمل': '01', 'ثور': '02', 'جوزا': '03', 'سرطان': '04',
    'اسد': '05', 'سنبله': '06', 'میزان': '07', 'عقرب': '08',
    'قوس': '09', 'جدی': '10', 'دلو': '11', 'حوت': '12'
  };
  
  late List<ReportType> _reportTypes;

  // Dropdown options
  List<String> get _dayOptions => ['روز'] + List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
  List<String> get _monthOptions => ['ماه'] + _persianMonths;
  List<String> get _yearOptions {
    final currentYear = int.parse(PersianDateConverter.getCurrentPersianDate().split(RegExp(r'[-/]'))[0]);
    return ['سال'] + List.generate(10, (i) => (currentYear - i).toString());
  }

  @override
  void initState() {
    super.initState();
    _reportTypes = [];
    _loadData();
  }

  // Helper to check if unit is weight-based
  bool _isWeightUnit(String unit) {
    return unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg' || 
           unit == 'تن' || unit == 'ton' || unit == 'Ton';
  }

  // Format weight with conversion - ALWAYS shows kg as tons
  String _formatWeightWithConversion(String unit, double weight) {
    if (_isWeightUnit(unit)) {
      double tons = weight / 1000;
      if (tons < 0.01) {
        return '${tons.toStringAsFixed(3)} تن';
      }
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} $unit';
  }

  // Format weight for waste - converts kg to tons
  String _formatWasteWeight(double weight) {
    if (weight <= 0) return '0';
    double tons = weight / 1000;
    if (tons < 1) {
      return '${tons.toStringAsFixed(3)} تن';
    }
    return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
  }

  // Convert weight to tons (returns double)
  double _convertToTons(String unit, double weight) {
    if (_isWeightUnit(unit)) {
      if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
        return weight / 1000;
      }
      return weight;
    }
    return weight;
  }

  // Unit translation helper
  String _translateUnit(String unit, AppLocalizations l10n) {
    if (_isWeightUnit(unit)) return l10n.tonUnit;
    if (unit == 'متر' || unit == 'm' || unit == 'M') return l10n.meterUnit;
    if (unit == 'عدد' || unit == 'pcs' || unit == 'Pcs') return l10n.pcsUnit;
    if (unit == 'لیتر' || unit == 'l' || unit == 'L') return l10n.literUnit;
    return unit;
  }

  // Format unit with conversion for table display
  String _formatUnitWithConversion(String unit, double weight, AppLocalizations l10n) {
    if (_isWeightUnit(unit)) {
      double tons = weight / 1000;
      return '${tons.toStringAsFixed(1)} ${l10n.tonUnit}';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} ${_translateUnit(unit, l10n)}';
  }

  // Format currency WITHOUT K/M/B abbreviations (for tables)
  String _formatCurrencyNoK(dynamic value) {
    if (value == null) return '0';
    final number = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  // Format currency with K/M/B for stats
  String _formatCurrencyWithK(dynamic value) {
    if (value == null) return '0';
    final number = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
    if (number >= 1000000000) return '${(number / 1000000000).toStringAsFixed(1)}B';
    else if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    else if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  // Get category color
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'سوخت':
        return Colors.orange.shade700;
      case 'مواد اولیه':
        return Colors.blue.shade700;
      case 'حقوق کارگران':
        return Colors.purple.shade700;
      case 'تعمیرات':
        return Colors.red.shade700;
      case 'حمل و نقل':
        return Colors.green.shade700;
      case 'سایر':
        return Colors.grey.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  List<ReportType> _getLocalizedReportTypes(AppLocalizations l10n) {
    return [
      ReportType(
        id: 'raw_materials', 
        label: l10n.rawMaterials, 
        icon: Icons.inventory_2, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getRawMaterials(),
        hasFinancial: true,
        hasWeight: true,
        hasNetGrossWeight: true,
      ),
      ReportType(
        id: 'produced_products', 
        label: l10n.productionManagement, 
        icon: Icons.factory, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getProducedProducts(),
        hasFinancial: false,
        hasWeight: true,
        hasNetGrossWeight: true,
      ),
      ReportType(
        id: 'sales_invoices', 
        label: l10n.sales, 
        icon: Icons.receipt_long, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getSalesInvoices(),
        hasFinancial: true,
        hasWeight: true,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'daily_expenses', 
        label: l10n.dailyExpenses, 
        icon: Icons.money_off, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getDailyExpenses(),
        hasFinancial: true,
        hasWeight: false,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'waste_records', 
        label: l10n.wastes, 
        icon: Icons.delete_outline, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getWasteRecords(),
        hasFinancial: true,
        hasWeight: true,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'service_invoices', 
        label: l10n.services, 
        icon: Icons.build_circle, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getServiceInvoices(),
        hasFinancial: true,
        hasWeight: false,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'customers', 
        label: l10n.customers, 
        icon: Icons.people, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getCustomers(),
        hasFinancial: false,
        hasWeight: false,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'companies', 
        label: l10n.companiesListPage, 
        icon: Icons.business, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getCompanies(),
        hasFinancial: false,
        hasWeight: false,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'suppliers', 
        label: l10n.suppliers, 
        icon: Icons.local_shipping, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getSuppliers(),
        hasFinancial: false,
        hasWeight: false,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'sell_loans', 
        label: l10n.loans, 
        icon: Icons.credit_card, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getSellLoans(),
        hasFinancial: true,
        hasWeight: false,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'sarafi_transactions', 
        label: l10n.sarafi, 
        icon: Icons.currency_exchange, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getSarafiTransactions(),
        hasFinancial: true,
        hasWeight: false,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'capital_assets', 
        label: l10n.capital, 
        icon: Icons.account_balance, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getCapitalAssets(),
        hasFinancial: true,
        hasWeight: false,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'capital_transactions', 
        label: 'تراکنش‌های سرمایه', 
        icon: Icons.swap_horiz, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getCapitalTransactions(),
        hasFinancial: true,
        hasWeight: false,
        hasNetGrossWeight: false,
      ),
      ReportType(
        id: 'sarafi_accounts', 
        label: 'حساب‌های صرافی', 
        icon: Icons.account_balance_wallet, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getSarafiAccounts(),
        hasFinancial: true,
        hasWeight: false,
        hasNetGrossWeight: false,
      ),
    ];
  }

  // Helper function to convert Persian date string to comparable format
  String _normalizePersianDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    dateStr = dateStr.trim();
    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    const englishDigits = '0123456789';
    for (int i = 0; i < persianDigits.length; i++) {
      dateStr = dateStr.replaceAll(persianDigits[i], englishDigits[i]);
    }
    dateStr = dateStr.replaceAll('/', '-');
    return dateStr;
  }

  // Parse Persian date string to a comparable integer (YYYYMMDD)
  int _parsePersianDateToInt(String dateStr) {
    if (dateStr.isEmpty) return 0;
    dateStr = _normalizePersianDate(dateStr);
    final parts = dateStr.split('-');
    if (parts.length < 3) return 0;
    try {
      final year = int.parse(parts[0].padLeft(4, '0'));
      final month = int.parse(parts[1].padLeft(2, '0'));
      final day = int.parse(parts[2].padLeft(2, '0'));
      return year * 10000 + month * 100 + day;
    } catch (e) {
      return 0;
    }
  }

  // Helper to check if all date parts are selected
  bool _isDateComplete(String year, String month, String day) {
    return year.isNotEmpty && month.isNotEmpty && day.isNotEmpty && 
           year != 'سال' && month != 'ماه' && day != 'روز';
  }

  // Get formatted date from dropdowns
  String _getFormattedDate(String year, String month, String day) {
    if (!_isDateComplete(year, month, day)) return '';
    final monthNumber = _persianMonthToNumber[month] ?? '';
    if (monthNumber.isEmpty) return '';
    return '$year-$monthNumber-$day';
  }

  // Check if date is within range
  bool _isDateInRange(String dateStr) {
    if (!_useDateRange || dateStr.isEmpty) return true;
    
    final dateInt = _parsePersianDateToInt(dateStr);
    if (dateInt == 0) return true;
    
    final fromDate = _getFormattedDate(_fromYear, _fromMonth, _fromDay);
    final toDate = _getFormattedDate(_toYear, _toMonth, _toDay);
    
    if (fromDate.isEmpty || toDate.isEmpty) return true;
    
    final fromInt = _parsePersianDateToInt(fromDate);
    final toInt = _parsePersianDateToInt(toDate);
    
    if (fromInt > 0 && dateInt < fromInt) return false;
    if (toInt > 0 && dateInt > toInt) return false;
    
    return true;
  }

  // Apply date filter when both dates are complete
  void _applyDateFilter() {
    bool fromComplete = _isDateComplete(_fromYear, _fromMonth, _fromDay);
    bool toComplete = _isDateComplete(_toYear, _toMonth, _toDay);
    
    if (_useDateRange && fromComplete && toComplete) {
      _loadData();
    } else if (!_useDateRange) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      ReportType? reportType;
      try {
        reportType = _reportTypes.firstWhere(
          (r) => r.id == _selectedReportId,
        );
      } catch (e) {
        if (_reportTypes.isNotEmpty) {
          reportType = _reportTypes.first;
          _selectedReportId = reportType.id;
          _selectedReportLabel = reportType.label;
        }
      }
      
      if (reportType == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      List<Map<String, dynamic>> data = await reportType.fetchData(_db);

      // Process data
      List<Map<String, dynamic>> processedData = data.map((item) {
        var newItem = Map<String, dynamic>.from(item);
        
        // Convert weight fields to tons
        String unit = item['unit']?.toString() ?? 'kg';
        
        if (item.containsKey('weight') && item['weight'] != null) {
          double weight = double.tryParse(item['weight']?.toString() ?? '0') ?? 0;
          newItem['weight_display'] = _formatWeightWithConversion(unit, weight);
          newItem['weight_tons'] = _convertToTons(unit, weight);
        }
        
        if (item.containsKey('total_weight') && item['total_weight'] != null) {
          double totalWeight = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
          newItem['total_weight_display'] = _formatWeightWithConversion(unit, totalWeight);
          newItem['total_weight_tons'] = _convertToTons(unit, totalWeight);
        }
        
        if (item.containsKey('net_weight') && item['net_weight'] != null) {
          double netWeight = double.tryParse(item['net_weight']?.toString() ?? '0') ?? 0;
          newItem['net_weight_display'] = _formatWeightWithConversion(unit, netWeight);
          newItem['net_weight_tons'] = _convertToTons(unit, netWeight);
        }
        
        if (item.containsKey('gross_weight') && item['gross_weight'] != null) {
          double grossWeight = double.tryParse(item['gross_weight']?.toString() ?? '0') ?? 0;
          newItem['gross_weight_display'] = _formatWeightWithConversion(unit, grossWeight);
          newItem['gross_weight_tons'] = _convertToTons(unit, grossWeight);
        }
        
        return newItem;
      }).toList();

      // Apply date range filter
      List<Map<String, dynamic>> filteredData = processedData.where((item) {
        String itemDate = item['date']?.toString() ?? item['date_en']?.toString() ?? '';
        if (itemDate.isEmpty) return true;
        return _isDateInRange(itemDate);
      }).toList();

      // Calculate statistics
      final todayPersianDate = PersianDateConverter.getCurrentPersianDate();
      final todayParts = todayPersianDate.split(RegExp(r'[-/]'));
      final currentYearMonth = todayParts[0] + "-" + todayParts[1];

      int todayCount = 0, monthCount = 0;
      double todayTotalAFN = 0.0, todayTotalUSD = 0.0;
      double monthTotalAFN = 0.0, monthTotalUSD = 0.0;
      double totalWeightTons = 0.0;
      double totalNetWeightTons = 0.0;
      double totalGrossWeightTons = 0.0;

      for (var item in processedData) {
        String itemDate = item['date']?.toString() ?? item['date_en']?.toString() ?? '';
        
        double weight = double.tryParse(item['weight_tons']?.toString() ?? '0') ?? 0;
        if (weight == 0) {
          weight = double.tryParse(item['total_weight_tons']?.toString() ?? '0') ?? 0;
        }
        totalWeightTons += weight;
        
        double netWeight = double.tryParse(item['net_weight_tons']?.toString() ?? '0') ?? 0;
        totalNetWeightTons += netWeight;
        
        double grossWeight = double.tryParse(item['gross_weight_tons']?.toString() ?? '0') ?? 0;
        totalGrossWeightTons += grossWeight;

        // Handle different report types
        String currency = item['currency']?.toString()?.toUpperCase() ?? 'AFN';
        double amount = 0;
        double usdEquivalent = 0;
        
        if (_selectedReportId == 'daily_expenses') {
          amount = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          usdEquivalent = double.tryParse(item['usd_equivalent']?.toString() ?? '0') ?? 0;
          
          if (currency == 'دالر' || currency == 'USD') {
            todayTotalUSD += amount;
            todayTotalAFN += usdEquivalent;
            monthTotalUSD += amount;
            monthTotalAFN += usdEquivalent;
          } else {
            todayTotalAFN += amount;
            todayTotalUSD += usdEquivalent;
            monthTotalAFN += amount;
            monthTotalUSD += usdEquivalent;
          }
        } else if (_selectedReportId == 'waste_records') {
          amount = double.tryParse(item['value']?.toString() ?? '0') ?? 0;
          usdEquivalent = double.tryParse(item['afn_equivalent']?.toString() ?? '0') ?? 0;
          
          if (currency == 'USD') {
            todayTotalUSD += amount;
            todayTotalAFN += usdEquivalent;
            monthTotalUSD += amount;
            monthTotalAFN += usdEquivalent;
          } else {
            todayTotalAFN += amount;
            todayTotalUSD += usdEquivalent;
            monthTotalAFN += amount;
            monthTotalUSD += usdEquivalent;
          }
        } else {
          amount = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0;
          if (amount == 0) {
            amount = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
          }
          if (amount == 0) {
            amount = double.tryParse(item['total_amount']?.toString() ?? '0') ?? 0;
          }
          if (amount == 0) {
            amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
          }
          if (amount == 0) {
            amount = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          }
          
          double afnAmount = 0;
          double usdAmount = 0;
          
          if (currency == 'USD') {
            usdAmount = amount;
          } else {
            afnAmount = amount;
          }
          
          if (itemDate == todayPersianDate) { 
            todayCount++; 
            todayTotalAFN += afnAmount;
            todayTotalUSD += usdAmount;
          }
          if (itemDate.startsWith(currentYearMonth)) { 
            monthCount++; 
            monthTotalAFN += afnAmount;
            monthTotalUSD += usdAmount;
          }
        }
      }

      setState(() {
        _statsData = {
          'today_count': todayCount, 
          'today_total_afn': todayTotalAFN,
          'today_total_usd': todayTotalUSD,
          'week_count': monthCount,
          'week_total_afn': monthTotalAFN,
          'week_total_usd': monthTotalUSD,
          'month_count': monthCount,
          'month_total_afn': monthTotalAFN,
          'month_total_usd': monthTotalUSD,
          'total_weight_tons': totalWeightTons,
          'total_net_weight_tons': totalNetWeightTons,
          'total_gross_weight_tons': totalGrossWeightTons,
        };
        _reportData = filteredData;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorLoadingDataReports} $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    _reportTypes = _getLocalizedReportTypes(l10n);
    
    bool idExists = _reportTypes.any((r) => r.id == _selectedReportId);
    if (!idExists && _reportTypes.isNotEmpty) {
      _selectedReportId = _reportTypes.first.id;
      _selectedReportLabel = _reportTypes.first.label;
    } else if (idExists) {
      final currentType = _reportTypes.firstWhere((r) => r.id == _selectedReportId);
      _selectedReportLabel = currentType.label;
    }

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              _buildHeader(l10n, isEnglish),
              const SizedBox(height: 12),
              _buildFilters(l10n, isEnglish),
              const SizedBox(height: 12),
              _buildStats(l10n),
              const SizedBox(height: 12),
              if (_isLoading) 
                Center(child: CircularProgressIndicator(color: const Color(0xFFCB001D)))
              else if (_reportData.isEmpty)
                _buildEmptyState(l10n)
              else
                _buildReportTable(l10n, isEnglish),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, bool isEnglish) {
    final reportType = _reportTypes.firstWhere(
      (r) => r.id == _selectedReportId,
      orElse: () => _reportTypes.first,
    );
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFCB001D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCB001D).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.factory, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.victorPipeCompanyName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.report_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reportsManagementTitle,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '${_selectedReportLabel} - ${_reportData.length} ${l10n.recordsCountLabel}',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                      ),
                      if (_useDateRange && _isDateComplete(_fromYear, _fromMonth, _fromDay) && 
                          _isDateComplete(_toYear, _toMonth, _toDay))
                        Text(
                          'از ${_getFormattedDate(_fromYear, _fromMonth, _fromDay)} تا ${_getFormattedDate(_toYear, _toMonth, _toDay)}',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                        ),
                      if (reportType.hasNetGrossWeight)
                        Row(
                          children: [
                            Text(
                              'وزن خالص: ${_formatNumber(_statsData['total_net_weight_tons'])} تن',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'وزن ناخالص: ${_formatNumber(_statsData['total_gross_weight_tons'])} تن',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildExportButton(l10n),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.print, 
                    label: l10n.printReportBtn, 
                    color: Colors.white, 
                    backgroundColor: Colors.white.withOpacity(0.2), 
                    onPressed: _printReport,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ NEW EXPORT WITH CUSTOM NAME AND LOCATION ============
  Widget _buildExportButton(AppLocalizations l10n) {
    return ElevatedButton.icon(
      onPressed: () => _showExportDialog(l10n),
      icon: const Icon(Icons.download, color: Colors.white, size: 20),
      label: Text(
        l10n.excelExport,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showExportDialog(AppLocalizations l10n) async {
    final TextEditingController fileNameController = TextEditingController(
      text: 'VictorPipe_${_selectedReportId}_${DateTime.now().millisecondsSinceEpoch}'
    );
    
    String? selectedDirectory;
    String? selectedPath;
    
    // Try to get default downloads directory
    try {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        selectedDirectory = dir.path;
        selectedPath = dir.path;
      }
    } catch (e) {
      // Fallback to documents directory
      try {
        final dir = await getApplicationDocumentsDirectory();
        selectedDirectory = dir.path;
        selectedPath = dir.path;
      } catch (e) {
        // ignore
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.save_alt, color: Color(0xFFCB001D), size: 28),
              const SizedBox(width: 12),
              Text(
                'ذخیره فایل اکسل',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report type info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCB001D).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFCB001D), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'نوع گزارش: $_selectedReportLabel',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // File name
                Text(
                  'نام فایل',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: fileNameController,
                  decoration: InputDecoration(
                    hintText: 'نام فایل را وارد کنید',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2),
                    ),
                    prefixIcon: const Icon(Icons.description, color: Color(0xFFCB001D)),
                    suffixText: '.xlsx',
                    suffixStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Location picker
                Text(
                  'مسیر ذخیره',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_open, color: Color(0xFFCB001D), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedPath ?? 'انتخاب مسیر...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selectedPath != null ? Colors.black : Colors.grey.shade500,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        String? selectedFolder = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: 'انتخاب مسیر ذخیره',
                        );
                        if (selectedFolder != null) {
                          selectedPath = selectedFolder;
                          setState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB001D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('انتخاب'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Info about data
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.data_usage, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_getFilteredData().length} رکورد برای صادرات',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                fileNameController.dispose();
                Navigator.pop(context);
              },
              child: Text(
                'لغو',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final fileName = fileNameController.text.trim();
                if (fileName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('لطفاً نام فایل را وارد کنید'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                if (selectedPath == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('لطفاً مسیر ذخیره را انتخاب کنید'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                Navigator.pop(context);
                await _exportToExcel(fileName, selectedPath!, l10n);
                fileNameController.dispose();
              },
              icon: const Icon(Icons.save, size: 18),
              label: const Text('ذخیره'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ EXPORT TO EXCEL WITH CUSTOM NAME AND LOCATION ============
  Future<void> _exportToExcel(String fileName, String savePath, AppLocalizations l10n) async {
    try {
      final reportType = _reportTypes.firstWhere(
        (r) => r.id == _selectedReportId,
        orElse: () => _reportTypes.first,
      );
      
      List<Map<String, dynamic>> dataToExport = _getFilteredData();
          
      if (dataToExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noDataToExportMsg), backgroundColor: Colors.orange),
        );
        return;
      }

      // Create Excel file
      var excelFile = excel.Excel.createExcel();
      
      // Get headers based on report type
      List<String> headers = _getExcelHeaders();
      
      // Add sheet
      excel.Sheet sheet = excelFile['Sheet1'];
      
      // Add headers with styling
      List<excel.CellValue> headerRow = [];
      for (var header in headers) {
        headerRow.add(excel.TextCellValue(header));
      }
      sheet.appendRow(headerRow);
      
      // Add data rows
      for (var item in dataToExport) {
        List<excel.CellValue> row = [];
        String currency = item['currency']?.toString()?.toUpperCase() ?? 'AFN';
        
        for (var key in headers) {
          String value = '';
          
          // Map each header to the actual data
          if (key == 'شماره') {
            value = item['id']?.toString() ?? '';
          } else if (key == 'تاریخ') {
            value = (item['date']?.toString() ?? item['date_en']?.toString() ?? '').replaceAll('-', '/');
          } else if (key == 'نام مواد') {
            value = item['name']?.toString() ?? '';
          } else if (key == 'نام فروشنده') {
            value = item['supplier_name']?.toString() ?? '';
          } else if (key == 'تلفن فروشنده') {
            value = item['supplier_phone']?.toString() ?? '';
          } else if (key == 'آدرس فروشنده') {
            value = item['location']?.toString() ?? item['supplier_address']?.toString() ?? '';
          } else if (key == 'واحد') {
            String unit = item['unit']?.toString() ?? '';
            value = _translateUnit(unit, l10n);
          } else if (key == 'وزن خالص') {
            double netWeight = double.tryParse(item['net_weight']?.toString() ?? '0') ?? 0;
            String unit = item['unit']?.toString() ?? 'kg';
            value = _formatUnitWithConversion(unit, netWeight, l10n);
          } else if (key == 'وزن ناخالص') {
            double grossWeight = double.tryParse(item['gross_weight']?.toString() ?? '0') ?? 0;
            String unit = item['unit']?.toString() ?? 'kg';
            value = _formatUnitWithConversion(unit, grossWeight, l10n);
          } else if (key == 'قیمت واحد') {
            value = item['unit_price']?.toString() ?? '';
          } else if (key == 'مبلغ فروشنده') {
            value = '${item['seller_payment'] ?? ''} $currency';
          } else if (key == 'پرداخت اولیه') {
            value = '${item['seller_paid_amount'] ?? ''} $currency';
          } else if (key == 'روش پرداخت') {
            String method = item['seller_payment_method']?.toString() ?? 'cash';
            if (method == 'cash') value = 'نقد';
            else if (method == 'loan_full') value = 'قرض کامل';
            else if (method == 'loan_partial') value = 'قرض جزئی';
            else value = method;
          } else if (key == 'قیمت محصول') {
            value = item['product']?.toString() ?? '';
          } else if (key == 'کمیسیون') {
            value = item['commission']?.toString() ?? '';
          } else if (key == 'هزینه حمل') {
            value = item['transfer_cost']?.toString() ?? '';
          } else if (key == 'متفرقه') {
            value = item['miscellaneous']?.toString() ?? '';
          } else if (key == 'غرفه‌داری') {
            value = item['ghurfedari']?.toString() ?? '';
          } else if (key == 'برچالانی') {
            value = item['barchalani']?.toString() ?? '';
          } else if (key == 'نوع خرید') {
            value = item['purchase_type']?.toString() ?? '';
          } else if (key == 'قیمت نهایی') {
            value = '${item['final_price'] ?? ''} $currency';
          } else if (key == 'واحد پول') {
            value = currency;
          } else if (key == 'نوع تولید') {
            value = item['production_type']?.toString() ?? '';
          } else if (key == 'سایز') {
            value = item['size']?.toString() ?? '';
          } else if (key == 'ضخامت') {
            value = item['thickness']?.toString() ?? '';
          } else if (key == 'طول') {
            value = item['length']?.toString() ?? '';
          } else if (key == 'تعداد خاده') {
            value = item['raw_count']?.toString() ?? '';
          } else if (key == 'وزن فی خاده') {
            String unit = item['unit']?.toString() ?? '';
            double rawWeight = double.tryParse(item['raw_weight']?.toString() ?? '0') ?? 0;
            if (_isWeightUnit(unit)) {
              value = '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} کیلوگرم';
            } else {
              value = '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} $unit';
            }
          } else if (key == 'مجموع وزن') {
            String unit = item['unit']?.toString() ?? '';
            double totalWeight = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
            if (_isWeightUnit(unit)) {
              double tons = totalWeight / 1000;
              if (tons < 0.01) {
                value = '${tons.toStringAsFixed(3)} تن';
              } else {
                value = '${tons.toStringAsFixed(2)} تن';
              }
            } else {
              value = '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 1)} $unit';
            }
          } else if (key == 'وضعیت') {
            value = item['status']?.toString() ?? '';
          } else if (key == 'شماره فاکتور') {
            value = item['invoice_number']?.toString() ?? '';
          } else if (key == 'نوع') {
            value = item['sale_type']?.toString() ?? '';
          } else if (key == 'مشتری') {
            value = item['customer_name']?.toString() ?? '';
          } else if (key == 'شرکت') {
            value = item['customer_company']?.toString() ?? '';
          } else if (key == 'وزن فی خاده (kg)') {
            double weightPerUnit = double.tryParse(item['weight_per_unit']?.toString() ?? '0') ?? 0;
            value = weightPerUnit.toStringAsFixed(weightPerUnit % 1 == 0 ? 0 : 1);
          } else if (key == 'وزن کل (تن)') {
            double totalWeight = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
            double tons = totalWeight / 1000;
            value = tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2);
          } else if (key == 'قیمت کل') {
            if (currency == 'USD') {
              value = item['total_price']?.toString() ?? '';
            } else {
              value = item['afn_equivalent']?.toString() ?? '';
            }
          } else if (key == 'تخفیف') {
            value = item['discount']?.toString() ?? '';
          } else if (key == 'وضعیت فروش') {
            final isReturned = item['is_back_returned'] == 1 || item['is_back_returned']?.toString() == '1';
            value = isReturned ? 'برگشتی' : 'عادی';
          } else if (key == 'شماره بل') {
            value = item['invoice_number']?.toString() ?? '';
          } else if (key == 'شماره ثبت') {
            value = item['registration_number']?.toString() ?? '';
          } else if (key == 'تاریخ شمسی') {
            value = item['date']?.toString() ?? '';
          } else if (key == 'تاریخ میلادی') {
            value = item['date_en']?.toString() ?? '';
          } else if (key == 'دسته بندی') {
            value = item['category']?.toString() ?? '';
          } else if (key == 'شرح') {
            value = item['description']?.toString() ?? '';
          } else if (key == 'مبلغ') {
            double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
            value = price.toStringAsFixed(0);
          } else if (key == 'نرخ ارز') {
            value = item['exchange_rate']?.toString() ?? '';
          } else if (key == 'معادل') {
            double usdEquivalent = double.tryParse(item['usd_equivalent']?.toString() ?? '0') ?? 0;
            value = usdEquivalent.toStringAsFixed(0);
          } else if (key == 'طرف') {
            value = item['party_details']?.toString() ?? '';
          } else if (key == 'نوع ضایعات') {
            value = item['waste_type']?.toString() ?? '';
          } else if (key == 'وزن (تن)') {
            double weight = double.tryParse(item['weight']?.toString() ?? '0') ?? 0;
            value = _formatWasteWeight(weight);
          } else if (key == 'تعداد') {
            value = item['quantity']?.toString() ?? '';
          } else if (key == 'ارزش') {
            double valueAmount = double.tryParse(item['value']?.toString() ?? '0') ?? 0;
            value = valueAmount.toStringAsFixed(0);
          } else if (key == 'معادل افغانی') {
            double afnEquivalent = double.tryParse(item['afn_equivalent']?.toString() ?? '0') ?? 0;
            value = afnEquivalent.toStringAsFixed(0);
          } else if (key == 'تلفن') {
            value = item['customer_phone']?.toString() ?? '';
          } else if (key == 'آدرس') {
            value = item['customer_address']?.toString() ?? '';
          } else if (key == 'نوع خدمت') {
            value = item['service_type']?.toString() ?? '';
          } else if (key == 'هزینه بارگیری') {
            value = item['loading_cost']?.toString() ?? '';
          } else if (key == 'هزینه ترخیص') {
            value = item['clearance_cost']?.toString() ?? '';
          } else {
            value = item[key]?.toString() ?? '';
          }
          
          // Clean up the value for Excel
          value = value.replaceAll(',', '').trim();
          row.add(excel.TextCellValue(value));
        }
        sheet.appendRow(row);
      }

      // Save the file
      final filePath = '$savePath/$fileName.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excelFile.save()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ فایل با موفقیت در مسیر زیر ذخیره شد:\n$filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.exportErrorMsg} $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<String> _getExcelHeaders() {
    if (_selectedReportId == 'raw_materials') {
      return ['شماره', 'نام مواد', 'نام فروشنده', 'تلفن فروشنده', 'آدرس فروشنده', 'تاریخ', 'واحد', 'وزن خالص', 'وزن ناخالص', 'قیمت واحد', 'مبلغ فروشنده', 'پرداخت اولیه', 'روش پرداخت', 'قیمت محصول', 'کمیسیون', 'هزینه حمل', 'متفرقه', 'غرفه‌داری', 'برچالانی', 'نوع خرید', 'قیمت نهایی', 'واحد پول'];
    } else if (_selectedReportId == 'produced_products') {
      return ['شماره', 'نوع تولید', 'سایز', 'ضخامت', 'طول', 'تعداد خاده', 'وزن فی خاده', 'مجموع وزن', 'واحد', 'تاریخ', 'وضعیت', 'وضعیت فروش'];
    } else if (_selectedReportId == 'sales_invoices') {
      return ['شماره فاکتور', 'نوع', 'مشتری', 'شرکت', 'نوع تولید', 'سایز', 'ضخامت', 'وزن فی خاده (kg)', 'تعداد خاده', 'وزن کل (تن)', 'قیمت واحد', 'قیمت کل', 'تخفیف', 'قیمت نهایی', 'واحد پول', 'تاریخ', 'وضعیت'];
    } else if (_selectedReportId == 'daily_expenses') {
      return ['شماره بل', 'شماره ثبت', 'تاریخ شمسی', 'تاریخ میلادی', 'دسته بندی', 'شرح', 'مبلغ', 'واحد پول', 'نرخ ارز', 'معادل'];
    } else if (_selectedReportId == 'waste_records') {
      return ['شماره', 'تاریخ', 'طرف', 'نوع ضایعات', 'وزن (تن)', 'تعداد', 'مجموع وزن', 'ارزش', 'واحد پول', 'نرخ ارز', 'معادل افغانی', 'شرح'];
    } else if (_selectedReportId == 'service_invoices') {
      return ['شماره', 'شماره فاکتور', 'مشتری', 'تلفن', 'آدرس', 'نوع خدمت', 'سایز', 'ضخامت', 'وزن کل', 'واحد', 'قیمت واحد', 'قیمت کل', 'هزینه بارگیری', 'هزینه حمل', 'هزینه ترخیص', 'تخفیف', 'قیمت نهایی', 'واحد پول', 'تاریخ'];
    } else {
      return ['شماره', 'تاریخ', 'نام', 'توضیحات', 'مبلغ', 'واحد پول'];
    }
  }

  Widget _buildActionButton({
    required IconData icon, 
    required String label, 
    required Color color, 
    required Color backgroundColor, 
    required VoidCallback onPressed
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report_outlined, size: 80, color: const Color(0xFFCB001D).withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              l10n.noDataToShow,
              style: const TextStyle(fontSize: 18, color: Color(0xFFCB001D), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.noRecordsFound} "${_selectedReportLabel}"',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            if (_useDateRange && _isDateComplete(_fromYear, _fromMonth, _fromDay) && 
                _isDateComplete(_toYear, _toMonth, _toDay))
              Text(
                'از ${_getFormattedDate(_fromYear, _fromMonth, _fromDay)} تا ${_getFormattedDate(_toYear, _toMonth, _toDay)} هیچ داده‌ای یافت نشد',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(AppLocalizations l10n, bool isEnglish) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 900;
          if (isSmallScreen) {
            return Column(
              children: [
                _buildReportTypeDropdown(l10n),
                const SizedBox(height: 8),
                _buildSearchField(l10n),
                const SizedBox(height: 8),
                _buildDateRangeFilter(l10n),
              ],
            );
          }
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildReportTypeDropdown(l10n),
              SizedBox(
                width: 250,
                child: _buildSearchField(l10n),
              ),
              _buildDateRangeFilter(l10n),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateRangeFilter(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _useDateRange ? const Color(0xFFCB001D).withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _useDateRange ? const Color(0xFFCB001D) : Colors.grey.shade200,
          width: _useDateRange ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _useDateRange = !_useDateRange;
                    if (!_useDateRange) {
                      _fromYear = '';
                      _fromMonth = '';
                      _fromDay = '';
                      _toYear = '';
                      _toMonth = '';
                      _toDay = '';
                    }
                    _loadData();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _useDateRange ? const Color(0xFFCB001D) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _useDateRange ? Icons.calendar_today : Icons.calendar_today_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _useDateRange ? 'بازه تاریخ فعال' : 'فیلتر تاریخ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_useDateRange && _isDateComplete(_fromYear, _fromMonth, _fromDay) && 
                  _isDateComplete(_toYear, _toMonth, _toDay)) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCB001D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'از ${_getFormattedDate(_fromYear, _fromMonth, _fromDay)} تا ${_getFormattedDate(_toYear, _toMonth, _toDay)}',
                    style: const TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFCB001D),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _fromYear = '';
                      _fromMonth = '';
                      _fromDay = '';
                      _toYear = '';
                      _toMonth = '';
                      _toDay = '';
                      _useDateRange = false;
                      _loadData();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
          if (_useDateRange) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildDateDropdownRow(
                  'از',
                  _fromYear, _fromMonth, _fromDay,
                  (val) => setState(() { _fromYear = val; _applyDateFilter(); }),
                  (val) => setState(() { _fromMonth = val; _applyDateFilter(); }),
                  (val) => setState(() { _fromDay = val; _applyDateFilter(); }),
                ),
                _buildDateDropdownRow(
                  'تا',
                  _toYear, _toMonth, _toDay,
                  (val) => setState(() { _toYear = val; _applyDateFilter(); }),
                  (val) => setState(() { _toMonth = val; _applyDateFilter(); }),
                  (val) => setState(() { _toDay = val; _applyDateFilter(); }),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateDropdownRow(
    String label,
    String year, String month, String day,
    Function(String) onYearChange,
    Function(String) onMonthChange,
    Function(String) onDayChange,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.w600,
              color: Color(0xFFCB001D),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 75,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: year.isNotEmpty ? year : 'سال',
                isExpanded: true,
                iconSize: 16,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFCB001D)),
                style: const TextStyle(
                  fontSize: 12, 
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: Colors.white,
                items: _yearOptions.map((y) => DropdownMenuItem(
                  value: y,
                  child: Text(
                    y, 
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    onYearChange(val == 'سال' ? '' : val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 65,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: month.isNotEmpty ? month : 'ماه',
                isExpanded: true,
                iconSize: 16,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFCB001D)),
                style: const TextStyle(
                  fontSize: 12, 
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: Colors.white,
                items: _monthOptions.map((m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                    m, 
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    onMonthChange(val == 'ماه' ? '' : val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 60,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: day.isNotEmpty ? day : 'روز',
                isExpanded: true,
                iconSize: 16,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFCB001D)),
                style: const TextStyle(
                  fontSize: 12, 
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: Colors.white,
                items: _dayOptions.map((d) => DropdownMenuItem(
                  value: d,
                  child: Text(
                    d, 
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    onDayChange(val == 'روز' ? '' : val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: l10n.searchReportsHint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildReportTypeDropdown(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 200),
      decoration: BoxDecoration(
        color: const Color(0xFFCB001D).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedReportId,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFCB001D)),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13, fontWeight: FontWeight.w500),
          items: _reportTypes.map((type) => DropdownMenuItem<String>(
            value: type.id,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCB001D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(type.icon, size: 16, color: const Color(0xFFCB001D)),
                ),
                const SizedBox(width: 8),
                Text(type.label),
              ],
            ),
          )).toList(),
          onChanged: (newId) {
            if (newId != null) {
              setState(() {
                _selectedReportId = newId;
                final selectedType = _reportTypes.firstWhere((r) => r.id == newId);
                _selectedReportLabel = selectedType.label;
                _searchQuery = '';
                _fromYear = '';
                _fromMonth = '';
                _fromDay = '';
                _toYear = '';
                _toMonth = '';
                _toDay = '';
                _useDateRange = false;
                _loadData();
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildStats(AppLocalizations l10n) {
    final data = _getFilteredData();
    final totalItems = data.length;
    final reportType = _reportTypes.firstWhere(
      (r) => r.id == _selectedReportId,
      orElse: () => _reportTypes.first,
    );
    
    double totalAFN = 0, totalUSD = 0, totalWeight = 0;
    double totalNetWeight = 0, totalGrossWeight = 0;
    
    for (var item in data) {
      String currency = item['currency']?.toString()?.toUpperCase() ?? 'AFN';
      
      if (_selectedReportId == 'daily_expenses') {
        double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
        double usdEquivalent = double.tryParse(item['usd_equivalent']?.toString() ?? '0') ?? 0;
        
        if (currency == 'دالر' || currency == 'USD') {
          totalUSD += price;
          totalAFN += usdEquivalent;
        } else {
          totalAFN += price;
          totalUSD += usdEquivalent;
        }
      } else if (_selectedReportId == 'waste_records') {
        double value = double.tryParse(item['value']?.toString() ?? '0') ?? 0;
        double afnEquivalent = double.tryParse(item['afn_equivalent']?.toString() ?? '0') ?? 0;
        
        if (currency == 'USD') {
          totalUSD += value;
          totalAFN += afnEquivalent;
        } else {
          totalAFN += value;
          totalUSD += afnEquivalent;
        }
        
        double weight = double.tryParse(item['weight_tons']?.toString() ?? '0') ?? 0;
        if (weight == 0) {
          double weightKg = double.tryParse(item['weight']?.toString() ?? '0') ?? 0;
          weight = weightKg / 1000;
        }
        totalWeight += weight;
      } else {
        double amount = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0;
        if (amount == 0) {
          amount = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
        }
        if (amount == 0) {
          amount = double.tryParse(item['total_amount']?.toString() ?? '0') ?? 0;
        }
        if (amount == 0) {
          amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
        }
        if (amount == 0) {
          amount = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
        }
        
        if (currency == 'USD') {
          totalUSD += amount;
        } else {
          totalAFN += amount;
        }
        
        double weight = double.tryParse(item['weight_tons']?.toString() ?? '0') ?? 0;
        if (weight == 0) {
          weight = double.tryParse(item['total_weight_tons']?.toString() ?? '0') ?? 0;
        }
        totalWeight += weight;
      }
      
      double netWeight = double.tryParse(item['net_weight_tons']?.toString() ?? '0') ?? 0;
      totalNetWeight += netWeight;
      
      double grossWeight = double.tryParse(item['gross_weight_tons']?.toString() ?? '0') ?? 0;
      totalGrossWeight += grossWeight;
    }

    List<Widget> stats = [
      _buildStatCard(
        l10n.totalCountStatsLabel,
        totalItems.toString(),
        Icons.numbers,
        const Color(0xFFCB001D),
        null,
        null,
      ),
      _buildStatCard(
        'مجموع (AFN)',
        _formatCurrencyWithK(totalAFN),
        Icons.attach_money,
        Colors.green,
        null,
        null,
      ),
      _buildStatCard(
        'مجموع (USD)',
        _formatCurrencyWithK(totalUSD),
        Icons.attach_money,
        Colors.blue,
        null,
        null,
      ),
      _buildStatCard(
        'وزن کل',
        '${_formatNumber(totalWeight)} تن',
        Icons.scale,
        Colors.orange,
        null,
        null,
      ),
    ];

    if (reportType.hasNetGrossWeight) {
      stats.add(_buildStatCard(
        'وزن خالص',
        '${_formatNumber(totalNetWeight)} تن',
        Icons.clear,
        Colors.purple,
        null,
        null,
      ));
      stats.add(_buildStatCard(
        'وزن ناخالص',
        '${_formatNumber(totalGrossWeight)} تن',
        Icons.square,
        Colors.deepOrange,
        null,
        null,
      ));
    }

    stats.addAll([
      _buildStatCard(
        l10n.todayStatsLabel,
        '${_statsData['today_count']}',
        Icons.today,
        Colors.green,
        _statsData['today_total_afn'],
        _statsData['today_total_usd'],
      ),
      _buildStatCard(
        l10n.thisMonthStatsLabel,
        '${_statsData['month_count']}',
        Icons.calendar_month,
        Colors.orange,
        _statsData['month_total_afn'],
        _statsData['month_total_usd'],
      ),
    ]);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(spacing: 12, runSpacing: 12, children: stats),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, dynamic afnAmount, dynamic usdAmount) {
    bool hasCurrency = afnAmount != null && usdAmount != null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasCurrency) ...[
                    Text(
                      'AFN: ${_formatCurrencyWithK(afnAmount)} | USD: ${_formatCurrencyWithK(usdAmount)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    double number = double.tryParse(value.toString()) ?? 0;
    return number.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  Widget _buildReportTable(AppLocalizations l10n, bool isEnglish) {
    final data = _getFilteredData();
    if (data.isEmpty) return _buildEmptyState(l10n);
    
    // For service_invoices report, show the services table
    if (_selectedReportId == 'service_invoices') {
      return _buildServicesTable(l10n);
    }
    
    // For raw_materials report
    if (_selectedReportId == 'raw_materials') {
      return _buildRawMaterialsTable(l10n);
    }
    
    // For produced_products report
    if (_selectedReportId == 'produced_products') {
      return _buildProducedProductsTable(l10n);
    }
    
    // For sales_invoices report
    if (_selectedReportId == 'sales_invoices') {
      return _buildSalesTable(l10n);
    }
    
    // For daily_expenses report
    if (_selectedReportId == 'daily_expenses') {
      return _buildDailyExpensesTable(l10n);
    }
    
    // For waste_records report
    if (_selectedReportId == 'waste_records') {
      return _buildWastesTable(l10n);
    }
    
    // Default table for other reports
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 600 
            ? _buildMobileCards(data, l10n) 
            : _buildDesktopTable(data, l10n, isEnglish),
      ),
    );
  }

  // ============ SERVICES TABLE ============
  Widget _buildServicesTable(AppLocalizations l10n) {
    final data = _getFilteredData();
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _horizontalScrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER ROW
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.05),
                border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Row(
                children: [
                  _buildHeaderCell('شماره', 50),
                  _buildHeaderCell('شماره فاکتور', 90),
                  _buildHeaderCell('مشتری', 100),
                  _buildHeaderCell('تلفن', 70),
                  _buildHeaderCell('آدرس', 80),
                  _buildHeaderCell('نوع خدمت', 80),
                  _buildHeaderCell('سایز', 50),
                  _buildHeaderCell('ضخامت', 50),
                  _buildHeaderCell('وزن کل', 70),
                  _buildHeaderCell('واحد', 45),
                  _buildHeaderCell('قیمت واحد', 65),
                  _buildHeaderCell('قیمت کل', 70),
                  _buildHeaderCell('هزینه بارگیری', 65),
                  _buildHeaderCell('هزینه حمل', 65),
                  _buildHeaderCell('هزینه ترخیص', 65),
                  _buildHeaderCell('تخفیف', 50),
                  _buildHeaderCell('قیمت نهایی', 75),
                  _buildHeaderCell('واحد پول', 50),
                  _buildHeaderCell('تاریخ', 80),
                ],
              ),
            ),
            
            // DATA ROWS
            ...data.map((service) {
              String unit = service['unit']?.toString() ?? 'TON';
              double totalWeight = double.tryParse(service['total_weight']?.toString() ?? '0') ?? 0;
              String currency = service['currency']?.toString() ?? 'USD';
              
              String displayWeight = unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم' 
                  ? _formatWeightWithConversion(unit, totalWeight)
                  : '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2)} $unit';
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                ),
                child: Row(
                  children: [
                    _buildDataCell(service['id']?.toString() ?? '-', 50, isBold: true),
                    _buildDataCell(service['invoice_number']?.toString() ?? '-', 90, isBold: true),
                    _buildDataCell(service['customer_name']?.toString() ?? '-', 100),
                    _buildDataCell(service['customer_phone']?.toString() ?? '-', 70),
                    _buildDataCell(service['customer_address']?.toString() ?? '-', 80),
                    _buildDataCell(service['service_type']?.toString() ?? '-', 80),
                    _buildDataCell(service['size']?.toString() ?? '-', 50),
                    _buildDataCell(service['thickness']?.toString() ?? '-', 50),
                    _buildDataCell(displayWeight, 70),
                    _buildDataCell(unit, 45),
                    _buildDataCell(_formatCurrencyNoK(service['unit_price']), 65),
                    _buildDataCell(_formatCurrencyNoK(service['total_price']), 70),
                    _buildDataCell(_formatCurrencyNoK(service['loading_cost']), 65),
                    _buildDataCell(_formatCurrencyNoK(service['transfer_cost']), 65),
                    _buildDataCell(_formatCurrencyNoK(service['clearance_cost']), 65),
                    _buildDataCell(_formatCurrencyNoK(service['discount']), 50),
                    _buildDataCell(_formatCurrencyNoK(service['final_price']), 75, isBold: true, isRed: true),
                    _buildDataCell(currency, 50),
                    _buildDataCell(service['date']?.toString() ?? '-', 80),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ============ RAW MATERIALS TABLE ============
  Widget _buildRawMaterialsTable(AppLocalizations l10n) {
    final data = _getFilteredData();
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _horizontalScrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.05),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  const SizedBox(width: 6),
                  _buildHeaderCell('شماره', 50),
                  _buildHeaderCell('نام مواد', 80),
                  _buildHeaderCell('نام فروشنده', 100),
                  _buildHeaderCell('تلفن', 70),
                  _buildHeaderCell('آدرس', 100),
                  _buildHeaderCell('تاریخ', 80),
                  _buildHeaderCell('واحد', 50),
                  _buildHeaderCell('وزن خالص', 60),
                  _buildHeaderCell('وزن ناخالص', 60),
                  _buildHeaderCell('قیمت واحد', 60),
                  _buildHeaderCell('مبلغ فروشنده', 70),
                  _buildHeaderCell('پرداخت اولیه', 70),
                  _buildHeaderCell('روش پرداخت', 70),
                  _buildHeaderCell('قیمت محصول', 50),
                  _buildHeaderCell('کمیسیون', 50),
                  _buildHeaderCell('هزینه حمل', 50),
                  _buildHeaderCell('متفرقه', 50),
                  _buildHeaderCell('غرفه‌داری', 50),
                  _buildHeaderCell('برچالانی', 50),
                  _buildHeaderCell('نوع خرید', 60),
                  _buildHeaderCell('قیمت نهایی', 70),
                ],
              ),
            ),
            ...data.map((material) {
              final translatedUnit = _translateUnit(material['unit'] ?? '-', l10n);
              
              double netWeight = double.tryParse(material['net_weight']?.toString() ?? '0') ?? 0;
              double grossWeight = double.tryParse(material['gross_weight']?.toString() ?? '0') ?? 0;
              String unit = material['unit'] ?? '-';
              
              String displayNet = _formatUnitWithConversion(unit, netWeight, l10n);
              String displayGross = _formatUnitWithConversion(unit, grossWeight, l10n);
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 40),
                    const SizedBox(width: 6),
                    _buildDataCell(material['id'].toString(), 50),
                    _buildDataCell(material['name'] ?? '-', 80),
                    _buildDataCell(material['supplier_name'] ?? '-', 100),
                    _buildDataCell(material['supplier_phone'] ?? '-', 70),
                    _buildDataCell(material['location'] ?? material['supplier_address'] ?? '-', 100),
                    Container(
                      width: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            material['date_en'] ?? '-',
                            style: const TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            material['date'] ?? '-',
                            style: const TextStyle(
                              fontSize: 6,
                              color: Color(0xFFCB001D),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    _buildDataCell(translatedUnit, 50),
                    _buildDataCell(displayNet, 60),
                    _buildDataCell(displayGross, 60),
                    _buildDataCell(material['unit_price'] ?? '-', 60),
                    _buildDataCell('${material['seller_payment'] ?? '-'} ${material['currency'] ?? 'AFN'}', 70),
                    _buildDataCell('${material['seller_paid_amount'] ?? '-'} ${material['currency'] ?? 'AFN'}', 70),
                    _buildDataCell(material['seller_payment_method'] == 'cash'
                        ? 'نقد'
                        : material['seller_payment_method'] == 'loan_full'
                            ? 'قرض کامل'
                            : material['seller_payment_method'] == 'loan_partial'
                                ? 'قرض جزئی'
                                : '-', 70),
                    _buildDataCell(material['product'] ?? '-', 50),
                    _buildDataCell(material['commission'] ?? '-', 50),
                    _buildDataCell(material['transfer_cost'] ?? '-', 50),
                    _buildDataCell(material['miscellaneous'] ?? '-', 50),
                    _buildDataCell(material['ghurfedari'] ?? '-', 50),
                    _buildDataCell(material['barchalani'] ?? '-', 50),
                    _buildDataCell(material['purchase_type'] ?? '-', 60),
                    _buildDataCell('${material['final_price'] ?? '-'} ${material['currency'] ?? 'AFN'}', 70, isBold: true, isRed: true),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ============ PRODUCED PRODUCTS TABLE ============
  Widget _buildProducedProductsTable(AppLocalizations l10n) {
    final data = _getFilteredData();
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _horizontalScrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.05),
                border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Row(
                children: [
                  _buildHeaderCell('شماره', 35),
                  _buildHeaderCell('نوع تولید', 90),
                  _buildHeaderCell('سایز', 45),
                  _buildHeaderCell('ضخامت', 45),
                  _buildHeaderCell('طول', 45),
                  _buildHeaderCell('تعداد خاده', 50),
                  _buildHeaderCell('وزن فی خاده', 65),
                  _buildHeaderCell('مجموع وزن', 70),
                  _buildHeaderCell('واحد', 40),
                  _buildHeaderCell('تاریخ', 80),
                  _buildHeaderCell('وضعیت', 65),
                  _buildHeaderCell('وضعیت فروش', 70),
                ],
              ),
            ),
            ...data.map((product) {
              String unit = product['unit']?.toString() ?? '';
              double rawWeight = double.tryParse(product['raw_weight']?.toString() ?? '0') ?? 0;
              double totalWeight = double.tryParse(product['total_weight']?.toString() ?? '0') ?? 0;
              
              String displayRawWeight;
              if (_isWeightUnit(unit)) {
                displayRawWeight = '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} کیلوگرم';
              } else {
                displayRawWeight = '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} $unit';
              }
              
              String displayTotalWeight;
              if (_isWeightUnit(unit)) {
                double tons = totalWeight / 1000;
                if (tons < 0.01) {
                  displayTotalWeight = '${tons.toStringAsFixed(3)} تن';
                } else {
                  displayTotalWeight = '${tons.toStringAsFixed(2)} تن';
                }
              } else {
                displayTotalWeight = '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 1)} $unit';
              }
              
              String displayUnit = _isWeightUnit(unit) ? 'تن' : unit;
              
              final isSold = (product['is_sold'] == 1 || product['is_sold']?.toString() == '1');
              final availableStock = double.tryParse(product['remaining_stock']?.toString() ?? '0') ?? 0;
              String stockDisplay = _formatWeightWithConversion(unit, availableStock);
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                ),
                child: Row(
                  children: [
                    _buildDataCell(product['id'].toString(), 35),
                    _buildDataCell(product['production_type']?.toString() ?? '-', 90, isBold: true),
                    _buildDataCell(product['size']?.toString() ?? '-', 45),
                    _buildDataCell(product['thickness']?.toString() ?? '-', 45),
                    _buildDataCell(product['length']?.toString() ?? '-', 45),
                    _buildDataCell(product['raw_count']?.toString() ?? '0', 50, isBold: true),
                    _buildDataCell(displayRawWeight, 65),
                    _buildDataCell(displayTotalWeight, 70, isBold: true, isRed: true),
                    _buildDataCell(displayUnit, 40),
                    SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            product['production_date']?.toString() ?? '-',
                            style: const TextStyle(fontSize: 8, color: Color(0xFF1A1A2E)),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            product['production_date_en']?.toString() ?? '-',
                            style: const TextStyle(fontSize: 6, color: Colors.grey),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 65,
                      child: Center(
                        child: _buildStatusChip(product['status']?.toString(), l10n),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Center(
                        child: _buildSoldStatusChip(product, l10n, availableStock, stockDisplay),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ============ SALES TABLE ============
  Widget _buildSalesTable(AppLocalizations l10n) {
    final data = _getFilteredData();
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _horizontalScrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.05),
                border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Row(
                children: [
                  _buildHeaderCell('شماره فاکتور', 90),
                  _buildHeaderCell('نوع', 60),
                  _buildHeaderCell('مشتری', 100),
                  _buildHeaderCell('شرکت', 80),
                  _buildHeaderCell('نوع تولید', 90),
                  _buildHeaderCell('سایز', 50),
                  _buildHeaderCell('ضخامت', 50),
                  _buildHeaderCell('وزن فی خاده (kg)', 70),
                  _buildHeaderCell('تعداد خاده', 55),
                  _buildHeaderCell('وزن کل (تن)', 70),
                  _buildHeaderCell('قیمت واحد', 65),
                  _buildHeaderCell('قیمت کل', 70),
                  _buildHeaderCell('تخفیف', 50),
                  _buildHeaderCell('قیمت نهایی', 75),
                  _buildHeaderCell('واحد پول', 50),
                  _buildHeaderCell('تاریخ', 80),
                  _buildHeaderCell('وضعیت', 60),
                ],
              ),
            ),
            ...data.map((sale) {
              String unit = sale['unit']?.toString() ?? 'کیلوگرم';
              double weightPerUnit = double.tryParse(sale['weight_per_unit']?.toString() ?? '0') ?? 0;
              double totalWeight = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
              String currency = sale['currency']?.toString()?.toUpperCase() ?? 'AFN';
              String saleType = sale['sale_type']?.toString() ?? 'فروش';
              
              String displayWeightPerUnit = weightPerUnit.toStringAsFixed(weightPerUnit % 1 == 0 ? 0 : 1);
              double totalWeightInTons = totalWeight / 1000;
              String displayTotalWeight = totalWeightInTons.toStringAsFixed(totalWeightInTons % 1 == 0 ? 0 : 2);
              
              final isReturned = sale['is_back_returned'] == 1 || sale['is_back_returned']?.toString() == '1';
              String statusText = isReturned ? 'برگشتی' : 'عادی';
              Color statusColor = isReturned ? Colors.orange : Colors.green;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                ),
                child: Row(
                  children: [
                    _buildDataCell(sale['invoice_number']?.toString() ?? '-', 90, isBold: true),
                    _buildDataCell(saleType, 60),
                    _buildDataCell(sale['customer_name']?.toString() ?? '-', 100),
                    _buildDataCell(sale['customer_company']?.toString() ?? '-', 80),
                    _buildDataCell(sale['product_name']?.toString() ?? '-', 90),
                    _buildDataCell(sale['size']?.toString() ?? '-', 50),
                    _buildDataCell(sale['thickness']?.toString() ?? '-', 50),
                    _buildDataCell(displayWeightPerUnit, 70),
                    _buildDataCell(sale['unit_count']?.toString() ?? '0', 55),
                    _buildDataCell(displayTotalWeight, 70),
                    _buildDataCell(_formatCurrencyNoK(sale['unit_price']), 65),
                    _buildDataCell(_formatCurrencyNoK(sale['total_price'] ?? sale['final_price']), 70),
                    _buildDataCell(_formatCurrencyNoK(sale['discount']), 50),
                    _buildDataCell(_formatCurrencyNoK(sale['final_price']), 75, isBold: true, isRed: true),
                    _buildDataCell(currency, 50),
                    _buildDataCell(sale['date']?.toString() ?? '-', 80),
                    Container(
                      width: 60,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ============ DAILY EXPENSES TABLE ============
  Widget _buildDailyExpensesTable(AppLocalizations l10n) {
    final data = _getFilteredData();
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _horizontalScrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.05),
                border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Row(
                children: [
                  _buildHeaderCell('شماره بل', 90),
                  _buildHeaderCell('شماره ثبت', 90),
                  _buildHeaderCell('تاریخ شمسی', 80),
                  _buildHeaderCell('تاریخ میلادی', 80),
                  _buildHeaderCell('دسته بندی', 70),
                  _buildHeaderCell('شرح', 120),
                  _buildHeaderCell('مبلغ', 80),
                  _buildHeaderCell('واحد پول', 60),
                  _buildHeaderCell('نرخ ارز', 60),
                  _buildHeaderCell('معادل', 80),
                ],
              ),
            ),
            ...data.map((expense) {
              String currency = expense['currency']?.toString() ?? 'افغانی';
              String category = expense['category']?.toString() ?? 'سایر';
              Color categoryColor = _getCategoryColor(category);
              
              double price = double.tryParse(expense['price']?.toString() ?? '0') ?? 0;
              double usdEquivalent = double.tryParse(expense['usd_equivalent']?.toString() ?? '0') ?? 0;
              double exchangeRate = double.tryParse(expense['exchange_rate']?.toString() ?? '1') ?? 1;
              
              String mainCurrency = '';
              String equivalentCurrency = '';
              double mainAmount = 0;
              double equivalentAmount = 0;
              
              if (currency == 'دالر' || currency == 'USD') {
                mainCurrency = 'USD';
                equivalentCurrency = 'AFN';
                mainAmount = price;
                equivalentAmount = usdEquivalent;
              } else {
                mainCurrency = 'AFN';
                equivalentCurrency = 'USD';
                mainAmount = price;
                equivalentAmount = usdEquivalent;
              }
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                ),
                child: Row(
                  children: [
                    _buildDataCell(expense['invoice_number']?.toString() ?? '-', 90, isBold: true),
                    _buildDataCell(expense['registration_number']?.toString() ?? '-', 90),
                    _buildDataCell(expense['date']?.toString() ?? '-', 80),
                    _buildDataCell(expense['date_en']?.toString() ?? '-', 80),
                    Container(
                      width: 70,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: categoryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    _buildDataCell(expense['description']?.toString() ?? '-', 120),
                    Container(
                      width: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatCurrencyNoK(mainAmount),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            mainCurrency,
                            style: TextStyle(
                              fontSize: 7,
                              color: mainCurrency == 'USD' ? Colors.blue : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    _buildDataCell(currency, 60),
                    _buildDataCell(exchangeRate.toStringAsFixed(exchangeRate % 1 == 0 ? 0 : 2), 60),
                    Container(
                      width: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatCurrencyNoK(equivalentAmount),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: equivalentCurrency == 'USD' ? Colors.blue : Colors.green,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            equivalentCurrency,
                            style: TextStyle(
                              fontSize: 7,
                              color: equivalentCurrency == 'USD' ? Colors.blue : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ============ WASTES TABLE ============
  Widget _buildWastesTable(AppLocalizations l10n) {
    final data = _getFilteredData();
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _horizontalScrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.05),
                border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Row(
                children: [
                  _buildHeaderCell('شماره', 60),
                  _buildHeaderCell('تاریخ', 80),
                  _buildHeaderCell('طرف', 100),
                  _buildHeaderCell('نوع ضایعات', 90),
                  _buildHeaderCell('وزن (تن)', 70),
                  _buildHeaderCell('تعداد', 50),
                  _buildHeaderCell('مجموع وزن', 80),
                  _buildHeaderCell('ارزش', 70),
                  _buildHeaderCell('واحد پول', 50),
                  _buildHeaderCell('نرخ ارز', 60),
                  _buildHeaderCell('معادل افغانی', 80),
                  _buildHeaderCell('شرح', 120),
                ],
              ),
            ),
            ...data.map((waste) {
              String currency = waste['currency']?.toString() ?? 'USD';
              double weight = double.tryParse(waste['weight']?.toString() ?? '0') ?? 0;
              double quantity = double.tryParse(waste['quantity']?.toString() ?? '0') ?? 0;
              double totalWeight = weight * quantity;
              double value = double.tryParse(waste['value']?.toString() ?? '0') ?? 0;
              double afnEquivalent = double.tryParse(waste['afn_equivalent']?.toString() ?? '0') ?? 0;
              double exchangeRate = double.tryParse(waste['exchange_rate']?.toString() ?? '1') ?? 1;
              
              String displayWeight = _formatWasteWeight(weight);
              String displayTotalWeight = _formatWasteWeight(totalWeight);
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                ),
                child: Row(
                  children: [
                    _buildDataCell(waste['id']?.toString() ?? '-', 60, isBold: true),
                    _buildDataCell(waste['date']?.toString() ?? '-', 80),
                    _buildDataCell(waste['party_details']?.toString() ?? '-', 100),
                    _buildDataCell(waste['waste_type']?.toString() ?? '-', 90),
                    _buildDataCell(displayWeight, 70),
                    _buildDataCell(waste['quantity']?.toString() ?? '0', 50),
                    _buildDataCell(displayTotalWeight, 80, isBold: true, isRed: true),
                    _buildDataCell(_formatCurrencyNoK(value), 70),
                    _buildDataCell(currency, 50),
                    _buildDataCell(exchangeRate.toStringAsFixed(exchangeRate % 1 == 0 ? 0 : 2), 60),
                    _buildDataCell(_formatCurrencyNoK(afnEquivalent), 80),
                    _buildDataCell(waste['description']?.toString() ?? '-', 120),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // Helper for status chip
  Widget _buildStatusChip(String? status, AppLocalizations l10n) {
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'تکمیل شده':
        color = Colors.green.shade700;
        icon = Icons.check_circle_rounded;
        label = 'تکمیل شده';
        break;
      case 'در حال تولید':
        color = Colors.blue.shade700;
        icon = Icons.pending_rounded;
        label = 'در حال تولید';
        break;
      case 'در انتظار':
        color = Colors.orange.shade700;
        icon = Icons.hourglass_empty_rounded;
        label = 'در انتظار';
        break;
      default:
        color = Colors.grey.shade600;
        icon = Icons.help_rounded;
        label = status ?? '-';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 2),
          Text(
            label, 
            style: TextStyle(
              color: color, 
              fontSize: 8, 
              fontWeight: FontWeight.w600
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Helper for sold status chip
  Widget _buildSoldStatusChip(Map<String, dynamic> product, AppLocalizations l10n, double availableStock, String stockDisplay) {
    final isSold = (product['is_sold'] == 1 || product['is_sold']?.toString() == '1');
    
    if (isSold && availableStock <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        child: const Text(
          'فروخته شده',
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: availableStock > 0 ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: availableStock > 0 ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3), 
          width: 1
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            availableStock > 0 ? Icons.check_circle : Icons.warning_amber_rounded, 
            color: availableStock > 0 ? Colors.green : Colors.orange, 
            size: 8
          ),
          const SizedBox(width: 2),
          Text(
            availableStock > 0 ? '$stockDisplay موجود' : 'موجودی: $stockDisplay',
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w600,
              color: availableStock > 0 ? Colors.green : Colors.orange,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 8,
          color: Color(0xFF1A1A2E),
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {bool isBold = false, bool isRed = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isRed ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E),
          fontSize: 8,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ============ MOBILE CARDS FOR OTHER REPORTS ============
  Widget _buildMobileCards(List<Map<String, dynamic>> data, AppLocalizations l10n) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: item.entries.map((entry) {
                if (entry.key.contains('_display') || entry.key == 'id') return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getFieldLabel(entry.key, l10n),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Flexible(
                        child: Text(
                          entry.value?.toString() ?? '-',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ============ DESKTOP TABLE FOR OTHER REPORTS ============
  Widget _buildDesktopTable(List<Map<String, dynamic>> data, AppLocalizations l10n, bool isEnglish) {
    List<String> allKeys = data.first.keys.toList();
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _horizontalScrollController,
        padding: const EdgeInsets.all(16),
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFCB001D),
            fontSize: 12,
          ),
          columns: allKeys.map((header) => DataColumn(
            label: Container(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                _getFieldLabel(header, l10n),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )).toList(),
          rows: data.map((item) {
            return DataRow(
              cells: allKeys.map((header) {
                dynamic value = item[header];
                return DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      value?.toString() ?? '-',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getFieldLabel(String key, AppLocalizations l10n) {
    final labels = {
      'id': 'شماره',
      'name': 'نام',
      'supplier_name': 'نام فروشنده',
      'supplier_phone': 'تلفن',
      'supplier_address': 'آدرس',
      'location': 'موقعیت',
      'date': 'تاریخ',
      'date_en': 'تاریخ میلادی',
      'unit': 'واحد',
      'net_weight': 'وزن خالص',
      'gross_weight': 'وزن ناخالص',
      'unit_price': 'قیمت واحد',
      'seller_payment': 'مبلغ فروشنده',
      'seller_paid_amount': 'پرداخت اولیه',
      'seller_payment_method': 'روش پرداخت',
      'product': 'قیمت محصول',
      'commission': 'کمیسیون',
      'transfer_cost': 'هزینه حمل',
      'miscellaneous': 'متفرقه',
      'ghurfedari': 'غرفه‌داری',
      'barchalani': 'برچالانی',
      'purchase_type': 'نوع خرید',
      'final_price': 'قیمت نهایی',
      'currency': 'واحد پول',
      'exchange_rate': 'نرخ ارز',
      'amount_afn': 'مبلغ (AFN)',
      'amount_usd': 'مبلغ (USD)',
      'paid_afn': 'پرداخت (AFN)',
      'paid_usd': 'پرداخت (USD)',
      'remaining_afn': 'باقی‌مانده (AFN)',
      'remaining_usd': 'باقی‌مانده (USD)',
      'value_afn': 'ارزش (AFN)',
      'value_usd': 'ارزش (USD)',
      'production_type': 'نوع تولید',
      'size': 'سایز',
      'thickness': 'ضخامت',
      'length': 'طول',
      'raw_count': 'تعداد خاده',
      'raw_weight': 'وزن فی خاده',
      'total_weight': 'مجموع وزن',
      'status': 'وضعیت',
      'production_date': 'تاریخ تولید',
      'invoice_number': 'شماره فاکتور',
      'customer_name': 'مشتری',
      'customer_company': 'شرکت',
      'product_name': 'محصول',
      'total_price': 'قیمت کل',
      'discount': 'تخفیف',
      'loading_cost': 'هزینه بارگیری',
      'clearance_cost': 'هزینه ترخیص',
      'payment_method': 'روش پرداخت',
      'sale_type': 'نوع فروش',
      'registration_number': 'شماره ثبت',
      'category': 'دسته بندی',
      'description': 'شرح',
      'price': 'قیمت',
      'usd_equivalent': 'معادل دالر',
      'party_details': 'طرف',
      'waste_type': 'نوع ضایعات',
      'weight': 'وزن',
      'quantity': 'تعداد',
      'value': 'ارزش',
      'afn_equivalent': 'معادل افغانی',
      'customer_phone': 'تلفن',
      'customer_address': 'آدرس',
      'service_type': 'نوع خدمت',
    };
    return labels[key] ?? key.replaceAll('_', ' ');
  }
  
  List<Map<String, dynamic>> _getFilteredData() {
    if (_searchQuery.isEmpty) return _reportData;
    return _reportData.where((item) => item.values.any((value) => 
      value != null && value.toString().toLowerCase().contains(_searchQuery.toLowerCase())
    )).toList();
  }

  void _printReport() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.preparingPrintMsg), duration: const Duration(seconds: 2)),
    );
  }
}

class ReportType {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final Future<List<Map<String, dynamic>>> Function(DatabaseHelper) fetchData;
  final bool hasFinancial;
  final bool hasWeight;
  final bool hasNetGrossWeight;
  
  ReportType({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.fetchData,
    this.hasFinancial = false,
    this.hasWeight = false,
    this.hasNetGrossWeight = false,
  });
}
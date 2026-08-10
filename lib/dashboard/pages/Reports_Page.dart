import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
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
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} $unit';
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

      // Process data to convert weights to tons and separate currencies
      List<Map<String, dynamic>> processedData = data.map((item) {
        var newItem = Map<String, dynamic>.from(item);
        
        // Convert weight fields to tons
        String unit = item['unit']?.toString() ?? 'kg';
        
        // Weight (old field)
        if (item.containsKey('weight') && item['weight'] != null) {
          double weight = double.tryParse(item['weight']?.toString() ?? '0') ?? 0;
          newItem['weight_display'] = _formatWeightWithConversion(unit, weight);
          newItem['weight_tons'] = _convertToTons(unit, weight);
        }
        
        // Total weight (sales)
        if (item.containsKey('total_weight') && item['total_weight'] != null) {
          double totalWeight = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
          newItem['total_weight_display'] = _formatWeightWithConversion(unit, totalWeight);
          newItem['total_weight_tons'] = _convertToTons(unit, totalWeight);
        }
        
        // Net weight (pure weight - NEW)
        if (item.containsKey('net_weight') && item['net_weight'] != null) {
          double netWeight = double.tryParse(item['net_weight']?.toString() ?? '0') ?? 0;
          newItem['net_weight_display'] = _formatWeightWithConversion(unit, netWeight);
          newItem['net_weight_tons'] = _convertToTons(unit, netWeight);
        }
        
        // Gross weight (with packaging - NEW)
        if (item.containsKey('gross_weight') && item['gross_weight'] != null) {
          double grossWeight = double.tryParse(item['gross_weight']?.toString() ?? '0') ?? 0;
          newItem['gross_weight_display'] = _formatWeightWithConversion(unit, grossWeight);
          newItem['gross_weight_tons'] = _convertToTons(unit, grossWeight);
        }
        
        // Remaining stock (NEW)
        if (item.containsKey('remaining_stock') && item['remaining_stock'] != null) {
          double remainingStock = double.tryParse(item['remaining_stock']?.toString() ?? '0') ?? 0;
          newItem['remaining_stock_display'] = _formatWeightWithConversion(unit, remainingStock);
          newItem['remaining_stock_tons'] = _convertToTons(unit, remainingStock);
        }
        
        if (item.containsKey('weight_per_unit')) {
          String unit2 = item['unit']?.toString() ?? 'kg';
          double weightPerUnit = double.tryParse(item['weight_per_unit']?.toString() ?? '0') ?? 0;
          newItem['weight_per_unit_display'] = _formatWeightWithConversion(unit2, weightPerUnit);
          newItem['weight_per_unit_tons'] = _convertToTons(unit2, weightPerUnit);
        }

        // Separate AFN and USD amounts
        String currency = item['currency']?.toString()?.toUpperCase() ?? 'AFN';
        double amount = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0;
        double paidAmount = double.tryParse(item['paid_amount']?.toString() ?? '0') ?? 0;
        double remainingAmount = double.tryParse(item['remaining_amount']?.toString() ?? '0') ?? 0;
        double value = double.tryParse(item['value']?.toString() ?? '0') ?? 0;
        double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
        double totalAmount = double.tryParse(item['total_amount']?.toString() ?? '0') ?? 0;

        if (currency == 'USD') {
          newItem['amount_usd'] = amount;
          newItem['amount_afn'] = 0;
          newItem['paid_usd'] = paidAmount;
          newItem['paid_afn'] = 0;
          newItem['remaining_usd'] = remainingAmount;
          newItem['remaining_afn'] = 0;
          newItem['value_usd'] = value;
          newItem['value_afn'] = 0;
          newItem['price_usd'] = price;
          newItem['price_afn'] = 0;
          newItem['total_amount_usd'] = totalAmount;
          newItem['total_amount_afn'] = 0;
        } else {
          newItem['amount_afn'] = amount;
          newItem['amount_usd'] = 0;
          newItem['paid_afn'] = paidAmount;
          newItem['paid_usd'] = 0;
          newItem['remaining_afn'] = remainingAmount;
          newItem['remaining_usd'] = 0;
          newItem['value_afn'] = value;
          newItem['value_usd'] = 0;
          newItem['price_afn'] = price;
          newItem['price_usd'] = 0;
          newItem['total_amount_afn'] = totalAmount;
          newItem['total_amount_usd'] = 0;
        }
        
        return newItem;
      }).toList();

      // Apply date range filter ONLY
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
        
        // Get weights
        double weight = double.tryParse(item['weight_tons']?.toString() ?? '0') ?? 0;
        if (weight == 0) {
          weight = double.tryParse(item['total_weight_tons']?.toString() ?? '0') ?? 0;
        }
        totalWeightTons += weight;
        
        double netWeight = double.tryParse(item['net_weight_tons']?.toString() ?? '0') ?? 0;
        totalNetWeightTons += netWeight;
        
        double grossWeight = double.tryParse(item['gross_weight_tons']?.toString() ?? '0') ?? 0;
        totalGrossWeightTons += grossWeight;

        double afnAmount = double.tryParse(item['amount_afn']?.toString() ?? '0') ?? 0;
        double usdAmount = double.tryParse(item['amount_usd']?.toString() ?? '0') ?? 0;
        if (afnAmount == 0) {
          afnAmount = double.tryParse(item['price_afn']?.toString() ?? '0') ?? 0;
          usdAmount = double.tryParse(item['price_usd']?.toString() ?? '0') ?? 0;
        }
        if (afnAmount == 0) {
          afnAmount = double.tryParse(item['total_amount_afn']?.toString() ?? '0') ?? 0;
          usdAmount = double.tryParse(item['total_amount_usd']?.toString() ?? '0') ?? 0;
        }
        if (afnAmount == 0) {
          afnAmount = double.tryParse(item['value_afn']?.toString() ?? '0') ?? 0;
          usdAmount = double.tryParse(item['value_usd']?.toString() ?? '0') ?? 0;
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
                  _buildExportDropdown(l10n),
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

  Widget _buildExportDropdown(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          icon: const Icon(Icons.download, color: Colors.white, size: 20),
          dropdownColor: Colors.white,
          hint: Text(
            l10n.excelExport,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Row(
                children: [
                  const Icon(Icons.table_chart, color: Color(0xFFCB001D), size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.exportAllData),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'filtered',
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Color(0xFFCB001D), size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.exportFilteredData),
                ],
              ),
            ),
          ],
          onChanged: (String? value) {
            if (value == 'all') _exportToCSV(allData: true);
            else if (value == 'filtered') _exportToCSV(allData: false);
          },
        ),
      ),
    );
  }

  Future<void> _exportToCSV({required bool allData}) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final reportType = _reportTypes.firstWhere(
        (r) => r.id == _selectedReportId,
        orElse: () => _reportTypes.first,
      );
      
      List<Map<String, dynamic>> dataToExport = allData 
          ? await reportType.fetchData(_db) 
          : _getFilteredData();
          
      if (dataToExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noDataToExportMsg), backgroundColor: Colors.orange),
        );
        return;
      }

      StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln(l10n.victorPipeCompanyName);
      csvBuffer.writeln('${l10n.reportsPageTitle}: ${reportType.label}');
      csvBuffer.writeln('${l10n.date}: ${PersianDateConverter.getCurrentPersianDateTime()}');
      if (_useDateRange && _isDateComplete(_fromYear, _fromMonth, _fromDay) && 
          _isDateComplete(_toYear, _toMonth, _toDay)) {
        csvBuffer.writeln('بازه تاریخ: از ${_getFormattedDate(_fromYear, _fromMonth, _fromDay)} تا ${_getFormattedDate(_toYear, _toMonth, _toDay)}');
      }
      csvBuffer.writeln('');

      List<String> headers;
      if (_selectedReportId == 'raw_materials') {
        headers = ['شماره', 'تاریخ', 'تفصیل', 'فروشنده', 'ارسالی', 'نوع خرید', 'نوع مواد', 'ضخامت', 'وزن خالص (تن)', 'وزن ناخالص (تن)', 'قیمت (AFN)', 'قیمت (USD)'];
      } else if (_selectedReportId == 'produced_products') {
        headers = ['شماره', 'نام محصول', 'نوع تولید', 'ضخامت', 'تعداد', 'وزن (تن)', 'وزن خالص (تن)', 'وزن ناخالص (تن)', 'واحد', 'موجودی (تن)', 'وضعیت'];
      } else if (_selectedReportId == 'sales_invoices') {
        headers = ['شماره', 'تاریخ', 'نام مشتری', 'محصول', 'واحد', 'تعداد', 'وزن کل (تن)', 'قیمت واحد (AFN)', 'قیمت واحد (USD)', 'جمع کل (AFN)', 'جمع کل (USD)'];
      } else if (_selectedReportId == 'daily_expenses') {
        headers = ['شماره', 'تاریخ', 'دسته بندی', 'شرح', 'قیمت (AFN)', 'قیمت (USD)'];
      } else if (_selectedReportId == 'waste_records') {
        headers = ['شماره', 'تاریخ', 'طرف', 'نوع ضایعات', 'وزن (تن)', 'تعداد', 'ارزش (AFN)', 'ارزش (USD)'];
      } else if (_selectedReportId == 'sell_loans') {
        headers = ['شماره', 'تاریخ', 'نام مشتری', 'مبلغ کل (AFN)', 'مبلغ کل (USD)', 'پرداخت شده (AFN)', 'پرداخت شده (USD)', 'باقی‌مانده (AFN)', 'باقی‌مانده (USD)'];
      } else {
        headers = dataToExport.first.keys.map((k) => _getFieldLabel(k, l10n)).toList();
        headers.removeWhere((e) => ['created_at', 'updated_at', 'supplier_id', 'account_id'].contains(e));
      }
      
      csvBuffer.writeln(headers.join(','));

      for (var item in dataToExport) {
        List<String> row = [];
        for (var key in headers) {
          String value = '';
          if (key == 'شماره') value = item['id']?.toString() ?? '';
          else if (key == 'تاریخ') value = (item['date']?.toString() ?? item['date_en']?.toString() ?? '').replaceAll('-', '/');
          else if (key == 'تفصیل' || key == 'نام' || key == 'محصول') value = item['name']?.toString() ?? item['product_name']?.toString() ?? item['product']?.toString() ?? '';
          else if (key == 'فروشنده' || key == 'تأمین‌کننده') value = item['supplier_name']?.toString() ?? '';
          else if (key == 'ارسالی' || key == 'محل') value = item['location']?.toString() ?? '';
          else if (key == 'نوع خرید' || key == 'روش پرداخت') value = item['purchase_type']?.toString() ?? item['payment_method']?.toString() ?? '';
          else if (key == 'نوع مواد') value = item['material_type']?.toString() ?? '';
          else if (key == 'ضخامت') value = (item['thickness']?.toString() ?? '').replaceAll('mm', '').trim();
          else if (key.contains('وزن خالص') && key.contains('تن')) {
            double netWeight = double.tryParse(item['net_weight']?.toString() ?? '0') ?? 0;
            String unit = item['unit']?.toString() ?? 'kg';
            value = _formatWeightWithConversion(unit, netWeight);
          }
          else if (key.contains('وزن ناخالص') && key.contains('تن')) {
            double grossWeight = double.tryParse(item['gross_weight']?.toString() ?? '0') ?? 0;
            String unit = item['unit']?.toString() ?? 'kg';
            value = _formatWeightWithConversion(unit, grossWeight);
          }
          else if (key.contains('وزن') && key.contains('تن') && !key.contains('خالص') && !key.contains('ناخالص')) {
            String unit = item['unit']?.toString() ?? 'kg';
            double weight = double.tryParse(item['weight']?.toString() ?? '0') ?? 0;
            if (key.contains('کل')) weight = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
            value = _formatWeightWithConversion(unit, weight);
          }
          else if (key == 'موجودی (تن)') {
            double remainingStock = double.tryParse(item['remaining_stock']?.toString() ?? '0') ?? 0;
            String unit = item['unit']?.toString() ?? 'kg';
            value = _formatWeightWithConversion(unit, remainingStock);
          }
          else if (key == 'نام مشتری') value = item['customer_name']?.toString() ?? '';
          else if (key == 'واحد') value = item['unit']?.toString() ?? '';
          else if (key == 'تعداد') value = item['quantity']?.toString() ?? item['unit_count']?.toString() ?? '';
          else if (key.contains('قیمت') && key.contains('AFN')) value = item['amount_afn']?.toString() ?? item['price_afn']?.toString() ?? '';
          else if (key.contains('قیمت') && key.contains('USD')) value = item['amount_usd']?.toString() ?? item['price_usd']?.toString() ?? '';
          else if (key.contains('جمع کل') && key.contains('AFN')) value = item['amount_afn']?.toString() ?? '';
          else if (key.contains('جمع کل') && key.contains('USD')) value = item['amount_usd']?.toString() ?? '';
          else if (key.contains('مبلغ کل') && key.contains('AFN')) value = item['total_amount_afn']?.toString() ?? '';
          else if (key.contains('مبلغ کل') && key.contains('USD')) value = item['total_amount_usd']?.toString() ?? '';
          else if (key.contains('پرداخت شده') && key.contains('AFN')) value = item['paid_afn']?.toString() ?? '';
          else if (key.contains('پرداخت شده') && key.contains('USD')) value = item['paid_usd']?.toString() ?? '';
          else if (key.contains('باقی‌مانده') && key.contains('AFN')) value = item['remaining_afn']?.toString() ?? '';
          else if (key.contains('باقی‌مانده') && key.contains('USD')) value = item['remaining_usd']?.toString() ?? '';
          else if (key == 'دسته بندی') value = item['category']?.toString() ?? '';
          else if (key == 'شرح') value = item['description']?.toString() ?? '';
          else if (key == 'طرف') value = item['party_details']?.toString() ?? '';
          else if (key == 'نوع ضایعات') value = item['waste_type']?.toString() ?? '';
          else if (key.contains('ارزش') && key.contains('AFN')) value = item['value_afn']?.toString() ?? '';
          else if (key.contains('ارزش') && key.contains('USD')) value = item['value_usd']?.toString() ?? '';
          else if (key == 'نام محصول') value = item['product_name']?.toString() ?? '';
          else if (key == 'نوع تولید') value = item['production_type']?.toString() ?? '';
          else if (key == 'وضعیت') value = item['status']?.toString() ?? '';
          else value = item[key]?.toString() ?? '';

          row.add(value.replaceAll(',', ' ').replaceAll('\n', ' '));
        }
        csvBuffer.writeln(row.join(','));
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'VictorPipe_${_selectedReportId}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      final List<int> utf8Bom = [0xEF, 0xBB, 0xBF];
      final List<int> utf8Bytes = utf8.encode(csvBuffer.toString());
      await file.writeAsBytes([...utf8Bom, ...utf8Bytes]);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.exportSuccessMsg} $fileName'),
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
                // FROM Date
                _buildDateDropdownRow(
                  'از',
                  _fromYear, _fromMonth, _fromDay,
                  (val) => setState(() { _fromYear = val; _applyDateFilter(); }),
                  (val) => setState(() { _fromMonth = val; _applyDateFilter(); }),
                  (val) => setState(() { _fromDay = val; _applyDateFilter(); }),
                ),
                // TO Date
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
          // Year Dropdown
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
          // Month Dropdown
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
          // Day Dropdown
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
      double afnAmount = double.tryParse(item['amount_afn']?.toString() ?? '0') ?? 0;
      if (afnAmount == 0) {
        afnAmount = double.tryParse(item['price_afn']?.toString() ?? '0') ?? 0;
      }
      if (afnAmount == 0) {
        afnAmount = double.tryParse(item['total_amount_afn']?.toString() ?? '0') ?? 0;
      }
      if (afnAmount == 0) {
        afnAmount = double.tryParse(item['value_afn']?.toString() ?? '0') ?? 0;
      }
      if (afnAmount == 0) {
        afnAmount = double.tryParse(item['paid_afn']?.toString() ?? '0') ?? 0;
      }
      if (afnAmount == 0) {
        afnAmount = double.tryParse(item['remaining_afn']?.toString() ?? '0') ?? 0;
      }
      totalAFN += afnAmount;
      
      double usdAmount = double.tryParse(item['amount_usd']?.toString() ?? '0') ?? 0;
      if (usdAmount == 0) {
        usdAmount = double.tryParse(item['price_usd']?.toString() ?? '0') ?? 0;
      }
      if (usdAmount == 0) {
        usdAmount = double.tryParse(item['total_amount_usd']?.toString() ?? '0') ?? 0;
      }
      if (usdAmount == 0) {
        usdAmount = double.tryParse(item['value_usd']?.toString() ?? '0') ?? 0;
      }
      if (usdAmount == 0) {
        usdAmount = double.tryParse(item['paid_usd']?.toString() ?? '0') ?? 0;
      }
      if (usdAmount == 0) {
        usdAmount = double.tryParse(item['remaining_usd']?.toString() ?? '0') ?? 0;
      }
      totalUSD += usdAmount;
      
      double weight = double.tryParse(item['weight_tons']?.toString() ?? '0') ?? 0;
      if (weight == 0) {
        weight = double.tryParse(item['total_weight_tons']?.toString() ?? '0') ?? 0;
      }
      totalWeight += weight;
      
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
        _formatCurrency(totalAFN),
        Icons.attach_money,
        Colors.green,
        null,
        null,
      ),
      _buildStatCard(
        'مجموع (USD)',
        _formatCurrency(totalUSD),
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
                      'AFN: ${_formatCurrency(afnAmount)} | USD: ${_formatCurrency(usdAmount)}',
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

  String _formatCurrency(dynamic value) {
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
    return Container(
      width: double.infinity,
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
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 600 
            ? _buildMobileCards(data, l10n) 
            : _buildDesktopTable(data, l10n, isEnglish),
      ),
    );
  }

  Widget _buildMobileCards(List<Map<String, dynamic>> data, AppLocalizations l10n) {
    final reportType = _reportTypes.firstWhere(
      (r) => r.id == _selectedReportId,
      orElse: () => _reportTypes.first,
    );
    
    final importantFields = data.first.keys
        .where((key) => key.contains('name') || key.contains('id') || key.contains('amount') || 
            key.contains('price') || key.contains('total') || key.contains('date') || key.contains('status') ||
            key.contains('weight') || key.contains('net') || key.contains('gross') ||
            key.contains('afn') || key.contains('usd') || key.contains('display') ||
            key.contains('remaining'))
        .take(18)
        .toList();
        
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        
        double itemWeight = double.tryParse(item['weight_tons']?.toString() ?? '0') ?? 0;
        if (itemWeight == 0) {
          itemWeight = double.tryParse(item['total_weight_tons']?.toString() ?? '0') ?? 0;
        }
        
        double netWeight = double.tryParse(item['net_weight_tons']?.toString() ?? '0') ?? 0;
        double grossWeight = double.tryParse(item['gross_weight_tons']?.toString() ?? '0') ?? 0;
        double remainingStock = double.tryParse(item['remaining_stock_tons']?.toString() ?? '0') ?? 0;
        
        double afnAmount = double.tryParse(item['amount_afn']?.toString() ?? '0') ?? 0;
        double usdAmount = double.tryParse(item['amount_usd']?.toString() ?? '0') ?? 0;
        if (afnAmount == 0) {
          afnAmount = double.tryParse(item['price_afn']?.toString() ?? '0') ?? 0;
          usdAmount = double.tryParse(item['price_usd']?.toString() ?? '0') ?? 0;
        }
        if (afnAmount == 0) {
          afnAmount = double.tryParse(item['total_amount_afn']?.toString() ?? '0') ?? 0;
          usdAmount = double.tryParse(item['total_amount_usd']?.toString() ?? '0') ?? 0;
        }
        if (afnAmount == 0) {
          afnAmount = double.tryParse(item['value_afn']?.toString() ?? '0') ?? 0;
          usdAmount = double.tryParse(item['value_usd']?.toString() ?? '0') ?? 0;
        }
        if (afnAmount == 0) {
          afnAmount = double.tryParse(item['paid_afn']?.toString() ?? '0') ?? 0;
          usdAmount = double.tryParse(item['paid_usd']?.toString() ?? '0') ?? 0;
        }
        if (afnAmount == 0) {
          afnAmount = double.tryParse(item['remaining_afn']?.toString() ?? '0') ?? 0;
          usdAmount = double.tryParse(item['remaining_usd']?.toString() ?? '0') ?? 0;
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFCB001D),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          item['id']?.toString() ?? 'Row ${index + 1}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    if (reportType.hasWeight && itemWeight > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'وزن کل',
                                style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '${_formatNumber(itemWeight)} تن',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFCB001D),
                                ),
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    if (reportType.hasNetGrossWeight) ...[
                      if (netWeight > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'وزن خالص',
                                  style: TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  '${_formatNumber(netWeight)} تن',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple,
                                  ),
                                  textAlign: TextAlign.left,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (grossWeight > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'وزن ناخالص',
                                  style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  '${_formatNumber(grossWeight)} تن',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.deepOrange,
                                  ),
                                  textAlign: TextAlign.left,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (remainingStock > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'موجودی',
                                  style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  '${_formatNumber(remainingStock)} تن',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                  textAlign: TextAlign.left,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    
                    if (reportType.hasFinancial && (afnAmount > 0 || usdAmount > 0))
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'AFN',
                                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    _formatCurrency(afnAmount),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                    textAlign: TextAlign.left,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (usdAmount > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'USD',
                                      style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _formatCurrency(usdAmount),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue,
                                      ),
                                      textAlign: TextAlign.left,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 8),
                        ],
                      ),
                    
                    ...importantFields
                        .where((key) => key != 'id' && 
                            !key.contains('afn') && !key.contains('usd') && 
                            !key.contains('weight_tons') && !key.contains('net_weight_tons') && 
                            !key.contains('gross_weight_tons') && !key.contains('remaining_stock_tons') &&
                            !key.contains('_display'))
                        .map((key) {
                          dynamic value = item[key];
                          if (value == null) return const SizedBox.shrink();
                          
                          String displayValue = value.toString();
                          bool isWeightField = key.contains('weight') || key.contains('net') || key.contains('gross');
                          
                          if (isWeightField && key.contains('display')) {
                            displayValue = value.toString();
                          }
                          
                          final isNumeric = _isNumeric(displayValue);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCB001D).withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getFieldLabel(key, l10n),
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    displayValue,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isNumeric ? FontWeight.bold : FontWeight.w500,
                                      color: isNumeric && displayValue.contains('تن') ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E),
                                    ),
                                    textAlign: TextAlign.left,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isNumeric(String value) => 
      double.tryParse(value.replaceAll(',', '').replaceAll(' تن', '')) != null || 
      int.tryParse(value.replaceAll(',', '').replaceAll(' تن', '')) != null;

  Widget _buildDesktopTable(List<Map<String, dynamic>> data, AppLocalizations l10n, bool isEnglish) {
    final reportType = _reportTypes.firstWhere(
      (r) => r.id == _selectedReportId,
      orElse: () => _reportTypes.first,
    );
    
    List<String> allKeys = data.first.keys.toList();
    
    List<String> headers = [];
    for (var key in allKeys) {
      if ((key == 'weight' || key == 'total_weight' || key == 'net_weight' || 
           key == 'gross_weight' || key == 'weight_per_unit') && 
          allKeys.contains('${key}_display')) {
        continue;
      }
      headers.add(key);
    }
    
    if (headers.isEmpty) {
      headers = allKeys;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFCB001D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.reportsTableTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (reportType.hasWeight)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.scale, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'وزن کل: ${_formatNumber(_statsData['total_weight_tons'])} تن',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    if (reportType.hasNetGrossWeight) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.clear, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'خالص: ${_formatNumber(_statsData['total_net_weight_tons'])} تن',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.square, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'ناخالص: ${_formatNumber(_statsData['total_gross_weight_tons'])} تن',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    if (_useDateRange && _isDateComplete(_fromYear, _fromMonth, _fromDay) && 
                        _isDateComplete(_toYear, _toMonth, _toDay))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'از ${_getFormattedDate(_fromYear, _fromMonth, _fromDay)} تا ${_getFormattedDate(_toYear, _toMonth, _toDay)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '${data.length} ${l10n.recordsCountLabel} | ${headers.length} ${l10n.columnsCountLabel}',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.vertical,
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
                dataRowMinHeight: 40,
                dataRowMaxHeight: 50,
                columnSpacing: 20,
                columns: headers.map((header) => DataColumn(
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
                  double itemWeight = double.tryParse(item['weight_tons']?.toString() ?? '0') ?? 0;
                  if (itemWeight == 0) {
                    itemWeight = double.tryParse(item['total_weight_tons']?.toString() ?? '0') ?? 0;
                  }
                  
                  double netWeight = double.tryParse(item['net_weight_tons']?.toString() ?? '0') ?? 0;
                  double grossWeight = double.tryParse(item['gross_weight_tons']?.toString() ?? '0') ?? 0;
                  double remainingStock = double.tryParse(item['remaining_stock_tons']?.toString() ?? '0') ?? 0;
                  
                  double afnAmount = double.tryParse(item['amount_afn']?.toString() ?? '0') ?? 0;
                  double usdAmount = double.tryParse(item['amount_usd']?.toString() ?? '0') ?? 0;
                  if (afnAmount == 0) {
                    afnAmount = double.tryParse(item['price_afn']?.toString() ?? '0') ?? 0;
                    usdAmount = double.tryParse(item['price_usd']?.toString() ?? '0') ?? 0;
                  }
                  if (afnAmount == 0) {
                    afnAmount = double.tryParse(item['total_amount_afn']?.toString() ?? '0') ?? 0;
                    usdAmount = double.tryParse(item['total_amount_usd']?.toString() ?? '0') ?? 0;
                  }
                  if (afnAmount == 0) {
                    afnAmount = double.tryParse(item['value_afn']?.toString() ?? '0') ?? 0;
                    usdAmount = double.tryParse(item['value_usd']?.toString() ?? '0') ?? 0;
                  }
                  if (afnAmount == 0) {
                    afnAmount = double.tryParse(item['paid_afn']?.toString() ?? '0') ?? 0;
                    usdAmount = double.tryParse(item['paid_usd']?.toString() ?? '0') ?? 0;
                  }
                  if (afnAmount == 0) {
                    afnAmount = double.tryParse(item['remaining_afn']?.toString() ?? '0') ?? 0;
                    usdAmount = double.tryParse(item['remaining_usd']?.toString() ?? '0') ?? 0;
                  }

                  return DataRow(
                    cells: headers.map((header) {
                      dynamic value = item[header];
                      String displayValue = value?.toString() ?? '-';
                      
                      if (header.contains('_display') || 
                          (header.contains('weight') && !header.contains('_tons') && !header.contains('_display'))) {
                        displayValue = value?.toString() ?? '-';
                      } else if (header == 'weight' || header == 'total_weight' || 
                                 header == 'net_weight' || header == 'gross_weight' || 
                                 header == 'weight_per_unit') {
                        String unit = item['unit']?.toString() ?? 'kg';
                        double weight = double.tryParse(value?.toString() ?? '0') ?? 0;
                        displayValue = _formatWeightWithConversion(unit, weight);
                      }
                      
                      bool isWeightField = displayValue.contains('تن') || displayValue.contains('kg');
                      bool isNumeric = _isNumeric(displayValue);
                      
                      if (header == 'net_weight_display' && netWeight > 0) {
                        return DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              '${_formatNumber(netWeight)} تن',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }
                      
                      if (header == 'gross_weight_display' && grossWeight > 0) {
                        return DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              '${_formatNumber(grossWeight)} تن',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }
                      
                      if (header == 'remaining_stock_display' && remainingStock > 0) {
                        return DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              '${_formatNumber(remainingStock)} تن',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }
                      
                      if (reportType.hasFinancial && (afnAmount > 0 || usdAmount > 0)) {
                        if (header.contains('amount_afn') || header.contains('price_afn') || 
                            header.contains('total_amount_afn') || header.contains('value_afn') ||
                            header.contains('paid_afn') || header.contains('remaining_afn')) {
                          return DataCell(
                            Container(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatCurrency(afnAmount),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (usdAmount > 0)
                                    Text(
                                      'USD: ${_formatCurrency(usdAmount)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }
                        if (header.contains('amount_usd') || header.contains('price_usd') || 
                            header.contains('total_amount_usd') || header.contains('value_usd') ||
                            header.contains('paid_usd') || header.contains('remaining_usd')) {
                          return DataCell(
                            Container(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatCurrency(usdAmount),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (afnAmount > 0)
                                    Text(
                                      'AFN: ${_formatCurrency(afnAmount)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }
                      }
                      
                      if (header.contains('weight') && reportType.hasWeight && itemWeight > 0) {
                        return DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              '${_formatNumber(itemWeight)} تن',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFCB001D),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }
                      
                      if (header.contains('_afn') || header.contains('_usd')) {
                        if (header != 'amount_afn' && header != 'amount_usd' && 
                            header != 'price_afn' && header != 'price_usd' &&
                            header != 'total_amount_afn' && header != 'total_amount_usd' &&
                            header != 'value_afn' && header != 'value_usd' &&
                            header != 'paid_afn' && header != 'paid_usd' &&
                            header != 'remaining_afn' && header != 'remaining_usd') {
                          return DataCell(
                            Container(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                displayValue,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        }
                      }
                      
                      return DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            displayValue,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: (isNumeric || isWeightField) ? FontWeight.bold : FontWeight.normal,
                              color: isWeightField ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(
                      l10n.scrollHintText,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: () {
                        _horizontalScrollController.animateTo(
                          _horizontalScrollController.offset - 200,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: () {
                        _horizontalScrollController.animateTo(
                          _horizontalScrollController.offset + 200,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFieldLabel(String key, AppLocalizations l10n) {
    final labels = {
      'id': l10n.tableIdLabel,
      'created_at': l10n.tableCreatedAtLabel,
      'name': l10n.tableNameLabel,
      'supplier_name': l10n.tableSupplierNameLabel,
      'supplier_phone': l10n.tableSupplierPhoneLabel,
      'supplier_email': l10n.tableSupplierEmailLabel,
      'supplier_address': l10n.tableSupplierAddressLabel,
      'material_type': l10n.tableMaterialTypeLabel,
      'thickness': l10n.tableThicknessLabel,
      'net_weight': 'وزن خالص',
      'net_weight_display': 'وزن خالص (تن)',
      'gross_weight': 'وزن ناخالص',
      'gross_weight_display': 'وزن ناخالص (تن)',
      'remaining_stock': 'موجودی',
      'remaining_stock_display': 'موجودی (تن)',
      'unit': l10n.tableUnitLabel,
      'unit_price': l10n.tableUnitPriceLabel,
      'product': l10n.tableProductLabel,
      'commission': l10n.tableCommissionLabel,
      'transfer_cost': l10n.tableTransferCostLabel,
      'miscellaneous': l10n.tableMiscellaneousLabel,
      'ghurfedari': l10n.tableGhurfedariLabel,
      'barchalani': l10n.tableBarchalaniLabel,
      'purchase_type': l10n.tablePurchaseTypeLabel,
      'seller_payment': l10n.tableSellerPaymentLabel,
      'seller_payment_method': l10n.tableSellerPaymentMethodLabel,
      'seller_paid_amount': l10n.tableSellerPaidAmountLabel,
      'currency': l10n.tableCurrencyLabel,
      'exchange_rate': l10n.tableExchangeRateLabel,
      'final_price': l10n.tableFinalPriceLabel,
      'date': l10n.tableDateLabel,
      'date_en': l10n.tableDateEnLabel,
      'product_name': l10n.tableProductNameLabel,
      'production_type': l10n.tableProductionTypeLabel,
      'loading': l10n.tableLoadingLabel,
      'length': l10n.tableLengthLabel,
      'quantity': l10n.tableQuantityLabel,
      'weight': 'وزن',
      'weight_display': 'وزن (تن)',
      'total_weight': 'وزن کل',
      'total_weight_display': 'وزن کل (تن)',
      'weight_per_unit': 'وزن فی خاده',
      'weight_per_unit_display': 'وزن فی خاده (تن)',
      'production_date': l10n.tableProductionDateLabel,
      'production_date_en': l10n.tableProductionDateEnLabel,
      'status': l10n.tableStatusLabel,
      'batch': l10n.tableBatchLabel,
      'description': l10n.tableDescriptionLabel,
      'invoice_number': l10n.tableInvoiceNumberLabel,
      'customer_name': l10n.tableCustomerNameLabel,
      'customer_phone': l10n.tableCustomerPhoneLabel,
      'customer_address': l10n.tableCustomerAddressLabel,
      'customer_company': l10n.tableCustomerCompanyLabel,
      'gender': l10n.tableGenderLabel,
      'size': l10n.tableSizeLabel,
      'total_price': l10n.tableTotalPriceLabel,
      'price_rate': l10n.tablePriceRateLabel,
      'usd_equivalent': l10n.tableUsdEquivalentLabel,
      'afn_equivalent': l10n.tableAfnEquivalentLabel,
      'loading_cost': l10n.tableLoadingCostLabel,
      'clearance_cost': l10n.tableClearanceCostLabel,
      'discount': l10n.tableDiscountLabel,
      'loading_time': l10n.tableLoadingTimeLabel,
      'loading_time_en': l10n.tableLoadingTimeEnLabel,
      'payment_method': l10n.tablePaymentMethodLabel,
      'loan_type': l10n.tableLoanTypeLabel,
      'paid_amount': l10n.tablePaidAmountLabel,
      'remaining_amount': l10n.tableRemainingAmountLabel,
      'sale_type': l10n.tableSaleTypeLabel,
      'is_back_returned': l10n.tableBackReturnedLabel,
      'back_return_reason': l10n.tableBackReturnReasonLabel,
      'back_return_date': l10n.tableBackReturnDateLabel,
      'back_return_date_en': l10n.tableBackReturnDateEnLabel,
      'service_title': l10n.tableServiceTitleLabel,
      'service_type': l10n.tableServiceTypeLabel,
      'price': l10n.tablePriceLabel,
      'total_amount': l10n.tableTotalAmountLabel,
      'due_date': l10n.tableDueDateLabel,
      'loan_source': l10n.tableLoanSourceLabel,
      'account_id': l10n.tableAccountIdLabel,
      'account_number': l10n.tableAccountNumberLabel,
      'transaction_type': l10n.tableTransactionTypeLabel,
      'amount_usd': 'مبلغ (USD)',
      'amount_afn': 'مبلغ (AFN)',
      'balance_after': l10n.tableBalanceAfterLabel,
      'source_name': l10n.tableSourceNameLabel,
      'source_account': l10n.tableSourceAccountLabel,
      'source_email': l10n.tableSourceEmailLabel,
      'source_phone': l10n.tableSourcePhoneLabel,
      'address': l10n.tableAddressLabel,
      'note': l10n.tableNoteLabel,
      'current_usd_balance': l10n.tableCurrentUsdBalanceLabel,
      'initial_usd_balance': l10n.tableInitialUsdBalanceLabel,
      'asset_type': l10n.tableAssetTypeLabel,
      'asset_name': l10n.tableAssetNameLabel,
      'current_balance': l10n.tableCurrentBalanceLabel,
      'initial_balance': l10n.tableInitialBalanceLabel,
      'category': l10n.tableCategoryLabel,
      'party_details': l10n.tablePartyDetailsLabel,
      'waste_type': l10n.tableWasteTypeLabel,
      'value': l10n.tableValueLabel,
      'nickname': l10n.tableNicknameLabel,
      'phone': l10n.tablePhoneLabel,
      'email': l10n.tableEmailLabel,
      'type': l10n.tableTypeLabel,
      'transactions': l10n.tableTransactionsLabel,
      'amount': 'مبلغ',
      'price_afn': 'قیمت (AFN)',
      'price_usd': 'قیمت (USD)',
      'total_amount_afn': 'جمع کل (AFN)',
      'total_amount_usd': 'جمع کل (USD)',
      'value_afn': 'ارزش (AFN)',
      'value_usd': 'ارزش (USD)',
      'paid_afn': 'پرداخت (AFN)',
      'paid_usd': 'پرداخت (USD)',
      'remaining_afn': 'باقی‌مانده (AFN)',
      'remaining_usd': 'باقی‌مانده (USD)',
      'weight_tons': 'وزن (تن)',
      'total_weight_tons': 'وزن کل (تن)',
      'gross_weight_tons': 'وزن ناخالص (تن)',
      'net_weight_tons': 'وزن خالص (تن)',
      'weight_per_unit_tons': 'وزن فی خاده (تن)',
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
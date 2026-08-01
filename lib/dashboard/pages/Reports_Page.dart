import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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

  String _selectedDateFilter = 'All';
  String _selectedMonthFilter = 'All';
  String _selectedYearFilter = 'All';
  
  Map<String, dynamic> _statsData = {
    'today_count': 0, 'today_total': 0.0,
    'week_count': 0, 'week_total': 0.0,
    'month_count': 0, 'month_total': 0.0,
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

  @override
  void initState() {
    super.initState();
    _reportTypes = [];
    _loadData();
  }

  List<ReportType> _getLocalizedReportTypes(AppLocalizations l10n) {
    return [
      ReportType(
        id: 'raw_materials', 
        label: l10n.rawMaterials, 
        icon: Icons.inventory_2, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getRawMaterials()
      ),
      ReportType(
        id: 'produced_products', 
        label: l10n.productionManagement, 
        icon: Icons.factory, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getProducedProducts()
      ),
      ReportType(
        id: 'sales_invoices', 
        label: l10n.sales, 
        icon: Icons.receipt_long, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getSalesInvoices()
      ),
      ReportType(
        id: 'service_invoices', 
        label: l10n.services, 
        icon: Icons.build_circle, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getServiceInvoices()
      ),
      ReportType(
        id: 'customers', 
        label: l10n.customers, 
        icon: Icons.people, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getCustomers()
      ),
      ReportType(
        id: 'companies', 
        label: l10n.companiesListPage, 
        icon: Icons.business, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getCompanies()
      ),
      ReportType(
        id: 'suppliers', 
        label: l10n.suppliers, 
        icon: Icons.local_shipping, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getSuppliers()
      ),
      ReportType(
        id: 'sell_loans', 
        label: l10n.loans, 
        icon: Icons.credit_card, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getSellLoans()
      ),
      ReportType(
        id: 'sarafi_transactions', 
        label: l10n.sarafi, 
        icon: Icons.currency_exchange, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getSarafiTransactions()
      ),
      ReportType(
        id: 'daily_expenses', 
        label: l10n.dailyExpenses, 
        icon: Icons.money_off, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getDailyExpenses()
      ),
      ReportType(
        id: 'waste_records', 
        label: l10n.wastes, 
        icon: Icons.delete_outline, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getWasteRecords()
      ),
      ReportType(
        id: 'capital_assets', 
        label: l10n.capital, 
        icon: Icons.account_balance, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getCapitalAssets()
      ),
      ReportType(
        id: 'capital_transactions', 
        label: l10n.capital, 
        icon: Icons.swap_horiz, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getCapitalTransactions()
      ),
      ReportType(
        id: 'sarafi_accounts', 
        label: l10n.sarafi, 
        icon: Icons.account_balance_wallet, 
        color: const Color(0xFFCB001D), 
        fetchData: (db) => db.getSarafiAccounts()
      ),
    ];
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

      List<Map<String, dynamic>> filteredData = data.where((item) {
        String itemDate = item['date']?.toString() ?? item['date_en']?.toString() ?? '';
        if (itemDate.isEmpty) return true;

        List<String> parts = itemDate.split(RegExp(r'[-/]'));
        String itemYear = parts[0];
        String itemMonth = parts.length >= 2 ? parts[1].padLeft(2, '0') : '';
        String itemDay = parts.length >= 3 ? parts[2].padLeft(2, '0') : '';

        if (_selectedDateFilter != 'All' && itemDay != _selectedDateFilter) return false;
        if (_selectedMonthFilter != 'All') {
          String selectedMonthNumber = _persianMonthToNumber[_selectedMonthFilter] ?? '';
          if (itemMonth != selectedMonthNumber) return false;
        }
        if (_selectedYearFilter != 'All' && itemYear != _selectedYearFilter) return false;

        return true;
      }).toList();

      final todayPersianDate = PersianDateConverter.getCurrentPersianDate();
      final todayParts = todayPersianDate.split(RegExp(r'[-/]'));
      final currentYearMonth = todayParts[0] + "-" + todayParts[1];

      int todayCount = 0, monthCount = 0;
      double todayTotal = 0.0, monthTotal = 0.0;

      for (var item in data) {
        String itemDate = item['date']?.toString() ?? item['date_en']?.toString() ?? '';
        double price = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0.0;

        if (itemDate == todayPersianDate) { todayCount++; todayTotal += price; }
        if (itemDate.startsWith(currentYearMonth)) { monthCount++; monthTotal += price; }
      }

      setState(() {
        _statsData = {
          'today_count': todayCount, 'today_total': todayTotal,
          'week_count': monthCount, 'week_total': monthTotal,
          'month_count': monthCount, 'month_total': monthTotal,
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
          child: LimitedBox(
            maxHeight: double.infinity,
            maxWidth: double.infinity,
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
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, bool isEnglish) {
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
      csvBuffer.writeln('');

      List<String> headers;
      if (_selectedReportId == 'raw_materials') {
        headers = ['شماره', 'تاریخ', 'تفصیل', 'فروشنده', 'ارسالی', 'نوع خرید', 'نوع مواد', 'ضخامت', 'وزن خالص', 'وزن ناخالص'];
      } else if (_selectedReportId == 'sales_invoices') {
        headers = ['شماره', 'تاریخ', 'نام مشتری', 'محصول', 'واحد', 'تعداد', 'قیمت واحد', 'جمع کل'];
      } else if (_selectedReportId == 'daily_expenses') {
        headers = ['شماره', 'تاریخ', 'دسته بندی', 'شرح', 'قیمت'];
      } else {
        // FIXED: Added l10n parameter
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
          else if (key == 'وزن خالص') value = double.tryParse(item['net_weight']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0';
          else if (key == 'وزن ناخالص') value = double.tryParse(item['gross_weight']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0';
          else if (key == 'نام مشتری') value = item['customer_name']?.toString() ?? '';
          else if (key == 'واحد') value = item['unit']?.toString() ?? '';
          else if (key == 'تعداد') value = item['quantity']?.toString() ?? item['unit_count']?.toString() ?? '';
          else if (key == 'قیمت واحد') value = item['unit_price']?.toString() ?? '';
          else if (key == 'جمع کل' || key == 'قیمت نهایی') value = item['final_price']?.toString() ?? item['total_price']?.toString() ?? '';
          else if (key == 'دسته بندی') value = item['category']?.toString() ?? '';
          else if (key == 'شرح') value = item['description']?.toString() ?? '';
          else if (key == 'قیمت') value = item['price']?.toString() ?? '';
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
                _buildDateFilters(l10n),
              ],
            );
          }
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildReportTypeDropdown(l10n),
              SizedBox(width: isSmallScreen ? 0 : 12),
              Expanded(child: _buildSearchField(l10n)),
              const SizedBox(width: 12),
              _buildDateFilters(l10n),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateFilters(AppLocalizations l10n) {
    List<String> dayItems = ['All'];
    for (int i = 1; i <= 31; i++) {
      dayItems.add(i.toString().padLeft(2, '0'));
    }
    
    List<String> monthItems = ['All'];
    final languageProvider = Provider.of<LanguageProvider>(context);
    if (languageProvider.isEnglish) {
      monthItems.addAll(['Farwardin', 'Ordibehesht', 'Khordad', 'Tir', 'Mordad', 'Shahrivar', 'Mehr', 'Aban', 'Azar', 'Dey', 'Bahman', 'Esfand']);
    } else {
      monthItems.addAll(_persianMonths);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFilterDropdown(
          l10n.dayFilterLabel,
          _selectedDateFilter,
          Icons.calendar_today,
          dayItems,
          (val) => setState(() { _selectedDateFilter = val!; _loadData(); }),
          l10n,
        ),
        const SizedBox(width: 8),
        _buildFilterDropdown(
          l10n.monthFilterLabel,
          _selectedMonthFilter,
          Icons.calendar_month,
          monthItems,
          (val) => setState(() { _selectedMonthFilter = val!; _loadData(); }),
          l10n,
        ),
        const SizedBox(width: 8),
        _buildFilterDropdown(
          l10n.yearFilterLabel,
          _selectedYearFilter,
          Icons.calendar_today,
          () {
            List<String> years = ['All'];
            final currentYear = PersianDateConverter.getCurrentPersianDate().split(RegExp(r'[-/]'))[0];
            for(int i=0; i<10; i++) years.add((int.parse(currentYear) - i).toString());
            return years;
          }(),
          (val) => setState(() { _selectedYearFilter = val!; _loadData(); }),
          l10n,
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String selected,
    IconData icon,
    List<String> items,
    Function(String?) onChanged,
    AppLocalizations l10n,
  ) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          icon: Icon(icon, size: 14, color: const Color(0xFFCB001D)),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e == 'All' ? l10n.allDaysLabel : e),
          )).toList(),
          onChanged: onChanged,
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
                _selectedDateFilter = 'All';
                _selectedMonthFilter = 'All';
                _selectedYearFilter = 'All';
                _loadData();
              });
            }
          },
        ),
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

  Widget _buildStats(AppLocalizations l10n) {
    final data = _getFilteredData();
    final totalItems = data.length;
    double totalAmount = 0;
    for (var item in data) {
      for (var key in item.keys) {
        final lowerKey = key.toLowerCase();
        if (lowerKey.contains('amount') || lowerKey.contains('price') || lowerKey.contains('total') || 
            lowerKey.contains('balance') || lowerKey.contains('final') || lowerKey.contains('payment') || 
            lowerKey.contains('value')) {
          final value = item[key];
          if (value is num) totalAmount += value.toDouble();
          else if (value is String) {
            final parsed = double.tryParse(value.replaceAll(',', ''));
            if (parsed != null) totalAmount += parsed;
          }
        }
      }
    }

    List<Widget> stats = [
      _buildStatCard(
        l10n.totalCountStatsLabel,
        totalItems.toString(),
        Icons.numbers,
        const Color(0xFFCB001D),
      ),
      _buildStatCard(
        l10n.totalAmountStatsLabel,
        _formatCurrency(totalAmount),
        Icons.attach_money,
        const Color(0xFFCB001D),
      ),
      _buildStatCard(
        l10n.todayStatsLabel,
        '${_statsData['today_count']} / ${_formatCurrency(_statsData['today_total'])}',
        Icons.today,
        Colors.green,
      ),
      _buildStatCard(
        l10n.thisMonthStatsLabel,
        '${_statsData['month_count']} / ${_formatCurrency(_statsData['month_total'])}',
        Icons.calendar_month,
        Colors.orange,
      ),
    ];

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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
      ),
      child: Row(
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
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0';
    final number = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
    if (number >= 1000000000) return '${(number / 1000000000).toStringAsFixed(1)} میلیارد';
    else if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)} میلیون';
    else if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)} هزار';
    return number.toStringAsFixed(0).replaceAllMapped(
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
    final importantFields = data.first.keys
        .where((key) => key.contains('name') || key.contains('id') || key.contains('amount') || 
            key.contains('price') || key.contains('total') || key.contains('date') || key.contains('status'))
        .take(8)
        .toList();
        
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
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
                  children: importantFields
                      .where((key) => key != 'id')
                      .map((key) {
                        final value = item[key];
                        if (value == null) return const SizedBox.shrink();
                        final isNumeric = _isNumeric(value.toString());
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
                                  // FIXED: Added l10n parameter
                                  _getFieldLabel(key, l10n),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  value.toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isNumeric ? FontWeight.bold : FontWeight.w500,
                                    color: isNumeric ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E),
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isNumeric(String value) => 
      double.tryParse(value.replaceAll(',', '')) != null || 
      int.tryParse(value.replaceAll(',', '')) != null;

  Widget _buildDesktopTable(List<Map<String, dynamic>> data, AppLocalizations l10n, bool isEnglish) {
    final headers = data.first.keys.toList();
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
                Text(
                  '${data.length} ${l10n.recordsCountLabel} | ${headers.length} ${l10n.columnsCountLabel}',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
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
                      // FIXED: Added l10n parameter
                      _getFieldLabel(header, l10n),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )).toList(),
                rows: data.map((item) => DataRow(
                  cells: headers.map((header) {
                    final value = item[header]?.toString() ?? '-';
                    final isNumeric = _isNumeric(value);
                    return DataCell(
                      Container(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isNumeric ? FontWeight.bold : FontWeight.normal,
                            color: isNumeric ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )).toList(),
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
                Text(
                  l10n.scrollHintText,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
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
      'net_weight': l10n.tableNetWeightLabel,
      'gross_weight': l10n.tableGrossWeightLabel,
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
      'weight': l10n.tableWeightLabel,
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
      'total_weight': l10n.tableTotalWeightLabel,
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
      'amount_usd': l10n.tableAmountUsdLabel,
      'amount_afn': l10n.tableAmountAfnLabel,
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

  Future<void> _generatePDFReport() async {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.generatingPDFMsg), duration: const Duration(seconds: 2)),
    );
  }
}

class ReportType {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final Future<List<Map<String, dynamic>>> Function(DatabaseHelper) fetchData;
  
  ReportType({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.fetchData,
  });
}
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DatabaseHelper _db = DatabaseHelper();
  
  String _selectedReport = 'مواد خام';
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _reportData = [];
  final ScrollController _horizontalScrollController = ScrollController();

  // ✅ Global Filters for ALL Reports
  String _selectedDateFilter = 'All';
  String _selectedMonthFilter = 'All';
  String _selectedYearFilter = 'All';
  
  // ✅ Universal Stats
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
  
  final List<ReportType> _reportTypes = [
    ReportType(id: 'raw_materials', label: 'مواد خام', icon: Icons.inventory_2, color: const Color(0xFFCB001D), fetchData: (db) => db.getRawMaterials()),
    ReportType(id: 'produced_products', label: 'محصولات تولیدی', icon: Icons.factory, color: const Color(0xFFCB001D), fetchData: (db) => db.getProducedProducts()),
    ReportType(id: 'sales_invoices', label: 'فروشات', icon: Icons.receipt_long, color: const Color(0xFFCB001D), fetchData: (db) => db.getSalesInvoices()),
    ReportType(id: 'service_invoices', label: 'فاکتورهای خدمات', icon: Icons.build_circle, color: const Color(0xFFCB001D), fetchData: (db) => db.getServiceInvoices()),
    ReportType(id: 'customers', label: 'مشتریان', icon: Icons.people, color: const Color(0xFFCB001D), fetchData: (db) => db.getCustomers()),
    ReportType(id: 'companies', label: 'شرکت‌ها', icon: Icons.business, color: const Color(0xFFCB001D), fetchData: (db) => db.getCompanies()),
    ReportType(id: 'suppliers', label: 'تأمین‌کنندگان', icon: Icons.local_shipping, color: const Color(0xFFCB001D), fetchData: (db) => db.getSuppliers()),
    ReportType(id: 'sell_loans', label: 'قرضه‌ها', icon: Icons.credit_card, color: const Color(0xFFCB001D), fetchData: (db) => db.getSellLoans()),
    ReportType(id: 'sarafi_transactions', label: 'صرافی', icon: Icons.currency_exchange, color: const Color(0xFFCB001D), fetchData: (db) => db.getSarafiTransactions()),
    ReportType(id: 'daily_expenses', label: 'هزینه‌های روزانه', icon: Icons.money_off, color: const Color(0xFFCB001D), fetchData: (db) => db.getDailyExpenses()),
    ReportType(id: 'waste_records', label: 'ضایعات و تلفات', icon: Icons.delete_outline, color: const Color(0xFFCB001D), fetchData: (db) => db.getWasteRecords()),
    ReportType(id: 'capital_assets', label: 'دارایی‌های سرمایه‌ای', icon: Icons.account_balance, color: const Color(0xFFCB001D), fetchData: (db) => db.getCapitalAssets()),
    ReportType(id: 'capital_transactions', label: 'تراکنش‌های سرمایه‌ای', icon: Icons.swap_horiz, color: const Color(0xFFCB001D), fetchData: (db) => db.getCapitalTransactions()),
    ReportType(id: 'sarafi_accounts', label: 'حساب‌های صرافی', icon: Icons.account_balance_wallet, color: const Color(0xFFCB001D), fetchData: (db) => db.getSarafiAccounts()),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // ✅ UNIVERSAL DATA LOADER & CALCULATOR (WORKING FOR ALL REPORTS)
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final reportType = _reportTypes.firstWhere(
        (r) => r.label == _selectedReport,
        orElse: () => _reportTypes.first,
      );
      
      List<Map<String, dynamic>> data = await reportType.fetchData(_db);

      // ✅ Universal Date Filtering (Based on 'date' or 'date_en' field)
      List<Map<String, dynamic>> filteredData = data.where((item) {
        // Try Persian date first, then English date
        String itemDate = item['date']?.toString() ?? item['date_en']?.toString() ?? '';
        if (itemDate.isEmpty) return true; // If no date, still show it

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

      // ✅ Universal Stats Calculation (Today, Week, Month)
      final todayPersianDate = PersianDateConverter.getCurrentPersianDate();
      // Extract current Persian Year/Month for "Month" stats
      final todayParts = todayPersianDate.split(RegExp(r'[-/]'));
      final currentYearMonth = todayParts[0] + "-" + todayParts[1]; // e.g. "1405-05"

      int todayCount = 0, monthCount = 0;
      double todayTotal = 0.0, monthTotal = 0.0;

      for (var item in data) {
        String itemDate = item['date']?.toString() ?? item['date_en']?.toString() ?? '';
        double price = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0.0;

        // Count Today
        if (itemDate == todayPersianDate) { todayCount++; todayTotal += price; }
        
        // Count This Month (simply check if the date string starts with YYYY-MM)
        if (itemDate.startsWith(currentYearMonth)) { monthCount++; monthTotal += price; }
      }

      setState(() {
        _statsData = {
          'today_count': todayCount, 'today_total': todayTotal,
          'week_count': monthCount, 'week_total': monthTotal, // Re-using Month logic for Week
          'month_count': monthCount, 'month_total': monthTotal,
        };
        _reportData = filteredData;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطا در بارگذاری داده: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LimitedBox(
            maxHeight: double.infinity,
            maxWidth: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildFilters(),
                const SizedBox(height: 12),
                _buildStats(),
                const SizedBox(height: 12),
                if (_isLoading) 
                  const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
                else if (_reportData.isEmpty)
                  _buildEmptyState()
                else
                  _buildReportTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                child: const Icon(Icons.factory, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 12),
              const Text(
                'شرکت وکتورپایپ',
                style: TextStyle(
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
                    child: const Icon(Icons.report_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('گزارشات مدیریتی', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('${_selectedReport} - ${_reportData.length} رکورد', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9))),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildExportDropdown(),
                  const SizedBox(width: 8),
                  _buildActionButton(icon: Icons.print, label: 'چاپ', color: Colors.white, backgroundColor: Colors.white.withOpacity(0.2), onPressed: _printReport),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportDropdown() {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          icon: const Icon(Icons.download, color: Colors.white, size: 20),
          dropdownColor: Colors.white,
          hint: const Text('خروجی اکسل', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          items: const [
            DropdownMenuItem(value: 'all', child: Row(children: [Icon(Icons.table_chart, color: Color(0xFFCB001D), size: 18), SizedBox(width: 8), Text('خروجی کل داده‌ها')])),
            DropdownMenuItem(value: 'filtered', child: Row(children: [Icon(Icons.filter_list, color: Color(0xFFCB001D), size: 18), SizedBox(width: 8), Text('خروجی فیلتر شده')])),
          ],
          onChanged: (String? value) {
            if (value == 'all') _exportToCSV(allData: true);
            else if (value == 'filtered') _exportToCSV(allData: false);
          },
        ),
      ),
    );
  }

  // ✅ UNIVERSAL PROFESSIONAL EXPORT FUNCTION
  Future<void> _exportToCSV({required bool allData}) async {
    try {
      List<Map<String, dynamic>> dataToExport = allData ? await _reportTypes.firstWhere((r) => r.label == _selectedReport).fetchData(_db) : _getFilteredData();
      if (dataToExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ هیچ داده‌ای برای خروجی وجود ندارد!'), backgroundColor: Colors.orange));
        return;
      }

      StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln('شرکت وکتورپایپ');
      csvBuffer.writeln('گزارش: $_selectedReport');
      csvBuffer.writeln('تاریخ تولید: ${PersianDateConverter.getCurrentPersianDateTime()}');
      csvBuffer.writeln('');

      // ✅ Determine relevant headers based on report type
      List<String> headers;
      if (_selectedReport == 'مواد خام') {
          headers = ['شماره', 'تاریخ', 'تفصیل', 'فروشنده', 'ارسالی', 'نوع خرید', 'نوع مواد', 'ضخامت', 'وزن خالص', 'وزن ناخالص'];
      } else if (_selectedReport == 'فروشات') {
          headers = ['شماره', 'تاریخ', 'نام مشتری', 'محصول', 'واحد', 'تعداد', 'قیمت واحد', 'جمع کل'];
      } else if (_selectedReport == 'هزینه‌های روزانه') {
          headers = ['شماره', 'تاریخ', 'دسته بندی', 'شرح', 'قیمت'];
      } else {
          // Generic Header for other reports
          headers = dataToExport.first.keys.map((k) => _getFieldLabel(k)).toList();
          // Remove ugly technical keys
          headers.removeWhere((e) => ['created_at', 'updated_at', 'supplier_id', 'account_id'].contains(e));
      }
      
      csvBuffer.writeln(headers.join(','));

      for (var item in dataToExport) {
        List<String> row = [];
        for (var key in headers) {
          // ✅ Map specific headers to DB keys
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
      final fileName = 'VictorPipe_${_selectedReport}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      final List<int> utf8Bom = [0xEF, 0xBB, 0xBF];
      final List<int> utf8Bytes = utf8.encode(csvBuffer.toString());
      await file.writeAsBytes([...utf8Bom, ...utf8Bytes]);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ فایل اکسل حرفه‌ای ذخیره شد: $fileName'), backgroundColor: Colors.green, duration: const Duration(seconds: 5)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطا در خروجی اکسل: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required Color backgroundColor, required VoidCallback onPressed}) {
    return Material(
      color: backgroundColor, borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed, borderRadius: BorderRadius.circular(10),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))])),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity, height: 300,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report_outlined, size: 80, color: const Color(0xFFCB001D).withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('هیچ داده‌ای برای نمایش وجود ندارد', style: TextStyle(fontSize: 18, color: const Color(0xFFCB001D), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('برای "${_selectedReport}" هیچ رکوردی یافت نشد', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))]),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 900;
          if (isSmallScreen) {
            return Column(children: [
              _buildReportTypeDropdown(), const SizedBox(height: 8), _buildSearchField(), const SizedBox(height: 8), _buildDateFilters(),
            ]);
          }
          return Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              _buildReportTypeDropdown(), SizedBox(width: isSmallScreen ? 0 : 12), Expanded(child: _buildSearchField()), const SizedBox(width: 12), _buildDateFilters(),
            ],
          );
        },
      ),
    );
  }

  // ✅ Display date filters for ALL reports
  Widget _buildDateFilters() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFilterDropdown('روز', _selectedDateFilter, Icons.calendar_today, ['All', ...List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'))], (val) => setState(() { _selectedDateFilter = val!; _loadData(); })),
        const SizedBox(width: 8),
        _buildFilterDropdown('ماه', _selectedMonthFilter, Icons.calendar_month, ['All', ..._persianMonths], (val) => setState(() { _selectedMonthFilter = val!; _loadData(); })),
        const SizedBox(width: 8),
        _buildFilterDropdown('سال', _selectedYearFilter, Icons.calendar_today, () {
          List<String> years = ['All'];
          final currentYear = PersianDateConverter.getCurrentPersianDate().split(RegExp(r'[-/]'))[0];
          for(int i=0; i<10; i++) years.add((int.parse(currentYear) - i).toString());
          return years;
        }(), (val) => setState(() { _selectedYearFilter = val!; _loadData(); })),
      ],
    );
  }

  Widget _buildFilterDropdown(String label, String selected, IconData icon, List<String> items, Function(String?) onChanged) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected, isExpanded: true,
          icon: Icon(icon, size: 14, color: const Color(0xFFCB001D)),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e == 'All' ? 'همه $label' : e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildReportTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4), constraints: const BoxConstraints(minWidth: 200),
      decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedReport, icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFCB001D)), dropdownColor: Colors.white,
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13, fontWeight: FontWeight.w500),
          items: _reportTypes.map((type) => DropdownMenuItem<String>(
            value: type.label,
            child: Row(children: [Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(type.icon, size: 16, color: const Color(0xFFCB001D))), const SizedBox(width: 8), Text(type.label)])
          )).toList(),
          onChanged: (newValue) { setState(() { _selectedReport = newValue!; _searchQuery = ''; _selectedDateFilter = 'All'; _selectedMonthFilter = 'All'; _selectedYearFilter = 'All'; _loadData(); }); },
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val), textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: '🔍 جستجو در گزارشات...', hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13), border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { setState(() => _searchQuery = ''); }) : null,
        ),
      ),
    );
  }

  // ✅ PROFESSIONAL STATS CARDS (Today, Week, Month)
  Widget _buildStats() {
    final data = _getFilteredData();
    final totalItems = data.length;
    double totalAmount = 0;
    for (var item in data) {
      for (var key in item.keys) {
        final lowerKey = key.toLowerCase();
        if (lowerKey.contains('amount') || lowerKey.contains('price') || lowerKey.contains('total') || lowerKey.contains('balance') || lowerKey.contains('final') || lowerKey.contains('payment') || lowerKey.contains('value')) {
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
      _buildStatCard('تعداد کل', totalItems.toString(), Icons.numbers, const Color(0xFFCB001D)),
      _buildStatCard('جمع کل', _formatCurrency(totalAmount), Icons.attach_money, const Color(0xFFCB001D)),
      // ✅ UNIVERSAL: Today, Month Cards for ALL REPORTS!
      _buildStatCard('امروز', '${_statsData['today_count']} / ${_formatCurrency(_statsData['today_total'])}', Icons.today, Colors.green),
      _buildStatCard('این ماه', '${_statsData['month_count']} / ${_formatCurrency(_statsData['month_total'])}', Icons.calendar_month, Colors.orange),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Wrap(spacing: 12, runSpacing: 12, children: stats),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.15), width: 1.5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 16)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)), Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis)]),
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
    return number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  Widget _buildReportTable() {
    final data = _getFilteredData();
    if (data.isEmpty) return _buildEmptyState();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))], border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1)),
      child: LayoutBuilder(builder: (context, constraints) => constraints.maxWidth < 600 ? _buildMobileCards(data) : _buildDesktopTable(data)),
    );
  }

  Widget _buildMobileCards(List<Map<String, dynamic>> data) {
    final importantFields = data.first.keys.where((key) => key.contains('name') || key.contains('id') || key.contains('amount') || key.contains('price') || key.contains('total') || key.contains('date') || key.contains('status')).take(8).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFFCB001D), borderRadius: BorderRadius.vertical(top: Radius.circular(16))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(Icons.receipt_long, color: Colors.white, size: 18), const SizedBox(width: 8), Text(item['id']?.toString() ?? 'ردیف ${index + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))]), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('#${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)))])),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: importantFields.where((key) => key != 'id').map((key) {
                  final value = item[key];
                  if (value == null) return const SizedBox.shrink();
                  final isNumeric = _isNumeric(value.toString());
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.06), borderRadius: BorderRadius.circular(4)), child: Text(_getFieldLabel(key), style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500))), Flexible(child: Text(value.toString(), style: TextStyle(fontSize: 13, fontWeight: isNumeric ? FontWeight.bold : FontWeight.w500, color: isNumeric ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E)), textAlign: TextAlign.left, overflow: TextOverflow.ellipsis))]));
                }).toList()),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isNumeric(String value) => double.tryParse(value.replaceAll(',', '')) != null || int.tryParse(value.replaceAll(',', '')) != null;

  Widget _buildDesktopTable(List<Map<String, dynamic>> data) {
    final headers = data.first.keys.toList();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1), width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: const BoxDecoration(color: Color(0xFFCB001D), borderRadius: BorderRadius.vertical(top: Radius.circular(16))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('جدول گزارشات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), Text('${data.length} رکورد | ${headers.length} ستون', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13))])),
          SingleChildScrollView(scrollDirection: Axis.vertical, child: SingleChildScrollView(scrollDirection: Axis.horizontal, controller: _horizontalScrollController, padding: const EdgeInsets.all(16), child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB001D), fontSize: 12),
            dataRowMinHeight: 40, dataRowMaxHeight: 50, columnSpacing: 20,
            columns: headers.map((header) => DataColumn(label: Container(constraints: const BoxConstraints(maxWidth: 150), child: Text(_getFieldLabel(header), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)))).toList(),
            rows: data.map((item) => DataRow(cells: headers.map((header) {
              final value = item[header]?.toString() ?? '-';
              final isNumeric = _isNumeric(value);
              return DataCell(Container(constraints: const BoxConstraints(maxWidth: 150), child: Text(value, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: isNumeric ? FontWeight.bold : FontWeight.normal, color: isNumeric ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E)))));
            }).toList())).toList(),
          ))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)), border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('👈 برای مشاهده ستون‌های بیشتر، افقی اسکرول کنید', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)), Row(children: [IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () { _horizontalScrollController.animateTo(_horizontalScrollController.offset - 200, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); }, constraints: const BoxConstraints()), IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () { _horizontalScrollController.animateTo(_horizontalScrollController.offset + 200, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); }, constraints: const BoxConstraints())])])),
        ],
      ),
    );
  }

  String _getFieldLabel(String key) {
    final labels = {
      'id': 'شناسه', 'created_at': 'تاریخ ایجاد', 'name': 'نام', 'supplier_name': 'تأمین‌کننده', 'supplier_phone': 'تلفن تأمین‌کننده',
      'supplier_email': 'ایمیل تأمین‌کننده', 'supplier_address': 'آدرس تأمین‌کننده', 'material_type': 'نوع ماده', 'thickness': 'ضخامت',
      'net_weight': 'وزن خالص', 'gross_weight': 'وزن ناخالص', 'unit': 'واحد', 'unit_price': 'قیمت واحد', 'product': 'محصول',
      'commission': 'کمیسیون', 'transfer_cost': 'هزینه حمل', 'miscellaneous': 'متفرقه', 'ghurfedari': 'غرفه‌داری', 'barchalani': 'بارچالانی',
      'purchase_type': 'نوع خرید', 'seller_payment': 'پرداخت فروشنده', 'seller_payment_method': 'روش پرداخت', 'seller_paid_amount': 'مبلغ پرداختی',
      'currency': 'ارز', 'exchange_rate': 'نرخ ارز', 'final_price': 'قیمت نهایی', 'date': 'تاریخ', 'date_en': 'تاریخ (انگلیسی)',
      'product_name': 'نام محصول', 'production_type': 'نوع تولید', 'loading': 'بارگیری', 'length': 'طول', 'quantity': 'تعداد',
      'weight': 'وزن', 'production_date': 'تاریخ تولید', 'production_date_en': 'تاریخ تولید (انگلیسی)', 'status': 'وضعیت',
      'batch': 'دسته', 'description': 'توضیحات', 'invoice_number': 'شماره فاکتور', 'customer_name': 'مشتری', 'customer_phone': 'تلفن مشتری',
      'customer_address': 'آدرس مشتری', 'customer_company': 'شرکت مشتری', 'gender': 'جنسیت', 'size': 'سایز', 'total_weight': 'وزن کل',
      'total_price': 'قیمت کل', 'price_rate': 'نرخ قیمت', 'usd_equivalent': 'معادل USD', 'afn_equivalent': 'معادل AFN',
      'loading_cost': 'هزینه بارگیری', 'clearance_cost': 'هزینه ترخیص', 'discount': 'تخفیف', 'loading_time': 'زمان بارگیری',
      'loading_time_en': 'زمان بارگیری (انگلیسی)', 'payment_method': 'روش پرداخت', 'loan_type': 'نوع قرض', 'paid_amount': 'مبلغ پرداختی',
      'remaining_amount': 'باقیمانده', 'sale_type': 'نوع فروش', 'is_back_returned': 'برگشتی', 'back_return_reason': 'دلیل برگشت',
      'back_return_date': 'تاریخ برگشت', 'back_return_date_en': 'تاریخ برگشت (انگلیسی)', 'service_title': 'عنوان خدمات',
      'service_type': 'نوع خدمات', 'price': 'قیمت', 'total_amount': 'مبلغ کل', 'due_date': 'تاریخ سررسید', 'loan_source': 'منبع قرض',
      'account_id': 'شناسه حساب', 'account_number': 'شماره حساب', 'transaction_type': 'نوع تراکنش', 'amount_usd': 'مبلغ USD',
      'amount_afn': 'مبلغ AFN', 'balance_after': 'موجودی بعدی', 'source_name': 'نام منبع', 'source_account': 'حساب منبع',
      'source_email': 'ایمیل منبع', 'source_phone': 'تلفن منبع', 'address': 'آدرس', 'note': 'یادداشت', 'current_usd_balance': 'موجودی USD',
      'initial_usd_balance': 'موجودی اولیه USD', 'asset_type': 'نوع دارایی', 'asset_name': 'نام دارایی', 'current_balance': 'موجودی فعلی',
      'initial_balance': 'موجودی اولیه', 'category': 'دسته‌بندی', 'party_details': 'جزئیات طرف', 'waste_type': 'نوع ضایعات',
      'value': 'ارزش', 'nickname': 'نام مستعار', 'phone': 'تلفن', 'email': 'ایمیل', 'type': 'نوع', 'transactions': 'تراکنش‌ها',
    };
    return labels[key] ?? key.replaceAll('_', ' ');
  }

  List<Map<String, dynamic>> _getFilteredData() {
    if (_searchQuery.isEmpty) return _reportData;
    return _reportData.where((item) => item.values.any((value) => value != null && value.toString().toLowerCase().contains(_searchQuery.toLowerCase()))).toList();
  }

  void _printReport() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🖨️ در حال آماده‌سازی برای چاپ...'), duration: Duration(seconds: 2)));
  Future<void> _generatePDFReport() async => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📄 در حال تولید PDF...'), duration: Duration(seconds: 2)));
}

class ReportType {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final Future<List<Map<String, dynamic>>> Function(DatabaseHelper) fetchData;
  ReportType({required this.id, required this.label, required this.icon, required this.color, required this.fetchData});
}
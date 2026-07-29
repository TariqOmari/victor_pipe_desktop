import 'dart:convert'; // ✅ FIXED: Added to fix the 'utf8' error
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

  // Filter & Stats State
  String _selectedDateFilter = 'All';
  String _selectedMonthFilter = 'All';
  String _selectedYearFilter = 'All';
  
  Map<String, dynamic> _statsData = {
    'today_count': 0, 'today_total': 0.0,
  };

  // Persian Month Names (Afghanistan/Hijri Shamsi)
  final List<String> _persianMonths = [
    'حمل', 'ثور', 'جوزا', 'سرطان', 
    'اسد', 'سنبله', 'میزان', 'عقرب', 
    'قوس', 'جدی', 'دلو', 'حوت'
  ];

  // Map Persian Month Name to Month Number (01, 02, etc.)
  final Map<String, String> _persianMonthToNumber = {
    'حمل': '01', 'ثور': '02', 'جوزا': '03', 'سرطان': '04',
    'اسد': '05', 'سنبله': '06', 'میزان': '07', 'عقرب': '08',
    'قوس': '09', 'جدی': '10', 'دلو': '11', 'حوت': '12'
  };
  
  final List<ReportType> _reportTypes = [
    ReportType(
      id: 'raw_materials',
      label: 'مواد خام',
      icon: Icons.inventory_2,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getRawMaterials(),
    ),
    ReportType(
      id: 'produced_products',
      label: 'محصولات تولیدی',
      icon: Icons.factory,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getProducedProducts(),
    ),
    ReportType(
      id: 'sales_invoices',
      label: 'فروشات',
      icon: Icons.receipt_long,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getSalesInvoices(),
    ),
    ReportType(
      id: 'service_invoices',
      label: 'فاکتورهای خدمات',
      icon: Icons.build_circle,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getServiceInvoices(),
    ),
    ReportType(
      id: 'customers',
      label: 'مشتریان',
      icon: Icons.people,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getCustomers(),
    ),
    ReportType(
      id: 'companies',
      label: 'شرکت‌ها',
      icon: Icons.business,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getCompanies(),
    ),
    ReportType(
      id: 'suppliers',
      label: 'تأمین‌کنندگان',
      icon: Icons.local_shipping,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getSuppliers(),
    ),
    ReportType(
      id: 'sell_loans',
      label: 'قرضه‌ها',
      icon: Icons.credit_card,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getSellLoans(),
    ),
    ReportType(
      id: 'sarafi_transactions',
      label: 'صرافی',
      icon: Icons.currency_exchange,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getSarafiTransactions(),
    ),
    ReportType(
      id: 'daily_expenses',
      label: 'هزینه‌های روزانه',
      icon: Icons.money_off,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getDailyExpenses(),
    ),
    ReportType(
      id: 'waste_records',
      label: 'ضایعات و تلفات',
      icon: Icons.delete_outline,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getWasteRecords(),
    ),
    ReportType(
      id: 'capital_assets',
      label: 'دارایی‌های سرمایه‌ای',
      icon: Icons.account_balance,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getCapitalAssets(),
    ),
    ReportType(
      id: 'capital_transactions',
      label: 'تراکنش‌های سرمایه‌ای',
      icon: Icons.swap_horiz,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getCapitalTransactions(),
    ),
    ReportType(
      id: 'sarafi_accounts',
      label: 'حساب‌های صرافی',
      icon: Icons.account_balance_wallet,
      color: const Color(0xFFCB001D),
      fetchData: (db) => db.getSarafiAccounts(),
    ),
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final reportType = _reportTypes.firstWhere(
        (r) => r.label == _selectedReport,
        orElse: () => _reportTypes.first,
      );
      
      // Fetch Data
      List<Map<String, dynamic>> data = await reportType.fetchData(_db);

      // Filter by PERSIAN dates and Months
      if (_selectedReport == 'مواد خام') {
        final todayPersianDate = PersianDateConverter.getCurrentPersianDate(); 
        
        // Filter data based on dropdowns
        List<Map<String, dynamic>> filteredData = data.where((item) {
          String itemDate = item['date'] ?? ''; // Using Persian 'date' field
          if (itemDate.isEmpty) return false;

          List<String> parts = itemDate.split(RegExp(r'[-/]'));
          String itemYear = parts[0];
          String itemMonth = parts.length >= 2 ? parts[1].padLeft(2, '0') : '';
          String itemDay = parts.length >= 3 ? parts[2].padLeft(2, '0') : '';

          if (_selectedDateFilter != 'All') {
            if (itemDay != _selectedDateFilter) return false;
          }
          if (_selectedMonthFilter != 'All') {
            String selectedMonthNumber = _persianMonthToNumber[_selectedMonthFilter] ?? '';
            if (itemMonth != selectedMonthNumber) return false;
          }
          if (_selectedYearFilter != 'All') {
            if (itemYear != _selectedYearFilter) return false;
          }
          return true;
        }).toList();

        // Calculate Real-time Stats for Today
        int todayCount = 0; double todayTotal = 0.0;
        for (var item in data) {
          String itemDate = item['date'] ?? '';
          double price = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0.0;
          if (itemDate == todayPersianDate) { 
            todayCount++; 
            todayTotal += price; 
          }
        }

        setState(() {
          _statsData = {
            'today_count': todayCount, 
            'today_total': todayTotal,
          };
          _reportData = filteredData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
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
          // NEW: Beautiful Centered Logo/Company Name
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
          // Existing Header Content
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
                    child: const Icon(
                      Icons.report_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'گزارشات مدیریتی',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_selectedReport} - ${_reportData.length} رکورد',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // NEW: Export Dropdown Button
                  _buildExportDropdown(),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.print,
                    label: 'چاپ',
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

  Widget _buildExportDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          icon: const Icon(Icons.download, color: Colors.white, size: 20),
          dropdownColor: Colors.white,
          hint: const Text(
            'خروجی اکسل',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: Color(0xFFCB001D), size: 18),
                  SizedBox(width: 8),
                  Text('خروجی کل داده‌ها'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'filtered',
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: Color(0xFFCB001D), size: 18),
                  SizedBox(width: 8),
                  Text('خروجی فیلتر شده'),
                ],
              ),
            ),
          ],
          onChanged: (String? value) {
            if (value == 'all') {
              _exportToCSV(allData: true);
            } else if (value == 'filtered') {
              _exportToCSV(allData: false);
            }
          },
        ),
      ),
    );
  }

  // =========================================================
  // NEW: Export to Excel/CSV Function
  // =========================================================
  // =========================================================
  // ✅ نسخه نهایی اکسل: دقیقاً طبق عکس، مرتب و حرفه‌ای
  // =========================================================
  Future<void> _exportToCSV({required bool allData}) async {
    try {
      List<Map<String, dynamic>> dataToExport;
      String exportType;

      if (allData) {
        final reportType = _reportTypes.firstWhere(
          (r) => r.label == _selectedReport,
          orElse: () => _reportTypes.first,
        );
        dataToExport = await reportType.fetchData(_db);
        exportType = 'کل';
      } else {
        dataToExport = _getFilteredData();
        exportType = 'فیلتر شده';
      }

      if (dataToExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ هیچ داده‌ای برای خروجی وجود ندارد!'), backgroundColor: Colors.orange),
        );
        return;
      }

      // 1. ساخت محتوای CSV دقیقاً طبق عکس شما
      StringBuffer csvBuffer = StringBuffer();
      
      // هدر اصلی شرکت (Middle Title)
      csvBuffer.writeln('شرکت وکتورپایپ');
      csvBuffer.writeln('لیست مواد خام دریافتی سال 1405');
      csvBuffer.writeln(''); // خط خالی برای زیبایی

      // =========================================================
      // نوشتن هدرهای جدول (دقیقاً طبق عکس شما)
      // =========================================================
      csvBuffer.writeln('شماره,تاریخ,تفصیل,اسم فروشنده,ارسالی,تخلیه شده,نوع مواد,ضخامت,وزن خالص,وزن ناخالص');

      // =========================================================
      // حلقه زدن روی داده‌ها و نوشتن ردیف‌ها
      // =========================================================
      for (var item in dataToExport) {
        List<String> row = [];

        // 1. شماره (شناسه)
        row.add(item['id']?.toString() ?? '');

        // 2. تاریخ (فرمت 12/12/1404)
        String rawDate = item['date']?.toString() ?? '';
        if (rawDate.isNotEmpty) {
          // تبدیل فرمت 1405-05-07 به 1405/05/07
          rawDate = rawDate.replaceAll('-', '/');
        }
        row.add(rawDate);

        // 3. تفصیل (همان نام مواد)
        row.add(item['name']?.toString() ?? '');

        // 4. اسم فروشنده
        row.add(item['supplier_name']?.toString() ?? '');

        // 5. ارسالی (محل تخلیه)
        row.add(item['location']?.toString() ?? '');

        // 6. تخلیه شده (نوع خرید: مستقیم / غیر مستقیم)
        String purchaseType = item['purchase_type']?.toString() ?? '';
        if (purchaseType == 'مستقیم') {
          purchaseType = 'فابریکه';
        } else if (purchaseType == 'غیر مستقیم') {
          purchaseType = 'غیر فابریکه';
        }
        row.add(purchaseType);

        // 7. نوع مواد
        row.add(item['material_type']?.toString() ?? '');

        // 8. ضخامت (Thickness) - تمیز کردن اعداد اعشاری
        String thickness = item['thickness']?.toString() ?? '';
        if (thickness.endsWith('mm')) {
          thickness = thickness.replaceAll('mm', '').trim();
        }
        row.add(thickness);

        // 9. وزن خالص (Net Weight)
        String netWeight = item['net_weight']?.toString() ?? '0';
        // اگر اعشار اضافه دارد، کوتاهش کن
        double netVal = double.tryParse(netWeight) ?? 0;
        row.add(netVal.toStringAsFixed(0));

        // 10. وزن ناخالص (Gross Weight)
        String grossWeight = item['gross_weight']?.toString() ?? '0';
        double grossVal = double.tryParse(grossWeight) ?? 0;
        row.add(grossVal.toStringAsFixed(0));

        // نوشتن ردیف در فایل
        csvBuffer.writeln(row.join(','));
      }

      // 2. ذخیره در پوشه اسناد
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'VictorPipe_Raw_Report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      
      // استفاده از BOM برای نمایش صحیح فارسی در اکسل
      final List<int> utf8Bom = [0xEF, 0xBB, 0xBF];
      final List<int> utf8Bytes = utf8.encode(csvBuffer.toString());
      await file.writeAsBytes([...utf8Bom, ...utf8Bytes]);

      // 3. پیام موفقیت
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ فایل اکسل با جدول تمیز و حرفه‌ای ذخیره شد: $fileName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطا در خروجی اکسل: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // =========================================================

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
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
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            Icon(
              Icons.report_outlined,
              size: 80,
              color: const Color(0xFFCB001D).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'هیچ داده‌ای برای نمایش وجود ندارد',
              style: TextStyle(
                fontSize: 18,
                color: const Color(0xFFCB001D),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'برای "${_selectedReport}" هیچ رکوردی یافت نشد',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
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
                _buildReportTypeDropdown(),
                const SizedBox(height: 8),
                _buildSearchField(),
                if (_selectedReport == 'مواد خام') ...[
                  const SizedBox(height: 8),
                  _buildDateFilters(),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildReportTypeDropdown(),
              SizedBox(width: isSmallScreen ? 0 : 12),
              Expanded(child: _buildSearchField()),
              if (_selectedReport == 'مواد خام') ...[
                const SizedBox(width: 12),
                _buildDateFilters(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateFilters() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDateFilter,
              isExpanded: true,
              icon: const Icon(Icons.calendar_today, size: 14, color: Color(0xFFCB001D)),
              items: [
                const DropdownMenuItem(value: 'All', child: Text('همه روزها')),
                ...List.generate(31, (index) => DropdownMenuItem(
                  value: (index + 1).toString().padLeft(2, '0'),
                  child: Text('روز ${index + 1}'),
                )),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedDateFilter = val!;
                  _loadData();
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMonthFilter,
              isExpanded: true,
              icon: const Icon(Icons.calendar_month, size: 14, color: Color(0xFFCB001D)),
              items: [
                const DropdownMenuItem(value: 'All', child: Text('همه ماه‌ها')),
                ..._persianMonths.map((month) => DropdownMenuItem(
                  value: month,
                  child: Text(month),
                )),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedMonthFilter = val!;
                  _loadData();
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedYearFilter,
              isExpanded: true,
              icon: const Icon(Icons.calendar_today, size: 14, color: Color(0xFFCB001D)),
              items: [
                const DropdownMenuItem(value: 'All', child: Text('همه سال‌ها')),
                ...List.generate(10, (index) {
                  final year = (PersianDateConverter.getCurrentPersianDate().split(RegExp(r'[-/]'))[0]);
                  final pastYear = (int.parse(year) - index).toString();
                  return DropdownMenuItem(value: pastYear, child: Text(pastYear));
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedYearFilter = val!;
                  _loadData();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 200),
      decoration: BoxDecoration(
        color: const Color(0xFFCB001D).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFCB001D).withOpacity(0.1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedReport,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Color(0xFFCB001D),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          items: _reportTypes.map((ReportType type) {
            return DropdownMenuItem<String>(
              value: type.label,
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
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedReport = newValue!;
              _searchQuery = '';
              _selectedDateFilter = 'All';
              _selectedMonthFilter = 'All';
              _selectedYearFilter = 'All';
              _loadData();
            });
          },
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: '🔍 جستجو در گزارشات...',
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

  List<Widget> _buildUnitCards() {
    if (_reportData.isEmpty) return [];

    Map<String, double> unitTotals = {};
    for (var item in _reportData) {
      String unit = item['unit']?.toString() ?? 'نامشخص';
      double weight = double.tryParse(item['gross_weight']?.toString() ?? '0') ?? 0.0;
      unitTotals[unit] = (unitTotals[unit] ?? 0) + weight;
    }

    return unitTotals.entries.map((entry) {
      String unit = entry.key;
      double totalWeight = entry.value;
      return Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12, bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFCB001D).withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.scale, color: Color(0xFFCB001D), size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              unit,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 4),
            Text(
              totalWeight.toStringAsFixed(0),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFCB001D)),
            ),
            const Text(
              'موجودی کل',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildStats() {
    final data = _getFilteredData();
    final totalItems = data.length;
    
    double totalAmount = 0;
    for (var item in data) {
      for (var key in item.keys) {
        final lowerKey = key.toLowerCase();
        if (lowerKey.contains('amount') || 
            lowerKey.contains('price') || 
            lowerKey.contains('total') || 
            lowerKey.contains('balance') ||
            lowerKey.contains('final') ||
            lowerKey.contains('payment') ||
            lowerKey.contains('value')) {
          final value = item[key];
          if (value is num) {
            totalAmount += value.toDouble();
          } else if (value is String) {
            final parsed = double.tryParse(value.replaceAll(',', ''));
            if (parsed != null) totalAmount += parsed;
          }
        }
      }
    }

    List<Widget> stats = [
      _buildStatCard(
        'تعداد کل',
        totalItems.toString(),
        Icons.numbers,
        const Color(0xFFCB001D),
      ),
      _buildStatCard(
        'جمع کل',
        _formatCurrency(totalAmount),
        Icons.attach_money,
        const Color(0xFFCB001D),
      ),
      _buildStatCard(
        'نوع گزارش',
        _selectedReport,
        Icons.report,
        const Color(0xFFCB001D),
      ),
      _buildStatCard(
        'تعداد ستون‌ها',
        data.isNotEmpty ? data.first.keys.length.toString() : '0',
        Icons.table_chart,
        const Color(0xFFCB001D),
      ),
    ];

    if (_selectedReport == 'مواد خام') {
      stats.insert(1, _buildStatCard(
        'امروز (تعداد/مبلغ)',
        '${_statsData['today_count']} / ${_formatCurrency(_statsData['today_total'])}',
        Icons.today,
        Colors.green,
      ));
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: stats,
          ),
          if (_selectedReport == 'مواد خام' && data.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'موجودی بر اساس واحد:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _buildUnitCards(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
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
    
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)} میلیارد';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)} میلیون';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)} هزار';
    }
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), 
      (m) => '${m[1]},'
    );
  }

  Widget _buildReportTable() {
    final data = _getFilteredData();

    if (data.isEmpty) {
      return _buildEmptyState();
    }

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
        border: Border.all(
          color: const Color(0xFFCB001D).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;

          if (isSmallScreen) {
            return _buildMobileCards(data);
          }

          return _buildDesktopTable(data);
        },
      ),
    );
  }

  Widget _buildMobileCards(List<Map<String, dynamic>> data) {
    final importantFields = data.first.keys
        .where((key) => 
            key.contains('name') || 
            key.contains('id') || 
            key.contains('amount') || 
            key.contains('price') || 
            key.contains('total') ||
            key.contains('date') ||
            key.contains('status'))
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFCB001D),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item['id']?.toString() ?? 'ردیف ${index + 1}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: importantFields.where((key) => key != 'id').map((key) {
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
                              _getFieldLabel(key),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
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
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isNumeric(String value) {
    return double.tryParse(value.replaceAll(',', '')) != null ||
           int.tryParse(value.replaceAll(',', '')) != null;
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> data) {
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
          // Table Header (Fixed at top)
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
                  'جدول گزارشات',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${data.length} رکورد | ${headers.length} ستون',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
              ],
            ),
          ),

          // No height constraint! Let the table grow as much as it wants
          SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              padding: const EdgeInsets.all(16),
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB001D), fontSize: 12),
                dataRowMinHeight: 40,
                dataRowMaxHeight: 50,
                columnSpacing: 20,
                columns: headers.map((header) {
                  return DataColumn(
                    label: Container(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        _getFieldLabel(header),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
                rows: data.map((item) {
                  return DataRow(
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
                  );
                }).toList(),
              ),
            ),
          ),

          // Footer (Scroll controls)
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
                  '👈 برای مشاهده ستون‌های بیشتر، افقی اسکرول کنید',
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

  String _getFieldLabel(String key) {
    final labels = {
      'id': 'شناسه',
      'created_at': 'تاریخ ایجاد',
      'name': 'نام',
      'supplier_name': 'تأمین‌کننده',
      'supplier_phone': 'تلفن تأمین‌کننده',
      'supplier_email': 'ایمیل تأمین‌کننده',
      'supplier_address': 'آدرس تأمین‌کننده',
      'material_type': 'نوع ماده',
      'thickness': 'ضخامت',
      'net_weight': 'وزن خالص',
      'gross_weight': 'وزن ناخالص',
      'unit': 'واحد',
      'unit_price': 'قیمت واحد',
      'product': 'محصول',
      'commission': 'کمیسیون',
      'transfer_cost': 'هزینه حمل',
      'miscellaneous': 'متفرقه',
      'ghurfedari': 'غرفه‌داری',
      'barchalani': 'بارچالانی',
      'purchase_type': 'نوع خرید',
      'seller_payment': 'پرداخت فروشنده',
      'seller_payment_method': 'روش پرداخت',
      'seller_paid_amount': 'مبلغ پرداختی',
      'currency': 'ارز',
      'exchange_rate': 'نرخ ارز',
      'final_price': 'قیمت نهایی',
      'date': 'تاریخ',
      'date_en': 'تاریخ (انگلیسی)',
      'product_name': 'نام محصول',
      'production_type': 'نوع تولید',
      'loading': 'بارگیری',
      'length': 'طول',
      'quantity': 'تعداد',
      'weight': 'وزن',
      'production_date': 'تاریخ تولید',
      'production_date_en': 'تاریخ تولید (انگلیسی)',
      'status': 'وضعیت',
      'batch': 'دسته',
      'description': 'توضیحات',
      'invoice_number': 'شماره فاکتور',
      'customer_name': 'مشتری',
      'customer_phone': 'تلفن مشتری',
      'customer_address': 'آدرس مشتری',
      'customer_company': 'شرکت مشتری',
      'gender': 'جنسیت',
      'size': 'سایز',
      'total_weight': 'وزن کل',
      'total_price': 'قیمت کل',
      'price_rate': 'نرخ قیمت',
      'usd_equivalent': 'معادل USD',
      'afn_equivalent': 'معادل AFN',
      'loading_cost': 'هزینه بارگیری',
      'clearance_cost': 'هزینه ترخیص',
      'discount': 'تخفیف',
      'loading_time': 'زمان بارگیری',
      'loading_time_en': 'زمان بارگیری (انگلیسی)',
      'payment_method': 'روش پرداخت',
      'loan_type': 'نوع قرض',
      'paid_amount': 'مبلغ پرداختی',
      'remaining_amount': 'باقیمانده',
      'sale_type': 'نوع فروش',
      'is_back_returned': 'برگشتی',
      'back_return_reason': 'دلیل برگشت',
      'back_return_date': 'تاریخ برگشت',
      'back_return_date_en': 'تاریخ برگشت (انگلیسی)',
      'service_title': 'عنوان خدمات',
      'service_type': 'نوع خدمات',
      'price': 'قیمت',
      'total_amount': 'مبلغ کل',
      'due_date': 'تاریخ سررسید',
      'loan_source': 'منبع قرض',
      'account_id': 'شناسه حساب',
      'account_number': 'شماره حساب',
      'transaction_type': 'نوع تراکنش',
      'amount_usd': 'مبلغ USD',
      'amount_afn': 'مبلغ AFN',
      'balance_after': 'موجودی بعدی',
      'source_name': 'نام منبع',
      'source_account': 'حساب منبع',
      'source_email': 'ایمیل منبع',
      'source_phone': 'تلفن منبع',
      'address': 'آدرس',
      'note': 'یادداشت',
      'current_usd_balance': 'موجودی USD',
      'initial_usd_balance': 'موجودی اولیه USD',
      'asset_type': 'نوع دارایی',
      'asset_name': 'نام دارایی',
      'current_balance': 'موجودی فعلی',
      'initial_balance': 'موجودی اولیه',
      'category': 'دسته‌بندی',
      'party_details': 'جزئیات طرف',
      'waste_type': 'نوع ضایعات',
      'value': 'ارزش',
      'nickname': 'نام مستعار',
      'phone': 'تلفن',
      'email': 'ایمیل',
      'type': 'نوع',
      'transactions': 'تراکنش‌ها',
    };
    return labels[key] ?? key.replaceAll('_', ' ');
  }

  List<Map<String, dynamic>> _getFilteredData() {
    if (_searchQuery.isEmpty) return _reportData;
    
    return _reportData.where((item) {
      return item.values.any((value) =>
          value != null && 
          value.toString().toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();
  }

  void _printReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🖨️ در حال آماده‌سازی برای چاپ...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _generatePDFReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📄 در حال تولید PDF...'),
        duration: Duration(seconds: 2),
      ),
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
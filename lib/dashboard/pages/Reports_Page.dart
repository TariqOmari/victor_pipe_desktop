import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
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
  
  final List<ReportType> _reportTypes = [
    ReportType(
      id: 'raw_materials',
      label: 'مواد خام',
      icon: Icons.inventory_2,
      color: Colors.blue,
      fetchData: (db) => db.getRawMaterials(),
    ),
    ReportType(
      id: 'produced_products',
      label: 'محصولات تولیدی',
      icon: Icons.factory,
      color: Colors.green,
      fetchData: (db) => db.getProducedProducts(),
    ),
    ReportType(
      id: 'sales_invoices',
      label: 'فروشات',
      icon: Icons.receipt_long,
      color: Colors.orange,
      fetchData: (db) => db.getSalesInvoices(),
    ),
    ReportType(
      id: 'service_invoices',
      label: 'فاکتورهای خدمات',
      icon: Icons.build_circle,
      color: Colors.purple,
      fetchData: (db) => db.getServiceInvoices(),
    ),
    ReportType(
      id: 'customers',
      label: 'مشتریان',
      icon: Icons.people,
      color: Colors.teal,
      fetchData: (db) => db.getCustomers(),
    ),
    ReportType(
      id: 'companies',
      label: 'شرکت‌ها',
      icon: Icons.business,
      color: Colors.indigo,
      fetchData: (db) => db.getCompanies(),
    ),
    ReportType(
      id: 'suppliers',
      label: 'تأمین‌کنندگان',
      icon: Icons.local_shipping,
      color: Colors.cyan,
      fetchData: (db) => db.getSuppliers(),
    ),
    ReportType(
      id: 'sell_loans',
      label: 'قرضه‌ها',
      icon: Icons.credit_card,
      color: Colors.red,
      fetchData: (db) => db.getSellLoans(),
    ),
    ReportType(
      id: 'sarafi_transactions',
      label: 'صرافی',
      icon: Icons.currency_exchange,
      color: Colors.amber,
      fetchData: (db) => db.getSarafiTransactions(),
    ),
    ReportType(
      id: 'daily_expenses',
      label: 'هزینه‌های روزانه',
      icon: Icons.money_off,
      color: Colors.pink,
      fetchData: (db) => db.getDailyExpenses(),
    ),
    ReportType(
      id: 'waste_records',
      label: 'ضایعات و تلفات',
      icon: Icons.delete_outline,
      color: Colors.brown,
      fetchData: (db) => db.getWasteRecords(),
    ),
    ReportType(
      id: 'capital_assets',
      label: 'دارایی‌های سرمایه‌ای',
      icon: Icons.account_balance,
      color: Colors.deepPurple,
      fetchData: (db) => db.getCapitalAssets(),
    ),
    ReportType(
      id: 'capital_transactions',
      label: 'تراکنش‌های سرمایه‌ای',
      icon: Icons.swap_horiz,
      color: Colors.lightBlue,
      fetchData: (db) => db.getCapitalTransactions(),
    ),
    ReportType(
      id: 'sarafi_accounts',
      label: 'حساب‌های صرافی',
      icon: Icons.account_balance_wallet,
      color: Colors.deepOrange,
      fetchData: (db) => db.getSarafiAccounts(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final reportType = _reportTypes.firstWhere(
        (r) => r.label == _selectedReport,
        orElse: () => _reportTypes.first,
      );
      final data = await reportType.fetchData(_db);
      setState(() {
        _reportData = data;
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
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildFilters(),
            const SizedBox(height: 12),
            _buildStats(),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isEmpty
                  ? _buildEmptyState()
                  : _buildReportTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFFCB001D),
            Color(0xFFA80018),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCB001D).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.report_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'گزارشات مدیریتی',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'مشاهده و چاپ گزارشات از تمام بخش‌های سیستم',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.picture_as_pdf,
                label: 'PDF',
                color: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.2),
                onPressed: _generatePDFReport,
              ),
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
    );
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'هیچ داده‌ای برای نمایش وجود ندارد',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'برای این گزارش هیچ رکوردی یافت نشد',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
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
          final isSmallScreen = constraints.maxWidth < 700;

          if (isSmallScreen) {
            return Column(
              children: [
                _buildReportTypeDropdown(),
                const SizedBox(height: 8),
                _buildSearchField(),
              ],
            );
          }

          return Row(
            children: [
              _buildReportTypeDropdown(),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSearchField(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 180),
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
                  Icon(type.icon, size: 18, color: type.color),
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

  Widget _buildStats() {
    final data = _getFilteredData();
    final totalItems = data.length;
    
    double totalAmount = 0;
    for (var item in data) {
      for (var key in item.keys) {
        if (key.contains('amount') || 
            key.contains('price') || 
            key.contains('total') || 
            key.contains('balance')) {
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

    final currentType = _reportTypes.firstWhere(
      (r) => r.label == _selectedReport,
      orElse: () => _reportTypes.first,
    );

    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildStatCard(
            'تعداد کل',
            totalItems.toString(),
            Icons.numbers,
            Colors.blue,
          ),
          _buildStatCard(
            'جمع کل',
            _formatNumber(totalAmount),
            Icons.attach_money,
            const Color(0xFFCB001D),
          ),
          _buildStatCard(
            'نوع گزارش',
            _selectedReport,
            currentType.icon,
            currentType.color,
          ),
          _buildStatCard(
            'تعداد ستون‌ها',
            data.isNotEmpty ? data.first.keys.length.toString() : '0',
            Icons.table_chart,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 9,
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)} میلیارد';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)} میلیون';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)} هزار';
    }
    return number.toStringAsFixed(0);
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
          color: const Color(0xFFCB001D).withOpacity(0.06),
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
        .take(6)
        .toList();

    final currentType = _reportTypes.firstWhere(
      (r) => r.label == _selectedReport,
      orElse: () => _reportTypes.first,
    );

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
                decoration: BoxDecoration(
                  color: currentType.color.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          currentType.icon,
                          color: currentType.color,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item['id']?.toString() ?? 'ردیف ${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: currentType.color,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: currentType.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: currentType.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: importantFields.where((key) => key != 'id').map((key) {
                    final value = item[key];
                    if (value == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getFieldLabel(key),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              value.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isNumeric(value.toString()) 
                                    ? const Color(0xFFCB001D) 
                                    : const Color(0xFF1A1A2E),
                              ),
                              textAlign: TextAlign.left,
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
    
    // Calculate available width
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 1200 ? 220.0 : 260.0;
    final availableWidth = screenWidth - sidebarWidth - 32; // 32 for padding
    
    // Calculate column width
    final columnWidth = (availableWidth - 32) / headers.length.clamp(1, 15);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: availableWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header
            Container(
              width: availableWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.05),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFCB001D), width: 1.5),
                ),
              ),
              child: Row(
                children: headers.map((header) {
                  return SizedBox(
                    width: columnWidth,
                    child: Text(
                      _getFieldLabel(header),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Color(0xFF1A1A2E),
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
            // Table Body
            ...data.map((item) {
              return Container(
                width: availableWidth,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: headers.map((header) {
                    final value = item[header]?.toString() ?? '-';
                    final isNumeric = _isNumeric(value);
                    
                    return SizedBox(
                      width: columnWidth,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isNumeric ? FontWeight.bold : FontWeight.normal,
                          color: isNumeric ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ],
        ),
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
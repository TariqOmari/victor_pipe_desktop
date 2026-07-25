import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // انتخاب نوع گزارش
  String _selectedReport = 'مواد خام';
  final List<String> _reportTypes = [
    'مواد خام',
    'تولید',
    'فروشات',
    'مشتریان',
    'فروشندگان',
    'قرضه‌ها',
    'صرافی',
  ];

  // فیلتر تاریخ
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  // داده‌های نمونه برای هر گزارش
  final Map<String, List<Map<String, dynamic>>> _reportData = {
    'مواد خام': [
      {
        'id': 'RM-001',
        'name': 'لوله پلی‌اتیلن',
        'supplier': 'شرکت پلیمر',
        'quantity': 150,
        'unit': 'متر',
        'price': 450000,
        'total': 67500000,
        'date': '۱۴۰۵/۰۵/۰۱',
      },
      {
        'id': 'RM-002',
        'name': 'اتصالات جوشی',
        'supplier': 'صنایع فلزی',
        'quantity': 80,
        'unit': 'عدد',
        'price': 320000,
        'total': 25600000,
        'date': '۱۴۰۵/۰۵/۰۲',
      },
      {
        'id': 'RM-003',
        'name': 'لوله فولادی',
        'supplier': 'فولاد مبارکه',
        'quantity': 200,
        'unit': 'متر',
        'price': 580000,
        'total': 116000000,
        'date': '۱۴۰۵/۰۵/۰۳',
      },
      {
        'id': 'RM-004',
        'name': 'کمربند فلنج',
        'supplier': 'صنایع فلزی',
        'quantity': 45,
        'unit': 'عدد',
        'price': 175000,
        'total': 7875000,
        'date': '۱۴۰۵/۰۵/۰۴',
      },
    ],
    'تولید': [
      {
        'id': 'P-1001',
        'product': 'لوله پلی‌اتیلن ۲۵۰',
        'type': 'لوله',
        'quantity': 150,
        'unit': 'متر',
        'weight': '۳۲۰ کیلوگرم',
        'status': 'تکمیل شده',
        'date': '۱۴۰۵/۰۵/۰۱',
      },
      {
        'id': 'P-1002',
        'product': 'اتصالات جوشی ۴ اینچ',
        'type': 'اتصال',
        'quantity': 80,
        'unit': 'عدد',
        'weight': '۴۵ کیلوگرم',
        'status': 'در حال تولید',
        'date': '۱۴۰۵/۰۵/۰۲',
      },
      {
        'id': 'P-1003',
        'product': 'لوله فولادی ۴ اینچ',
        'type': 'لوله',
        'quantity': 200,
        'unit': 'متر',
        'weight': '۸۵۰ کیلوگرم',
        'status': 'تکمیل شده',
        'date': '۱۴۰۵/۰۵/۰۳',
      },
    ],
    'فروشات': [
      {
        'id': 'S-1001',
        'customer': 'علی رضایی',
        'product': 'لوله پلی‌اتیلن',
        'quantity': 150,
        'unit': 'متر',
        'price': 450000,
        'total': 67500000,
        'status': 'تکمیل شده',
        'date': '۱۴۰۵/۰۵/۰۱',
      },
      {
        'id': 'S-1002',
        'customer': 'شرکت نفت جنوب',
        'product': 'اتصالات جوشی',
        'quantity': 80,
        'unit': 'عدد',
        'price': 320000,
        'total': 25600000,
        'status': 'در انتظار',
        'date': '۱۴۰۵/۰۵/۰۲',
      },
      {
        'id': 'S-1003',
        'customer': 'مهندس کریمی',
        'product': 'لوله فولادی',
        'quantity': 200,
        'unit': 'متر',
        'price': 580000,
        'total': 116000000,
        'status': 'ارسال شده',
        'date': '۱۴۰۵/۰۵/۰۳',
      },
    ],
    'مشتریان': [
      {
        'id': 'C-001',
        'name': 'علی رضایی',
        'phone': '۰۹۱۲۱۲۳۴۵۶۷',
        'email': 'ali@email.com',
        'type': 'حقیقی',
        'total_purchases': 67500000,
        'last_purchase': '۱۴۰۵/۰۵/۰۱',
      },
      {
        'id': 'C-002',
        'name': 'شرکت نفت جنوب',
        'phone': '۰۲۱۲۲۳۳۴۴۵۵',
        'email': 'info@oil.com',
        'type': 'حقوقی',
        'total_purchases': 25600000,
        'last_purchase': '۱۴۰۵/۰۵/۰۲',
      },
      {
        'id': 'C-003',
        'name': 'مهندس کریمی',
        'phone': '۰۹۱۲۳۴۵۶۷۸۹',
        'email': 'karimi@email.com',
        'type': 'حقیقی',
        'total_purchases': 116000000,
        'last_purchase': '۱۴۰۵/۰۵/۰۳',
      },
    ],
    'فروشندگان': [
      {
        'id': 'V-001',
        'name': 'شرکت پلیمر',
        'phone': '۰۲۱۸۸۷۷۶۶۵۵',
        'email': 'info@polymer.com',
        'type': 'تأمین‌کننده',
        'total_supplies': 67500000,
        'last_supply': '۱۴۰۵/۰۵/۰۱',
      },
      {
        'id': 'V-002',
        'name': 'صنایع فلزی',
        'phone': '۰۲۱۸۸۷۷۴۴۳۳',
        'email': 'info@metal.com',
        'type': 'تأمین‌کننده',
        'total_supplies': 25600000,
        'last_supply': '۱۴۰۵/۰۵/۰۲',
      },
      {
        'id': 'V-003',
        'name': 'فولاد مبارکه',
        'phone': '۰۳۱۳۲۲۳۳۴۴۵',
        'email': 'info@mobarakeh.com',
        'type': 'تأمین‌کننده',
        'total_supplies': 116000000,
        'last_supply': '۱۴۰۵/۰۵/۰۳',
      },
    ],
    'قرضه‌ها': [
      {
        'id': 'L-001',
        'customer': 'محمد کریمی',
        'amount': 5000000,
        'interest': 0,
        'date': '۱۴۰۵/۰۵/۰۱',
        'due_date': '۱۴۰۵/۰۶/۰۱',
        'status': 'فعال',
      },
      {
        'id': 'L-002',
        'customer': 'احمد حسینی',
        'amount': 3000000,
        'interest': 5,
        'date': '۱۴۰۵/۰۵/۰۲',
        'due_date': '۱۴۰۵/۰۶/۰۲',
        'status': 'تسویه شده',
      },
      {
        'id': 'L-003',
        'customer': 'علی رضایی',
        'amount': 10000000,
        'interest': 3,
        'date': '۱۴۰۵/۰۵/۰۳',
        'due_date': '۱۴۰۵/۰۷/۰۳',
        'status': 'فعال',
      },
    ],
    'صرافی': [
      {
        'id': 'EX-001',
        'type': 'خرید ارز',
        'currency': 'USD',
        'amount': 1000,
        'rate': 85000,
        'total': 85000000,
        'date': '۱۴۰۵/۰۵/۰۱',
        'status': 'انجام شده',
      },
      {
        'id': 'EX-002',
        'type': 'فروش ارز',
        'currency': 'EUR',
        'amount': 500,
        'rate': 92000,
        'total': 46000000,
        'date': '۱۴۰۵/۰۵/۰۲',
        'status': 'انجام شده',
      },
      {
        'id': 'EX-003',
        'type': 'خرید ارز',
        'currency': 'GBP',
        'amount': 200,
        'rate': 105000,
        'total': 21000000,
        'date': '۱۴۰۵/۰۵/۰۳',
        'status': 'در انتظار',
      },
    ],
  };

  // ============ BUILD HEADER ============
  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'گزارشات',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'مدیریت و چاپ گزارشات مدیریتی',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (!isSmallScreen) ...[
                  ElevatedButton.icon(
                    onPressed: _generatePDFReport,
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
                    label: const Text(
                      'خروجی PDF',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: _printReport,
                  icon: const Icon(Icons.print, color: Colors.white, size: 18),
                  label: Text(
                    isSmallScreen ? 'چاپ' : 'چاپ',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ============ BUILD FILTERS ============
  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          final isMediumScreen = constraints.maxWidth < 1000;

          if (isSmallScreen) {
            return Column(
              children: [
                _buildReportTypeDropdown(),
                const SizedBox(height: 8),
                _buildSearchField(),
                const SizedBox(height: 8),
                _buildDateFilters(),
              ],
            );
          }

          return Row(
            children: [
              _buildReportTypeDropdown(),
              const SizedBox(width: 12),
              Expanded(
                flex: isMediumScreen ? 1 : 2,
                child: _buildSearchField(),
              ),
              const SizedBox(width: 12),
              _buildDateFilters(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFCB001D).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
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
          items: _reportTypes.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedReport = newValue!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'جستجو در گزارشات...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.grey.shade400,
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        isDense: true,
      ),
    );
  }

  Widget _buildDateFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;

        if (isSmallScreen) {
          return Column(
            children: [
              _buildDatePicker(true),
              const SizedBox(height: 4),
              _buildDatePicker(false),
            ],
          );
        }

        return Row(
          children: [
            _buildDatePicker(true),
            const SizedBox(width: 6),
            const Text('تا', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(width: 6),
            _buildDatePicker(false),
            if (_startDate != null || _endDate != null) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDatePicker(bool isStart) {
    return InkWell(
      onTap: () => _selectDate(context, isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFFCB001D)),
            const SizedBox(width: 4),
            Text(
              isStart
                  ? (_startDate != null
                      ? '${_startDate!.year}/${_startDate!.month}/${_startDate!.day}'
                      : 'از تاریخ')
                  : (_endDate != null
                      ? '${_endDate!.year}/${_endDate!.month}/${_endDate!.day}'
                      : 'تا تاریخ'),
              style: TextStyle(
                fontSize: 11,
                color: (isStart ? _startDate : _endDate) != null
                    ? Colors.black
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ BUILD STATS ============
  Widget _buildStats() {
    final data = _getFilteredData();
    final totalItems = data.length;
    
    double totalAmount = 0;
    for (var item in data) {
      if (item.containsKey('total')) {
        totalAmount += (item['total'] as num).toDouble();
      } else if (item.containsKey('amount')) {
        totalAmount += (item['amount'] as num).toDouble();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isSmallScreen
              ? Column(
                  children: [
                    _buildStatItem('تعداد کل', totalItems.toString(), Icons.numbers, Colors.blue),
                    const SizedBox(height: 8),
                    _buildStatItem('جمع کل', formatNumber(totalAmount), Icons.attach_money, const Color(0xFFCB001D)),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('تعداد کل', totalItems.toString(), Icons.numbers, Colors.blue),
                    ),
                    Expanded(
                      child: _buildStatItem('جمع کل', formatNumber(totalAmount), Icons.attach_money, const Color(0xFFCB001D)),
                    ),
                    Expanded(
                      child: _buildStatItem('نوع گزارش', _selectedReport, Icons.report, Colors.orange),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
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
          ),
        ],
      ),
    );
  }

  String formatNumber(double number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)} میلیارد';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)} میلیون';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)} هزار';
    }
    return number.toStringAsFixed(0);
  }

  // ============ BUILD REPORT TABLE - FULL WIDTH ============
  Widget _buildReportTable() {
    final data = _getFilteredData();

    if (data.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.report_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'هیچ داده‌ای برای نمایش وجود ندارد',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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

          return _buildDesktopTable(data, constraints.maxWidth);
        },
      ),
    );
  }

  // ============ MOBILE CARDS VIEW ============
  Widget _buildMobileCards(List<Map<String, dynamic>> data) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCB001D).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item['id'] ?? '-',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFCB001D),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...item.entries.where((entry) => entry.key != 'id').map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getFieldLabel(entry.key),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // ============ DESKTOP TABLE VIEW - FULL WIDTH ============
  Widget _buildDesktopTable(List<Map<String, dynamic>> data, double maxWidth) {
    final headers = data.first.keys.toList();
    final headerCount = headers.length;
    
    // محاسبه عرض هر ستون به صورت درصدی از کل عرض
    final double columnWidth = (maxWidth - 40) / headerCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFCB001D).withOpacity(0.05),
            border: const Border(
              bottom: BorderSide(color: Colors.grey, width: 0.5),
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
        // Rows
        ...data.map((item) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 0.3),
              ),
            ),
            child: Row(
              children: headers.map((header) {
                final value = item[header]?.toString() ?? '-';
                final isTotal = header == 'total' || header == 'amount' || 
                               header == 'total_purchases' || header == 'total_supplies';
                
                return SizedBox(
                  width: columnWidth,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                      color: isTotal ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E),
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
    );
  }

  // ============ HELPERS ============
  String _getFieldLabel(String key) {
    final labels = {
      'id': 'شناسه',
      'name': 'نام',
      'product': 'محصول',
      'product_name': 'نام محصول',
      'supplier': 'فروشنده',
      'customer': 'مشتری',
      'type': 'نوع',
      'quantity': 'تعداد',
      'unit': 'واحد',
      'price': 'قیمت واحد',
      'total': 'جمع کل',
      'date': 'تاریخ',
      'status': 'وضعیت',
      'weight': 'وزن',
      'phone': 'تلفن',
      'email': 'ایمیل',
      'total_purchases': 'کل خرید',
      'last_purchase': 'آخرین خرید',
      'total_supplies': 'کل تأمین',
      'last_supply': 'آخرین تأمین',
      'amount': 'مبلغ',
      'interest': 'بهره',
      'due_date': 'تاریخ سررسید',
      'currency': 'ارز',
      'rate': 'نرخ',
    };
    return labels[key] ?? key;
  }

  List<Map<String, dynamic>> _getFilteredData() {
    var data = _reportData[_selectedReport] ?? [];

    if (_searchQuery.isNotEmpty) {
      data = data.where((item) {
        return item.values.any((value) =>
            value.toString().contains(_searchQuery));
      }).toList();
    }

    return data;
  }

  // ============ DATE PICKER ============
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // ============ PRINT & PDF ============
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

  // ============ MAIN BUILD ============
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 16),
            _buildStats(),
            const SizedBox(height: 12),
            Expanded(
              child: _buildReportTable(),
            ),
          ],
        ),
      ),
    );
  }
}
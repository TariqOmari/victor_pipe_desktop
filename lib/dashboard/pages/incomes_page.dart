// lib/screens/pages/incomes_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/language_provider.dart';

class IncomesPage extends StatefulWidget {
  const IncomesPage({super.key});

  @override
  State<IncomesPage> createState() => _IncomesPageState();
}

class _IncomesPageState extends State<IncomesPage>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;

  // Data
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _producedProducts = [];
  List<Map<String, dynamic>> _dailyExpenses = [];
  // <<< NEW: Add a list to hold service invoices
  List<Map<String, dynamic>> _services = [];

  // Calculated
  double _totalSales = 0;
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
    // Rough Persian date conversion
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
      final rawMaterials = await _db.getRawMaterials();
      final producedProducts = await _db.getProducedProducts();
      final dailyExpenses = await _db.getDailyExpenses();
      // <<< NEW: Fetch service invoices
      final services = await _db.getServiceInvoices();

      setState(() {
        _sales = sales;
        _rawMaterials = rawMaterials;
        _producedProducts = producedProducts;
        _dailyExpenses = dailyExpenses;
        _services = services; // <<< NEW
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
    // <<< NEW: Get filtered services for the selected month
    final filteredServices = _getFilteredServices();
    final filteredExpenses = _getFilteredExpenses();

    // --- Calculate Total Sales (Products + Services) ---
    double salesTotal = filteredSales.fold<double>(0, (sum, sale) {
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

    // <<< NEW: Calculate total service income
    double servicesTotal = filteredServices.fold<double>(0, (sum, service) {
      final price = double.tryParse(service['final_price']?.toString() ?? '0') ?? 0;
      // Use exchange_rate from service table
      if (service['currency'] == 'AFN' && _selectedCurrency == 'USD') {
        final rate = double.tryParse(service['exchange_rate']?.toString() ?? '1') ?? 1;
        return sum + (rate > 0 ? price / rate : 0);
      } else if (service['currency'] == 'USD' && _selectedCurrency == 'AFN') {
        final rate = double.tryParse(service['exchange_rate']?.toString() ?? '1') ?? 1;
        return sum + (price * rate);
      }
      return sum + price;
    });

    // <<< NEW: Combine both totals
    _totalSales = salesTotal + servicesTotal;

    // --- Calculate Raw Material Cost (Only for products) ---
    _totalRawMaterialCost = _calculateRawMaterialCost(filteredSales);
    _grossProfit = _totalSales - _totalRawMaterialCost;
    _profitMargin = _totalSales > 0 ? (_grossProfit / _totalSales) * 100 : 0;

    // --- Calculate Expenses ---
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
    _netProfitMargin = _totalSales > 0 ? (_netProfit / _totalSales) * 100 : 0;
  }

  double _calculateRawMaterialCost(List<Map<String, dynamic>> filteredSales) {
    // This function remains largely the same, only calculating cost based on product sales.
    // This is the core logic you described: Raw Materials cost is ONLY against product sales.
    final Map<String, double> productCostMap = {};

    // ... (rest of the function is unchanged, it uses filteredSales) ...
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

  // ============ CORRECT PERSIAN TO GREGORIAN CONVERSION ============
  List<DateTime> _getGregorianRangeForPersianMonth(int year, int month) {
    // ... (this function remains unchanged) ...
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
    // ... (this function remains unchanged) ...
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

  // <<< NEW: Filter services by date
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
    // ... (this function remains unchanged) ...
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
            : Column(
                crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildFilterRow(),
                  const SizedBox(height: 16),
                  _buildTabBar(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGrossProfitView(),
                        _buildNetProfitView(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    // ... (this function remains unchanged) ...
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
                const Text(
                  'مدیریت عواید',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  'محاسبه سود ناخالص و خالص (شامل فروش کالا و خدمات)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
          label: const Text('تازه سازی', style: TextStyle(color: Colors.white, fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCB001D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    // ... (this function remains unchanged) ...
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
                  '${_getFilteredSales().length} فروش | ${_getFilteredServices().length} خدمات | ${_getFilteredExpenses().length} هزینه',
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

  Widget _buildTabBar() {
    // ... (this function remains unchanged) ...
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
        tabs: const [
          Tab(text: '💰 سود ناخالص'),
          Tab(text: '📊 سود خالص'),
        ],
      ),
    );
  }

  Widget _buildGrossProfitView() {
    // ... (this function remains unchanged) ...
    final isProfit = _grossProfit >= 0;
    final profitColor = isProfit ? Colors.green.shade700 : Colors.red.shade700;

    return Column(
      children: [
        _buildGrossProfitCards(),
        const SizedBox(height: 12),
        _buildProfitSummary(isProfit, profitColor, _grossProfit, _profitMargin,
            _totalSales, _totalRawMaterialCost, 'سود ناخالص', 'هزینه مواد خام'),
        const SizedBox(height: 12),
        Expanded(
          child: _buildSalesTable(),
        ),
      ],
    );
  }

  Widget _buildGrossProfitCards() {
    // ... (this function remains unchanged) ...
    return Row(
      children: [
        _buildStatCard('کل فروش (کالا و خدمات)', _formatCurrency(_totalSales),
            Icons.trending_up_rounded, Colors.blue.shade700, 'مجموع فروش ناخالص'),
        const SizedBox(width: 12),
        _buildStatCard('هزینه مواد خام', _formatCurrency(_totalRawMaterialCost),
            Icons.warehouse_outlined, Colors.orange.shade700, 'قیمت تمام شده کالا'),
        const SizedBox(width: 12),
        _buildStatCard(
            'سود ناخالص',
            _formatCurrency(_grossProfit),
            Icons.account_balance_rounded,
            _grossProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
            '${_profitMargin.toStringAsFixed(1)}% حاشیه سود'),
      ],
    );
  }

  Widget _buildNetProfitView() {
    // ... (this function remains unchanged) ...
    final isProfit = _netProfit >= 0;
    final profitColor = isProfit ? Colors.green.shade700 : Colors.red.shade700;

    return Column(
      children: [
        _buildNetProfitCards(),
        const SizedBox(height: 12),
        _buildProfitSummary(isProfit, profitColor, _netProfit, _netProfitMargin,
            _totalSales, _totalExpenses, 'سود خالص', 'مصارف روزانه'),
        const SizedBox(height: 12),
        Expanded(
          child: _buildExpensesTable(),
        ),
      ],
    );
  }

  Widget _buildNetProfitCards() {
    // ... (this function remains unchanged) ...
    return Row(
      children: [
        _buildStatCard('سود ناخالص', _formatCurrency(_grossProfit),
            Icons.trending_up_rounded,
            _grossProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
            'قبل از کسر مصارف'),
        const SizedBox(width: 12),
        _buildStatCard('مصارف روزانه', _formatCurrency(_totalExpenses),
            Icons.account_balance_wallet_outlined, Colors.orange.shade700,
            'مجموع مصارف'),
        const SizedBox(width: 12),
        _buildStatCard(
            'سود خالص',
            _formatCurrency(_netProfit),
            Icons.account_balance_rounded,
            _netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
            '${_netProfitMargin.toStringAsFixed(1)}% حاشیه سود خالص'),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    // ... (this function remains unchanged) ...
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
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitSummary(bool isProfit, Color profitColor, double profit,
      double margin, double total, double cost, String profitLabel, String costLabel) {
    // ... (this function remains unchanged) ...
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
                    const Text('حاشیه سود: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                  Text('سود: ${_formatCurrency(profit)}', style: TextStyle(fontSize: 10, color: profitColor)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // <<< NEW: Updated table to show both sales and services
  Widget _buildSalesTable() {
    final filteredSales = _getFilteredSales();
    final filteredServices = _getFilteredServices();

    // Combine sales and services for the table
    List<Map<String, dynamic>> combinedItems = [
      ...filteredSales.map((s) => {...s, '_type': 'sale'}),
      ...filteredServices.map((s) => {...s, '_type': 'service'}),
    ];
    
    // Sort by date or invoice number (optional but good practice)
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
                ? const Center(child: Text('هیچ فروش یا خدماتی یافت نشد', style: TextStyle(color: Colors.grey)))
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
                                  isService ? 'خدمات' : 'فروش',
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
          _buildPagination(combinedItems.length, totalPages),
        ],
      ),
    );
  }

  Widget _buildExpensesTable() {
    // ... (this function remains unchanged) ...
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
                ? const Center(child: Text('هیچ هزینه‌ای یافت نشد', style: TextStyle(color: Colors.grey)))
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
          _buildPagination(filteredExpenses.length, totalPages),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalItems, int totalPages) {
    // ... (this function remains unchanged) ...
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
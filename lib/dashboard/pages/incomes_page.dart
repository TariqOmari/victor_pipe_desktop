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

class _IncomesPageState extends State<IncomesPage> with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  
  // Data
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _producedProducts = [];
  List<Map<String, dynamic>> _dailyExpenses = [];
  
  // Calculated
  double _totalSales = 0;
  double _totalRawMaterialCost = 0;
  double _grossProfit = 0;
  double _profitMargin = 0;
  double _totalExpenses = 0;
  double _netProfit = 0;
  double _netProfitMargin = 0;
  
  // Filters
  String _filterPeriod = 'all';
  String _selectedCurrency = 'USD';
  
  // Tab Controller
  late TabController _tabController;
  
  // Pagination
  int _currentPage = 0;
  int _rowsPerPage = 10;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
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
      
      setState(() {
        _sales = sales;
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
    final filteredExpenses = _getFilteredExpenses();
    
    // Calculate total sales
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

    // Calculate raw material cost
    _totalRawMaterialCost = _calculateRawMaterialCost(filteredSales);
    
    // Calculate gross profit
    _grossProfit = _totalSales - _totalRawMaterialCost;
    _profitMargin = _totalSales > 0 ? (_grossProfit / _totalSales) * 100 : 0;
    
    // Calculate daily expenses
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
    
    // Calculate net profit
    _netProfit = _grossProfit - _totalExpenses;
    _netProfitMargin = _totalSales > 0 ? (_netProfit / _totalSales) * 100 : 0;
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

  List<Map<String, dynamic>> _getFilteredSales() {
    final now = DateTime.now();
    
    return _sales.where((sale) {
      if (sale['is_back_returned'] == 1 || sale['is_back_returned']?.toString() == '1') {
        return false;
      }
      
      if (_filterPeriod == 'all') return true;
      
      final dateStr = sale['date_en']?.toString() ?? '';
      if (dateStr.isEmpty) return true;
      
      try {
        final parts = dateStr.split('-');
        if (parts.length != 3) return true;
        final year = int.tryParse(parts[0]) ?? 0;
        final month = int.tryParse(parts[1]) ?? 0;
        final day = int.tryParse(parts[2]) ?? 0;
        final saleDate = DateTime(year, month, day);
        
        switch (_filterPeriod) {
          case 'today':
            return saleDate.year == now.year && 
                   saleDate.month == now.month && 
                   saleDate.day == now.day;
          case 'week':
            final weekAgo = now.subtract(const Duration(days: 7));
            return saleDate.isAfter(weekAgo);
          case 'month':
            return saleDate.year == now.year && 
                   saleDate.month == now.month;
          case 'year':
            return saleDate.year == now.year;
          default:
            return true;
        }
      } catch (_) {
        return true;
      }
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredExpenses() {
    final now = DateTime.now();
    
    return _dailyExpenses.where((expense) {
      if (_filterPeriod == 'all') return true;
      
      final dateStr = expense['date_en']?.toString() ?? '';
      if (dateStr.isEmpty) return true;
      
      try {
        final parts = dateStr.split('-');
        if (parts.length != 3) return true;
        final year = int.tryParse(parts[0]) ?? 0;
        final month = int.tryParse(parts[1]) ?? 0;
        final day = int.tryParse(parts[2]) ?? 0;
        final expenseDate = DateTime(year, month, day);
        
        switch (_filterPeriod) {
          case 'today':
            return expenseDate.year == now.year && 
                   expenseDate.month == now.month && 
                   expenseDate.day == now.day;
          case 'week':
            final weekAgo = now.subtract(const Duration(days: 7));
            return expenseDate.isAfter(weekAgo);
          case 'month':
            return expenseDate.year == now.year && 
                   expenseDate.month == now.month;
          case 'year':
            return expenseDate.year == now.year;
          default:
            return true;
        }
      } catch (_) {
        return true;
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

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildHeader() {
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
                  'محاسبه سود ناخالص و خالص',
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
    final periods = [
      {'key': 'all', 'label': 'همه'},
      {'key': 'today', 'label': 'امروز'},
      {'key': 'week', 'label': 'هفته'},
      {'key': 'month', 'label': 'ماه'},
      {'key': 'year', 'label': 'سال'},
    ];

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
          const Text('دوره: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ...periods.map((period) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: FilterChip(
              label: Text(period['label']!, style: TextStyle(
                color: _filterPeriod == period['key'] ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              )),
              selected: _filterPeriod == period['key'],
              onSelected: (_) => setState(() {
                _filterPeriod = period['key']!;
                _calculateIncomes();
              }),
              selectedColor: const Color(0xFFCB001D),
              backgroundColor: Colors.grey.shade100,
              checkmarkColor: Colors.white,
            ),
          )).toList(),
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
                icon: Icon(Icons.arrow_drop_down, color: const Color(0xFFCB001D), size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFCB001D).withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_sales.length} فروش',
              style: const TextStyle(fontSize: 11, color: Color(0xFFCB001D), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
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

  // ============ GROSS PROFIT VIEW ============
  Widget _buildGrossProfitView() {
    final isProfit = _grossProfit >= 0;
    final profitColor = isProfit ? Colors.green.shade700 : Colors.red.shade700;

    return Column(
      children: [
        _buildGrossProfitCards(),
        const SizedBox(height: 12),
        _buildProfitSummary(isProfit, profitColor, _grossProfit, _profitMargin, _totalSales, _totalRawMaterialCost, 'سود ناخالص', 'هزینه مواد خام'),
        const SizedBox(height: 12),
        Expanded(
          child: _buildSalesTable('فروش‌ها'),
        ),
      ],
    );
  }

  Widget _buildGrossProfitCards() {
    return Row(
      children: [
        _buildStatCard('کل فروش', _formatCurrency(_totalSales), Icons.trending_up_rounded, Colors.blue.shade700, 'مجموع فروش'),
        const SizedBox(width: 12),
        _buildStatCard('هزینه مواد خام', _formatCurrency(_totalRawMaterialCost), Icons.warehouse_outlined, Colors.orange.shade700, 'قیمت تمام شده'),
        const SizedBox(width: 12),
        _buildStatCard('سود ناخالص', _formatCurrency(_grossProfit), Icons.account_balance_rounded, 
            _grossProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700, 
            '${_profitMargin.toStringAsFixed(1)}% حاشیه سود'),
      ],
    );
  }

  // ============ NET PROFIT VIEW ============
  Widget _buildNetProfitView() {
    final isProfit = _netProfit >= 0;
    final profitColor = isProfit ? Colors.green.shade700 : Colors.red.shade700;

    return Column(
      children: [
        _buildNetProfitCards(),
        const SizedBox(height: 12),
        _buildProfitSummary(isProfit, profitColor, _netProfit, _netProfitMargin, _totalSales, _totalExpenses, 'سود خالص', 'مصارف روزانه'),
        const SizedBox(height: 12),
        Expanded(
          child: _buildExpensesTable(),
        ),
      ],
    );
  }

  Widget _buildNetProfitCards() {
    return Row(
      children: [
        _buildStatCard('سود ناخالص', _formatCurrency(_grossProfit), Icons.trending_up_rounded, 
            _grossProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700, 'قبل از کسر مصارف'),
        const SizedBox(width: 12),
        _buildStatCard('مصارف روزانه', _formatCurrency(_totalExpenses), Icons.account_balance_wallet_outlined, Colors.orange.shade700, 'مجموع مصارف'),
        const SizedBox(width: 12),
        _buildStatCard('سود خالص', _formatCurrency(_netProfit), Icons.account_balance_rounded, 
            _netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700, 
            '${_netProfitMargin.toStringAsFixed(1)}% حاشیه سود خالص'),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
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

  Widget _buildProfitSummary(bool isProfit, Color profitColor, double profit, double margin, double total, double cost, String profitLabel, String costLabel) {
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

  Widget _buildSalesTable(String title) {
    final filteredSales = _getFilteredSales();
    final totalPages = (filteredSales.length / _rowsPerPage).ceil();
    final start = (_currentPage * _rowsPerPage).clamp(0, filteredSales.length);
    final paged = filteredSales.skip(start).take(_rowsPerPage).toList();

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
                const Expanded(flex: 1, child: Text('شماره', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 2, child: Text('مشتری', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 2, child: Text('محصول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
                const Expanded(flex: 1, child: Text('فروش', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
                const Expanded(flex: 1, child: Text('تاریخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center)),
              ],
            ),
          ),
          Expanded(
            child: paged.isEmpty
                ? const Center(child: Text('هیچ فروشی یافت نشد', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: paged.length,
                    itemBuilder: (context, index) {
                      final sale = paged[index];
                      final saleAmount = double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
                          color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: Text(sale['invoice_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                            Expanded(flex: 2, child: Text(sale['customer_name']?.toString() ?? '-', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            Expanded(flex: 2, child: Text(sale['product_name']?.toString() ?? '-', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            Expanded(flex: 1, child: Text(_formatCurrency(saleAmount), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue), textAlign: TextAlign.center)),
                            Expanded(flex: 1, child: Text(sale['date']?.toString() ?? '-', style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _buildPagination(filteredSales.length, totalPages),
        ],
      ),
    );
  }

  Widget _buildExpensesTable() {
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
                    icon: Icon(Icons.arrow_drop_down, color: const Color(0xFFCB001D), size: 16),
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
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  final DatabaseHelper _db = DatabaseHelper();

  // Dashboard Data
  Map<String, dynamic> dashboardData = {};
  List<Map<String, dynamic>> rawMaterials = [];
  List<Map<String, dynamic>> salesInvoices = [];
  List<Map<String, dynamic>> producedProducts = [];
  List<Map<String, dynamic>> sellLoans = [];
  List<Map<String, dynamic>> supplierLoans = [];
  List<Map<String, dynamic>> capitalAssets = [];
  List<Map<String, dynamic>> sarafiTransactions = [];
  List<Map<String, dynamic>> wasteRecords = [];
  List<Map<String, dynamic>> dailyExpenses = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> users = [];

  // Helper to check if unit is weight-based
  bool _isWeightUnit(String unit) {
    return unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg' || 
           unit == 'تن' || unit == 'ton' || unit == 'Ton';
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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _db.getRawMaterials(),
        _db.getSalesInvoices(),
        _db.getProducedProducts(),
        _db.getSellLoans(),
        _db.getSupplierLoans(),
        _db.getSuppliers(),
        _db.getCustomers(),
        _db.getCapitalAssets(),
        _db.getSarafiTransactions(),
        _db.getWasteRecords(),
        _db.getDailyExpenses(),
        _db.getUsers(),
      ]);

      rawMaterials = results[0] as List<Map<String, dynamic>>;
      salesInvoices = results[1] as List<Map<String, dynamic>>;
      producedProducts = results[2] as List<Map<String, dynamic>>;
      sellLoans = results[3] as List<Map<String, dynamic>>;
      supplierLoans = results[4] as List<Map<String, dynamic>>;
      suppliers = results[5] as List<Map<String, dynamic>>;
      customers = results[6] as List<Map<String, dynamic>>;
      capitalAssets = results[7] as List<Map<String, dynamic>>;
      sarafiTransactions = results[8] as List<Map<String, dynamic>>;
      wasteRecords = results[9] as List<Map<String, dynamic>>;
      dailyExpenses = results[10] as List<Map<String, dynamic>>;
      users = results[11] as List<Map<String, dynamic>>;

      _calculateStatistics();
    } catch (e) {
      print('❌ Error loading dashboard data: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorLoadingData}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateStatistics() {
    // ============ RAW MATERIALS STATS ============
    double totalWeightTON = 0;
    double totalRawMaterialCostAFN = 0;
    double totalRawMaterialCostUSD = 0;
    Map<String, double> materialTypesTON = {};
    
    for (var material in rawMaterials) {
      double weight = double.tryParse(material['gross_weight']?.toString() ?? '0') ?? 0;
      String unit = material['unit']?.toString()?.toLowerCase() ?? 'kg';
      String type = material['material_type']?.toString() ?? 'سایر';
      double cost = double.tryParse(material['final_price']?.toString() ?? '0') ?? 0;
      String currency = material['currency']?.toString()?.toUpperCase() ?? 'AFN';
      
      if (currency == 'USD') {
        totalRawMaterialCostUSD += cost;
      } else {
        totalRawMaterialCostAFN += cost;
      }
      
      double weightInTons = weight;
      if (unit == 'kg' || unit == 'کیلوگرم' || unit == 'kilogram') {
        weightInTons = weight / 1000;
      }
      totalWeightTON += weightInTons;
      materialTypesTON[type] = (materialTypesTON[type] ?? 0) + weightInTons;
    }

    // ============ SALES STATS ============
    double totalSalesAmountAFN = 0;
    double totalSalesAmountUSD = 0;
    double totalSalesPaidAFN = 0;
    double totalSalesPaidUSD = 0;
    double totalSalesRemainingAFN = 0;
    double totalSalesRemainingUSD = 0;
    int totalSalesCount = salesInvoices.length;
    int returnedSalesCount = salesInvoices.where((s) => s['is_back_returned'] == 1).length;

    double totalSalesWeightTON = 0;
    for (var sale in salesInvoices) {
      double weight = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
      String unit = sale['unit']?.toString()?.toLowerCase() ?? 'kg';
      totalSalesWeightTON += _convertToTons(unit, weight);
      
      double finalPrice = double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;
      String currency = sale['currency']?.toString()?.toUpperCase() ?? 'AFN';
      
      if (currency == 'USD') {
        totalSalesAmountUSD += finalPrice;
        totalSalesPaidUSD += double.tryParse(sale['paid_amount']?.toString() ?? '0') ?? 0;
        totalSalesRemainingUSD += double.tryParse(sale['remaining_amount']?.toString() ?? '0') ?? 0;
      } else {
        totalSalesAmountAFN += finalPrice;
        totalSalesPaidAFN += double.tryParse(sale['paid_amount']?.toString() ?? '0') ?? 0;
        totalSalesRemainingAFN += double.tryParse(sale['remaining_amount']?.toString() ?? '0') ?? 0;
      }
    }

    Map<String, double> salesByDate = {};
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime date = now.subtract(Duration(days: i));
      String key = DateFormat('yyyy-MM-dd').format(date);
      salesByDate[key] = 0;
    }

    for (var sale in salesInvoices) {
      double finalPrice = double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;
      String dateStr = sale['date_en']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        try {
          DateTime date = DateTime.parse(dateStr);
          String key = DateFormat('yyyy-MM-dd').format(date);
          if (salesByDate.containsKey(key)) {
            salesByDate[key] = (salesByDate[key] ?? 0) + finalPrice;
          }
        } catch (e) {}
      }
    }

    // ============ PRODUCTION STATS ============
    int totalProduced = producedProducts.length;
    int producedSold = producedProducts.where((p) => p['is_sold'] == 1).length;
    
    double productionWeightTON = 0;
    for (var product in producedProducts) {
      double weight = double.tryParse(product['weight']?.toString() ?? '0') ?? 0;
      String unit = product['unit']?.toString()?.toLowerCase() ?? 'kg';
      productionWeightTON += _convertToTons(unit, weight);
    }

    // ============ CUSTOMER LOANS STATS ============
    double totalCustomerLoansUSD = 0;
    double totalCustomerLoansAFN = 0;
    double totalCustomerLoansPaidUSD = 0;
    double totalCustomerLoansPaidAFN = 0;
    double totalCustomerLoansRemainingUSD = 0;
    double totalCustomerLoansRemainingAFN = 0;
    int customerLoanCount = 0;

    for (var loan in sellLoans) {
      double totalAmount = double.tryParse(loan['total_amount']?.toString() ?? '0') ?? 0;
      String currency = loan['currency']?.toString()?.toUpperCase() ?? 'AFN';
      
      customerLoanCount++;
      if (currency == 'USD') {
        totalCustomerLoansUSD += totalAmount;
        totalCustomerLoansPaidUSD += double.tryParse(loan['paid_amount']?.toString() ?? '0') ?? 0;
        totalCustomerLoansRemainingUSD += double.tryParse(loan['remaining_amount']?.toString() ?? '0') ?? 0;
      } else {
        totalCustomerLoansAFN += totalAmount;
        totalCustomerLoansPaidAFN += double.tryParse(loan['paid_amount']?.toString() ?? '0') ?? 0;
        totalCustomerLoansRemainingAFN += double.tryParse(loan['remaining_amount']?.toString() ?? '0') ?? 0;
      }
    }

    // ============ SUPPLIER LOANS STATS ============
    double totalSupplierLoansUSD = 0;
    double totalSupplierLoansAFN = 0;
    double totalSupplierLoansPaidUSD = 0;
    double totalSupplierLoansPaidAFN = 0;
    double totalSupplierLoansRemainingUSD = 0;
    double totalSupplierLoansRemainingAFN = 0;
    int supplierLoanCount = 0;

    for (var loan in supplierLoans) {
      double totalAmount = double.tryParse(loan['total_amount']?.toString() ?? '0') ?? 0;
      String currency = loan['currency']?.toString()?.toUpperCase() ?? 'AFN';
      
      supplierLoanCount++;
      if (currency == 'USD') {
        totalSupplierLoansUSD += totalAmount;
        totalSupplierLoansPaidUSD += double.tryParse(loan['paid_amount']?.toString() ?? '0') ?? 0;
        totalSupplierLoansRemainingUSD += double.tryParse(loan['remaining_amount']?.toString() ?? '0') ?? 0;
      } else {
        totalSupplierLoansAFN += totalAmount;
        totalSupplierLoansPaidAFN += double.tryParse(loan['paid_amount']?.toString() ?? '0') ?? 0;
        totalSupplierLoansRemainingAFN += double.tryParse(loan['remaining_amount']?.toString() ?? '0') ?? 0;
      }
    }

    // ============ CAPITAL STATS ============
    double totalCapitalAFN = 0;
    double totalCapitalUSD = 0;
    for (var asset in capitalAssets) {
      double amount = double.tryParse(asset['current_balance']?.toString() ?? '0') ?? 0;
      String currency = asset['currency']?.toString()?.toUpperCase() ?? 'AFN';
      if (currency == 'USD') {
        totalCapitalUSD += amount;
      } else {
        totalCapitalAFN += amount;
      }
    }

    // ============ SARAFI STATS ============
    double totalSarafiUSD = 0;
    double totalSarafiAFN = 0;
    int sarafiDeposits = 0;
    int sarafiWithdrawals = 0;
    
    for (var transaction in sarafiTransactions) {
      String type = transaction['transaction_type']?.toString() ?? 'deposit';
      double usdAmount = double.tryParse(transaction['amount_usd']?.toString() ?? '0') ?? 0;
      double afnAmount = double.tryParse(transaction['amount_afn']?.toString() ?? '0') ?? 0;
      
      if (type == 'deposit' || type == 'افزایش' || type == 'واریز') {
        sarafiDeposits++;
        totalSarafiUSD += usdAmount;
        totalSarafiAFN += afnAmount;
      } else {
        sarafiWithdrawals++;
        totalSarafiUSD -= usdAmount;
        totalSarafiAFN -= afnAmount;
      }
    }

    // ============ WASTE STATS ============
    double totalWasteValueAFN = 0;
    double totalWasteValueUSD = 0;
    double totalWasteWeightTON = 0;
    for (var waste in wasteRecords) {
      double value = double.tryParse(waste['value']?.toString() ?? '0') ?? 0;
      String currency = waste['currency']?.toString()?.toUpperCase() ?? 'AFN';
      if (currency == 'USD') {
        totalWasteValueUSD += value;
      } else {
        totalWasteValueAFN += value;
      }
      double weight = double.tryParse(waste['weight']?.toString() ?? '0') ?? 0;
      totalWasteWeightTON += weight / 1000;
    }

    // ============ EXPENSES STATS ============
    double totalExpensesAFN = 0;
    double totalExpensesUSD = 0;
    for (var expense in dailyExpenses) {
      double amount = double.tryParse(expense['price']?.toString() ?? '0') ?? 0;
      String currency = expense['currency']?.toString()?.toUpperCase() ?? 'AFN';
      if (currency == 'USD') {
        totalExpensesUSD += amount;
      } else {
        totalExpensesAFN += amount;
      }
    }

    dashboardData = {
      'rawMaterials': {
        'weightTON': totalWeightTON,
        'totalCostAFN': totalRawMaterialCostAFN,
        'totalCostUSD': totalRawMaterialCostUSD,
        'count': rawMaterials.length,
        'typesTON': materialTypesTON,
      },
      'sales': {
        'totalAmountAFN': totalSalesAmountAFN,
        'totalAmountUSD': totalSalesAmountUSD,
        'totalPaidAFN': totalSalesPaidAFN,
        'totalPaidUSD': totalSalesPaidUSD,
        'totalRemainingAFN': totalSalesRemainingAFN,
        'totalRemainingUSD': totalSalesRemainingUSD,
        'count': totalSalesCount,
        'returned': returnedSalesCount,
        'byDate': salesByDate,
        'weightTON': totalSalesWeightTON,
      },
      'production': {
        'total': totalProduced,
        'sold': producedSold,
        'available': totalProduced - producedSold,
        'weightTON': productionWeightTON,
      },
      'loans': {
        'customer': {
          'count': customerLoanCount,
          'totalUSD': totalCustomerLoansUSD,
          'totalAFN': totalCustomerLoansAFN,
          'paidUSD': totalCustomerLoansPaidUSD,
          'paidAFN': totalCustomerLoansPaidAFN,
          'remainingUSD': totalCustomerLoansRemainingUSD,
          'remainingAFN': totalCustomerLoansRemainingAFN,
        },
        'supplier': {
          'count': supplierLoanCount,
          'totalUSD': totalSupplierLoansUSD,
          'totalAFN': totalSupplierLoansAFN,
          'paidUSD': totalSupplierLoansPaidUSD,
          'paidAFN': totalSupplierLoansPaidAFN,
          'remainingUSD': totalSupplierLoansRemainingUSD,
          'remainingAFN': totalSupplierLoansRemainingAFN,
        },
      },
      'capital': {
        'totalAFN': totalCapitalAFN,
        'totalUSD': totalCapitalUSD,
        'assets': capitalAssets.length,
      },
      'sarafi': {
        'totalUSD': totalSarafiUSD,
        'totalAFN': totalSarafiAFN,
        'deposits': sarafiDeposits,
        'withdrawals': sarafiWithdrawals,
        'transactions': sarafiTransactions.length,
      },
      'waste': {
        'totalValueAFN': totalWasteValueAFN,
        'totalValueUSD': totalWasteValueUSD,
        'totalWeightTON': totalWasteWeightTON,
        'count': wasteRecords.length,
      },
      'expenses': {
        'totalAFN': totalExpensesAFN,
        'totalUSD': totalExpensesUSD,
        'count': dailyExpenses.length,
      },
      'customers': {
        'count': customers.length,
      },
      'suppliers': {
        'count': suppliers.length,
      },
      'users': {
        'count': users.length,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    final bool isEnglish = languageProvider.isEnglish;
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFCB001D),
                ),
              )
            : Column(
                crossAxisAlignment: isEnglish 
                    ? CrossAxisAlignment.start 
                    : CrossAxisAlignment.end,
                children: [
                  _buildHeader(l10n, languageProvider),
                  const SizedBox(height: 24),
                  _buildStatsRow1(l10n, languageProvider),
                  const SizedBox(height: 16),
                  _buildStatsRow2(l10n, languageProvider),
                  const SizedBox(height: 16),
                  _buildStatsRow3(l10n, languageProvider),
                  const SizedBox(height: 24),
                  _buildChartsRow(l10n, languageProvider),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, LanguageProvider languageProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: languageProvider.isEnglish 
              ? CrossAxisAlignment.start 
              : CrossAxisAlignment.end,
          children: [
            Text(
              l10n.dashboardTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.dashboardSubtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Text(
                '${users.length} ${l10n.activeUsers}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow1(AppLocalizations l10n, LanguageProvider languageProvider) {
    double ton = dashboardData['rawMaterials']?['weightTON'] ?? 0;
    
    double totalCostAFN = dashboardData['rawMaterials']?['totalCostAFN'] ?? 0;
    double totalCostUSD = dashboardData['rawMaterials']?['totalCostUSD'] ?? 0;
    
    double totalSalesAFN = dashboardData['sales']?['totalAmountAFN'] ?? 0;
    double totalSalesUSD = dashboardData['sales']?['totalAmountUSD'] ?? 0;
    double totalSalesPaidAFN = dashboardData['sales']?['totalPaidAFN'] ?? 0;
    double totalSalesPaidUSD = dashboardData['sales']?['totalPaidUSD'] ?? 0;
    double totalSalesRemainingAFN = dashboardData['sales']?['totalRemainingAFN'] ?? 0;
    double totalSalesRemainingUSD = dashboardData['sales']?['totalRemainingUSD'] ?? 0;
    
    double salesWeightTON = dashboardData['sales']?['weightTON'] ?? 0;
    
    String tonDisplay = '${_formatNumber(ton)} ${l10n.ton}';
    String salesWeightDisplay = '${_formatNumber(salesWeightTON)} ${l10n.ton}';

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: l10n.rawMaterials,
            afnValue: _formatCurrencyFull(totalCostAFN),
            usdValue: _formatCurrencyFull(totalCostUSD),
            subtitle: '${dashboardData['rawMaterials']?['count'] ?? 0} ${l10n.items} | وزن: $tonDisplay',
            icon: Icons.warehouse,
            color: const Color(0xFFCB001D),
            details: 'مواد خام',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: l10n.totalSales,
            afnValue: _formatCurrencyFull(totalSalesAFN),
            usdValue: _formatCurrencyFull(totalSalesUSD),
            subtitle: '${dashboardData['sales']?['count'] ?? 0} ${l10n.invoices} | وزن: $salesWeightDisplay',
            icon: Icons.attach_money,
            color: Colors.green,
            details: 'پرداخت: ${_formatCurrencyFull(totalSalesPaidAFN)} AFN | مانده: ${_formatCurrencyFull(totalSalesRemainingAFN)} AFN',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: l10n.productions,
            afnValue: '${dashboardData['production']?['total'] ?? 0}',
            usdValue: null,
            subtitle: '${dashboardData['production']?['sold'] ?? 0} ${l10n.sold}',
            icon: Icons.factory,
            color: Colors.orange,
            details: 'موجود: ${dashboardData['production']?['available'] ?? 0} | وزن: ${_formatNumber(dashboardData['production']?['weightTON'] ?? 0)} ${l10n.ton}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: l10n.returnedSales,
            afnValue: '${dashboardData['sales']?['returned'] ?? 0}',
            usdValue: null,
            subtitle: l10n.returnedInvoices,
            icon: Icons.undo,
            color: Colors.red,
            details: '${((dashboardData['sales']?['returned'] ?? 0) / (dashboardData['sales']?['count'] ?? 1) * 100).toStringAsFixed(1)}%',
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow2(AppLocalizations l10n, LanguageProvider languageProvider) {
    double customerTotalUSD = dashboardData['loans']?['customer']?['totalUSD'] ?? 0;
    double customerTotalAFN = dashboardData['loans']?['customer']?['totalAFN'] ?? 0;
    double customerRemainingUSD = dashboardData['loans']?['customer']?['remainingUSD'] ?? 0;
    double customerRemainingAFN = dashboardData['loans']?['customer']?['remainingAFN'] ?? 0;
    int customerCount = dashboardData['loans']?['customer']?['count'] ?? 0;
    
    double supplierTotalUSD = dashboardData['loans']?['supplier']?['totalUSD'] ?? 0;
    double supplierTotalAFN = dashboardData['loans']?['supplier']?['totalAFN'] ?? 0;
    double supplierRemainingUSD = dashboardData['loans']?['supplier']?['remainingUSD'] ?? 0;
    double supplierRemainingAFN = dashboardData['loans']?['supplier']?['remainingAFN'] ?? 0;
    int supplierCount = dashboardData['loans']?['supplier']?['count'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: '${l10n.customerLoans} (کل)',
            afnValue: _formatCurrencyFull(customerTotalAFN),
            usdValue: _formatCurrencyFull(customerTotalUSD),
            subtitle: '${customerCount} ${l10n.loans}',
            icon: Icons.people,
            color: Colors.purple,
            details: 'کل وام مشتریان',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '${l10n.customerLoans} (باقی)',
            afnValue: _formatCurrencyFull(customerRemainingAFN),
            usdValue: _formatCurrencyFull(customerRemainingUSD),
            subtitle: '${customerCount} ${l10n.loans}',
            icon: Icons.pending,
            color: Colors.purple,
            details: 'باقی‌مانده وام مشتریان',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '${l10n.supplierLoans} (کل)',
            afnValue: _formatCurrencyFull(supplierTotalAFN),
            usdValue: _formatCurrencyFull(supplierTotalUSD),
            subtitle: '${supplierCount} ${l10n.loans}',
            icon: Icons.business,
            color: Colors.teal,
            details: 'کل وام تأمین‌کنندگان',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '${l10n.supplierLoans} (باقی)',
            afnValue: _formatCurrencyFull(supplierRemainingAFN),
            usdValue: _formatCurrencyFull(supplierRemainingUSD),
            subtitle: '${supplierCount} ${l10n.loans}',
            icon: Icons.pending,
            color: Colors.teal,
            details: 'باقی‌مانده وام تأمین‌کنندگان',
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow3(AppLocalizations l10n, LanguageProvider languageProvider) {
    double sarafiUSD = dashboardData['sarafi']?['totalUSD'] ?? 0;
    double sarafiAFN = dashboardData['sarafi']?['totalAFN'] ?? 0;
    
    double wasteValueAFN = dashboardData['waste']?['totalValueAFN'] ?? 0;
    double wasteValueUSD = dashboardData['waste']?['totalValueUSD'] ?? 0;
    double wasteWeightTON = dashboardData['waste']?['totalWeightTON'] ?? 0;
    
    double expensesAFN = dashboardData['expenses']?['totalAFN'] ?? 0;
    double expensesUSD = dashboardData['expenses']?['totalUSD'] ?? 0;
    
    double capitalAFN = dashboardData['capital']?['totalAFN'] ?? 0;
    double capitalUSD = dashboardData['capital']?['totalUSD'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: l10n.sarafi,
            afnValue: _formatCurrencyFull(sarafiAFN),
            usdValue: _formatCurrencyFull(sarafiUSD),
            subtitle: '${dashboardData['sarafi']?['deposits'] ?? 0} واریز | ${dashboardData['sarafi']?['withdrawals'] ?? 0} برداشت',
            icon: Icons.currency_exchange,
            color: Colors.amber,
            details: '${dashboardData['sarafi']?['transactions'] ?? 0} تراکنش',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: l10n.wastes,
            afnValue: _formatCurrencyFull(wasteValueAFN),
            usdValue: _formatCurrencyFull(wasteValueUSD),
            subtitle: '${_formatNumber(wasteWeightTON)} ${l10n.ton}',
            icon: Icons.delete,
            color: Colors.red,
            details: '${dashboardData['waste']?['count'] ?? 0} مورد ضایعات',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: l10n.dailyExpenses,
            afnValue: _formatCurrencyFull(expensesAFN),
            usdValue: _formatCurrencyFull(expensesUSD),
            subtitle: '${dashboardData['expenses']?['count'] ?? 0} مورد',
            icon: Icons.receipt,
            color: Colors.grey,
            details: 'مصارف روزانه',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: l10n.capital,
            afnValue: _formatCurrencyFull(capitalAFN),
            usdValue: _formatCurrencyFull(capitalUSD),
            subtitle: '${dashboardData['capital']?['assets'] ?? 0} دارایی',
            icon: Icons.account_balance,
            color: Colors.blue,
            details: 'سرمایه کل',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String afnValue,
    String? usdValue,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? details,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // AFN Value - Main (Big)
          Text(
            '$afnValue AFN',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          // USD Value - Below AFN (Smaller)
          if (usdValue != null) ...[
            const SizedBox(height: 2),
            Text(
              '$usdValue USD',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (details != null) ...[
            const SizedBox(height: 2),
            Text(
              details,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartsRow(AppLocalizations l10n, LanguageProvider languageProvider) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildSalesChart(l10n, languageProvider),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMaterialDistributionChart(l10n, languageProvider),
        ),
      ],
    );
  }

  Widget _buildSalesChart(AppLocalizations l10n, LanguageProvider languageProvider) {
    var salesByDate = dashboardData['sales']?['byDate'] as Map<String, double>? ?? {};
    
    List<FlSpot> spots = [];
    int index = 0;
    salesByDate.forEach((key, value) {
      spots.add(FlSpot(index.toDouble(), value));
      index++;
    });

    List<String> dateLabels = salesByDate.keys.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFCB001D).withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📈 ${l10n.salesTrend}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                l10n.viewAll,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFCB001D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: spots.length > 1
                ? LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 1000,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return const FlLine(
                            color: Colors.grey,
                            strokeWidth: 0.5,
                            dashArray: [5, 5],
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1000,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatCurrencyFull(value),
                                style: const TextStyle(fontSize: 8),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < dateLabels.length) {
                                String label = dateLabels[index];
                                try {
                                  DateTime date = DateTime.parse(label);
                                  return Text(
                                    '${date.day}/${date.month}',
                                    style: const TextStyle(fontSize: 8),
                                  );
                                } catch (e) {
                                  return const Text('', style: TextStyle(fontSize: 8));
                                }
                              }
                              return const Text('', style: TextStyle(fontSize: 8));
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                          left: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFFCB001D),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFFCB001D).withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Text(
                      l10n.noDataToDisplay,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialDistributionChart(AppLocalizations l10n, LanguageProvider languageProvider) {
    var typesTON = dashboardData['rawMaterials']?['typesTON'] as Map<String, double>? ?? {};
    
    List<PieChartSectionData> sections = [];
    List<Color> colors = [
      const Color(0xFFCB001D), 
      Colors.blue, 
      Colors.orange, 
      Colors.purple, 
      Colors.teal, 
      Colors.green,
      Colors.red,
      Colors.amber,
    ];
    
    int colorIndex = 0;
    double totalWeight = 0;
    typesTON.forEach((key, value) {
      totalWeight += value;
    });
    
    typesTON.forEach((type, weight) {
      if (weight > 0) {
        double percentage = totalWeight > 0 ? (weight / totalWeight * 100) : 0;
        sections.add(
          PieChartSectionData(
            value: weight,
            title: percentage > 5 ? '${percentage.toStringAsFixed(1)}%' : '',
            color: colors[colorIndex % colors.length],
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        colorIndex++;
      }
    });

    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          value: 1,
          title: l10n.noData,
          color: Colors.grey,
          radius: 50,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFCB001D).withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 ${l10n.materialDistribution} (${l10n.ton})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 20,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                ),
              ),
            ),
          ),
          if (typesTON.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: typesTON.keys.toList().asMap().entries.map((entry) {
                int idx = entry.key;
                String type = entry.value;
                double weight = typesTON[type] ?? 0;
                double percentage = totalWeight > 0 ? (weight / totalWeight * 100) : 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors[idx % colors.length].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$type ${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 9,
                      color: colors[idx % colors.length],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCurrencyFull(dynamic value) {
    if (value == null) return '۰';
    double number = double.tryParse(value.toString()) ?? 0;
    return NumberFormat('#,##0').format(number);
  }
  
  String _formatNumber(dynamic value) {
    if (value == null) return '۰';
    double number = double.tryParse(value.toString()) ?? 0;
    if (number == 0) return '۰';
    return NumberFormat('#,##0.0').format(number);
  }
}
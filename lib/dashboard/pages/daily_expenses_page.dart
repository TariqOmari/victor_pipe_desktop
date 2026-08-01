import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class DailyExpensesPage extends StatefulWidget {
  const DailyExpensesPage({super.key});

  @override
  State<DailyExpensesPage> createState() => _DailyExpensesPageState();
}

class _DailyExpensesPageState extends State<DailyExpensesPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  final List<Map<String, dynamic>> _expensesData = [];

  String _searchQuery = '';
  String _selectedCategory = 'همه';
  DateTime? _selectedDate;
  String _selectedCurrency = 'همه';

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController();
  final TextEditingController _exchangeRateController = TextEditingController();
  final TextEditingController _usdEquivalentController = TextEditingController();

  final List<String> _categories = [
    'همه',
    'سوخت',
    'مواد اولیه',
    'حقوق کارگران',
    'تعمیرات',
    'حمل و نقل',
    'سایر',
  ];

  final List<String> _currencies = [
    'همه',
    'افغانی',
    'دالر',
    'یورو',
  ];

  @override
  void dispose() {
    _dateController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _exchangeRateController.dispose();
    _usdEquivalentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getDailyExpenses();
      if (!mounted) return;
      setState(() {
        _expensesData.clear();
        for (final r in list) {
          _expensesData.add({
            'id': r['id'],
            'invoiceNumber': r['invoice_number'],
            'date': r['date'],
            'date_en': r['date_en'],
            'category': r['category'],
            'description': r['description'],
            'price': (r['price'] is int) ? r['price'] : (r['price'] is double ? (r['price'] as double).round() : int.tryParse(r['price']?.toString() ?? '0') ?? 0),
            'currency': r['currency'],
            'exchangeRate': r['exchange_rate'],
            'usdEquivalent': (r['usd_equivalent'] is int) ? r['usd_equivalent'] : (r['usd_equivalent'] is double ? (r['usd_equivalent'] as double).round() : int.tryParse(r['usd_equivalent']?.toString() ?? '0') ?? 0),
          });
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackBar(l10n.errorLoadingExpenses, Colors.red);
    }
  }

  Future<void> _addExpense() async {
    final l10n = AppLocalizations.of(context)!;
    _dateController.clear();
    _categoryController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _currencyController.clear();
    _exchangeRateController.clear();
    _usdEquivalentController.clear();
    final nextInvoice = await _db.getNextSalesInvoiceNumber();
    final invoiceShown = nextInvoice.toString().padLeft(5, '0');
    String? selectedEnglishDate;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              l10n.addNewExpense,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF1A1A1A),
              ),
            ),
            content: SizedBox(
              width: 650,
              height: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${l10n.invoiceNumberLabel}: $invoiceShown', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: l10n.persianDate,
                        suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 18),
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          String persianDate = PersianDateConverter.gregorianToJalali(picked);
                          String englishDate = PersianDateConverter.getEnglishDate(picked);
                          setDialogState(() {
                            _dateController.text = persianDate;
                            selectedEnglishDate = englishDate;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _categoryController,
                      label: l10n.category,
                      icon: Icons.category_outlined,
                      hint: l10n.categoryHint,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descriptionController,
                      label: l10n.description,
                      icon: Icons.description_outlined,
                      hint: l10n.descriptionHint,
                      maxLines: 2,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _priceController,
                      label: l10n.price,
                      icon: Icons.money_outlined,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            controller: _currencyController,
                            label: l10n.currency,
                            icon: Icons.currency_exchange_outlined,
                            items: ['افغانی', 'دالر', 'یورو'],
                            l10n: l10n,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _exchangeRateController,
                            label: l10n.exchangeRate,
                            icon: Icons.trending_up_outlined,
                            hint: '0.011',
                            keyboardType: TextInputType.number,
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _usdEquivalentController,
                      label: l10n.usdEquivalent,
                      icon: Icons.attach_money_outlined,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      l10n: l10n,
                    ),
                  ],
                ),
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_dateController.text.isEmpty) {
                    _showSnackBar(l10n.pleaseEnterDate, Colors.red);
                    return;
                  }
                  if (_priceController.text.isEmpty) {
                    _showSnackBar(l10n.pleaseEnterPrice, Colors.red);
                    return;
                  }

                  Navigator.of(context).pop();
                  final insertPayload = {
                    'invoice_number': invoiceShown,
                    'date': _dateController.text,
                    'date_en': selectedEnglishDate ?? PersianDateConverter.getEnglishDate(DateTime.now()),
                    'category': _categoryController.text.isNotEmpty ? _categoryController.text : 'سایر',
                    'description': _descriptionController.text,
                    'price': double.tryParse(_priceController.text) ?? 0,
                    'currency': _currencyController.text.isNotEmpty ? _currencyController.text : 'افغانی',
                    'exchange_rate': double.tryParse(_exchangeRateController.text) ?? 0.011,
                  };
                  final price = double.tryParse(_priceController.text) ?? 0;
                  final rate = double.tryParse(_exchangeRateController.text) ?? 0.0;
                  insertPayload['usd_equivalent'] = (price * rate).round();

                  final id = await _db.insertDailyExpense(insertPayload);
                  if (id != -1) {
                    await _loadExpenses();
                    _showSnackBar(l10n.expenseAddedSuccess, Colors.green);
                  } else {
                    _showSnackBar(l10n.errorAddingExpense, Colors.red);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCB001D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.addExpense),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editExpense(Map<String, dynamic> expense) {
    final l10n = AppLocalizations.of(context)!;
    _dateController.text = expense['date'];
    _categoryController.text = expense['category'] ?? '';
    _descriptionController.text = expense['description'] ?? '';
    _priceController.text = expense['price'].toString();
    _currencyController.text = expense['currency'] ?? '';
    _exchangeRateController.text = expense['exchangeRate'].toString();
    _usdEquivalentController.text = expense['usdEquivalent'].toString();

    String? selectedEnglishDate = expense['date_en'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.editExpense,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: SizedBox(
          width: 650,
          height: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: l10n.persianDate,
                    suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 18),
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      String persianDate = PersianDateConverter.gregorianToJalali(picked);
                      String englishDate = PersianDateConverter.getEnglishDate(picked);
                      setState(() {
                        _dateController.text = persianDate;
                        selectedEnglishDate = englishDate;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _categoryController,
                  label: l10n.category,
                  icon: Icons.category_outlined,
                  hint: l10n.categoryHint,
                  l10n: l10n,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _descriptionController,
                  label: l10n.description,
                  icon: Icons.description_outlined,
                  maxLines: 2,
                  l10n: l10n,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _priceController,
                  label: l10n.price,
                  icon: Icons.money_outlined,
                  keyboardType: TextInputType.number,
                  l10n: l10n,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        controller: _currencyController,
                        label: l10n.currency,
                        icon: Icons.currency_exchange_outlined,
                        items: ['افغانی', 'دالر', 'یورو'],
                        l10n: l10n,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _exchangeRateController,
                        label: l10n.exchangeRate,
                        icon: Icons.trending_up_outlined,
                        keyboardType: TextInputType.number,
                        l10n: l10n,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _usdEquivalentController,
                  label: l10n.usdEquivalent,
                  icon: Icons.attach_money_outlined,
                  keyboardType: TextInputType.number,
                  l10n: l10n,
                ),
              ],
            ),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_dateController.text.isEmpty) {
                _showSnackBar(l10n.pleaseEnterDate, Colors.red);
                return;
              }

              final payload = {
                'date': _dateController.text,
                'date_en': selectedEnglishDate ?? PersianDateConverter.getEnglishDate(DateTime.now()),
                'category': _categoryController.text.isNotEmpty ? _categoryController.text : 'سایر',
                'description': _descriptionController.text,
                'price': double.tryParse(_priceController.text) ?? 0,
                'currency': _currencyController.text.isNotEmpty ? _currencyController.text : 'افغانی',
                'exchange_rate': double.tryParse(_exchangeRateController.text) ?? 0.011,
              };
              final price = double.tryParse(_priceController.text) ?? 0;
              final rate = double.tryParse(_exchangeRateController.text) ?? 0.0;
              payload['usd_equivalent'] = (price * rate).round();

              final res = await _db.updateDailyExpense(expense['id'] as int, payload);
              if (res != -1) {
                await _loadExpenses();
                Navigator.pop(context);
                _showSnackBar(l10n.expenseUpdatedSuccess, Colors.blue);
              } else {
                _showSnackBar(l10n.errorUpdatingExpense, Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB001D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l10n.saveChanges),
          ),
        ],
      ),
    );
  }

  void _deleteExpense(Map<String, dynamic> expense) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.deleteExpense,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          '${l10n.deleteConfirmation} "${expense['invoiceNumber']}"؟',
          style: const TextStyle(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _db.deleteDailyExpense(expense['id'] as int).then((res) async {
                if (res != -1) {
                  await _loadExpenses();
                  _showSnackBar(l10n.expenseDeletedSuccess, Colors.red);
                } else {
                  _showSnackBar(l10n.errorDeletingExpense, Colors.red);
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _printPage() {
    final l10n = AppLocalizations.of(context)!;
    _showSnackBar(l10n.preparingPrint, Colors.blue);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppLocalizations l10n,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: const Color(0xFFCB001D), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> items,
    required AppLocalizations l10n,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFCB001D), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: controller.text.isNotEmpty ? controller.text : null,
                hint: Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                isExpanded: true,
                items: items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: (value) {
                  controller.text = value ?? '';
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final filteredData = _expensesData.where((expense) {
      final matchesSearch = (expense['invoiceNumber'] ?? '').toString().contains(_searchQuery) ||
        (expense['description'] ?? '').toString().contains(_searchQuery) ||
        (expense['category'] ?? '').toString().contains(_searchQuery);
      final matchesCategory = _selectedCategory == 'همه' ||
          expense['category'] == _selectedCategory;
      final matchesCurrency = _selectedCurrency == 'همه' ||
          expense['currency'] == _selectedCurrency;
      return matchesSearch && matchesCategory && matchesCurrency;
    }).toList();

    final totalPrice = filteredData.fold<int>(
      0,
      (sum, expense) => sum + (expense['price'] as int),
    );
    final totalUsd = filteredData.fold<int>(
      0,
      (sum, expense) => sum + (expense['usdEquivalent'] as int),
    );

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(totalPrice, totalUsd, l10n),
              const SizedBox(height: 24),
              _buildQuickStats(l10n),
              const SizedBox(height: 24),
              _buildFilterAndSearch(l10n),
              const SizedBox(height: 20),
              Expanded(child: _buildExpensesTable(filteredData, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int totalPrice, int totalUsd, AppLocalizations l10n) {
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
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFFCB001D),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dailyExpensesManagement,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${l10n.totalAmount}: ${totalPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} ${l10n.afghani}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB001D).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${l10n.usdEquivalent}: ${totalUsd.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} \$',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFCB001D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _printPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFCB001D),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: const BorderSide(color: Color(0xFFCB001D)),
                elevation: 0,
              ),
              icon: const Icon(Icons.print_outlined, size: 20),
              label: Text(
                l10n.print,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _showTodayInvoice(l10n),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A1A1A),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: Colors.grey.shade300),
                elevation: 0,
              ),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(l10n.todayInvoice),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _addExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                l10n.addNewExpense,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats(AppLocalizations l10n) {
    final totalExpenses = _expensesData.length;
    final totalAmount = _expensesData.fold<int>(
      0,
      (sum, expense) => sum + (expense['price'] as int),
    );
    final totalUsd = _expensesData.fold<int>(
      0,
      (sum, expense) => sum + (expense['usdEquivalent'] as int),
    );
    final todayExpenses = _expensesData.where(
      (e) => e['date'] == PersianDateConverter.getCurrentPersianDate(),
    ).length;

    return Row(
      children: [
        _buildStatCard(
          title: l10n.totalExpenses,
          value: totalExpenses.toString(),
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFFCB001D),
          subtitle: l10n.totalRecords,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: l10n.totalAmount,
          value: totalAmount.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          ),
          icon: Icons.money_outlined,
          color: Colors.blue.shade700,
          subtitle: l10n.afghani,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: l10n.usdEquivalent,
          value: totalUsd.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          ),
          icon: Icons.attach_money_outlined,
          color: Colors.green.shade700,
          subtitle: l10n.usd,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: l10n.todayExpenses,
          value: todayExpenses.toString(),
          icon: Icons.today_outlined,
          color: Colors.orange.shade700,
          subtitle: l10n.recordedToday,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndSearch(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: l10n.searchExpenses,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                  size: 22,
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
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterDropdown(
              value: _selectedCategory,
              items: _categories,
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
              label: l10n.category,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterDropdown(
              value: _selectedCurrency,
              items: _currencies,
              onChanged: (value) {
                setState(() => _selectedCurrency = value!);
              },
              label: l10n.currency,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildExpensesTable(List<Map<String, dynamic>> data, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 1, child: Text(l10n.persianDate, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.invoiceNumberLabel, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.englishDate, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.category, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text(l10n.description, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.price, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text(l10n.currency, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.exchangeRate, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text(l10n.usdEquivalent, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text(l10n.actions, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              ],
            ),
          ),
          Expanded(
            child: data.isEmpty
                ? Center(
                    child: Text(
                      l10n.noExpensesFound,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final expense = data[index];
                      return _buildTableRow(expense, l10n);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> expense, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              expense['date'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['invoiceNumber'] ?? '-',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['date_en'] ?? '-',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getCategoryColor(expense['category']).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                expense['category'] ?? 'سایر',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getCategoryColor(expense['category']),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              expense['description'] ?? '-',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF333333),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['price'].toString().replaceAllMapped(
                RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]},',
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['currency'] ?? 'افغانی',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['exchangeRate'].toString(),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                expense['usdEquivalent'].toString().replaceAllMapped(
                  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: Colors.green,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _editExpense(expense),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: Colors.grey.shade600,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _showSingleExpenseInvoice(expense),
                  icon: const Icon(Icons.receipt_outlined, color: Colors.blue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _deleteExpense(expense),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.grey.shade600,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Future<pw.Document> _buildExpenseInvoicePdf(List<Map<String, dynamic>> items, String title, AppLocalizations l10n) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final dateStr = PersianDateConverter.getCurrentPersianDate();
    final totalPrice = items.fold<double>(0, (s, e) => s + (double.tryParse(e['price']?.toString() ?? '0') ?? 0));
    final totalUsd = items.fold<double>(0, (s, e) => s + (double.tryParse(e['usdEquivalent']?.toString() ?? '0') ?? 0));

    final ttf = await _loadVazirFont();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: pw.TextStyle(font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('${l10n.date}: $dateStr', style: pw.TextStyle(font: ttf)),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: [l10n.invoiceNumberLabel, l10n.englishDate, l10n.category, l10n.description, l10n.price, l10n.currency, l10n.exchangeRate, l10n.usdEquivalent],
                  data: items.map((e) {
                    return [
                      e['invoiceNumber'] ?? '-',
                      e['date_en'] ?? '-',
                      e['category'] ?? '-',
                      e['description'] ?? '-',
                      (e['price'] ?? '').toString(),
                      e['currency'] ?? '-',
                      (e['exchangeRate'] ?? '').toString(),
                      (e['usdEquivalent'] ?? '').toString(),
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                  cellAlignment: pw.Alignment.centerRight,
                  border: pw.TableBorder.symmetric(outside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5), inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                pw.SizedBox(height: 12),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                  pw.Column(children: [
                    pw.Text('${l10n.totalAmount}: ${totalPrice.toStringAsFixed(0)}', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${l10n.usdEquivalent}: ${totalUsd.toStringAsFixed(0)}', style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                  ])
                ])
              ],
            ),
          ),
        ],
      ),
    );

    return doc;
  }

  Future<pw.Font> _loadVazirFont() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      return pw.Font.helvetica();
    }
  }

  Future<void> _showInvoiceDialogWithPdf(pw.Document doc, String filename, AppLocalizations l10n) async {
    final bytes = await doc.save();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.invoicePreview),
        content: Text(l10n.invoicePreviewMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Printing.layoutPdf(onLayout: (format) async => bytes);
            },
            child: Text(l10n.print),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Printing.sharePdf(bytes: bytes, filename: filename);
            },
            child: Text(l10n.savePdf),
          ),
        ],
      ),
    );
  }

  Future<void> _showTodayInvoice(AppLocalizations l10n) async {
    final today = PersianDateConverter.getCurrentPersianDate();
    final items = _expensesData.where((e) => e['date'] == today).toList();
    if (items.isEmpty) {
      _showSnackBar(l10n.noExpensesToday, Colors.grey);
      return;
    }
    final doc = await _buildExpenseInvoicePdf(items, l10n.todayExpensesList, l10n);
    await _showInvoiceDialogWithPdf(doc, 'daily_invoice_$today.pdf', l10n);
  }

  Future<void> _showSingleExpenseInvoice(Map<String, dynamic> expense) async {
    final l10n = AppLocalizations.of(context)!;
    final doc = await _buildExpenseInvoicePdf([expense], l10n.expenseInvoice, l10n);
    final inv = (expense['invoiceNumber'] ?? DateTime.now().millisecondsSinceEpoch.toString());
    await _showInvoiceDialogWithPdf(doc, 'expense_$inv.pdf', l10n);
  }
}
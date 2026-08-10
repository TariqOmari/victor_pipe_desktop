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

  final TextEditingController _registrationNumberController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController();
  final TextEditingController _exchangeRateController = TextEditingController();
  final TextEditingController _equivalentController = TextEditingController();

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
    _registrationNumberController.dispose();
    _dateController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _exchangeRateController.dispose();
    _equivalentController.dispose();
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
            'registrationNumber': r['registration_number'] ?? '-',
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
    _registrationNumberController.clear();
    _dateController.clear();
    _categoryController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _currencyController.clear();
    _exchangeRateController.clear();
    _equivalentController.clear();
    
    String? selectedEnglishDate;
    String selectedCurrency = 'افغانی';
    
    void updateEquivalent() {
      final price = double.tryParse(_priceController.text) ?? 0;
      final rate = double.tryParse(_exchangeRateController.text) ?? 1;
      
      if (selectedCurrency == 'دالر') {
        // USD selected: price * rate = AFN equivalent
        _equivalentController.text = (price * rate).toStringAsFixed(0);
      } else {
        // AFN or other selected: price / rate = USD equivalent
        _equivalentController.text = rate > 0 ? (price / rate).toStringAsFixed(2) : '0';
      }
    }
    
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
              height: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: _registrationNumberController,
                      label: 'شماره ثبت',
                      icon: Icons.numbers_outlined,
                      hint: 'شماره ثبت را وارد کنید',
                      l10n: l10n,
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
                      onChanged: (_) => setDialogState(updateEquivalent),
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.currency_exchange_outlined, color: const Color(0xFFCB001D), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedCurrency,
                                      isExpanded: true,
                                      items: ['افغانی', 'دالر', 'یورو'].map((item) {
                                        return DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(item),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() {
                                            selectedCurrency = value;
                                            updateEquivalent();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _exchangeRateController,
                            label: selectedCurrency == 'دالر' 
                                ? 'نرخ ارز (USD به AFN) *' 
                                : 'نرخ ارز (AFN به USD) *',
                            icon: Icons.trending_up_outlined,
                            hint: selectedCurrency == 'دالر' ? '70' : '0.015',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(updateEquivalent),
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _equivalentController,
                      label: selectedCurrency == 'دالر' 
                          ? 'معادل به افغانی (AFN)' 
                          : 'معادل به دالر (USD)',
                      icon: Icons.attach_money_outlined,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      readOnly: true,
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
                  if (_registrationNumberController.text.isEmpty) {
                    _showSnackBar('لطفاً شماره ثبت را وارد کنید', Colors.red);
                    return;
                  }
                  if (_dateController.text.isEmpty) {
                    _showSnackBar(l10n.pleaseEnterDate, Colors.red);
                    return;
                  }
                  if (_priceController.text.isEmpty) {
                    _showSnackBar(l10n.pleaseEnterPrice, Colors.red);
                    return;
                  }

                  Navigator.of(context).pop();
                  final price = double.tryParse(_priceController.text) ?? 0;
                  final rate = double.tryParse(_exchangeRateController.text) ?? 1;
                  
                  // Calculate USD equivalent based on currency
                  int usdEquivalent;
                  if (selectedCurrency == 'دالر') {
                    // USD to AFN: price * rate
                    usdEquivalent = (price * rate).round();
                  } else {
                    // AFN to USD: price / rate
                    usdEquivalent = rate > 0 ? (price / rate).round() : 0;
                  }
                  
                  final insertPayload = {
                    'registration_number': _registrationNumberController.text.trim(),
                    'date': _dateController.text,
                    'date_en': selectedEnglishDate ?? PersianDateConverter.getEnglishDate(DateTime.now()),
                    'category': _categoryController.text.isNotEmpty ? _categoryController.text : 'سایر',
                    'description': _descriptionController.text,
                    'price': price,
                    'currency': selectedCurrency,
                    'exchange_rate': rate,
                    'usd_equivalent': usdEquivalent,
                  };

                  final id = await _db.insertDailyExpense(insertPayload);
                  if (id != -1) {
                    await _loadExpenses();
                    _showSnackBar(l10n.expenseAddedSuccess, Colors.green);
                  } else {
                    _showSnackBar('شماره ثبت تکراری است یا خطایی رخ داد', Colors.red);
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
    _registrationNumberController.text = expense['registrationNumber'] ?? '';
    _dateController.text = expense['date'];
    _categoryController.text = expense['category'] ?? '';
    _descriptionController.text = expense['description'] ?? '';
    _priceController.text = expense['price'].toString();
    String selectedCurrency = expense['currency'] ?? 'افغانی';
    _exchangeRateController.text = expense['exchangeRate'].toString();
    _equivalentController.text = expense['usdEquivalent'].toString();

    String? selectedEnglishDate = expense['date_en'];
    
    void updateEquivalent() {
      final price = double.tryParse(_priceController.text) ?? 0;
      final rate = double.tryParse(_exchangeRateController.text) ?? 1;
      
      if (selectedCurrency == 'دالر') {
        _equivalentController.text = (price * rate).toStringAsFixed(0);
      } else {
        _equivalentController.text = rate > 0 ? (price / rate).toStringAsFixed(2) : '0';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
              height: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: _registrationNumberController,
                      label: 'شماره ثبت',
                      icon: Icons.numbers_outlined,
                      hint: 'شماره ثبت را وارد کنید',
                      l10n: l10n,
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
                      maxLines: 2,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _priceController,
                      label: l10n.price,
                      icon: Icons.money_outlined,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(updateEquivalent),
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.currency_exchange_outlined, color: const Color(0xFFCB001D), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedCurrency,
                                      isExpanded: true,
                                      items: ['افغانی', 'دالر', 'یورو'].map((item) {
                                        return DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(item),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() {
                                            selectedCurrency = value;
                                            updateEquivalent();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _exchangeRateController,
                            label: selectedCurrency == 'دالر' 
                                ? 'نرخ ارز (USD به AFN) *' 
                                : 'نرخ ارز (AFN به USD) *',
                            icon: Icons.trending_up_outlined,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(updateEquivalent),
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _equivalentController,
                      label: selectedCurrency == 'دالر' 
                          ? 'معادل به افغانی (AFN)' 
                          : 'معادل به دالر (USD)',
                      icon: Icons.attach_money_outlined,
                      keyboardType: TextInputType.number,
                      readOnly: true,
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
                  if (_registrationNumberController.text.isEmpty) {
                    _showSnackBar('لطفاً شماره ثبت را وارد کنید', Colors.red);
                    return;
                  }
                  if (_dateController.text.isEmpty) {
                    _showSnackBar(l10n.pleaseEnterDate, Colors.red);
                    return;
                  }

                  final price = double.tryParse(_priceController.text) ?? 0;
                  final rate = double.tryParse(_exchangeRateController.text) ?? 1;
                  
                  int usdEquivalent;
                  if (selectedCurrency == 'دالر') {
                    usdEquivalent = (price * rate).round();
                  } else {
                    usdEquivalent = rate > 0 ? (price / rate).round() : 0;
                  }

                  final payload = {
                    'registration_number': _registrationNumberController.text.trim(),
                    'date': _dateController.text,
                    'date_en': selectedEnglishDate ?? PersianDateConverter.getEnglishDate(DateTime.now()),
                    'category': _categoryController.text.isNotEmpty ? _categoryController.text : 'سایر',
                    'description': _descriptionController.text,
                    'price': price,
                    'currency': selectedCurrency,
                    'exchange_rate': rate,
                    'usd_equivalent': usdEquivalent,
                  };

                  final res = await _db.updateDailyExpense(expense['id'] as int, payload);
                  if (res != -1) {
                    await _loadExpenses();
                    Navigator.pop(context);
                    _showSnackBar(l10n.expenseUpdatedSuccess, Colors.blue);
                  } else {
                    _showSnackBar('شماره ثبت تکراری است یا خطایی رخ داد', Colors.red);
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
          );
        },
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
          '${l10n.deleteConfirmation} "${expense['registrationNumber']}"؟',
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
    bool readOnly = false,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: onChanged,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final filteredData = _expensesData.where((expense) {
      final matchesSearch = (expense['registrationNumber'] ?? '').toString().contains(_searchQuery) ||
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
                Expanded(flex: 1, child: Text('شماره ثبت', style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.persianDate, style: const TextStyle(fontWeight: FontWeight.w600))),
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
              expense['registrationNumber'] ?? '-',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w700),
            ),
          ),
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
}
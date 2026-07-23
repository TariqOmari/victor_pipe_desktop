import 'package:flutter/material.dart';

class DailyExpensesPage extends StatefulWidget {
  const DailyExpensesPage({super.key});

  @override
  State<DailyExpensesPage> createState() => _DailyExpensesPageState();
}

class _DailyExpensesPageState extends State<DailyExpensesPage> {
  // ======================== داده‌های نمونه مصارف ========================
  final List<Map<String, dynamic>> _expensesData = [
    {
      'id': 1,
      'date': '۱۴۰۵/۰۵/۰۱',
      'billNumber': 'BL-۱۴۰۵-۰۰۱',
      'registrationNumber': 'REG-۱۲۳۴۵',
      'category': 'سوخت',
      'description': 'خرید گازوئیل برای ژنراتور',
      'price': 2500000,
      'currency': 'افغانی',
      'exchangeRate': 0.011,
      'usdEquivalent': 27500,
    },
    {
      'id': 2,
      'date': '۱۴۰۵/۰۵/۰۱',
      'billNumber': 'BL-۱۴۰۵-۰۰۲',
      'registrationNumber': 'REG-۱۲۳۴۶',
      'category': 'مواد اولیه',
      'description': 'خرید مواد شیمیایی تصفیه',
      'price': 4500000,
      'currency': 'افغانی',
      'exchangeRate': 0.011,
      'usdEquivalent': 49500,
    },
    {
      'id': 3,
      'date': '۱۴۰۵/۰۵/۰۲',
      'billNumber': 'BL-۱۴۰۵-۰۰۳',
      'registrationNumber': 'REG-۱۲۳۴۷',
      'category': 'حقوق کارگران',
      'description': 'حقوق ماهانه کارگران خط تولید',
      'price': 15000000,
      'currency': 'افغانی',
      'exchangeRate': 0.011,
      'usdEquivalent': 165000,
    },
    {
      'id': 4,
      'date': '۱۴۰۵/۰۵/۰۲',
      'billNumber': 'BL-۱۴۰۵-۰۰۴',
      'registrationNumber': 'REG-۱۲۳۴۸',
      'category': 'تعمیرات',
      'description': 'تعمیر دستگاه پرس',
      'price': 3200000,
      'currency': 'افغانی',
      'exchangeRate': 0.011,
      'usdEquivalent': 35200,
    },
    {
      'id': 5,
      'date': '۱۴۰۵/۰۵/۰۳',
      'billNumber': 'BL-۱۴۰۵-۰۰۵',
      'registrationNumber': 'REG-۱۲۳۴۹',
      'category': 'حمل و نقل',
      'description': 'هزینه حمل مواد اولیه',
      'price': 1800000,
      'currency': 'افغانی',
      'exchangeRate': 0.011,
      'usdEquivalent': 19800,
    },
    {
      'id': 6,
      'date': '۱۴۰۵/۰۵/۰۳',
      'billNumber': 'BL-۱۴۰۵-۰۰۶',
      'registrationNumber': 'REG-۱۲۳۵۰',
      'category': 'سوخت',
      'description': 'خرید بنزین برای خودروها',
      'price': 950000,
      'currency': 'افغانی',
      'exchangeRate': 0.011,
      'usdEquivalent': 10450,
    },
    {
      'id': 7,
      'date': '۱۴۰۵/۰۵/۰۴',
      'billNumber': 'BL-۱۴۰۵-۰۰۷',
      'registrationNumber': 'REG-۱۲۳۵۱',
      'category': 'مواد اولیه',
      'description': 'خرید PVC گرید صنعتی',
      'price': 8500000,
      'currency': 'افغانی',
      'exchangeRate': 0.011,
      'usdEquivalent': 93500,
    },
    {
      'id': 8,
      'date': '۱۴۰۵/۰۵/۰۴',
      'billNumber': 'BL-۱۴۰۵-۰۰۸',
      'registrationNumber': 'REG-۱۲۳۵۲',
      'category': 'سایر',
      'description': 'لوازم اداری و مصرفی',
      'price': 650000,
      'currency': 'افغانی',
      'exchangeRate': 0.011,
      'usdEquivalent': 7150,
    },
  ];

  String _searchQuery = '';
  String _selectedCategory = 'همه';
  DateTime? _selectedDate;
  String _selectedCurrency = 'همه';

  // ======================== کنترل‌های فرم ========================
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _billNumberController = TextEditingController();
  final TextEditingController _registrationNumberController = TextEditingController();
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
    _billNumberController.dispose();
    _registrationNumberController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _exchangeRateController.dispose();
    _usdEquivalentController.dispose();
    super.dispose();
  }

  // ======================== متدهای مدیریت ========================
  void _addExpense() {
    _dateController.clear();
    _billNumberController.clear();
    _registrationNumberController.clear();
    _categoryController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _currencyController.clear();
    _exchangeRateController.clear();
    _usdEquivalentController.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text(
              'ثبت مصرف جدید',
              style: TextStyle(
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
                    // تاریخ
                    _buildTextField(
                      controller: _dateController,
                      label: 'تاریخ',
                      icon: Icons.calendar_today_outlined,
                      hint: '۱۴۰۵/۰۵/۰۱',
                    ),
                    const SizedBox(height: 12),
                    // شماره بل و شماره ثبت
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _billNumberController,
                            label: 'شماره بل',
                            icon: Icons.receipt_outlined,
                            hint: 'BL-۱۴۰۵-۰۰۱',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _registrationNumberController,
                            label: 'شماره ثبت',
                            icon: Icons.numbers_outlined,
                            hint: 'REG-۱۲۳۴۵',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // کتگوری
                    _buildDropdownField(
                      controller: _categoryController,
                      label: 'کتگوری',
                      icon: Icons.category_outlined,
                      items: _categories.where((c) => c != 'همه').toList(),
                    ),
                    const SizedBox(height: 12),
                    // تفصیل
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'تفصیل',
                      icon: Icons.description_outlined,
                      hint: 'توضیحات کامل مصرف',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    // قیمت
                    _buildTextField(
                      controller: _priceController,
                      label: 'قیمت',
                      icon: Icons.money_outlined,
                      hint: '۰',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    // واحد پول و نرخ ارز
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            controller: _currencyController,
                            label: 'واحد پول',
                            icon: Icons.currency_exchange_outlined,
                            items: ['افغانی', 'دالر', 'یورو'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _exchangeRateController,
                            label: 'نرخ ارز',
                            icon: Icons.trending_up_outlined,
                            hint: '۰.۰۱۱',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // معادل دالر
                    _buildTextField(
                      controller: _usdEquivalentController,
                      label: 'معادل دالر',
                      icon: Icons.attach_money_outlined,
                      hint: '۰',
                      keyboardType: TextInputType.number,
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
                child: const Text(
                  'انصراف',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // اعتبارسنجی
                  if (_dateController.text.isEmpty) {
                    _showSnackBar('لطفاً تاریخ را وارد کنید', Colors.red);
                    return;
                  }
                  if (_billNumberController.text.isEmpty) {
                    _showSnackBar('لطفاً شماره بل را وارد کنید', Colors.red);
                    return;
                  }
                  if (_priceController.text.isEmpty) {
                    _showSnackBar('لطفاً قیمت را وارد کنید', Colors.red);
                    return;
                  }

                  setState(() {
                    _expensesData.add({
                      'id': _expensesData.length + 1,
                      'date': _dateController.text,
                      'billNumber': _billNumberController.text,
                      'registrationNumber': _registrationNumberController.text,
                      'category': _categoryController.text.isNotEmpty
                          ? _categoryController.text
                          : 'سایر',
                      'description': _descriptionController.text,
                      'price': int.tryParse(_priceController.text) ?? 0,
                      'currency': _currencyController.text.isNotEmpty
                          ? _currencyController.text
                          : 'افغانی',
                      'exchangeRate': double.tryParse(_exchangeRateController.text) ?? 0.011,
                      'usdEquivalent': int.tryParse(_usdEquivalentController.text) ?? 0,
                    });
                  });

                  Navigator.pop(context);
                  _showSnackBar('مصرف با موفقیت ثبت شد', Colors.green);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCB001D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('ثبت مصرف'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editExpense(Map<String, dynamic> expense) {
    _dateController.text = expense['date'];
    _billNumberController.text = expense['billNumber'];
    _registrationNumberController.text = expense['registrationNumber'] ?? '';
    _categoryController.text = expense['category'] ?? '';
    _descriptionController.text = expense['description'] ?? '';
    _priceController.text = expense['price'].toString();
    _currencyController.text = expense['currency'] ?? '';
    _exchangeRateController.text = expense['exchangeRate'].toString();
    _usdEquivalentController.text = expense['usdEquivalent'].toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ویرایش مصرف',
          style: TextStyle(
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
                _buildTextField(
                  controller: _dateController,
                  label: 'تاریخ',
                  icon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _billNumberController,
                        label: 'شماره بل',
                        icon: Icons.receipt_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _registrationNumberController,
                        label: 'شماره ثبت',
                        icon: Icons.numbers_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  controller: _categoryController,
                  label: 'کتگوری',
                  icon: Icons.category_outlined,
                  items: _categories.where((c) => c != 'همه').toList(),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'تفصیل',
                  icon: Icons.description_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _priceController,
                  label: 'قیمت',
                  icon: Icons.money_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        controller: _currencyController,
                        label: 'واحد پول',
                        icon: Icons.currency_exchange_outlined,
                        items: ['افغانی', 'دالر', 'یورو'],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _exchangeRateController,
                        label: 'نرخ ارز',
                        icon: Icons.trending_up_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _usdEquivalentController,
                  label: 'معادل دالر',
                  icon: Icons.attach_money_outlined,
                  keyboardType: TextInputType.number,
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
            child: const Text(
              'انصراف',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_dateController.text.isEmpty) {
                _showSnackBar('لطفاً تاریخ را وارد کنید', Colors.red);
                return;
              }

              setState(() {
                final index = _expensesData.indexWhere((e) => e['id'] == expense['id']);
                if (index != -1) {
                  _expensesData[index] = {
                    'id': expense['id'],
                    'date': _dateController.text,
                    'billNumber': _billNumberController.text,
                    'registrationNumber': _registrationNumberController.text,
                    'category': _categoryController.text.isNotEmpty
                        ? _categoryController.text
                        : 'سایر',
                    'description': _descriptionController.text,
                    'price': int.tryParse(_priceController.text) ?? 0,
                    'currency': _currencyController.text.isNotEmpty
                        ? _currencyController.text
                        : 'افغانی',
                    'exchangeRate': double.tryParse(_exchangeRateController.text) ?? 0.011,
                    'usdEquivalent': int.tryParse(_usdEquivalentController.text) ?? 0,
                  };
                }
              });

              Navigator.pop(context);
              _showSnackBar('مصرف با موفقیت ویرایش شد', Colors.blue);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB001D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('ذخیره تغییرات'),
          ),
        ],
      ),
    );
  }

  void _deleteExpense(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'حذف مصرف',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          'آیا از حذف مصرف "${expense['billNumber']}" مطمئن هستید؟',
          style: const TextStyle(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'انصراف',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _expensesData.removeWhere((e) => e['id'] == expense['id']);
              });
              Navigator.pop(context);
              _showSnackBar('مصرف با موفقیت حذف شد', Colors.red);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _printPage() {
    // برای پرینت صفحه
    _showSnackBar('در حال آماده‌سازی پرینت...', Colors.blue);
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

  // ======================== ویجت‌های کمکی ========================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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

  // ======================== ویجت‌های اصلی ========================
  @override
  Widget build(BuildContext context) {
    // فیلتر کردن داده‌ها
    final filteredData = _expensesData.where((expense) {
      final matchesSearch = expense['billNumber'].contains(_searchQuery) ||
          expense['description'].contains(_searchQuery) ||
          expense['category'].contains(_searchQuery);
      final matchesCategory = _selectedCategory == 'همه' ||
          expense['category'] == _selectedCategory;
      final matchesCurrency = _selectedCurrency == 'همه' ||
          expense['currency'] == _selectedCurrency;
      return matchesSearch && matchesCategory && matchesCurrency;
    }).toList();

    // محاسبه مجموع کل
    final totalPrice = filteredData.fold<int>(
      0,
      (sum, expense) => sum + (expense['price'] as int),
    );
    final totalUsd = filteredData.fold<int>(
      0,
      (sum, expense) => sum + (expense['usdEquivalent'] as int),
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(totalPrice, totalUsd),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildFilterAndSearch(),
            const SizedBox(height: 20),
            Expanded(child: _buildExpensesTable(filteredData)),
          ],
        ),
      ),
    );
  }

  // ======================== هدر ========================
  Widget _buildHeader(int totalPrice, int totalUsd) {
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
                const Text(
                  'مدیریت مصارف روزمره فابریکه',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'مجموع: ${totalPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} افغانی',
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
                        'معادل: ${totalUsd.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} \$',
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
              label: const Text(
                'پرینت',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              label: const Text(
                'ثبت مصرف جدید',
                style: TextStyle(
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

  // ======================== کارت‌های آمار ========================
  Widget _buildQuickStats() {
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
      (e) => e['date'] == '۱۴۰۵/۰۵/۰۴',
    ).length;

    return Row(
      children: [
        _buildStatCard(
          title: 'کل مصارف',
          value: totalExpenses.toString(),
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFFCB001D),
          subtitle: 'تعداد کل ثبت‌ها',
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: 'مجموع مبلغ',
          value: totalAmount.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          ),
          icon: Icons.money_outlined,
          color: Colors.blue.shade700,
          subtitle: 'افغانی',
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: 'معادل دالر',
          value: totalUsd.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          ),
          icon: Icons.attach_money_outlined,
          color: Colors.green.shade700,
          subtitle: 'دالر آمریکایی',
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: 'مصارف امروز',
          value: todayExpenses.toString(),
          icon: Icons.today_outlined,
          color: Colors.orange.shade700,
          subtitle: 'ثبت شده امروز',
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

  // ======================== فیلتر و جستجو ========================
  Widget _buildFilterAndSearch() {
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
          // جستجو
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'جستجو بر اساس شماره بل، تفصیل یا کتگوری...',
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
          // فیلتر کتگوری
          Expanded(
            child: _buildFilterDropdown(
              value: _selectedCategory,
              items: _categories,
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
              label: 'کتگوری',
            ),
          ),
          const SizedBox(width: 12),
          // فیلتر واحد پول
          Expanded(
            child: _buildFilterDropdown(
              value: _selectedCurrency,
              items: _currencies,
              onChanged: (value) {
                setState(() => _selectedCurrency = value!);
              },
              label: 'واحد پول',
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

  // ======================== جدول مصارف ========================
  Widget _buildExpensesTable(List<Map<String, dynamic>> data) {
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
          // هدر جدول
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
              children: const [
                Expanded(flex: 1, child: Text('تاریخ', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('شماره بل', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('شماره ثبت', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('کتگوری', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('تفصیل', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('قیمت', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('واحد پول', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('نرخ ارز', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('معادل \$', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('عملیات', style: TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // ردیف‌های جدول
          Expanded(
            child: data.isEmpty
                ? const Center(
                    child: Text(
                      'هیچ مصرفی یافت نشد',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final expense = data[index];
                      return _buildTableRow(expense);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> expense) {
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                expense['billNumber'],
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: Color(0xFFCB001D),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['registrationNumber'] ?? '-',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
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

  // ======================== توابع کمکی ========================
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
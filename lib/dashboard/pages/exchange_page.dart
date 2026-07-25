import 'package:flutter/material.dart';

class ExchangePage extends StatefulWidget {
  const ExchangePage({super.key});

  @override
  State<ExchangePage> createState() => _ExchangePageState();
}

class _ExchangePageState extends State<ExchangePage> {
  // ======================== نرخ ارزها ========================
  final Map<String, double> _exchangeRates = {
    'USD': 85000,
    'EUR': 92000,
    'GBP': 105000,
    'TRY': 2600,
    'AED': 23000,
    'CNY': 11700,
    'JPY': 580,
    'CAD': 62000,
  };

  // ======================== لیست معاملات ========================
  final List<Map<String, dynamic>> _transactions = [
    {
      'id': 'EX-001',
      'type': 'خرید',
      'currency': 'USD',
      'amount': 1000,
      'rate': 85000,
      'total': 85000000,
      'date': '۱۴۰۵/۰۵/۰۱',
      'status': 'انجام شده',
      'description': 'خرید ارز برای واردات مواد اولیه',
      'customer': 'شرکت پلیمر',
      'reference': 'REF-2025-001',
    },
    {
      'id': 'EX-002',
      'type': 'فروش',
      'currency': 'EUR',
      'amount': 500,
      'rate': 92000,
      'total': 46000000,
      'date': '۱۴۰۵/۰۵/۰۲',
      'status': 'انجام شده',
      'description': 'فروش ارز حاصل از صادرات',
      'customer': 'مهندس کریمی',
      'reference': 'REF-2025-002',
    },
    {
      'id': 'EX-003',
      'type': 'خرید',
      'currency': 'GBP',
      'amount': 200,
      'rate': 105000,
      'total': 21000000,
      'date': '۱۴۰۵/۰۵/۰۳',
      'status': 'در انتظار',
      'description': 'خرید ارز برای سفر کاری',
      'customer': 'علی رضایی',
      'reference': 'REF-2025-003',
    },
    {
      'id': 'EX-004',
      'type': 'فروش',
      'currency': 'TRY',
      'amount': 5000,
      'rate': 2600,
      'total': 13000000,
      'date': '۱۴۰۵/۰۵/۰۴',
      'status': 'لغو شده',
      'description': 'فروش لیر ترکیه',
      'customer': 'سارا حسینی',
      'reference': 'REF-2025-004',
    },
    {
      'id': 'EX-005',
      'type': 'خرید',
      'currency': 'AED',
      'amount': 3000,
      'rate': 23000,
      'total': 69000000,
      'date': '۱۴۰۵/۰۵/۰۵',
      'status': 'انجام شده',
      'description': 'خرید درهم امارات',
      'customer': 'شرکت نفت جنوب',
      'reference': 'REF-2025-005',
    },
    {
      'id': 'EX-006',
      'type': 'فروش',
      'currency': 'JPY',
      'amount': 10000,
      'rate': 580,
      'total': 5800000,
      'date': '۱۴۰۵/۰۵/۰۶',
      'status': 'در انتظار',
      'description': 'فروش ین ژاپن',
      'customer': 'پیمانکاران عمران',
      'reference': 'REF-2025-006',
    },
  ];

  // ======================== فیلترها ========================
  String _searchQuery = '';
  String _selectedFilter = 'همه';
  final List<String> _filterTypes = ['همه', 'خرید', 'فروش'];
  final List<String> _currencyList = [
    'همه',
    'USD',
    'EUR',
    'GBP',
    'TRY',
    'AED',
    'CNY',
    'JPY',
    'CAD'
  ];
  String _selectedCurrency = 'همه';

  // ======================== کنترل‌های فرم ========================
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  String _selectedType = 'خرید';
  String _selectedCurrencyForm = 'USD';
  String _selectedStatus = 'انجام شده';
  DateTime? _selectedDate;

  // ======================== متدهای محاسبه ========================
  String _formatCurrency(dynamic amount) {
    final doubleValue = amount is int ? amount.toDouble() : amount;
    return doubleValue.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  double _calculateTotal() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    return amount * rate;
  }

  // ======================== متدهای مدیریت ========================
  void _showAddTransactionDialog() {
    _amountController.clear();
    _rateController.clear();
    _descriptionController.clear();
    _customerController.clear();
    _referenceController.clear();
    _selectedType = 'خرید';
    _selectedCurrencyForm = 'USD';
    _selectedStatus = 'انجام شده';
    _selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ثبت معامله ارزی جدید',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: SizedBox(
          width: 550,
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // نوع معامله و ارز
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogDropdown(
                            value: _selectedType,
                            items: ['خرید', 'فروش'],
                            label: 'نوع معامله',
                            icon: Icons.swap_horiz_rounded,
                            onChanged: (value) {
                              setStateDialog(() {
                                _selectedType = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogDropdown(
                            value: _selectedCurrencyForm,
                            items: _currencyList.where((c) => c != 'همه').toList(),
                            label: 'ارز',
                            icon: Icons.attach_money_rounded,
                            onChanged: (value) {
                              setStateDialog(() {
                                _selectedCurrencyForm = value!;
                                // تنظیم نرخ پیش‌فرض
                                _rateController.text =
                                    _exchangeRates[_selectedCurrencyForm]?.toString() ?? '';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // مبلغ و نرخ
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            controller: _amountController,
                            label: 'مبلغ ارز',
                            icon: Icons.numbers_rounded,
                            hint: 'مثال: ۱۰۰۰',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setStateDialog(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogField(
                            controller: _rateController,
                            label: 'نرخ (ریال)',
                            icon: Icons.trending_up_rounded,
                            hint: 'مثال: ۸۵۰۰۰',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setStateDialog(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // جمع کل (محاسبه خودکار)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB001D).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCB001D).withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'جمع کل:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            '${_formatCurrency(_calculateTotal())} ریال',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFFCB001D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // مشتری و مرجع
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            controller: _customerController,
                            label: 'مشتری/فروشنده',
                            icon: Icons.person_outline,
                            hint: 'نام شخص یا شرکت',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogField(
                            controller: _referenceController,
                            label: 'شماره مرجع',
                            icon: Icons.receipt_outlined,
                            hint: 'REF-2025-001',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // تاریخ و وضعیت
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setStateDialog(() {
                                  _selectedDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 20,
                                    color: Color(0xFFCB001D),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedDate != null
                                        ? '${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}'
                                        : 'انتخاب تاریخ',
                                    style: TextStyle(
                                      color: _selectedDate != null
                                          ? Colors.black
                                          : Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogDropdown(
                            value: _selectedStatus,
                            items: ['انجام شده', 'در انتظار', 'لغو شده'],
                            label: 'وضعیت',
                            icon: Icons.verified_outlined,
                            onChanged: (value) {
                              setStateDialog(() {
                                _selectedStatus = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // توضیحات
                    _buildDialogField(
                      controller: _descriptionController,
                      label: 'توضیحات',
                      icon: Icons.description_outlined,
                      hint: 'توضیحات تکمیلی...',
                      maxLines: 2,
                    ),
                  ],
                ),
              );
            },
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
              if (_amountController.text.isEmpty || _rateController.text.isEmpty) {
                _showSnackbar('لطفاً مبلغ و نرخ را وارد کنید', Colors.red);
                return;
              }
              final amount = double.tryParse(_amountController.text) ?? 0;
              final rate = double.tryParse(_rateController.text) ?? 0;
              if (amount <= 0 || rate <= 0) {
                _showSnackbar('لطفاً مقادیر معتبر وارد کنید', Colors.red);
                return;
              }

              setState(() {
                _transactions.insert(0, {
                  'id': 'EX-${DateTime.now().millisecondsSinceEpoch.toString().padLeft(5, '0')}',
                  'type': _selectedType,
                  'currency': _selectedCurrencyForm,
                  'amount': amount,
                  'rate': rate,
                  'total': amount * rate,
                  'date': _selectedDate != null
                      ? '${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}'
                      : '۱۴۰۵/۰۵/۰۱',
                  'status': _selectedStatus,
                  'description': _descriptionController.text,
                  'customer': _customerController.text,
                  'reference': _referenceController.text,
                });
              });

              Navigator.pop(context);
              _showSnackbar('معامله با موفقیت ثبت شد', Colors.green);
            },
            style: _buildButtonStyle(),
            child: const Text('ثبت معامله'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 12,
        ),
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFCB001D),
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFCB001D),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required String value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down,
            color: const Color(0xFFCB001D),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFFCB001D)),
                  const SizedBox(width: 8),
                  Text(item),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ======================== ویجت‌های اصلی ========================
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مدیریت صرافی',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'مدیریت و کنترل معاملات ارزی',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _showAddTransactionDialog,
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
            'ثبت معامله جدید',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExchangeRates() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                color: Color(0xFFCB001D),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'نرخ روز ارزها',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _exchangeRates.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCB001D).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFCB001D).withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFFCB001D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(entry.value),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
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
  }

  Widget _buildStatsRow() {
    final totalTransactions = _transactions.length;
    final totalBuy = _transactions
        .where((t) => t['type'] == 'خرید' && t['status'] == 'انجام شده')
        .fold<double>(0, (sum, t) => sum + (t['total'] as num).toDouble());
    final totalSell = _transactions
        .where((t) => t['type'] == 'فروش' && t['status'] == 'انجام شده')
        .fold<double>(0, (sum, t) => sum + (t['total'] as num).toDouble());

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;

          if (isSmallScreen) {
            return Column(
              children: [
                _buildStatItem('کل معاملات', totalTransactions.toString(), Colors.blue, Icons.receipt_long_rounded),
                const SizedBox(height: 8),
                _buildStatItem('کل خرید', _formatCurrency(totalBuy), Colors.green, Icons.arrow_upward_rounded),
                const SizedBox(height: 8),
                _buildStatItem('کل فروش', _formatCurrency(totalSell), Colors.orange, Icons.arrow_downward_rounded),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildStatItem('کل معاملات', totalTransactions.toString(), Colors.blue, Icons.receipt_long_rounded),
              ),
              Expanded(
                child: _buildStatItem('کل خرید', _formatCurrency(totalBuy), Colors.green, Icons.arrow_upward_rounded),
              ),
              Expanded(
                child: _buildStatItem('کل فروش', _formatCurrency(totalSell), Colors.orange, Icons.arrow_downward_rounded),
              ),
              Expanded(
                child: _buildStatItem(
                  'سود/زیان',
                  _formatCurrency(totalSell - totalBuy),
                  (totalSell - totalBuy) >= 0 ? Colors.green : Colors.red,
                  Icons.trending_up_rounded,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
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

  Widget _buildSearchAndFilter() {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 700;

          if (isSmallScreen) {
            return Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildFilterDropdown('نوع', _filterTypes, _selectedFilter, (v) => setState(() => _selectedFilter = v!))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFilterDropdown('ارز', _currencyList, _selectedCurrency, (v) => setState(() => _selectedCurrency = v!))),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 2, child: _buildSearchField()),
              const SizedBox(width: 12),
              _buildFilterDropdown('نوع', _filterTypes, _selectedFilter, (v) => setState(() => _selectedFilter = v!)),
              const SizedBox(width: 8),
              _buildFilterDropdown('ارز', _currencyList, _selectedCurrency, (v) => setState(() => _selectedCurrency = v!)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'جستجو در معاملات...',
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
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFCB001D),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        isDense: true,
      ),
    );
  }

  Widget _buildFilterDropdown(String label, List<String> items, String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFCB001D).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Color(0xFFCB001D),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          items: items.map((String item) {
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

  Widget _buildTransactionsList() {
    final filtered = _transactions.where((t) {
      final matchSearch = t['id'].contains(_searchQuery) ||
          t['customer'].contains(_searchQuery) ||
          t['description'].contains(_searchQuery) ||
          t['reference'].contains(_searchQuery);
      final matchType = _selectedFilter == 'همه' || t['type'] == _selectedFilter;
      final matchCurrency = _selectedCurrency == 'همه' || t['currency'] == _selectedCurrency;
      return matchSearch && matchType && matchCurrency;
    }).toList();

    if (filtered.isEmpty) {
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.currency_exchange_rounded,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'هیچ معامله‌ای یافت نشد',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final transaction = filtered[index];
          return _buildTransactionItem(transaction, index);
        },
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction, int index) {
    final isBuy = transaction['type'] == 'خرید';
    final color = isBuy ? Colors.green.shade700 : Colors.orange.shade700;
    final icon = isBuy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    Color statusColor;
    switch (transaction['status']) {
      case 'انجام شده':
        statusColor = Colors.green;
        break;
      case 'در انتظار':
        statusColor = Colors.orange;
        break;
      case 'لغو شده':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;

          if (isSmallScreen) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction['id'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFFCB001D),
                              ),
                            ),
                            Text(
                              '${transaction['currency']} - ${transaction['type']}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        transaction['status'],
                        style: TextStyle(
                          fontSize: 9,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      transaction['customer'] ?? '-',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${transaction['amount']} ${transaction['currency']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'نرخ: ${_formatCurrency(transaction['rate'])}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _formatCurrency(transaction['total']),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFFCB001D),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: Text(
                  transaction['id'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFFCB001D),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction['customer'] ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      transaction['description'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '${transaction['currency']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '${transaction['amount']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  transaction['date'],
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  transaction['status'],
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: Text(
                  _formatCurrency(transaction['total']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFFCB001D),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ======================== متدهای کمکی ========================
  ButtonStyle _buildButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFCB001D),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ======================== صفحه اصلی ========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildExchangeRates(),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildSearchAndFilter(),
            const SizedBox(height: 16),
            Expanded(
              child: _buildTransactionsList(),
            ),
          ],
        ),
      ),
    );
  }
}
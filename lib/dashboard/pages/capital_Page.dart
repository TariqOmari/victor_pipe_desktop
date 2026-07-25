import 'package:flutter/material.dart';

class CapitalPage extends StatefulWidget {
  const CapitalPage({super.key});

  @override
  State<CapitalPage> createState() => _CapitalPageState();
}

class _CapitalPageState extends State<CapitalPage> {
  // ======================== داده‌های سرمایه ========================
  // سرمایه اولیه
  double _initialCapital = 500000000; // 500 میلیون
  
  // موجودی فعلی
  double _currentBalance = 487500000; // 487.5 میلیون
  
  // درآمد کل
  double _totalIncome = 125000000; // 125 میلیون
  
  // هزینه کل
  double _totalExpense = 137500000; // 137.5 میلیون
  
  // سود/زیان
  double get _profitLoss => _totalIncome - _totalExpense;
  
  // درصد تغییر
  double get _changePercent => ((_currentBalance - _initialCapital) / _initialCapital) * 100;

  // لیست تراکنش‌های سرمایه
  final List<Map<String, dynamic>> _transactions = [
    {
      'id': 1,
      'title': 'افزایش سرمایه اولیه',
      'type': 'واریز',
      'category': 'سرمایه‌گذاری',
      'amount': 500000000,
      'date': '۱۴۰۵/۰۱/۰۱',
      'description': 'سرمایه اولیه شرکت',
      'status': 'تایید شده',
    },
    {
      'id': 2,
      'title': 'فروش لوله پلی‌اتیلن',
      'type': 'واریز',
      'category': 'فروش',
      'amount': 67500000,
      'date': '۱۴۰۵/۰۵/۰۱',
      'description': 'فروش به مشتری علی رضایی',
      'status': 'تایید شده',
    },
    {
      'id': 3,
      'title': 'خرید مواد خام',
      'type': 'برداشت',
      'category': 'تامین مواد',
      'amount': 45000000,
      'date': '۱۴۰۵/۰۵/۰۲',
      'description': 'خرید لوله پلی‌اتیلن از شرکت پلیمر',
      'status': 'تایید شده',
    },
    {
      'id': 4,
      'title': 'فروش اتصالات جوشی',
      'type': 'واریز',
      'category': 'فروش',
      'amount': 25600000,
      'date': '۱۴۰۵/۰۵/۰۲',
      'description': 'فروش به شرکت نفت جنوب',
      'status': 'در انتظار',
    },
    {
      'id': 5,
      'title': 'حقوق کارکنان',
      'type': 'برداشت',
      'category': 'هزینه پرسنلی',
      'amount': 25000000,
      'date': '۱۴۰۵/۰۴/۳۰',
      'description': 'حقوق ماهیانه کارکنان',
      'status': 'تایید شده',
    },
    {
      'id': 6,
      'title': 'فروش لوله فولادی',
      'type': 'واریز',
      'category': 'فروش',
      'amount': 116000000,
      'date': '۱۴۰۵/۰۵/۰۳',
      'description': 'فروش به مهندس کریمی',
      'status': 'تایید شده',
    },
    {
      'id': 7,
      'title': 'هزینه حمل و نقل',
      'type': 'برداشت',
      'category': 'هزینه حمل',
      'amount': 15000000,
      'date': '۱۴۰۵/۰۵/۰۳',
      'description': 'هزینه حمل مواد به انبار',
      'status': 'تایید شده',
    },
    {
      'id': 8,
      'title': 'پرداخت قسط وام',
      'type': 'برداشت',
      'category': 'بدهی',
      'amount': 30000000,
      'date': '۱۴۰۵/۰۵/۰۴',
      'description': 'اقساط ماهیانه وام بانکی',
      'status': 'در انتظار',
    },
  ];

  // فیلترها
  String _searchQuery = '';
  String _selectedFilter = 'همه';
  final List<String> _filterTypes = ['همه', 'واریز', 'برداشت'];
  final List<String> _categoryTypes = [
    'همه',
    'سرمایه‌گذاری',
    'فروش',
    'تامین مواد',
    'هزینه پرسنلی',
    'هزینه حمل',
    'بدهی',
    'سایر'
  ];

  // کنترل‌های فرم
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedType = 'واریز';
  String _selectedCategory = 'فروش';
  String _selectedStatus = 'تایید شده';
  DateTime? _selectedDate;

  // ======================== متدهای محاسبه (اصلاح شده) ========================
  String _formatCurrency(dynamic amount) {
    // تبدیل به double اگر int باشد
    final doubleValue = amount is int ? amount.toDouble() : amount;
    return doubleValue.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // ======================== متدهای مدیریت ========================
  void _showAddTransactionDialog() {
    _titleController.clear();
    _amountController.clear();
    _descriptionController.clear();
    _selectedType = 'واریز';
    _selectedCategory = 'فروش';
    _selectedStatus = 'تایید شده';
    _selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ثبت تراکنش جدید',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: SizedBox(
          width: 500,
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // عنوان
                    _buildDialogField(
                      controller: _titleController,
                      label: 'عنوان تراکنش',
                      icon: Icons.title_outlined,
                      hint: 'مثال: فروش محصول',
                    ),
                    const SizedBox(height: 12),
                    
                    // مبلغ
                    _buildDialogField(
                      controller: _amountController,
                      label: 'مبلغ (ریال)',
                      icon: Icons.attach_money_rounded,
                      hint: 'مثال: ۱۰۰۰۰۰۰۰۰',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    
                    // نوع تراکنش
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            value: _selectedType,
                            items: ['واریز', 'برداشت'],
                            label: 'نوع تراکنش',
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
                          child: _buildDropdownField(
                            value: _selectedCategory,
                            items: _categoryTypes.where((c) => c != 'همه').toList(),
                            label: 'دسته‌بندی',
                            icon: Icons.category_outlined,
                            onChanged: (value) {
                              setStateDialog(() {
                                _selectedCategory = value!;
                              });
                            },
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
                          child: _buildDropdownField(
                            value: _selectedStatus,
                            items: ['تایید شده', 'در انتظار', 'لغو شده'],
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
              if (_titleController.text.isEmpty || _amountController.text.isEmpty) {
                _showSnackbar('لطفاً عنوان و مبلغ را وارد کنید', Colors.red);
                return;
              }
              final amount = double.tryParse(_amountController.text) ?? 0;
              if (amount <= 0) {
                _showSnackbar('لطفاً مبلغ معتبر وارد کنید', Colors.red);
                return;
              }

              setState(() {
                _transactions.insert(0, {
                  'id': DateTime.now().millisecondsSinceEpoch,
                  'title': _titleController.text,
                  'type': _selectedType,
                  'category': _selectedCategory,
                  'amount': amount,
                  'date': _selectedDate != null
                      ? '${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}'
                      : '۱۴۰۵/۰۵/۰۱',
                  'description': _descriptionController.text,
                  'status': _selectedStatus,
                });

                // به‌روزرسانی موجودی
                if (_selectedType == 'واریز') {
                  _currentBalance += amount;
                  _totalIncome += amount;
                } else {
                  _currentBalance -= amount;
                  _totalExpense += amount;
                }
              });

              Navigator.pop(context);
              _showSnackbar('تراکنش با موفقیت ثبت شد', Colors.green);
            },
            style: _buildButtonStyle(),
            child: const Text('ثبت تراکنش'),
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
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

  Widget _buildDropdownField({
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
              'مدیریت سرمایه',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'مدیریت و کنترل جریان مالی و سرمایه شرکت',
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
            'ثبت تراکنش جدید',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final cardWidth = isSmallScreen
            ? constraints.maxWidth / 2 - 6
            : constraints.maxWidth / 4 - 12;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSummaryCard(
              title: 'موجودی فعلی',
              value: _formatCurrency(_currentBalance),
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFFCB001D),
              width: cardWidth,
            ),
            _buildSummaryCard(
              title: 'سرمایه اولیه',
              value: _formatCurrency(_initialCapital),
              icon: Icons.trending_up_rounded,
              color: Colors.blue.shade700,
              width: cardWidth,
            ),
            _buildSummaryCard(
              title: 'درآمد کل',
              value: _formatCurrency(_totalIncome),
              icon: Icons.arrow_upward_rounded,
              color: Colors.green.shade700,
              width: cardWidth,
            ),
            _buildSummaryCard(
              title: 'هزینه کل',
              value: _formatCurrency(_totalExpense),
              icon: Icons.arrow_downward_rounded,
              color: Colors.orange.shade700,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return SizedBox(
      width: width,
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
          border: Border.all(
            color: color.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
                  Text(
                    '$value ریال',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final profit = _profitLoss;
    final percent = _changePercent;

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
                _buildStatItem(
                  'سود/زیان کل',
                  '${profit >= 0 ? '+' : ''}${_formatCurrency(profit)}',
                  profit >= 0 ? Colors.green : Colors.red,
                  Icons.trending_up_rounded,
                ),
                const SizedBox(height: 8),
                _buildStatItem(
                  'درصد تغییر',
                  '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%',
                  percent >= 0 ? Colors.green : Colors.red,
                  Icons.percent_rounded,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'سود/زیان کل',
                  '${profit >= 0 ? '+' : ''}${_formatCurrency(profit)}',
                  profit >= 0 ? Colors.green : Colors.red,
                  Icons.trending_up_rounded,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'درصد تغییر',
                  '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%',
                  percent >= 0 ? Colors.green : Colors.red,
                  Icons.percent_rounded,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'تعداد تراکنش',
                  _transactions.length.toString(),
                  Colors.blue.shade700,
                  Icons.receipt_long_rounded,
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
                    Expanded(
                      child: _buildFilterDropdown(
                        value: _selectedFilter,
                        items: _filterTypes,
                        label: 'نوع',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown(
                        value: _selectedCategory,
                        items: _categoryTypes,
                        label: 'دسته',
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 2, child: _buildSearchField()),
              const SizedBox(width: 12),
              _buildFilterDropdown(
                value: _selectedFilter,
                items: _filterTypes,
                label: 'نوع',
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown(
                value: _selectedCategory,
                items: _categoryTypes,
                label: 'دسته',
              ),
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
        hintText: 'جستجو در تراکنش‌ها...',
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

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required String label,
  }) {
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
          onChanged: (String? newValue) {
            setState(() {
              if (label == 'نوع') {
                _selectedFilter = newValue!;
              } else {
                _selectedCategory = newValue!;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    final filtered = _transactions.where((t) {
      final matchSearch = t['title'].contains(_searchQuery) ||
          t['description'].contains(_searchQuery) ||
          t['category'].contains(_searchQuery);
      final matchType = _selectedFilter == 'همه' || t['type'] == _selectedFilter;
      final matchCategory = _selectedCategory == 'همه' || t['category'] == _selectedCategory;
      return matchSearch && matchType && matchCategory;
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
                Icons.receipt_long_rounded,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'هیچ تراکنشی یافت نشد',
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
    final isDeposit = transaction['type'] == 'واریز';
    final color = isDeposit ? Colors.green.shade700 : Colors.red.shade700;
    final icon = isDeposit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    Color statusColor;
    switch (transaction['status']) {
      case 'تایید شده':
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
          final isSmallScreen = constraints.maxWidth < 500;

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
                              transaction['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              transaction['category'],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          transaction['date'],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${isDeposit ? '+' : '-'}${_formatCurrency(transaction['amount'])}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: color,
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
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      transaction['category'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  transaction['date'],
                  style: TextStyle(
                    fontSize: 12,
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
                  '${isDeposit ? '+' : '-'}${_formatCurrency(transaction['amount'])} ریال',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: color,
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
            const SizedBox(height: 20),
            _buildSummaryCards(),
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
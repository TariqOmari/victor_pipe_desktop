import 'package:flutter/material.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  // ======================== داده‌های مشتریان ========================
  final List<Map<String, dynamic>> _customers = [
    {
      'id': 1,
      'name': 'علی رضایی',
      'phone': '۰۹۱۲۳۴۵۶۷۸۹',
      'address': 'تهران، خیابان آزادی، پلاک ۱۲۳',
      'company': 'ساختمانی رضایی',
    },
    {
      'id': 2,
      'name': 'شرکت نفت جنوب',
      'phone': '۰۲۱۸۸۷۶۵۴۳۲',
      'address': 'اهواز، کیلومتر ۱۵ جاده ساحلی',
      'company': 'نفت جنوب',
    },
    {
      'id': 3,
      'name': 'مهندس کریمی',
      'phone': '۰۹۱۷۶۵۴۳۲۱۰',
      'address': 'اصفهان، خیابان چهارباغ، پلاک ۴۵',
      'company': 'مهندسی کریمی',
    },
    {
      'id': 4,
      'name': 'پیمانکاران عمران',
      'phone': '۰۲۱۴۴۳۲۱۸۷۶',
      'address': 'شیراز، بلوار جمهوری، پلاک ۷۸',
      'company': 'عمران سازان',
    },
  ];

  // ======================== داده‌های فروش ========================
  List<Map<String, dynamic>> _salesData = [
    {
      'id': 'S-1001',
      'customerId': 1,
      'customer': 'علی رضایی',
      'phone': '۰۹۱۲۳۴۵۶۷۸۹',
      'address': 'تهران، خیابان آزادی، پلاک ۱۲۳',
      'product': 'لوله پلی‌اتیلن ۲۵۰',
      'quantity': 150,
      'unit': 'متر',
      'price': 450000,
      'total': 67500000,
      'status': 'تکمیل شده',
      'date': '۱۴۰۵/۰۵/۰۱',
    },
    {
      'id': 'S-1002',
      'customerId': 2,
      'customer': 'شرکت نفت جنوب',
      'phone': '۰۲۱۸۸۷۶۵۴۳۲',
      'address': 'اهواز، کیلومتر ۱۵ جاده ساحلی',
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
      'customerId': 3,
      'customer': 'مهندس کریمی',
      'phone': '۰۹۱۷۶۵۴۳۲۱۰',
      'address': 'اصفهان، خیابان چهارباغ، پلاک ۴۵',
      'product': 'لوله فولادی ۴ اینچ',
      'quantity': 200,
      'unit': 'متر',
      'price': 580000,
      'total': 116000000,
      'status': 'ارسال شده',
      'date': '۱۴۰۵/۰۵/۰۳',
    },
    {
      'id': 'S-1004',
      'customerId': 4,
      'customer': 'پیمانکاران عمران',
      'phone': '۰۲۱۴۴۳۲۱۸۷۶',
      'address': 'شیراز، بلوار جمهوری، پلاک ۷۸',
      'product': 'کمربند فلنج',
      'quantity': 45,
      'unit': 'عدد',
      'price': 175000,
      'total': 7875000,
      'status': 'لغو شده',
      'date': '۱۴۰۵/۰۵/۰۴',
    },
  ];

  String _searchQuery = '';
  String _selectedFilter = 'همه';
  int? _selectedCustomerId;

  // ======================== کنترل‌های فرم ========================
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();
  final TextEditingController _customerCompanyController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _customerCompanyController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ======================== متدهای مدیریت مشتری ========================
  void _addCustomer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'افزودن مشتری جدید',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: _customerNameController,
                label: 'نام مشتری',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customerPhoneController,
                label: 'شماره تماس',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customerAddressController,
                label: 'آدرس',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customerCompanyController,
                label: 'شرکت',
                icon: Icons.business_outlined,
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearCustomerForm();
              Navigator.pop(context);
            },
            child: const Text(
              'انصراف',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_customerNameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لطفاً نام مشتری را وارد کنید'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              setState(() {
                _customers.add({
                  'id': _customers.length + 1,
                  'name': _customerNameController.text,
                  'phone': _customerPhoneController.text,
                  'address': _customerAddressController.text,
                  'company': _customerCompanyController.text,
                });
              });
              _clearCustomerForm();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('مشتری با موفقیت افزوده شد'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB001D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('افزودن مشتری'),
          ),
        ],
      ),
    );
  }

  void _editCustomer(Map<String, dynamic> customer) {
    _customerNameController.text = customer['name'];
    _customerPhoneController.text = customer['phone'] ?? '';
    _customerAddressController.text = customer['address'] ?? '';
    _customerCompanyController.text = customer['company'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ویرایش مشتری',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: _customerNameController,
                label: 'نام مشتری',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customerPhoneController,
                label: 'شماره تماس',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customerAddressController,
                label: 'آدرس',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customerCompanyController,
                label: 'شرکت',
                icon: Icons.business_outlined,
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearCustomerForm();
              Navigator.pop(context);
            },
            child: const Text(
              'انصراف',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_customerNameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لطفاً نام مشتری را وارد کنید'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              setState(() {
                final index = _customers.indexWhere((c) => c['id'] == customer['id']);
                if (index != -1) {
                  _customers[index] = {
                    'id': customer['id'],
                    'name': _customerNameController.text,
                    'phone': _customerPhoneController.text,
                    'address': _customerAddressController.text,
                    'company': _customerCompanyController.text,
                  };
                }
              });
              _clearCustomerForm();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('مشتری با موفقیت ویرایش شد'),
                  backgroundColor: Colors.blue,
                ),
              );
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

  void _deleteCustomer(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'حذف مشتری',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          'آیا از حذف مشتری "${customer['name']}" مطمئن هستید؟',
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
                _customers.removeWhere((c) => c['id'] == customer['id']);
                // حذف فروش‌های مرتبط با این مشتری
                _salesData.removeWhere((s) => s['customerId'] == customer['id']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('مشتری با موفقیت حذف شد'),
                  backgroundColor: Colors.red,
                ),
              );
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

  void _clearCustomerForm() {
    _customerNameController.clear();
    _customerPhoneController.clear();
    _customerAddressController.clear();
    _customerCompanyController.clear();
  }

  // ======================== متدهای مدیریت فروش ========================
  void _addSale() {
    _selectedCustomerId = null;
    _productController.clear();
    _quantityController.clear();
    _priceController.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text(
              'ثبت فروش جدید',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF1A1A1A),
              ),
            ),
            content: SizedBox(
              width: 550,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // انتخاب مشتری
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedCustomerId,
                        hint: const Text(
                          'انتخاب مشتری',
                          style: TextStyle(color: Colors.grey),
                        ),
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        items: _customers.map((customer) {
                          return DropdownMenuItem<int>(
                            value: customer['id'],
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 18,
                                  color: Color(0xFFCB001D),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (customer['company'] != null &&
                                          customer['company'].isNotEmpty)
                                        Text(
                                          customer['company'],
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setStateDialog(() {
                            _selectedCustomerId = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // نمایش اطلاعات مشتری انتخاب شده
                  if (_selectedCustomerId != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB001D).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCB001D).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 16,
                                color: Color(0xFFCB001D),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'شماره تماس: ${_customers.firstWhere((c) => c['id'] == _selectedCustomerId)['phone'] ?? 'نامشخص'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Color(0xFFCB001D),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'آدرس: ${_customers.firstWhere((c) => c['id'] == _selectedCustomerId)['address'] ?? 'نامشخص'}',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _productController,
                    label: 'نام محصول',
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _quantityController,
                          label: 'تعداد',
                          icon: Icons.numbers_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _priceController,
                          label: 'قیمت واحد (ریال)',
                          icon: Icons.attach_money_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
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
                  if (_selectedCustomerId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('لطفاً مشتری را انتخاب کنید'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  if (_productController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('لطفاً نام محصول را وارد کنید'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  final customer = _customers.firstWhere(
                    (c) => c['id'] == _selectedCustomerId,
                  );
                  final quantity = int.tryParse(_quantityController.text) ?? 0;
                  final price = int.tryParse(_priceController.text) ?? 0;
                  final total = quantity * price;

                  setState(() {
                    _salesData.add({
                      'id': 'S-${1000 + _salesData.length + 1}',
                      'customerId': _selectedCustomerId,
                      'customer': customer['name'],
                      'phone': customer['phone'] ?? '',
                      'address': customer['address'] ?? '',
                      'product': _productController.text,
                      'quantity': quantity,
                      'unit': 'متر',
                      'price': price,
                      'total': total,
                      'status': 'در انتظار',
                      'date': DateTime.now().toPersianDate(),
                    });
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('فروش با موفقیت ثبت شد'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCB001D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('ثبت فروش'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editSale(Map<String, dynamic> sale) {
    // پیاده‌سازی ویرایش فروش
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ویرایش فروش در حال توسعه...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _deleteSale(Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'حذف فروش',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          'آیا از حذف فروش "${sale['id']}" مطمئن هستید؟',
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
                _salesData.removeWhere((s) => s['id'] == sale['id']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('فروش با موفقیت حذف شد'),
                  backgroundColor: Colors.red,
                ),
              );
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

  // ======================== ویجت کمکی ========================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
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

  // ======================== ویجت‌های اصلی ========================
  @override
  Widget build(BuildContext context) {
    final filteredData = _salesData.where((sale) {
      final matchesSearch = sale['id'].contains(_searchQuery) ||
          sale['customer'].contains(_searchQuery) ||
          sale['product'].contains(_searchQuery);
      final matchesFilter = _selectedFilter == 'همه' ||
          sale['status'] == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildFilterAndSearch(),
            const SizedBox(height: 20),
            Expanded(child: _buildSalesTable(filteredData)),
          ],
        ),
      ),
    );
  }

  // ======================== هدر ========================
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
              child: const Icon(
                Icons.trending_up_rounded,
                color: Color(0xFFCB001D),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مدیریت فروشات',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  'مدیریت و پیگیری سفارشات فروش و مشتریان',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _addCustomer,
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
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              label: const Text(
                'افزودن مشتری',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _addSale,
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
                'ثبت فروش جدید',
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
    final totalSales = _salesData.fold<int>(
      0,
      (sum, sale) => sum + (sale['total'] as int),
    );
    final totalOrders = _salesData.length;
    final pendingOrders = _salesData.where((s) => s['status'] == 'در انتظار').length;
    final shippedOrders = _salesData.where((s) => s['status'] == 'ارسال شده').length;

    return Row(
      children: [
        _buildStatCard(
          title: 'کل فروش',
          value: totalSales.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          ),
          icon: Icons.attach_money,
          color: const Color(0xFFCB001D),
          subtitle: 'مجموع فروش کل',
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: 'تعداد سفارشات',
          value: totalOrders.toString(),
          icon: Icons.receipt_long,
          color: Colors.blue.shade700,
          subtitle: 'کل سفارشات ثبت شده',
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: 'در انتظار تایید',
          value: pendingOrders.toString(),
          icon: Icons.pending_actions,
          color: Colors.orange.shade700,
          subtitle: 'نیاز به بررسی',
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: 'ارسال شده',
          value: shippedOrders.toString(),
          icon: Icons.local_shipping,
          color: Colors.green.shade700,
          subtitle: 'در مسیر تحویل',
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
    final filters = ['همه', 'تکمیل شده', 'در انتظار', 'ارسال شده', 'لغو شده'];

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
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'جستجو بر اساس شناسه، مشتری یا محصول...',
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
          const SizedBox(width: 16),
          ...filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedFilter = filter);
                },
                backgroundColor: Colors.grey.shade100,
                selectedColor: const Color(0xFFCB001D),
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFFCB001D)
                        : Colors.grey.shade200,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ======================== جدول فروشات ========================
  Widget _buildSalesTable(List<Map<String, dynamic>> data) {
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                Expanded(flex: 1, child: Text('شناسه')),
                Expanded(flex: 2, child: Text('مشتری')),
                Expanded(flex: 2, child: Text('شماره تماس')),
                Expanded(flex: 2, child: Text('محصول')),
                Expanded(flex: 1, child: Text('تعداد')),
                Expanded(flex: 1, child: Text('قیمت کل')),
                Expanded(flex: 1, child: Text('تاریخ')),
                Expanded(flex: 1, child: Text('وضعیت')),
                Expanded(flex: 1, child: Text('عملیات')),
              ],
            ),
          ),
          Expanded(
            child: data.isEmpty
                ? const Center(
                    child: Text(
                      'هیچ فروشی یافت نشد',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final sale = data[index];
                      return _buildTableRow(sale);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> sale) {
    Color statusColor;
    IconData statusIcon;
    switch (sale['status']) {
      case 'تکمیل شده':
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'در انتظار':
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.pending_rounded;
        break;
      case 'ارسال شده':
        statusColor = Colors.blue.shade700;
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'لغو شده':
        statusColor = Colors.red.shade700;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusIcon = Icons.help_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              sale['id'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale['customer'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (sale['address'] != null && sale['address'].isNotEmpty)
                  Text(
                    sale['address'],
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              sale['phone'] ?? '-',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF333333),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              sale['product'],
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${sale['quantity']} ${sale['unit']}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${sale['total'].toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              sale['date'],
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    sale['status'],
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _editSale(sale),
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
                  onPressed: () => _deleteSale(sale),
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
}

// ======================== اکستنشن تاریخ ========================
extension DateExtension on DateTime {
  String toPersianDate() {
    // اینجا می‌توانید تاریخ شمسی را پیاده‌سازی کنید
    // برای نمونه از تاریخ میلادی استفاده می‌کنیم
    return '${year}/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';
  }
}
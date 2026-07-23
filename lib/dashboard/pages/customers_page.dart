import 'package:flutter/material.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final List<Map<String, dynamic>> _customers = [
    {
      'id': 1,
      'name': 'احمد رضایی',
      'code': 'CUS-001',
      'phone': '0912 345 6789',
      'email': 'ahmad@email.com',
      'type': 'شرکت',
      'status': 'فعال',
      'credit': '۱۲,۵۰۰,۰۰۰',
      'city': 'تهران',
    },
    {
      'id': 2,
      'name': 'محمد کریمی',
      'code': 'CUS-002',
      'phone': '0913 456 7890',
      'email': 'mohammad@email.com',
      'type': 'شخصی',
      'status': 'فعال',
      'credit': '۸,۲۰۰,۰۰۰',
      'city': 'اصفهان',
    },
    {
      'id': 3,
      'name': 'سارا حسینی',
      'code': 'CUS-003',
      'phone': '0914 567 8901',
      'email': 'sara@email.com',
      'type': 'شرکت',
      'status': 'غیرفعال',
      'credit': '۰',
      'city': 'شیراز',
    },
    {
      'id': 4,
      'name': 'علی محمدی',
      'code': 'CUS-004',
      'phone': '0915 678 9012',
      'email': 'ali@email.com',
      'type': 'شخصی',
      'status': 'فعال',
      'credit': '۵,۳۰۰,۰۰۰',
      'city': 'مشهد',
    },
  ];

  String _searchQuery = '';

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50, 100];

  // Selection
  final Set<int> _selectedIds = {};

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((customer) {
      return customer['name'].toString().contains(_searchQuery) ||
          customer['code'].toString().contains(_searchQuery) ||
          customer['phone'].toString().contains(_searchQuery) ||
          customer['email'].toString().contains(_searchQuery);
    }).toList();
  }

  // Get paginated data
  List<Map<String, dynamic>> get _paginatedCustomers {
    final filtered = _filteredCustomers;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= filtered.length) {
      _currentPage = 1;
      return filtered.take(_itemsPerPage).toList();
    }
    return filtered.sublist(
      start,
      end > filtered.length ? filtered.length : end,
    );
  }

  int get _totalPages => (_filteredCustomers.length / _itemsPerPage).ceil();

  void _changePage(int newPage) {
    if (newPage >= 1 && newPage <= _totalPages) {
      setState(() {
        _currentPage = newPage;
        _selectedIds.clear();
      });
    }
  }

  void _changeItemsPerPage(int? newSize) {
    if (newSize != null) {
      setState(() {
        _itemsPerPage = newSize;
        _currentPage = 1;
        _selectedIds.clear();
      });
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final currentIds = _paginatedCustomers.map((m) => m['id'] as int).toList();
      final allSelected = currentIds.every((id) => _selectedIds.contains(id));
      if (allSelected) {
        _selectedIds.removeAll(currentIds);
      } else {
        _selectedIds.addAll(currentIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مدیریت مشتریان',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'مدیریت اطلاعات مشتریان و ارتباطات',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFFCB001D),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_selectedIds.length} انتخاب شده',
                              style: const TextStyle(
                                color: Color(0xFFCB001D),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 12),
                    // Export Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFCB001D).withOpacity(0.1),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.download_outlined,
                          color: const Color(0xFFCB001D),
                          size: 22,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📊 گزارش در حال تولید...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Add Button
                    ElevatedButton.icon(
                      onPressed: () {
                        _showAddCustomerDialog(context);
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'افزودن مشتری',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB001D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats Cards
            Row(
              children: [
                _buildStatCard('کل مشتریان', _customers.length.toString(), Icons.people_alt_outlined),
                const SizedBox(width: 16),
                _buildStatCard(
                  'فعال',
                  _customers.where((c) => c['status'] == 'فعال').length.toString(),
                  Icons.check_circle_outline,
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'غیرفعال',
                  _customers.where((c) => c['status'] == 'غیرفعال').length.toString(),
                  Icons.cancel_outlined,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFCB001D).withOpacity(0.1),
                ),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _currentPage = 1;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'جستجوی مشتریان...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: const Color(0xFFCB001D),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Table with Pagination
            Expanded(
              child: Container(
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
                child: _filteredCustomers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'هیچ مشتری‌ای یافت نشد',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Table with Checkbox
                          Expanded(
                            child: ListView.builder(
                              itemCount: _paginatedCustomers.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  // Header Row with Select All
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCB001D).withOpacity(0.05),
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 44,
                                          child: Checkbox(
                                            value: _paginatedCustomers.isNotEmpty &&
                                                _paginatedCustomers.every(
                                                  (m) => _selectedIds.contains(m['id'] as int),
                                                ),
                                            onChanged: (_) => _toggleSelectAll(),
                                            activeColor: const Color(0xFFCB001D),
                                            checkColor: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'نام مشتری',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1A1A2E),
                                            ),
                                          ),
                                        ),
                                        const Expanded(
                                          flex: 1,
                                          child: Text(
                                            'کد',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1A1A2E),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const Expanded(
                                          flex: 1,
                                          child: Text(
                                            'تلفن',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1A1A2E),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const Expanded(
                                          flex: 1,
                                          child: Text(
                                            'شهر',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1A1A2E),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const Expanded(
                                          flex: 1,
                                          child: Text(
                                            'نوع',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1A1A2E),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const Expanded(
                                          flex: 1,
                                          child: Text(
                                            'اعتبار',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFF1A1A2E),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(width: 80),
                                      ],
                                    ),
                                  );
                                }

                                final customer = _paginatedCustomers[index - 1];
                                final isSelected = _selectedIds.contains(customer['id'] as int);

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFCB001D).withOpacity(0.04)
                                        : null,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade100,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Checkbox
                                      SizedBox(
                                        width: 44,
                                        child: Checkbox(
                                          value: isSelected,
                                          onChanged: (_) => _toggleSelection(customer['id'] as int),
                                          activeColor: const Color(0xFFCB001D),
                                          checkColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Name
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer['name'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Color(0xFF1A1A2E),
                                              ),
                                            ),
                                            Text(
                                              customer['email'] ?? '-',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Code
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          customer['code'] ?? '-',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      // Phone
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          customer['phone'] ?? '-',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      // City
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          customer['city'] ?? '-',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      // Type
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: customer['type'] == 'شرکت'
                                                ? Colors.blue.withOpacity(0.1)
                                                : Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            customer['type'] ?? '-',
                                            style: TextStyle(
                                              color: customer['type'] == 'شرکت'
                                                  ? Colors.blue
                                                  : Colors.orange,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      // Credit
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          customer['credit'] ?? '-',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Color(0xFFCB001D),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      // Actions
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit_outlined,
                                              color: const Color(0xFFCB001D),
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              _showEditCustomerDialog(context, customer);
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Colors.red.shade400,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              _showDeleteDialog(context, customer);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          // Pagination Controls
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Items per page
                                Row(
                                  children: [
                                    const Text(
                                      'نمایش:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF888888),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFCB001D).withOpacity(0.2),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _itemsPerPage,
                                          onChanged: _changeItemsPerPage,
                                          items: _pageSizeOptions.map((size) {
                                            return DropdownMenuItem<int>(
                                              value: size,
                                              child: Text(
                                                size.toString(),
                                                style: const TextStyle(
                                                  color: Color(0xFF1A1A2E),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          dropdownColor: Colors.white,
                                          icon: Icon(
                                            Icons.arrow_drop_down,
                                            color: const Color(0xFFCB001D),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'در هر صفحه',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),

                                // Page info and controls
                                Row(
                                  children: [
                                    Text(
                                      'صفحه $_currentPage از $_totalPages',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF888888),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.chevron_right,
                                        color: Color(0xFFCB001D),
                                      ),
                                      onPressed: _currentPage > 1
                                          ? () => _changePage(_currentPage - 1)
                                          : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.chevron_left,
                                        color: Color(0xFFCB001D),
                                      ),
                                      onPressed: _currentPage < _totalPages
                                          ? () => _changePage(_currentPage + 1)
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, [Color? color]) {
    final cardColor = color ?? const Color(0xFFCB001D);
    return Expanded(
      child: Container(
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
            color: cardColor.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cardColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final cityController = TextEditingController();
    final typeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'افزودن مشتری جدید',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('نام مشتری', Icons.person_outline, nameController),
              const SizedBox(height: 12),
              _buildTextField('شماره تلفن', Icons.phone_outlined, phoneController),
              const SizedBox(height: 12),
              _buildTextField('ایمیل', Icons.email_outlined, emailController),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField('شهر', Icons.location_city_outlined, cityController),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField('نوع', Icons.business_outlined, typeController),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'انصراف',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ مشتری با موفقیت اضافه شد'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB001D),
            ),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(BuildContext context, Map<String, dynamic> customer) {
    final nameController = TextEditingController(text: customer['name']);
    final phoneController = TextEditingController(text: customer['phone']);
    final emailController = TextEditingController(text: customer['email']);
    final cityController = TextEditingController(text: customer['city']);
    final typeController = TextEditingController(text: customer['type']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ویرایش مشتری',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('نام مشتری', Icons.person_outline, nameController),
              const SizedBox(height: 12),
              _buildTextField('شماره تلفن', Icons.phone_outlined, phoneController),
              const SizedBox(height: 12),
              _buildTextField('ایمیل', Icons.email_outlined, emailController),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField('شهر', Icons.location_city_outlined, cityController),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField('نوع', Icons.business_outlined, typeController),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'انصراف',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ مشتری با موفقیت ویرایش شد'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB001D),
            ),
            child: const Text('به‌روزرسانی'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'حذف مشتری',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
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
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ مشتری با موفقیت حذف شد'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFFCB001D),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFCB001D), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: const Color(0xFFCB001D).withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFCB001D),
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: const Color(0xFFCB001D).withOpacity(0.2),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
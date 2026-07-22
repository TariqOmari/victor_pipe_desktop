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

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((customer) {
      return customer['name'].toString().contains(_searchQuery) ||
          customer['code'].toString().contains(_searchQuery) ||
          customer['phone'].toString().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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

          // Table
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
                  : ListView.builder(
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade100,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCB001D).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    customer['name'][0],
                                    style: const TextStyle(
                                      color: Color(0xFFCB001D),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Name & Code
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    Text(
                                      'کد: ${customer['code']}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Phone
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'تلفن',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      customer['phone'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // City & Type
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      customer['city'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: customer['type'] == 'شرکت'
                                            ? Colors.blue.withOpacity(0.1)
                                            : Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        customer['type'],
                                        style: TextStyle(
                                          color: customer['type'] == 'شرکت'
                                              ? Colors.blue
                                              : Colors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Credit
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'اعتبار',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '${customer['credit']} تومان',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFFCB001D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Status
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: customer['status'] == 'فعال'
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      customer['status'] == 'فعال'
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: customer['status'] == 'فعال'
                                          ? Colors.green
                                          : Colors.red,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      customer['status'],
                                      style: TextStyle(
                                        color: customer['status'] == 'فعال'
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
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
          ),
        ],
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
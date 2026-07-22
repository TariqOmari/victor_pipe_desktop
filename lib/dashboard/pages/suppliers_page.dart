import 'package:flutter/material.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final List<Map<String, dynamic>> _suppliers = [
    {
      'id': 1,
      'name': 'تامین پلیمر تهران',
      'code': 'SUP-001',
      'phone': '021 1234 5678',
      'mobile': '0912 345 6789',
      'address': 'تهران، خیابان آزادی، پلاک ۱۲۳',
      'type': 'تامین‌کننده اصلی',
      'status': 'فعال',
      'products': 'پلی اتیلن، پی وی سی',
      'credit': '۵۰,۰۰۰,۰۰۰',
    },
    {
      'id': 2,
      'name': 'صنایع پترو',
      'code': 'SUP-002',
      'phone': '031 2345 6789',
      'mobile': '0913 456 7890',
      'address': 'اصفهان، شهرک صنعتی، خیابان دوم',
      'type': 'تامین‌کننده',
      'status': 'فعال',
      'products': 'مواد شیمیایی، پلیمر',
      'credit': '۳۵,۰۰۰,۰۰۰',
    },
    {
      'id': 3,
      'name': 'روغن پارس',
      'code': 'SUP-003',
      'phone': '021 8765 4321',
      'mobile': '0914 567 8901',
      'address': 'تهران، جاده مخصوص، پلاک ۴۵',
      'type': 'تامین‌کننده',
      'status': 'فعال',
      'products': 'روغن صنعتی، گریس',
      'credit': '۲۰,۰۰۰,۰۰۰',
    },
    {
      'id': 4,
      'name': 'رنگین صنعت',
      'code': 'SUP-004',
      'phone': '071 3456 7890',
      'mobile': '0915 678 9012',
      'address': 'شیراز، بلوار معلم، پلاک ۶۷',
      'type': 'تامین‌کننده',
      'status': 'غیرفعال',
      'products': 'رنگ، مواد رنگی',
      'credit': '۰',
    },
    {
      'id': 5,
      'name': 'چسب پارس',
      'code': 'SUP-005',
      'phone': '021 9876 5432',
      'mobile': '0916 789 0123',
      'address': 'تهران، خیابان ولیعصر، پلاک ۸۹',
      'type': 'تامین‌کننده',
      'status': 'فعال',
      'products': 'چسب صنعتی، چسب حرارتی',
      'credit': '۱۵,۰۰۰,۰۰۰',
    },
  ];

  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredSuppliers {
    if (_searchQuery.isEmpty) return _suppliers;
    return _suppliers.where((supplier) {
      return supplier['name'].toString().contains(_searchQuery) ||
          supplier['code'].toString().contains(_searchQuery) ||
          supplier['phone'].toString().contains(_searchQuery) ||
          supplier['mobile'].toString().contains(_searchQuery);
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
                    'مدیریت فروشندگان',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'مدیریت اطلاعات فروشندگان و تامین‌کنندگان',
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
                      _showAddSupplierDialog(context);
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'افزودن فروشنده',
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
              _buildStatCard('کل فروشندگان', _suppliers.length.toString(), Icons.business_outlined),
              const SizedBox(width: 16),
              _buildStatCard(
                'فعال',
                _suppliers.where((s) => s['status'] == 'فعال').length.toString(),
                Icons.check_circle_outline,
                Colors.green,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'غیرفعال',
                _suppliers.where((s) => s['status'] == 'غیرفعال').length.toString(),
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
                hintText: 'جستجوی فروشندگان...',
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
              child: _filteredSuppliers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'هیچ فروشنده‌ای یافت نشد',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredSuppliers.length,
                      itemBuilder: (context, index) {
                        final supplier = _filteredSuppliers[index];
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
                                    supplier['name'][0],
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
                                      supplier['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    Text(
                                      'کد: ${supplier['code']}',
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
                                      supplier['phone'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Mobile
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'موبایل',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      supplier['mobile'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Address
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'آدرس',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      supplier['address'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Products
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'محصولات',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      supplier['products'] ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                  color: supplier['status'] == 'فعال'
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      supplier['status'] == 'فعال'
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: supplier['status'] == 'فعال'
                                          ? Colors.green
                                          : Colors.red,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      supplier['status'],
                                      style: TextStyle(
                                        color: supplier['status'] == 'فعال'
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
                                      _showEditSupplierDialog(context, supplier);
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red.shade400,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _showDeleteDialog(context, supplier);
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

  void _showAddSupplierDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final mobileController = TextEditingController();
    final addressController = TextEditingController();
    final typeController = TextEditingController();
    final productsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'افزودن فروشنده جدید',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('نام فروشنده', Icons.business_outlined, nameController),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField('تلفن', Icons.phone_outlined, phoneController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField('موبایل', Icons.smartphone_outlined, mobileController),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField('آدرس', Icons.location_on_outlined, addressController),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField('نوع', Icons.category_outlined, typeController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField('محصولات', Icons.inventory_2_outlined, productsController),
                    ),
                  ],
                ),
              ],
            ),
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
                  content: Text('✅ فروشنده با موفقیت اضافه شد'),
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

  void _showEditSupplierDialog(BuildContext context, Map<String, dynamic> supplier) {
    final nameController = TextEditingController(text: supplier['name']);
    final phoneController = TextEditingController(text: supplier['phone']);
    final mobileController = TextEditingController(text: supplier['mobile']);
    final addressController = TextEditingController(text: supplier['address']);
    final typeController = TextEditingController(text: supplier['type']);
    final productsController = TextEditingController(text: supplier['products'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ویرایش فروشنده',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('نام فروشنده', Icons.business_outlined, nameController),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField('تلفن', Icons.phone_outlined, phoneController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField('موبایل', Icons.smartphone_outlined, mobileController),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField('آدرس', Icons.location_on_outlined, addressController),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField('نوع', Icons.category_outlined, typeController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField('محصولات', Icons.inventory_2_outlined, productsController),
                    ),
                  ],
                ),
              ],
            ),
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
                  content: Text('✅ فروشنده با موفقیت ویرایش شد'),
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

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'حذف فروشنده',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        content: Text(
          'آیا از حذف فروشنده "${supplier['name']}" مطمئن هستید؟',
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
                  content: Text('✅ فروشنده با موفقیت حذف شد'),
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
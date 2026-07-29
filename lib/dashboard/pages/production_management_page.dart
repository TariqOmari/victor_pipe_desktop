import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';

class ProductionManagementPage extends StatefulWidget {
  const ProductionManagementPage({super.key});

  @override
  State<ProductionManagementPage> createState() => _ProductionManagementPageState();
}

class _ProductionManagementPageState extends State<ProductionManagementPage> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> productions = [];
  bool isLoading = true;

  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50, 100];
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final data = await _db.getProducedProductsWithSaleStatus();
      if (!mounted) return;
      setState(() {
        productions = data;
        isLoading = false;
        _selectedIds.clear();
        _currentPage = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ خطا در بارگذاری اطلاعات تولید'), backgroundColor: Colors.red),
      );
    }
  }

  List<Map<String, dynamic>> get _paginatedProductions {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= productions.length) {
      _currentPage = 1;
      return productions.take(_itemsPerPage).toList();
    }
    return productions.sublist(start, end > productions.length ? productions.length : end);
  }

  int get _totalPages {
    if (productions.isEmpty) return 1;
    return (productions.length / _itemsPerPage).ceil();
  }

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
      final currentIds = _paginatedProductions.map((item) => item['id'] as int).toList();
      final allSelected = currentIds.every((id) => _selectedIds.contains(id));
      if (allSelected) {
        _selectedIds.removeAll(currentIds);
      } else {
        _selectedIds.addAll(currentIds);
      }
    });
  }

  Map<String, double> _getUnitTotals() {
    final totals = <String, double>{};
    for (final product in productions) {
      final unit = product['unit']?.toString() ?? 'نامشخص';
      final quantity = double.tryParse(product['quantity']?.toString() ?? '0') ?? 0;
      final weight = double.tryParse(product['weight']?.toString() ?? '0') ?? 0;
      totals[unit] = (totals[unit] ?? 0) + quantity + weight;
    }
    return totals;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: color.withOpacity(0.08), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مدیریت تولید', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
            SizedBox(height: 2),
            Text('ثبت، مشاهده و مدیریت موجودی محصولات تولیدشده', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
          ],
        ),
        Row(
          children: [
            if (_selectedIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFFCB001D), size: 14),
                    const SizedBox(width: 4),
                    Text('${_selectedIds.length} انتخاب شده', style: const TextStyle(color: Color(0xFFCB001D), fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showProductDialog(context),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text('ثبت تولید جدید', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    final total = productions.length;
    final completed = productions.where((p) => p['status'] == 'تکمیل شده').length;
    final inProgress = productions.where((p) => p['status'] == 'در حال تولید').length;
    final pending = productions.where((p) => p['status'] == 'در انتظار').length;

    return Row(
      children: [
        _buildStatCard('کل تولیدات', total.toString(), Icons.factory_rounded, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard('تکمیل شده', completed.toString(), Icons.check_circle_rounded, Colors.green.shade700),
        const SizedBox(width: 12),
        _buildStatCard('در حال تولید', inProgress.toString(), Icons.pending_rounded, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard('در انتظار', pending.toString(), Icons.hourglass_empty_rounded, Colors.orange.shade700),
      ],
    );
  }

  List<Widget> _buildUnitCards() {
    final unitTotals = _getUnitTotals();
    if (unitTotals.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.06), width: 1),
          ),
          child: const Text('هیچ محصولی ثبت نشده است', style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
        ),
      ];
    }

    return unitTotals.entries.map((entry) {
      final itemCount = productions.where((item) => (item['unit'] ?? 'نامشخص').toString() == entry.key).length;
      return Container(
        width: 190,
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
          border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.06), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFFCB001D), size: 14),
                ),
                const SizedBox(width: 6),
                Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFCB001D))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('مجموع: ', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                Text(entry.value.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E))),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('تعداد اقلام: ', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                Text(itemCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E))),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildDataCell(String text, double width, {bool isBold = false, bool isRed = false}) {
    return SizedBox(
      width: width,
      child: Text(text, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isRed ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E), fontSize: 9), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'تکمیل شده':
        color = Colors.green.shade700;
        icon = Icons.check_circle_rounded;
        break;
      case 'در حال تولید':
        color = Colors.blue.shade700;
        icon = Icons.pending_rounded;
        break;
      case 'در انتظار':
        color = Colors.orange.shade700;
        icon = Icons.hourglass_empty_rounded;
        break;
      default:
        color = Colors.grey.shade600;
        icon = Icons.help_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(status ?? '-', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSoldStatusChip(bool isSold, int saleCount) {
    if (isSold) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sell, color: Colors.red, size: 10),
            const SizedBox(width: 2),
            Text(
              'فروخته شد ($saleCount)',
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.check_circle, color: Colors.green, size: 10),
          SizedBox(width: 2),
          Text(
            'موجود',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  void _showProductDialog(BuildContext context, {Map<String, dynamic>? product}) {
    final isEditing = product != null;
    final nameController = TextEditingController(text: product?['product_name']?.toString() ?? '');
    final typeController = TextEditingController(text: product?['production_type']?.toString() ?? '');
    final loadingController = TextEditingController(text: product?['loading']?.toString() ?? '');
    final thicknessController = TextEditingController(text: product?['thickness']?.toString() ?? '');
    final lengthController = TextEditingController(text: product?['length']?.toString() ?? '');
    final quantityController = TextEditingController(text: product?['quantity']?.toString() ?? '');
    final weightController = TextEditingController(text: product?['weight']?.toString() ?? '');
    final unitController = TextEditingController(text: product?['unit']?.toString() ?? '');
    final dateController = TextEditingController(text: product?['production_date']?.toString() ?? '');
    final batchController = TextEditingController(text: product?['batch']?.toString() ?? '');
    final descriptionController = TextEditingController(text: product?['description']?.toString() ?? '');

    String? selectedEnglishDate = product?['production_date_en']?.toString();
    String? selectedUnit = product?['unit']?.toString() ?? 'متر';
    String? selectedStatus = product?['status']?.toString() ?? 'در حال تولید';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(isEditing ? 'ویرایش محصول تولیدی' : 'ثبت محصول تولیدی جدید'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'نام محصول *', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: typeController,
                        decoration: const InputDecoration(labelText: 'نوع تولید *', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: loadingController,
                        decoration: const InputDecoration(labelText: 'بارگیری', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: thicknessController,
                              decoration: const InputDecoration(labelText: 'ضخامت', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lengthController,
                              decoration: const InputDecoration(labelText: 'طول', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              decoration: const InputDecoration(labelText: 'تعداد تولید *', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: weightController,
                              decoration: const InputDecoration(labelText: 'وزن تولید', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'واحد *', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              value: selectedUnit,
                              items: const [
                                DropdownMenuItem(value: 'متر', child: Text('متر')),
                                DropdownMenuItem(value: 'عدد', child: Text('عدد')),
                                DropdownMenuItem(value: 'کیلوگرم', child: Text('کیلوگرم')),
                                DropdownMenuItem(value: 'تن', child: Text('تن')),
                              ],
                              onChanged: (value) => setDialogState(() => selectedUnit = value),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: dateController,
                              decoration: InputDecoration(labelText: 'تاریخ *', border: const OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              readOnly: true,
                              onTap: () async {
                                DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                                if (picked != null) {
                                  final persianDate = PersianDateConverter.gregorianToJalali(picked);
                                  final englishDate = PersianDateConverter.getEnglishDate(picked);
                                  setDialogState(() {
                                    dateController.text = persianDate;
                                    selectedEnglishDate = englishDate;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'وضعیت', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                        value: selectedStatus,
                        items: const [
                          DropdownMenuItem(value: 'در حال تولید', child: Text('در حال تولید')),
                          DropdownMenuItem(value: 'تکمیل شده', child: Text('تکمیل شده')),
                          DropdownMenuItem(value: 'در انتظار', child: Text('در انتظار')),
                        ],
                        onChanged: (value) => setDialogState(() => selectedStatus = value),
                      ),
                      const SizedBox(height: 8),
                      TextField(controller: batchController, decoration: const InputDecoration(labelText: 'شماره بچ', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                      const SizedBox(height: 8),
                      TextField(controller: descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: 'توضیحات', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف', style: TextStyle(color: Color(0xFF888888)))),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || quantityController.text.isEmpty || selectedUnit == null || dateController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لطفاً فیلدهای ضروری را پر کنید'), backgroundColor: Colors.red));
                      return;
                    }

                    final payload = {
                      'product_name': nameController.text,
                      'production_type': typeController.text,
                      'loading': loadingController.text,
                      'thickness': thicknessController.text,
                      'length': lengthController.text,
                      'quantity': int.tryParse(quantityController.text) ?? 0,
                      'weight': weightController.text,
                      'unit': selectedUnit,
                      'production_date': dateController.text,
                      'production_date_en': selectedEnglishDate ?? '',
                      'status': selectedStatus ?? 'در حال تولید',
                      'batch': batchController.text,
                      'description': descriptionController.text,
                    };

                    Navigator.pop(context);
                    final result = isEditing ? await _db.updateProducedProduct(product!['id'], payload) : await _db.insertProducedProduct(payload);
                    if (!mounted) return;
                    if (result != -1) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? '✅ محصول با موفقیت به‌روزرسانی شد' : '✅ محصول با موفقیت ثبت شد'), backgroundColor: Colors.green));
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ خطا در ذخیره‌سازی'), backgroundColor: Colors.red));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D)),
                  child: Text(isEditing ? 'به‌روزرسانی' : 'ذخیره'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف محصول تولیدی'),
          content: Text('آیا از حذف محصول "${product['product_name']}" مطمئن هستید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف', style: TextStyle(color: Color(0xFF888888)))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await _db.deleteProducedProduct(product['id']);
                if (!mounted) return;
                if (result != -1) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ محصول حذف شد'), backgroundColor: Colors.green));
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ خطا در حذف محصول'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildStatsCards(),
            const SizedBox(height: 12),
            const Text('خلاصه تولیدات بر اساس واحد:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 6),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _buildUnitCards())),
            const SizedBox(height: 14),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
                  : productions.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.factory_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('هنوز محصولی ثبت نشده است', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
                                  border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.06), width: 1),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final totalWidth = constraints.maxWidth - 60;
                                    final columnWidths = {
                                      'checkbox': 40.0,
                                      'id': totalWidth * 0.05,
                                      'product': totalWidth * 0.12,
                                      'type': totalWidth * 0.07,
                                      'thickness': totalWidth * 0.06,
                                      'length': totalWidth * 0.06,
                                      'quantity': totalWidth * 0.07,
                                      'weight': totalWidth * 0.07,
                                      'unit': totalWidth * 0.06,
                                      'date': totalWidth * 0.08,
                                      'status': totalWidth * 0.08,
                                      'batch': totalWidth * 0.07,
                                      'saleStatus': totalWidth * 0.09,
                                      'actions': totalWidth * 0.08,
                                    };

                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: columnWidths.values.reduce((a, b) => a + b) + 60,
                                        child: ListView.builder(
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _paginatedProductions.length + 1,
                                          itemBuilder: (context, index) {
                                            if (index == 0) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.05), border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5))),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: columnWidths['checkbox'],
                                                      child: Checkbox(
                                                        value: _paginatedProductions.isNotEmpty && _paginatedProductions.every((p) => _selectedIds.contains(p['id'] as int)),
                                                        onChanged: (_) => _toggleSelectAll(),
                                                        activeColor: const Color(0xFFCB001D),
                                                        checkColor: Colors.white,
                                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    ),
                                                    _buildHeaderCell('شناسه', columnWidths['id']!),
                                                    _buildHeaderCell('نام محصول', columnWidths['product']!),
                                                    _buildHeaderCell('نوع', columnWidths['type']!),
                                                    _buildHeaderCell('ضخامت', columnWidths['thickness']!),
                                                    _buildHeaderCell('طول', columnWidths['length']!),
                                                    _buildHeaderCell('تعداد', columnWidths['quantity']!),
                                                    _buildHeaderCell('وزن', columnWidths['weight']!),
                                                    _buildHeaderCell('واحد', columnWidths['unit']!),
                                                    _buildHeaderCell('تاریخ', columnWidths['date']!),
                                                    _buildHeaderCell('وضعیت', columnWidths['status']!),
                                                    _buildHeaderCell('بچ', columnWidths['batch']!),
                                                    _buildHeaderCell('وضعیت فروش', columnWidths['saleStatus']!),
                                                    _buildHeaderCell('عملیات', columnWidths['actions']!),
                                                  ],
                                                ),
                                              );
                                            }

                                            final product = _paginatedProductions[index - 1];
                                            final isSelected = _selectedIds.contains(product['id'] as int);
                                            final isSold = (product['is_sold'] == 1 || product['is_sold']?.toString() == '1');
                                            final saleCount = (product['sale_count'] as int? ?? 0);

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isSelected ? const Color(0xFFCB001D).withOpacity(0.04) : null,
                                                border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: columnWidths['checkbox'],
                                                    child: Checkbox(
                                                      value: isSelected,
                                                      onChanged: (_) => _toggleSelection(product['id'] as int),
                                                      activeColor: const Color(0xFFCB001D),
                                                      checkColor: Colors.white,
                                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                  ),
                                                  _buildDataCell(product['id'].toString(), columnWidths['id']!),
                                                  _buildDataCell(product['product_name']?.toString() ?? '-', columnWidths['product']!),
                                                  _buildDataCell(product['production_type']?.toString() ?? '-', columnWidths['type']!),
                                                  _buildDataCell(product['thickness']?.toString() ?? '-', columnWidths['thickness']!),
                                                  _buildDataCell(product['length']?.toString() ?? '-', columnWidths['length']!),
                                                  _buildDataCell(product['quantity'].toString(), columnWidths['quantity']!, isBold: true),
                                                  _buildDataCell(product['weight']?.toString() ?? '-', columnWidths['weight']!),
                                                  _buildDataCell(product['unit']?.toString() ?? '-', columnWidths['unit']!),
                                                  _buildDataCell('${product['production_date']?.toString() ?? '-'}\n${product['production_date_en']?.toString() ?? '-'}', columnWidths['date']!),
                                                  SizedBox(width: columnWidths['status']!, child: _buildStatusChip(product['status']?.toString())),
                                                  _buildDataCell(product['batch']?.toString() ?? '-', columnWidths['batch']!),
                                                  SizedBox(
                                                    width: columnWidths['saleStatus']!,
                                                    child: _buildSoldStatusChip(isSold, saleCount),
                                                  ),
                                                  SizedBox(
                                                    width: columnWidths['actions']!,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.edit_outlined, color: Color(0xFFCB001D), size: 16),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          onPressed: () => _showProductDialog(context, product: product),
                                                        ),
                                                        IconButton(
                                                          icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 16),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          onPressed: () => _showDeleteDialog(context, product),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                                border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('نمایش:', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)), borderRadius: BorderRadius.circular(6)),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _itemsPerPage,
                                            onChanged: _changeItemsPerPage,
                                            items: _pageSizeOptions.map((size) => DropdownMenuItem<int>(
                                              value: size,
                                              child: Text(size.toString(), style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 12)),
                                            )).toList(),
                                            dropdownColor: Colors.white,
                                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFCB001D), size: 18),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text('در هر صفحه', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text('صفحه $_currentPage از $_totalPages', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right, color: Color(0xFFCB001D), size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left, color: Color(0xFFCB001D), size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null,
                                      ),
                                    ],
                                  ),
                                ],
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
}
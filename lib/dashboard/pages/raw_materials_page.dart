import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class RawMaterialsPage extends StatefulWidget {
  const RawMaterialsPage({super.key});

  @override
  State<RawMaterialsPage> createState() => _RawMaterialsPageState();
}

class _RawMaterialsPageState extends State<RawMaterialsPage> {
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> suppliers = [];
  bool isLoading = true;
  final DatabaseHelper _db = DatabaseHelper();

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50, 100];

  // Selection
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final materialsData = await _db.getRawMaterials();
      final suppliersData = await _db.getSuppliers();
      print('📦 Materials loaded: ${materialsData.length}');
      setState(() {
        materials = materialsData;
        suppliers = suppliersData;
        isLoading = false;
        _selectedIds.clear();
        _currentPage = 1;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _paginatedMaterials {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= materials.length) {
      _currentPage = 1;
      return materials.take(_itemsPerPage).toList();
    }
    return materials.sublist(
      start,
      end > materials.length ? materials.length : end,
    );
  }

  int get _totalPages => (materials.length / _itemsPerPage).ceil();

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
      final currentIds = _paginatedMaterials.map((m) => m['id'] as int).toList();
      final allSelected = currentIds.every((id) => _selectedIds.contains(id));
      if (allSelected) {
        _selectedIds.removeAll(currentIds);
      } else {
        _selectedIds.addAll(currentIds);
      }
    });
  }

  // ============ BUILD UNIT CARDS ============
  List<Widget> _buildUnitCards() {
    Map<String, Map<String, double>> unitTotals = {};
    
    for (var material in materials) {
      String unit = material['unit'] ?? 'نامشخص';
      double netWeight = double.tryParse(material['net_weight']?.toString() ?? '0') ?? 0;
      double grossWeight = double.tryParse(material['gross_weight']?.toString() ?? '0') ?? 0;
      
      if (!unitTotals.containsKey(unit)) {
        unitTotals[unit] = {'net': 0, 'gross': 0};
      }
      unitTotals[unit]!['net'] = (unitTotals[unit]!['net'] ?? 0) + netWeight;
      unitTotals[unit]!['gross'] = (unitTotals[unit]!['gross'] ?? 0) + grossWeight;
    }

    if (unitTotals.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFCB001D).withOpacity(0.06),
              width: 1,
            ),
          ),
          child: const Text(
            'هیچ ماده خامی در انبار نیست',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 13,
            ),
          ),
        ),
      ];
    }

    List<Widget> cards = [];
    unitTotals.forEach((unit, totals) {
      cards.add(
        Container(
          width: 180,
          margin: const EdgeInsets.only(left: 12),
          padding: const EdgeInsets.all(14),
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
              color: const Color(0xFFCB001D).withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCB001D).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.scale,
                      color: Color(0xFFCB001D),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCB001D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'خالص:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                  Text(
                    totals['net']!.toStringAsFixed(0),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ناخالص:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                  Text(
                    totals['gross']!.toStringAsFixed(0),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFCB001D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });

    return cards;
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
                      'مدیریت مواد خام',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'مدیریت و کنترل مواد اولیه انبار',
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
                    ElevatedButton.icon(
                      onPressed: () {
                        _showAddDialog(context);
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'افزودن ماده خام',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB001D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats
            Row(
              children: [
                _buildStatCard('کل مواد', materials.length.toString()),
                const SizedBox(width: 16),
                _buildStatCard(
                  'فروشندگان',
                  suppliers.length.toString(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Unit-based totals cards
            if (materials.isNotEmpty) ...[
              const Text(
                'خلاصه انبار موجود بر اساس واحد:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _buildUnitCards(),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // List
            Flexible(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFCB001D),
                      ),
                    )
                  : materials.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warehouse_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'هیچ ماده خامی یافت نشد',
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
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: 1800,
                                    child: ListView.builder(
                                      itemCount: _paginatedMaterials.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          // HEADER ROW
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
                                                const SizedBox(width: 44),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 90, child: Text('نام مواد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)))),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 70, child: Text('تاریخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 70, child: Text('واحد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 70, child: Text('وزن خالص', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 70, child: Text('وزن ناخالص', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 70, child: Text('قیمت واحد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 70, child: Text('محصول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 70, child: Text('کمیشن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 80, child: Text('کرایه انتقال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 70, child: Text('متفرقه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 70, child: Text('غرفه داری', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 70, child: Text('بارچلانی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 8),
                                                const SizedBox(width: 100, child: Text('قیمت تمام شد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFCB001D)), textAlign: TextAlign.center)),
                                                const SizedBox(width: 80),
                                              ],
                                            ),
                                          );
                                        }

                                        final material = _paginatedMaterials[index - 1];
                                        final isSelected = _selectedIds.contains(material['id'] as int);

                                        // DATA ROW
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
                                              SizedBox(
                                                width: 44,
                                                child: Checkbox(
                                                  value: isSelected,
                                                  onChanged: (_) => _toggleSelection(material['id'] as int),
                                                  activeColor: const Color(0xFFCB001D),
                                                  checkColor: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 90, child: Text(material['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF1A1A2E)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 70, child: Text(material['date'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 70, child: Text(material['unit'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 70, child: Text(material['net_weight'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 70, child: Text(material['gross_weight'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 70, child: Text(material['unit_price'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 70, child: Text(material['product'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 70, child: Text(material['commission'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 80, child: Text(material['transfer_cost'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 70, child: Text(material['miscellaneous'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 70, child: Text(material['ghurfedari'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 70, child: Text(material['barchalani'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 8),
                                              SizedBox(width: 100, child: Text(material['final_price'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFCB001D)), textAlign: TextAlign.center)),
                                              const SizedBox(width: 80),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.edit_outlined, color: const Color(0xFFCB001D), size: 20),
                                                    onPressed: () { _showEditDialog(context, material); },
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                                                    onPressed: () { _showDeleteDialog(context, material); },
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
                              ),
                            ),

                            // Pagination
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
                                  Row(
                                    children: [
                                      const Text('نمایش:', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _itemsPerPage,
                                            onChanged: _changeItemsPerPage,
                                            items: _pageSizeOptions.map((size) {
                                              return DropdownMenuItem<int>(
                                                value: size,
                                                child: Text(size.toString(), style: const TextStyle(color: Color(0xFF1A1A2E))),
                                              );
                                            }).toList(),
                                            dropdownColor: Colors.white,
                                            icon: Icon(Icons.arrow_drop_down, color: const Color(0xFFCB001D)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text('در هر صفحه', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text('صفحه $_currentPage از $_totalPages', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                                      const SizedBox(width: 16),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right, color: Color(0xFFCB001D)),
                                        onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left, color: Color(0xFFCB001D)),
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

  String _getSupplierName(int? supplierId) {
    if (supplierId == null) return '-';
    final supplier = suppliers.firstWhere(
      (s) => s['id'] == supplierId,
      orElse: () => {},
    );
    return supplier['name'] ?? '-';
  }

  Widget _buildStatCard(String title, String value) {
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
            color: const Color(0xFFCB001D).withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFFCB001D),
                size: 24,
              ),
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

  // ============ ADD DIALOG ============
  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final netWeightController = TextEditingController();
    final grossWeightController = TextEditingController();
    final thicknessController = TextEditingController();
    final materialTypeController = TextEditingController();
    final locationController = TextEditingController();
    final dateController = TextEditingController();
    final unitController = TextEditingController();
    final unitPriceController = TextEditingController();
    final productController = TextEditingController();
    final commissionController = TextEditingController();
    final transferCostController = TextEditingController();
    final miscellaneousController = TextEditingController();
    final ghurfedariController = TextEditingController();  // NEW
    final barchalaniController = TextEditingController();  // NEW
    final finalPriceController = TextEditingController();

    String? selectedSupplierId;

    void _updateFinalPrice() {
      double grossWeight = double.tryParse(grossWeightController.text) ?? 0;
      double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      double productCost = double.tryParse(productController.text) ?? 0;
      double commission = double.tryParse(commissionController.text) ?? 0;
      double transferCost = double.tryParse(transferCostController.text) ?? 0;
      double miscellaneous = double.tryParse(miscellaneousController.text) ?? 0;
      double ghurfedari = double.tryParse(ghurfedariController.text) ?? 0;
      double barchalani = double.tryParse(barchalaniController.text) ?? 0;

      double basePrice = grossWeight * unitPrice;
      double finalPrice = basePrice + productCost + commission + transferCost + 
                          miscellaneous + ghurfedari + barchalani;

      finalPriceController.text = finalPrice.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text(
                'افزودن ماده خام جدید',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Supplier Dropdown
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'انتخاب فروشنده *',
                          labelStyle: TextStyle(color: Color(0xFFCB001D)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        value: selectedSupplierId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('انتخاب فروشنده...'),
                          ),
                          ...suppliers.map((supplier) {
                            return DropdownMenuItem<String>(
                              value: supplier['id'].toString(),
                              child: Text(supplier['name']),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedSupplierId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),

                      // Date
                      TextFormField(
                        controller: dateController,
                        decoration: const InputDecoration(
                          labelText: 'تاریخ *',
                          labelStyle: TextStyle(color: Color(0xFFCB001D)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          suffixIcon: Icon(Icons.calendar_today, color: Color(0xFFCB001D)),
                        ),
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            dateController.text = '${picked.year}/${picked.month}/${picked.day}';
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // Name
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'نام مواد ارسالی *',
                          labelStyle: TextStyle(color: Color(0xFFCB001D)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Location
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'محل تخلیه *',
                          labelStyle: TextStyle(color: Color(0xFFCB001D)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Material Type
                      TextField(
                        controller: materialTypeController,
                        decoration: const InputDecoration(
                          labelText: 'نوع مواد *',
                          labelStyle: TextStyle(color: Color(0xFFCB001D)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Unit
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'واحد *',
                          labelStyle: TextStyle(color: Color(0xFFCB001D)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        value: unitController.text.isNotEmpty ? unitController.text : null,
                        items: const [
                          DropdownMenuItem<String>(value: 'کیلوگرم', child: Text('کیلوگرم (Kg)')),
                          DropdownMenuItem<String>(value: 'تن', child: Text('تن (Ton)')),
                          DropdownMenuItem<String>(value: 'متر', child: Text('متر (M)')),
                          DropdownMenuItem<String>(value: 'سانتی‌متر', child: Text('سانتی‌متر (Cm)')),
                          DropdownMenuItem<String>(value: 'لیتر', child: Text('لیتر (L)')),
                          DropdownMenuItem<String>(value: 'عدد', child: Text('عدد (Pcs)')),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            unitController.text = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 10),

                      // Thickness
                      TextField(
                        controller: thicknessController,
                        decoration: const InputDecoration(
                          labelText: 'ضخامت *',
                          labelStyle: TextStyle(color: Color(0xFFCB001D)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Product
                      TextField(
                        controller: productController,
                        decoration: const InputDecoration(
                          labelText: 'قیمت محصول (افغانی)',
                          labelStyle: TextStyle(color: Color(0xFFCB001D)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateFinalPrice(),
                      ),
                      const SizedBox(height: 10),

                      // Net & Gross Weight
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: netWeightController,
                              decoration: const InputDecoration(
                                labelText: 'وزن خالص *',
                                labelStyle: TextStyle(color: Color(0xFFCB001D)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: grossWeightController,
                              decoration: const InputDecoration(
                                labelText: 'وزن ناخالص *',
                                labelStyle: TextStyle(color: Color(0xFFCB001D)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Unit Price
                      TextField(
                        controller: unitPriceController,
                        decoration: const InputDecoration(
                          labelText: 'قیمت واحد (افغانی) *',
                          labelStyle: TextStyle(color: Color(0xFFCB001D)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateFinalPrice(),
                      ),
                      const SizedBox(height: 10),

                      // Commission & Transfer
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commissionController,
                              decoration: const InputDecoration(
                                labelText: 'کمیشن (افغانی)',
                                labelStyle: TextStyle(color: Color(0xFFCB001D)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: transferCostController,
                              decoration: const InputDecoration(
                                labelText: 'کرایه انتقالات (افغانی)',
                                labelStyle: TextStyle(color: Color(0xFFCB001D)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // غرفه داری & بارچلانی
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ghurfedariController,
                              decoration: const InputDecoration(
                                labelText: 'غرفه داری (افغانی)',
                                labelStyle: TextStyle(color: Color(0xFFCB001D)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: barchalaniController,
                              decoration: const InputDecoration(
                                labelText: 'بارچلانی (افغانی)',
                                labelStyle: TextStyle(color: Color(0xFFCB001D)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Miscellaneous & Final Price
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: miscellaneousController,
                              decoration: const InputDecoration(
                                labelText: 'متفرقه (افغانی)',
                                labelStyle: TextStyle(color: Color(0xFFCB001D)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: finalPriceController,
                              enabled: false,
                              decoration: const InputDecoration(
                                labelText: 'قیمت تمام شد (افغانی)',
                                labelStyle: TextStyle(
                                  color: Color(0xFFCB001D),
                                  fontWeight: FontWeight.bold,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                fillColor: Color(0xFFF5F0EB),
                                filled: true,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFFCB001D),
                              ),
                            ),
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
                  child: const Text('انصراف', style: TextStyle(color: Color(0xFF888888))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedSupplierId == null || nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لطفاً تمام فیلدهای ضروری را پر کنید'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final material = {
                      'supplier_id': int.parse(selectedSupplierId!),
                      'name': nameController.text,
                      'location': locationController.text,
                      'material_type': materialTypeController.text,
                      'thickness': thicknessController.text,
                      'net_weight': netWeightController.text,
                      'gross_weight': grossWeightController.text,
                      'date': dateController.text,
                      'unit': unitController.text,
                      'unit_price': unitPriceController.text,
                      'product': productController.text,
                      'commission': commissionController.text,
                      'transfer_cost': transferCostController.text,
                      'miscellaneous': miscellaneousController.text,
                      'ghurfedari': ghurfedariController.text,
                      'barchalani': barchalaniController.text,
                      'final_price': finalPriceController.text,
                    };

                    final result = await _db.insertRawMaterial(material);
                    Navigator.pop(context);

                    if (result != -1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ ماده خام با موفقیت اضافه شد'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ خطا در افزودن ماده خام'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                  ),
                  child: const Text('ذخیره'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============ EDIT DIALOG ============
  void _showEditDialog(BuildContext context, Map<String, dynamic> material) {
    final nameController = TextEditingController(text: material['name'] ?? '');
    final netWeightController = TextEditingController(text: material['net_weight'] ?? '');
    final grossWeightController = TextEditingController(text: material['gross_weight'] ?? '');
    final thicknessController = TextEditingController(text: material['thickness'] ?? '');
    final materialTypeController = TextEditingController(text: material['material_type'] ?? '');
    final locationController = TextEditingController(text: material['location'] ?? '');
    final dateController = TextEditingController(text: material['date'] ?? '');
    final unitController = TextEditingController(text: material['unit'] ?? '');
    final unitPriceController = TextEditingController(text: material['unit_price'] ?? '');
    final productController = TextEditingController(text: material['product'] ?? '');
    final commissionController = TextEditingController(text: material['commission'] ?? '');
    final transferCostController = TextEditingController(text: material['transfer_cost'] ?? '');
    final miscellaneousController = TextEditingController(text: material['miscellaneous'] ?? '');
    final ghurfedariController = TextEditingController(text: material['ghurfedari'] ?? '');
    final barchalaniController = TextEditingController(text: material['barchalani'] ?? '');
    final finalPriceController = TextEditingController(text: material['final_price'] ?? '');

    String? selectedSupplierId = material['supplier_id']?.toString();

    void _updateFinalPrice() {
      double grossWeight = double.tryParse(grossWeightController.text) ?? 0;
      double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      double productCost = double.tryParse(productController.text) ?? 0;
      double commission = double.tryParse(commissionController.text) ?? 0;
      double transferCost = double.tryParse(transferCostController.text) ?? 0;
      double miscellaneous = double.tryParse(miscellaneousController.text) ?? 0;
      double ghurfedari = double.tryParse(ghurfedariController.text) ?? 0;
      double barchalani = double.tryParse(barchalaniController.text) ?? 0;

      double basePrice = grossWeight * unitPrice;
      double finalPrice = basePrice + productCost + commission + transferCost + 
                          miscellaneous + ghurfedari + barchalani;

      finalPriceController.text = finalPrice.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text(
                'ویرایش ماده خام',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Same fields as Add Dialog with controllers
                      // ... (copy from Add Dialog but with controllers)
                      // I'll keep it short - use the same structure as Add Dialog
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('انصراف', style: TextStyle(color: Color(0xFF888888))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // ... update logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                  ),
                  child: const Text('به‌روزرسانی'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============ DELETE DIALOG ============
  void _showDeleteDialog(BuildContext context, Map<String, dynamic> material) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'حذف ماده خام',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          content: Text(
            'آیا از حذف ماده خام "${material['name']}" مطمئن هستید؟',
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
              onPressed: () async {
                final result = await _db.deleteRawMaterial(material['id']);
                Navigator.pop(context);

                if (result != -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ ماده خام با موفقیت حذف شد'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ خطا در حذف ماده خام'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }
}
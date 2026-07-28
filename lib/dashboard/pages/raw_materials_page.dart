import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';

class RawMaterialsPage extends StatefulWidget {
  const RawMaterialsPage({super.key});

  @override
  State<RawMaterialsPage> createState() => _RawMaterialsPageState();
}

class _RawMaterialsPageState extends State<RawMaterialsPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> suppliers = [];
  bool isLoading = true;
  final DatabaseHelper _db = DatabaseHelper();

  late TabController _tabController;

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50, 100];

  // Selection
  final Set<int> _selectedIds = {};

  // Class level variable for English date
  String? selectedEnglishDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final materialsData = await _db.getRawMaterials();
      final suppliersData = await _db.getSuppliers();
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

  // ============ GET UNIT TOTALS ============
  Map<String, double> _getUnitTotals() {
    Map<String, double> totals = {};
    for (var material in materials) {
      String unit = material['unit'] ?? 'نامشخص';
      double grossWeight = double.tryParse(material['gross_weight']?.toString() ?? '0') ?? 0;
      totals[unit] = (totals[unit] ?? 0) + grossWeight;
    }
    return totals;
  }

  // ============ CUT FROM UNIT TOTAL ============
  Future<void> _showCutUnitDialog(String unit, double totalWeight) async {
    final weightController = TextEditingController();
    String selectedType = 'تخلیه شده';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('کسر از موجودی ${unit == 'نامشخص' ? '' : '(' + unit + ')'}'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'مجموع موجودی این واحد:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalWeight $unit',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCB001D),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'نوع کسر',
                  border: OutlineInputBorder(),
                ),
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: 'تخلیه شده', child: Text('تخلیه شده')),
                  DropdownMenuItem(value: 'قطع شده', child: Text('قطع شده')),
                ],
                onChanged: (value) {
                  if (value != null) selectedType = value;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weightController,
                decoration: const InputDecoration(
                  labelText: 'مقدار کسر',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final weight = double.tryParse(weightController.text) ?? 0;
                if (weight <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('مقدار معتبر وارد کنید'), backgroundColor: Colors.red),
                  );
                  return;
                }

                if (weight > totalWeight) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('موجودی کافی نیست!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                // Find all items with this unit
                final itemsToUpdate = materials.where((m) => m['unit'] == unit).toList();
                
                // Calculate total weight of all items with this unit
                double totalUnitWeight = 0;
                for (var item in itemsToUpdate) {
                  totalUnitWeight += double.tryParse(item['gross_weight']?.toString() ?? '0') ?? 0;
                }

                // Distribute the cut proportionally
                for (var item in itemsToUpdate) {
                  double currentWeight = double.tryParse(item['gross_weight']?.toString() ?? '0') ?? 0;
                  double ratio = currentWeight / totalUnitWeight;
                  double cutAmount = weight * ratio;
                  double newWeight = currentWeight - cutAmount;
                  
                  final updatedMaterial = Map<String, dynamic>.from(item);
                  updatedMaterial['gross_weight'] = newWeight.toStringAsFixed(2);
                  await _db.updateRawMaterial(item['id'], updatedMaterial);
                }

                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ $weight $unit ${selectedType == 'تخلیه شده' ? 'تخلیه' : 'قطع'} شد از مجموع ${itemsToUpdate.length} آیتم'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
              ),
              child: const Text('تایید'),
            ),
          ],
        ),
      ),
    );
  }

  // ============ BUILD UNIT CARDS (TAB 2 - STOCK OVERVIEW) ============
  List<Widget> _buildUnitStockCards() {
    Map<String, double> unitTotals = _getUnitTotals();

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
    unitTotals.forEach((unit, total) {
      // Get items count for this unit
      int itemCount = materials.where((m) => m['unit'] == unit).length;
      
      cards.add(
        Container(
          width: 220,
          margin: const EdgeInsets.only(left: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFCB001D).withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCB001D).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.scale,
                      color: Color(0xFFCB001D),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      unit == 'نامشخص' ? 'بدون واحد' : unit,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'مجموع موجودی:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                  Text(
                    total.toStringAsFixed(0),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFFCB001D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تعداد آیتم‌ها: $itemCount',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888),
                    ),
                  ),
                  // Cut Button
                  InkWell(
                    onTap: () => _showCutUnitDialog(unit, total),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.cut, color: Colors.orange, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'کسر',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
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

  // ============ BUILD UNIT SUMMARY CARDS (TAB 1) ============
  List<Widget> _buildUnitSummaryCards() {
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
          width: 170,
          margin: const EdgeInsets.only(left: 12),
          padding: const EdgeInsets.all(12),
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
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCB001D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'خالص:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888),
                    ),
                  ),
                  Text(
                    totals['net']!.toStringAsFixed(0),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
                      fontSize: 11,
                      color: Color(0xFF888888),
                    ),
                  ),
                  Text(
                    totals['gross']!.toStringAsFixed(0),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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

  // ============ BUILD STOCK TABLE (Tab 2) - ONLY CARDS, NO DETAILS TABLE ============
  Widget _buildStockTable() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)));
    }

    Map<String, double> unitTotals = _getUnitTotals();

    if (materials.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('هیچ ماده خامی در انبار نیست', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'موجودی بر اساس واحد:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 12),
          // Stock Cards - Responsive grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _buildUnitStockCards(),
          ),
        ],
      ),
    );
  }

  // ============ BUILD MAIN TABLE (Tab 1) ============
  Widget _buildMainTable() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)));
    }

    if (materials.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warehouse_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('هیچ ماده خامی یافت نشد', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.06), width: 1),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB001D).withOpacity(0.05),
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 40),
                          const SizedBox(width: 6),
                          _buildHeaderCell('شماره', 60),
                          _buildHeaderCell('نام مواد', 90),
                          _buildHeaderCell('تاریخ', 100),
                          _buildHeaderCell('واحد', 60),
                          _buildHeaderCell('وزن خالص', 65),
                          _buildHeaderCell('وزن ناخالص', 65),
                          _buildHeaderCell('قیمت واحد', 65),
                          _buildHeaderCell('قیمت پایه فروشنده', 80),
                          _buildHeaderCell('پرداخت اولیه', 80),
                          _buildHeaderCell('روش پرداخت', 80),
                          _buildHeaderCell('محصول', 60),
                          _buildHeaderCell('کمیشن', 60),
                          _buildHeaderCell('کرایه', 60),
                          _buildHeaderCell('متفرقه', 60),
                          _buildHeaderCell('غرفه داری', 60),
                          _buildHeaderCell('بارچلانی', 60),
                          _buildHeaderCell('نوع خرید', 70),
                          _buildHeaderCell('قیمت نهایی', 80),
                          _buildHeaderCell('عملیات', 80),
                        ],
                      ),
                    ),
                    ..._paginatedMaterials.map((material) {
                      final isSelected = _selectedIds.contains(material['id'] as int);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFCB001D).withOpacity(0.04) : null,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(material['id'] as int),
                                activeColor: const Color(0xFFCB001D),
                                checkColor: Colors.white,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildDataCell(material['id'].toString(), 60),
                            _buildDataCell(material['name'] ?? '-', 90),
                            Container(
                              width: 100,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    material['date_en'] ?? '-',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    material['date'] ?? '-',
                                    style: const TextStyle(
                                      fontSize: 7,
                                      color: Color(0xFFCB001D),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            _buildDataCell(material['unit'] ?? '-', 60),
                            _buildDataCell(material['net_weight'] ?? '-', 65),
                            _buildDataCell(material['gross_weight'] ?? '-', 65),
                            _buildDataCell(material['unit_price'] ?? '-', 65),
                            _buildDataCell(material['seller_payment'] ?? '-', 80),
                            _buildDataCell(material['seller_paid_amount'] ?? '-', 80),
                            _buildDataCell(material['seller_payment_method'] == 'cash'
                                ? 'نقد'
                                : material['seller_payment_method'] == 'loan_full'
                                    ? 'قرض کامل'
                                    : material['seller_payment_method'] == 'loan_partial'
                                        ? 'قرض جزئی'
                                        : '-', 80),
                            _buildDataCell(material['product'] ?? '-', 60),
                            _buildDataCell(material['commission'] ?? '-', 60),
                            _buildDataCell(material['transfer_cost'] ?? '-', 60),
                            _buildDataCell(material['miscellaneous'] ?? '-', 60),
                            _buildDataCell(material['ghurfedari'] ?? '-', 60),
                            _buildDataCell(material['barchalani'] ?? '-', 60),
                            Container(
                              width: 70,
                              child: _buildPurchaseTypeChip(material['purchase_type']),
                            ),
                            _buildDataCell(material['final_price'] ?? '-', 80, isBold: true, isRed: true),
                            SizedBox(
                              width: 80,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: const Color(0xFFCB001D), size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showEditDialog(context, material),
                                    tooltip: 'ویرایش',
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showDeleteDialog(context, material),
                                    tooltip: 'حذف',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
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
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _itemsPerPage,
                        onChanged: _changeItemsPerPage,
                        items: _pageSizeOptions.map((size) {
                          return DropdownMenuItem<int>(
                            value: size,
                            child: Text(size.toString(), style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 12)),
                          );
                        }).toList(),
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down, color: const Color(0xFFCB001D), size: 18),
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
    );
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

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 9,
          color: Color(0xFF1A1A2E),
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {bool isBold = false, bool isRed = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isRed ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E),
          fontSize: 9,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPurchaseTypeChip(String? purchaseType) {
    final type = purchaseType ?? 'نامشخص';
    final isDirect = type == 'مستقیم';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDirect ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDirect ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDirect ? Icons.check_circle : Icons.remove_circle,
            color: isDirect ? Colors.green : Colors.orange,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            type,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: isDirect ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, [IconData? icon, Color? color]) {
    final cardColor = color ?? const Color(0xFFCB001D);
    final cardIcon = icon ?? Icons.inventory_2_outlined;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: cardColor.withOpacity(0.06), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(cardIcon, color: cardColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 1),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
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
    final ghurfedariController = TextEditingController();
    final barchalaniController = TextEditingController();
    final finalPriceController = TextEditingController();
    final sellerPaymentController = TextEditingController();
    final sellerPaidAmountController = TextEditingController();

    String selectedSellerPaymentMethod = 'cash';
    String? selectedPurchaseType;
    String? selectedSupplierId;
    String? selectedDate;

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
      sellerPaymentController.text = basePrice.toStringAsFixed(0);
      if (selectedSellerPaymentMethod == 'cash') {
        sellerPaidAmountController.text = sellerPaymentController.text;
      } else if ((selectedSellerPaymentMethod == 'loan_full' || selectedSellerPaymentMethod == 'loan_partial') && sellerPaidAmountController.text.isEmpty) {
        sellerPaidAmountController.text = '0';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('افزودن ماده خام جدید'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'انتخاب فروشنده *',
                          labelStyle: TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: selectedSupplierId,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('انتخاب فروشنده...')),
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
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: dateController,
                        decoration: InputDecoration(
                          labelText: 'تاریخ *',
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
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
                            setStateDialog(() {
                              dateController.text = persianDate;
                              selectedDate = persianDate;
                              selectedEnglishDate = englishDate;
                            });
                          }
                        },
                        readOnly: true,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'نام مواد ارسالی *',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'محل تخلیه *',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: materialTypeController,
                        decoration: const InputDecoration(
                          labelText: 'نوع مواد *',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'واحد *',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: unitController.text.isNotEmpty ? unitController.text : null,
                        items: const [
                          DropdownMenuItem<String>(value: 'کیلوگرم', child: Text('کیلوگرم (Kg)')),
                          DropdownMenuItem<String>(value: 'تن', child: Text('تن (Ton)')),
                          DropdownMenuItem<String>(value: 'متر', child: Text('متر (M)')),
                          DropdownMenuItem<String>(value: 'عدد', child: Text('عدد (Pcs)')),
                          DropdownMenuItem<String>(value: 'لیتر', child: Text('لیتر (L)')),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            unitController.text = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: thicknessController,
                        decoration: const InputDecoration(
                          labelText: 'ضخامت *',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'نوع خرید *',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: selectedPurchaseType,
                        items: const [
                          DropdownMenuItem<String>(value: null, child: Text('انتخاب نوع خرید...')),
                          DropdownMenuItem<String>(value: 'مستقیم', child: Text('مستقیم')),
                          DropdownMenuItem<String>(value: 'غیر مستقیم', child: Text('غیر مستقیم')),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedPurchaseType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: netWeightController,
                              decoration: const InputDecoration(
                                labelText: 'وزن خالص *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: grossWeightController,
                              decoration: const InputDecoration(
                                labelText: 'وزن ناخالص *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: unitPriceController,
                        decoration: const InputDecoration(
                          labelText: 'قیمت واحد (افغانی) *',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateFinalPrice(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: productController,
                        decoration: const InputDecoration(
                          labelText: 'قیمت محصول (افغانی)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateFinalPrice(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sellerPaymentController,
                              enabled: false,
                              decoration: const InputDecoration(
                                labelText: 'مبلغ فروشنده (افغانی)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB001D)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSellerPaymentMethod,
                              decoration: const InputDecoration(
                                labelText: 'روش پرداخت فروشنده',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'cash', child: Text('نقد')),
                                DropdownMenuItem(value: 'loan_full', child: Text('قرض کامل')),
                                DropdownMenuItem(value: 'loan_partial', child: Text('قرض جزئی')),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  selectedSellerPaymentMethod = value ?? 'cash';
                                  if (selectedSellerPaymentMethod == 'cash') {
                                    sellerPaidAmountController.text = sellerPaymentController.text;
                                  } else {
                                    sellerPaidAmountController.text = '0';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (selectedSellerPaymentMethod == 'loan_partial') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: sellerPaidAmountController,
                          decoration: const InputDecoration(
                            labelText: 'مبلغ پرداختی اولیه فروشنده',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'قرض فروشنده فقط بر اساس مبلغ پایه محاسبه می‌شود. هزینه‌های اضافی مانند محصول، کمیشن، کرایه، غرفه‌داری، بارچلانی و متفرقه جداگانه پرداخت می‌شوند.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commissionController,
                              decoration: const InputDecoration(
                                labelText: 'کمیشن (افغانی)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: transferCostController,
                              decoration: const InputDecoration(
                                labelText: 'کرایه (افغانی)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ghurfedariController,
                              decoration: const InputDecoration(
                                labelText: 'غرفه داری (افغانی)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: barchalaniController,
                              decoration: const InputDecoration(
                                labelText: 'بارچلانی (افغانی)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: miscellaneousController,
                              decoration: const InputDecoration(
                                labelText: 'متفرقه (افغانی)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: finalPriceController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'قیمت تمام شد (افغانی)',
                                border: OutlineInputBorder(),
                                fillColor: Color(0xFFF5F0EB),
                                filled: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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
                  child: const Text('انصراف', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedSupplierId == null || nameController.text.isEmpty || selectedPurchaseType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('لطفاً تمام فیلدهای ضروری را پر کنید'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final sellerPayment = double.tryParse(sellerPaymentController.text) ?? 0;
                    final sellerPaidAmount = selectedSellerPaymentMethod == 'cash'
                        ? sellerPayment
                        : double.tryParse(sellerPaidAmountController.text) ?? 0;

                    if ((selectedSellerPaymentMethod == 'loan_full' || selectedSellerPaymentMethod == 'loan_partial') && sellerPaidAmount > sellerPayment) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('مبلغ پرداختی فروشنده نمی‌تواند بیشتر از مبلغ پایه باشد'), backgroundColor: Colors.red),
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
                      'date_en': selectedEnglishDate,
                      'unit': unitController.text,
                      'unit_price': unitPriceController.text,
                      'product': productController.text,
                      'commission': commissionController.text,
                      'transfer_cost': transferCostController.text,
                      'miscellaneous': miscellaneousController.text,
                      'ghurfedari': ghurfedariController.text,
                      'barchalani': barchalaniController.text,
                      'purchase_type': selectedPurchaseType,
                      'seller_payment': sellerPayment.toStringAsFixed(0),
                      'seller_payment_method': selectedSellerPaymentMethod,
                      'seller_paid_amount': sellerPaidAmount.toStringAsFixed(0),
                      'final_price': finalPriceController.text,
                    };

                    final result = await _db.insertRawMaterial(material);
                    if (selectedSellerPaymentMethod != 'cash') {
                      final sellerPayment = double.tryParse(sellerPaymentController.text) ?? 0;
                      final sellerPaidAmount = double.tryParse(sellerPaidAmountController.text) ?? 0;
                      final remainingSeller = (sellerPayment - sellerPaidAmount) < 0 ? 0 : (sellerPayment - sellerPaidAmount);
                      final supplier = suppliers.firstWhere((s) => s['id'].toString() == selectedSupplierId, orElse: () => {});
                      final loanPayload = {
                        'sale_invoice_id': null,
                        'invoice_number': 'RM-${DateTime.now().millisecondsSinceEpoch}',
                        'customer_name': supplier['name'] ?? 'فروشنده',
                        'customer_company': supplier['address'] ?? '',
                        'total_amount': sellerPayment,
                        'paid_amount': selectedSellerPaymentMethod == 'loan_full' ? 0 : sellerPaidAmount,
                        'remaining_amount': remainingSeller,
                        'loan_type': selectedSellerPaymentMethod == 'loan_full' ? 'full' : 'partial',
                        'loan_source': 'supplier',
                        'currency': 'AFN',
                        'date': dateController.text.trim(),
                        'date_en': selectedEnglishDate,
                      };
                      final loanId = await _db.insertSellLoan(loanPayload);
                      if (loanId != -1 && sellerPaidAmount > 0) {
                        await _db.insertSellLoanPayment({
                          'loan_id': loanId,
                          'amount': sellerPaidAmount,
                          'note': 'پرداخت اولیه فروشنده هنگام ثبت ماده خام',
                          'date': dateController.text.trim(),
                          'date_en': selectedEnglishDate,
                        });
                      }
                    }
                    Navigator.pop(context);

                    if (result != -1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ ماده خام با موفقیت اضافه شد'), backgroundColor: Colors.green),
                      );
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('❌ خطا در افزودن ماده خام'), backgroundColor: Colors.red),
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

  void _showEditDialog(BuildContext context, Map<String, dynamic> material) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ویرایش در حال توسعه...'), duration: Duration(seconds: 2)),
    );
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> material) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف ماده خام'),
          content: Text('آیا از حذف ماده خام "${material['name']}" مطمئن هستید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await _db.deleteRawMaterial(material['id']);
                Navigator.pop(context);
                if (result != -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ ماده خام با موفقیت حذف شد'), backgroundColor: Colors.green),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ خطا در حذف ماده خام'), backgroundColor: Colors.red),
                  );
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مدیریت مواد خام', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                    SizedBox(height: 2),
                    Text('مدیریت و کنترل مواد اولیه انبار', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () { _showAddDialog(context); },
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text('افزودن ماده خام', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                _buildStatCard('کل مواد', materials.length.toString()),
                const SizedBox(width: 12),
                _buildStatCard('فروشندگان', suppliers.length.toString()),
              ],
            ),
            const SizedBox(height: 12),

            // Unit-based totals cards - Summary (Tab 1 style)
            if (materials.isNotEmpty) ...[
              const Text('خلاصه انبار موجود بر اساس واحد:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _buildUnitSummaryCards()),
              ),
            ],
            const SizedBox(height: 14),

            // Tabs Container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: '📦 مدیریت مواد خام'),
                        Tab(text: '📊 موجودی مواد خام'),
                      ],
                      labelColor: const Color(0xFFCB001D),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFFCB001D),
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMainTable(),
                          _buildStockTable(),
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
}
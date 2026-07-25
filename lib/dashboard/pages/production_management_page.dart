import 'package:flutter/material.dart';

class ProductionManagementPage extends StatefulWidget {
  const ProductionManagementPage({super.key});

  @override
  State<ProductionManagementPage> createState() =>
      _ProductionManagementPageState();
}

class _ProductionManagementPageState extends State<ProductionManagementPage> {
  // داده‌های نمونه
  List<Map<String, dynamic>> productions = [];
  bool isLoading = true;

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50, 100];

  // Selection
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadSampleData();
  }

  void _loadSampleData() {
    setState(() {
      productions = [
        {
          'id': 1,
          'product_name': 'لوله پلی‌اتیلن ۲۵۰',
          'type': 'لوله',
          'thickness': '۲.۵',
          'length': '۶',
          'quantity': 150,
          'weight': '۳۲۰',
          'unit': 'متر',
          'date': '۱۴۰۵/۰۵/۰۱',
          'status': 'تکمیل شده',
          'batch': 'B-2025-001',
          'description': 'تولید لوله پلی‌اتیلن برای پروژه آبرسانی',
        },
        {
          'id': 2,
          'product_name': 'اتصالات جوشی ۴ اینچ',
          'type': 'اتصال',
          'thickness': '۳',
          'length': '۰.۵',
          'quantity': 80,
          'weight': '۴۵',
          'unit': 'عدد',
          'date': '۱۴۰۵/۰۵/۰۲',
          'status': 'در حال تولید',
          'batch': 'B-2025-002',
          'description': 'اتصالات جوشی برای خط لوله گاز',
        },
        {
          'id': 3,
          'product_name': 'لوله فولادی ۴ اینچ',
          'type': 'لوله',
          'thickness': '۴',
          'length': '۱۲',
          'quantity': 200,
          'weight': '۸۵۰',
          'unit': 'متر',
          'date': '۱۴۰۵/۰۵/۰۳',
          'status': 'تکمیل شده',
          'batch': 'B-2025-003',
          'description': 'لوله فولادی برای پروژه صنعتی',
        },
        {
          'id': 4,
          'product_name': 'کمربند فلنج ۲ اینچ',
          'type': 'فلنج',
          'thickness': '۱.۵',
          'length': '۲',
          'quantity': 45,
          'weight': '۱۲',
          'unit': 'عدد',
          'date': '۱۴۰۵/۰۵/۰۴',
          'status': 'در انتظار',
          'batch': 'B-2025-004',
          'description': 'فلنج برای اتصالات صنعتی',
        },
      ];
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _paginatedProductions {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= productions.length) {
      _currentPage = 1;
      return productions.take(_itemsPerPage).toList();
    }
    return productions.sublist(
      start,
      end > productions.length ? productions.length : end,
    );
  }

  int get _totalPages => (productions.length / _itemsPerPage).ceil();

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
      final currentIds =
          _paginatedProductions.map((m) => m['id'] as int).toList();
      final allSelected =
          currentIds.every((id) => _selectedIds.contains(id));
      if (allSelected) {
        _selectedIds.removeAll(currentIds);
      } else {
        _selectedIds.addAll(currentIds);
      }
    });
  }

  // ============ BUILD STATS CARDS ============
  Widget _buildStatsCards() {
    final total = productions.length;
    final completed = productions.where((p) => p['status'] == 'تکمیل شده').length;
    final inProgress = productions.where((p) => p['status'] == 'در حال تولید').length;
    final pending = productions.where((p) => p['status'] == 'در انتظار').length;

    return Row(
      children: [
        _buildStatCard('کل تولیدات', total.toString(), Icons.factory_rounded,
            const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard('تکمیل شده', completed.toString(),
            Icons.check_circle_rounded, Colors.green.shade700),
        const SizedBox(width: 12),
        _buildStatCard('در حال تولید', inProgress.toString(),
            Icons.pending_rounded, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard('در انتظار', pending.toString(),
            Icons.hourglass_empty_rounded, Colors.orange.shade700),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
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

  // ============ BUILD HEADER ============
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مدیریت تولید',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'مدیریت و کنترل فرآیندهای تولید',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (_selectedIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCB001D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFFCB001D),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_selectedIds.length} انتخاب شده',
                      style: const TextStyle(
                        color: Color(0xFFCB001D),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                _showAddDialog(context);
              },
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text(
                'ثبت تولید جدید',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============ BUILD UNIT CARDS ============
  List<Widget> _buildUnitCards() {
    Map<String, Map<String, dynamic>> unitTotals = {};

    for (var production in productions) {
      String unit = production['unit'] ?? 'نامشخص';
      double quantity = double.tryParse(production['quantity']?.toString() ?? '0') ?? 0;
      double weight = double.tryParse(production['weight']?.toString() ?? '0') ?? 0;

      if (!unitTotals.containsKey(unit)) {
        unitTotals[unit] = {'quantity': 0, 'weight': 0, 'count': 0};
      }
      unitTotals[unit]!['quantity'] =
          (unitTotals[unit]!['quantity'] ?? 0) + quantity;
      unitTotals[unit]!['weight'] =
          (unitTotals[unit]!['weight'] ?? 0) + weight;
      unitTotals[unit]!['count'] = (unitTotals[unit]!['count'] ?? 0) + 1;
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
            'هیچ تولیدی ثبت نشده است',
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
                      Icons.production_quantity_limits_rounded,
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
                    'تعداد:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888),
                    ),
                  ),
                  Text(
                    totals['quantity']!.toStringAsFixed(0),
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
                    'وزن کل:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888),
                    ),
                  ),
                  Text(
                    '${totals['weight']!.toStringAsFixed(0)} کیلوگرم',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFFCB001D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تعداد اقلام:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888),
                    ),
                  ),
                  Text(
                    totals['count']!.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1A1A2E),
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

  // ============ BUILD HEADER CELL ============
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

  Widget _buildDataCell(String text, double width,
      {bool isBold = false, bool isRed = false}) {
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

  // ============ BUILD STATUS CHIP ============
  Widget _buildStatusChip(String status) {
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============ MAIN BUILD ============
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

            // Unit-based totals cards
            if (productions.isNotEmpty) ...[
              const Text(
                'خلاصه تولیدات بر اساس واحد:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _buildUnitCards()),
              ),
            ],
            const SizedBox(height: 14),

            // List - Responsive Table
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFCB001D),
                      ),
                    )
                  : productions.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.factory_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'هیچ تولیدی ثبت نشده است',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: const Color(0xFFCB001D)
                                        .withOpacity(0.06),
                                    width: 1,
                                  ),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // محاسبه عرض کل جدول بر اساس عرض موجود
                                    final totalWidth = constraints.maxWidth - 60; // برای چک‌باکس و padding
                                    
                                    // ستون‌ها با عرض نسبی (درصدی)
                                    final columnWidths = {
                                      'checkbox': 40.0,
                                      'id': totalWidth * 0.05,
                                      'product': totalWidth * 0.12,
                                      'type': totalWidth * 0.07,
                                      'thickness': totalWidth * 0.07,
                                      'length': totalWidth * 0.07,
                                      'quantity': totalWidth * 0.08,
                                      'weight': totalWidth * 0.08,
                                      'unit': totalWidth * 0.07,
                                      'date': totalWidth * 0.09,
                                      'status': totalWidth * 0.09,
                                      'batch': totalWidth * 0.08,
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
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFCB001D)
                                                      .withOpacity(0.05),
                                                  border: const Border(
                                                    bottom: BorderSide(
                                                      color: Colors.grey,
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: columnWidths['checkbox'],
                                                      child: Checkbox(
                                                        value: false,
                                                        onChanged: (_) => _toggleSelectAll(),
                                                        activeColor: const Color(0xFFCB001D),
                                                        checkColor: Colors.white,
                                                        materialTapTargetSize:
                                                            MaterialTapTargetSize.shrinkWrap,
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
                                                    _buildHeaderCell('عملیات', columnWidths['actions']!),
                                                  ],
                                                ),
                                              );
                                            }

                                            final production = _paginatedProductions[index - 1];
                                            final isSelected = _selectedIds
                                                .contains(production['id'] as int);

                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFFCB001D)
                                                        .withOpacity(0.04)
                                                    : null,
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Colors.grey.shade100,
                                                    width: 0.5,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: columnWidths['checkbox'],
                                                    child: Checkbox(
                                                      value: isSelected,
                                                      onChanged: (_) =>
                                                          _toggleSelection(
                                                              production['id'] as int),
                                                      activeColor: const Color(0xFFCB001D),
                                                      checkColor: Colors.white,
                                                      materialTapTargetSize:
                                                          MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                  ),
                                                  _buildDataCell(
                                                      production['id'].toString(),
                                                      columnWidths['id']!),
                                                  _buildDataCell(
                                                      production['product_name'] ?? '-',
                                                      columnWidths['product']!),
                                                  _buildDataCell(
                                                      production['type'] ?? '-',
                                                      columnWidths['type']!),
                                                  _buildDataCell(
                                                      production['thickness'] ?? '-',
                                                      columnWidths['thickness']!),
                                                  _buildDataCell(
                                                      production['length'] ?? '-',
                                                      columnWidths['length']!),
                                                  _buildDataCell(
                                                      production['quantity'].toString(),
                                                      columnWidths['quantity']!,
                                                      isBold: true),
                                                  _buildDataCell(
                                                      production['weight'] ?? '-',
                                                      columnWidths['weight']!),
                                                  _buildDataCell(
                                                      production['unit'] ?? '-',
                                                      columnWidths['unit']!),
                                                  _buildDataCell(
                                                      production['date'] ?? '-',
                                                      columnWidths['date']!),
                                                  SizedBox(
                                                    width: columnWidths['status']!,
                                                    child: _buildStatusChip(
                                                        production['status'] ?? '-'),
                                                  ),
                                                  _buildDataCell(
                                                      production['batch'] ?? '-',
                                                      columnWidths['batch']!),
                                                  SizedBox(
                                                    width: columnWidths['actions']!,
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.center,
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(
                                                            Icons.edit_outlined,
                                                            color: const Color(0xFFCB001D),
                                                            size: 16,
                                                          ),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          onPressed: () {
                                                            _showEditDialog(
                                                                context, production);
                                                          },
                                                        ),
                                                        IconButton(
                                                          icon: Icon(
                                                            Icons.delete_outline,
                                                            color: Colors.red.shade400,
                                                            size: 16,
                                                          ),
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          onPressed: () {
                                                            _showDeleteDialog(
                                                                context, production);
                                                          },
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

                            // Pagination
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'نمایش:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 6),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFFCB001D)
                                                .withOpacity(0.2),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _itemsPerPage,
                                            onChanged:
                                                _changeItemsPerPage,
                                            items: _pageSizeOptions
                                                .map((size) {
                                              return DropdownMenuItem<int>(
                                                value: size,
                                                child: Text(
                                                  size.toString(),
                                                  style:
                                                      const TextStyle(
                                                    color: Color(
                                                        0xFF1A1A2E),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            dropdownColor: Colors.white,
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                              color: const Color(
                                                  0xFFCB001D),
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'در هر صفحه',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'صفحه $_currentPage از $_totalPages',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.chevron_right,
                                          color: Color(0xFFCB001D),
                                          size: 20,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints(),
                                        onPressed: _currentPage > 1
                                            ? () => _changePage(
                                                _currentPage - 1)
                                            : null,
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.chevron_left,
                                          color: Color(0xFFCB001D),
                                          size: 20,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints(),
                                        onPressed: _currentPage <
                                                _totalPages
                                            ? () => _changePage(
                                                _currentPage + 1)
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
          ],
        ),
      ),
    );
  }

  // ============ ADD DIALOG ============
  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final thicknessController = TextEditingController();
    final lengthController = TextEditingController();
    final quantityController = TextEditingController();
    final weightController = TextEditingController();
    final unitController = TextEditingController();
    final dateController = TextEditingController();
    final batchController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ثبت تولید جدید'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'نام محصول *',
                      labelStyle: TextStyle(
                        color: Color(0xFFCB001D),
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCB001D)),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'نوع تولید *',
                      labelStyle: TextStyle(
                        color: Color(0xFFCB001D),
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCB001D)),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    value: typeController.text.isNotEmpty
                        ? typeController.text
                        : null,
                    items: const [
                      DropdownMenuItem<String>(
                          value: 'لوله', child: Text('لوله')),
                      DropdownMenuItem<String>(
                          value: 'اتصال', child: Text('اتصال')),
                      DropdownMenuItem<String>(
                          value: 'فلنج', child: Text('فلنج')),
                      DropdownMenuItem<String>(
                          value: 'کمربند', child: Text('کمربند')),
                      DropdownMenuItem<String>(
                          value: 'سایر', child: Text('سایر')),
                    ],
                    onChanged: (value) {
                      typeController.text = value ?? '';
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: thicknessController,
                          decoration: const InputDecoration(
                            labelText: 'ضخامت (میلی‌متر) *',
                            labelStyle: TextStyle(
                              color: Color(0xFFCB001D),
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFCB001D)),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: lengthController,
                          decoration: const InputDecoration(
                            labelText: 'طول (متر) *',
                            labelStyle: TextStyle(
                              color: Color(0xFFCB001D),
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFCB001D)),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          keyboardType: TextInputType.number,
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
                          decoration: const InputDecoration(
                            labelText: 'تعداد *',
                            labelStyle: TextStyle(
                              color: Color(0xFFCB001D),
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFCB001D)),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: weightController,
                          decoration: const InputDecoration(
                            labelText: 'وزن (کیلوگرم)',
                            labelStyle: TextStyle(
                              color: Color(0xFFCB001D),
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFCB001D)),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
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
                          decoration: const InputDecoration(
                            labelText: 'واحد *',
                            labelStyle: TextStyle(
                              color: Color(0xFFCB001D),
                              fontSize: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFCB001D)),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          value: unitController.text.isNotEmpty
                              ? unitController.text
                              : null,
                          items: const [
                            DropdownMenuItem<String>(
                                value: 'متر', child: Text('متر')),
                            DropdownMenuItem<String>(
                                value: 'عدد', child: Text('عدد')),
                            DropdownMenuItem<String>(
                                value: 'کیلوگرم', child: Text('کیلوگرم')),
                            DropdownMenuItem<String>(
                                value: 'تن', child: Text('تن')),
                          ],
                          onChanged: (value) {
                            unitController.text = value ?? '';
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: dateController,
                          decoration: InputDecoration(
                            labelText: 'تاریخ *',
                            labelStyle: const TextStyle(
                              color: Color(0xFFCB001D),
                              fontSize: 12,
                            ),
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFCB001D)),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            suffixIcon: Icon(
                              Icons.calendar_today,
                              color: const Color(0xFFCB001D),
                              size: 18,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              dateController.text =
                                  '${picked.year}/${picked.month}/${picked.day}';
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: batchController,
                    decoration: const InputDecoration(
                      labelText: 'شماره بچ',
                      labelStyle: TextStyle(
                        color: Color(0xFFCB001D),
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCB001D)),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'توضیحات',
                      labelStyle: TextStyle(
                        color: Color(0xFFCB001D),
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFCB001D)),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
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
                if (nameController.text.isEmpty ||
                    typeController.text.isEmpty ||
                    quantityController.text.isEmpty ||
                    unitController.text.isEmpty ||
                    dateController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('لطفاً تمام فیلدهای ضروری را پر کنید'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  productions.insert(0, {
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'product_name': nameController.text,
                    'type': typeController.text,
                    'thickness': thicknessController.text.isEmpty
                        ? '-'
                        : thicknessController.text,
                    'length': lengthController.text.isEmpty
                        ? '-'
                        : lengthController.text,
                    'quantity':
                        int.tryParse(quantityController.text) ?? 0,
                    'weight': weightController.text.isEmpty
                        ? '-'
                        : weightController.text,
                    'unit': unitController.text,
                    'date': dateController.text,
                    'status': 'در حال تولید',
                    'batch': batchController.text.isEmpty
                        ? '-'
                        : batchController.text,
                    'description': descriptionController.text,
                  });
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تولید با موفقیت ثبت شد'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
              ),
              child: const Text('ثبت تولید'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> production) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ویرایش در حال توسعه...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, Map<String, dynamic> production) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف تولید'),
          content: Text(
            'آیا از حذف تولید "${production['product_name']}" مطمئن هستید؟',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
                setState(() {
                  productions.removeWhere(
                      (p) => p['id'] == production['id']);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تولید با موفقیت حذف شد'),
                    backgroundColor: Colors.green,
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
      ),
    );
  }
}
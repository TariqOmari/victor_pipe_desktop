import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

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

  // Unit translation helper
  String _translateUnit(String unit, AppLocalizations l10n) {
    if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') return l10n.kgUnit;
    if (unit == 'تن' || unit == 'ton' || unit == 'Ton') return l10n.tonUnit;
    if (unit == 'متر' || unit == 'm' || unit == 'M') return l10n.meterUnit;
    if (unit == 'عدد' || unit == 'pcs' || unit == 'Pcs') return l10n.pcsUnit;
    if (unit == 'لیتر' || unit == 'l' || unit == 'L') return l10n.literUnit;
    return unit;
  }

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
    final l10n = AppLocalizations.of(context)!;
    final weightController = TextEditingController();
    String selectedType = l10n.discharged;
    final translatedUnit = _translateUnit(unit, l10n);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('${l10n.cutFromStock} ${unit == 'نامشخص' ? '' : '(' + translatedUnit + ')'}'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.totalStockForUnit,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalWeight $translatedUnit',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCB001D),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: l10n.cutType,
                  border: const OutlineInputBorder(),
                ),
                value: selectedType,
                items: [
                  DropdownMenuItem(value: l10n.discharged, child: Text(l10n.discharged)),
                  DropdownMenuItem(value: l10n.cut, child: Text(l10n.cut)),
                ],
                onChanged: (value) {
                  if (value != null) selectedType = value;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weightController,
                decoration: InputDecoration(
                  labelText: l10n.cutAmount,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final weight = double.tryParse(weightController.text) ?? 0;
                if (weight <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.enterValidAmount), backgroundColor: Colors.red),
                  );
                  return;
                }

                if (weight > totalWeight) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.insufficientStock), backgroundColor: Colors.red),
                  );
                  return;
                }

                final itemsToUpdate = materials.where((m) => m['unit'] == unit).toList();
                
                double totalUnitWeight = 0;
                for (var item in itemsToUpdate) {
                  totalUnitWeight += double.tryParse(item['gross_weight']?.toString() ?? '0') ?? 0;
                }

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
                    content: Text('✅ $weight $translatedUnit ${selectedType == l10n.discharged ? l10n.discharged : l10n.cut} ${l10n.from} ${itemsToUpdate.length} ${l10n.items}'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
              ),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ),
    );
  }

  // ============ BUILD UNIT CARDS (TAB 2 - STOCK OVERVIEW) ============
  List<Widget> _buildUnitStockCards(AppLocalizations l10n) {
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
          child: Text(
            l10n.noRawMaterialsInStock,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 13,
            ),
          ),
        ),
      ];
    }

    List<Widget> cards = [];
    unitTotals.forEach((unit, total) {
      int itemCount = materials.where((m) => m['unit'] == unit).length;
      final translatedUnit = _translateUnit(unit, l10n);
      
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
                      unit == 'نامشخص' ? l10n.noUnit : translatedUnit,
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
                  Text(
                    l10n.totalStock,
                    style: const TextStyle(
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
                    '${l10n.itemsCount}: $itemCount',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888),
                    ),
                  ),
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
                        children: [
                          const Icon(Icons.cut, color: Colors.orange, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            l10n.cut,
                            style: const TextStyle(
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
  List<Widget> _buildUnitSummaryCards(AppLocalizations l10n) {
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
          child: Text(
            l10n.noRawMaterialsInStock,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 13,
            ),
          ),
        ),
      ];
    }

    List<Widget> cards = [];
    unitTotals.forEach((unit, totals) {
      final translatedUnit = _translateUnit(unit, l10n);
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
                    unit == 'نامشخص' ? l10n.noUnit : translatedUnit,
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
                  Text(
                    l10n.netWeight,
                    style: const TextStyle(
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
                  Text(
                    l10n.grossWeight,
                    style: const TextStyle(
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

  // ============ BUILD STOCK TABLE (Tab 2) ============
  Widget _buildStockTable(AppLocalizations l10n) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)));
    }

    Map<String, double> unitTotals = _getUnitTotals();

    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(l10n.noRawMaterialsInStock, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.stockByUnit,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _buildUnitStockCards(l10n),
          ),
        ],
      ),
    );
  }

  // ============ BUILD MAIN TABLE (Tab 1) ============
  Widget _buildMainTable(AppLocalizations l10n) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)));
    }

    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warehouse_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(l10n.noRawMaterialsFound, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
                          _buildHeaderCell(l10n.id, 60),
                          _buildHeaderCell(l10n.materialName, 90),
                          _buildHeaderCell(l10n.supplierName, 120),
                          _buildHeaderCell(l10n.supplierPhone, 90),
                          _buildHeaderCell(l10n.supplierAddress, 120),
                          _buildHeaderCell(l10n.date, 100),
                          _buildHeaderCell(l10n.unit, 60),
                          _buildHeaderCell(l10n.netWeight, 65),
                          _buildHeaderCell(l10n.grossWeight, 65),
                          _buildHeaderCell(l10n.unitPrice, 65),
                          _buildHeaderCell(l10n.sellerBasePrice, 80),
                          _buildHeaderCell(l10n.initialPayment, 80),
                          _buildHeaderCell(l10n.paymentMethod, 80),
                          _buildHeaderCell(l10n.product, 60),
                          _buildHeaderCell(l10n.commission, 60),
                          _buildHeaderCell(l10n.transferCost, 60),
                          _buildHeaderCell(l10n.miscellaneous, 60),
                          _buildHeaderCell(l10n.ghurfedari, 60),
                          _buildHeaderCell(l10n.barchalani, 60),
                          _buildHeaderCell(l10n.purchaseType, 70),
                          _buildHeaderCell(l10n.finalPrice, 80),
                          _buildHeaderCell(l10n.actions, 80),
                        ],
                      ),
                    ),
                    ..._paginatedMaterials.map((material) {
                      final isSelected = _selectedIds.contains(material['id'] as int);
                      final translatedUnit = _translateUnit(material['unit'] ?? '-', l10n);
                      final isImported = material['imported_by_excel'] == true;
                      
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
                            _buildDataCell(material['supplier_name'] ?? '-', 120),
                            _buildDataCell(material['supplier_phone'] ?? '-', 90),
                            _buildDataCell(material['supplier_address'] ?? '-', 120),
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
                            _buildDataCell(translatedUnit, 60),
                            _buildDataCell(material['net_weight'] ?? '-', 65),
                            _buildDataCell(material['gross_weight'] ?? '-', 65),
                            _buildDataCell(material['unit_price'] ?? '-', 65),
                            _buildDataCell('${material['seller_payment'] ?? '-'} ${material['currency'] ?? 'AFN'}', 80),
                            _buildDataCell('${material['seller_paid_amount'] ?? '-'} ${material['currency'] ?? 'AFN'}', 80),
                            _buildDataCell(material['seller_payment_method'] == 'cash'
                                ? l10n.cash
                                : material['seller_payment_method'] == 'loan_full'
                                    ? l10n.fullLoan
                                    : material['seller_payment_method'] == 'loan_partial'
                                        ? l10n.partialLoan
                                        : '-', 80),
                            _buildDataCell(material['product'] ?? '-', 60),
                            _buildDataCell(material['commission'] ?? '-', 60),
                            _buildDataCell(material['transfer_cost'] ?? '-', 60),
                            _buildDataCell(material['miscellaneous'] ?? '-', 60),
                            _buildDataCell(material['ghurfedari'] ?? '-', 60),
                            _buildDataCell(material['barchalani'] ?? '-', 60),
                            Container(
                              width: 70,
                              child: _buildPurchaseTypeChip(material['purchase_type'], l10n),
                            ),
                            _buildDataCell('${material['final_price'] ?? '-'} ${material['currency'] ?? 'AFN'}', 80, isBold: true, isRed: true),
                            SizedBox(
                              width: 80,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isImported)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.cloud_done, color: Colors.green, size: 12),
                                          SizedBox(width: 2),
                                          Text(
                                            '📥',
                                            style: TextStyle(fontSize: 8),
                                          ),
                                        ],
                                      ),
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: const Color(0xFFCB001D), size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showEditDialog(context, material, l10n),
                                    tooltip: l10n.edit,
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showDeleteDialog(context, material, l10n),
                                    tooltip: l10n.delete,
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
                  Text(l10n.show, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
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
                  Text(l10n.perPage, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              Row(
                children: [
                  Text('${l10n.page} $_currentPage ${l10n.pageOf} $_totalPages', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
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

  Widget _buildPurchaseTypeChip(String? purchaseType, AppLocalizations l10n) {
    final type = purchaseType ?? l10n.unknown;
    final isDirect = type == l10n.direct;
    
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
    final l10n = AppLocalizations.of(context)!;
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
    final exchangeRateController = TextEditingController(text: '1');
    final afnEquivalentController = TextEditingController();

    String selectedSellerPaymentMethod = 'cash';
    String selectedCurrency = 'AFN';
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
      double exchangeRate = double.tryParse(exchangeRateController.text) ?? 1;

      double basePrice = grossWeight * unitPrice;
      double expensesAfn = productCost + commission + transferCost + miscellaneous + ghurfedari + barchalani;
      double expensesInPriceCurrency = selectedCurrency == 'USD' ? (exchangeRate <= 0 ? expensesAfn : expensesAfn / exchangeRate) : expensesAfn;
      double finalPrice = selectedCurrency == 'USD' ? basePrice + expensesInPriceCurrency : basePrice + expensesAfn;
      finalPriceController.text = finalPrice.toStringAsFixed(0);
      afnEquivalentController.text = (selectedCurrency == 'USD'
              ? finalPrice * exchangeRate
              : finalPrice)
          .toStringAsFixed(0);
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
              title: Text(l10n.addRawMaterial),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.selectSupplier,
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: selectedSupplierId,
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text(l10n.selectSupplier)),
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
                          labelText: l10n.dateRequired,
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: const OutlineInputBorder(),
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
                        decoration: InputDecoration(
                          labelText: l10n.materialNameRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText: l10n.dischargeLocationRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: materialTypeController,
                        decoration: InputDecoration(
                          labelText: l10n.materialTypeRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.unitRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: unitController.text.isNotEmpty ? unitController.text : null,
                        items: [
                          DropdownMenuItem<String>(value: 'کیلوگرم', child: Text(l10n.kgUnit)),
                          DropdownMenuItem<String>(value: 'تن', child: Text(l10n.tonUnit)),
                          DropdownMenuItem<String>(value: 'متر', child: Text(l10n.meterUnit)),
                          DropdownMenuItem<String>(value: 'عدد', child: Text(l10n.pcsUnit)),
                          DropdownMenuItem<String>(value: 'لیتر', child: Text(l10n.literUnit)),
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
                        decoration: InputDecoration(
                          labelText: l10n.thicknessRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.purchaseTypeRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: selectedPurchaseType,
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text(l10n.selectPurchaseType)),
                          DropdownMenuItem<String>(value: 'مستقیم', child: Text(l10n.direct)),
                          DropdownMenuItem<String>(value: 'غیر مستقیم', child: Text(l10n.indirect)),
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
                              decoration: InputDecoration(
                                labelText: l10n.netWeightRequired,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: grossWeightController,
                              decoration: InputDecoration(
                                labelText: l10n.grossWeightRequired,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              controller: unitPriceController,
                              decoration: InputDecoration(
                                labelText: '${l10n.unitPrice} (${selectedCurrency}) *',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCurrency,
                              decoration: InputDecoration(
                                labelText: l10n.currencyPrice,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'AFN', child: Text('افغانی')),
                                DropdownMenuItem(value: 'USD', child: Text('دلار')),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  selectedCurrency = value ?? 'AFN';
                                  _updateFinalPrice();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (selectedCurrency == 'USD')
                        TextField(
                          controller: exchangeRateController,
                          decoration: InputDecoration(
                            labelText: l10n.exchangeRate,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _updateFinalPrice(),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: productController,
                        decoration: InputDecoration(
                          labelText: l10n.productPrice,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              decoration: InputDecoration(
                                labelText: '${l10n.sellerAmount} (${selectedCurrency})',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB001D)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSellerPaymentMethod,
                              decoration: InputDecoration(
                                labelText: l10n.sellerPaymentMethod,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          decoration: InputDecoration(
                            labelText: l10n.sellerInitialPayment,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        l10n.sellerLoanNote,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commissionController,
                              decoration: InputDecoration(
                                labelText: l10n.commission,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: transferCostController,
                              decoration: InputDecoration(
                                labelText: l10n.transferCost,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              decoration: InputDecoration(
                                labelText: l10n.ghurfedari,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: barchalaniController,
                              decoration: InputDecoration(
                                labelText: l10n.barchalani,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              decoration: InputDecoration(
                                labelText: l10n.miscellaneous,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                labelText: '${l10n.finalTotalPrice} (${selectedCurrency})',
                                border: const OutlineInputBorder(),
                                fillColor: const Color(0xFFF5F0EB),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFCB001D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: afnEquivalentController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: l10n.afnEquivalent,
                          border: const OutlineInputBorder(),
                          fillColor: const Color(0xFFF5F0EB),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFCB001D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedSupplierId == null || nameController.text.isEmpty || selectedPurchaseType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.fillAllRequiredFields), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final sellerPayment = double.tryParse(sellerPaymentController.text) ?? 0;
                    final sellerPaidAmount = selectedSellerPaymentMethod == 'cash'
                        ? sellerPayment
                        : double.tryParse(sellerPaidAmountController.text) ?? 0;

                    if ((selectedSellerPaymentMethod == 'loan_full' || selectedSellerPaymentMethod == 'loan_partial') && sellerPaidAmount > sellerPayment) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.sellerPaymentExceedsBase), backgroundColor: Colors.red),
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
                      'currency': selectedCurrency,
                      'exchange_rate': double.tryParse(exchangeRateController.text) ?? 1,
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
                        'supplier_id': int.parse(selectedSupplierId!),
                        'invoice_number': 'RM-${DateTime.now().millisecondsSinceEpoch}',
                        'customer_name': supplier['name'] ?? 'فروشنده',
                        'customer_company': supplier['address'] ?? '',
                        'total_amount': sellerPayment,
                        'paid_amount': selectedSellerPaymentMethod == 'loan_full' ? 0 : sellerPaidAmount,
                        'remaining_amount': remainingSeller,
                        'loan_type': selectedSellerPaymentMethod == 'loan_full' ? 'full' : 'partial',
                        'loan_source': 'supplier',
                        'currency': selectedCurrency,
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
                        SnackBar(content: Text(l10n.rawMaterialAddedSuccess), backgroundColor: Colors.green),
                      );
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.errorAddingRawMaterial), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                  ),
                  child: Text(l10n.save),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> material, AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.editInDevelopment), duration: const Duration(seconds: 2)),
    );
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> material, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(l10n.deleteRawMaterial),
          content: Text('${l10n.deleteConfirmation} "${material['name']}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await _db.deleteRawMaterial(material['id']);
                Navigator.pop(context);
                if (result != -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.rawMaterialDeletedSuccess), backgroundColor: Colors.green),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.errorDeletingRawMaterial), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
    );
  }

  // ============ EXPORT TO EXCEL ============
  Future<void> _exportToExcel() async {
    final l10n = AppLocalizations.of(context)!;
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFCB001D)),
        ),
      );

      final excel = Excel.createExcel();
      final sheet = excel['RawMaterials'];

      final headers = [
        'شناسه', 'شناسه تامین‌کننده', 'نام تامین‌کننده', 'نام ماده خام',
        'محل تخلیه', 'نوع ماده', 'ضخامت', 'وزن خالص', 'وزن ناخالص',
        'تاریخ (شمسی)', 'تاریخ (میلادی)', 'واحد', 'قیمت واحد', 'قیمت محصول',
        'کمیسیون', 'هزینه حمل', 'متفرقه', 'غرفه‌داری', 'بارچالانی',
        'نوع خرید', 'مبلغ فروشنده', 'روش پرداخت فروشنده', 'مبلغ پرداختی فروشنده',
        'واحد پول', 'نرخ ارز', 'قیمت نهایی', 'تاریخ ایجاد'
      ];

      final dbFields = [
        'id', 'supplier_id', 'supplier_name', 'name', 'location', 'material_type',
        'thickness', 'net_weight', 'gross_weight', 'date', 'date_en', 'unit',
        'unit_price', 'product', 'commission', 'transfer_cost', 'miscellaneous',
        'ghurfedari', 'barchalani', 'purchase_type', 'seller_payment',
        'seller_payment_method', 'seller_paid_amount', 'currency', 'exchange_rate',
        'final_price', 'created_at'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = CellStyle(
          bold: true,
          fontSize: 11,
          backgroundColorHex: ExcelColor.fromHexString('FFCB001D'),
          fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
        );
      }

      for (int row = 0; row < materials.length; row++) {
        final material = materials[row];
        final supplierName = suppliers.firstWhere(
          (s) => s['id'] == material['supplier_id'],
          orElse: () => {'name': ''},
        )['name'] ?? '';

        for (int col = 0; col < dbFields.length; col++) {
          String value = '';
          final field = dbFields[col];
          
          if (field == 'supplier_name') {
            value = supplierName.toString();
          } else {
            value = material[field]?.toString() ?? '';
          }
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1)).value = TextCellValue(value);
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'raw_materials_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';
      
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        
        Navigator.pop(context);
        
        String? savedPath;
        if (Platform.isAndroid) {
          try {
            final dir = Directory('/storage/emulated/0/Download');
            if (await dir.exists()) {
              final targetPath = '${dir.path}/$fileName';
              await file.copy(targetPath);
              savedPath = targetPath;
            }
          } catch (_) {}
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${l10n.exportSuccess}: ${savedPath ?? filePath}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.exportFailed}: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============ IMPORT FROM EXCEL ============
  Future<void> _importFromExcel() async {
    final l10n = AppLocalizations.of(context)!;
    
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'انتخاب فایل اکسل',
        allowMultiple: false,
        withData: true,
        withReadStream: true,
      );

      if (result == null || result.files.isEmpty) return;
      
      final filePath = result.files.single.path;
      if (filePath == null) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFCB001D)),
        ),
      );

      final importedMaterials = await _importExcelData(filePath);
      Navigator.pop(context);

      if (importedMaterials.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ فایل انتخاب شده معتبر نیست یا داده‌ای برای وارد کردن ندارد'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await _showImportPreviewDialog(importedMaterials);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.importFailed}: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============ IMPORT EXCEL DATA ============
// ============ IMPORT EXCEL DATA ============
Future<List<Map<String, dynamic>>> _importExcelData(String filePath) async {
  final file = File(filePath);
  final bytes = await file.readAsBytes();
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables.values.first;

  // Find the first row that contains headers (look for non-empty cells)
  int headerRowIndex = 0;
  for (int row = 0; row < 10 && row < sheet.maxRows; row++) {
    bool hasData = false;
    for (int col = 0; col < sheet.maxColumns && col < 20; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      if (cell.value != null && cell.value!.toString().trim().isNotEmpty) {
        hasData = true;
        break;
      }
    }
    if (hasData) {
      headerRowIndex = row;
      break;
    }
  }

  // Get headers from the found row
  final headers = <String>[];
  for (int col = 0; col < sheet.maxColumns; col++) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: headerRowIndex));
    if (cell.value != null && cell.value!.toString().trim().isNotEmpty) {
      headers.add(cell.value!.toString().trim());
    }
  }

  print('📋 Excel Headers found at row $headerRowIndex: $headers');
  print('📋 Total headers: ${headers.length}');
  print('📋 Total rows in sheet: ${sheet.maxRows}');

  // If still no headers, try to use first row with any data
  if (headers.isEmpty) {
    for (int col = 0; col < sheet.maxColumns; col++) {
      headers.add('ستون ${col + 1}');
    }
  }

  // Define possible field mappings
  final fieldMappings = {
    'name': ['نام ماده خام', 'نام مواد', 'مواد', 'تفصیل', 'شرح', 'نام', 'ارسالی', 'کالا', 'product', 'description', 'item', 'شماره'],
    'supplier_name': ['نام تامین‌کننده', 'تامین‌کننده', 'اسم فروشنده', 'فروشنده', 'supplier', 'vendor', 'seller'],
    'gross_weight': ['وزن ناخالص', 'وزن کل', 'وزن', 'gross weight', 'total weight', 'weight', 'وزن ناخالص'],
    'net_weight': ['وزن خالص', 'net weight'],
    'unit_price': ['قیمت واحد', 'قیمت', 'unit price', 'price'],
    'unit': ['واحد', 'unit'],
    'date': ['تاریخ (شمسی)', 'تاریخ', 'date', 'تاریخ شمسی'],
    'date_en': ['تاریخ (میلادی)', 'date en', 'english date'],
    'location': ['محل تخلیه', 'تخلیه', 'location', 'تخلیه شده'],
    'material_type': ['نوع ماده', 'نوع مواد', 'material type', 'type', 'نوع'],
    'thickness': ['ضخامت', 'thickness', 'ض'],
    'purchase_type': ['نوع خرید', 'purchase type'],
    'currency': ['واحد پول', 'currency'],
    'exchange_rate': ['نرخ ارز', 'exchange rate'],
    'product': ['قیمت محصول', 'product price'],
    'commission': ['کمیسیون', 'commission'],
    'transfer_cost': ['هزینه حمل', 'transfer cost'],
    'miscellaneous': ['متفرقه', 'miscellaneous'],
    'ghurfedari': ['غرفه‌داری', 'ghurfedari'],
    'barchalani': ['بارچالانی', 'barchalani'],
    'seller_payment': ['مبلغ فروشنده', 'seller payment'],
    'seller_payment_method': ['روش پرداخت', 'payment method'],
    'seller_paid_amount': ['مبلغ پرداختی', 'paid amount'],
    'final_price': ['قیمت نهایی', 'final price'],
  };

  // Find column mappings
  final columnMap = <String, int>{};
  for (int i = 0; i < headers.length; i++) {
    final header = headers[i].trim();
    print('🔍 Checking header: "$header"');
    for (final entry in fieldMappings.entries) {
      final field = entry.key;
      final possibleNames = entry.value;
      for (final possibleName in possibleNames) {
        if (header.contains(possibleName) || 
            possibleName.contains(header) ||
            header.trim().toLowerCase() == possibleName.trim().toLowerCase()) {
          columnMap[field] = i;
          print('✅ Matched: "$header" → $field');
          break;
        }
      }
      if (columnMap.containsKey(field)) break;
    }
  }

  // If no matches, use all columns as generic data
  if (columnMap.isEmpty) {
    print('⚠️ No column matches found, using all columns');
    for (int i = 0; i < headers.length; i++) {
      columnMap['field_$i'] = i;
    }
  }

  final materials = <Map<String, dynamic>>[];
  
  // Process rows (start after header row)
  for (int row = headerRowIndex + 1; row < sheet.maxRows; row++) {
    final material = <String, dynamic>{};
    bool hasAnyData = false;
    String? nameValue;

    // Collect data from mapped columns
    for (final entry in columnMap.entries) {
      final field = entry.key;
      final col = entry.value;
      
      if (col < sheet.maxColumns) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        String value = cell.value?.toString() ?? '';
        if (value.trim().isNotEmpty) {
          // Try to parse as number
          final cleanValue = value.trim().replaceAll(',', '');
          final numValue = double.tryParse(cleanValue);
          if (numValue != null && cleanValue.isNotEmpty) {
            material[field] = numValue;
          } else {
            material[field] = value.trim();
          }
          hasAnyData = true;
          
          if (field == 'name' || field.startsWith('field_')) {
            if (nameValue == null && value.trim().length > 1) {
              nameValue = value.trim();
            }
          }
        }
      }
    }

    // Skip empty rows
    if (!hasAnyData) continue;

    // Find name from any column if not found
    if (nameValue == null) {
      for (int col = 0; col < sheet.maxColumns && nameValue == null; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        String value = cell.value?.toString() ?? '';
        if (value.trim().isNotEmpty && value.trim().length > 1) {
          nameValue = value.trim();
        }
      }
    }

    // Skip if no name
    if (nameValue == null || nameValue.isEmpty) continue;

    // Build material
    material['name'] = nameValue;

    // Set defaults for all required fields
    if (!material.containsKey('unit') || material['unit'].toString().isEmpty) {
      material['unit'] = 'کیلوگرم';
    }
    if (!material.containsKey('currency') || material['currency'].toString().isEmpty) {
      material['currency'] = 'AFN';
    }
    if (!material.containsKey('seller_payment_method') || material['seller_payment_method'].toString().isEmpty) {
      material['seller_payment_method'] = 'cash';
    }
    if (!material.containsKey('purchase_type') || material['purchase_type'].toString().isEmpty) {
      material['purchase_type'] = 'مستقیم';
    }
    if (!material.containsKey('gross_weight') || material['gross_weight'].toString().isEmpty) {
      material['gross_weight'] = '0';
    }
    if (!material.containsKey('net_weight') || material['net_weight'].toString().isEmpty) {
      material['net_weight'] = '0';
    }
    if (!material.containsKey('unit_price') || material['unit_price'].toString().isEmpty) {
      material['unit_price'] = '0';
    }
    if (!material.containsKey('seller_payment')) {
      material['seller_payment'] = '0';
    }
    if (!material.containsKey('seller_paid_amount')) {
      material['seller_paid_amount'] = '0';
    }
    if (!material.containsKey('final_price')) {
      material['final_price'] = '0';
    }
    if (!material.containsKey('date') || material['date'].toString().isEmpty) {
      final now = DateTime.now();
      material['date'] = PersianDateConverter.gregorianToJalali(now);
      material['date_en'] = PersianDateConverter.getEnglishDate(now);
    }
    
    // Mark as imported (will be removed before insert)
    material['_imported_by_excel'] = true;
    
    materials.add(material);
    print('✅ Row $row imported: ${material['name']}');
  }

  print('📊 Total imported: ${materials.length} materials');
  return materials;
}

  // ============ SHOW IMPORT PREVIEW DIALOG ============
  Future<void> _showImportPreviewDialog(List<Map<String, dynamic>> importedMaterials) async {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;
    
    return showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
        child: AlertDialog(
          title: Text('📊 ${l10n.importPreview}'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SizedBox(
            width: 600,
            height: 400,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l10n.itemsToImport}: ${importedMaterials.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFCB001D),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_done, color: Colors.green, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'وارد شده از اکسل',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCB001D).withOpacity(0.1),
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildPreviewHeader('#', 40),
                                  _buildPreviewHeader(l10n.materialName, 120),
                                  _buildPreviewHeader(l10n.grossWeight, 80),
                                  _buildPreviewHeader(l10n.unit, 60),
                                  _buildPreviewHeader(l10n.unitPrice, 80),
                                  _buildPreviewHeader(l10n.currency, 60),
                                ],
                              ),
                            ),
                            ...importedMaterials.take(10).toList().asMap().entries.map((entry) {
                              final index = entry.key;
                              final material = entry.value;
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildPreviewCell((index + 1).toString(), 40),
                                    _buildPreviewCell(material['name']?.toString() ?? '-', 120),
                                    _buildPreviewCell(material['gross_weight']?.toString() ?? '0', 80),
                                    _buildPreviewCell(material['unit']?.toString() ?? '-', 60),
                                    _buildPreviewCell(material['unit_price']?.toString() ?? '0', 80),
                                    _buildPreviewCell(material['currency']?.toString() ?? 'AFN', 60),
                                  ],
                                ),
                              );
                            }),
                            if (importedMaterials.length > 10)
                              Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '... ${l10n.andMore} ${importedMaterials.length - 10} ${l10n.items}',
                                  style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.importConfirmation,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performImport(importedMaterials);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
              ),
              child: Text('${l10n.import} (${importedMaterials.length})'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewHeader(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Color(0xFF1A1A2E),
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPreviewCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: Color(0xFF1A1A2E)),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ============ PERFORM IMPORT ============
  Future<void> _performImport(List<Map<String, dynamic>> importedMaterials) async {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFCB001D)),
      ),
    );

    try {
      int inserted = 0;
      int skipped = 0;
      List<String> errors = [];

      for (var material in importedMaterials) {
        try {
          String? supplierName = material['supplier_name']?.toString();
          if (supplierName != null && supplierName.isNotEmpty) {
            var existingSupplier = suppliers.firstWhere(
              (s) => s['name'] == supplierName,
              orElse: () => {},
            );
            
            if (existingSupplier.isNotEmpty) {
              material['supplier_id'] = existingSupplier['id'];
            } else {
              final supplierId = await _db.insertSupplier({
                'name': supplierName,
                'phone': '',
                'address': '',
              });
              if (supplierId != -1) {
                material['supplier_id'] = supplierId;
              } else {
                skipped++;
                errors.add('خطا در ایجاد تامین‌کننده: $supplierName');
                continue;
              }
            }
          }

          material.remove('supplier_name');
          
          // Remove temporary import flag
          material.remove('_imported_by_excel');
          
          // Remove any field_ or extra_ columns
          material.removeWhere((key, value) => key.startsWith('field_'));
          material.removeWhere((key, value) => key.startsWith('extra_'));

          if (material['date'] == null || material['date'].toString().isEmpty) {
            final now = DateTime.now();
            material['date'] = PersianDateConverter.gregorianToJalali(now);
            material['date_en'] = PersianDateConverter.getEnglishDate(now);
          }

          final result = await _db.insertRawMaterial(material);
          if (result != -1) {
            inserted++;
          } else {
            skipped++;
          }
        } catch (e) {
          skipped++;
          errors.add('خطا در وارد کردن ${material['name']}: $e');
        }
      }

      Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('📥 ${l10n.importResult}'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('✅ ${l10n.successfullyImported}: $inserted ${l10n.items}'),
                    ],
                  ),
                  if (skipped > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('⚠️ ${l10n.skipped}: $skipped ${l10n.items}'),
                      ],
                    ),
                  ],
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.errors,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    ...errors.take(5).map((error) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $error', style: const TextStyle(fontSize: 12, color: Colors.red)),
                      ),
                    ),
                    if (errors.length > 5)
                      Text('... ${l10n.andMore} ${errors.length - 5} ${l10n.errors}'),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_done, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text(
                          '✅ موارد وارد شده با برچسب "وارد شده از اکسل" مشخص شده‌اند',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCB001D),
                ),
                child: Text(l10n.ok),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.importFailed}: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Text(
                      l10n.rawMaterialsManagement,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.rawMaterialsSubtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.file_download, color: Color(0xFFCB001D)),
                      tooltip: l10n.exportToExcel,
                      onPressed: materials.isEmpty ? null : _exportToExcel,
                      style: IconButton.styleFrom(
                        backgroundColor: materials.isEmpty 
                            ? Colors.grey.shade200 
                            : const Color(0xFFCB001D).withOpacity(0.08),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.file_upload, color: Colors.green),
                      tooltip: l10n.importFromExcel,
                      onPressed: _importFromExcel,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.08),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: () { _showAddDialog(context); },
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: Text(l10n.addRawMaterial, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB001D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _buildStatCard(l10n.totalMaterials, materials.length.toString()),
                const SizedBox(width: 12),
                _buildStatCard(l10n.suppliers, suppliers.length.toString()),
              ],
            ),
            const SizedBox(height: 12),

            if (materials.isNotEmpty) ...[
              Text(
                l10n.stockSummaryByUnit,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _buildUnitSummaryCards(l10n)),
              ),
            ],
            const SizedBox(height: 14),

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
                      tabs: [
                        Tab(text: l10n.rawMaterialsTab),
                        Tab(text: l10n.stockTab),
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
                          _buildMainTable(l10n),
                          _buildStockTable(l10n),
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
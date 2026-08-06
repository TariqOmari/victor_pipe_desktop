import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

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

  // Class level variable for English date
  String? selectedEnglishDate;

  // Scroll controller for horizontal scrolling
  final ScrollController _horizontalScrollController = ScrollController();

  // Helper to check if unit is weight-based
  bool _isWeightUnit(String unit) {
    return unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg' || 
           unit == 'تن' || unit == 'ton' || unit == 'Ton';
  }

  // Get total tons of all raw materials
  double _getTotalTons() {
    double totalTons = 0;
    for (var material in materials) {
      String unit = material['unit'] ?? '';
      double grossWeight = double.tryParse(material['gross_weight']?.toString() ?? '0') ?? 0;
      
      if (_isWeightUnit(unit)) {
        // Convert to tons (if kg, divide by 1000)
        if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
          totalTons += grossWeight / 1000;
        } else {
          totalTons += grossWeight; // Already in tons
        }
      }
    }
    return totalTons;
  }

  // Unit translation helper - FOR TABLE DISPLAY ONLY
  String _translateUnit(String unit, AppLocalizations l10n) {
    // For weight units in the TABLE, show as tons
    if (_isWeightUnit(unit)) return l10n.tonUnit;
    if (unit == 'متر' || unit == 'm' || unit == 'M') return l10n.meterUnit;
    if (unit == 'عدد' || unit == 'pcs' || unit == 'Pcs') return l10n.pcsUnit;
    if (unit == 'لیتر' || unit == 'l' || unit == 'L') return l10n.literUnit;
    return unit;
  }

  // Format unit with conversion for table display - ALWAYS shows kg as tons
  String _formatUnitWithConversion(String unit, double weight, AppLocalizations l10n) {
    // For weight units in the TABLE, ALWAYS show as tons
    if (_isWeightUnit(unit)) {
      double tons = weight / 1000;
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 1)} ${l10n.tonUnit}';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} ${_translateUnit(unit, l10n)}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
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

  // ============ BUILD UNIT SUMMARY CARDS ============
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
      
      // Format weights with conversion
      String displayNet = _formatUnitWithConversion(unit, totals['net']!, l10n);
      String displayGross = _formatUnitWithConversion(unit, totals['gross']!, l10n);
      
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
                    displayNet,
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
                    displayGross,
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

  // ============ BUILD MAIN TABLE ============
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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.06), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Column(
                    children: [
                      // Table Header
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
                      // Table Rows
                      ..._paginatedMaterials.map((material) {
                        final isSelected = _selectedIds.contains(material['id'] as int);
                        final translatedUnit = _translateUnit(material['unit'] ?? '-', l10n);
                        
                        // Get weight values for formatting
                        double netWeight = double.tryParse(material['net_weight']?.toString() ?? '0') ?? 0;
                        double grossWeight = double.tryParse(material['gross_weight']?.toString() ?? '0') ?? 0;
                        String unit = material['unit'] ?? '-';
                        
                        // Format weights with conversion if needed
                        String displayNet = _formatUnitWithConversion(unit, netWeight, l10n);
                        String displayGross = _formatUnitWithConversion(unit, grossWeight, l10n);
                        
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
                              _buildDataCell(displayNet, 65),
                              _buildDataCell(displayGross, 65),
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
        ),
        // Pagination with Scroll Indicators
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
                  // Horizontal Scroll Indicators
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFCB001D), size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30),
                    onPressed: () {
                      _horizontalScrollController.animateTo(
                        _horizontalScrollController.offset - 200,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    tooltip: 'Scroll Left',
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFFCB001D), size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30),
                    onPressed: () {
                      _horizontalScrollController.animateTo(
                        _horizontalScrollController.offset + 200,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    tooltip: 'Scroll Right',
                  ),
                  const SizedBox(width: 8),
                  // Page Info
                  Text('${l10n.page} $_currentPage ${l10n.pageOf} $_totalPages', 
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
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

    // Helper to convert kg to ton (ONLY USED IN DIALOG)
    String _convertToTon(double weight) {
      if (weight <= 0) return '0';
      double tons = weight / 1000;
      return tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2);
    }

    String _getUnitSymbol(String unit) {
      if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') return 'تن';
      if (unit == 'تن' || unit == 'ton' || unit == 'Ton') return 'تن';
      if (unit == 'متر' || unit == 'm' || unit == 'M') return 'متر';
      if (unit == 'عدد' || unit == 'pcs' || unit == 'Pcs') return 'عدد';
      if (unit == 'لیتر' || unit == 'l' || unit == 'L') return 'لیتر';
      return unit;
    }

    // ============================================
    // CHANGED: Now uses NET WEIGHT for calculations
    // ============================================
    void _updateFinalPrice() {
      // CHANGED: Use netWeight instead of grossWeight
      double netWeight = double.tryParse(netWeightController.text) ?? 0;
      double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      double productCost = double.tryParse(productController.text) ?? 0;
      double commission = double.tryParse(commissionController.text) ?? 0;
      double transferCost = double.tryParse(transferCostController.text) ?? 0;
      double miscellaneous = double.tryParse(miscellaneousController.text) ?? 0;
      double ghurfedari = double.tryParse(ghurfedariController.text) ?? 0;
      double barchalani = double.tryParse(barchalaniController.text) ?? 0;
      double exchangeRate = double.tryParse(exchangeRateController.text) ?? 1;

      // CHANGED: basePrice = netWeight * unitPrice (not grossWeight)
      double basePrice = netWeight * unitPrice;
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
          double netWeight = double.tryParse(netWeightController.text) ?? 0;
          double grossWeight = double.tryParse(grossWeightController.text) ?? 0;
          String selectedUnit = unitController.text;
          
          String netTon = _convertToTon(netWeight);
          String grossTon = _convertToTon(grossWeight);
          String unitSymbol = _getUnitSymbol(selectedUnit);
          bool isKg = selectedUnit == 'کیلوگرم' || selectedUnit == 'kg' || selectedUnit == 'Kg';
          
          // Get unit display name
          String unitDisplay = '';
          if (selectedUnit == 'کیلوگرم' || selectedUnit == 'kg' || selectedUnit == 'Kg') {
            unitDisplay = 'kg';
          } else if (selectedUnit == 'تن' || selectedUnit == 'ton' || selectedUnit == 'Ton') {
            unitDisplay = 'تن';
          } else {
            unitDisplay = selectedUnit;
          }

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
                      // Net Weight with kg AND ton side by side
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: netWeightController,
                            decoration: InputDecoration(
                              labelText: l10n.netWeightRequired,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              setStateDialog(() {});
                              _updateFinalPrice();
                            },
                          ),
                          if (netWeight > 0 && selectedUnit.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCB001D).withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFCB001D).withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isKg) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$netWeight kg',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, color: const Color(0xFFCB001D), size: 14),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCB001D).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$netTon تن',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFCB001D),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$netWeight $unitDisplay',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Gross Weight with kg AND ton side by side
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: grossWeightController,
                            decoration: InputDecoration(
                              labelText: l10n.grossWeightRequired,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              setStateDialog(() {});
                              _updateFinalPrice();
                            },
                          ),
                          if (grossWeight > 0 && selectedUnit.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCB001D).withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFCB001D).withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isKg) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$grossWeight kg',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, color: const Color(0xFFCB001D), size: 14),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCB001D).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$grossTon تن',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFCB001D),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$grossWeight $unitDisplay',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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
                      final supplier = suppliers.firstWhere((s) => s['id'].toString() == selectedSupplierId, orElse: () => {});
                      final remainingSeller = (sellerPayment - sellerPaidAmount) < 0 ? 0 : (sellerPayment - sellerPaidAmount);
                      final loanPayload = {
                        'supplier_id': int.parse(selectedSupplierId!),
                        'raw_material_id': result,
                        'invoice_number': 'SL-${DateTime.now().millisecondsSinceEpoch}',
                        'supplier_name': supplier['name'] ?? 'فروشنده',
                        'supplier_company': supplier['address'] ?? '',
                        'total_amount': sellerPayment,
                        'paid_amount': selectedSellerPaymentMethod == 'loan_full' ? 0 : sellerPaidAmount,
                        'remaining_amount': remainingSeller,
                        'loan_type': selectedSellerPaymentMethod == 'loan_full' ? 'full' : 'partial',
                        'currency': selectedCurrency,
                        'date': dateController.text.trim(),
                        'date_en': selectedEnglishDate,
                        'description': 'خرید مواد خام از فروشنده',
                      };
                      final loanId = await _db.insertSupplierLoan(loanPayload);
                      if (loanId != -1 && sellerPaidAmount > 0) {
                        await _db.insertSupplierLoanPayment({
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
            // Header
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
            const SizedBox(height: 16),

            // ONE CARD - Total Tons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
                ],
                border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.15), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCB001D).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.scale, color: Color(0xFFCB001D), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مجموع وزن به تن',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${_getTotalTons().toStringAsFixed(_getTotalTons() % 1 == 0 ? 0 : 1)} تن',
                          style: const TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            color: Color(0xFFCB001D)
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Unit-based totals cards - Summary
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

            // Main Table Container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: _buildMainTable(l10n),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
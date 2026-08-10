import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _sales = [];
  int _currentPage = 0;
  int _rowsPerPage = 10;
  final Set<String> _selectedInvoices = {};
  List<Map<String, dynamic>> _partyOptions = [];
  String _searchQuery = '';
  String _selectedFilter = 'همه';
  final TextEditingController _searchController = TextEditingController();

  bool _isWeightUnit(String unit) {
    return unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg' || 
           unit == 'تن' || unit == 'ton' || unit == 'Ton';
  }

  String _formatWeightWithConversion(String unit, double weight) {
    if (_isWeightUnit(unit)) {
      double tons = weight / 1000;
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} $unit';
  }

  double _getTotalTons() {
    double totalTons = 0;
    for (var sale in _sales) {
      String unit = sale['unit']?.toString() ?? '';
      double weight = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
      
      if (_isWeightUnit(unit)) {
        if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
          totalTons += weight / 1000;
        } else {
          totalTons += weight;
        }
      }
    }
    return totalTons;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _db.getCustomers();
      final companies = await _db.getCompanies();
      final sales = await _db.getSalesInvoices();
      final options = <Map<String, dynamic>>[];
      for (final customer in customers) {
        options.add({
          'id': customer['id'],
          'name': customer['name'],
          'phone': customer['phone'],
          'address': customer['address'],
          'company': customer['type'],
          'source': 'customer',
        });
      }
      for (final company in companies) {
        options.add({
          'id': company['id'],
          'name': company['name'],
          'phone': company['phone'],
          'address': company['address'],
          'company': company['name'],
          'source': 'company',
        });
      }
      options.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _companies = companies;
        _sales = sales;
        _partyOptions = options;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar(l10n.errorLoadingSales, Colors.red);
    }
  }

  // ============================================
  // EDIT SALE DIALOG
  // ============================================
  Future<void> _showEditSaleDialog(Map<String, dynamic> sale) async {
    final l10n = AppLocalizations.of(context)!;
    
    final customerNameController = TextEditingController(text: sale['customer_name']?.toString() ?? '');
    final phoneController = TextEditingController(text: sale['customer_phone']?.toString() ?? '');
    final addressController = TextEditingController(text: sale['customer_address']?.toString() ?? '');
    final companyController = TextEditingController(text: sale['customer_company']?.toString() ?? '');
    final productController = TextEditingController(text: sale['product_name']?.toString() ?? '');
    final genderController = TextEditingController(text: sale['gender']?.toString() ?? '');
    final sizeController = TextEditingController(text: sale['size']?.toString() ?? '');
    final thicknessController = TextEditingController(text: sale['thickness']?.toString() ?? '');
    final weightPerUnitController = TextEditingController(text: sale['weight_per_unit']?.toString() ?? '');
    final unitCountController = TextEditingController(text: sale['unit_count']?.toString() ?? '');
    final totalWeightController = TextEditingController(text: sale['total_weight']?.toString() ?? '');
    final timeController = TextEditingController(text: sale['loading_time']?.toString() ?? _formatTimeOfDay(TimeOfDay.now()));
    final unitController = TextEditingController(text: sale['unit']?.toString() ?? 'کیلو');
    final unitPriceController = TextEditingController(text: sale['unit_price']?.toString() ?? '');
    final totalPriceController = TextEditingController(text: sale['total_price']?.toString() ?? '');
    final finalPriceController = TextEditingController(text: sale['final_price']?.toString() ?? '');
    final priceRateController = TextEditingController(text: sale['price_rate']?.toString() ?? '1');
    final loadingController = TextEditingController(text: sale['loading_cost']?.toString() ?? '');
    final transferController = TextEditingController(text: sale['transfer_cost']?.toString() ?? '');
    final clearanceController = TextEditingController(text: sale['clearance_cost']?.toString() ?? '');
    final discountController = TextEditingController(text: sale['discount']?.toString() ?? '');
    final descriptionController = TextEditingController(text: sale['description']?.toString() ?? '');
    final equivalentController = TextEditingController();
    final dateController = TextEditingController(text: sale['date']?.toString() ?? PersianDateConverter.getCurrentPersianDate());
    final paidAmountController = TextEditingController(text: sale['paid_amount']?.toString() ?? '');
    final invoiceNumberController = TextEditingController(text: sale['invoice_number']?.toString() ?? '');
    
    String selectedPaymentMethod = sale['payment_method']?.toString() ?? 'cash';
    String selectedCurrency = sale['currency']?.toString() ?? 'USD';
    String selectedType = sale['sale_type']?.toString() ?? 'فروش';
    Map<String, dynamic>? selectedParty;
    String selectedEnglishDate = sale['date_en']?.toString() ?? PersianDateConverter.getEnglishDate(DateTime.now());
    String selectedEnglishTime = sale['loading_time_en']?.toString() ?? _formatTimeOfDay(TimeOfDay.now());

    final List<Map<String, dynamic>> producedProducts = await _db.getProducedProducts();
    final List<Map<String, dynamic>> productOptions = producedProducts.map((product) {
      return {
        'id': product['id'],
        'name': product['product_name']?.toString() ?? '-',
        'unit': product['unit']?.toString() ?? 'کیلو',
        'thickness': product['thickness']?.toString() ?? '',
        'loading': product['loading']?.toString() ?? '',
      };
    }).toList();

    int? selectedProductId = sale['produced_product_id'] as int?;
    String? selectedProductName = sale['product_name']?.toString();
    String? selectedProductUnit = sale['unit']?.toString();
    String? selectedProductThickness = sale['thickness']?.toString();

    if (sale['customer_name'] != null) {
      selectedParty = _partyOptions.firstWhere(
        (p) => p['name']?.toString() == sale['customer_name']?.toString(),
        orElse: () => {
          'id': null,
          'name': sale['customer_name']?.toString() ?? '',
          'phone': sale['customer_phone']?.toString() ?? '',
          'address': sale['customer_address']?.toString() ?? '',
          'company': sale['customer_company']?.toString() ?? '',
          'source': 'customer',
        },
      );
    }

    void updateTotals() {
      double weightPerUnit = double.tryParse(weightPerUnitController.text) ?? 0;
      String currentUnit = unitController.text;
      
      double weightPerUnitInTons = weightPerUnit;
      bool isKg = currentUnit == 'کیلوگرم' || currentUnit == 'kg' || currentUnit == 'Kg';
      if (isKg) {
        weightPerUnitInTons = weightPerUnit / 1000;
      }
      
      double unitCount = double.tryParse(unitCountController.text) ?? 0;
      double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      double priceRate = double.tryParse(priceRateController.text) ?? 1;
      double loadingCost = double.tryParse(loadingController.text) ?? 0;
      double transferCost = double.tryParse(transferController.text) ?? 0;
      double clearanceCost = double.tryParse(clearanceController.text) ?? 0;
      double discount = double.tryParse(discountController.text) ?? 0;
      
      double totalWeight = weightPerUnit * unitCount;
      double totalWeightInTons = weightPerUnitInTons * unitCount;
      double totalPrice = totalWeightInTons * unitPrice;

      totalWeightController.text = totalWeight > 0 ? totalWeight.toStringAsFixed(2) : '';
      totalPriceController.text = totalPrice > 0 ? totalPrice.toStringAsFixed(0) : '';

      if (selectedCurrency == 'USD') {
        equivalentController.text = totalPrice > 0 ? (totalPrice * (priceRate <= 0 ? 1 : priceRate)).toStringAsFixed(0) : '';
      } else {
        equivalentController.text = totalPrice > 0 ? (totalPrice / (priceRate <= 0 ? 1 : priceRate)).toStringAsFixed(2) : '';
      }

      double finalPrice = totalPrice + loadingCost + transferCost + clearanceCost - discount;
      finalPriceController.text = finalPrice > 0 ? finalPrice.toStringAsFixed(0) : '';
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double weightPerUnit = double.tryParse(weightPerUnitController.text) ?? 0;
          double unitCount = double.tryParse(unitCountController.text) ?? 0;
          String currentUnit = unitController.text;
          bool isKg = currentUnit == 'کیلوگرم' || currentUnit == 'kg' || currentUnit == 'Kg';
          
          double weightPerUnitInTons = isKg ? weightPerUnit / 1000 : weightPerUnit;
          double totalWeight = weightPerUnit * unitCount;
          double totalWeightInTons = isKg ? totalWeight / 1000 : totalWeight;

          double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
          String pricePerTonHint = '';
          if (currentUnit.isNotEmpty && weightPerUnit > 0 && unitPrice > 0) {
            double weightPerUnitInTonsCalc = isKg ? weightPerUnit / 1000 : weightPerUnit;
            if (weightPerUnitInTonsCalc > 0) {
              pricePerTonHint = 'قیمت هر تن: ${unitPrice.toStringAsFixed(0)}';
            }
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('${l10n.edit} ${l10n.sale}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1A1A1A))),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('ویرایش فروش', l10n),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: invoiceNumberController,
                        label: l10n.invoiceNumberLabel,
                        icon: Icons.numbers,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedParty,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.selectCustomerCompany,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.history_rounded, color: Color(0xFFCB001D)),
                            tooltip: l10n.viewCustomerHistory,
                            onPressed: selectedParty == null
                                ? null
                                : () => _showPartyTransactionHistory(selectedParty),
                          ),
                        ),
                        items: _partyOptions.map((option) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: option,
                            child: Text('${option['name']} (${option['source'] == 'company' ? l10n.company : l10n.customer})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedParty = value;
                            customerNameController.text = value['name']?.toString() ?? '';
                            phoneController.text = value['phone']?.toString() ?? '';
                            addressController.text = value['address']?.toString() ?? '';
                            companyController.text = value['company']?.toString() ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: customerNameController,
                              label: l10n.customerName,
                              icon: Icons.person_outline,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: companyController,
                              label: l10n.companyName,
                              icon: Icons.business_outlined,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: phoneController,
                              label: l10n.phoneNumber,
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: addressController,
                              label: l10n.address,
                              icon: Icons.location_on_outlined,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle(l10n.productDetails, l10n),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          value: selectedProductName != null && productOptions.any((p) => p['name']?.toString() == selectedProductName) 
                              ? selectedProductName 
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.selectProductFromProduction,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.inventory_2_outlined, color: Color(0xFFCB001D)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.grey, size: 18),
                              onPressed: () async {
                                final updated = await _db.getProducedProducts();
                                setDialogState(() {
                                  productOptions.clear();
                                  productOptions.addAll(updated.map((p) => {
                                    'id': p['id'],
                                    'name': p['product_name']?.toString() ?? '-',
                                    'unit': p['unit']?.toString() ?? 'کیلو',
                                    'thickness': p['thickness']?.toString() ?? '',
                                    'loading': p['loading']?.toString() ?? '',
                                  }));
                                  if (selectedProductName != null && !productOptions.any((p) => p['name']?.toString() == selectedProductName)) {
                                    selectedProductName = null;
                                    selectedProductId = null;
                                    selectedProductUnit = null;
                                    selectedProductThickness = null;
                                    productController.text = '';
                                  }
                                });
                              },
                            ),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(l10n.selectProduct, style: TextStyle(color: Colors.grey)),
                            ),
                            ...productOptions.map((product) {
                              final name = product['name']?.toString() ?? '-';
                              final unit = product['unit']?.toString() ?? '';
                              final thickness = product['thickness']?.toString() ?? '';
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Row(
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, color: Color(0xFFCB001D), size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (unit.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(unit, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                      ),
                                    ],
                                    if (thickness.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('${l10n.thicknessShort}: $thickness', style: TextStyle(fontSize: 9, color: Colors.blue.shade700)),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              setDialogState(() {
                                selectedProductId = null;
                                selectedProductName = null;
                                selectedProductUnit = null;
                                selectedProductThickness = null;
                                productController.text = '';
                              });
                              return;
                            }
                            final selected = productOptions.firstWhere(
                              (p) => p['name']?.toString() == value,
                              orElse: () => {},
                            );
                            setDialogState(() {
                              selectedProductId = selected['id'] as int?;
                              selectedProductName = value;
                              selectedProductUnit = selected['unit']?.toString() ?? 'کیلو';
                              selectedProductThickness = selected['thickness']?.toString() ?? '';
                              productController.text = value;
                              if (selectedProductUnit != null && selectedProductUnit!.isNotEmpty) {
                                unitController.text = selectedProductUnit!;
                              }
                              if (selectedProductThickness != null && selectedProductThickness!.isNotEmpty) {
                                thicknessController.text = selectedProductThickness!;
                              }
                            });
                          },
                        )
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: productController,
                              label: l10n.productName,
                              icon: Icons.inventory_2_outlined,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: genderController,
                              label: l10n.gender,
                              icon: Icons.category_outlined,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: sizeController,
                              label: l10n.size,
                              icon: Icons.straighten,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: thicknessController,
                              label: l10n.thickness,
                              icon: Icons.height,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: weightPerUnitController,
                                  label: l10n.weightPerUnit,
                                  icon: Icons.scale_outlined,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setDialogState(() {
                                    updateTotals();
                                    setDialogState(() {});
                                  }),
                                  l10n: l10n,
                                ),
                                if (weightPerUnit > 0 && isKg)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D).withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '$weightPerUnit kg',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A1A2E),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.arrow_forward, color: Color(0xFFCB001D), size: 12),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFCB001D).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D).withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '${weightPerUnitInTons.toStringAsFixed(weightPerUnitInTons % 1 == 0 ? 0 : 2)} تن',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFCB001D),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: unitCountController,
                              label: l10n.unitCount,
                              icon: Icons.numbers,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: totalWeightController,
                                  label: l10n.totalWeight,
                                  icon: Icons.monitor_weight_outlined,
                                  keyboardType: TextInputType.number,
                                  readOnly: true,
                                  l10n: l10n,
                                ),
                                if (totalWeight > 0 && isKg)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D).withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '$totalWeight kg',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A1A2E),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.arrow_forward, color: Color(0xFFCB001D), size: 12),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFCB001D).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D).withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '${totalWeightInTons.toStringAsFixed(totalWeightInTons % 1 == 0 ? 0 : 2)} تن',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFCB001D),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: unitController,
                              label: l10n.unit,
                              icon: Icons.scale,
                              readOnly: true,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle(l10n.financialInfo, l10n),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: unitPriceController,
                                  label: '${l10n.unitPricePerKg} (قیمت هر تن)',
                                  icon: Icons.attach_money_outlined,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setDialogState(updateTotals),
                                  l10n: l10n,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: unitController,
                                  label: l10n.unit,
                                  icon: Icons.widgets_outlined,
                                  readOnly: true,
                                  l10n: l10n,
                                ),
                              ),
                            ],
                          ),
                          if (currentUnit.isNotEmpty && weightPerUnit > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'قیمت بر اساس هر تن محاسبه می‌شود',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (pricePerTonHint.isNotEmpty) ...[
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCB001D).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          pricePerTonHint,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFCB001D),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: totalPriceController,
                              label: l10n.totalPrice,
                              icon: Icons.receipt_long_outlined,
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: priceRateController,
                              label: selectedCurrency == 'USD' 
                                  ? 'نرخ ارز (USD به AFN) *' 
                                  : 'نرخ ارز (AFN به USD) *',
                              icon: Icons.currency_exchange,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: equivalentController,
                        label: selectedCurrency == 'USD' 
                            ? 'معادل به افغانی (AFN)' 
                            : 'معادل به دالر (USD)',
                        icon: Icons.currency_exchange,
                        readOnly: true,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: loadingController,
                              label: l10n.loadingCost,
                              icon: Icons.local_shipping_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: transferController,
                              label: l10n.transferCost,
                              icon: Icons.drive_eta_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: clearanceController,
                              label: l10n.clearanceCost,
                              icon: Icons.fact_check_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: discountController,
                              label: l10n.discount,
                              icon: Icons.discount_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: finalPriceController,
                              label: l10n.finalPrice,
                              icon: Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: dateController,
                              label: l10n.persianDate,
                              icon: Icons.date_range_outlined,
                              readOnly: true,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    dateController.text = PersianDateConverter.gregorianToJalali(picked);
                                    selectedEnglishDate = PersianDateConverter.getEnglishDate(picked);
                                  });
                                }
                              },
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: timeController,
                              label: l10n.loadingTime,
                              icon: Icons.access_time_outlined,
                              readOnly: true,
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    timeController.text = _formatTimeOfDay(picked);
                                    selectedEnglishTime = _formatTimeOfDay(picked);
                                  });
                                }
                              },
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCurrency,
                        decoration: InputDecoration(labelText: l10n.finalCurrency, border: const OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'AFN', child: Text('AFN')),
                        ],
                        onChanged: (value) => setDialogState(() {
                          selectedCurrency = value ?? 'USD';
                          updateTotals();
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: InputDecoration(labelText: l10n.transactionType, border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'فروش', child: Text(l10n.sale)),
                          DropdownMenuItem(value: 'پیش‌فاکتور', child: Text(l10n.proformaInvoice)),
                        ],
                        onChanged: (value) => setDialogState(() => selectedType = value ?? 'فروش'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethod,
                        decoration: InputDecoration(labelText: l10n.paymentMethod, border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'cash', child: Text(l10n.cash)),
                          DropdownMenuItem(value: 'loan_full', child: Text(l10n.fullLoan)),
                          DropdownMenuItem(value: 'loan_partial', child: Text(l10n.partialLoan)),
                        ],
                        onChanged: (value) => setDialogState(() => selectedPaymentMethod = value ?? 'cash'),
                      ),
                      if (selectedPaymentMethod == 'loan_partial') const SizedBox(height: 12),
                      if (selectedPaymentMethod == 'loan_partial')
                        _buildTextField(
                          controller: paidAmountController,
                          label: l10n.initialPaymentAmount,
                          icon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          l10n: l10n,
                        ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: descriptionController,
                        label: l10n.description,
                        icon: Icons.notes_outlined,
                        maxLines: 2,
                        l10n: l10n,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    final invoiceNumber = invoiceNumberController.text.trim();
                    final customerName = customerNameController.text.trim();
                    final phone = phoneController.text.trim();
                    final address = addressController.text.trim();
                    final company = companyController.text.trim();
                    final product = productController.text.trim();
                    
                    if (invoiceNumber.isEmpty) {
                      _showSnackbar('شماره فاکتور الزامی است', Colors.red);
                      return;
                    }
                    
                    if (customerName.isEmpty || product.isEmpty) {
                      _showSnackbar(l10n.customerAndProductRequired, Colors.red);
                      return;
                    }
                    
                    final unitPrice = double.tryParse(unitPriceController.text) ?? 0;
                    final totalPrice = double.tryParse(totalPriceController.text) ?? 0;
                    final discount = double.tryParse(discountController.text) ?? 0;
                    final loadingCost = double.tryParse(loadingController.text) ?? 0;
                    final transferCost = double.tryParse(transferController.text) ?? 0;
                    final clearanceCost = double.tryParse(clearanceController.text) ?? 0;
                    final priceRate = double.tryParse(priceRateController.text) ?? 1;
                    final totalWeight = double.tryParse(totalWeightController.text) ?? 0;
                    final paidAmount = double.tryParse(paidAmountController.text) ?? 0;

                    final finalPrice = totalPrice + loadingCost + transferCost + clearanceCost - discount;
                    final currencyType = selectedCurrency;
                    final usdEquivalent = currencyType == 'USD' ? finalPrice : (priceRate <= 0 ? finalPrice : finalPrice / priceRate);
                    final afnEquivalent = currencyType == 'AFN' ? finalPrice : (finalPrice * (priceRate <= 0 ? 1 : priceRate));
                    final remainingAmount = selectedPaymentMethod == 'cash'
                        ? 0
                        : (finalPrice - paidAmount) < 0
                            ? 0
                            : finalPrice - paidAmount;
                    
                    final existingInvoice = await _db.getSalesInvoiceByNumber(invoiceNumber);
                    if (existingInvoice != null && existingInvoice['id'] != sale['id']) {
                      _showSnackbar('این شماره فاکتور قبلاً ثبت شده است', Colors.red);
                      return;
                    }
                    
                    final payload = {
                      'invoice_number': invoiceNumber,
                      'customer_name': customerName,
                      'customer_phone': phone,
                      'customer_address': address,
                      'customer_company': company,
                      'product_name': product,
                      'gender': genderController.text.trim(),
                      'size': sizeController.text.trim(),
                      'thickness': thicknessController.text.trim(),
                      'weight': totalWeightController.text.trim(),
                      'weight_per_unit': weightPerUnitController.text.trim(),
                      'unit_count': unitCountController.text.trim(),
                      'total_weight': totalWeightController.text.trim(),
                      'unit': unitController.text.trim(),
                      'unit_price': unitPrice,
                      'total_price': totalPrice,
                      'price_rate': priceRate,
                      'currency': currencyType,
                      'usd_equivalent': usdEquivalent,
                      'afn_equivalent': afnEquivalent,
                      'loading_cost': loadingCost,
                      'transfer_cost': transferCost,
                      'clearance_cost': clearanceCost,
                      'discount': discount,
                      'loading_time': timeController.text.trim(),
                      'loading_time_en': selectedEnglishTime,
                      'final_price': finalPrice,
                      'payment_method': selectedPaymentMethod,
                      'loan_type': selectedPaymentMethod == 'loan_full' ? 'full' : selectedPaymentMethod == 'loan_partial' ? 'partial' : 'cash',
                      'paid_amount': selectedPaymentMethod == 'cash' ? finalPrice : paidAmount,
                      'remaining_amount': remainingAmount,
                      'description': descriptionController.text.trim(),
                      'sale_type': selectedType,
                      'date': dateController.text.trim(),
                      'date_en': selectedEnglishDate,
                      'produced_product_id': selectedProductId,
                    };
                    
                    final result = await _db.updateSalesInvoice(sale['id'], payload);
                    if (result == -1) {
                      _showSnackbar('❌ خطا در ویرایش فروش', Colors.red);
                      return;
                    }

                    Navigator.pop(context);
                    await _loadData();
                    _showSnackbar('✅ فروش با موفقیت ویرایش شد', Colors.green);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white),
                  child: Text(l10n.update),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // ADD SALE DIALOG
  // ============================================
  Future<void> _showAddSaleDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final customerNameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final companyController = TextEditingController();
    final productController = TextEditingController();
    final genderController = TextEditingController();
    final sizeController = TextEditingController();
    final thicknessController = TextEditingController();
    final weightPerUnitController = TextEditingController();
    final unitCountController = TextEditingController();
    final totalWeightController = TextEditingController();
    final timeController = TextEditingController(text: _formatTimeOfDay(TimeOfDay.now()));
    final unitController = TextEditingController(text: 'کیلو');
    final unitPriceController = TextEditingController();
    final totalPriceController = TextEditingController();
    final finalPriceController = TextEditingController();
    final priceRateController = TextEditingController(text: '1');
    final loadingController = TextEditingController();
    final transferController = TextEditingController();
    final clearanceController = TextEditingController();
    final discountController = TextEditingController();
    final descriptionController = TextEditingController();
    final equivalentController = TextEditingController();
    final dateController = TextEditingController(text: PersianDateConverter.getCurrentPersianDate());
    final paidAmountController = TextEditingController();
    
    final invoiceNumberController = TextEditingController();
    
    String selectedPaymentMethod = 'cash';
    String selectedCurrency = 'USD';
    String selectedType = 'فروش';
    Map<String, dynamic>? selectedParty;
    String selectedEnglishDate = PersianDateConverter.getEnglishDate(DateTime.now());
    String selectedEnglishTime = _formatTimeOfDay(TimeOfDay.now());

    final List<Map<String, dynamic>> producedProducts = await _db.getProducedProducts();
    final List<Map<String, dynamic>> productOptions = producedProducts.map((product) {
      return {
        'id': product['id'],
        'name': product['product_name']?.toString() ?? '-',
        'unit': product['unit']?.toString() ?? 'کیلو',
        'thickness': product['thickness']?.toString() ?? '',
        'loading': product['loading']?.toString() ?? '',
      };
    }).toList();

    int? selectedProductId;
    String? selectedProductName;
    String? selectedProductUnit;
    String? selectedProductThickness;
    String? selectedProductLoading;

    void updateTotals() {
      double weightPerUnit = double.tryParse(weightPerUnitController.text) ?? 0;
      String currentUnit = unitController.text;
      
      double weightPerUnitInTons = weightPerUnit;
      bool isKg = currentUnit == 'کیلوگرم' || currentUnit == 'kg' || currentUnit == 'Kg';
      if (isKg) {
        weightPerUnitInTons = weightPerUnit / 1000;
      }
      
      double unitCount = double.tryParse(unitCountController.text) ?? 0;
      double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      double priceRate = double.tryParse(priceRateController.text) ?? 1;
      double loadingCost = double.tryParse(loadingController.text) ?? 0;
      double transferCost = double.tryParse(transferController.text) ?? 0;
      double clearanceCost = double.tryParse(clearanceController.text) ?? 0;
      double discount = double.tryParse(discountController.text) ?? 0;
      
      double totalWeight = weightPerUnit * unitCount;
      double totalWeightInTons = weightPerUnitInTons * unitCount;
      double totalPrice = totalWeightInTons * unitPrice;

      totalWeightController.text = totalWeight > 0 ? totalWeight.toStringAsFixed(2) : '';
      totalPriceController.text = totalPrice > 0 ? totalPrice.toStringAsFixed(0) : '';

      if (selectedCurrency == 'USD') {
        equivalentController.text = totalPrice > 0 ? (totalPrice * (priceRate <= 0 ? 1 : priceRate)).toStringAsFixed(0) : '';
      } else {
        equivalentController.text = totalPrice > 0 ? (totalPrice / (priceRate <= 0 ? 1 : priceRate)).toStringAsFixed(2) : '';
      }

      double finalPrice = totalPrice + loadingCost + transferCost + clearanceCost - discount;
      finalPriceController.text = finalPrice > 0 ? finalPrice.toStringAsFixed(0) : '';
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double weightPerUnit = double.tryParse(weightPerUnitController.text) ?? 0;
          double unitCount = double.tryParse(unitCountController.text) ?? 0;
          String currentUnit = unitController.text;
          bool isKg = currentUnit == 'کیلوگرم' || currentUnit == 'kg' || currentUnit == 'Kg';
          
          double weightPerUnitInTons = isKg ? weightPerUnit / 1000 : weightPerUnit;
          double totalWeight = weightPerUnit * unitCount;
          double totalWeightInTons = isKg ? totalWeight / 1000 : totalWeight;

          double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
          String pricePerTonHint = '';
          if (currentUnit.isNotEmpty && weightPerUnit > 0 && unitPrice > 0) {
            double weightPerUnitInTonsCalc = isKg ? weightPerUnit / 1000 : weightPerUnit;
            if (weightPerUnitInTonsCalc > 0) {
              pricePerTonHint = 'قیمت هر تن: ${unitPrice.toStringAsFixed(0)}';
            }
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(l10n.addNewSale, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1A1A1A))),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(l10n.salesManagement, l10n),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: invoiceNumberController,
                        label: l10n.invoiceNumberLabel,
                        icon: Icons.numbers,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedParty,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.selectCustomerCompany,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.history_rounded, color: Color(0xFFCB001D)),
                            tooltip: l10n.viewCustomerHistory,
                            onPressed: selectedParty == null
                                ? null
                                : () => _showPartyTransactionHistory(selectedParty),
                          ),
                        ),
                        items: _partyOptions.map((option) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: option,
                            child: Text('${option['name']} (${option['source'] == 'company' ? l10n.company : l10n.customer})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedParty = value;
                            customerNameController.text = value['name']?.toString() ?? '';
                            phoneController.text = value['phone']?.toString() ?? '';
                            addressController.text = value['address']?.toString() ?? '';
                            companyController.text = value['company']?.toString() ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: customerNameController,
                              label: l10n.customerName,
                              icon: Icons.person_outline,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: companyController,
                              label: l10n.companyName,
                              icon: Icons.business_outlined,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: phoneController,
                              label: l10n.phoneNumber,
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: addressController,
                              label: l10n.address,
                              icon: Icons.location_on_outlined,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle(l10n.productDetails, l10n),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          value: selectedProductName != null && productOptions.any((p) => p['name']?.toString() == selectedProductName) 
                              ? selectedProductName 
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.selectProductFromProduction,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.inventory_2_outlined, color: Color(0xFFCB001D)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.grey, size: 18),
                              onPressed: () async {
                                final updated = await _db.getProducedProducts();
                                setDialogState(() {
                                  productOptions.clear();
                                  productOptions.addAll(updated.map((p) => {
                                    'id': p['id'],
                                    'name': p['product_name']?.toString() ?? '-',
                                    'unit': p['unit']?.toString() ?? 'کیلو',
                                    'thickness': p['thickness']?.toString() ?? '',
                                    'loading': p['loading']?.toString() ?? '',
                                  }));
                                  if (selectedProductName != null && !productOptions.any((p) => p['name']?.toString() == selectedProductName)) {
                                    selectedProductName = null;
                                    selectedProductId = null;
                                    selectedProductUnit = null;
                                    selectedProductThickness = null;
                                    selectedProductLoading = null;
                                    productController.text = '';
                                  }
                                });
                              },
                            ),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(l10n.selectProduct, style: TextStyle(color: Colors.grey)),
                            ),
                            ...productOptions.map((product) {
                              final name = product['name']?.toString() ?? '-';
                              final unit = product['unit']?.toString() ?? '';
                              final thickness = product['thickness']?.toString() ?? '';
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Row(
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, color: Color(0xFFCB001D), size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (unit.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(unit, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                      ),
                                    ],
                                    if (thickness.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('${l10n.thicknessShort}: $thickness', style: TextStyle(fontSize: 9, color: Colors.blue.shade700)),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              setDialogState(() {
                                selectedProductId = null;
                                selectedProductName = null;
                                selectedProductUnit = null;
                                selectedProductThickness = null;
                                selectedProductLoading = null;
                                productController.text = '';
                              });
                              return;
                            }
                            final selected = productOptions.firstWhere(
                              (p) => p['name']?.toString() == value,
                              orElse: () => {},
                            );
                            setDialogState(() {
                              selectedProductId = selected['id'] as int?;
                              selectedProductName = value;
                              selectedProductUnit = selected['unit']?.toString() ?? 'کیلو';
                              selectedProductThickness = selected['thickness']?.toString() ?? '';
                              selectedProductLoading = selected['loading']?.toString() ?? '';
                              productController.text = value;
                              if (selectedProductUnit != null && selectedProductUnit!.isNotEmpty) {
                                unitController.text = selectedProductUnit!;
                              }
                              if (selectedProductThickness != null && selectedProductThickness!.isNotEmpty) {
                                thicknessController.text = selectedProductThickness!;
                              }
                            });
                          },
                        )
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: productController,
                              label: l10n.productName,
                              icon: Icons.inventory_2_outlined,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: genderController,
                              label: l10n.gender,
                              icon: Icons.category_outlined,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: sizeController,
                              label: l10n.size,
                              icon: Icons.straighten,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: thicknessController,
                              label: l10n.thickness,
                              icon: Icons.height,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: weightPerUnitController,
                                  label: l10n.weightPerUnit,
                                  icon: Icons.scale_outlined,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setDialogState(() {
                                    updateTotals();
                                    setDialogState(() {});
                                  }),
                                  l10n: l10n,
                                ),
                                if (weightPerUnit > 0 && isKg)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D).withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '$weightPerUnit kg',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A1A2E),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.arrow_forward, color: Color(0xFFCB001D), size: 12),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFCB001D).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D).withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '${weightPerUnitInTons.toStringAsFixed(weightPerUnitInTons % 1 == 0 ? 0 : 2)} تن',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFCB001D),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: unitCountController,
                              label: l10n.unitCount,
                              icon: Icons.numbers,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: totalWeightController,
                                  label: l10n.totalWeight,
                                  icon: Icons.monitor_weight_outlined,
                                  keyboardType: TextInputType.number,
                                  readOnly: true,
                                  l10n: l10n,
                                ),
                                if (totalWeight > 0 && isKg)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D).withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '$totalWeight kg',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A1A2E),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.arrow_forward, color: Color(0xFFCB001D), size: 12),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFCB001D).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D).withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '${totalWeightInTons.toStringAsFixed(totalWeightInTons % 1 == 0 ? 0 : 2)} تن',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFCB001D),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: unitController,
                              label: l10n.unit,
                              icon: Icons.scale,
                              readOnly: true,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle(l10n.financialInfo, l10n),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: unitPriceController,
                                  label: '${l10n.unitPricePerKg} (قیمت هر تن)',
                                  icon: Icons.attach_money_outlined,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setDialogState(updateTotals),
                                  l10n: l10n,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: unitController,
                                  label: l10n.unit,
                                  icon: Icons.widgets_outlined,
                                  readOnly: true,
                                  l10n: l10n,
                                ),
                              ),
                            ],
                          ),
                          if (currentUnit.isNotEmpty && weightPerUnit > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'قیمت بر اساس هر تن محاسبه می‌شود',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (pricePerTonHint.isNotEmpty) ...[
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCB001D).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          pricePerTonHint,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFCB001D),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: totalPriceController,
                              label: l10n.totalPrice,
                              icon: Icons.receipt_long_outlined,
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: priceRateController,
                              label: selectedCurrency == 'USD' 
                                  ? 'نرخ ارز (USD به AFN) *' 
                                  : 'نرخ ارز (AFN به USD) *',
                              icon: Icons.currency_exchange,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: equivalentController,
                        label: selectedCurrency == 'USD' 
                            ? 'معادل به افغانی (AFN)' 
                            : 'معادل به دالر (USD)',
                        icon: Icons.currency_exchange,
                        readOnly: true,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: loadingController,
                              label: l10n.loadingCost,
                              icon: Icons.local_shipping_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: transferController,
                              label: l10n.transferCost,
                              icon: Icons.drive_eta_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: clearanceController,
                              label: l10n.clearanceCost,
                              icon: Icons.fact_check_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: discountController,
                              label: l10n.discount,
                              icon: Icons.discount_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: finalPriceController,
                              label: l10n.finalPrice,
                              icon: Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: dateController,
                              label: l10n.persianDate,
                              icon: Icons.date_range_outlined,
                              readOnly: true,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    dateController.text = PersianDateConverter.gregorianToJalali(picked);
                                    selectedEnglishDate = PersianDateConverter.getEnglishDate(picked);
                                  });
                                }
                              },
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: timeController,
                              label: l10n.loadingTime,
                              icon: Icons.access_time_outlined,
                              readOnly: true,
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    timeController.text = _formatTimeOfDay(picked);
                                    selectedEnglishTime = _formatTimeOfDay(picked);
                                  });
                                }
                              },
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCurrency,
                        decoration: InputDecoration(labelText: l10n.finalCurrency, border: const OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'AFN', child: Text('AFN')),
                        ],
                        onChanged: (value) => setDialogState(() {
                          selectedCurrency = value ?? 'USD';
                          updateTotals();
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: InputDecoration(labelText: l10n.transactionType, border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'فروش', child: Text(l10n.sale)),
                          DropdownMenuItem(value: 'پیش‌فاکتور', child: Text(l10n.proformaInvoice)),
                        ],
                        onChanged: (value) => setDialogState(() => selectedType = value ?? 'فروش'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethod,
                        decoration: InputDecoration(labelText: l10n.paymentMethod, border: const OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(value: 'cash', child: Text(l10n.cash)),
                          DropdownMenuItem(value: 'loan_full', child: Text(l10n.fullLoan)),
                          DropdownMenuItem(value: 'loan_partial', child: Text(l10n.partialLoan)),
                        ],
                        onChanged: (value) => setDialogState(() => selectedPaymentMethod = value ?? 'cash'),
                      ),
                      if (selectedPaymentMethod == 'loan_partial') const SizedBox(height: 12),
                      if (selectedPaymentMethod == 'loan_partial')
                        _buildTextField(
                          controller: paidAmountController,
                          label: l10n.initialPaymentAmount,
                          icon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          l10n: l10n,
                        ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: descriptionController,
                        label: l10n.description,
                        icon: Icons.notes_outlined,
                        maxLines: 2,
                        l10n: l10n,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    final invoiceNumber = invoiceNumberController.text.trim();
                    final customerName = customerNameController.text.trim();
                    final phone = phoneController.text.trim();
                    final address = addressController.text.trim();
                    final company = companyController.text.trim();
                    final product = productController.text.trim();
                    
                    if (invoiceNumber.isEmpty) {
                      _showSnackbar('شماره فاکتور الزامی است', Colors.red);
                      return;
                    }
                    
                    if (customerName.isEmpty || product.isEmpty) {
                      _showSnackbar(l10n.customerAndProductRequired, Colors.red);
                      return;
                    }
                    
                    final unitPrice = double.tryParse(unitPriceController.text) ?? 0;
                    final totalPrice = double.tryParse(totalPriceController.text) ?? 0;
                    final discount = double.tryParse(discountController.text) ?? 0;
                    final loadingCost = double.tryParse(loadingController.text) ?? 0;
                    final transferCost = double.tryParse(transferController.text) ?? 0;
                    final clearanceCost = double.tryParse(clearanceController.text) ?? 0;
                    final priceRate = double.tryParse(priceRateController.text) ?? 1;
                    final totalWeight = double.tryParse(totalWeightController.text) ?? 0;
                    final paidAmount = double.tryParse(paidAmountController.text) ?? 0;

                    final finalPrice = totalPrice + loadingCost + transferCost + clearanceCost - discount;
                    final currencyType = selectedCurrency;
                    final usdEquivalent = currencyType == 'USD' ? finalPrice : (priceRate <= 0 ? finalPrice : finalPrice / priceRate);
                    final afnEquivalent = currencyType == 'AFN' ? finalPrice : (finalPrice * (priceRate <= 0 ? 1 : priceRate));
                    final remainingAmount = selectedPaymentMethod == 'cash'
                        ? 0
                        : (finalPrice - paidAmount) < 0
                            ? 0
                            : finalPrice - paidAmount;
                    
                    final existingInvoice = await _db.getSalesInvoiceByNumber(invoiceNumber);
                    if (existingInvoice != null) {
                      _showSnackbar('این شماره فاکتور قبلاً ثبت شده است', Colors.red);
                      return;
                    }
                    
                    final payload = {
                      'invoice_number': invoiceNumber,
                      'customer_name': customerName,
                      'customer_phone': phone,
                      'customer_address': address,
                      'customer_company': company,
                      'product_name': product,
                      'gender': genderController.text.trim(),
                      'size': sizeController.text.trim(),
                      'thickness': thicknessController.text.trim(),
                      'weight': totalWeightController.text.trim(),
                      'weight_per_unit': weightPerUnitController.text.trim(),
                      'unit_count': unitCountController.text.trim(),
                      'total_weight': totalWeightController.text.trim(),
                      'unit': unitController.text.trim(),
                      'unit_price': unitPrice,
                      'total_price': totalPrice,
                      'price_rate': priceRate,
                      'currency': currencyType,
                      'usd_equivalent': usdEquivalent,
                      'afn_equivalent': afnEquivalent,
                      'loading_cost': loadingCost,
                      'transfer_cost': transferCost,
                      'clearance_cost': clearanceCost,
                      'discount': discount,
                      'loading_time': timeController.text.trim(),
                      'loading_time_en': selectedEnglishTime,
                      'final_price': finalPrice,
                      'payment_method': selectedPaymentMethod,
                      'loan_type': selectedPaymentMethod == 'loan_full' ? 'full' : selectedPaymentMethod == 'loan_partial' ? 'partial' : 'cash',
                      'paid_amount': selectedPaymentMethod == 'cash' ? finalPrice : paidAmount,
                      'remaining_amount': remainingAmount,
                      'description': descriptionController.text.trim(),
                      'sale_type': selectedType,
                      'date': dateController.text.trim(),
                      'date_en': selectedEnglishDate,
                      'produced_product_id': selectedProductId,
                    };
                    
                    final id = await _db.insertSalesInvoice(payload);
                    if (id == -1) {
                      _showSnackbar(l10n.errorAddingSale, Colors.red);
                      return;
                    }

                    if (selectedProductId != null && totalWeight > 0) {
                      final unit = unitController.text.trim();
                      final stockDeducted = await _db.deductProductStock(
                        selectedProductId!, 
                        totalWeight, 
                        unit
                      );
                      
                      if (!stockDeducted) {
                        _showSnackbar('⚠️ موجودی کافی نیست!', Colors.red);
                        await _db.deleteSalesInvoice(id);
                        return;
                      }
                    }

                    if (selectedPaymentMethod != 'cash') {
                      final paidAmount = double.tryParse(paidAmountController.text) ?? 0;
                      final totalAmount = finalPrice;
                      final remaining = (totalAmount - paidAmount) < 0 ? 0 : (totalAmount - paidAmount);
                      final loanPayload = {
                        'sale_invoice_id': id,
                        'invoice_number': invoiceNumber,
                        'customer_name': customerName,
                        'customer_company': company,
                        'total_amount': totalAmount,
                        'paid_amount': paidAmount,
                        'remaining_amount': remaining,
                        'loan_type': selectedPaymentMethod == 'loan_full' ? 'full' : 'partial',
                        'currency': currencyType,
                        'date': dateController.text.trim(),
                        'date_en': selectedEnglishDate,
                      };
                      if (loanPayload.isEmpty) {
                        print('⚠️ loanPayload empty');
                      }
                      final loanId = await _db.insertSellLoan(loanPayload);
                      if (loanId == -1) {
                        _showSnackbar(l10n.errorSavingLoan, Colors.red);
                      } else {
                        if (paidAmount > 0) {
                          await _db.insertSellLoanPayment({
                            'loan_id': loanId,
                            'amount': paidAmount,
                            'note': l10n.initialPaymentNote,
                            'date': dateController.text.trim(),
                            'date_en': selectedEnglishDate,
                          });
                        }
                      }
                    }

                    Navigator.pop(context);
                    await _loadData();
                    _showInvoiceModal(context, invoiceNumber, {
                      ...payload,
                      'supplier_name': customerName,
                      'location': address,
                    }, l10n);
                    _showSnackbar(l10n.saleSavedSuccess, Colors.green);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white),
                  child: Text(l10n.saveSale),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // PARTY TRANSACTION HISTORY
  // ============================================
  void _showPartyTransactionHistory(Map<String, dynamic>? initialParty) {
    final l10n = AppLocalizations.of(context)!;
    Map<String, dynamic>? selectedParty = initialParty ?? (_partyOptions.isNotEmpty ? _partyOptions.first : null);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final currentParty = selectedParty;
            final filteredSales = currentParty == null
                ? <Map<String, dynamic>>[]
                : _sales.where((sale) {
                    final name = currentParty['name']?.toString() ?? '';
                    return sale['customer_name']?.toString() == name || sale['customer_company']?.toString() == name;
                  }).toList();

            final totalAmount = filteredSales.fold<double>(0, (sum, sale) => sum + (double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0));
            final totalInvoices = filteredSales.length;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.customerTransactionHistory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                            const SizedBox(height: 4),
                            Text(currentParty == null ? l10n.noCustomerSelected : currentParty['name']?.toString() ?? '-', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                          ],
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey, size: 24)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedParty,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.selectCustomerCompany, border: const OutlineInputBorder()),
                      items: _partyOptions.map((option) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: option,
                          child: Text('${option['name']?.toString() ?? '-'} (${option['source']?.toString() == 'company' ? l10n.company : l10n.customer})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedParty = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildKeyValueChip(l10n.invoicesCount, totalInvoices.toString(), Colors.blue, l10n),
                        const SizedBox(width: 12),
                        _buildKeyValueChip(l10n.totalAmount, _formatCurrency(totalAmount), Colors.green, l10n),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredSales.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(l10n.noHistoryForCustomer, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredSales.length,
                              separatorBuilder: (_, __) => const Divider(color: Colors.grey),
                              itemBuilder: (context, index) {
                                final sale = filteredSales[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  title: Text('${sale['invoice_number'] ?? '-'} • ${sale['customer_name'] ?? sale['customer_company'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('${sale['product_name'] ?? '-'} • ${sale['date'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: Text('${_formatCurrency(sale['final_price'])} ${sale['currency'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFCB001D))),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showInvoiceModal(context, sale['invoice_number'] ?? '-', sale, l10n);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKeyValueChip(String label, String value, Color color, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // ============================================
  // INVOICE MODAL
  // ============================================
  void _showInvoiceModal(BuildContext context, String invoiceNumber, Map<String, dynamic> invoice, AppLocalizations l10n) {
    String getInvoiceValue(String key, {String defaultValue = '-'}) {
      return invoice?[key]?.toString() ?? defaultValue;
    }

    String unit = getInvoiceValue('unit');
    double weightPerUnitRaw = double.tryParse(getInvoiceValue('weight_per_unit')) ?? 0;
    double unitCount = double.tryParse(getInvoiceValue('unit_count')) ?? 0;
    double totalWeightRaw = double.tryParse(getInvoiceValue('total_weight')) ?? 0;
    
    String displayWeightPerUnit = _formatWeightWithConversion(unit, weightPerUnitRaw);
    String displayTotalWeight = _formatWeightWithConversion(unit, totalWeightRaw);
    double weightValue = double.tryParse(getInvoiceValue('weight')) ?? 0;
    String displayWeightValue = _formatWeightWithConversion(unit, weightValue);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 950,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCB001D), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            'assets/images/companylogo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Center(child: Text('VP', style: TextStyle(color: Color(0xFFCB001D), fontSize: 16, fontWeight: FontWeight.w900))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.companyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 2),
                          Text(l10n.integratedManagementSystem, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFCB001D), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Invoice', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('${l10n.invoiceNumberLabel}: $invoiceNumber', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB001D), fontSize: 12)),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${l10n.persianDate}: ${getInvoiceValue('date')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        Text('Date (EN): ${getInvoiceValue('date_en')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        if (getInvoiceValue('loading_time') != '-' && getInvoiceValue('loading_time').isNotEmpty) Text('${l10n.loadingTime}: ${getInvoiceValue('loading_time')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        if (getInvoiceValue('loading_time_en') != '-' && getInvoiceValue('loading_time_en').isNotEmpty) Text('Loading (EN): ${getInvoiceValue('loading_time_en')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        if (invoice?['is_back_returned'] == 1 || invoice?['is_back_returned']?.toString() == '1') ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFEBF1FF), borderRadius: BorderRadius.circular(4)),
                            child: Text(l10n.statusReturned, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF034ADE))),
                          ),
                          if (getInvoiceValue('back_return_reason') != '-' && getInvoiceValue('back_return_reason').isNotEmpty) Text('${l10n.returnReason}: ${getInvoiceValue('back_return_reason')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                          Text('${l10n.returnDate}: ${getInvoiceValue('back_return_date')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                          Text('Return Date (EN): ${getInvoiceValue('back_return_date_en')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        ],
                      ]),
                    ],
                  ),
                ],
              ),
              Container(height: 2, margin: const EdgeInsets.symmetric(vertical: 8), color: const Color(0xFFCB001D)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200, width: 1)),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(children: [
                        const Icon(Icons.business, color: Color(0xFFCB001D), size: 14),
                        const SizedBox(width: 4),
                        Text('${l10n.customer}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(getInvoiceValue('supplier_name') != '-' ? getInvoiceValue('supplier_name') : getInvoiceValue('customer_name'), style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                    Expanded(
                      child: Row(children: [
                        const Icon(Icons.location_on, color: Color(0xFFCB001D), size: 14),
                        const SizedBox(width: 4),
                        Text('${l10n.dischargeLocation}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(getInvoiceValue('location') != '-' ? getInvoiceValue('location') : getInvoiceValue('customer_address'), style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (getInvoiceValue('payment_method') != '-') ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF1F8FF), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${l10n.paymentMethod}: ${getInvoiceValue('payment_method') == 'cash' ? l10n.cash : getInvoiceValue('payment_method') == 'loan_full' ? l10n.fullLoan : getInvoiceValue('payment_method') == 'loan_partial' ? l10n.partialLoan : '-'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    if (getInvoiceValue('payment_method') != 'cash') ...[
                      const SizedBox(height: 4),
                      Text('${l10n.loanType}: ${getInvoiceValue('loan_type') == 'full' ? l10n.full : getInvoiceValue('loan_type') == 'partial' ? l10n.partial : '-'}', style: const TextStyle(fontSize: 10)),
                      Text('${l10n.paidAmount}: ${_formatCurrency(invoice?['paid_amount'])} ${getInvoiceValue('currency')}', style: const TextStyle(fontSize: 10)),
                      Text('${l10n.remainingAmount}: ${_formatCurrency(invoice?['remaining_amount'])} ${getInvoiceValue('currency')}', style: const TextStyle(fontSize: 10)),
                    ],
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              Flexible(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, width: 1), borderRadius: BorderRadius.circular(4)),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      decoration: const BoxDecoration(color: Color(0xFFCB001D), borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _buildInvoiceHeaderCell(l10n.customerName, 80),
                          _buildInvoiceHeaderCell(l10n.company, 70),
                          _buildInvoiceHeaderCell(l10n.product, 90),
                          _buildInvoiceHeaderCell(l10n.gender, 60),
                          _buildInvoiceHeaderCell(l10n.size, 60),
                          _buildInvoiceHeaderCell(l10n.thickness, 60),
                          _buildInvoiceHeaderCell(l10n.weight, 60),
                          _buildInvoiceHeaderCell(l10n.weightPerUnit, 70),
                          _buildInvoiceHeaderCell(l10n.unitCount, 70),
                          _buildInvoiceHeaderCell(l10n.totalWeight, 70),
                          _buildInvoiceHeaderCell(l10n.unitPrice, 70),
                          _buildInvoiceHeaderCell(l10n.totalPrice, 70),
                          _buildInvoiceHeaderCell(l10n.discount, 60),
                          _buildInvoiceHeaderCell(l10n.finalPrice, 80),
                        ]),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            child: Row(children: [
                              _buildInvoiceDataCell(getInvoiceValue('customer_name'), 80),
                              _buildInvoiceDataCell(getInvoiceValue('customer_company'), 70),
                              _buildInvoiceDataCell(getInvoiceValue('product_name'), 90),
                              _buildInvoiceDataCell(getInvoiceValue('gender'), 60),
                              _buildInvoiceDataCell(getInvoiceValue('size'), 60),
                              _buildInvoiceDataCell(getInvoiceValue('thickness'), 60),
                              _buildInvoiceDataCell(displayWeightValue, 60),
                              _buildInvoiceDataCell(displayWeightPerUnit, 70),
                              _buildInvoiceDataCell(getInvoiceValue('unit_count'), 70),
                              _buildInvoiceDataCell(displayTotalWeight, 70),
                              _buildInvoiceDataCell(_formatCurrency(invoice?['unit_price']), 70),
                              _buildInvoiceDataCell(_formatCurrency(invoice?['total_price']), 70),
                              _buildInvoiceDataCell(_formatCurrency(invoice?['discount']), 60),
                              _buildInvoiceDataCell(_formatCurrency(invoice?['final_price']), 80, isBold: true, isRed: true),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.04), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.15), width: 1)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      _buildInvoiceSummaryItem(l10n.basePrice, _formatCurrency(invoice?['total_price']), ''),
                      const SizedBox(width: 12),
                      _buildInvoiceSummaryItem(l10n.loadingCost, _formatCurrency(invoice?['loading_cost']), ''),
                      const SizedBox(width: 12),
                      _buildInvoiceSummaryItem(l10n.transferCost, _formatCurrency(invoice?['transfer_cost']), ''),
                      const SizedBox(width: 12),
                      _buildInvoiceSummaryItem(l10n.clearanceCost, _formatCurrency(invoice?['clearance_cost']), ''),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(l10n.amountDue, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                      Text('${_formatCurrency(invoice?['final_price'])} ${getInvoiceValue('currency') != '-' ? getInvoiceValue('currency') : 'USD'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFCB001D))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1))),
                padding: const EdgeInsets.only(top: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(l10n.signature, style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
                  Text('${l10n.printDate}: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', style: const TextStyle(fontSize: 8, color: Color(0xFF888888))),
                ]),
              ),
              const SizedBox(height: 4),
              Center(child: Text(l10n.footerText, style: const TextStyle(fontSize: 7, color: Color(0xFF888888)))),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close, style: const TextStyle(fontSize: 12))),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _generatePdfInvoice(invoice, invoiceNumber, l10n);
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                  label: Text(l10n.pdf, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _generatePdfInvoice(invoice, invoiceNumber, l10n);
                  },
                  icon: const Icon(Icons.print, size: 18, color: Colors.white),
                  label: Text(l10n.print, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // PDF GENERATION
  // ============================================
  Future<void> _generatePdfInvoice(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    String getPdfValue(String key, {String defaultValue = '-'}) {
      return invoice?[key]?.toString() ?? defaultValue;
    }

    String unit = getPdfValue('unit');
    double weightPerUnitRaw = double.tryParse(getPdfValue('weight_per_unit')) ?? 0;
    double totalWeightRaw = double.tryParse(getPdfValue('total_weight')) ?? 0;
    
    String displayWeightPerUnit = _formatWeightWithConversion(unit, weightPerUnitRaw);
    String displayTotalWeight = _formatWeightWithConversion(unit, totalWeightRaw);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red, width: 1.8),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(l10n.companyName, style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.SizedBox(height: 4),
                        pw.Text(l10n.integratedManagementSystem, style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
                      ]),
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(6)),
                          child: pw.Text('Invoice', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text('${l10n.invoiceNumberLabel}: $invoiceNumber', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${l10n.persianDate}: ${getPdfValue('date')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('Date (EN): ${getPdfValue('date_en')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('${l10n.paymentMethod}: ${getPdfValue('payment_method') == 'cash' ? l10n.cash : l10n.loan}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        if (getPdfValue('payment_method') != 'cash') pw.Text('${l10n.loanType}: ${getPdfValue('loan_type') == 'full' ? l10n.full : l10n.partial}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        if (getPdfValue('payment_method') != 'cash') pw.Text('${l10n.paidAmount}: ${_formatCurrency(invoice?['paid_amount'])} ${getPdfValue('currency')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        if (getPdfValue('payment_method') != 'cash') pw.Text('${l10n.remainingAmount}: ${_formatCurrency(invoice?['remaining_amount'])} ${getPdfValue('currency')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        if (getPdfValue('loading_time') != '-' && getPdfValue('loading_time').isNotEmpty) pw.Text('${l10n.loadingTime}: ${getPdfValue('loading_time')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        if (getPdfValue('loading_time_en') != '-' && getPdfValue('loading_time_en').isNotEmpty) pw.Text('Loading (EN): ${getPdfValue('loading_time_en')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                      ]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Row(children: [
                    pw.Expanded(child: pw.Text('${l10n.customer}: ${getPdfValue('customer_name')}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    pw.Expanded(child: pw.Text('${l10n.company}: ${getPdfValue('customer_company')}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    pw.Expanded(child: pw.Text('${l10n.dischargeLocation}: ${getPdfValue('location') != '-' ? getPdfValue('location') : getPdfValue('customer_address')}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                  ]),
                ),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: [l10n.customerName, l10n.company, l10n.product, l10n.gender, l10n.size, l10n.thickness, l10n.weight, l10n.weightPerUnit, l10n.unitCount, l10n.totalWeight, l10n.unitPrice, l10n.totalPrice, l10n.discount, l10n.finalPrice],
                  data: [
                    [
                      getPdfValue('customer_name'),
                      getPdfValue('customer_company'),
                      getPdfValue('product_name'),
                      getPdfValue('gender'),
                      getPdfValue('size'),
                      getPdfValue('thickness'),
                      displayTotalWeight,
                      displayWeightPerUnit,
                      getPdfValue('unit_count'),
                      displayTotalWeight,
                      _formatCurrency(invoice?['unit_price']),
                      _formatCurrency(invoice?['total_price']),
                      _formatCurrency(invoice?['discount']),
                      '${_formatCurrency(invoice?['final_price'])} ${getPdfValue('currency') != '-' ? getPdfValue('currency') : 'USD'}',
                    ],
                  ],
                  headerStyle: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 8),
                  cellAlignment: pw.Alignment.center,
                  border: pw.TableBorder.symmetric(outside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5), inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                pw.SizedBox(height: 16),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('${l10n.loadingCost}: ${_formatCurrency(invoice?['loading_cost'])}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('${l10n.transferCost}: ${_formatCurrency(invoice?['transfer_cost'])}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('${l10n.clearanceCost}: ${_formatCurrency(invoice?['clearance_cost'])}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('${l10n.totalPrice}: ${_formatCurrency(invoice?['total_price'])}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('${l10n.discount}: ${_formatCurrency(invoice?['discount'])}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('${l10n.amountDue}: ${_formatCurrency(invoice?['final_price'])} ${getPdfValue('currency') != '-' ? getPdfValue('currency') : 'USD'}', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                  ]),
                ]),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text(l10n.signature, style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('${l10n.printDate}: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                ]),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ============================================
  // BUILD HELPER METHODS
  // ============================================
  Widget _buildInvoiceHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 8), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildInvoiceDataCell(String text, double width, {bool isBold = false, bool isRed = false}) {
    return SizedBox(
      width: width,
      child: Text(text, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isRed ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E), fontSize: 8), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildInvoiceSummaryItem(String label, String value, String unit) {
    return Row(children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11)), const SizedBox(width: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), const SizedBox(width: 2), Text(unit, style: const TextStyle(fontSize: 9, color: Color(0xFF888888)))]);
  }

  Future<void> _deleteSale(Map<String, dynamic> sale) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteInvoice),
        content: Text('${l10n.deleteConfirmation} ${sale['invoice_number']}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _db.deleteSalesInvoice(sale['id']);
    if (result == -1) {
      _showSnackbar(l10n.errorDeletingInvoice, Colors.red);
      return;
    }
    await _loadData();
    _showSnackbar(l10n.invoiceDeletedSuccess, Colors.red);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildSectionTitle(String title, AppLocalizations l10n) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppLocalizations l10n,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    void Function(String)? onChanged,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: onChanged,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: const Color(0xFFCB001D), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0';
    final number = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
    return number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  Widget _buildReturnStatusCell(Map<String, dynamic> sale, AppLocalizations l10n) {
    final isReturned = sale['is_back_returned'] == 1 || sale['is_back_returned']?.toString() == '1';
    if (!isReturned) {
      return Text(l10n.normal, style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFEBF1FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
      child: Text(l10n.returned, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF034ADE))),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: Color(0xFFCB001D), size: 28)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.salesManagement, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              Text(l10n.salesManagementSubtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ]),
          ],
        ),
        ElevatedButton.icon(onPressed: _showAddSaleDialog, icon: const Icon(Icons.add_circle_outline), label: Text(l10n.addNewSale), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12))),
      ],
    );
  }

  Widget _buildQuickStats(AppLocalizations l10n) {
    final totalSales = _sales.fold<double>(0, (sum, item) => sum + (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0));
    final totalInvoices = _sales.length;
    final totalTons = _getTotalTons();
    
    return Row(
      children: [
        _buildStatCard(l10n.totalSales, _formatCurrency(totalSales), Icons.attach_money_outlined, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard(l10n.totalInvoices, totalInvoices.toString(), Icons.receipt_long_outlined, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard(l10n.usdTotal, _formatCurrency(_sales.fold<double>(0, (sum, item) => sum + ((item['currency'] == 'USD' ? (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0) : 0)))), Icons.currency_exchange, Colors.green.shade700),
        const SizedBox(width: 12),
        _buildStatCard('مجموع وزن', '${totalTons.toStringAsFixed(totalTons % 1 == 0 ? 0 : 2)} تن', Icons.scale, const Color(0xFFCB001D)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
        child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)))]))]),
      ),
    );
  }

  Widget _buildFilterAndSearch(AppLocalizations l10n) {
    final filters = [l10n.all, l10n.sale, l10n.proformaInvoice];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Row(children: [Expanded(child: TextField(controller: _searchController, onChanged: (value) => setState(() => _searchQuery = value), decoration: InputDecoration(hintText: l10n.searchByCustomerOrInvoice, prefixIcon: Icon(Icons.search, color: Colors.grey.shade400), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2))))), const SizedBox(width: 12), ...filters.map((filter) => Padding(padding: const EdgeInsets.only(left: 8), child: FilterChip(label: Text(filter, style: TextStyle(color: _selectedFilter == filter ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w600)), selected: _selectedFilter == filter, onSelected: (selected) => setState(() => _selectedFilter = filter), selectedColor: const Color(0xFFCB001D), backgroundColor: Colors.grey.shade100, checkmarkColor: Colors.white)))]),
    );
  }

  Widget _buildSalesTable(List<Map<String, dynamic>> data, AppLocalizations l10n) {
    final totalPages = (data.length / _rowsPerPage).ceil();
    final start = (_currentPage * _rowsPerPage).clamp(0, data.length);
    final paged = data.skip(start).take(_rowsPerPage).toList();
    final allSelectedOnPage = paged.isNotEmpty && paged.every((s) => _selectedInvoices.contains((s['invoice_number'] ?? '').toString()));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14))
          ),
          child: Row(children: [
            SizedBox(width: 40, child: Checkbox(
              value: allSelectedOnPage,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    for (final s in paged) {
                      final id = (s['invoice_number'] ?? '').toString();
                      if (id.isNotEmpty) _selectedInvoices.add(id);
                    }
                  } else {
                    for (final s in paged) {
                      final id = (s['invoice_number'] ?? '').toString();
                      _selectedInvoices.remove(id);
                    }
                  }
                });
              }
            )),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: Text(l10n.invoiceNumberLabel)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: Text(l10n.customer)),
            Expanded(flex: 2, child: Text(l10n.product)),
            Expanded(flex: 1, child: Text(l10n.finalPrice)),
            Expanded(flex: 1, child: Text(l10n.status)),
            Expanded(flex: 1, child: Text(l10n.date)),
            Expanded(flex: 1, child: Text(l10n.actions))
          ]),
        ),
        Expanded(child: paged.isEmpty ? Center(child: Text(l10n.noInvoicesFound, style: const TextStyle(color: Colors.grey))) : ListView.builder(itemCount: paged.length, itemBuilder: (context, index) {
          final sale = paged[index];
          final inv = (sale['invoice_number'] ?? '').toString();
          final checked = _selectedInvoices.contains(inv);
          
          return InkWell(
            onTap: () => _showInvoiceModal(context, sale['invoice_number'] ?? '-', sale, l10n),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1))),
              child: Row(children: [
                SizedBox(width: 40, child: Checkbox(
                  value: checked,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedInvoices.add(inv);
                      } else {
                        _selectedInvoices.remove(inv);
                      }
                    });
                  }
                )),
                Expanded(flex: 1, child: Text(inv.isNotEmpty ? inv : '-', style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sale['customer_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(sale['customer_company'] ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))
                ])),
                Expanded(flex: 2, child: Text(sale['product_name'] ?? '-', style: const TextStyle(fontSize: 13))),
                Expanded(flex: 1, child: Text(_formatCurrency(sale['final_price']), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFCB001D)))),
                Expanded(flex: 1, child: _buildReturnStatusCell(sale, l10n)),
                Expanded(flex: 1, child: Text(sale['date'] ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                Expanded(flex: 1, child: Row(children: [
                  IconButton(onPressed: () => _showInvoiceModal(context, sale['invoice_number'] ?? '-', sale, l10n), icon: const Icon(Icons.visibility_outlined, color: Colors.blue)),
                  IconButton(onPressed: () => _showEditSaleDialog(sale), icon: const Icon(Icons.edit_outlined, color: Colors.orange)),
                  IconButton(onPressed: () => _deleteSale(sale), icon: const Icon(Icons.delete_outline, color: Colors.red))
                ]))
              ])
            )
          );
        })),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Text('${l10n.page} ${_currentPage + 1} ${l10n.pageOf} ${totalPages == 0 ? 1 : totalPages}'),
            const SizedBox(width: 12),
            IconButton(onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null, icon: const Icon(Icons.chevron_left)),
            IconButton(onPressed: (_currentPage + 1) < totalPages ? () => setState(() => _currentPage++) : null, icon: const Icon(Icons.chevron_right)),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _rowsPerPage,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 20, child: Text('20')),
                DropdownMenuItem(value: 50, child: Text('50'))
              ],
              onChanged: (v) => setState(() { _rowsPerPage = v ?? 10; _currentPage = 0; })
            ),
          ]),
          Row(children: [
            Text('${l10n.selected}: ${_selectedInvoices.length}'),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _selectedInvoices.isEmpty ? null : () { /* placeholder for bulk actions */ },
              child: Text(l10n.bulkActions)
            )
          ])
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final filteredData = _sales.where((sale) {
      final search = _searchQuery.toLowerCase();
      final matchesSearch = (sale['invoice_number'] ?? '').toString().toLowerCase().contains(search) || 
                           (sale['customer_name'] ?? '').toString().toLowerCase().contains(search) || 
                           (sale['product_name'] ?? '').toString().toLowerCase().contains(search);
      final matchesFilter = _selectedFilter == 'همه' || (sale['sale_type'] ?? 'فروش') == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(l10n),
                    const SizedBox(height: 20),
                    _buildQuickStats(l10n),
                    const SizedBox(height: 20),
                    _buildFilterAndSearch(l10n),
                    const SizedBox(height: 16),
                    Expanded(child: _buildSalesTable(filteredData, l10n))
                  ]
                ),
        ),
      ),
    );
  }
}
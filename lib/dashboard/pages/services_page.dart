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

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];
  int _currentPage = 0;
  int _rowsPerPage = 10;
  final Set<String> _selectedServices = {};
  String _searchQuery = '';
  String _selectedFilter = 'همه';
  final TextEditingController _searchController = TextEditingController();

  // Helper to convert kg to tons
  String _formatWeightWithConversion(double weight) {
    if (weight <= 0) return '0';
    double tons = weight / 1000;
    
    // For numbers less than 1 ton, show 3 decimal places
    if (tons < 1) {
      return '${tons.toStringAsFixed(3)} تن';
    }
    // For numbers 1 ton or more, show 2 decimal places
    return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
  }

  // Format weight for display based on unit
  String _formatWeightForDisplay(double weight, String unit) {
    if (unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم') {
      return _formatWeightWithConversion(weight);
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 2)} $unit';
  }

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final services = await _db.getServiceInvoices();
      if (!mounted) return;
      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar(l10n.errorLoadingServices, Colors.red);
    }
  }

  Future<void> _showServiceDialog({Map<String, dynamic>? service}) async {
    final l10n = AppLocalizations.of(context)!;
    
    // Initialize controllers
    final invoiceNumberController = TextEditingController(
      text: service?['invoice_number']?.toString() ?? ''
    );
    final customerNameController = TextEditingController(
      text: service?['customer_name']?.toString() ?? ''
    );
    final customerPhoneController = TextEditingController(
      text: service?['customer_phone']?.toString() ?? ''
    );
    final customerAddressController = TextEditingController(
      text: service?['customer_address']?.toString() ?? ''
    );
    final serviceTypeController = TextEditingController(
      text: service?['service_type']?.toString() ?? ''
    );
    final sizeController = TextEditingController(
      text: service?['size']?.toString() ?? ''
    );
    final thicknessController = TextEditingController(
      text: service?['thickness']?.toString() ?? ''
    );
    final totalWeightController = TextEditingController(
      text: service?['total_weight']?.toString() ?? ''
    );
    String selectedUnit = service?['unit']?.toString() ?? 'TON';
    final unitPriceController = TextEditingController(
      text: service?['unit_price']?.toString() ?? ''
    );
    final totalPriceController = TextEditingController(
      text: service?['total_price']?.toString() ?? ''
    );
    final exchangeRateController = TextEditingController(
      text: service?['exchange_rate']?.toString() ?? '1'
    );
    final loadingController = TextEditingController(
      text: service?['loading_cost']?.toString() ?? ''
    );
    final transferController = TextEditingController(
      text: service?['transfer_cost']?.toString() ?? ''
    );
    final clearanceController = TextEditingController(
      text: service?['clearance_cost']?.toString() ?? ''
    );
    final discountController = TextEditingController(
      text: service?['discount']?.toString() ?? ''
    );
    final finalPriceController = TextEditingController(
      text: service?['final_price']?.toString() ?? ''
    );
    final equivalentController = TextEditingController(
      text: service?['afn_equivalent']?.toString() ?? ''
    );
    final dateController = TextEditingController(
      text: service?['date']?.toString() ?? PersianDateConverter.getCurrentPersianDate()
    );
    String selectedEnglishDate = service?['date_en']?.toString() ?? 
        PersianDateConverter.getEnglishDate(DateTime.now());
    String selectedCurrency = service?['currency']?.toString() ?? 'USD';

    // ============================================
    // FIXED: Unit price is ALWAYS per ton
    // ============================================
    void updateTotals() {
      double totalWeight = double.tryParse(totalWeightController.text) ?? 0;
      
      // Convert weight to tons if unit is KG
      double totalWeightInTons = totalWeight;
      bool isKg = selectedUnit == 'KG' || selectedUnit == 'kg' || selectedUnit == 'کیلوگرم';
      if (isKg) {
        totalWeightInTons = totalWeight / 1000;
      }
      
      double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      double exchangeRate = double.tryParse(exchangeRateController.text) ?? 1;
      double loadingCost = double.tryParse(loadingController.text) ?? 0;
      double transferCost = double.tryParse(transferController.text) ?? 0;
      double clearanceCost = double.tryParse(clearanceController.text) ?? 0;
      double discount = double.tryParse(discountController.text) ?? 0;
      
      // FIXED: totalPrice = (weight in tons) * unitPrice (unit price is PER TON)
      double totalPrice = totalWeightInTons * unitPrice;
      totalPriceController.text = totalPrice > 0 ? totalPrice.toStringAsFixed(0) : '';
      
      // Calculate final price
      double finalPrice = totalPrice + loadingCost + transferCost + clearanceCost - discount;
      finalPriceController.text = finalPrice > 0 ? finalPrice.toStringAsFixed(0) : '';
      
      // Calculate equivalent based on selected currency
      if (selectedCurrency == 'USD') {
        // USD selected: finalPrice * rate = AFN equivalent
        equivalentController.text = finalPrice > 0 
            ? (finalPrice * (exchangeRate <= 0 ? 1 : exchangeRate)).toStringAsFixed(0) 
            : '';
      } else {
        // AFN selected: finalPrice / rate = USD equivalent
        equivalentController.text = finalPrice > 0 
            ? (finalPrice / (exchangeRate <= 0 ? 1 : exchangeRate)).toStringAsFixed(2) 
            : '';
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double totalWeight = double.tryParse(totalWeightController.text) ?? 0;
          bool isKg = selectedUnit == 'KG' || selectedUnit == 'kg' || selectedUnit == 'کیلوگرم';
          String displayWeight = isKg 
              ? _formatWeightWithConversion(totalWeight) 
              : '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2)} $selectedUnit';

          // Calculate price per ton hint
          double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
          String pricePerTonHint = '';
          if (selectedUnit.isNotEmpty && totalWeight > 0 && unitPrice > 0) {
            double totalWeightInTons = isKg ? totalWeight / 1000 : totalWeight;
            if (totalWeightInTons > 0) {
              pricePerTonHint = 'قیمت هر تن: ${unitPrice.toStringAsFixed(0)}';
            }
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                service == null ? l10n.addNewService : l10n.editServiceLabel2,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invoice Number
                      _buildTextField(
                        controller: invoiceNumberController,
                        label: l10n.invoiceNumberLabel,
                        icon: Icons.numbers,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      
                      // Customer Name
                      _buildTextField(
                        controller: customerNameController, 
                        label: l10n.customerName, 
                        icon: Icons.person_outline, 
                        l10n: l10n
                      ),
                      const SizedBox(height: 12),
                      
                      // Customer Phone
                      _buildTextField(
                        controller: customerPhoneController, 
                        label: l10n.customerPhone, 
                        icon: Icons.phone_outlined, 
                        keyboardType: TextInputType.phone, 
                        l10n: l10n
                      ),
                      const SizedBox(height: 12),
                      
                      // Customer Address
                      _buildTextField(
                        controller: customerAddressController, 
                        label: l10n.customerAddress, 
                        icon: Icons.location_on_outlined, 
                        l10n: l10n
                      ),
                      const SizedBox(height: 12),
                      
                      // Service Type
                      _buildTextField(
                        controller: serviceTypeController, 
                        label: l10n.serviceTypeLabel2, 
                        icon: Icons.design_services_outlined, 
                        l10n: l10n
                      ),
                      const SizedBox(height: 12),
                      
                      // Size and Thickness
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: sizeController, 
                              label: l10n.size, 
                              icon: Icons.aspect_ratio_outlined, 
                              l10n: l10n
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: thicknessController, 
                              label: l10n.thickness, 
                              icon: Icons.straighten_outlined, 
                              l10n: l10n
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Total Weight and Unit
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
                                  onChanged: (_) => setDialogState(() {
                                    updateTotals();
                                    setDialogState(() {});
                                  }),
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
                                              displayWeight,
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
                                if (totalWeight > 0 && !isKg && selectedUnit != 'TON')
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
                                      child: Text(
                                        '$totalWeight $selectedUnit',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              decoration: InputDecoration(
                                labelText: l10n.unit,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.scale, color: Color(0xFFCB001D)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'TON', child: Text('TON')),
                                DropdownMenuItem(value: 'KG', child: Text('KG')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedUnit = value;
                                  updateTotals();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Unit Price with per ton hint
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: unitPriceController, 
                                  label: '${l10n.unitPrice} (قیمت هر تن)', 
                                  icon: Icons.price_check_outlined, 
                                  keyboardType: TextInputType.number, 
                                  onChanged: (_) => setDialogState(updateTotals), 
                                  l10n: l10n
                                )
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: totalPriceController, 
                                  label: l10n.totalPrice, 
                                  icon: Icons.attach_money_outlined, 
                                  readOnly: true, 
                                  l10n: l10n
                                )
                              ),
                            ],
                          ),
                          if (selectedUnit.isNotEmpty && totalWeight > 0)
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
                      
                      // Currency and Exchange Rate
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCurrency,
                              decoration: InputDecoration(
                                labelText: l10n.currency,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.currency_exchange, color: Color(0xFFCB001D)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'USD', child: Text('USD')),
                                DropdownMenuItem(value: 'AFN', child: Text('AFN')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedCurrency = value;
                                  updateTotals();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: exchangeRateController, 
                              label: selectedCurrency == 'USD' 
                                  ? 'نرخ ارز (USD به AFN) *' 
                                  : 'نرخ ارز (AFN به USD) *',
                              icon: Icons.currency_exchange, 
                              keyboardType: TextInputType.number, 
                              onChanged: (_) => setDialogState(updateTotals), 
                              l10n: l10n
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Equivalent (AFN/USD)
                      _buildTextField(
                        controller: equivalentController, 
                        label: selectedCurrency == 'USD' 
                            ? 'معادل به افغانی (AFN)' 
                            : 'معادل به دالر (USD)',
                        icon: Icons.currency_exchange, 
                        readOnly: true, 
                        l10n: l10n
                      ),
                      const SizedBox(height: 12),
                      
                      // Loading, Transfer, Clearance
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: loadingController, 
                              label: l10n.loadingCost, 
                              icon: Icons.local_shipping_outlined, 
                              keyboardType: TextInputType.number, 
                              onChanged: (_) => setDialogState(updateTotals), 
                              l10n: l10n
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: transferController, 
                              label: l10n.transferCost, 
                              icon: Icons.drive_eta_outlined, 
                              keyboardType: TextInputType.number, 
                              onChanged: (_) => setDialogState(updateTotals), 
                              l10n: l10n
                            )
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
                              icon: Icons.inventory_2_outlined, 
                              keyboardType: TextInputType.number, 
                              onChanged: (_) => setDialogState(updateTotals), 
                              l10n: l10n
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: discountController, 
                              label: l10n.discount, 
                              icon: Icons.discount_outlined, 
                              keyboardType: TextInputType.number, 
                              onChanged: (_) => setDialogState(updateTotals), 
                              l10n: l10n
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Final Price and Date
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: finalPriceController, 
                              label: l10n.finalPrice, 
                              icon: Icons.receipt_long_outlined, 
                              readOnly: true, 
                              l10n: l10n
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
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
                              child: AbsorbPointer(
                                child: _buildTextField(
                                  controller: dateController, 
                                  label: l10n.date, 
                                  icon: Icons.calendar_today_outlined, 
                                  readOnly: true, 
                                  l10n: l10n
                                ),
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
                  child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final invoiceNumber = invoiceNumberController.text.trim();
                    
                    // Validate invoice number
                    if (invoiceNumber.isEmpty) {
                      _showSnackbar('شماره فاکتور الزامی است', Colors.red);
                      return;
                    }
                    
                    // Check if invoice number already exists
                    if (service == null) {
                      final existing = await _db.getServiceInvoiceByNumber(invoiceNumber);
                      if (existing != null) {
                        _showSnackbar('این شماره فاکتور قبلاً ثبت شده است', Colors.red);
                        return;
                      }
                    }
                    
                    final payload = {
                      'invoice_number': invoiceNumber,
                      'customer_name': customerNameController.text.trim(),
                      'customer_phone': customerPhoneController.text.trim(),
                      'customer_address': customerAddressController.text.trim(),
                      'service_type': serviceTypeController.text.trim(),
                      'size': sizeController.text.trim(),
                      'thickness': thicknessController.text.trim(),
                      'total_weight': double.tryParse(totalWeightController.text) ?? 0,
                      'unit': selectedUnit,
                      'unit_price': double.tryParse(unitPriceController.text) ?? 0,
                      'total_price': double.tryParse(totalPriceController.text) ?? 0,
                      'currency': selectedCurrency,
                      'exchange_rate': double.tryParse(exchangeRateController.text) ?? 1,
                      'loading_cost': double.tryParse(loadingController.text) ?? 0,
                      'transfer_cost': double.tryParse(transferController.text) ?? 0,
                      'clearance_cost': double.tryParse(clearanceController.text) ?? 0,
                      'discount': double.tryParse(discountController.text) ?? 0,
                      'final_price': double.tryParse(finalPriceController.text) ?? 0,
                      'afn_equivalent': double.tryParse(equivalentController.text) ?? 0,
                      'date': dateController.text.trim(),
                      'date_en': selectedEnglishDate,
                    };

                    try {
                      if (service == null) {
                        await _db.insertServiceInvoice(payload);
                      } else {
                        await _db.updateServiceInvoice(service['id'], payload);
                      }
                      if (!mounted) return;
                      Navigator.pop(context);
                      await _loadServices();
                      _showSnackbar(
                        service == null ? l10n.serviceAddedSuccess : l10n.serviceUpdatedSuccess, 
                        Colors.green
                      );
                    } catch (e) {
                      if (!mounted) return;
                      _showSnackbar(l10n.errorSavingService, Colors.red);
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(service == null ? l10n.saveService : l10n.saveChanges),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteService(Map<String, dynamic> service) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteServiceLabel),
        content: Text('${l10n.deleteConfirmation} "${service['customer_name'] ?? '-'}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), 
            child: Text(l10n.delete)
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.deleteServiceInvoice(service['id']);
      await _loadServices();
      _showSnackbar(l10n.serviceDeletedSuccess, Colors.orange);
    } catch (e) {
      _showSnackbar(l10n.errorDeletingService, Colors.red);
    }
  }

  // ==================== PDF & PRINT FUNCTIONS ====================

  Future<void> _printServiceInvoice(Map<String, dynamic> service) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final pdf = await _generateServicePDF(service, l10n);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
        name: '${l10n.serviceInvoice}_${service['invoice_number'] ?? service['id']}',
      );
    } catch (e) {
      _showSnackbar('${l10n.errorPrintingInvoice}: $e', Colors.red);
    }
  }

  Future<Uint8List> _generateServicePDF(Map<String, dynamic> service, AppLocalizations l10n) async {
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    // Format weight for PDF
    String unit = service['unit']?.toString() ?? 'TON';
    double totalWeight = double.tryParse(service['total_weight']?.toString() ?? '0') ?? 0;
    String displayWeight = unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم' 
        ? _formatWeightWithConversion(totalWeight) 
        : '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2)} $unit';

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
                // Header - Matching Sales Invoice Style
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
                        pw.Text(
                          l10n.companyName, 
                          style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.black)
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          l10n.integratedSystem, 
                          style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)
                        ),
                      ]),
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(6)),
                          child: pw.Text(
                            'Service Invoice', 
                            style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          '${l10n.invoiceNumberLabel}: ${service['invoice_number'] ?? service['id'] ?? '-'}', 
                          style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)
                        ),
                        pw.Text(
                          '${l10n.persianDate}: ${service['date'] ?? '-'}', 
                          style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)
                        ),
                        pw.Text(
                          'Date (EN): ${service['date_en'] ?? '-'}', 
                          style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)
                        ),
                      ]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Customer Info - Matching Sales Invoice Style
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${l10n.customerName}: ${service['customer_name'] ?? '-'}', 
                            style: pw.TextStyle(font: ttf, fontSize: 10)
                          )
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            '${l10n.customerPhone}: ${service['customer_phone'] ?? '-'}', 
                            style: pw.TextStyle(font: ttf, fontSize: 10)
                          )
                        ),
                      ]),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${l10n.customerAddress}: ${service['customer_address'] ?? '-'}', 
                        style: pw.TextStyle(font: ttf, fontSize: 10)
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${l10n.serviceTypeLabel2}: ${service['service_type'] ?? '-'}', 
                            style: pw.TextStyle(font: ttf, fontSize: 10)
                          )
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            '${l10n.size}: ${service['size'] ?? '-'}', 
                            style: pw.TextStyle(font: ttf, fontSize: 10)
                          )
                        ),
                      ]),
                      pw.Row(children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${l10n.thickness}: ${service['thickness'] ?? '-'}', 
                            style: pw.TextStyle(font: ttf, fontSize: 10)
                          )
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            '${l10n.unit}: ${service['unit'] ?? '-'}', 
                            style: pw.TextStyle(font: ttf, fontSize: 10)
                          )
                        ),
                      ]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // Service Details Table - Matching Sales Invoice Style
                pw.Table.fromTextArray(
                  headers: [l10n.descriptionLabel, l10n.amountLabel],
                  data: [
                    ['${l10n.totalWeight} (${service['unit'] ?? 'TON'})', displayWeight],
                    [l10n.unitPrice, '${_formatNumber(service['unit_price'])} ${service['currency'] ?? 'USD'}'],
                    [l10n.totalPrice, '${_formatNumber(service['total_price'])} ${service['currency'] ?? 'USD'}'],
                    [l10n.loadingCost, '${_formatNumber(service['loading_cost'])} ${service['currency'] ?? 'USD'}'],
                    [l10n.transferCost, '${_formatNumber(service['transfer_cost'])} ${service['currency'] ?? 'USD'}'],
                    [l10n.clearanceCost, '${_formatNumber(service['clearance_cost'])} ${service['currency'] ?? 'USD'}'],
                    [l10n.discount, '-${_formatNumber(service['discount'])} ${service['currency'] ?? 'USD'}'],
                    [l10n.finalPrice, '${_formatNumber(service['final_price'])} ${service['currency'] ?? 'USD'}'],
                  ],
                  headerStyle: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
                  cellAlignment: pw.Alignment.centerRight,
                  border: pw.TableBorder.symmetric(
                    outside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                pw.SizedBox(height: 16),

                // Currency Info - Matching Sales Invoice Style
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${l10n.currency}: ${service['currency'] ?? '-'}', 
                        style: pw.TextStyle(font: ttf, fontSize: 10)
                      ),
                      pw.Text(
                        '${l10n.exchangeRate}: ${service['exchange_rate'] ?? '-'}', 
                        style: pw.TextStyle(font: ttf, fontSize: 10)
                      ),
                      pw.Text(
                        '${l10n.afnEquivalent}: ${_formatNumber(service['afn_equivalent'])} AFN', 
                        style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),

                // Footer - Matching Sales Invoice Style
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text(
                    l10n.signature, 
                    style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)
                  ),
                  pw.Text(
                    '${l10n.printDate}: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', 
                    style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)
                  ),
                ]),
                pw.Center(
                  child: pw.Text(
                    l10n.footerText, 
                    style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey500)
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  // ==================== UI BUILDERS ====================

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.design_services, color: Color(0xFFCB001D), size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.servicesManagement, 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))
                ),
                Text(
                  l10n.servicesManagementSubtitle, 
                  style: const TextStyle(fontSize: 13, color: Colors.grey)
                ),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showServiceDialog(),
          icon: const Icon(Icons.add_circle_outline),
          label: Text(l10n.addNewService),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCB001D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(AppLocalizations l10n) {
    final totalServices = _services.length;
    final totalRevenue = _services.fold<double>(0, (sum, item) => sum + (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0));
    
    // Calculate total weight in tons from all services
    double totalWeightInTons = 0;
    for (var service in _services) {
      String unit = service['unit']?.toString() ?? 'TON';
      double weight = double.tryParse(service['total_weight']?.toString() ?? '0') ?? 0;
      if (unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم') {
        totalWeightInTons += weight / 1000;
      } else {
        totalWeightInTons += weight;
      }
    }
    
    return Row(
      children: [
        _buildStatCard(l10n.totalRevenue, _formatNumber(totalRevenue), Icons.attach_money_outlined, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard(l10n.totalServicesCount, totalServices.toString(), Icons.design_services_outlined, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard(l10n.usdTotalServices, _formatNumber(_services.fold<double>(0, (sum, item) => sum + ((item['currency'] == 'USD' ? (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0) : 0)))), Icons.currency_exchange, Colors.green.shade700),
        const SizedBox(width: 12),
        _buildStatCard('مجموع وزن', '${totalWeightInTons.toStringAsFixed(totalWeightInTons % 1 == 0 ? 0 : 2)} تن', Icons.scale, const Color(0xFFCB001D)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8), 
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), 
            child: Icon(icon, color: color, size: 18)
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildFilterAndSearch(AppLocalizations l10n) {
    final filters = [l10n.allFilter, l10n.servicesFilter];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: l10n.searchServices,
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ...filters.map((filter) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: FilterChip(
            label: Text(filter, style: TextStyle(color: _selectedFilter == filter ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w600)),
            selected: _selectedFilter == filter,
            onSelected: (selected) => setState(() => _selectedFilter = filter),
            selectedColor: const Color(0xFFCB001D),
            backgroundColor: Colors.grey.shade100,
            checkmarkColor: Colors.white,
          ),
        )),
      ]),
    );
  }

  Widget _buildServicesTable(List<Map<String, dynamic>> data, AppLocalizations l10n) {
    final totalPages = (data.length / _rowsPerPage).ceil();
    final start = (_currentPage * _rowsPerPage).clamp(0, data.length);
    final paged = data.skip(start).take(_rowsPerPage).toList();
    final allSelectedOnPage = paged.isNotEmpty && paged.every((s) => _selectedServices.contains((s['invoice_number'] ?? s['id'] ?? '').toString()));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Checkbox(
                      value: allSelectedOnPage,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            for (final s in paged) {
                              final id = (s['invoice_number'] ?? s['id'] ?? '').toString();
                              if (id.isNotEmpty) _selectedServices.add(id);
                            }
                          } else {
                            for (final s in paged) {
                              final id = (s['invoice_number'] ?? s['id'] ?? '').toString();
                              _selectedServices.remove(id);
                            }
                          }
                        });
                      },
                    ),
                  ),
                  _buildHeaderCell(l10n.invoiceNumberLabel, 90),
                  _buildHeaderCell(l10n.customer, 120),
                  _buildHeaderCell(l10n.customerPhone, 100),
                  _buildHeaderCell(l10n.serviceTypeLabel2, 100),
                  _buildHeaderCell(l10n.size, 70),
                  _buildHeaderCell(l10n.thickness, 70),
                  _buildHeaderCell(l10n.totalWeight, 80),
                  _buildHeaderCell(l10n.unit, 50),
                  _buildHeaderCell(l10n.unitPrice, 80),
                  _buildHeaderCell(l10n.totalPrice, 90),
                  _buildHeaderCell(l10n.finalPrice, 90),
                  _buildHeaderCell(l10n.currency, 60),
                  _buildHeaderCell(l10n.date, 90),
                  _buildHeaderCell(l10n.actions, 140),
                ],
              ),
            ),
          ),
          // Data Rows
          Expanded(
            child: paged.isEmpty
                ? Center(child: Text(l10n.noServicesFound, style: const TextStyle(color: Colors.grey)))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: paged.map((service) {
                          final id = (service['invoice_number'] ?? service['id'] ?? '').toString();
                          final checked = _selectedServices.contains(id);
                          
                          // Format weight based on unit
                          String unit = service['unit']?.toString() ?? 'TON';
                          double totalWeight = double.tryParse(service['total_weight']?.toString() ?? '0') ?? 0;
                          String displayWeight = unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم' 
                              ? _formatWeightWithConversion(totalWeight) 
                              : totalWeight.toString();
                          String displayUnit = unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم' ? 'تن' : unit;
                          
                          return InkWell(
                            onTap: () => _printServiceInvoice(service),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade100, width: 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 50,
                                    child: Checkbox(
                                      value: checked,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedServices.add(id);
                                          } else {
                                            _selectedServices.remove(id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  _buildDataCell(service['invoice_number']?.toString() ?? '-', 90, isBold: true),
                                  _buildDataCell(service['customer_name'] ?? '-', 120, isBold: true),
                                  _buildDataCell(service['customer_phone'] ?? '-', 100),
                                  _buildDataCell(service['service_type'] ?? '-', 100),
                                  _buildDataCell(service['size'] ?? '-', 70),
                                  _buildDataCell(service['thickness'] ?? '-', 70),
                                  _buildDataCell(displayWeight, 80),
                                  _buildDataCell(displayUnit, 50),
                                  _buildDataCell(_formatNumber(service['unit_price']), 80),
                                  _buildDataCell(_formatNumber(service['total_price']), 90),
                                  _buildDataCell(_formatNumber(service['final_price']), 90, isBold: true, color: const Color(0xFFCB001D)),
                                  _buildDataCell(service['currency'] ?? '-', 60),
                                  _buildDataCell(service['date'] ?? '-', 90),
                                  SizedBox(
                                    width: 140,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          onPressed: () => _showServiceDialog(service: service),
                                          icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                          padding: EdgeInsets.zero,
                                        ),
                                        IconButton(
                                          onPressed: () => _deleteService(service),
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                          padding: EdgeInsets.zero,
                                        ),
                                        IconButton(
                                          onPressed: () => _printServiceInvoice(service),
                                          icon: const Icon(Icons.print_outlined, color: Color(0xFFCB001D), size: 20),
                                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          // Pagination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Text('${l10n.page} ${_currentPage + 1} ${l10n.pageOf} ${totalPages == 0 ? 1 : totalPages}'),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                    icon: const Icon(Icons.chevron_left),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: (_currentPage + 1) < totalPages ? () => setState(() => _currentPage++) : null,
                    icon: const Icon(Icons.chevron_right),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _rowsPerPage,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5')),
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 20, child: Text('20')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                    ],
                    onChanged: (v) => setState(() {
                      _rowsPerPage = v ?? 10;
                      _currentPage = 0;
                    }),
                  ),
                ]),
                Row(children: [
                  Text('${l10n.selected}: ${_selectedServices.length}'),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedServices.isEmpty ? null : () {
                      // Bulk actions placeholder
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCB001D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(l10n.bulkActions),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widgets for table
  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Color(0xFF1A1A1A),
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {bool isBold = false, Color? color}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          fontSize: 11,
          color: color ?? const Color(0xFF1A1A1A),
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppLocalizations l10n,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int maxLines = 1,
    Function(String)? onChanged,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      inputFormatters: keyboardType == TextInputType.number 
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))] 
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: const Color(0xFFCB001D), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onChanged: onChanged,
    );
  }

  String _formatNumber(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '0') ?? 0;
    return parsed.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final filteredData = _services.where((service) {
      final search = _searchQuery.toLowerCase();
      final matchesSearch = 
          (service['invoice_number'] ?? '').toString().toLowerCase().contains(search) ||
          (service['customer_name'] ?? '').toString().toLowerCase().contains(search) ||
          (service['service_type'] ?? '').toString().toLowerCase().contains(search) ||
          (service['id'] ?? '').toString().toLowerCase().contains(search) ||
          (service['customer_phone'] ?? '').toString().toLowerCase().contains(search);
      
      final matchesFilter = _selectedFilter == 'همه' || 
          (service['service_type'] ?? '').toString().isNotEmpty;
      
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
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildHeader(l10n),
                  const SizedBox(height: 20),
                  _buildQuickStats(l10n),
                  const SizedBox(height: 20),
                  _buildFilterAndSearch(l10n),
                  const SizedBox(height: 16),
                  Expanded(child: _buildServicesTable(filteredData, l10n)),
                ]),
        ),
      ),
    );
  }
}
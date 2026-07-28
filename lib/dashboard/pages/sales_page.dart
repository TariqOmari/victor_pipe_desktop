import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';

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
      _showSnackbar('خطا در بارگذاری فروش‌ها', Colors.red);
    }
  }

  Future<void> _showAddSaleDialog() async {
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
    final afnEquivalentController = TextEditingController();
    final dateController = TextEditingController(text: PersianDateConverter.getCurrentPersianDate());
    final paidAmountController = TextEditingController();
    String selectedPaymentMethod = 'cash';
    String selectedCurrency = 'USD';
    String selectedType = 'فروش';
    Map<String, dynamic>? selectedParty;
    String selectedEnglishDate = PersianDateConverter.getEnglishDate(DateTime.now());
    String selectedEnglishTime = _formatTimeOfDay(TimeOfDay.now());

    void updateTotals() {
      final weightPerUnit = double.tryParse(weightPerUnitController.text) ?? 0;
      final unitCount = double.tryParse(unitCountController.text) ?? 0;
      final unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      final priceRate = double.tryParse(priceRateController.text) ?? 1;
      final loadingCost = double.tryParse(loadingController.text) ?? 0;
      final transferCost = double.tryParse(transferController.text) ?? 0;
      final clearanceCost = double.tryParse(clearanceController.text) ?? 0;
      final discount = double.tryParse(discountController.text) ?? 0;
      final totalWeight = weightPerUnit * unitCount;
      final totalPrice = totalWeight * unitPrice;

      totalWeightController.text = totalWeight > 0 ? totalWeight.toStringAsFixed(2) : '';
      totalPriceController.text = totalPrice > 0 ? totalPrice.toStringAsFixed(0) : '';

      if (selectedCurrency == 'USD') {
        afnEquivalentController.text = totalPrice > 0 ? (totalPrice * (priceRate <= 0 ? 1 : priceRate)).toStringAsFixed(0) : '';
      } else {
        afnEquivalentController.text = totalPrice > 0 ? (totalPrice / (priceRate <= 0 ? 1 : priceRate)).toStringAsFixed(0) : '';
      }

      final finalPrice = totalPrice + loadingCost + transferCost + clearanceCost - discount;
      finalPriceController.text = finalPrice > 0 ? finalPrice.toStringAsFixed(0) : '';
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('ثبت فروش جدید', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1A1A1A))),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('مدیریت فروشات'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedParty,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'انتخاب مشتری / شرکت',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.history_rounded, color: Color(0xFFCB001D)),
                            tooltip: 'مشاهده سوابق مشتری/شرکت',
                            onPressed: selectedParty == null
                                ? null
                                : () => _showPartyTransactionHistory(selectedParty),
                          ),
                        ),
                        items: _partyOptions.map((option) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: option,
                            child: Text('${option['name']} (${option['source'] == 'company' ? 'شرکت' : 'مشتری'})'),
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
                          Expanded(child: _buildTextField(controller: customerNameController, label: 'نام مشتری', icon: Icons.person_outline)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: companyController, label: 'نام شرکت', icon: Icons.business_outlined)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: phoneController, label: 'شماره تماس', icon: Icons.phone_outlined, keyboardType: TextInputType.phone)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: addressController, label: 'آدرس', icon: Icons.location_on_outlined)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle('مشخصات محصول'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: productController, label: 'نام محصول', icon: Icons.inventory_2_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: genderController, label: 'نوع جنس', icon: Icons.category_outlined)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: sizeController, label: 'سایز', icon: Icons.straighten)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: thicknessController, label: 'ضخامت', icon: Icons.height)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: weightPerUnitController, label: 'وزن فی خاده (کیلوگرم)', icon: Icons.scale_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: unitCountController, label: 'تعداد خاده', icon: Icons.numbers, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: totalWeightController, label: 'مجموع وزن (کیلوگرم)', icon: Icons.monitor_weight_outlined, keyboardType: TextInputType.number, readOnly: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: unitController, label: 'واحد', icon: Icons.scale, readOnly: true)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle('اطلاعات مالی'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: unitController, label: 'واحد', icon: Icons.widgets_outlined, readOnly: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: unitPriceController, label: 'قیمت واحد (هر کیلو)', icon: Icons.attach_money_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: totalPriceController, label: 'مجموع قیمت', icon: Icons.receipt_long_outlined, keyboardType: TextInputType.number, readOnly: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: priceRateController, label: 'نرخ ارز (از سیستم/ورود دستی)', icon: Icons.currency_exchange, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(controller: afnEquivalentController, label: 'معادل افغانی', icon: Icons.currency_exchange, readOnly: true),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: loadingController, label: 'هزینه بارگیری', icon: Icons.local_shipping_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: transferController, label: 'هزینه انتقال', icon: Icons.drive_eta_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: clearanceController, label: 'هزینه تخلیه', icon: Icons.fact_check_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: discountController, label: 'تخفیف', icon: Icons.discount_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: finalPriceController, label: 'قیمت نهایی', icon: Icons.payments_outlined, keyboardType: TextInputType.number, readOnly: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: dateController, label: 'تاریخ شمسی', icon: Icons.date_range_outlined, readOnly: true, onTap: () async {
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
                          })),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: timeController, label: 'ساعت بارگیری', icon: Icons.access_time_outlined, readOnly: true, onTap: () async {
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
                          })),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCurrency,
                        decoration: const InputDecoration(labelText: 'ارز نهایی', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('دالر (USD)')),
                          DropdownMenuItem(value: 'AFN', child: Text('افغانی (AFN)')),
                        ],
                        onChanged: (value) => setDialogState(() {
                          selectedCurrency = value ?? 'USD';
                          updateTotals();
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: 'نوع معامله', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'فروش', child: Text('فروش')),
                          DropdownMenuItem(value: 'پیش‌فاکتور', child: Text('پیش‌فاکتور')),
                        ],
                        onChanged: (value) => setDialogState(() => selectedType = value ?? 'فروش'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethod,
                        decoration: const InputDecoration(labelText: 'روش پرداخت', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقد')),
                          DropdownMenuItem(value: 'loan_full', child: Text('قرض (کامل)')),
                          DropdownMenuItem(value: 'loan_partial', child: Text('قرض (نقد جزئی)')),
                        ],
                        onChanged: (value) => setDialogState(() => selectedPaymentMethod = value ?? 'cash'),
                      ),
                      if (selectedPaymentMethod == 'loan_partial') const SizedBox(height: 12),
                      if (selectedPaymentMethod == 'loan_partial') _buildTextField(controller: paidAmountController, label: 'مبلغ پرداختی اولیه', icon: Icons.payments_outlined, keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      _buildTextField(controller: descriptionController, label: 'توضیحات', icon: Icons.notes_outlined, maxLines: 2),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    final customerName = customerNameController.text.trim();
                    final phone = phoneController.text.trim();
                    final address = addressController.text.trim();
                    final company = companyController.text.trim();
                    final product = productController.text.trim();
                    if (customerName.isEmpty || product.isEmpty) {
                      _showSnackbar('نام مشتری و محصول الزامی است', Colors.red);
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
                    final invoiceNumber = await _buildInvoiceNumber();
                    final remainingAmount = selectedPaymentMethod == 'cash'
                        ? 0
                        : (finalPrice - paidAmount) < 0
                            ? 0
                            : finalPrice - paidAmount;
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
                    };
                    final id = await _db.insertSalesInvoice(payload);
                    if (id == -1) {
                      _showSnackbar('ثبت فروش با خطا مواجه شد', Colors.red);
                      return;
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
                        _showSnackbar('خطا در ذخیره قرض', Colors.red);
                      } else {
                        if (paidAmount > 0) {
                          await _db.insertSellLoanPayment({
                            'loan_id': loanId,
                            'amount': paidAmount,
                            'note': 'پرداخت اولیه هنگام ثبت فروش',
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
                    });
                    _showSnackbar('فروش با موفقیت ثبت و ذخیره شد', Colors.green);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white),
                  child: const Text('ثبت فروش'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPartyTransactionHistory(Map<String, dynamic>? initialParty) {
    Map<String, dynamic>? selectedParty = initialParty ?? (_partyOptions.isNotEmpty ? _partyOptions.first : null);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
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
                          const Text('سوابق معاملات مشتری / شرکت', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                          const SizedBox(height: 4),
                          Text(currentParty == null ? 'هیچ مشتری/شرکتی انتخاب نشده است' : currentParty['name']?.toString() ?? '-', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                        ],
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey, size: 24)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedParty,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'انتخاب مشتری / شرکت', border: OutlineInputBorder()),
                    items: _partyOptions.map((option) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: option,
                        child: Text('${option['name']?.toString() ?? '-'} (${option['source']?.toString() == 'company' ? 'شرکت' : 'مشتری'})'),
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
                      _buildKeyValueChip('فاکتورها', totalInvoices.toString(), Colors.blue),
                      const SizedBox(width: 12),
                      _buildKeyValueChip('مجموع مبلغ', _formatCurrency(totalAmount), Colors.green),
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
                                Text('هیچ سوابقی برای این ${currentParty == null ? '' : currentParty['source']?.toString() == 'company' ? 'شرکت' : 'مشتری'} ثبت نشده است', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
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
                                  _showInvoiceModal(context, sale['invoice_number'] ?? '-', sale);
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
      ),
    );
  }

  Widget _buildKeyValueChip(String label, String value, Color color) {
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

  void _showInvoiceModal(BuildContext context, String invoiceNumber, Map<String, dynamic> invoice) {
    // Helper function to safely get values from invoice map
    String getInvoiceValue(String key, {String defaultValue = '-'}) {
      return invoice?[key]?.toString() ?? defaultValue;
    }

    double getInvoiceNumberValue(String key, {double defaultValue = 0}) {
      final value = invoice?[key];
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ویکتور پایپ صنعت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                          SizedBox(height: 2),
                          Text('سامانه مدیریت یکپارچه', style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
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
                        child: Text('شماره: $invoiceNumber', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB001D), fontSize: 12)),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('تاریخ (شمسی): ${getInvoiceValue('date')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        Text('Date (EN): ${getInvoiceValue('date_en')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        if (getInvoiceValue('loading_time') != '-' && getInvoiceValue('loading_time').isNotEmpty) Text('ساعت بارگیری: ${getInvoiceValue('loading_time')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        if (getInvoiceValue('loading_time_en') != '-' && getInvoiceValue('loading_time_en').isNotEmpty) Text('Loading (EN): ${getInvoiceValue('loading_time_en')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        if (invoice?['is_back_returned'] == 1 || invoice?['is_back_returned']?.toString() == '1') ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFEBF1FF), borderRadius: BorderRadius.circular(4)),
                            child: const Text('وضعیت: برگشت خورده', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF034ADE))),
                          ),
                          if (getInvoiceValue('back_return_reason') != '-' && getInvoiceValue('back_return_reason').isNotEmpty) Text('علت برگشت: ${getInvoiceValue('back_return_reason')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                          Text('تاریخ برگشت: ${getInvoiceValue('back_return_date')}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
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
                        const Text('مشتری:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(getInvoiceValue('supplier_name') != '-' ? getInvoiceValue('supplier_name') : getInvoiceValue('customer_name'), style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                    Expanded(
                      child: Row(children: [
                        const Icon(Icons.location_on, color: Color(0xFFCB001D), size: 14),
                        const SizedBox(width: 4),
                        const Text('محل تخلیه:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
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
                    Text('روش پرداخت: ${getInvoiceValue('payment_method') == 'cash' ? 'نقد' : getInvoiceValue('payment_method') == 'loan_full' ? 'قرض کامل' : getInvoiceValue('payment_method') == 'loan_partial' ? 'قرض جزئی' : '-'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    if (getInvoiceValue('payment_method') != 'cash') ...[
                      const SizedBox(height: 4),
                      Text('نوع قرض: ${getInvoiceValue('loan_type') == 'full' ? 'تمام' : getInvoiceValue('loan_type') == 'partial' ? 'جزئی' : '-'}', style: const TextStyle(fontSize: 10)),
                      Text('پرداخت شده: ${_formatCurrency(invoice?['paid_amount'])} ${getInvoiceValue('currency')}', style: const TextStyle(fontSize: 10)),
                      Text('باقی‌مانده: ${_formatCurrency(invoice?['remaining_amount'])} ${getInvoiceValue('currency')}', style: const TextStyle(fontSize: 10)),
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
                          _buildInvoiceHeaderCell('نام مشتری', 80),
                          _buildInvoiceHeaderCell('شرکت', 70),
                          _buildInvoiceHeaderCell('محصول', 90),
                          _buildInvoiceHeaderCell('جنس', 60),
                          _buildInvoiceHeaderCell('سایز', 60),
                          _buildInvoiceHeaderCell('ضخامت', 60),
                          _buildInvoiceHeaderCell('وزن', 60),
                          _buildInvoiceHeaderCell('وزن خاده', 70),
                          _buildInvoiceHeaderCell('تعداد خاده', 70),
                          _buildInvoiceHeaderCell('مجموع وزن', 70),
                          _buildInvoiceHeaderCell('قیمت واحد', 70),
                          _buildInvoiceHeaderCell('مجموع قیمت', 70),
                          _buildInvoiceHeaderCell('تخفیف', 60),
                          _buildInvoiceHeaderCell('قیمت نهایی', 80),
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
                              _buildInvoiceDataCell(getInvoiceValue('weight'), 60),
                              _buildInvoiceDataCell(getInvoiceValue('weight_per_unit'), 70),
                              _buildInvoiceDataCell(getInvoiceValue('unit_count'), 70),
                              _buildInvoiceDataCell(getInvoiceValue('total_weight'), 70),
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
                      _buildInvoiceSummaryItem('قیمت پایه:', _formatCurrency(invoice?['total_price']), ''),
                      const SizedBox(width: 12),
                      _buildInvoiceSummaryItem('هزینه بارگیری:', _formatCurrency(invoice?['loading_cost']), ''),
                      const SizedBox(width: 12),
                      _buildInvoiceSummaryItem('هزینه انتقال:', _formatCurrency(invoice?['transfer_cost']), ''),
                      const SizedBox(width: 12),
                      _buildInvoiceSummaryItem('هزینه تخلیه:', _formatCurrency(invoice?['clearance_cost']), ''),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('مبلغ قابل پرداخت', style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
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
                  const Text('امضا: _________________', style: TextStyle(fontSize: 9, color: Color(0xFF888888))),
                  Text('تاریخ چاپ: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', style: const TextStyle(fontSize: 8, color: Color(0xFF888888))),
                ]),
              ),
              const SizedBox(height: 4),
              const Center(child: Text('ویکتور پایپ صنعت - سامانه مدیریت یکپارچه', style: TextStyle(fontSize: 7, color: Color(0xFF888888)))),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن', style: TextStyle(fontSize: 12))),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _generatePdfInvoice(invoice, invoiceNumber);
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                  label: const Text('PDF', style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _generatePdfInvoice(invoice, invoiceNumber);
                  },
                  icon: const Icon(Icons.print, size: 18, color: Colors.white),
                  label: const Text('چاپ', style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdfInvoice(Map<String, dynamic> invoice, String invoiceNumber) async {
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    // Helper function for PDF
    String getPdfValue(String key, {String defaultValue = '-'}) {
      return invoice?[key]?.toString() ?? defaultValue;
    }

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
                        pw.Text('ویکتور پایپ صنعت', style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.SizedBox(height: 4),
                        pw.Text('سامانه مدیریت یکپارچه', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
                      ]),
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(6)),
                          child: pw.Text('Invoice', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text('شماره: $invoiceNumber', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('تاریخ (شمسی): ${getPdfValue('date')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('Date (EN): ${getPdfValue('date_en')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('روش پرداخت: ${getPdfValue('payment_method') == 'cash' ? 'نقد' : 'قرض'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        if (getPdfValue('payment_method') != 'cash') pw.Text('نوع قرض: ${getPdfValue('loan_type') == 'full' ? 'تمام' : 'جزئی'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        if (getPdfValue('payment_method') != 'cash') pw.Text('پرداخت شده: ${_formatCurrency(invoice?['paid_amount'])} ${getPdfValue('currency')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        if (getPdfValue('payment_method') != 'cash') pw.Text('باقی‌مانده: ${_formatCurrency(invoice?['remaining_amount'])} ${getPdfValue('currency')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        if (getPdfValue('loading_time') != '-' && getPdfValue('loading_time').isNotEmpty) pw.Text('ساعت بارگیری: ${getPdfValue('loading_time')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
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
                    pw.Expanded(child: pw.Text('مشتری: ${getPdfValue('customer_name')}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    pw.Expanded(child: pw.Text('شرکت: ${getPdfValue('customer_company')}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    pw.Expanded(child: pw.Text('محل تخلیه: ${getPdfValue('location') != '-' ? getPdfValue('location') : getPdfValue('customer_address')}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                  ]),
                ),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: ['نام مشتری', 'شرکت', 'محصول', 'جنس', 'سایز', 'ضخامت', 'وزن', 'وزن/واحد', 'تعداد واحد', 'مجموع وزن', 'قیمت واحد', 'قیمت پایه', 'تخفیف', 'قیمت نهایی'],
                  data: [
                    [
                      getPdfValue('customer_name'),
                      getPdfValue('customer_company'),
                      getPdfValue('product_name'),
                      getPdfValue('gender'),
                      getPdfValue('size'),
                      getPdfValue('thickness'),
                      getPdfValue('weight'),
                      getPdfValue('weight_per_unit'),
                      getPdfValue('unit_count'),
                      getPdfValue('total_weight'),
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
                    pw.Text('هزینه بارگیری: ${_formatCurrency(invoice?['loading_cost'])}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('هزینه انتقال: ${_formatCurrency(invoice?['transfer_cost'])}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('هزینه تخلیه: ${_formatCurrency(invoice?['clearance_cost'])}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('قیمت پایه: ${_formatCurrency(invoice?['total_price'])}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('تخفیف: ${_formatCurrency(invoice?['discount'])}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('مبلغ قابل پرداخت: ${_formatCurrency(invoice?['final_price'])} ${getPdfValue('currency') != '-' ? getPdfValue('currency') : 'USD'}', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                  ]),
                ]),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('امضا: ______________________', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('تاریخ چاپ: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                ]),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فاکتور'),
        content: Text('آیا از حذف فاکتور ${sale['invoice_number']} مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _db.deleteSalesInvoice(sale['id']);
    if (result == -1) {
      _showSnackbar('حذف فاکتور با خطا مواجه شد', Colors.red);
      return;
    }
    await _loadData();
    _showSnackbar('فاکتور با موفقیت حذف شد', Colors.red);
  }

  Future<String> _buildInvoiceNumber() async {
    final nextNumber = await _db.getNextSalesInvoiceNumber();
    return nextNumber.toString().padLeft(5, '0');
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)));
  }

  Widget _invoiceInfoRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Text(value?.toString() ?? '-', style: const TextStyle(color: Color(0xFF1A1A1A)))),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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

  Widget _buildReturnStatusCell(Map<String, dynamic> sale) {
    final isReturned = sale['is_back_returned'] == 1 || sale['is_back_returned']?.toString() == '1';
    if (!isReturned) {
      return Text('عادی', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFEBF1FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
      child: const Text('برگشت خورده', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF034ADE))),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: Color(0xFFCB001D), size: 28)),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مدیریت فروشات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))), Text('ثبت، ذخیره و پیش‌نمایش فاکتورهای فروش', style: TextStyle(fontSize: 13, color: Colors.grey))]),
          ],
        ),
        ElevatedButton.icon(onPressed: _showAddSaleDialog, icon: const Icon(Icons.add_circle_outline), label: const Text('ثبت فروش جدید'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12))),
      ],
    );
  }

  Widget _buildQuickStats() {
    final totalSales = _sales.fold<double>(0, (sum, item) => sum + (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0));
    final totalInvoices = _sales.length;
    return Row(
      children: [
        _buildStatCard('جمع فروش', _formatCurrency(totalSales), Icons.attach_money_outlined, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard('تعداد فاکتور', totalInvoices.toString(), Icons.receipt_long_outlined, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard('ارز USD', _formatCurrency(_sales.fold<double>(0, (sum, item) => sum + ((item['currency'] == 'USD' ? (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0) : 0)))), Icons.currency_exchange, Colors.green.shade700),
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

  Widget _buildFilterAndSearch() {
    final filters = ['همه', 'فروش', 'پیش‌فاکتور'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Row(children: [Expanded(child: TextField(controller: _searchController, onChanged: (value) => setState(() => _searchQuery = value), decoration: InputDecoration(hintText: 'جستجو بر اساس مشتری یا شماره فاکتور...', prefixIcon: Icon(Icons.search, color: Colors.grey.shade400), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2))))), const SizedBox(width: 12), ...filters.map((filter) => Padding(padding: const EdgeInsets.only(left: 8), child: FilterChip(label: Text(filter, style: TextStyle(color: _selectedFilter == filter ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w600)), selected: _selectedFilter == filter, onSelected: (selected) => setState(() => _selectedFilter = filter), selectedColor: const Color(0xFFCB001D), backgroundColor: Colors.grey.shade100, checkmarkColor: Colors.white)))]),
    );
  }

  Widget _buildSalesTable(List<Map<String, dynamic>> data) {
    final totalPages = (data.length / _rowsPerPage).ceil();
    final start = (_currentPage * _rowsPerPage).clamp(0, data.length);
    final paged = data.skip(start).take(_rowsPerPage).toList();
    final allSelectedOnPage = paged.isNotEmpty && paged.every((s) => _selectedInvoices.contains((s['invoice_number'] ?? '').toString()));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14))), child: Row(children: [SizedBox(width: 40, child: Checkbox(value: allSelectedOnPage, onChanged: (v) {
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
            })), const SizedBox(width: 8), const Expanded(flex: 1, child: Text('شماره')), const SizedBox(width: 8), const Expanded(flex: 2, child: Text('مشتری')), const Expanded(flex: 2, child: Text('محصول')), const Expanded(flex: 1, child: Text('جمع نهایی')), const Expanded(flex: 1, child: Text('وضعیت')), const Expanded(flex: 1, child: Text('تاریخ')), const Expanded(flex: 1, child: Text('عملیات'))])),
        Expanded(child: paged.isEmpty ? const Center(child: Text('هیچ فاکتوری ثبت نشده است', style: TextStyle(color: Colors.grey))) : ListView.builder(itemCount: paged.length, itemBuilder: (context, index) {
          final sale = paged[index];
          final inv = (sale['invoice_number'] ?? '').toString();
          final checked = _selectedInvoices.contains(inv);
          return InkWell(onTap: () => _showInvoiceModal(context, sale['invoice_number'] ?? '-', sale), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1))), child: Row(children: [SizedBox(width: 40, child: Checkbox(value: checked, onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedInvoices.add(inv);
                  } else {
                    _selectedInvoices.remove(inv);
                  }
                });
              })), Expanded(flex: 1, child: Text(inv.isNotEmpty ? inv : '-', style: const TextStyle(fontWeight: FontWeight.w700))), Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(sale['customer_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)), Text(sale['customer_company'] ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))])), Expanded(flex: 2, child: Text(sale['product_name'] ?? '-', style: const TextStyle(fontSize: 13))), Expanded(flex: 1, child: Text(_formatCurrency(sale['final_price']), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFCB001D)))), Expanded(flex: 1, child: _buildReturnStatusCell(sale)), Expanded(flex: 1, child: Text(sale['date'] ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))), Expanded(flex: 1, child: Row(children: [IconButton(onPressed: () => _showInvoiceModal(context, sale['invoice_number'] ?? '-', sale), icon: const Icon(Icons.visibility_outlined, color: Colors.blue)), IconButton(onPressed: () => _deleteSale(sale), icon: const Icon(Icons.delete_outline, color: Colors.red))]))])));})),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [Text('صفحه ${_currentPage + 1} از ${totalPages == 0 ? 1 : totalPages}'), const SizedBox(width: 12), IconButton(onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null, icon: const Icon(Icons.chevron_left)), IconButton(onPressed: (_currentPage + 1) < totalPages ? () => setState(() => _currentPage++) : null, icon: const Icon(Icons.chevron_right)), const SizedBox(width: 12), DropdownButton<int>(value: _rowsPerPage, items: const [DropdownMenuItem(value: 5, child: Text('5')), DropdownMenuItem(value: 10, child: Text('10')), DropdownMenuItem(value: 20, child: Text('20')), DropdownMenuItem(value: 50, child: Text('50'))], onChanged: (v) => setState(() { _rowsPerPage = v ?? 10; _currentPage = 0; })),]),
          Row(children: [Text('انتخاب شده: ${_selectedInvoices.length}'), const SizedBox(width: 12), ElevatedButton(onPressed: _selectedInvoices.isEmpty ? null : () { /* placeholder for bulk actions */ }, child: const Text('عملیات جمعی'))])
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _sales.where((sale) {
      final search = _searchQuery.toLowerCase();
      final matchesSearch = (sale['invoice_number'] ?? '').toString().toLowerCase().contains(search) || (sale['customer_name'] ?? '').toString().toLowerCase().contains(search) || (sale['product_name'] ?? '').toString().toLowerCase().contains(search);
      final matchesFilter = _selectedFilter == 'همه' || (sale['sale_type'] ?? 'فروش') == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildHeader(), const SizedBox(height: 20), _buildQuickStats(), const SizedBox(height: 20), _buildFilterAndSearch(), const SizedBox(height: 16), Expanded(child: _buildSalesTable(filteredData))]),
      ),
    );
  }
}
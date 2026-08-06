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

class BackReturnedSalesPage extends StatefulWidget {
  const BackReturnedSalesPage({super.key});

  @override
  State<BackReturnedSalesPage> createState() => _BackReturnedSalesPageState();
}

class _BackReturnedSalesPageState extends State<BackReturnedSalesPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _returnedSales = [];
  String _searchQuery = '';
  int _currentPage = 0;
  int _rowsPerPage = 10;

  // Helper to check if unit is weight-based
  bool _isWeightUnit(String unit) {
    return unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg' || 
           unit == 'تن' || unit == 'ton' || unit == 'Ton';
  }

  // Convert weight to tons (1 ton = 1000 kg)
  double _convertToTons(String unit, double weight) {
    if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
      return weight / 1000; // Convert kg to tons
    } else if (unit == 'تن' || unit == 'ton' || unit == 'Ton') {
      return weight; // Already in tons
    }
    return weight; // Non-weight unit, return as is
  }

  // Format weight with conversion - ALWAYS shows in tons for weight units
  String _formatWeightWithConversion(String unit, double weight) {
    if (_isWeightUnit(unit)) {
      double tons = _convertToTons(unit, weight);
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} $unit';
  }

  // Get total tons of all returned sales
  double _getTotalTons() {
    double totalTons = 0;
    for (var sale in _returnedSales) {
      String unit = sale['unit']?.toString() ?? '';
      double weight = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
      
      if (_isWeightUnit(unit)) {
        totalTons += _convertToTons(unit, weight);
      }
    }
    return totalTons;
  }

  // Get count of returned sales
  int _getReturnedCount() {
    return _returnedSales.length;
  }

  // Get total value of returned sales
  double _getTotalValue() {
    double total = 0;
    for (var sale in _returnedSales) {
      total += double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allSales = await _db.getSalesInvoices();
      final returnedSales = allSales.where((sale) => (sale['is_back_returned'] ?? 0) == 1).toList();
      if (!mounted) return;
      setState(() {
        _allSales = allSales;
        _returnedSales = returnedSales;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar(l10n.errorLoadingReturnedSales, Colors.red);
    }
  }

 Future<void> _showAddReturnedSaleDialog() async {
  final l10n = AppLocalizations.of(context)!;
  final reasonController = TextEditingController();
  final dateController = TextEditingController(text: PersianDateConverter.getCurrentPersianDate());
  String selectedEnglishDate = PersianDateConverter.getEnglishDate(DateTime.now());
  Map<String, dynamic>? selectedSale;
  final availableSales = _allSales.where((sale) => (sale['is_back_returned'] ?? 0) != 1).toList();

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(l10n.addReturnedSale, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1A1A1A))),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedSale,
                      decoration: InputDecoration(labelText: l10n.selectSaleInvoice, border: const OutlineInputBorder()),
                      items: availableSales.map((sale) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: sale,
                          child: Text('${sale['invoice_number'] ?? '-'} | ${sale['customer_name'] ?? '-'} | ${sale['product_name'] ?? '-'}'),
                        );
                      }).toList(),
                      onChanged: (sale) {
                        setDialogState(() {
                          selectedSale = sale;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selectedSale != null) ...[
                      _buildReadOnlyField(l10n.invoiceNumberLabel, selectedSale!['invoice_number']?.toString() ?? '-', l10n),
                      const SizedBox(height: 12),
                      _buildReadOnlyField(l10n.customerName, selectedSale!['customer_name']?.toString() ?? '-', l10n),
                      const SizedBox(height: 12),
                      _buildReadOnlyField(l10n.company, selectedSale!['customer_company']?.toString() ?? '-', l10n),
                      const SizedBox(height: 12),
                      _buildReadOnlyField(l10n.productName, selectedSale!['product_name']?.toString() ?? '-', l10n),
                      const SizedBox(height: 12),
                      _buildReadOnlyField(
                        'وزن کل', 
                        _formatWeightWithConversion(
                          selectedSale!['unit']?.toString() ?? '',
                          double.tryParse(selectedSale!['total_weight']?.toString() ?? '0') ?? 0
                        ), 
                        l10n
                      ),
                      const SizedBox(height: 12),
                      _buildReadOnlyField(l10n.finalPrice, _formatCurrency(selectedSale!['final_price']), l10n),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.returnReason,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: l10n.returnDatePersian,
                        prefixIcon: const Icon(Icons.date_range_outlined, color: Color(0xFFCB001D)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            dateController.text = PersianDateConverter.gregorianToJalali(picked);
                            selectedEnglishDate = PersianDateConverter.getEnglishDate(picked);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: selectedSale == null || reasonController.text.trim().isEmpty
                    ? null
                    : () async {
                        // ===== RESTORE STOCK =====
                        // Get the product_id from the sale
                        final productId = selectedSale!['produced_product_id'];
                        final totalWeight = double.tryParse(selectedSale!['total_weight']?.toString() ?? '0') ?? 0;
                        final unit = selectedSale!['unit']?.toString() ?? '';
                        
                        if (productId != null && totalWeight > 0) {
                          final stockRestored = await _db.addProductStock(
                            productId,
                            totalWeight,
                            unit
                          );
                          if (!stockRestored) {
                            _showSnackbar('⚠️ خطا در بازگرداندن موجودی به انبار', Colors.orange);
                          } else {
                            _showSnackbar('✅ موجودی به انبار بازگردانده شد', Colors.green);
                          }
                        }
                        // ===== END RESTORE STOCK =====

                        final payload = {
                          'is_back_returned': 1,
                          'back_return_reason': reasonController.text.trim(),
                          'back_return_date': dateController.text.trim(),
                          'back_return_date_en': selectedEnglishDate,
                        };
                        final result = await _db.updateSalesInvoice(selectedSale!['id'], payload);
                        if (result == -1) {
                          _showSnackbar(l10n.errorSavingReturnedSale, Colors.red);
                          return;
                        }
                        await _loadData();
                        Navigator.pop(context);
                        _showSnackbar(l10n.returnedSaleSavedSuccess, Colors.green);
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white),
                child: Text(l10n.saveReturnedSale),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  Widget _buildReadOnlyField(String label, String value, AppLocalizations l10n) {
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _generatePdfReturnInvoice(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    // Get unit and format weights - ALL IN TONS
    String unit = invoice['unit']?.toString() ?? '';
    double weightRaw = double.tryParse(invoice['weight']?.toString() ?? '0') ?? 0;
    double weightPerUnitRaw = double.tryParse(invoice['weight_per_unit']?.toString() ?? '0') ?? 0;
    double totalWeightRaw = double.tryParse(invoice['total_weight']?.toString() ?? '0') ?? 0;
    
    String displayWeight = _formatWeightWithConversion(unit, weightRaw);
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
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(l10n.companyName, style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(l10n.returnReceipt, style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey700)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(6)),
                      child: pw.Text('RETURN', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('${l10n.invoiceNumberLabel}: $invoiceNumber', style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${l10n.returnDate}: ${invoice['back_return_date'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('Date (EN): ${invoice['back_return_date_en'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                  ]),
                ]),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Row(children: [
                    pw.Expanded(child: pw.Text('${l10n.customer}: ${invoice['customer_name'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    pw.Expanded(child: pw.Text('${l10n.company}: ${invoice['customer_company'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    pw.Expanded(child: pw.Text('${l10n.address}: ${invoice['customer_address'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                  ]),
                ),
                pw.SizedBox(height: 12),
                pw.Text('${l10n.returnReason}: ${invoice['back_return_reason'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                pw.SizedBox(height: 12),
                pw.Table.fromTextArray(
                  headers: [
                    l10n.customerName, l10n.company, l10n.productName, 
                    l10n.gender, l10n.size, 'وزن', 
                    'وزن فی خاده', 'تعداد خاده', 'وزن کل', 
                    l10n.finalPrice
                  ],
                  data: [
                    [
                      invoice['customer_name'] ?? '-',
                      invoice['customer_company'] ?? '-',
                      invoice['product_name'] ?? '-',
                      invoice['gender'] ?? '-',
                      invoice['size'] ?? '-',
                      displayWeight,  // Weight in TONS
                      displayWeightPerUnit,  // Weight per unit in TONS
                      invoice['unit_count']?.toString() ?? '-',
                      displayTotalWeight,  // Total weight in TONS
                      '${_formatCurrency(invoice['final_price'])} ${invoice['currency'] ?? ''}',
                    ],
                  ],
                  headerStyle: pw.TextStyle(font: ttf, fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 8),
                  cellAlignment: pw.Alignment.center,
                ),
                pw.Spacer(),
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

  String _formatCurrency(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '0') ?? 0;
    return number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.assignment_return_outlined, color: Color(0xFFCB001D), size: 28),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.returnedSales, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 4),
            Text(l10n.returnedSalesSubtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ]),
        ]),
        ElevatedButton.icon(
          onPressed: _showAddReturnedSaleDialog,
          icon: const Icon(Icons.add_circle_outline),
          label: Text(l10n.addReturnedSale),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
        ),
      ],
    );
  }

Widget _buildStatsCards(AppLocalizations l10n) {
  final totalTons = _getTotalTons();
  final totalCount = _getReturnedCount();
  
  // Calculate total value in AFN and USD
  double totalAFN = 0;
  double totalUSD = 0;
  
  for (var sale in _returnedSales) {
    double price = double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;
    String currency = sale['currency']?.toString() ?? 'USD';
    
    if (currency == 'USD') {
      totalUSD += price;
    } else if (currency == 'AFN') {
      totalAFN += price;
    }
  }

  return Row(
    children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCB001D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_return, color: Color(0xFFCB001D), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تعداد برگشتی‌ها',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalCount.toString(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.scale, color: Colors.green.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مجموع وزن (تن)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalTons.toStringAsFixed(totalTons % 1 == 0 ? 0 : 2)} تن',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.attach_money, color: Colors.blue.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مجموع ارزش',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (totalUSD > 0)
                          Text(
                            '${_formatCurrency(totalUSD)} USD',
                            style: const TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w800, 
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        if (totalAFN > 0)
                          Text(
                            '${_formatCurrency(totalAFN)} AFN',
                            style: const TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w800, 
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        if (totalUSD == 0 && totalAFN == 0)
                          Text(
                            '0',
                            style: const TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w800, 
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

  Widget _buildFilterAndSearch(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Row(children: [
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: l10n.searchReturnedSales,
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildReturnsTable(List<Map<String, dynamic>> data, AppLocalizations l10n) {
    final totalPages = (data.length / _rowsPerPage).ceil();
    final start = (_currentPage * _rowsPerPage).clamp(0, data.length);
    final paged = data.skip(start).take(_rowsPerPage).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFCB001D),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildHeaderCell('شماره', 80),
                  _buildHeaderCell('مشتری', 100),
                  _buildHeaderCell('شرکت', 100),
                  _buildHeaderCell('محصول', 90),
                  _buildHeaderCell('جنسیت', 60),
                  _buildHeaderCell('سایز', 60),
                  _buildHeaderCell('ضخامت', 60),
                  _buildHeaderCell('وزن', 70),
                  _buildHeaderCell('وزن فی', 70),
                  _buildHeaderCell('تعداد', 60),
                  _buildHeaderCell('وزن کل', 70),
                  _buildHeaderCell('قیمت واحد', 80),
                  _buildHeaderCell('قیمت کل', 80),
                  _buildHeaderCell('تخفیف', 60),
                  _buildHeaderCell('قیمت نهایی', 80),
                  _buildHeaderCell('تاریخ برگشت', 80),
                  _buildHeaderCell('دلیل برگشت', 90),
                  _buildHeaderCell('عملیات', 70),
                ],
              ),
            ),
          ),
          Expanded(
            child: paged.isEmpty
                ? Center(child: Text(l10n.noReturnedSales, style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: paged.length,
                    itemBuilder: (context, index) {
                      final sale = paged[index];
                      final isEven = index % 2 == 0;
                      
                      // Format weights - ALL IN TONS
                      String unit = sale['unit']?.toString() ?? '';
                      double weightRaw = double.tryParse(sale['weight']?.toString() ?? '0') ?? 0;
                      double weightPerUnitRaw = double.tryParse(sale['weight_per_unit']?.toString() ?? '0') ?? 0;
                      double totalWeightRaw = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
                      
                      String displayWeight = _formatWeightWithConversion(unit, weightRaw);
                      String displayWeightPerUnit = _formatWeightWithConversion(unit, weightPerUnitRaw);
                      String displayTotalWeight = _formatWeightWithConversion(unit, totalWeightRaw);
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isEven ? Colors.white : Colors.grey.shade50,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Invoice Number
                              _buildDataCell(
                                sale['invoice_number']?.toString() ?? '-',
                                80,
                                isBold: true,
                                color: const Color(0xFFCB001D),
                              ),
                              // Customer Name
                              _buildDataCell(
                                sale['customer_name']?.toString() ?? '-',
                                100,
                                isBold: true,
                              ),
                              // Company
                              _buildDataCell(
                                sale['customer_company']?.toString() ?? '-',
                                100,
                              ),
                              // Product Name
                              _buildDataCell(
                                sale['product_name']?.toString() ?? '-',
                                90,
                              ),
                              // Gender
                              _buildDataCell(
                                sale['gender']?.toString() ?? '-',
                                60,
                              ),
                              // Size
                              _buildDataCell(
                                sale['size']?.toString() ?? '-',
                                60,
                              ),
                              // Thickness
                              _buildDataCell(
                                sale['thickness']?.toString() ?? '-',
                                60,
                              ),
                              // Weight - in TONS
                              _buildDataCell(
                                displayWeight,
                                70,
                                isBold: true,
                                color: const Color(0xFFCB001D),
                              ),
                              // Weight Per Unit - in TONS
                              _buildDataCell(
                                displayWeightPerUnit,
                                70,
                              ),
                              // Unit Count
                              _buildDataCell(
                                sale['unit_count']?.toString() ?? '-',
                                60,
                              ),
                              // Total Weight - in TONS
                              _buildDataCell(
                                displayTotalWeight,
                                70,
                                isBold: true,
                                color: const Color(0xFFCB001D),
                              ),
                              // Unit Price
                              _buildDataCell(
                                _formatCurrency(sale['unit_price']),
                                80,
                              ),
                              // Total Price
                              _buildDataCell(
                                _formatCurrency(sale['total_price']),
                                80,
                              ),
                              // Discount
                              _buildDataCell(
                                _formatCurrency(sale['discount']),
                                60,
                              ),
                              // Final Price
                              _buildDataCell(
                                '${_formatCurrency(sale['final_price'])} ${sale['currency'] ?? ''}',
                                80,
                                isBold: true,
                                color: const Color(0xFFCB001D),
                              ),
                              // Return Date
                              _buildDataCell(
                                sale['back_return_date']?.toString() ?? '-',
                                80,
                              ),
                              // Return Reason
                              Container(
                                width: 90,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Text(
                                  sale['back_return_reason']?.toString() ?? '-',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // Actions
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _generatePdfReturnInvoice(sale, sale['invoice_number']?.toString() ?? '-', l10n),
                                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                                    tooltip: 'PDF',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  IconButton(
                                    onPressed: () => _showReturnDetailsDialog(sale, l10n),
                                    icon: const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                                    tooltip: 'Details',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Text('${l10n.page} ${_currentPage + 1} ${l10n.pageOf} ${totalPages == 0 ? 1 : totalPages}'),
                const SizedBox(width: 12),
                IconButton(onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null, icon: const Icon(Icons.chevron_left)),
                IconButton(onPressed: (_currentPage + 1) < totalPages ? () => setState(() => _currentPage++) : null, icon: const Icon(Icons.chevron_right)),
              ]),
              Row(children: [
                Text(l10n.rowsPerPage),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 20, child: Text('20')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (value) => setState(() {
                    _rowsPerPage = value ?? 10;
                    _currentPage = 0;
                  }),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {bool isBold = false, Color? color}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? const Color(0xFF1A1A2E),
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showReturnDetailsDialog(Map<String, dynamic> sale, AppLocalizations l10n) {
    // Format weights - ALL IN TONS
    String unit = sale['unit']?.toString() ?? '';
    double weightRaw = double.tryParse(sale['weight']?.toString() ?? '0') ?? 0;
    double weightPerUnitRaw = double.tryParse(sale['weight_per_unit']?.toString() ?? '0') ?? 0;
    double totalWeightRaw = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
    
    String displayWeight = _formatWeightWithConversion(unit, weightRaw);
    String displayWeightPerUnit = _formatWeightWithConversion(unit, weightPerUnitRaw);
    String displayTotalWeight = _formatWeightWithConversion(unit, totalWeightRaw);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment_return, color: Color(0xFFCB001D)),
            ),
            const SizedBox(width: 12),
            Text('${l10n.returnedSales} - ${sale['invoice_number'] ?? '-'}'),
          ],
        ),
        content: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('شماره بل', sale['invoice_number']?.toString() ?? '-'),
              _buildDetailRow(l10n.customerName, sale['customer_name'] ?? '-'),
              _buildDetailRow(l10n.company, sale['customer_company'] ?? '-'),
              _buildDetailRow(l10n.productName, sale['product_name'] ?? '-'),
              _buildDetailRow(l10n.gender, sale['gender'] ?? '-'),
              _buildDetailRow(l10n.size, sale['size'] ?? '-'),
              _buildDetailRow('ضخامت', sale['thickness'] ?? '-'),
              _buildDetailRow('وزن', displayWeight),
              _buildDetailRow('وزن فی خاده', displayWeightPerUnit),
              _buildDetailRow('تعداد خاده', sale['unit_count']?.toString() ?? '-'),
              _buildDetailRow('وزن کل', displayTotalWeight),
              _buildDetailRow('واحد', sale['unit']?.toString() ?? '-'),
              _buildDetailRow(l10n.finalPrice, '${_formatCurrency(sale['final_price'])} ${sale['currency'] ?? ''}'),
              _buildDetailRow(l10n.returnDate, sale['back_return_date']?.toString() ?? '-'),
              _buildDetailRow(l10n.returnReason, sale['back_return_reason']?.toString() ?? '-', isReason: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _generatePdfReturnInvoice(sale, sale['invoice_number']?.toString() ?? '-', l10n);
            },
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: Text(l10n.pdf),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isReason = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: isReason ? Colors.orange.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: isReason ? Border.all(color: Colors.orange.shade200) : null,
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  color: isReason ? Colors.orange.shade800 : Colors.black87,
                  fontWeight: isReason ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final filtered = _returnedSales.where((sale) {
      final search = _searchQuery.toLowerCase();
      return (sale['invoice_number']?.toString().toLowerCase().contains(search) ?? false) ||
          (sale['customer_name']?.toString().toLowerCase().contains(search) ?? false) ||
          (sale['product_name']?.toString().toLowerCase().contains(search) ?? false) ||
          (sale['customer_company']?.toString().toLowerCase().contains(search) ?? false) ||
          (sale['back_return_reason']?.toString().toLowerCase().contains(search) ?? false);
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
                  _buildStatsCards(l10n),
                  const SizedBox(height: 20),
                  _buildFilterAndSearch(l10n),
                  const SizedBox(height: 16),
                  Expanded(child: _buildReturnsTable(filtered, l10n)),
                ]),
        ),
      ),
    );
  }
}
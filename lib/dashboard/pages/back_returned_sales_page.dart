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
                          final updatedSale = await _db.getSalesInvoiceById(selectedSale!['id']);
                          if (updatedSale != null) {
                            _showReturnInvoiceModal(context, updatedSale['invoice_number']?.toString() ?? '-', updatedSale, l10n);
                          }
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

  void _showReturnInvoiceModal(BuildContext context, String invoiceNumber, Map<String, dynamic> invoice, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 900,
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
                  Row(children: [
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
                        Text(l10n.returnedSales, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                        const SizedBox(height: 2),
                        Text(l10n.returnInvoiceReceipt, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                      ],
                    ),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text('${l10n.invoiceNumberLabel}: $invoiceNumber', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB001D), fontSize: 12)),
                    ),
                    const SizedBox(height: 6),
                    Text('${l10n.returnDate}: ${invoice['back_return_date'] ?? '-'}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                    Text('Date (EN): ${invoice['back_return_date_en'] ?? '-'}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                  ]),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade200, width: 1)),
                child: Row(children: [
                  Expanded(child: Text('${l10n.customer}: ${invoice['customer_name'] ?? '-'}', style: const TextStyle(fontSize: 10))),
                  Expanded(child: Text('${l10n.company}: ${invoice['customer_company'] ?? '-'}', style: const TextStyle(fontSize: 10))),
                  Expanded(child: Text('${l10n.dischargeLocation}: ${invoice['customer_address'] ?? '-'}', style: const TextStyle(fontSize: 10))),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF1F8FF), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${l10n.returnReason}: ${invoice['back_return_reason'] ?? '-'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('${l10n.product}: ${invoice['product_name'] ?? '-'}', style: const TextStyle(fontSize: 10)),
                  Text('${l10n.finalPrice}: ${_formatCurrency(invoice['final_price'])} ${invoice['currency'] ?? ''}', style: const TextStyle(fontSize: 10)),
                ]),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, width: 1), borderRadius: BorderRadius.circular(4)),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      decoration: const BoxDecoration(color: Color(0xFFCB001D), borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                      child: Row(children: [
                        _buildInvoiceHeaderCell(l10n.customerName, 100),
                        _buildInvoiceHeaderCell(l10n.company, 80),
                        _buildInvoiceHeaderCell(l10n.productName, 100),
                        _buildInvoiceHeaderCell(l10n.gender, 80),
                        _buildInvoiceHeaderCell(l10n.size, 80),
                        _buildInvoiceHeaderCell(l10n.weight, 80),
                        _buildInvoiceHeaderCell(l10n.finalPrice, 100),
                      ]),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _buildInvoiceDataCell(invoice['customer_name'] ?? '-', 100),
                          _buildInvoiceDataCell(invoice['customer_company'] ?? '-', 80),
                          _buildInvoiceDataCell(invoice['product_name'] ?? '-', 100),
                          _buildInvoiceDataCell(invoice['gender'] ?? '-', 80),
                          _buildInvoiceDataCell(invoice['size'] ?? '-', 80),
                          _buildInvoiceDataCell(invoice['weight'] ?? '-', 80),
                          _buildInvoiceDataCell('${_formatCurrency(invoice['final_price'])} ${invoice['currency'] ?? ''}', 100, isBold: true, isRed: true),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close, style: const TextStyle(fontSize: 12))),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _generatePdfReturnInvoice(invoice, invoiceNumber, l10n);
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                  label: Text(l10n.pdf, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _generatePdfReturnInvoice(invoice, invoiceNumber, l10n);
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

  Future<void> _generatePdfReturnInvoice(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
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
                  headers: [l10n.customerName, l10n.company, l10n.productName, l10n.gender, l10n.size, l10n.weight, l10n.finalPrice],
                  data: [
                    [
                      invoice['customer_name'] ?? '-',
                      invoice['customer_company'] ?? '-',
                      invoice['product_name'] ?? '-',
                      invoice['gender'] ?? '-',
                      invoice['size'] ?? '-',
                      invoice['weight'] ?? '-',
                      '${_formatCurrency(invoice['final_price'])} ${invoice['currency'] ?? ''}',
                    ],
                  ],
                  headerStyle: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14))),
          child: Row(children: [
            Expanded(flex: 1, child: Text(l10n.invoiceNumberLabel)),
            Expanded(flex: 2, child: Text(l10n.customer)),
            Expanded(flex: 2, child: Text(l10n.productName)),
            Expanded(flex: 1, child: Text(l10n.finalPrice)),
            Expanded(flex: 1, child: Text(l10n.returnDate)),
            Expanded(flex: 1, child: Text(l10n.actions)),
          ]),
        ),
        Expanded(
          child: paged.isEmpty
              ? Center(child: Text(l10n.noReturnedSales, style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: paged.length,
                  itemBuilder: (context, index) {
                    final sale = paged[index];
                    return InkWell(
                      onTap: () => _showReturnInvoiceModal(context, sale['invoice_number']?.toString() ?? '-', sale, l10n),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1))),
                        child: Row(children: [
                          Expanded(flex: 1, child: Text(sale['invoice_number']?.toString() ?? '-')),
                          Expanded(flex: 2, child: Text(sale['customer_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700))),
                          Expanded(flex: 2, child: Text(sale['product_name']?.toString() ?? '-', style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 1, child: Text(_formatCurrency(sale['final_price']))),
                          Expanded(flex: 1, child: Text(sale['back_return_date']?.toString() ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                          Expanded(
                            flex: 1,
                            child: Row(children: [
                              IconButton(onPressed: () => _showReturnInvoiceModal(context, sale['invoice_number']?.toString() ?? '-', sale, l10n), icon: const Icon(Icons.visibility_outlined, color: Colors.blue)),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      ]),
    );
  }

  Widget _buildInvoiceHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 8), textAlign: TextAlign.center),
    );
  }

  Widget _buildInvoiceDataCell(String text, double width, {bool isBold = false, bool isRed = false}) {
    return SizedBox(
      width: width,
      child: Text(text, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isRed ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E), fontSize: 8), textAlign: TextAlign.center),
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
          (sale['product_name']?.toString().toLowerCase().contains(search) ?? false);
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
                  _buildFilterAndSearch(l10n),
                  const SizedBox(height: 16),
                  Expanded(child: _buildReturnsTable(filtered, l10n)),
                ]),
        ),
      ),
    );
  }
}
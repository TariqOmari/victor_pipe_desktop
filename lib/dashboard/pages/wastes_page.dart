import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';

class WastesPage extends StatefulWidget {
  const WastesPage({super.key});

  @override
  State<WastesPage> createState() => _WastesPageState();
}

class _WastesPageState extends State<WastesPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _wastes = [];
  int _currentPage = 0;
  int _rowsPerPage = 10;
  final Set<String> _selectedWastes = {};
  String _searchQuery = '';
  String _selectedFilter = 'همه';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWastes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWastes() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getWasteRecords();
      if (!mounted) return;
      setState(() {
        _wastes = list.map((item) => {
          'id': item['id'],
          'invoice_number': item['invoice_number'],
          'date': item['date'],
          'date_en': item['date_en'],
          'party_details': item['party_details'],
          'waste_type': item['waste_type'],
          'weight': item['weight'],
          'quantity': item['quantity'],
          'value': item['value'],
          'currency': item['currency'],
          'exchange_rate': item['exchange_rate'],
          'afn_equivalent': item['afn_equivalent'],
          'description': item['description'],
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('خطا در بارگذاری کسورات', Colors.red);
    }
  }

  Future<void> _showWasteDialog({Map<String, dynamic>? waste}) async {
    final dateController = TextEditingController(text: waste?['date']?.toString() ?? PersianDateConverter.getCurrentPersianDate());
    final partyDetailsController = TextEditingController(text: waste?['party_details']?.toString() ?? '');
    final wasteTypeController = TextEditingController(text: waste?['waste_type']?.toString() ?? '');
    final descriptionController = TextEditingController(text: waste?['description']?.toString() ?? '');
    final weightController = TextEditingController(text: waste?['weight']?.toString() ?? '');
    final quantityController = TextEditingController(text: waste?['quantity']?.toString() ?? '');
    final valueController = TextEditingController(text: waste?['value']?.toString() ?? '');
    final priceRateController = TextEditingController(text: waste?['exchange_rate']?.toString() ?? '0.011');
    final afnEquivalentController = TextEditingController(text: waste?['afn_equivalent']?.toString() ?? '');
    String selectedCurrency = waste?['currency']?.toString() ?? 'USD';
    String selectedEnglishDate = waste?['date_en']?.toString() ?? PersianDateConverter.getEnglishDate(DateTime.now());

    void updateTotals() {
      final value = double.tryParse(valueController.text) ?? 0;
      final rate = double.tryParse(priceRateController.text) ?? 1;
      if (selectedCurrency == 'AFN') {
        afnEquivalentController.text = value > 0 && rate > 0 ? (value / rate).toStringAsFixed(0) : '';
      } else {
        afnEquivalentController.text = value > 0 && rate > 0 ? (value * rate).toStringAsFixed(0) : '';
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                waste == null ? 'ثبت کسورات جدید' : 'ویرایش کسورات',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: dateController,
                        label: 'تاریخ',
                        icon: Icons.calendar_today_outlined,
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
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(controller: partyDetailsController, label: 'مشخصات طرف / شرکت', icon: Icons.business_outlined),
                      const SizedBox(height: 12),
                      _buildTextField(controller: wasteTypeController, label: 'نوع کسورات', icon: Icons.category_outlined),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: weightController, label: 'وزن', icon: Icons.scale_outlined, keyboardType: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: quantityController, label: 'تعداد', icon: Icons.numbers_outlined, keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: valueController, label: 'ارزش مالی', icon: Icons.attach_money_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: priceRateController, label: 'نرخ اسعار (از سیستم یا ورود دستی)', icon: Icons.currency_exchange, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: afnEquivalentController, label: selectedCurrency == 'AFN' ? 'معادل به دالر' : 'معادل به افغانی', icon: Icons.currency_exchange, readOnly: true)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCurrency,
                              decoration: const InputDecoration(
                                labelText: 'واحد پول',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.request_quote_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'USD', child: Text('دلار')),
                                DropdownMenuItem(value: 'AFN', child: Text('افغانی')),
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(controller: descriptionController, label: 'تفصیل', icon: Icons.description_outlined, maxLines: 3),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف', style: TextStyle(color: Colors.grey))),
                ElevatedButton.icon(
                  onPressed: () async {
                    final payload = {
                      'invoice_number': waste?['invoice_number']?.toString() ?? '',
                      'date': dateController.text.trim(),
                      'date_en': selectedEnglishDate,
                      'party_details': partyDetailsController.text.trim(),
                      'waste_type': wasteTypeController.text.trim(),
                      'weight': double.tryParse(weightController.text) ?? 0,
                      'quantity': double.tryParse(quantityController.text) ?? 0,
                      'value': double.tryParse(valueController.text) ?? 0,
                      'currency': selectedCurrency,
                      'exchange_rate': double.tryParse(priceRateController.text) ?? 0.011,
                      'description': descriptionController.text.trim(),
                      'afn_equivalent': double.tryParse(afnEquivalentController.text) ?? 0,
                    };

                    try {
                      if (waste == null) {
                        await _db.insertWasteRecord(payload);
                      } else {
                        await _db.updateWasteRecord(waste['id'], payload);
                      }
                      if (!mounted) return;
                      Navigator.pop(context);
                      await _loadWastes();
                      _showSnackbar(waste == null ? 'کسورات با موفقیت ثبت شد' : 'کسورات با موفقیت ویرایش شد', Colors.green);
                    } catch (e) {
                      if (!mounted) return;
                      _showSnackbar('خطا در ذخیره‌سازی کسورات', Colors.red);
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(waste == null ? 'ثبت کسورات' : 'ذخیره تغییرات'),
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

  Future<void> _deleteWaste(Map<String, dynamic> waste) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف کسورات'),
        content: Text('آیا از حذف این مورد مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), child: const Text('حذف')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.deleteWasteRecord(waste['id']);
      await _loadWastes();
      _showSnackbar('مورد حذف شد', Colors.orange);
    } catch (e) {
      _showSnackbar('خطا در حذف مورد', Colors.red);
    }
  }

  // ==================== PDF & PRINT FUNCTIONS ====================

  Future<void> _printWasteInvoice(Map<String, dynamic> waste) async {
    try {
      final pdf = await _generateWastePDF(waste);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
        name: 'فاکتور_کسورات_${waste['id']}',
      );
    } catch (e) {
      _showSnackbar('خطا در چاپ فاکتور: $e', Colors.red);
    }
  }

  Future<Uint8List> _generateWastePDF(Map<String, dynamic> waste) async {
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
                // Header
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
                          child: pw.Text('Waste Invoice', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text('شماره: ${waste['invoice_number'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('تاریخ (شمسی): ${waste['date'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('Date (EN): ${waste['date_en'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                      ]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Party Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(children: [
                    pw.Expanded(child: pw.Text('طرف / شرکت: ${waste['party_details'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    pw.Expanded(child: pw.Text('نوع کسورات: ${waste['waste_type'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                  ]),
                ),
                pw.SizedBox(height: 16),

                // Waste Details Table
                pw.Table.fromTextArray(
                  headers: ['شرح', 'مقدار'],
                  data: [
                    ['وزن', '${_formatNumber(waste['weight'])} کیلوگرم'],
                    ['تعداد', _formatNumber(waste['quantity'])],
                    ['ارزش مالی', '${_formatNumber(waste['value'])} ${waste['currency'] ?? 'USD'}'],
                    ['نرخ ارز', _formatNumber(waste['exchange_rate'])],
                    ['معادل افغانی', '${_formatNumber(waste['afn_equivalent'])} AFN'],
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

                // Description
                if (waste['description'] != null && waste['description'].toString().isNotEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Text('تفصیل: ${waste['description']}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                  ),
                pw.Spacer(),

                // Footer
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('امضا: ______________________', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('تاریخ چاپ: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                ]),
                pw.Center(
                  child: pw.Text('ویکتور پایپ صنعت - سامانه مدیریت یکپارچه', style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey500)),
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

  Widget _buildHeader() {
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
              child: const Icon(Icons.delete_outline, color: Color(0xFFCB001D), size: 28),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مدیریت کسورات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                Text('ثبت، ذخیره و مدیریت کسورات و اتلافات', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showWasteDialog(),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('ثبت کسورات جدید'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCB001D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final totalWastes = _wastes.length;
    final totalValue = _wastes.fold<double>(0, (sum, item) => sum + (double.tryParse(item['value']?.toString() ?? '0') ?? 0));
    final totalAfn = _wastes.fold<double>(0, (sum, item) => sum + (double.tryParse(item['afn_equivalent']?.toString() ?? '0') ?? 0));
    
    return Row(
      children: [
        _buildStatCard('تعداد کسورات', totalWastes.toString(), Icons.delete_outline, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard('جمع ارزش مالی', _formatNumber(totalValue), Icons.attach_money_outlined, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard('جمع معادل افغانی', _formatNumber(totalAfn), Icons.currency_exchange, Colors.green.shade700),
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
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
          ])),
        ]),
      ),
    );
  }

  Widget _buildFilterAndSearch() {
    final filters = ['همه', 'کسورات'];
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
              hintText: 'جستجو بر اساس طرف، نوع کسورات یا شماره...',
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

  Widget _buildWastesTable(List<Map<String, dynamic>> data) {
    final totalPages = (data.length / _rowsPerPage).ceil();
    final start = (_currentPage * _rowsPerPage).clamp(0, data.length);
    final paged = data.skip(start).take(_rowsPerPage).toList();
    final allSelectedOnPage = paged.isNotEmpty && paged.every((s) => _selectedWastes.contains((s['id'] ?? '').toString()));

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
                              final id = (s['id'] ?? '').toString();
                              if (id.isNotEmpty) _selectedWastes.add(id);
                            }
                          } else {
                            for (final s in paged) {
                              final id = (s['id'] ?? '').toString();
                              _selectedWastes.remove(id);
                            }
                          }
                        });
                      },
                    ),
                  ),
                  _buildHeaderCell('شماره', 70),
                  _buildHeaderCell('تاریخ', 100),
                  _buildHeaderCell('طرف / شرکت', 130),
                  _buildHeaderCell('نوع کسورات', 120),
                  _buildHeaderCell('وزن', 80),
                  _buildHeaderCell('تعداد', 80),
                  _buildHeaderCell('ارزش مالی', 90),
                  _buildHeaderCell('ارز', 60),
                  _buildHeaderCell('نرخ ارز', 80),
                  _buildHeaderCell('معادل افغانی', 100),
                  _buildHeaderCell('تفصیل', 150),
                  _buildHeaderCell('عملیات', 140),
                ],
              ),
            ),
          ),
          // Data Rows
          Expanded(
            child: paged.isEmpty
                ? const Center(child: Text('هیچ موردی ثبت نشده است', style: TextStyle(color: Colors.grey)))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: paged.map((waste) {
                          final id = (waste['id'] ?? '').toString();
                          final checked = _selectedWastes.contains(id);
                          return InkWell(
                            onTap: () => _printWasteInvoice(waste),
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
                                            _selectedWastes.add(id);
                                          } else {
                                            _selectedWastes.remove(id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  _buildDataCell(waste['invoice_number']?.toString() ?? '-', 70, isBold: true),
                                  _buildDataCell(waste['date']?.toString() ?? '-', 100),
                                  _buildDataCell(waste['party_details']?.toString() ?? '-', 130),
                                  _buildDataCell(waste['waste_type']?.toString() ?? '-', 120),
                                  _buildDataCell(_formatNumber(waste['weight']), 80),
                                  _buildDataCell(_formatNumber(waste['quantity']), 80),
                                  _buildDataCell(_formatNumber(waste['value']), 90, isBold: true, color: const Color(0xFFCB001D)),
                                  _buildDataCell(waste['currency']?.toString() ?? '-', 60),
                                  _buildDataCell(_formatNumber(waste['exchange_rate']), 80),
                                  _buildDataCell(_formatNumber(waste['afn_equivalent']), 100),
                                  _buildDataCell(waste['description']?.toString() ?? '-', 150),
                                  SizedBox(
                                    width: 140,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          onPressed: () => _showWasteDialog(waste: waste),
                                          icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                          padding: EdgeInsets.zero,
                                        ),
                                        IconButton(
                                          onPressed: () => _deleteWaste(waste),
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                          padding: EdgeInsets.zero,
                                        ),
                                        IconButton(
                                          onPressed: () => _printWasteInvoice(waste),
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
                  Text('صفحه ${_currentPage + 1} از ${totalPages == 0 ? 1 : totalPages}'),
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
                  Text('انتخاب شده: ${_selectedWastes.length}'),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedWastes.isEmpty ? null : () {
                      // Bulk actions placeholder
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCB001D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('عملیات جمعی'),
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
      inputFormatters: keyboardType == TextInputType.number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))] : null,
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
      onTap: onTap,
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
    final filteredData = _wastes.where((waste) {
      final search = _searchQuery.toLowerCase();
      final matchesSearch = (waste['party_details'] ?? '').toString().toLowerCase().contains(search) ||
          (waste['waste_type'] ?? '').toString().toLowerCase().contains(search) ||
          (waste['invoice_number'] ?? '').toString().toLowerCase().contains(search) ||
          (waste['description'] ?? '').toString().toLowerCase().contains(search);
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildQuickStats(),
                const SizedBox(height: 20),
                _buildFilterAndSearch(),
                const SizedBox(height: 16),
                Expanded(child: _buildWastesTable(filteredData)),
              ]),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';

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
      _showSnackbar('خطا در بارگذاری خدمات', Colors.red);
    }
  }

  Future<void> _showServiceDialog({Map<String, dynamic>? service}) async {
    final customerNameController = TextEditingController(text: service?['customer_name']?.toString() ?? '');
    final serviceTypeController = TextEditingController(text: service?['service_type']?.toString() ?? '');
    final basePriceController = TextEditingController(text: service?['price']?.toString() ?? '');
    final exchangeRateController = TextEditingController(text: service?['exchange_rate']?.toString() ?? '85');
    final loadingController = TextEditingController(text: service?['loading_cost']?.toString() ?? '');
    final transferController = TextEditingController(text: service?['transfer_cost']?.toString() ?? '');
    final clearanceController = TextEditingController(text: service?['clearance_cost']?.toString() ?? '');
    final discountController = TextEditingController(text: service?['discount']?.toString() ?? '');
    final finalPriceController = TextEditingController(text: service?['final_price']?.toString() ?? '');
    final afnEquivalentController = TextEditingController(text: service?['afn_equivalent']?.toString() ?? '');
    final dateController = TextEditingController(text: service?['date']?.toString() ?? PersianDateConverter.getCurrentPersianDate());
    String selectedEnglishDate = service?['date_en']?.toString() ?? PersianDateConverter.getEnglishDate(DateTime.now());
    String selectedCurrency = service?['currency']?.toString() ?? 'USD';

    void updateTotals() {
      final basePrice = double.tryParse(basePriceController.text) ?? 0;
      final exchangeRate = double.tryParse(exchangeRateController.text) ?? 1;
      final loadingCost = double.tryParse(loadingController.text) ?? 0;
      final transferCost = double.tryParse(transferController.text) ?? 0;
      final clearanceCost = double.tryParse(clearanceController.text) ?? 0;
      final discount = double.tryParse(discountController.text) ?? 0;
      final finalPrice = basePrice + loadingCost + transferCost + clearanceCost - discount;
      finalPriceController.text = finalPrice > 0 ? finalPrice.toStringAsFixed(0) : '';
      if (selectedCurrency == 'AFN') {
        afnEquivalentController.text = basePrice > 0 ? basePrice.toStringAsFixed(0) : '';
      } else {
        afnEquivalentController.text = basePrice > 0 ? (basePrice * (exchangeRate <= 0 ? 1 : exchangeRate)).toStringAsFixed(0) : '';
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
                service == null ? 'ثبت خدمت جدید' : 'ویرایش خدمت',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(controller: customerNameController, label: 'ثبت مشخصات بل', icon: Icons.person_outline),
                      const SizedBox(height: 12),
                      _buildTextField(controller: serviceTypeController, label: 'نوع خدمات', icon: Icons.design_services_outlined),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: basePriceController, label: 'نرخ اسعار (از سیستم یا ورود دستی)', icon: Icons.attach_money_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCurrency,
                              decoration: const InputDecoration(labelText: 'ارز', border: OutlineInputBorder()),
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
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: exchangeRateController, label: 'نرخ ارز', icon: Icons.currency_exchange, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: afnEquivalentController, label: 'معادل افغانی', icon: Icons.currency_exchange, readOnly: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: loadingController, label: 'اجرت بارگیری', icon: Icons.local_shipping_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: transferController, label: 'کرایه انتقال', icon: Icons.drive_eta_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: clearanceController, label: 'اجرت تخلیه', icon: Icons.inventory_2_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: discountController, label: 'تخفیف', icon: Icons.discount_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: finalPriceController, label: 'قیمت نهایی', icon: Icons.receipt_long_outlined, readOnly: true)),
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
                                child: _buildTextField(controller: dateController, label: 'تاریخ', icon: Icons.calendar_today_outlined, readOnly: true),
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف', style: TextStyle(color: Colors.grey))),
                ElevatedButton.icon(
                  onPressed: () async {
                    final payload = {
                      'customer_name': customerNameController.text.trim(),
                      'service_type': serviceTypeController.text.trim(),
                      'price': double.tryParse(basePriceController.text) ?? 0,
                      'currency': selectedCurrency,
                      'exchange_rate': double.tryParse(exchangeRateController.text) ?? 1,
                      'loading_cost': double.tryParse(loadingController.text) ?? 0,
                      'transfer_cost': double.tryParse(transferController.text) ?? 0,
                      'clearance_cost': double.tryParse(clearanceController.text) ?? 0,
                      'discount': double.tryParse(discountController.text) ?? 0,
                      'final_price': double.tryParse(finalPriceController.text) ?? 0,
                      'afn_equivalent': double.tryParse(afnEquivalentController.text) ?? 0,
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
                      _showSnackbar(service == null ? 'خدمت با موفقیت ثبت شد' : 'خدمت با موفقیت ویرایش شد', Colors.green);
                    } catch (e) {
                      if (!mounted) return;
                      _showSnackbar('خطا در ذخیره‌سازی خدمت', Colors.red);
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(service == null ? 'ثبت خدمت' : 'ذخیره تغییرات'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف خدمت'),
        content: Text('آیا از حذف خدمت "${service['customer_name'] ?? '-'}" مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), child: const Text('حذف')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.deleteServiceInvoice(service['id']);
      await _loadServices();
      _showSnackbar('خدمت حذف شد', Colors.orange);
    } catch (e) {
      _showSnackbar('خطا در حذف خدمت', Colors.red);
    }
  }

  // ==================== PDF & PRINT FUNCTIONS ====================

  Future<void> _printServiceInvoice(Map<String, dynamic> service) async {
    try {
      final pdf = await _generateServicePDF(service);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
        name: 'فاکتور_خدمات_${service['id']}',
      );
    } catch (e) {
      _showSnackbar('خطا در چاپ فاکتور: $e', Colors.red);
    }
  }

  Future<Uint8List> _generateServicePDF(Map<String, dynamic> service) async {
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
                          child: pw.Text('Service Invoice', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text('شماره: ${service['id'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('تاریخ (شمسی): ${service['date'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('Date (EN): ${service['date_en'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                      ]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Customer Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(children: [
                    pw.Expanded(child: pw.Text('نام مشتری: ${service['customer_name'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    pw.Expanded(child: pw.Text('نوع خدمت: ${service['service_type'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                  ]),
                ),
                pw.SizedBox(height: 16),

                // Service Details Table
                pw.Table.fromTextArray(
                  headers: ['شرح', 'مبلغ'],
                  data: [
                    ['قیمت پایه', '${_formatNumber(service['price'])} ${service['currency'] ?? 'USD'}'],
                    ['اجرت بارگیری', '${_formatNumber(service['loading_cost'])} ${service['currency'] ?? 'USD'}'],
                    ['کرایه انتقال', '${_formatNumber(service['transfer_cost'])} ${service['currency'] ?? 'USD'}'],
                    ['اجرت تخلیه', '${_formatNumber(service['clearance_cost'])} ${service['currency'] ?? 'USD'}'],
                    ['تخفیف', '-${_formatNumber(service['discount'])} ${service['currency'] ?? 'USD'}'],
                    ['قیمت نهایی', '${_formatNumber(service['final_price'])} ${service['currency'] ?? 'USD'}'],
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

                // Currency Info
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
                      pw.Text('ارز: ${service['currency'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      pw.Text('نرخ ارز: ${service['exchange_rate'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      pw.Text('معادل افغانی: ${_formatNumber(service['afn_equivalent'])} AFN', style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
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
              child: const Icon(Icons.design_services, color: Color(0xFFCB001D), size: 28),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مدیریت خدمات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                Text('ثبت، ذخیره و مدیریت فاکتورهای خدمات', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showServiceDialog(),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('ثبت خدمت جدید'),
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
    final totalServices = _services.length;
    final totalRevenue = _services.fold<double>(0, (sum, item) => sum + (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0));
    
    return Row(
      children: [
        _buildStatCard('جمع درآمد', _formatNumber(totalRevenue), Icons.attach_money_outlined, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard('تعداد خدمات', totalServices.toString(), Icons.design_services_outlined, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard('ارز USD', _formatNumber(_services.fold<double>(0, (sum, item) => sum + ((item['currency'] == 'USD' ? (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0) : 0)))), Icons.currency_exchange, Colors.green.shade700),
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
    final filters = ['همه', 'خدمات'];
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
              hintText: 'جستجو بر اساس مشتری یا نوع خدمت...',
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

  Widget _buildServicesTable(List<Map<String, dynamic>> data) {
    final totalPages = (data.length / _rowsPerPage).ceil();
    final start = (_currentPage * _rowsPerPage).clamp(0, data.length);
    final paged = data.skip(start).take(_rowsPerPage).toList();
    final allSelectedOnPage = paged.isNotEmpty && paged.every((s) => _selectedServices.contains((s['id'] ?? '').toString()));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header Row - با اسکرول افقی
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
                  // چک‌باکس
                  SizedBox(
                    width: 50,
                    child: Checkbox(
                      value: allSelectedOnPage,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            for (final s in paged) {
                              final id = (s['id'] ?? '').toString();
                              if (id.isNotEmpty) _selectedServices.add(id);
                            }
                          } else {
                            for (final s in paged) {
                              final id = (s['id'] ?? '').toString();
                              _selectedServices.remove(id);
                            }
                          }
                        });
                      },
                    ),
                  ),
                  // ستون‌های جدول
                  _buildHeaderCell('شماره', 70),
                  _buildHeaderCell('مشتری', 130),
                  _buildHeaderCell('نوع خدمت', 130),
                  _buildHeaderCell('قیمت پایه', 90),
                  _buildHeaderCell('بارگیری', 80),
                  _buildHeaderCell('انتقال', 80),
                  _buildHeaderCell('تخلیه', 80),
                  _buildHeaderCell('تخفیف', 80),
                  _buildHeaderCell('قیمت نهایی', 100),
                  _buildHeaderCell('ارز', 60),
                  _buildHeaderCell('نرخ ارز', 80),
                  _buildHeaderCell('معادل افغانی', 100),
                  _buildHeaderCell('تاریخ', 100),
                  _buildHeaderCell('عملیات', 140),
                ],
              ),
            ),
          ),
          // Data Rows - با اسکرول عمودی و افقی
          Expanded(
            child: paged.isEmpty
                ? const Center(child: Text('هیچ خدمتی ثبت نشده است', style: TextStyle(color: Colors.grey)))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: paged.map((service) {
                          final id = (service['id'] ?? '').toString();
                          final checked = _selectedServices.contains(id);
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
                                  // چک‌باکس
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
                                  // داده‌های هر ستون
                                  _buildDataCell(service['id']?.toString() ?? '-', 70, isBold: true),
                                  _buildDataCell(service['customer_name'] ?? '-', 130, isBold: true),
                                  _buildDataCell(service['service_type'] ?? '-', 130),
                                  _buildDataCell(_formatNumber(service['price']), 90),
                                  _buildDataCell(_formatNumber(service['loading_cost']), 80),
                                  _buildDataCell(_formatNumber(service['transfer_cost']), 80),
                                  _buildDataCell(_formatNumber(service['clearance_cost']), 80),
                                  _buildDataCell(_formatNumber(service['discount']), 80, color: Colors.red),
                                  _buildDataCell(_formatNumber(service['final_price']), 100, isBold: true, color: const Color(0xFFCB001D)),
                                  _buildDataCell(service['currency'] ?? '-', 60),
                                  _buildDataCell(_formatNumber(service['exchange_rate']), 80),
                                  _buildDataCell(_formatNumber(service['afn_equivalent']), 100),
                                  _buildDataCell(service['date'] ?? '-', 100),
                                  // عملیات
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
                  Text('انتخاب شده: ${_selectedServices.length}'),
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
    final filteredData = _services.where((service) {
      final search = _searchQuery.toLowerCase();
      final matchesSearch = (service['customer_name'] ?? '').toString().toLowerCase().contains(search) ||
          (service['service_type'] ?? '').toString().toLowerCase().contains(search) ||
          (service['id'] ?? '').toString().toLowerCase().contains(search);
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
                Expanded(child: _buildServicesTable(filteredData)),
              ]),
      ),
    );
  }
}
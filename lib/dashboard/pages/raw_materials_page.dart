import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';

class RawMaterialsPage extends StatefulWidget {
  const RawMaterialsPage({super.key});

  @override
  State<RawMaterialsPage> createState() => _RawMaterialsPageState();
}

class _RawMaterialsPageState extends State<RawMaterialsPage> {
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> invoices = [];
  bool isLoading = true;
  final DatabaseHelper _db = DatabaseHelper();

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50, 100];

  // Selection
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final materialsData = await _db.getRawMaterials();
      final suppliersData = await _db.getSuppliers();
      final invoicesData = await _db.getInvoices();
      setState(() {
        materials = materialsData;
        suppliers = suppliersData;
        invoices = invoicesData;
        isLoading = false;
        _selectedIds.clear();
        _currentPage = 1;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
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

  void _toggleSelectAll() {
    setState(() {
      final currentIds = _paginatedMaterials.map((m) => m['id'] as int).toList();
      final allSelected = currentIds.every((id) => _selectedIds.contains(id));
      if (allSelected) {
        _selectedIds.removeAll(currentIds);
      } else {
        _selectedIds.addAll(currentIds);
      }
    });
  }

  // ============ BUILD UNIT CARDS ============
  List<Widget> _buildUnitCards() {
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
          child: const Text(
            'هیچ ماده خامی در انبار نیست',
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
                      Icons.scale,
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
                    'خالص:',
                    style: TextStyle(
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
                  const Text(
                    'ناخالص:',
                    style: TextStyle(
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

  // ============ GENERATE INVOICE ============
  Future<void> _generateInvoice(Map<String, dynamic> material) async {
    try {
      final random = DateTime.now().millisecondsSinceEpoch % 100000;
      final invoiceNumber = random.toString().padLeft(5, '0');
      
      final supplier = suppliers.firstWhere(
        (s) => s['id'] == material['supplier_id'],
        orElse: () => {},
      );
      
      final invoiceData = {
        'invoice_number': invoiceNumber,
        'supplier_id': material['supplier_id'],
        'supplier_name': supplier['name'] ?? '',
        'date': material['date'] ?? DateTime.now().toString().split(' ')[0],
        'location': material['location'] ?? '',
        'name': material['name'] ?? '',
        'material_type': material['material_type'] ?? '',
        'thickness': material['thickness'] ?? '',
        'net_weight': double.tryParse(material['net_weight']?.toString() ?? '0') ?? 0,
        'gross_weight': double.tryParse(material['gross_weight']?.toString() ?? '0') ?? 0,
        'unit': material['unit'] ?? '',
        'unit_price': double.tryParse(material['unit_price']?.toString() ?? '0') ?? 0,
        'product': double.tryParse(material['product']?.toString() ?? '0') ?? 0,
        'commission': double.tryParse(material['commission']?.toString() ?? '0') ?? 0,
        'transfer_cost': double.tryParse(material['transfer_cost']?.toString() ?? '0') ?? 0,
        'miscellaneous': double.tryParse(material['miscellaneous']?.toString() ?? '0') ?? 0,
        'ghurfedari': double.tryParse(material['ghurfedari']?.toString() ?? '0') ?? 0,
        'barchalani': double.tryParse(material['barchalani']?.toString() ?? '0') ?? 0,
        'final_price': double.tryParse(material['final_price']?.toString() ?? '0') ?? 0,
        'material_id': material['id'],
      };
      
      final result = await _db.insertInvoice(invoiceData);
      
      if (result != -1) {
        await _db.updateRawMaterial(material['id'], {
          ...material,
          'invoice_id': result,
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ فاکتور با موفقیت ایجاد شد'),
            backgroundColor: Colors.green,
          ),
        );
        
        _showInvoiceModal(context, invoiceNumber, invoiceData, supplier);
        _loadData();
      }
    } catch (e) {
      print('❌ Invoice error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطا در ایجاد فاکتور: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============ GENERATE PDF WITH PERSIAN SUPPORT ============
 // ============ GENERATE PDF WITH PERSIAN SUPPORT ============
// ============ GENERATE PDF WITH ALL FIELDS ============
// ============ GENERATE PDF WITH ALL FIELDS (TABLE ONLY) ============
Future<void> _generatePDFInvoice(Map<String, dynamic> invoice, String invoiceNumber) async {
  try {
    // ============ LOAD VAZIR FONT FOR PDF ============
    final ByteData fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
    final Uint8List fontBytes = fontData.buffer.asUint8List();
    final pw.Font vazirFont = pw.Font.ttf(fontBytes.buffer.asByteData());
    
    final pdf = pw.Document();
    
    // Load company logo
    final ByteData logoData = await rootBundle.load('assets/images/companylogo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with Logo
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Image(
                          pw.MemoryImage(logoBytes),
                          width: 60,
                          height: 60,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'ویکتور پایپ صنعت',
                          style: pw.TextStyle(
                            font: vazirFont,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red,
                          ),
                        ),
                        pw.Text(
                          'سامانه مدیریت یکپارچه',
                          style: pw.TextStyle(
                            font: vazirFont,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Invoice',
                          style: pw.TextStyle(
                            font: vazirFont,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'شماره: $invoiceNumber',
                          style: pw.TextStyle(
                            font: vazirFont,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'تاریخ: ${invoice['date'] ?? '-'}',
                          style: pw.TextStyle(
                            font: vazirFont,
                            fontSize: 11,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 2, color: PdfColors.red),

                // Supplier Info
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'فروشنده: ${invoice['supplier_name'] ?? '-'}',
                          style: pw.TextStyle(font: vazirFont),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          'محل تخلیه: ${invoice['location'] ?? '-'}',
                          style: pw.TextStyle(font: vazirFont),
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // ============ TABLE HEADER WITH ALL FIELDS (RED) ============
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 2, child: pw.Text('نام مواد', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8))),
                      pw.Expanded(flex: 1, child: pw.Text('نوع', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('واحد', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('ضخامت', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('وزن خالص', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('وزن ناخالص', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('قیمت واحد', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('محصول', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('کمیشن', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('کرایه', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('متفرقه', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('غرفه داری', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('بارچلانی', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('قیمت نهایی', style: pw.TextStyle(font: vazirFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8), textAlign: pw.TextAlign.center)),
                    ],
                  ),
                ),

                // ============ TABLE ROW WITH ALL FIELDS ============
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 2, child: pw.Text(invoice['name'] ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8))),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['material_type'] ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['unit'] ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['thickness'] ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['net_weight']?.toString() ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['gross_weight']?.toString() ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['unit_price']?.toString() ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['product']?.toString() ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['commission']?.toString() ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['transfer_cost']?.toString() ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['miscellaneous']?.toString() ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['ghurfedari']?.toString() ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(invoice['barchalani']?.toString() ?? '-', style: pw.TextStyle(font: vazirFont, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(
                        '${invoice['final_price'] ?? 0}',
                        style: pw.TextStyle(
                          font: vazirFont,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                          color: PdfColors.red,
                        ),
                        textAlign: pw.TextAlign.center,
                      )),
                    ],
                  ),
                ),

                pw.SizedBox(height: 16),

                // Footer
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('امضا: _________________', style: pw.TextStyle(font: vazirFont, fontSize: 10)),
                    pw.Text(
                      'تاریخ چاپ: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}',
                      style: pw.TextStyle(font: vazirFont, fontSize: 9, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'ویکتور پایپ صنعت - سامانه مدیریت یکپارچه',
                    style: pw.TextStyle(font: vazirFont, fontSize: 8, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Print or save PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'invoice_$invoiceNumber.pdf',
    );
  } catch (e) {
    print('PDF Error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ خطا در ایجاد PDF: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  // ============ SHOW INVOICE MODAL ============
  void _showInvoiceModal(BuildContext context, String invoiceNumber, Map<String, dynamic> invoice, Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 900,
          constraints: const BoxConstraints(maxHeight: 650),
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
              // Header
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
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Text(
                                  'VP',
                                  style: TextStyle(
                                    color: Color(0xFFCB001D),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            },
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
                        child: Text('Invoice', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('شماره: $invoiceNumber', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB001D), fontSize: 12)),
                      ),
                      Text('تاریخ: ${invoice['date'] ?? '-'}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                    ],
                  ),
                ],
              ),
              
              Container(height: 2, margin: const EdgeInsets.symmetric(vertical: 8), color: const Color(0xFFCB001D)),
              
              // Supplier Info
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.business, color: Color(0xFFCB001D), size: 14),
                          const SizedBox(width: 4),
                          const Text('فروشنده:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              invoice['supplier_name'] ?? '-',
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFCB001D), size: 14),
                          const SizedBox(width: 4),
                          const Text('محل تخلیه:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              invoice['location'] ?? '-',
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Table
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFCB001D),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTH('نام مواد', 80),
                              _buildTH('نوع', 50),
                              _buildTH('واحد', 45),
                              _buildTH('ضخامت', 45),
                              _buildTH('وزن خالص', 60),
                              _buildTH('وزن ناخالص', 60),
                              _buildTH('قیمت واحد', 60),
                              _buildTH('محصول', 50),
                              _buildTH('کمیشن', 50),
                              _buildTH('کرایه', 50),
                              _buildTH('متفرقه', 50),
                              _buildTH('غرفه داری', 50),
                              _buildTH('بارچلانی', 50),
                              _buildTH('قیمت نهایی', 65),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              child: Row(
                                children: [
                                  _buildTD(invoice['name'] ?? '-', 80),
                                  _buildTD(invoice['material_type'] ?? '-', 50),
                                  _buildTD(invoice['unit'] ?? '-', 45),
                                  _buildTD(invoice['thickness'] ?? '-', 45),
                                  _buildTD(invoice['net_weight']?.toString() ?? '-', 60),
                                  _buildTD(invoice['gross_weight']?.toString() ?? '-', 60),
                                  _buildTD(invoice['unit_price']?.toString() ?? '-', 60),
                                  _buildTD(invoice['product']?.toString() ?? '-', 50),
                                  _buildTD(invoice['commission']?.toString() ?? '-', 50),
                                  _buildTD(invoice['transfer_cost']?.toString() ?? '-', 50),
                                  _buildTD(invoice['miscellaneous']?.toString() ?? '-', 50),
                                  _buildTD(invoice['ghurfedari']?.toString() ?? '-', 50),
                                  _buildTD(invoice['barchalani']?.toString() ?? '-', 50),
                                  _buildTD(invoice['final_price']?.toString() ?? '-', 65, isBold: true, isRed: true),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Summary
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCB001D).withOpacity(0.04),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.15), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildSummaryItem('وزن خالص:', invoice['net_weight']?.toString() ?? '0', invoice['unit'] ?? ''),
                        const SizedBox(width: 16),
                        _buildSummaryItem('وزن ناخالص:', invoice['gross_weight']?.toString() ?? '0', invoice['unit'] ?? ''),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('مبلغ قابل پرداخت', style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                        Text(
                          '${invoice['final_price'] ?? 0} افغانی',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFCB001D)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Footer
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
                ),
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('امضا: _________________', style: TextStyle(fontSize: 9, color: Color(0xFF888888))),
                    Text(
                      'تاریخ چاپ: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}',
                      style: const TextStyle(fontSize: 8, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'ویکتور پایپ صنعت - سامانه مدیریت یکپارچه',
                  style: TextStyle(fontSize: 7, color: Color(0xFF888888)),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // ============ BUTTONS WITH PRINT & PDF ============
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('بستن', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _generatePDFInvoice(invoice, invoiceNumber);
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                    label: const Text('PDF', style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _generatePDFInvoice(invoice, invoiceNumber);
                    },
                    icon: const Icon(Icons.print, size: 18, color: Colors.white),
                    label: const Text('چاپ', style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCB001D),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ TABLE HELPERS ============
  Widget _buildTH(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 8,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTD(String text, double width, {bool isBold = false, bool isRed = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isRed ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E),
          fontSize: 8,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, String unit) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11)),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(width: 2),
        Text(unit, style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مدیریت مواد خام', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                    SizedBox(height: 2),
                    Text('مدیریت و کنترل مواد اولیه انبار', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
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
                            const Icon(Icons.check_circle, color: Color(0xFFCB001D), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${_selectedIds.length} انتخاب شده',
                              style: const TextStyle(color: Color(0xFFCB001D), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () { _showAddDialog(context); },
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: const Text('افزودن ماده خام', style: TextStyle(color: Colors.white, fontSize: 12)),
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

            // Stats
            Row(
              children: [
                _buildStatCard('کل مواد', materials.length.toString()),
                const SizedBox(width: 12),
                _buildStatCard('فروشندگان', suppliers.length.toString()),
                const SizedBox(width: 12),
                _buildStatCard('فاکتورها', invoices.length.toString(), Icons.receipt, Colors.orange),
              ],
            ),
            const SizedBox(height: 12),

            // Unit-based totals cards
            if (materials.isNotEmpty) ...[
              const Text('خلاصه انبار موجود بر اساس واحد:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _buildUnitCards()),
              ),
            ],
            const SizedBox(height: 14),

            // List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
                  : materials.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warehouse_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('هیچ ماده خامی یافت نشد', style: TextStyle(fontSize: 14, color: Colors.grey)),
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
                                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
                                  ],
                                  border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.06), width: 1),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: 1800,
                                    child: ListView.builder(
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _paginatedMaterials.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFCB001D).withOpacity(0.05),
                                              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                                            ),
                                            child: Row(
                                              children: [
                                                const SizedBox(width: 40),
                                                const SizedBox(width: 6),
                                                _buildHeaderCell('شماره', 60),
                                                _buildHeaderCell('نام مواد', 90),
                                                _buildHeaderCell('تاریخ', 65),
                                                _buildHeaderCell('واحد', 60),
                                                _buildHeaderCell('وزن خالص', 65),
                                                _buildHeaderCell('وزن ناخالص', 65),
                                                _buildHeaderCell('قیمت واحد', 65),
                                                _buildHeaderCell('محصول', 60),
                                                _buildHeaderCell('کمیشن', 60),
                                                _buildHeaderCell('کرایه', 60),
                                                _buildHeaderCell('متفرقه', 60),
                                                _buildHeaderCell('غرفه داری', 60),
                                                _buildHeaderCell('بارچلانی', 60),
                                                _buildHeaderCell('قیمت نهایی', 80),
                                                _buildHeaderCell('فاکتور', 65),
                                                const SizedBox(width: 70),
                                              ],
                                            ),
                                          );
                                        }

                                        final material = _paginatedMaterials[index - 1];
                                        final isSelected = _selectedIds.contains(material['id'] as int);
                                        final hasInvoice = material['invoice_id'] != null;

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
                                              _buildDataCell(material['date'] ?? '-', 65),
                                              _buildDataCell(material['unit'] ?? '-', 60),
                                              _buildDataCell(material['net_weight'] ?? '-', 65),
                                              _buildDataCell(material['gross_weight'] ?? '-', 65),
                                              _buildDataCell(material['unit_price'] ?? '-', 65),
                                              _buildDataCell(material['product'] ?? '-', 60),
                                              _buildDataCell(material['commission'] ?? '-', 60),
                                              _buildDataCell(material['transfer_cost'] ?? '-', 60),
                                              _buildDataCell(material['miscellaneous'] ?? '-', 60),
                                              _buildDataCell(material['ghurfedari'] ?? '-', 60),
                                              _buildDataCell(material['barchalani'] ?? '-', 60),
                                              _buildDataCell(material['final_price'] ?? '-', 80, isBold: true, isRed: true),
                                              SizedBox(
                                                width: 65,
                                                child: hasInvoice
                                                    ? IconButton(
                                                        icon: const Icon(Icons.receipt, color: Colors.orange, size: 18),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () {
                                                          final invoice = invoices.firstWhere(
                                                            (inv) => inv['id'] == material['invoice_id'],
                                                            orElse: () => {},
                                                          );
                                                          final supplier = suppliers.firstWhere(
                                                            (s) => s['id'] == material['supplier_id'],
                                                            orElse: () => {},
                                                          );
                                                          _showInvoiceModal(context, invoice['invoice_number'] ?? '---', invoice, supplier);
                                                        },
                                                      )
                                                    : SizedBox(
                                                        width: 50,
                                                        height: 24,
                                                        child: ElevatedButton(
                                                          onPressed: () { _generateInvoice(material); },
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.green,
                                                            padding: EdgeInsets.zero,
                                                            minimumSize: const Size(40, 22),
                                                          ),
                                                          child: const Text('ایجاد', style: TextStyle(fontSize: 8, color: Colors.white)),
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 6),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.edit_outlined, color: const Color(0xFFCB001D), size: 18),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    onPressed: () { _showEditDialog(context, material); },
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    onPressed: () { _showDeleteDialog(context, material); },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Pagination
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
                                      const Text('نمایش:', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
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
                                      Text('در هر صفحه', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text('صفحه $_currentPage از $_totalPages', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
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
                        ),
            ),
          ],
        ),
      ),
    );
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

  String _getSupplierName(int? supplierId) {
    if (supplierId == null) return '-';
    final supplier = suppliers.firstWhere(
      (s) => s['id'] == supplierId,
      orElse: () => {},
    );
    return supplier['name'] ?? '-';
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

    String? selectedSupplierId;

    void _updateFinalPrice() {
      double grossWeight = double.tryParse(grossWeightController.text) ?? 0;
      double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      double productCost = double.tryParse(productController.text) ?? 0;
      double commission = double.tryParse(commissionController.text) ?? 0;
      double transferCost = double.tryParse(transferCostController.text) ?? 0;
      double miscellaneous = double.tryParse(miscellaneousController.text) ?? 0;
      double ghurfedari = double.tryParse(ghurfedariController.text) ?? 0;
      double barchalani = double.tryParse(barchalaniController.text) ?? 0;

      double basePrice = grossWeight * unitPrice;
      double finalPrice = basePrice + productCost + commission + transferCost + 
                          miscellaneous + ghurfedari + barchalani;
      finalPriceController.text = finalPrice.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('افزودن ماده خام جدید'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Supplier Dropdown
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'انتخاب فروشنده *',
                          labelStyle: TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: selectedSupplierId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('انتخاب فروشنده...'),
                          ),
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
                      
                      // Date
                      TextFormField(
                        controller: dateController,
                        decoration: InputDecoration(
                          labelText: 'تاریخ *',
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
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
                            dateController.text = '${picked.year}/${picked.month}/${picked.day}';
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      
                      // Name
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'نام مواد ارسالی *',
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Location
                      TextField(
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText: 'محل تخلیه *',
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Material Type
                      TextField(
                        controller: materialTypeController,
                        decoration: InputDecoration(
                          labelText: 'نوع مواد *',
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Unit
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'واحد *',
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: unitController.text.isNotEmpty ? unitController.text : null,
                        items: const [
                          DropdownMenuItem<String>(value: 'کیلوگرم', child: Text('کیلوگرم (Kg)')),
                          DropdownMenuItem<String>(value: 'تن', child: Text('تن (Ton)')),
                          DropdownMenuItem<String>(value: 'متر', child: Text('متر (M)')),
                          DropdownMenuItem<String>(value: 'سانتی‌متر', child: Text('سانتی‌متر (Cm)')),
                          DropdownMenuItem<String>(value: 'لیتر', child: Text('لیتر (L)')),
                          DropdownMenuItem<String>(value: 'عدد', child: Text('عدد (Pcs)')),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            unitController.text = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      
                      // Thickness
                      TextField(
                        controller: thicknessController,
                        decoration: InputDecoration(
                          labelText: 'ضخامت *',
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Product
                      TextField(
                        controller: productController,
                        decoration: InputDecoration(
                          labelText: 'قیمت محصول (افغانی)',
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateFinalPrice(),
                      ),
                      const SizedBox(height: 8),
                      
                      // Net & Gross Weight
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: netWeightController,
                              decoration: InputDecoration(
                                labelText: 'وزن خالص *',
                                labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
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
                                labelText: 'وزن ناخالص *',
                                labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Unit Price
                      TextField(
                        controller: unitPriceController,
                        decoration: InputDecoration(
                          labelText: 'قیمت واحد (افغانی) *',
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFCB001D)),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateFinalPrice(),
                      ),
                      const SizedBox(height: 8),
                      
                      // Commission & Transfer
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commissionController,
                              decoration: InputDecoration(
                                labelText: 'کمیشن (افغانی)',
                                labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
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
                                labelText: 'کرایه انتقالات (افغانی)',
                                labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // غرفه داری & بارچلانی
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ghurfedariController,
                              decoration: InputDecoration(
                                labelText: 'غرفه داری (افغانی)',
                                labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
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
                                labelText: 'بارچلانی (افغانی)',
                                labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Miscellaneous & Final Price
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: miscellaneousController,
                              decoration: InputDecoration(
                                labelText: 'متفرقه (افغانی)',
                                labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
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
                                labelText: 'قیمت تمام شد (افغانی)',
                                labelStyle: const TextStyle(
                                  color: Color(0xFFCB001D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFCB001D)),
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                ),
                                fillColor: const Color(0xFFF5F0EB),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFFCB001D),
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
                  child: const Text('انصراف', style: TextStyle(color: Color(0xFF888888))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedSupplierId == null || nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لطفاً تمام فیلدهای ضروری را پر کنید'),
                          backgroundColor: Colors.red,
                        ),
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
                      'unit': unitController.text,
                      'unit_price': unitPriceController.text,
                      'product': productController.text,
                      'commission': commissionController.text,
                      'transfer_cost': transferCostController.text,
                      'miscellaneous': miscellaneousController.text,
                      'ghurfedari': ghurfedariController.text,
                      'barchalani': barchalaniController.text,
                      'final_price': finalPriceController.text,
                    };

                    final result = await _db.insertRawMaterial(material);
                    Navigator.pop(context);

                    if (result != -1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ ماده خام اضافه شد. در حال ایجاد فاکتور...'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      
                      final newMaterial = await _db.getRawMaterials();
                      if (newMaterial.isNotEmpty) {
                        final latestMaterial = newMaterial.last;
                        await _generateInvoice(latestMaterial);
                      }
                      
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ خطا در افزودن ماده خام'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                  ),
                  child: const Text('ذخیره و ایجاد فاکتور'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> material) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ویرایش در حال توسعه...'), duration: Duration(seconds: 2)),
    );
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> material) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف ماده خام'),
          content: Text('آیا از حذف ماده خام "${material['name']}" مطمئن هستید؟'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف', style: TextStyle(color: Color(0xFF888888))),
            ),
            ElevatedButton(
              onPressed: () async {
                // Delete invoice first if exists
                if (material['invoice_id'] != null) {
                  await _db.deleteInvoice(material['invoice_id']);
                }
                final result = await _db.deleteRawMaterial(material['id']);
                Navigator.pop(context);
                if (result != -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ ماده خام با موفقیت حذف شد'), backgroundColor: Colors.green),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ خطا در حذف ماده خام'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }
}
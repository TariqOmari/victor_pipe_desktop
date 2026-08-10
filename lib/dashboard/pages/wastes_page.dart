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

  // Helper to convert kg to tons - with proper decimal places
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

  // Format weight for table - always in tons
  String _getDisplayWeight(dynamic weight) {
    final value = double.tryParse(weight?.toString() ?? '0') ?? 0;
    return _formatWeightWithConversion(value);
  }

  // Calculate total weight (weight × quantity) and convert to tons
  String _getTotalWeightDisplay(dynamic weight, dynamic quantity) {
    final w = double.tryParse(weight?.toString() ?? '0') ?? 0;
    final q = double.tryParse(quantity?.toString() ?? '0') ?? 0;
    final total = w * q;
    return _formatWeightWithConversion(total);
  }

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
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar(l10n.errorLoadingWastes, Colors.red);
    }
  }

  Future<void> _showWasteDialog({Map<String, dynamic>? waste}) async {
    final l10n = AppLocalizations.of(context)!;
    final dateController = TextEditingController(text: waste?['date']?.toString() ?? PersianDateConverter.getCurrentPersianDate());
    final partyDetailsController = TextEditingController(text: waste?['party_details']?.toString() ?? '');
    final wasteTypeController = TextEditingController(text: waste?['waste_type']?.toString() ?? '');
    final descriptionController = TextEditingController(text: waste?['description']?.toString() ?? '');
    final weightController = TextEditingController(text: waste?['weight']?.toString() ?? '');
    final quantityController = TextEditingController(text: waste?['quantity']?.toString() ?? '');
    final valueController = TextEditingController(text: waste?['value']?.toString() ?? '');
    final priceRateController = TextEditingController(text: waste?['exchange_rate']?.toString() ?? '1');
    final equivalentController = TextEditingController(text: waste?['afn_equivalent']?.toString() ?? '');
    final totalWeightController = TextEditingController(text: '');
    String selectedCurrency = waste?['currency']?.toString() ?? 'USD';
    String selectedEnglishDate = waste?['date_en']?.toString() ?? PersianDateConverter.getEnglishDate(DateTime.now());

    void updateTotals() {
      final value = double.tryParse(valueController.text) ?? 0;
      final rate = double.tryParse(priceRateController.text) ?? 1;
      
      if (selectedCurrency == 'AFN') {
        // AFN selected: value / rate = USD equivalent
        equivalentController.text = value > 0 && rate > 0 ? (value / rate).toStringAsFixed(2) : '';
      } else {
        // USD selected: value * rate = AFN equivalent
        equivalentController.text = value > 0 && rate > 0 ? (value * rate).toStringAsFixed(0) : '';
      }
    }

    void updateTotalWeight() {
      final weight = double.tryParse(weightController.text) ?? 0;
      final quantity = double.tryParse(quantityController.text) ?? 0;
      final total = weight * quantity;
      if (total > 0) {
        totalWeightController.text = _formatWeightWithConversion(total);
      } else {
        totalWeightController.text = '';
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double weight = double.tryParse(weightController.text) ?? 0;
          double quantity = double.tryParse(quantityController.text) ?? 0;
          double totalWeight = weight * quantity;
          String weightInTons = _formatWeightWithConversion(weight);
          String totalWeightInTons = _formatWeightWithConversion(totalWeight);

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                waste == null ? l10n.addWasteRecord : l10n.editWasteRecord,
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
                        label: l10n.date,
                        icon: Icons.calendar_today_outlined,
                        readOnly: true,
                        l10n: l10n,
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
                      _buildTextField(controller: partyDetailsController, label: l10n.partyDetailsLabel, icon: Icons.business_outlined, l10n: l10n),
                      const SizedBox(height: 12),
                      _buildTextField(controller: wasteTypeController, label: l10n.wasteTypeLabel, icon: Icons.category_outlined, l10n: l10n),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: weightController,
                                  label: l10n.weightKgLabel,
                                  icon: Icons.scale_outlined,
                                  keyboardType: TextInputType.number,
                                  l10n: l10n,
                                  onChanged: (_) {
                                    setDialogState(() {
                                      updateTotalWeight();
                                    });
                                  },
                                ),
                                if (weight > 0)
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
                                              '$weight kg',
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
                                              weightInTons,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: quantityController,
                                  label: l10n.quantityAmountLabel,
                                  icon: Icons.numbers_outlined,
                                  keyboardType: TextInputType.number,
                                  l10n: l10n,
                                  onChanged: (_) {
                                    setDialogState(() {
                                      updateTotalWeight();
                                    });
                                  },
                                ),
                                if (quantity > 0 && weight > 0)
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
                                              '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2)} kg',
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
                                              totalWeightInTons,
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: totalWeightController,
                        label: 'مجموع وزن (تن)',
                        icon: Icons.monitor_weight_outlined,
                        readOnly: true,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: valueController, label: l10n.wasteValueLabel, icon: Icons.attach_money_outlined, keyboardType: TextInputType.number, l10n: l10n, onChanged: (_) => setDialogState(updateTotals))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: priceRateController, label: selectedCurrency == 'USD' ? 'نرخ ارز (USD به AFN) *' : 'نرخ ارز (AFN به USD) *', icon: Icons.currency_exchange, keyboardType: TextInputType.number, l10n: l10n, onChanged: (_) => setDialogState(updateTotals))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: equivalentController, label: selectedCurrency == 'AFN' ? 'معادل به دالر (USD)' : 'معادل به افغانی (AFN)', icon: Icons.currency_exchange, readOnly: true, l10n: l10n)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCurrency,
                              decoration: InputDecoration(
                                labelText: l10n.currency,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.request_quote_outlined),
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(controller: descriptionController, label: l10n.description, icon: Icons.description_outlined, maxLines: 3, l10n: l10n),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
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
                      'exchange_rate': double.tryParse(priceRateController.text) ?? 1,
                      'description': descriptionController.text.trim(),
                      'afn_equivalent': double.tryParse(equivalentController.text) ?? 0,
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
                      _showSnackbar(waste == null ? l10n.wasteAddedSuccess : l10n.wasteUpdatedSuccess, Colors.green);
                    } catch (e) {
                      if (!mounted) return;
                      _showSnackbar(l10n.errorSavingWaste, Colors.red);
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(waste == null ? l10n.addWasteRecord : l10n.saveChanges),
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteWasteRecord),
        content: Text(l10n.deleteConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), child: Text(l10n.delete)),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.deleteWasteRecord(waste['id']);
      await _loadWastes();
      _showSnackbar(l10n.wasteDeletedSuccess, Colors.orange);
    } catch (e) {
      _showSnackbar(l10n.errorDeletingWaste, Colors.red);
    }
  }

  Future<void> _printWasteInvoice(Map<String, dynamic> waste) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final pdf = await _generateWastePDF(waste, l10n);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
        name: '${l10n.wasteInvoice}_${waste['id']}',
      );
    } catch (e) {
      _showSnackbar('${l10n.errorPrintingWasteInvoice}: $e', Colors.red);
    }
  }

  Future<Uint8List> _generateWastePDF(Map<String, dynamic> waste, AppLocalizations l10n) async {
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    double weight = double.tryParse(waste['weight']?.toString() ?? '0') ?? 0;
    double quantity = double.tryParse(waste['quantity']?.toString() ?? '0') ?? 0;
    double totalWeight = weight * quantity;
    String displayWeight = _formatWeightWithConversion(weight);
    String displayTotalWeight = _formatWeightWithConversion(totalWeight);

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
                        pw.Text(l10n.integratedSystem, style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
                      ]),
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(6)),
                          child: pw.Text('Waste Invoice', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text('${l10n.invoiceNumber}: ${waste['invoice_number'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${l10n.persianDate}: ${waste['date'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('Date (EN): ${waste['date_en'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                      ]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(children: [
                    pw.Expanded(child: pw.Text('${l10n.partyDetailsLabel}: ${waste['party_details'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    pw.Expanded(child: pw.Text('${l10n.wasteTypeLabel}: ${waste['waste_type'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                  ]),
                ),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: [l10n.description, 'مبلغ'],
                  data: [
                    [l10n.weightKgLabel, displayWeight],
                    [l10n.quantityAmountLabel, _formatNumber(waste['quantity'])],
                    ['مجموع وزن', displayTotalWeight],
                    [l10n.wasteValueLabel, '${_formatNumber(waste['value'])} ${waste['currency'] ?? 'USD'}'],
                    [l10n.exchangeRate, _formatNumber(waste['exchange_rate'])],
                    [l10n.afnEquivalentLabel, '${_formatNumber(waste['afn_equivalent'])} AFN'],
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
                if (waste['description'] != null && waste['description'].toString().isNotEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Text('${l10n.description}: ${waste['description']}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                  ),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text(l10n.signature, style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('${l10n.printDate}: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                ]),
                pw.Center(
                  child: pw.Text(l10n.footerText, style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

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
              child: const Icon(Icons.delete_outline, color: Color(0xFFCB001D), size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.wastesManagement, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                Text(l10n.wastesManagementSubtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _showWasteDialog(),
          icon: const Icon(Icons.add_circle_outline),
          label: Text(l10n.addWasteRecord),
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
    final totalWastes = _wastes.length;
    final totalValue = _wastes.fold<double>(0, (sum, item) => sum + (double.tryParse(item['value']?.toString() ?? '0') ?? 0));
    final totalAfn = _wastes.fold<double>(0, (sum, item) => sum + (double.tryParse(item['afn_equivalent']?.toString() ?? '0') ?? 0));
    final totalWeight = _wastes.fold<double>(0, (sum, item) => sum + (double.tryParse(item['weight']?.toString() ?? '0') ?? 0));
    final totalWeightInTons = totalWeight / 1000;
    
    return Row(
      children: [
        _buildStatCard(l10n.totalWastesCount, totalWastes.toString(), Icons.delete_outline, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard(l10n.totalWasteValue, _formatNumber(totalValue), Icons.attach_money_outlined, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard(l10n.totalAfnEquivalentWaste, _formatNumber(totalAfn), Icons.currency_exchange, Colors.green.shade700),
        const SizedBox(width: 12),
        _buildStatCard('مجموع وزن', '${totalWeightInTons.toStringAsFixed(totalWeightInTons % 1 == 0 ? 0 : 3)} تن', Icons.scale, const Color(0xFFCB001D)),
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

  Widget _buildFilterAndSearch(AppLocalizations l10n) {
    final filters = [l10n.all, l10n.wastesFilter];
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
              hintText: l10n.searchWastes,
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

  Widget _buildWastesTable(List<Map<String, dynamic>> data, AppLocalizations l10n) {
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
                  _buildHeaderCell(l10n.invoiceNumberLabel, 70),
                  _buildHeaderCell(l10n.date, 100),
                  _buildHeaderCell(l10n.partyDetailsLabel, 130),
                  _buildHeaderCell(l10n.wasteTypeLabel, 120),
                  _buildHeaderCell('وزن (تن)', 80),
                  _buildHeaderCell(l10n.quantityAmountLabel, 80),
                  _buildHeaderCell('مجموع وزن', 100),
                  _buildHeaderCell(l10n.wasteValueLabel, 90),
                  _buildHeaderCell(l10n.currency, 60),
                  _buildHeaderCell(l10n.exchangeRate, 80),
                  _buildHeaderCell(l10n.afnEquivalentLabel, 100),
                  _buildHeaderCell(l10n.description, 150),
                  _buildHeaderCell(l10n.actions, 140),
                ],
              ),
            ),
          ),
          Expanded(
            child: paged.isEmpty
                ? Center(child: Text(l10n.noWastesFound, style: const TextStyle(color: Colors.grey)))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: paged.map((waste) {
                          final id = (waste['id'] ?? '').toString();
                          final checked = _selectedWastes.contains(id);
                          String displayWeight = _getDisplayWeight(waste['weight']);
                          String totalWeightDisplay = _getTotalWeightDisplay(waste['weight'], waste['quantity']);
                          
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
                                  _buildDataCell(displayWeight, 80),
                                  _buildDataCell(_formatNumber(waste['quantity']), 80),
                                  _buildDataCell(totalWeightDisplay, 100, isBold: true, color: const Color(0xFFCB001D)),
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
                  Text('${l10n.selected}: ${_selectedWastes.length}'),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedWastes.isEmpty ? null : () {},
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
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final filteredData = _wastes.where((waste) {
      final search = _searchQuery.toLowerCase();
      final matchesSearch = (waste['party_details'] ?? '').toString().toLowerCase().contains(search) ||
          (waste['waste_type'] ?? '').toString().toLowerCase().contains(search) ||
          (waste['invoice_number'] ?? '').toString().toLowerCase().contains(search) ||
          (waste['description'] ?? '').toString().toLowerCase().contains(search);
      return matchesSearch;
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
                  Expanded(child: _buildWastesTable(filteredData, l10n)),
                ]),
        ),
      ),
    );
  }
}
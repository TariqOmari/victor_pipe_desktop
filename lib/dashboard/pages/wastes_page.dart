import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
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
  List<Map<String, dynamic>> _rawMaterials = [];
  int _currentPage = 1;
  int _rowsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50];
  final Set<int> _selectedWastes = {};
  String _searchQuery = '';
  String _selectedFilter = 'همه';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _invoicePreviewKey = GlobalKey();

  // Helper to convert kg to tons - with proper decimal places
  String _formatWeightWithConversion(double weight) {
    if (weight <= 0) return '0';
    double tons = weight / 1000;
    if (tons < 1) {
      return '${tons.toStringAsFixed(3)} تن';
    }
    return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
  }

  String _getDisplayWeight(dynamic weight) {
    final value = double.tryParse(weight?.toString() ?? '0') ?? 0;
    return _formatWeightWithConversion(value);
  }

  String _getTotalWeightDisplay(dynamic weight, dynamic quantity) {
    final w = double.tryParse(weight?.toString() ?? '0') ?? 0;
    final q = double.tryParse(quantity?.toString() ?? '0') ?? 0;
    final total = w * q;
    return _formatWeightWithConversion(total);
  }

  // ============ PERSIAN DIGIT CONVERSION HELPERS ============
  String _convertPersianToEnglishDigits(String value) {
    if (value.isEmpty) return value;

    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    String result = value;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(persianDigits[i], englishDigits[i]);
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return result;
  }

  String _getCellValueDirect(List<excel.Data?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    final cell = row[index];
    if (cell == null) return '';
    if (cell.value == null) return '';

    String value;
    if (cell.value is String) {
      value = (cell.value as String).trim();
    } else if (cell.value is num) {
      num val = cell.value as num;
      value = val.toString();
    } else {
      value = cell.value.toString().trim();
    }

    if (value.isNotEmpty) {
      value = _convertPersianToEnglishDigits(value);
    }

    return value;
  }

  double _parseNumber(String value) {
    if (value.isEmpty) return 0;
    String cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return 0;
    try {
      return double.parse(cleaned);
    } catch (e) {
      return 0;
    }
  }

  // ============ EXCEL IMPORT ============
  Future<void> _importExcel() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFCB001D)),
              const SizedBox(height: 16),
              const Text(
                'در حال وارد کردن اکسل...',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await _pickAndImportExcel();

      Navigator.pop(context);

      if (result['success']) {
        _showImportResultDialog(context, result);
        await _loadWastes();
      } else {
        _showSnackbar(result['message'] ?? 'خطا در وارد کردن فایل', Colors.red);
      }
    } catch (e) {
      Navigator.pop(context);
      _showSnackbar('خطا در وارد کردن: $e', Colors.red);
    }
  }

  Future<Map<String, dynamic>> _pickAndImportExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) {
        return {'success': false, 'message': 'فایلی انتخاب نشد'};
      }

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

      try {
        final excelFile = excel.Excel.decodeBytes(bytes);
        final sheet = excelFile.tables[excelFile.tables.keys.first];
        if (sheet == null) {
          return {'success': false, 'message': 'فایل اکسل معتبر نیست'};
        }
        return await _parseExcelSheet(sheet);
      } catch (e) {
        return {
          'success': false,
          'message': 'فایل اکسل خراب است یا فرمت آن پشتیبانی نمی‌شود'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در خواندن فایل: $e'};
    }
  }

  Future<Map<String, dynamic>> _parseExcelSheet(excel.Sheet sheet) async {
    try {
      List<Map<String, dynamic>> importedData = [];
      int successCount = 0;
      int skippedCount = 0;
      List<String> errors = [];

      final headersRow = sheet.rows.first;
      List<String> headers = [];
      for (var cell in headersRow) {
        if (cell != null && cell.value != null) {
          headers.add(cell.value.toString().trim());
        }
      }

      int invoiceNumberIndex = -1;
      int dateIndex = -1;
      int partyDetailsIndex = -1;
      int wasteTypeIndex = -1;
      int weightIndex = -1;
      int quantityIndex = -1;
      int currencyIndex = -1;
      int exchangeRateIndex = -1;
      int afnEquivalentIndex = -1;
      int descriptionIndex = -1;
      int sellPriceIndex = -1;
      int sellCustomerNameIndex = -1;
      int driverNameIndex = -1;
      int numberPlateIndex = -1;

      for (int i = 0; i < headers.length; i++) {
        String h = headers[i];
        String hLower = h.toLowerCase();

        if (hLower.contains('شماره') || hLower.contains('فاکتور') ||
            hLower.contains('invoice')) {
          invoiceNumberIndex = i;
        } else if (hLower.contains('تاریخ') || hLower.contains('date')) {
          dateIndex = i;
        } else if (hLower.contains('طرف') || hLower.contains('خریدار') ||
            hLower.contains('فروشنده') || hLower.contains('party')) {
          partyDetailsIndex = i;
        } else if (hLower.contains('نوع ضایعات') || hLower.contains('ضایعات') ||
            hLower.contains('waste') || hLower.contains('type')) {
          wasteTypeIndex = i;
        } else if (hLower.contains('وزن') && !hLower.contains('ناخالص') &&
            !hLower.contains('خالص') || hLower.contains('weight')) {
          weightIndex = i;
        } else if (hLower.contains('تعداد') || hLower.contains('quantity') ||
            hLower.contains('quantity')) {
          quantityIndex = i;
        } else if (hLower.contains('ارز') || hLower.contains('واحد پول') ||
            hLower.contains('currency')) {
          currencyIndex = i;
        } else if (hLower.contains('نرخ') || hLower.contains('exchange') ||
            hLower.contains('rate')) {
          exchangeRateIndex = i;
        } else if (hLower.contains('معادل') || hLower.contains('afn') ||
            hLower.contains('افغانی')) {
          afnEquivalentIndex = i;
        } else if (hLower.contains('توضیحات') || hLower.contains('شرح') ||
            hLower.contains('description')) {
          descriptionIndex = i;
        } else if (hLower.contains('قیمت فروش') || hLower.contains('sell price') ||
            hLower.contains('sell_price')) {
          sellPriceIndex = i;
        } else if (hLower.contains('مشتری فروش') || hLower.contains('sell customer') ||
            hLower.contains('buyer')) {
          sellCustomerNameIndex = i;
        } else if (hLower.contains('دریور') || hLower.contains('driver')) {
          driverNameIndex = i;
        } else if (hLower.contains('پلیت') || hLower.contains('plate')) {
          numberPlateIndex = i;
        }
      }

      if (dateIndex == -1) {
        return {
          'success': false,
          'message': 'فیلد مورد نیاز پیدا نشد: تاریخ'
        };
      }

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        bool hasData = false;
        for (var cell in row) {
          if (cell != null && cell.value != null) {
            String val = cell.value.toString().trim();
            if (val.isNotEmpty && val != '0' && val != '-' && val != '\$') {
              hasData = true;
              break;
            }
          }
        }
        if (!hasData) continue;

        try {
          String invoiceNumber = invoiceNumberIndex != -1
              ? _getCellValueDirect(row, invoiceNumberIndex)
              : '';
          String date = _getCellValueDirect(row, dateIndex);
          String partyDetails = partyDetailsIndex != -1
              ? _getCellValueDirect(row, partyDetailsIndex)
              : '';
          String wasteType = wasteTypeIndex != -1
              ? _getCellValueDirect(row, wasteTypeIndex)
              : '';
          String weightStr = weightIndex != -1
              ? _getCellValueDirect(row, weightIndex)
              : '0';
          String quantityStr = quantityIndex != -1
              ? _getCellValueDirect(row, quantityIndex)
              : '0';
          String currency = currencyIndex != -1
              ? _getCellValueDirect(row, currencyIndex)
              : 'USD';
          String exchangeRateStr = exchangeRateIndex != -1
              ? _getCellValueDirect(row, exchangeRateIndex)
              : '1';
          String afnEquivalentStr = afnEquivalentIndex != -1
              ? _getCellValueDirect(row, afnEquivalentIndex)
              : '0';
          String description = descriptionIndex != -1
              ? _getCellValueDirect(row, descriptionIndex)
              : '';
          String sellPriceStr = sellPriceIndex != -1
              ? _getCellValueDirect(row, sellPriceIndex)
              : '0';
          String sellCustomerName = sellCustomerNameIndex != -1
              ? _getCellValueDirect(row, sellCustomerNameIndex)
              : '';
          String driverName = driverNameIndex != -1
              ? _getCellValueDirect(row, driverNameIndex)
              : '';
          String numberPlate = numberPlateIndex != -1
              ? _getCellValueDirect(row, numberPlateIndex)
              : '';

          weightStr = weightStr.replaceAll(RegExp(r'[$,]'), '').trim();
          quantityStr = quantityStr.replaceAll(RegExp(r'[$,]'), '').trim();
          exchangeRateStr = exchangeRateStr.replaceAll(RegExp(r'[$,]'), '')
              .trim();
          afnEquivalentStr = afnEquivalentStr.replaceAll(RegExp(r'[$,]'), '')
              .trim();
          sellPriceStr = sellPriceStr.replaceAll(RegExp(r'[$,]'), '').trim();

          if (date.isEmpty) {
            skippedCount++;
            errors.add('ردیف ' + (i + 1).toString() + ': تاریخ الزامی است');
            continue;
          }

          if (invoiceNumber.isEmpty) {
            final nextNumber = await _db.getNextWasteInvoiceNumber();
            invoiceNumber = nextNumber.toString().padLeft(5, '0');
          }

          final existing = await _db.getWasteRecords();
          bool duplicate = existing.any((e) =>
          e['invoice_number'] == invoiceNumber);
          if (duplicate) {
            skippedCount++;
            errors.add('ردیف ' + (i + 1).toString() + ': شماره بل "' +
                invoiceNumber + '" تکراری است');
            continue;
          }

          double weight = _parseNumber(weightStr);
          double quantity = _parseNumber(quantityStr);
          double exchangeRate = _parseNumber(exchangeRateStr);
          double afnEquivalent = _parseNumber(afnEquivalentStr);
          double sellPrice = _parseNumber(sellPriceStr);

          String currencyFinal =
          currency == 'AFN' || currency == 'افغانی' ? 'AFN' : 'USD';
          
          // Calculate AFN equivalent based on SELL PRICE
          if (afnEquivalent <= 0 && sellPrice > 0) {
            if (currencyFinal == 'USD') {
              afnEquivalent = sellPrice * exchangeRate;
            } else {
              afnEquivalent = sellPrice;
            }
          }

          if (date.isEmpty) {
            date = PersianDateConverter.gregorianToJalali(DateTime.now());
          }
          String dateEn = PersianDateConverter.getEnglishDate(DateTime.now());

          Map<String, dynamic> waste = {
            'invoice_number': invoiceNumber,
            'date': date,
            'date_en': dateEn,
            'party_details': partyDetails,
            'waste_type': wasteType,
            'weight': weight,
            'quantity': quantity > 0 ? quantity : 1,
            'value': 0,
            'currency': currencyFinal,
            'exchange_rate': exchangeRate > 0 ? exchangeRate : 1,
            'afn_equivalent': afnEquivalent > 0 ? afnEquivalent : (sellPrice * exchangeRate),
            'description': description,
            'is_sold': 1,
            'sell_currency': currencyFinal,
            'sell_price': sellPrice > 0 ? sellPrice : 0,
            'sell_date': date,
            'sell_date_en': dateEn,
            'sell_customer_name': sellCustomerName,
            'driver_name': driverName,
            'number_plate': numberPlate,
            'raw_material_id': null,
            'waste_unit_price': null,
            'waste_final_price': null,
            'waste_raw_material_pure_weight': null,
          };

          int result = await _db.insertWasteRecord(waste);
          if (result != -1) {
            successCount++;
            importedData.add(waste);
          } else {
            skippedCount++;
            errors.add('ردیف ' + (i + 1).toString() + ': خطا در ذخیره‌سازی');
          }
        } catch (e) {
          skippedCount++;
          errors.add('ردیف ' + (i + 1).toString() + ': خطا - ' + e.toString());
        }
      }

      return {
        'success': true,
        'successCount': successCount,
        'skippedCount': skippedCount,
        'importedData': importedData,
        'errors': errors,
        'message': '✅ ${successCount} ردیف با موفقیت وارد شد. ${skippedCount} ردیف نادیده گرفته شد.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطا در پردازش فایل: $e',
      };
    }
  }

  void _showImportResultDialog(BuildContext context,
      Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نتیجه وارد کردن'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✅ ${result['successCount']} رکورد با موفقیت وارد شد',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
                if (result['skippedCount'] > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ ${result['skippedCount']} رکورد نادیده گرفته شد',
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ],
                if (result['errors'] != null && result['errors'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'خطاها:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    height: 100,
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (result['errors'] as List<String>)
                            .take(5)
                            .map((error) => Text(
                          error,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.red),
                        ))
                            .toList(),
                      ),
                    ),
                  ),
                  if ((result['errors'] as List<String>).length > 5)
                    Text(
                      'و ${(result['errors'] as List<String>).length - 5} خطای دیگر...',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('باشه'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadWastes();
    _loadRawMaterials();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRawMaterials() async {
    try {
      final list = await _db.getRawMaterials();
      setState(() {
        _rawMaterials = list;
      });
    } catch (e) {
      print('Error loading raw materials: $e');
    }
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
          'is_sold': item['is_sold'] ?? 0,
          'sell_currency': item['sell_currency'],
          'sell_price': item['sell_price'],
          'sell_date': item['sell_date'],
          'sell_date_en': item['sell_date_en'],
          'sell_customer_name': item['sell_customer_name'],
          'driver_name': item['driver_name'],
          'number_plate': item['number_plate'],
          'raw_material_id': item['raw_material_id'],
          'waste_unit_price': item['waste_unit_price'],
          'waste_final_price': item['waste_final_price'],
          'waste_raw_material_pure_weight': item[
          'waste_raw_material_pure_weight'],
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('خطا در بارگذاری ضایعات', Colors.red);
    }
  }

  // ============================================
  // WASTE DIALOG
  // ============================================
  Future<void> _showWasteDialog({Map<String, dynamic>? waste}) async {
    final invoiceNumberController = TextEditingController(
        text: waste?['invoice_number']?.toString() ?? '');
    final dateController = TextEditingController(
        text: waste?['date']?.toString() ??
            PersianDateConverter.getCurrentPersianDate());
    final partyDetailsController = TextEditingController(
        text: waste?['party_details']?.toString() ?? '');
    final wasteTypeController = TextEditingController(
        text: waste?['waste_type']?.toString() ?? '');
    final descriptionController = TextEditingController(
        text: waste?['description']?.toString() ?? '');
    final weightController = TextEditingController(
        text: waste?['weight']?.toString() ?? '');
    final quantityController = TextEditingController(
      text: (waste != null && waste['quantity'] != null && waste['quantity'] !=
          1)
          ? waste['quantity'].toString()
          : '',
    );
    final priceRateController = TextEditingController(
        text: waste?['exchange_rate']?.toString() ?? '1');
    final equivalentController = TextEditingController(
        text: waste?['afn_equivalent']?.toString() ?? '');
    final totalWeightController = TextEditingController(text: '');

    final sellPriceController = TextEditingController(
        text: waste?['sell_price']?.toString() ?? '');
    final sellCustomerNameController = TextEditingController(
        text: waste?['sell_customer_name']?.toString() ?? '');
    final driverNameController = TextEditingController(
        text: waste?['driver_name']?.toString() ?? '');
    final numberPlateController = TextEditingController(
        text: waste?['number_plate']?.toString() ?? '');

    final rawMaterialPureWeightController = TextEditingController(text: '');
    final rawMaterialFinalPriceController = TextEditingController(text: '');
    final wasteUnitPriceController = TextEditingController(text: '');

    String selectedCurrency = waste?['currency']?.toString() ?? 'USD';
    String selectedEnglishDate = waste?['date_en']?.toString() ??
        PersianDateConverter.getEnglishDate(DateTime.now());

    Map<String, dynamic>? selectedRawMaterial;
    String? selectedRawMaterialId = waste?['raw_material_id']?.toString();

    if (selectedRawMaterialId != null) {
      try {
        selectedRawMaterial = _rawMaterials.firstWhere(
              (rm) => rm['id'].toString() == selectedRawMaterialId,
          orElse: () => {},
        );
        if (selectedRawMaterial.isNotEmpty) {
          rawMaterialPureWeightController.text = selectedRawMaterial['net_weight']
              ?.toString() ?? '';
          rawMaterialFinalPriceController.text = selectedRawMaterial['final_price']
              ?.toString() ?? '';

          double pureWeight = double.tryParse(
              selectedRawMaterial['net_weight']?.toString() ?? '0') ?? 0;
          double finalPrice = double.tryParse(
              selectedRawMaterial['final_price']?.toString() ?? '0') ?? 0;

          if (pureWeight > 0 && finalPrice > 0) {
            String unit = selectedRawMaterial['unit'] ?? 'kg';
            double pureWeightInTons = pureWeight;
            if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
              pureWeightInTons = pureWeight / 1000;
            }
            wasteUnitPriceController.text = (finalPrice / pureWeightInTons)
                .toStringAsFixed(2);
          }

          wasteTypeController.text = selectedRawMaterial['name'] ?? '';
          partyDetailsController.text = selectedRawMaterial['supplier_name'] ??
              '';
        }
      } catch (e) {
        print('Error loading raw material: $e');
      }
    }

    if (invoiceNumberController.text.isEmpty && waste == null) {
      final nextNumber = await _db.getNextWasteInvoiceNumber();
      invoiceNumberController.text = nextNumber.toString().padLeft(5, '0');
    }

  void updateTotals() {
  final sellPrice = double.tryParse(sellPriceController.text) ?? 0;
  final rate = double.tryParse(priceRateController.text) ?? 1;

  if (selectedCurrency == 'AFN') {
    // Convert AFN to USD
    equivalentController.text = sellPrice > 0 && rate > 0
        ? (sellPrice / rate).toStringAsFixed(2)
        : '0';
  } else {
    // Convert USD to AFN
    equivalentController.text = sellPrice > 0 && rate > 0
        ? (sellPrice * rate).toStringAsFixed(0)
        : '0';
  }
  
  // Debug print to verify
  print('💰 Sell Price: $sellPrice, Rate: $rate, AFN: ${equivalentController.text}');
}

    void updateTotalWeight() {
      final weight = double.tryParse(weightController.text) ?? 0;
      final quantityText = quantityController.text.trim();
      double quantity;

      if (quantityText.isEmpty || quantityText == '0') {
        quantity = 1;
      } else {
        quantity = double.tryParse(quantityText) ?? 0;
        if (quantity == 0) quantity = 1;
      }

      final total = weight * quantity;
      if (total > 0) {
        totalWeightController.text = _formatWeightWithConversion(total);
      } else {
        totalWeightController.text = '';
      }
    }

    void calculateWasteValue() {
      if (selectedRawMaterial == null || selectedRawMaterial!.isEmpty) {
        return;
      }

      double pureWeight = double.tryParse(
          selectedRawMaterial!['net_weight']?.toString() ?? '0') ?? 0;
      double finalPrice = double.tryParse(
          selectedRawMaterial!['final_price']?.toString() ?? '0') ?? 0;
      String unit = selectedRawMaterial!['unit'] ?? 'kg';

      double pureWeightInTons = pureWeight;
      if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
        pureWeightInTons = pureWeight / 1000;
      }

      double wasteUnitPrice = 0;
      if (pureWeightInTons > 0 && finalPrice > 0) {
        wasteUnitPrice = finalPrice / pureWeightInTons;
        wasteUnitPriceController.text = wasteUnitPrice.toStringAsFixed(2);
      }

      double wasteWeight = double.tryParse(weightController.text) ?? 0;
      if (wasteWeight > 0) {
        double wasteWeightInTons = wasteWeight / 1000;
        if (wasteWeightInTons > 0 && wasteUnitPrice > 0) {
          double wasteValue = wasteWeightInTons * wasteUnitPrice;
          if (sellPriceController.text.isEmpty) {
            sellPriceController.text = wasteValue.toStringAsFixed(2);
          }
          updateTotals();
        }
      }

      if (wasteTypeController.text.isEmpty) {
        wasteTypeController.text = selectedRawMaterial!['name'] ?? '';
      }
      if (partyDetailsController.text.isEmpty) {
        partyDetailsController.text = selectedRawMaterial!['supplier_name'] ??
            '';
      }
    }

    void onRawMaterialSelected(String? id) {
      if (id == null || id.isEmpty) {
        setState(() {
          selectedRawMaterialId = null;
          selectedRawMaterial = null;
          rawMaterialPureWeightController.text = '';
          rawMaterialFinalPriceController.text = '';
          wasteUnitPriceController.text = '';
        });
        return;
      }

      try {
        final rawMaterial = _rawMaterials.firstWhere(
              (rm) => rm['id'].toString() == id,
          orElse: () => {},
        );

        if (rawMaterial.isNotEmpty) {
          setState(() {
            selectedRawMaterialId = id;
            selectedRawMaterial = rawMaterial;
            rawMaterialPureWeightController.text = rawMaterial['net_weight']
                ?.toString() ?? '';
            rawMaterialFinalPriceController.text = rawMaterial['final_price']
                ?.toString() ?? '';

            double pureWeight = double.tryParse(
                rawMaterial['net_weight']?.toString() ?? '0') ?? 0;
            double finalPrice = double.tryParse(
                rawMaterial['final_price']?.toString() ?? '0') ?? 0;

            if (pureWeight > 0 && finalPrice > 0) {
              String unit = rawMaterial['unit'] ?? 'kg';
              double pureWeightInTons = pureWeight;
              if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
                pureWeightInTons = pureWeight / 1000;
              }
              wasteUnitPriceController.text = (finalPrice / pureWeightInTons)
                  .toStringAsFixed(2);
            }

            wasteTypeController.text = rawMaterial['name'] ?? '';
            partyDetailsController.text = rawMaterial['supplier_name'] ?? '';

            calculateWasteValue();
          });
        }
      } catch (e) {
        print('Error selecting raw material: $e');
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

          List<DropdownMenuItem<String>> rawMaterialItems = [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('انتخاب ماده خام...'),
            ),
          ];

          for (var rm in _rawMaterials) {
            String name = rm['name']?.toString() ?? 'بدون نام';
            String supplier = rm['supplier_name']?.toString() ?? '';
            String netWeight = rm['net_weight']?.toString() ?? '0';
            String display = '$name (${_formatWeightWithConversion(double.tryParse(netWeight) ?? 0)} - $supplier)';
            rawMaterialItems.add(
              DropdownMenuItem<String>(
                value: rm['id'].toString(),
                child: Text(display, overflow: TextOverflow.ellipsis),
              ),
            );
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                waste == null ? 'افزودن ضایعات جدید' : 'ویرایش ضایعات',
                style: const TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: invoiceNumberController,
                        label: 'شماره بل',
                        icon: Icons.receipt_outlined,
                        keyboardType: TextInputType.number,
                        hint: 'شماره بل را وارد کنید',
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFCB001D).withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'اطلاعات ماده خام',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFFCB001D),
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'انتخاب ماده خام',
                                labelStyle: TextStyle(
                                    color: const Color(0xFFCB001D),
                                    fontSize: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              value: selectedRawMaterialId,
                              items: rawMaterialItems,
                              onChanged: (value) {
                                setDialogState(() {
                                  onRawMaterialSelected(value);
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: rawMaterialPureWeightController,
                                    decoration: InputDecoration(
                                      labelText: 'وزن خالص ماده خام',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 12, vertical: 10),
                                    ),
                                    readOnly: true,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: rawMaterialFinalPriceController,
                                    decoration: InputDecoration(
                                      labelText: 'قیمت تمام شده ماده خام',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 12, vertical: 10),
                                    ),
                                    readOnly: true,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFCB001D)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCB001D).withOpacity(
                                    0.06),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFCB001D).withOpacity(
                                      0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Color(0xFFCB001D), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'قیمت فی واحد (هر تن): ${wasteUnitPriceController.text} ${selectedCurrency}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

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
                              dateController.text = PersianDateConverter
                                  .gregorianToJalali(picked);
                              selectedEnglishDate = PersianDateConverter
                                  .getEnglishDate(picked);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                          controller: partyDetailsController,
                          label: 'طرف حساب (منبع)',
                          icon: Icons.business_outlined),
                      const SizedBox(height: 12),
                      _buildTextField(
                          controller: wasteTypeController,
                          label: 'نوع ضایعات',
                          icon: Icons.category_outlined),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '👤 اطلاعات فروش به مشتری',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: sellCustomerNameController,
                              label: 'نام مشتری فروش',
                              icon: Icons.person_outline,
                              hint: 'مشتری که ضایعات به او فروخته می‌شود',
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: driverNameController,
                                    label: 'اسم دریور',
                                    icon: Icons.person_outline,
                                    hint: 'نام دریور',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: numberPlateController,
                                    label: 'نمبر پلیت',
                                    icon: Icons.local_shipping_outlined,
                                    hint: 'شماره پلیت',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: weightController,
                                  label: 'وزن (کیلوگرم)',
                                  icon: Icons.scale_outlined,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    setDialogState(() {
                                      updateTotalWeight();
                                      if (selectedRawMaterial != null) {
                                        calculateWasteValue();
                                      }
                                    });
                                  },
                                ),
                                if (weight > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCB001D)
                                            .withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFCB001D)
                                              .withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius
                                                  .circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D)
                                                    .withOpacity(0.2),
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
                                          const Icon(Icons.arrow_forward,
                                              color: Color(0xFFCB001D),
                                              size: 12),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFCB001D)
                                                  .withOpacity(0.1),
                                              borderRadius: BorderRadius
                                                  .circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D)
                                                    .withOpacity(0.3),
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
                                  label: 'تعداد',
                                  hint: 'اختیاری - پیش‌فرض ۱',
                                  icon: Icons.numbers_outlined,
                                  keyboardType: TextInputType.number,
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCB001D)
                                            .withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFCB001D)
                                              .withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius
                                                  .circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D)
                                                    .withOpacity(0.2),
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
                                          const Icon(Icons.arrow_forward,
                                              color: Color(0xFFCB001D),
                                              size: 12),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFCB001D)
                                                  .withOpacity(0.1),
                                              borderRadius: BorderRadius
                                                  .circular(4),
                                              border: Border.all(
                                                color: const Color(0xFFCB001D)
                                                    .withOpacity(0.3),
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
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFCB001D).withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calculate,
                                color: const Color(0xFFCB001D), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'وزن فی واحد (هر تن): ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${wasteUnitPriceController.text} ${selectedCurrency}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFFCB001D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '💵 قیمت فروش',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'قیمت واقعی که ضایعات به آن فروخته می‌شود',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: sellPriceController,
                              label: 'قیمت فروش (${selectedCurrency}) *',
                              icon: Icons.sell_outlined,
                              keyboardType: TextInputType.number,
                              hint: 'مبلغ فروش واقعی را وارد کنید',
                              onChanged: (_) {
                                setDialogState(() {
                                  updateTotals();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: priceRateController,
                              label: selectedCurrency == 'USD'
                                  ? 'نرخ ارز (USD به AFN) *'
                                  : 'نرخ ارز (AFN به USD) *',
                              icon: Icons.currency_exchange,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: equivalentController,
                              label: selectedCurrency == 'AFN'
                                  ? 'معادل به دالر (USD) - بر اساس قیمت فروش'
                                  : 'معادل به افغانی (AFN) - بر اساس قیمت فروش',
                              icon: Icons.currency_exchange,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCurrency,
                              decoration: InputDecoration(
                                labelText: 'واحد پول',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(
                                    Icons.request_quote_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'USD',
                                    child: Text('USD')),
                                DropdownMenuItem(value: 'AFN',
                                    child: Text('AFN')),
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
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '✅ وضعیت فروش',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'فروخته شده با قیمت: ${sellPriceController.text.isNotEmpty ? sellPriceController.text : '0'} ${selectedCurrency}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildTextField(
                        controller: descriptionController,
                        label: 'توضیحات',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('لغو',
                        style: TextStyle(color: Colors.grey))),
              // ============================================
// FIXED SAVE BUTTON IN WASTES_PAGE
// ============================================

ElevatedButton.icon(
  onPressed: () async {
    if (selectedRawMaterialId == null ||
        selectedRawMaterialId!.isEmpty) {
      _showSnackbar('لطفاً یک ماده خام انتخاب کنید', Colors.orange);
      return;
    }

    final invoiceNumber = invoiceNumberController.text.trim();
    if (invoiceNumber.isEmpty) {
      _showSnackbar('لطفاً شماره بل را وارد کنید', Colors.orange);
      return;
    }

    final sellPrice = double.tryParse(sellPriceController.text.trim().replaceAll(',', '')) ?? 0;
    if (sellPrice <= 0) {
      _showSnackbar('لطفاً قیمت فروش معتبر وارد کنید', Colors.orange);
      return;
    }

    final currentDate = dateController.text.trim();
    final currentDateEn = selectedEnglishDate;
    
    // ✅ CALCULATE INIT PRICE (VALUE) FROM RAW MATERIAL
    double initPrice = 0;
    final selectedRM = _rawMaterials.firstWhere(
      (rm) => rm['id'].toString() == selectedRawMaterialId,
      orElse: () => {},
    );
    
    if (selectedRM.isNotEmpty) {
      double pureWeight = double.tryParse(selectedRM['net_weight']?.toString() ?? '0') ?? 0;
      double finalPrice = double.tryParse(selectedRM['final_price']?.toString() ?? '0') ?? 0;
      String unit = selectedRM['unit'] ?? 'kg';
      
      // Convert pure weight to tons if in kg
      double pureWeightInTons = pureWeight;
      if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
        pureWeightInTons = pureWeight / 1000;
      }
      
      // Price per ton
      double pricePerTon = 0;
      if (pureWeightInTons > 0 && finalPrice > 0) {
        pricePerTon = finalPrice / pureWeightInTons;
      }
      
      // Waste weight in kg from user input
      double wasteWeight = double.tryParse(weightController.text) ?? 0;
      if (wasteWeight > 0 && pricePerTon > 0) {
        // Convert waste weight to tons
        double wasteWeightInTons = wasteWeight / 1000;
        initPrice = wasteWeightInTons * pricePerTon;
      }
    }

    // ✅ DEBUG PRINT
    print('💰 WASTE VALUE (initPrice): $initPrice');
    print('💰 SELL PRICE: $sellPrice');
    print('💰 RAW MATERIAL ID: $selectedRawMaterialId');

    final afnEquivalent = double.tryParse(equivalentController.text.trim().replaceAll(',', '')) ?? 0;

    final payload = {
      'invoice_number': invoiceNumber,
      'date': currentDate,
      'date_en': currentDateEn,
      'party_details': partyDetailsController.text.trim(),
      'waste_type': wasteTypeController.text.trim(),
      'weight': double.tryParse(weightController.text) ?? 0,
      'quantity': (() {
        final q = double.tryParse(quantityController.text.trim()) ?? 0;
        return q > 0 ? q : 1;
      })(),
      'value': initPrice, // ✅ THIS IS THE WASTE VALUE - MUST BE SAVED!
      'currency': selectedCurrency,
      'exchange_rate': double.tryParse(priceRateController.text.replaceAll(',', '')) ?? 1,
      'description': descriptionController.text.trim(),
      'afn_equivalent': afnEquivalent,
      'is_sold': 1,
      'sell_currency': selectedCurrency,
      'sell_price': sellPrice,
      'sell_date': currentDate,
      'sell_date_en': currentDateEn,
      'sell_customer_name': sellCustomerNameController.text.trim(),
      'driver_name': driverNameController.text.trim(),
      'number_plate': numberPlateController.text.trim(),
      'raw_material_id': int.parse(selectedRawMaterialId!),
      'waste_unit_price': double.tryParse(wasteUnitPriceController.text.replaceAll(',', '')) ?? 0,
      'waste_final_price': double.tryParse(rawMaterialFinalPriceController.text.replaceAll(',', '')) ?? 0,
      'waste_raw_material_pure_weight': double.tryParse(rawMaterialPureWeightController.text.replaceAll(',', '')) ?? 0,
    };

    // ✅ DEBUG PRINT PAYLOAD
    print('📦 PAYLOAD: $payload');

    try {
      if (waste == null) {
        await _db.insertWasteRecord(payload);
      } else {
        await _db.updateWasteRecord(waste['id'], payload);
      }
      if (!mounted) return;
      Navigator.pop(context);
      await _loadWastes();
      _showSnackbar(
          waste == null
              ? 'ضایعات با موفقیت اضافه و فروخته شد ✅'
              : 'ضایعات با موفقیت ویرایش شد',
          Colors.green);
      _showInvoiceModal(context, invoiceNumber, payload);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('خطا در ذخیره ضایعات', Colors.red);
    }
  },
  icon: const Icon(Icons.save_outlined),
  label: Text(
      waste == null ? 'افزودن و فروش ضایعات' : 'ذخیره تغییرات'),
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
        title: const Text('حذف ضایعات'),
        content: const Text('آیا از حذف این رکورد اطمینان دارید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700),
              child: const Text('حذف')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.deleteWasteRecord(waste['id']);
      await _loadWastes();
      _showSnackbar('ضایعات با موفقیت حذف شد', Colors.orange);
    } catch (e) {
      _showSnackbar('خطا در حذف ضایعات', Colors.red);
    }
  }

  // ============================================
  // INVOICE MODAL
  // ============================================
  void _showInvoiceModal(BuildContext context, String invoiceNumber, Map<String, dynamic> invoice) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final dialogWidth = screenWidth * 0.9;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          child: Container(
            width: dialogWidth > 850 ? 850 : dialogWidth,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: SingleChildScrollView(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      key: _invoicePreviewKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              'بل فروش ضایعات',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                          ),
                          const SizedBox(height: 25),
                          _buildInvoiceUpperSection(invoice, invoiceNumber, l10n),
                          const SizedBox(height: 25),
                          _buildInvoiceTableWithData(invoice, l10n),
                          const SizedBox(height: 20),
                          _buildSaleFinancialSection(invoice, l10n),
                          const SizedBox(height: 20),
                          _buildInvoiceSignatureRow(),
                          const SizedBox(height: 25),
                          _buildInvoiceDriverSection(invoice),
                          const SizedBox(height: 15),
                          _buildInvoiceCustomerSection(invoice),
                          const SizedBox(height: 15),
                          _buildInvoiceLegalTerms(),
                          const SizedBox(height: 20),
                          _buildInvoiceOfficeRegistry(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(l10n.close, style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _saveInvoicePdf(invoice, invoiceNumber, l10n);
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                          label: Text(l10n.savePdf, style: const TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _printInvoicePdf(invoice, invoiceNumber, l10n);
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.print, size: 18, color: Colors.white),
                          label: Text(l10n.print, style: const TextStyle(fontSize: 12, color: Colors.white)),
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
          ),
        );
      },
    );
  }

Widget _buildSaleFinancialSection(Map<String, dynamic> invoice, AppLocalizations l10n) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black, width: 1),
      borderRadius: BorderRadius.circular(8),
      color: Colors.grey.shade50,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اطلاعات مالی ضایعات',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFCB001D)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSaleFinancialItem(
                'قیمت فروش',
                _formatNumber(invoice['sell_price']),
                invoice['sell_currency']?.toString() ?? 'USD',
                isTotal: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSaleFinancialItem(
                'نرخ ارز',
                invoice['exchange_rate']?.toString() ?? '1',
                '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSaleFinancialItem(
                'معادل افغانی',
                _formatNumber(invoice['afn_equivalent']),
                'AFN',
                isTotal: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSaleFinancialItem(
                'واحد پول',
                invoice['currency']?.toString() ?? 'USD',
                '',
              ),
            ),
          ],
        ),
        // ✅ REMOVED driver_name and number_plate from here - they're shown below
      ],
    ),
  );
}
  Widget _buildSaleFinancialItem(String label, String value, String currency, {bool isTotal = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isTotal ? const Color(0xFFCB001D).withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isTotal ? const Color(0xFFCB001D).withOpacity(0.3) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? const Color(0xFFCB001D) : Colors.grey.shade700,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                  color: isTotal ? const Color(0xFFCB001D) : const Color(0xFF1A1A2E),
                ),
              ),
              if (currency.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  currency,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceUpperSection(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('مشتری فروش', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Buyer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.black),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('مشخصات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      children: [
                        const Text('اسم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                            ),
                            child: Text(
                              invoice['sell_customer_name']?.toString() ?? '-',
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.black),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      children: [
                        const Text('شماره', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                            ),
                            child: Text(
                              invoiceNumber,
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
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
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      children: [
                        const Text('نوع ضایعات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                            ),
                            child: Text(
                              invoice['waste_type']?.toString() ?? '-',
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.black),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      children: [
                        const Text('تعداد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                            ),
                            child: Text(
                              invoice['quantity']?.toString() ?? '1',
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
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
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.black, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const Text('توضیحات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                          ),
                          child: Text(
                            invoice['description']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 30, color: Colors.black),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.black, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const Text('تاریخ میلادی', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                          ),
                          child: Text(
                            invoice['date_en']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 30, color: Colors.black),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    children: [
                      const Text('تاریخ شمسی', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                          ),
                          child: Text(
                            invoice['date']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTableWithData(Map<String, dynamic> invoice, AppLocalizations l10n) {
    const headerFont = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black);
    const bodyFont = TextStyle(fontSize: 11, color: Colors.black);

    String wasteType = invoice['waste_type']?.toString() ?? '-';
    String weight = invoice['weight']?.toString() ?? '0';
    String quantity = invoice['quantity']?.toString() ?? '1';
    double totalWeight = (double.tryParse(weight) ?? 0) * (double.tryParse(quantity) ?? 1);
    String displayWeight = _formatWeightWithConversion(double.tryParse(weight) ?? 0);
    String displayTotalWeight = _formatWeightWithConversion(totalWeight);

    final columnHeaders = [
      'شماره',
      'نوع ضایعات',
      'وزن (تن)',
      'تعداد',
      'مجموع وزن (تن)',
      'قیمت فروش',
    ];

    List<List<String>> tableData = [
      ['1', wasteType, displayWeight, quantity, displayTotalWeight, _formatNumber(invoice['sell_price'])],
    ];

    while (tableData.length < 10) {
      tableData.add(['', '', '', '', '', '']);
    }

    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: const {
        0: FixedColumnWidth(40),
        1: FixedColumnWidth(120),
        2: FixedColumnWidth(80),
        3: FixedColumnWidth(70),
        4: FixedColumnWidth(90),
        5: FixedColumnWidth(100),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.blue[100]),
          children: columnHeaders.map((title) => Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            alignment: Alignment.center,
            child: Text(title, style: headerFont, textAlign: TextAlign.center),
          )).toList(),
        ),
        ...tableData.map((row) => TableRow(
          children: row.map((cellValue) => Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            alignment: Alignment.center,
            child: Text(cellValue, style: bodyFont, textAlign: TextAlign.center),
          )).toList(),
        )),
        TableRow(
          decoration: BoxDecoration(color: Colors.blue[100]),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              alignment: Alignment.center,
              child: const Text('مجموعه :', style: headerFont),
            ),
            ...List.generate(2, (_) => const SizedBox.shrink()),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              alignment: Alignment.center,
              child: Text(quantity, style: headerFont),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              alignment: Alignment.center,
              child: Text(displayTotalWeight, style: headerFont),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              alignment: Alignment.center,
              child: Text(_formatNumber(invoice['sell_price']), style: headerFont),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoiceSignatureRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 60.0),
          child: Column(
            children: [
              const Text('امضا مسئول', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(width: 140, height: 1.2, color: Colors.black),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceDriverSection(Map<String, dynamic> invoice) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        children: [
          Container(
            color: Colors.blue[900],
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            child: const Text(
              'تسلیم دهی دریور:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: _buildInvoiceInlineInput('اسم :', invoice['driver_name']?.toString() ?? '')),
                const SizedBox(width: 15),
                Expanded(child: _buildInvoiceInlineInput('نمبر پلیت:', invoice['number_plate']?.toString() ?? '')),
                const SizedBox(width: 15),
                Expanded(child: _buildInvoiceInlineInput('امضا/شصت دریور:', '')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCustomerSection(Map<String, dynamic> invoice) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        children: [
          Container(
            color: Colors.blue[900],
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            child: const Text(
              'تسلیم دهی مشتری:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: _buildInvoiceInlineInput('اسم :', invoice['sell_customer_name']?.toString() ?? '')),
                const SizedBox(width: 15),
                Expanded(child: _buildInvoiceInlineInput('وظیفه:', '')),
                const SizedBox(width: 15),
                Expanded(child: _buildInvoiceInlineInput('مهر و امضا:', '')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceLegalTerms() {
    const termsStyleEn = TextStyle(fontSize: 10, color: Colors.black87);
    const termsStyleFa = TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black87);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Before carry, please check quality & quantity.', style: termsStyleEn, textDirection: TextDirection.ltr),
            Text('.لطفا قبل از انتقال کیفیت، تعداد ومقدار جنس را چک نمائید', style: termsStyleFa),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Transportation services will provide by carrier company against specified freight.', style: termsStyleEn, textDirection: TextDirection.ltr),
            Text('.خدمات ترانسپورتی درمقابل کرایه معین توسط شرکت باربری مهیا میگردد', style: termsStyleFa),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Terms & conditions of seller are applicable.', style: termsStyleEn, textDirection: TextDirection.ltr),
            Text('.مقررات و شرایط فروشنده قابل تطبیق میباشد', style: termsStyleFa),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoiceOfficeRegistry() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.yellow[600],
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            child: const Text(
              'مخصوص ثبت دفاتر:',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: _buildInvoiceInlineInput('شماره:', '')),
                const SizedBox(width: 10),
                Expanded(child: _buildInvoiceInlineInput('صفحه:', '')),
                const SizedBox(width: 10),
                Expanded(child: _buildInvoiceInlineInput('جلد:', '')),
                const SizedBox(width: 10),
                Expanded(child: _buildInvoiceInlineInput('مؤرخ:', '    /    /  ')),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _buildInvoiceInlineInput('امضا ثبت کننده:', '')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceInlineInput(String label, String explicitValue) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black54, width: 1)),
            ),
            child: Text(
              explicitValue,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // PDF GENERATION
  // ============================================
  Future<Uint8List> _generateInvoicePdfBytes(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
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

    double weight = double.tryParse(getPdfValue('weight')) ?? 0;
    double quantity = double.tryParse(getPdfValue('quantity', defaultValue: '1')) ?? 1;
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
            child: pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.7), borderRadius: pw.BorderRadius.circular(14)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.red, width: 2)),
                      color: PdfColors.white,
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          pw.Text('شرکت ویکتور', style: pw.TextStyle(font: ttf, fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                          pw.SizedBox(height: 6),
                          pw.Text('سیستم مدیریت یکپارچه', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
                        ]),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                          decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(10)),
                          child: pw.Text('بل فروش ضایعات', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(10)),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(child: pw.Text('مشتری فروش: ${getPdfValue('sell_customer_name')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black))),
                              pw.SizedBox(width: 12),
                              pw.Expanded(child: pw.Text('نوع ضایعات: ${getPdfValue('waste_type')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black))),
                              pw.SizedBox(width: 12),
                              pw.Expanded(child: pw.Text('تعداد: ${getPdfValue('quantity', defaultValue: '1')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black))),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 18),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(10)),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                                pw.Text('شماره بل: $invoiceNumber', style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 6),
                                pw.Text('تاریخ شمسی: ${getPdfValue('date')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                                pw.Text('Date (EN): ${getPdfValue('date_en')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                                pw.Text('دریور: ${getPdfValue('driver_name')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                                pw.Text('پلیت: ${getPdfValue('number_plate')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                              ]),
                              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                                pw.Text('واحد پول: ${getPdfValue('currency')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black)),
                                pw.SizedBox(height: 6),
                                pw.Text('وضعیت: ✅ فروخته شده', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.green)),
                              ]),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 18),
                        pw.Container(
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(10)),
                          child: pw.Table.fromTextArray(
                            border: pw.TableBorder.symmetric(outside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5), inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                            headerStyle: pw.TextStyle(font: ttf, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                            headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
                            cellStyle: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.black),
                            cellAlignment: pw.Alignment.center,
                            headers: [
                              'شماره',
                              'نوع ضایعات',
                              'وزن (تن)',
                              'تعداد',
                              'مجموع وزن (تن)',
                              'قیمت فروش',
                              'واحد پول',
                            ],
                            data: [
                              [
                                '1',
                                getPdfValue('waste_type'),
                                displayWeight,
                                getPdfValue('quantity', defaultValue: '1'),
                                displayTotalWeight,
                                _formatNumber(getPdfValue('sell_price')),
                                getPdfValue('currency'),
                              ],
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 18),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(10)),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                                pw.Text('نرخ ارز: ${getPdfValue('exchange_rate')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                                pw.Text('معادل افغانی: ${_formatNumber(getPdfValue('afn_equivalent'))} AFN', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                              ]),
                              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                                pw.SizedBox(height: 6),
                                pw.Text('قیمت فروش: ${_formatNumber(getPdfValue('sell_price'))} ${getPdfValue('sell_currency', defaultValue: getPdfValue('currency'))}', style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                              ]),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 24),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                              pw.Text('تاریخ چاپ: ${DateTime.now().year}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                              pw.SizedBox(height: 8),
                              pw.Text('امضا مسئول', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                              pw.SizedBox(height: 8),
                              pw.Container(height: 1, width: 140, color: PdfColors.grey600),
                            ]),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _saveInvoicePdf(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    try {
      Uint8List? bytes;

      try {
        if (_invoicePreviewKey.currentContext != null) {
          final boundary = _invoicePreviewKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
          if (boundary != null) {
            final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
            final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              final Uint8List pngBytes = byteData.buffer.asUint8List();
              final pw.Document pdf = pw.Document();
              final pw.MemoryImage pwImage = pw.MemoryImage(pngBytes);
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  build: (context) => pw.Center(child: pw.Image(pwImage, fit: pw.BoxFit.contain)),
                ),
              );
              bytes = await pdf.save();
            }
          }
        }
      } catch (e) {
        bytes = null;
      }

      bytes ??= await _generateInvoicePdfBytes(invoice, invoiceNumber, l10n);

      final String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.savePdf,
        fileName: 'waste_${invoiceNumber.replaceAll(' ', '_')}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (filePath == null) {
        return;
      }

      final File file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      _showSnackbar('${l10n.fileSaved}', Colors.green);
    } catch (e) {
      _showSnackbar('${l10n.errorPrintingInvoice}: $e', Colors.red);
    }
  }

  Future<void> _printInvoicePdf(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    try {
      Uint8List? bytes;

      try {
        if (_invoicePreviewKey.currentContext != null) {
          final boundary = _invoicePreviewKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
          if (boundary != null) {
            final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
            final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              final Uint8List pngBytes = byteData.buffer.asUint8List();
              final pw.Document pdf = pw.Document();
              final pw.MemoryImage pwImage = pw.MemoryImage(pngBytes);
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  build: (context) => pw.Center(child: pw.Image(pwImage, fit: pw.BoxFit.contain)),
                ),
              );
              bytes = await pdf.save();
            }
          }
        }
      } catch (e) {
        bytes = null;
      }

      bytes ??= await _generateInvoicePdfBytes(invoice, invoiceNumber, l10n);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes!,
        name: 'waste_${invoiceNumber.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      _showSnackbar('${l10n.errorPrintingInvoice}: $e', Colors.red);
    }
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
              child: const Icon(Icons.delete_outline, color: Color(0xFFCB001D),
                  size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مدیریت کسرات',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A)),
                ),
                const Text(
                  'ثبت و مدیریت ضایعات و کسرات',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _importExcel,
              icon: const Icon(Icons.upload_file, color: Color(0xFFCB001D),
                  size: 18),
              label: const Text('Import Excel',
                  style: TextStyle(color: Color(0xFFCB001D), fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCB001D)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => _showWasteDialog(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('ثبت کسرات جدید'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final totalWastes = _wastes.length;
    final totalAfn = _wastes.fold<double>(0, (sum, item) => sum +
        (double.tryParse(item['afn_equivalent']?.toString() ?? '0') ?? 0));
    final totalWeight = _wastes.fold<double>(0, (sum, item) => sum +
        (double.tryParse(item['weight']?.toString() ?? '0') ?? 0));
    final totalWeightInTons = totalWeight / 1000;
    final soldCount = _wastes.where((w) => w['is_sold'] == 1).length;
    final soldTotal = _wastes.fold<double>(0, (sum, item) => sum +
        (double.tryParse(item['sell_price']?.toString() ?? '0') ?? 0));

    return Row(
      children: [
        _buildStatCard('تعداد', totalWastes.toString(), Icons.delete_outline,
            const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard('فروخته شده', soldCount.toString(), Icons.sell,
            Colors.green.shade700),
        const SizedBox(width: 12),
        _buildStatCard('کل فروش', _formatNumber(soldTotal), Icons.attach_money,
            Colors.orange.shade700),
        const SizedBox(width: 12),
        _buildStatCard('جمع معادل افغانی', _formatNumber(totalAfn),
            Icons.currency_exchange, Colors.green.shade700),
        const SizedBox(width: 12),
        _buildStatCard('وزن (تن)',
            '${totalWeightInTons.toStringAsFixed(totalWeightInTons % 1 == 0 ? 0 : 3)} تن',
            Icons.scale, const Color(0xFFCB001D)),
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
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 20,
              offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A))),
          ])),
        ]),
      ),
    );
  }

  Widget _buildFilterAndSearch() {
    final filters = ['همه', 'کسرات', 'فروخته شده', 'فروخته نشده'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 20,
            offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'جستجو بر اساس طرف، نوع کسرات یا شماره...',
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCB001D),
                      width: 2)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ...filters.map((filter) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: FilterChip(
            label: Text(filter,
                style: TextStyle(
                    color: _selectedFilter == filter ? Colors.white : Colors
                        .grey.shade700,
                    fontWeight: FontWeight.w600)),
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

  // ==================== MAIN TABLE ====================
  Widget _buildMainTable() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFCB001D)));
    }

    if (_wastes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('هیچ ضایعاتی یافت نشد',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    final filteredData = _wastes.where((waste) {
      final search = _searchQuery.toLowerCase();
      final matchesSearch = (waste['party_details'] ?? '').toString()
          .toLowerCase()
          .contains(search) ||
          (waste['waste_type'] ?? '').toString().toLowerCase().contains(
              search) ||
          (waste['invoice_number'] ?? '').toString().toLowerCase().contains(
              search) ||
          (waste['description'] ?? '').toString().toLowerCase().contains(search) ||
          (waste['sell_customer_name'] ?? '').toString().toLowerCase().contains(
              search);

      if (_selectedFilter == 'فروخته شده') {
        return matchesSearch && waste['is_sold'] == 1;
      } else if (_selectedFilter == 'فروخته نشده') {
        return matchesSearch && waste['is_sold'] != 1;
      } else if (_selectedFilter == 'کسرات') {
        return matchesSearch && waste['waste_type']?.isNotEmpty == true;
      }

      return matchesSearch;
    }).toList();

    final totalPages = (filteredData.length / _rowsPerPage).ceil();
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = start + _rowsPerPage;
    final paged = filteredData.sublist(
      start,
      end > filteredData.length ? filteredData.length : end,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 20,
            offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== HEADER ROW =====
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB001D).withOpacity(0.05),
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200,
                                width: 1)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 40),
                          _buildHeaderCell('#', 50),
                          _buildHeaderCell('شماره بل', 100),
                          _buildHeaderCell('تاریخ', 100),
                          _buildHeaderCell('مشتری فروش', 140),
                          _buildHeaderCell('نوع کسرات', 130),
                          _buildHeaderCell('وزن (تن)', 90),
                          _buildHeaderCell('تعداد', 70),
                          _buildHeaderCell('مجموع وزن', 110),
                          _buildHeaderCell('قیمت فروش', 120),
                          _buildHeaderCell('واحد پول', 70),
                          _buildHeaderCell('نرخ تبدیل', 90),
                          _buildHeaderCell('معادل افغانی', 120),
                          _buildHeaderCell('دریور', 100),
                          _buildHeaderCell('پلیت', 100),
                          _buildHeaderCell('عملیات', 200),
                        ],
                      ),
                    ),
                    if (paged.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('هیچ داده‌ای یافت نشد',
                            style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...paged.asMap().entries.map((entry) {
                        final index = entry.key;
                        final waste = entry.value;
                        final id = waste['id'] as int;
                        final isSelected = _selectedWastes.contains(id);
                        bool isSold = waste['is_sold'] == 1;
                        String displayWeight = _getDisplayWeight(waste['weight']);
                        String totalWeightDisplay = _getTotalWeightDisplay(
                            waste['weight'], waste['quantity']);
                        String sellDisplay = isSold
                            ? '${_formatNumber(waste['sell_price'])}'
                            : '-';

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFCB001D)
                                .withOpacity(0.04) : null,
                            border: Border(
                                bottom: BorderSide(
                                    color: Colors.grey.shade100, width: 1)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleSelection(id),
                                  activeColor: const Color(0xFFCB001D),
                                  checkColor: Colors.white,
                                  materialTapTargetSize: MaterialTapTargetSize
                                      .shrinkWrap,
                                ),
                              ),
                              _buildDataCell((start + index + 1).toString(), 50),
                              _buildDataCell(
                                  waste['invoice_number']?.toString() ?? '-',
                                  100, isBold: true),
                              Container(
                                width: 100,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      waste['date_en'] ?? '-',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      waste['date'] ?? '-',
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
                              _buildDataCell(
                                  waste['sell_customer_name']?.toString() ?? '-',
                                  140),
                              _buildDataCell(
                                  waste['waste_type']?.toString() ?? '-', 130),
                              _buildDataCell(displayWeight, 90),
                              _buildDataCell(
                                  (waste['quantity'] != null && waste[
                                      'quantity'] != 1 && waste['quantity'] != 0)
                                      ? _formatNumber(waste['quantity'])
                                      : '-',
                                  70),
                              _buildDataCell(totalWeightDisplay, 110,
                                  isBold: true, color: const Color(0xFFCB001D)),
                              _buildDataCell(sellDisplay, 120,
                                  isBold: true, color: Colors.green.shade700),
                              _buildDataCell(
                                  waste['currency']?.toString() ?? '-', 70),
                              _buildDataCell(
                                  _formatNumber(waste['exchange_rate']), 90),
                              _buildDataCell(
                                  _formatNumber(waste['afn_equivalent']), 120),
                              _buildDataCell(
                                  waste['driver_name']?.toString() ?? '-', 100),
                              _buildDataCell(
                                  waste['number_plate']?.toString() ?? '-', 100),
                              SizedBox(
                                width: 200,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () => _showWasteDialog(
                                          waste: waste),
                                      icon: Icon(Icons.edit_outlined,
                                          color: Colors.blue.shade700, size: 20),
                                      constraints: const BoxConstraints(
                                          minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'ویرایش',
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteWaste(waste),
                                      icon: Icon(Icons.delete_outline,
                                          color: Colors.red.shade400, size: 20),
                                      constraints: const BoxConstraints(
                                          minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'حذف',
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        _showInvoiceModal(context, waste['invoice_number'] ?? '-', waste);
                                      },
                                      icon: const Icon(Icons.visibility_outlined,
                                          color: Color(0xFFCB001D), size: 20),
                                      constraints: const BoxConstraints(
                                          minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'مشاهده فاکتور',
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await _printInvoicePdf(waste, waste['invoice_number'] ?? '-', AppLocalizations.of(context)!);
                                      },
                                      icon: const Icon(Icons.print_outlined,
                                          color: Color(0xFFCB001D), size: 20),
                                      constraints: const BoxConstraints(
                                          minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'چاپ',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
          // ===== FOOTER (Pagination) =====
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('نمایش',
                        style: TextStyle(fontSize: 12,
                            color: Color(0xFF888888))),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFFCB001D).withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _rowsPerPage,
                          onChanged: _changeItemsPerPage,
                          items: _pageSizeOptions.map((size) {
                            return DropdownMenuItem<int>(
                              value: size,
                              child: Text(size.toString(),
                                  style: const TextStyle(
                                      color: Color(0xFF1A1A2E), fontSize: 12)),
                            );
                          }).toList(),
                          dropdownColor: Colors.white,
                          icon: Icon(Icons.arrow_drop_down,
                              color: const Color(0xFFCB001D), size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('در هر صفحه',
                        style: TextStyle(fontSize: 12,
                            color: Colors.grey.shade600)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Color(0xFFCB001D), size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30),
                      onPressed: () {
                        _scrollController.animateTo(
                          _scrollController.offset - 300,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      tooltip: 'اسکرول به چپ',
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios,
                          color: Color(0xFFCB001D), size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30),
                      onPressed: () {
                        _scrollController.animateTo(
                          _scrollController.offset + 300,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      tooltip: 'اسکرول به راست',
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'صفحه $_currentPage از ${totalPages == 0 ? 1 : totalPages}',
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF888888)),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: Color(0xFFCB001D), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _currentPage > 1
                          ? () => _changePage(_currentPage - 1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left,
                          color: Color(0xFFCB001D), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _currentPage < totalPages
                          ? () => _changePage(_currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedWastes.contains(id)) {
        _selectedWastes.remove(id);
      } else {
        _selectedWastes.add(id);
      }
    });
  }

  void _changePage(int newPage) {
    final totalPages = (_wastes.length / _rowsPerPage).ceil();
    if (newPage >= 1 && newPage <= totalPages) {
      setState(() {
        _currentPage = newPage;
        _selectedWastes.clear();
      });
    }
  }

  void _changeItemsPerPage(int? newSize) {
    if (newSize != null) {
      setState(() {
        _rowsPerPage = newSize;
        _currentPage = 1;
        _selectedWastes.clear();
      });
    }
  }

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: Color(0xFF1A1A2E),
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(String text, double width,
      {bool isBold = false, Color? color}) {
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int maxLines = 1,
    Function(String)? onChanged,
    VoidCallback? onTap,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: const Color(0xFFCB001D), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onChanged: onChanged,
      onTap: onTap,
    );
  }

  String _formatNumber(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '0') ?? 0;
    return parsed.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
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
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildQuickStats(),
              const SizedBox(height: 20),
              _buildFilterAndSearch(),
              const SizedBox(height: 16),
              Expanded(child: _buildMainTable()),
            ],
          ),
        ),
      ),
    );
  }
}
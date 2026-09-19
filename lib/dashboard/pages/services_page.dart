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
  final GlobalKey _invoicePreviewKey = GlobalKey();

  // ============================================
  // SERVICE ITEMS - For multi-service support
  // ============================================
  List<Map<String, dynamic>> _serviceItems = [];
  int _nextServiceItemIndex = 1;

  // Helper to convert kg to tons
  String _formatWeightWithConversion(double weight) {
    if (weight <= 0) return '0';
    double tons = weight / 1000;
    if (tons < 1) {
      return '${tons.toStringAsFixed(3)} تن';
    }
    return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
  }

  String _formatWeightForDisplay(double weight, String unit) {
    if (unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم') {
      return _formatWeightWithConversion(weight);
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 2)} $unit';
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
        await _loadServices();
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
        return {'success': false, 'message': 'فایل اکسل خراب است یا فرمت آن پشتیبانی نمی‌شود'};
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

    print('📋 Headers: $headers');

    int invoiceNumberIndex = -1;
    int customerNameIndex = -1;
    int customerPhoneIndex = -1;
    int customerAddressIndex = -1;
    int serviceTypeIndex = -1;
    int sizeIndex = -1;
    int thicknessIndex = -1;
    int totalWeightIndex = -1;
    int unitIndex = -1;
    int unitPriceIndex = -1;
    int totalPriceIndex = -1;
    int currencyIndex = -1;
    int exchangeRateIndex = -1;
    int loadingCostIndex = -1;
    int transferCostIndex = -1;
    int clearanceCostIndex = -1;
    int discountIndex = -1;
    int finalPriceIndex = -1;
    int afnEquivalentIndex = -1;
    int dateIndex = -1;

    for (int i = 0; i < headers.length; i++) {
      String h = headers[i];
      String hLower = h.toLowerCase();
      
      if (hLower.contains('نمبر') || hLower.contains(' بل') || hLower.contains('invoice')) {
        invoiceNumberIndex = i;
      } else if (hLower.contains('مشتری') || hLower.contains('خریدار') || hLower.contains('customer')) {
        customerNameIndex = i;
      } else if (hLower.contains('تلفن') || hLower.contains('phone')) {
        customerPhoneIndex = i;
      } else if (hLower.contains('آدرس') || hLower.contains('address')) {
        customerAddressIndex = i;
      } else if (hLower.contains('نوع خدمت') || hLower.contains('service') || hLower.contains('خدمت')) {
        serviceTypeIndex = i;
      } else if (hLower.contains('سایز') || hLower.contains('size')) {
        sizeIndex = i;
      } else if (hLower.contains('ضخامت') || hLower.contains('thickness')) {
        thicknessIndex = i;
      } else if (hLower.contains('وزن کل') || hLower.contains('total weight')) {
        totalWeightIndex = i;
      } else if (hLower.contains('واحد') && !hLower.contains('پول')) {
        unitIndex = i;
      } else if (hLower.contains('قیمت واحد') || hLower.contains('unit price')) {
        unitPriceIndex = i;
      } else if (hLower.contains('قیمت کل') || hLower.contains('total price')) {
        totalPriceIndex = i;
      } else if (hLower.contains('ارز') || hLower.contains('واحد پول') || hLower.contains('currency')) {
        currencyIndex = i;
      } else if (hLower.contains('نرخ') || hLower.contains('exchange') || hLower.contains('rate')) {
        exchangeRateIndex = i;
      } else if (hLower.contains('بارگیری') || hLower.contains('loading')) {
        loadingCostIndex = i;
      } else if (hLower.contains('حمل') || hLower.contains('transfer')) {
        transferCostIndex = i;
      } else if (hLower.contains('ترخیص') || hLower.contains('clearance')) {
        clearanceCostIndex = i;
      } else if (hLower.contains('تخفیف') || hLower.contains('discount')) {
        discountIndex = i;
      } else if (hLower.contains('قیمت نهایی') || hLower.contains('final price')) {
        finalPriceIndex = i;
      } else if (hLower.contains('معادل') || hLower.contains('afn') || hLower.contains('افغانی')) {
        afnEquivalentIndex = i;
      } else if (hLower.contains('تاریخ') || hLower.contains('date')) {
        dateIndex = i;
      }
    }

    print('📋 InvoiceNumber: $invoiceNumberIndex, Customer: $customerNameIndex');

    if (invoiceNumberIndex == -1 || customerNameIndex == -1) {
      return {
        'success': false,
        'message': 'فیلدهای مورد نیاز پیدا نشد: شماره فاکتور، مشتری'
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
        String invoiceNumber = _getCellValueDirect(row, invoiceNumberIndex);
        String customerName = _getCellValueDirect(row, customerNameIndex);
        String customerPhone = customerPhoneIndex != -1 ? _getCellValueDirect(row, customerPhoneIndex) : '';
        String customerAddress = customerAddressIndex != -1 ? _getCellValueDirect(row, customerAddressIndex) : '';
        String serviceType = serviceTypeIndex != -1 ? _getCellValueDirect(row, serviceTypeIndex) : '';
        String size = sizeIndex != -1 ? _getCellValueDirect(row, sizeIndex) : '';
        String thickness = thicknessIndex != -1 ? _getCellValueDirect(row, thicknessIndex) : '';
        String totalWeightStr = totalWeightIndex != -1 ? _getCellValueDirect(row, totalWeightIndex) : '0';
        String unit = unitIndex != -1 ? _getCellValueDirect(row, unitIndex) : 'TON';
        String unitPriceStr = unitPriceIndex != -1 ? _getCellValueDirect(row, unitPriceIndex) : '0';
        String totalPriceStr = totalPriceIndex != -1 ? _getCellValueDirect(row, totalPriceIndex) : '0';
        String currency = currencyIndex != -1 ? _getCellValueDirect(row, currencyIndex) : 'USD';
        String exchangeRateStr = exchangeRateIndex != -1 ? _getCellValueDirect(row, exchangeRateIndex) : '1';
        String loadingCostStr = loadingCostIndex != -1 ? _getCellValueDirect(row, loadingCostIndex) : '0';
        String transferCostStr = transferCostIndex != -1 ? _getCellValueDirect(row, transferCostIndex) : '0';
        String clearanceCostStr = clearanceCostIndex != -1 ? _getCellValueDirect(row, clearanceCostIndex) : '0';
        String discountStr = discountIndex != -1 ? _getCellValueDirect(row, discountIndex) : '0';
        String finalPriceStr = finalPriceIndex != -1 ? _getCellValueDirect(row, finalPriceIndex) : '0';
        String afnEquivalentStr = afnEquivalentIndex != -1 ? _getCellValueDirect(row, afnEquivalentIndex) : '0';
        String date = dateIndex != -1 ? _getCellValueDirect(row, dateIndex) : '';

        totalWeightStr = totalWeightStr.replaceAll(RegExp(r'[$,]'), '').trim();
        unitPriceStr = unitPriceStr.replaceAll(RegExp(r'[$,]'), '').trim();
        totalPriceStr = totalPriceStr.replaceAll(RegExp(r'[$,]'), '').trim();
        loadingCostStr = loadingCostStr.replaceAll(RegExp(r'[$,]'), '').trim();
        transferCostStr = transferCostStr.replaceAll(RegExp(r'[$,]'), '').trim();
        clearanceCostStr = clearanceCostStr.replaceAll(RegExp(r'[$,]'), '').trim();
        discountStr = discountStr.replaceAll(RegExp(r'[$,]'), '').trim();
        finalPriceStr = finalPriceStr.replaceAll(RegExp(r'[$,]'), '').trim();
        afnEquivalentStr = afnEquivalentStr.replaceAll(RegExp(r'[$,]'), '').trim();
        exchangeRateStr = exchangeRateStr.replaceAll(RegExp(r'[$,]'), '').trim();

        print('📝 Row ${i+1}: Invoice="$invoiceNumber", Customer="$customerName"');

        if (invoiceNumber.isEmpty || customerName.isEmpty) {
          skippedCount++;
          errors.add('ردیف ' + (i+1).toString() + ': فیلدهای مورد نیاز کامل نیستند');
          continue;
        }

        final existing = await _db.getServiceInvoiceByNumber(invoiceNumber);
        if (existing != null) {
          skippedCount++;
          errors.add('ردیف ' + (i+1).toString() + ': شماره فاکتور "' + invoiceNumber + '" تکراری است');
          continue;
        }

        double totalWeight = _parseNumber(totalWeightStr);
        double unitPrice = _parseNumber(unitPriceStr);
        double totalPrice = _parseNumber(totalPriceStr);
        double loadingCost = _parseNumber(loadingCostStr);
        double transferCost = _parseNumber(transferCostStr);
        double clearanceCost = _parseNumber(clearanceCostStr);
        double discount = _parseNumber(discountStr);
        double finalPrice = _parseNumber(finalPriceStr);
        double afnEquivalent = _parseNumber(afnEquivalentStr);
        double exchangeRate = _parseNumber(exchangeRateStr);

        if (exchangeRate <= 0) exchangeRate = 1;

        String unitNormalized = unit.trim().toLowerCase();
        bool isKiloUnit = unitNormalized == 'kg' || 
                          unitNormalized == 'کیلو' || 
                          unitNormalized == 'کیلوگرم' || 
                          unitNormalized == 'kilo' ||
                          unitNormalized == 'kgs';

        String unitFinal = isKiloUnit ? 'KG' : 'TON';
        print('📏 Unit raw: "$unit" → normalized: "$unitFinal"');

        double totalWeightInTons = isKiloUnit ? totalWeight / 1000 : totalWeight;
        
        if (totalPrice <= 0 && unitPrice > 0 && totalWeightInTons > 0) {
          totalPrice = totalWeightInTons * unitPrice;
          print('💰 Calculated totalPrice: $totalWeightInTons ton × $unitPrice = $totalPrice');
        }

        String currencyFinal = currency == 'AFN' || currency == 'افغانی' || currency.toLowerCase() == 'afn' 
            ? 'AFN' 
            : 'USD';

        double loadingCostUSD = currencyFinal == 'USD' ? loadingCost / exchangeRate : loadingCost;
        double transferCostUSD = currencyFinal == 'USD' ? transferCost / exchangeRate : transferCost;
        double clearanceCostUSD = currencyFinal == 'USD' ? clearanceCost / exchangeRate : clearanceCost;
        double discountUSD = currencyFinal == 'USD' ? discount / exchangeRate : discount;

        if (finalPrice <= 0 && totalPrice > 0) {
          finalPrice = totalPrice + loadingCostUSD + transferCostUSD + clearanceCostUSD - discountUSD;
        }

        if (currencyFinal == 'USD') {
          afnEquivalent = finalPrice * exchangeRate;
        } else {
          afnEquivalent = exchangeRate > 0 ? finalPrice / exchangeRate : 0;
        }

        if (date.isEmpty) {
          date = PersianDateConverter.gregorianToJalali(DateTime.now());
        }
        String dateEn = PersianDateConverter.getEnglishDate(DateTime.now());

        Map<String, dynamic> service = {
          'invoice_number': invoiceNumber,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_address': customerAddress,
          'service_type': serviceType,
          'size': size,
          'thickness': thickness,
          'total_weight': totalWeightInTons,
          'unit': 'TON',
          'unit_price': unitPrice,
          'total_price': totalPrice > 0 ? totalPrice : finalPrice,
          'currency': currencyFinal,
          'exchange_rate': exchangeRate,
          'loading_cost': loadingCost,
          'transfer_cost': transferCost,
          'clearance_cost': clearanceCost,
          'discount': discount,
          'final_price': finalPrice > 0 ? finalPrice : totalPrice,
          'afn_equivalent': afnEquivalent,
          'date': date,
          'date_en': dateEn,
        };

        int result = await _db.insertServiceInvoice(service);
        if (result != -1) {
          successCount++;
          importedData.add(service);
        } else {
          skippedCount++;
          errors.add('ردیف ' + (i+1).toString() + ': خطا در ذخیره‌سازی');
        }

      } catch (e) {
        skippedCount++;
        errors.add('ردیف ' + (i+1).toString() + ': خطا - ' + e.toString());
        print('❌ Error: $e');
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
    print('❌ Error: $e');
    return {
      'success': false,
      'message': 'خطا در پردازش فایل: $e',
    };
  }
}

  void _showImportResultDialog(BuildContext context, Map<String, dynamic> result) {
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
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
                if (result['skippedCount'] > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ ${result['skippedCount']} رکورد نادیده گرفته شد',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
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
                                  style: const TextStyle(fontSize: 11, color: Colors.red),
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
      
      // Group services by invoice_number
      final Map<String, List<Map<String, dynamic>>> groupedServices = {};
      for (var service in services) {
        final invoiceNumber = service['invoice_number']?.toString() ?? 'unknown';
        if (!groupedServices.containsKey(invoiceNumber)) {
          groupedServices[invoiceNumber] = [];
        }
        groupedServices[invoiceNumber]!.add(service);
      }
      
      // Convert grouped to a list of consolidated services
      final List<Map<String, dynamic>> consolidatedServices = [];
      for (var entry in groupedServices.entries) {
        final items = entry.value;
        final firstItem = items.first;
        
        final consolidated = Map<String, dynamic>.from(firstItem);
        consolidated['items'] = items;
        
        double totalWeight = 0;
        double totalPrice = 0;
        double totalFinalPrice = 0;
        String unit = 'TON';
        
        for (var item in items) {
          final weight = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
          final price = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
          final fPrice = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0;
          totalWeight += weight;
          totalPrice += price;
          totalFinalPrice = fPrice;
          if (item['unit'] != null) unit = item['unit'].toString();
        }
        
        consolidated['total_weight'] = totalWeight;
        consolidated['total_price'] = totalPrice;
        consolidated['final_price'] = totalFinalPrice;
        consolidated['unit'] = unit;
        consolidated['service_count'] = items.length;
        
        final serviceTypes = items.map((item) => item['service_type']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
        consolidated['service_types'] = serviceTypes;
        consolidated['display_services'] = serviceTypes.join('، ');
        
        consolidatedServices.add(consolidated);
      }
      
      consolidatedServices.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
      
      if (!mounted) return;
      setState(() {
        _services = consolidatedServices;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar(l10n.errorLoadingServices, Colors.red);
    }
  }

  // ============================================
  // SERVICE DIALOG WITH MULTI-SERVICE SUPPORT
  // ============================================
  Future<void> _showServiceDialog({Map<String, dynamic>? service}) async {
    final l10n = AppLocalizations.of(context)!;
    
    // Reset service items
    _serviceItems = [];
    _nextServiceItemIndex = 1;
    
    // Main invoice controllers
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
    
    // Exchange rate controller
    final exchangeRateController = TextEditingController(
      text: service?['exchange_rate']?.toString() ?? '65'
    );
    
    // Expense Controllers - Shared across all service items (in AFN)
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
    
    final dateController = TextEditingController(
      text: service?['date']?.toString() ?? PersianDateConverter.getCurrentPersianDate()
    );
    String selectedCurrency = service?['currency']?.toString() ?? 'USD';
    String selectedEnglishDate = service?['date_en']?.toString() ?? 
        PersianDateConverter.getEnglishDate(DateTime.now());

    // Add initial empty service item
    _serviceItems.add({
      'id': _nextServiceItemIndex++,
      'service_type': '',
      'size': '',
      'thickness': '',
      'total_weight': 0.0,
      'unit': 'TON',
      'unit_price': 0.0,
      'total_price': 0.0,
      'serviceTypeCtrl': TextEditingController(),
      'sizeCtrl': TextEditingController(),
      'thicknessCtrl': TextEditingController(),
      'weightCtrl': TextEditingController(),
      'unitPriceCtrl': TextEditingController(),
    });

    // Helper function to calculate totals
    double getTotalWeight() {
      double total = 0;
      for (var item in _serviceItems) {
        double weight = item['total_weight'] ?? 0;
        String unit = item['unit'] ?? 'TON';
        if (unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم') {
          total += weight / 1000;
        } else {
          total += weight;
        }
      }
      return total;
    }

    double getTotalPrice() {
      double total = 0;
      for (var item in _serviceItems) {
        total += item['total_price'] ?? 0;
      }
      return total;
    }

    void updateServiceItemTotals(Map<String, dynamic> item) {
      double totalWeight = item['total_weight'] ?? 0;
      String unit = item['unit'] ?? 'TON';
      double unitPrice = item['unit_price'] ?? 0;
      
      double totalWeightInTons = (unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم') ? totalWeight / 1000 : totalWeight;
      double totalPrice = totalWeightInTons * unitPrice;
      
      item['total_price'] = totalPrice;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double totalWeight = getTotalWeight();
          double totalPrice = getTotalPrice();
          double exchangeRate = double.tryParse(exchangeRateController.text) ?? 65;
          
          // Get expense values (ALWAYS IN AFN)
          double loadingCost = double.tryParse(loadingController.text) ?? 0;
          double transferCost = double.tryParse(transferController.text) ?? 0;
          double clearanceCost = double.tryParse(clearanceController.text) ?? 0;
          double discount = double.tryParse(discountController.text) ?? 0;
          
          // ✅ Calculate based on selected currency
          double finalPrice;
          double oppositeEquivalent;
          String oppositeLabel;
          
          if (selectedCurrency == 'AFN') {
            // When AFN: totalPrice is already in AFN
            // Expenses are also in AFN, so no conversion needed
            finalPrice = totalPrice + loadingCost + transferCost + clearanceCost - discount;
            // Opposite (USD) = AFN / exchangeRate
            oppositeEquivalent = exchangeRate > 0 ? finalPrice / exchangeRate : 0;
            oppositeLabel = 'معادل به دالر (USD)';
          } else {
            // When USD: totalPrice is in USD
            // Expenses are in AFN - convert to USD
            double loadingCostUSD = exchangeRate > 0 ? loadingCost / exchangeRate : 0;
            double transferCostUSD = exchangeRate > 0 ? transferCost / exchangeRate : 0;
            double clearanceCostUSD = exchangeRate > 0 ? clearanceCost / exchangeRate : 0;
            double discountUSD = exchangeRate > 0 ? discount / exchangeRate : 0;
            
            finalPrice = totalPrice + loadingCostUSD + transferCostUSD + clearanceCostUSD - discountUSD;
            // Opposite (AFN) = USD * exchangeRate
            oppositeEquivalent = finalPrice * exchangeRate;
            oppositeLabel = 'معادل به افغانی (AFN)';
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                service == null ? l10n.addNewService : l10n.editServiceLabel2,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: SizedBox(
                width: 900,
                height: MediaQuery.of(context).size.height * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invoice Header
                      _buildSectionTitle('اطلاعات فاکتور', l10n),
                      const SizedBox(height: 8),
                      
                      _buildTextField(
                        controller: invoiceNumberController,
                        label: l10n.invoiceNumberLabel,
                        icon: Icons.numbers,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      
                      _buildTextField(
                        controller: customerNameController, 
                        label: l10n.customerName, 
                        icon: Icons.person_outline, 
                        l10n: l10n
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: customerPhoneController, 
                              label: l10n.customerPhone, 
                              icon: Icons.phone_outlined, 
                              keyboardType: TextInputType.phone, 
                              l10n: l10n
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: customerAddressController, 
                              label: l10n.customerAddress, 
                              icon: Icons.location_on_outlined, 
                              l10n: l10n
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // SERVICE ITEMS SECTION
                      _buildSectionTitle('خدمات', l10n),
                      const SizedBox(height: 8),
                      
                      ..._serviceItems.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> item = entry.value;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'خدمت ${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFFCB001D),
                                    ),
                                  ),
                                  if (_serviceItems.length > 1)
                                    IconButton(
                                      onPressed: () {
                                        setDialogState(() {
                                          _serviceItems.removeAt(index);
                                        });
                                      },
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Service Type
                              _buildTextField(
                                controller: item['serviceTypeCtrl'] as TextEditingController,
                                label: l10n.serviceTypeLabel2,
                                icon: Icons.design_services_outlined,
                                l10n: l10n,
                                onChanged: (value) {
                                  item['service_type'] = value;
                                  setDialogState(() {});
                                },
                              ),
                              const SizedBox(height: 8),
                              
                              // Size & Thickness
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: item['sizeCtrl'] as TextEditingController,
                                      label: l10n.size,
                                      icon: Icons.aspect_ratio_outlined,
                                      l10n: l10n,
                                      onChanged: (value) {
                                        item['size'] = value;
                                        setDialogState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: item['thicknessCtrl'] as TextEditingController,
                                      label: l10n.thickness,
                                      icon: Icons.straighten_outlined,
                                      l10n: l10n,
                                      onChanged: (value) {
                                        item['thickness'] = value;
                                        setDialogState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Weight & Unit
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildTextField(
                                          controller: item['weightCtrl'] as TextEditingController,
                                          label: l10n.totalWeight,
                                          icon: Icons.monitor_weight_outlined,
                                          keyboardType: TextInputType.number,
                                          l10n: l10n,
                                          onChanged: (value) {
                                            item['total_weight'] = double.tryParse(value) ?? 0;
                                            updateServiceItemTotals(item);
                                            setDialogState(() {});
                                          },
                                        ),
                                        if (item['total_weight'] != null && item['total_weight'] > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                              ),
                                              child: Text(
                                                item['unit'] == 'KG' || item['unit'] == 'kg' 
                                                    ? '${item['total_weight']} kg = ${(item['total_weight'] / 1000).toStringAsFixed(2)} تن'
                                                    : '${item['total_weight']} تن',
                                                style: const TextStyle(fontSize: 10, color: Colors.blue),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: item['unit'] ?? 'TON',
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
                                          item['unit'] = value;
                                          updateServiceItemTotals(item);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Unit Price & Total Price
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: item['unitPriceCtrl'] as TextEditingController,
                                      label: '${l10n.unitPrice} (قیمت هر تن)',
                                      icon: Icons.price_check_outlined,
                                      keyboardType: TextInputType.number,
                                      l10n: l10n,
                                      onChanged: (value) {
                                        item['unit_price'] = double.tryParse(value) ?? 0;
                                        updateServiceItemTotals(item);
                                        setDialogState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: TextEditingController(
                                        text: item['total_price'] != null && item['total_price'] > 0 
                                            ? item['total_price'].toStringAsFixed(0) 
                                            : ''
                                      ),
                                      label: l10n.totalPrice,
                                      icon: Icons.attach_money_outlined,
                                      readOnly: true,
                                      l10n: l10n,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      
                      // Add service button
                      ElevatedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            _serviceItems.add({
                              'id': _nextServiceItemIndex++,
                              'service_type': '',
                              'size': '',
                              'thickness': '',
                              'total_weight': 0.0,
                              'unit': 'TON',
                              'unit_price': 0.0,
                              'total_price': 0.0,
                              'serviceTypeCtrl': TextEditingController(),
                              'sizeCtrl': TextEditingController(),
                              'thicknessCtrl': TextEditingController(),
                              'weightCtrl': TextEditingController(),
                              'unitPriceCtrl': TextEditingController(),
                            });
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('افزودن خدمت'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: const Color(0xFFCB001D),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Expenses Section (ALL IN AFN)
                      _buildSectionTitle('هزینه‌ها (به افغانی)', l10n),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: loadingController,
                              label: 'هزینه بارگیری (AFN)',
                              icon: Icons.local_shipping_outlined,
                              keyboardType: TextInputType.number,
                              l10n: l10n,
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: transferController,
                              label: 'هزینه حمل (AFN)',
                              icon: Icons.drive_eta_outlined,
                              keyboardType: TextInputType.number,
                              l10n: l10n,
                              onChanged: (_) => setDialogState(() {}),
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
                              label: 'هزینه ترخیص (AFN)',
                              icon: Icons.inventory_2_outlined,
                              keyboardType: TextInputType.number,
                              l10n: l10n,
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: discountController,
                              label: 'تخفیف (AFN)',
                              icon: Icons.discount_outlined,
                              keyboardType: TextInputType.number,
                              l10n: l10n,
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Exchange Rate & Currency Section
                      _buildSectionTitle('نرخ ارز و ارز', l10n),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: exchangeRateController,
                              label: 'نرخ ارز (USD به AFN) *',
                              icon: Icons.currency_exchange,
                              keyboardType: TextInputType.number,
                              l10n: l10n,
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Financial Summary
                      _buildSectionTitle(l10n.financialInfo, l10n),
                      const SizedBox(height: 8),
                      
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildFinancialSummaryItem(
                                'مجموع وزن',
                                '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2)} تن',
                                const Color(0xFFCB001D),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFinancialSummaryItem(
                                'قیمت کل (${selectedCurrency})',
                                '${selectedCurrency == 'AFN' ? 'AFN ' : '\$'}${totalPrice.toStringAsFixed(0)}',
                                const Color(0xFFCB001D),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFinancialSummaryItem(
                                'تعداد خدمات',
                                _serviceItems.length.toString(),
                                Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFinancialSummaryItem(
                                'قیمت نهایی (${selectedCurrency})',
                                '${selectedCurrency == 'AFN' ? 'AFN ' : '\$'}${finalPrice.toStringAsFixed(2)}',
                                const Color(0xFFCB001D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Opposite Currency Equivalent
                      _buildTextField(
                        controller: TextEditingController(
                          text: oppositeEquivalent.toStringAsFixed(2)
                        ),
                        label: oppositeLabel,
                        icon: Icons.currency_exchange,
                        readOnly: true,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      
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
                    final customerName = customerNameController.text.trim();
                    
                    if (invoiceNumber.isEmpty) {
                      _showSnackbar('شماره فاکتور الزامی است', Colors.red);
                      return;
                    }
                    
                    if (customerName.isEmpty) {
                      _showSnackbar('نام مشتری الزامی است', Colors.red);
                      return;
                    }
                    
                    // Check if any service item has valid data
                    bool hasValidItem = false;
                    for (var item in _serviceItems) {
                      if ((item['service_type'] != null && item['service_type']!.toString().isNotEmpty) &&
                          (item['total_weight'] ?? 0) > 0) {
                        hasValidItem = true;
                        break;
                      }
                    }
                    if (!hasValidItem) {
                      _showSnackbar('حداقل یک خدمت معتبر باید انتخاب شود', Colors.red);
                      return;
                    }
                    
                    if (service == null) {
                      final existing = await _db.getServiceInvoiceByNumber(invoiceNumber);
                      if (existing != null) {
                        _showSnackbar('این شماره فاکتور قبلاً ثبت شده است', Colors.red);
                        return;
                      }
                    }
                    
                    // Calculate totals from all items
                    double totalWeight = 0;
                    double totalPrice = 0;
                    for (var item in _serviceItems) {
                      double weight = item['total_weight'] ?? 0;
                      String unit = item['unit'] ?? 'TON';
                      if (unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم') {
                        totalWeight += weight / 1000;
                      } else {
                        totalWeight += weight;
                      }
                      totalPrice += item['total_price'] ?? 0;
                    }
                    
                    double exchangeRate = double.tryParse(exchangeRateController.text) ?? 65;
                    
                    // Get expense values (ALWAYS IN AFN)
                    double loadingCost = double.tryParse(loadingController.text) ?? 0;
                    double transferCost = double.tryParse(transferController.text) ?? 0;
                    double clearanceCost = double.tryParse(clearanceController.text) ?? 0;
                    double discount = double.tryParse(discountController.text) ?? 0;
                    
                    // ✅ Calculate based on selected currency
                    double finalPrice;
                    double oppositeEquivalent;
                    
                    if (selectedCurrency == 'AFN') {
                      // AFN: totalPrice is in AFN
                      // Expenses are in AFN, no conversion
                      finalPrice = totalPrice + loadingCost + transferCost + clearanceCost - discount;
                      // ✅ Save USD equivalent (AFN / rate)
                      oppositeEquivalent = exchangeRate > 0 ? finalPrice / exchangeRate : 0;
                    } else {
                      // USD: totalPrice is in USD
                      // Expenses are in AFN - convert to USD
                      double loadingCostUSD = exchangeRate > 0 ? loadingCost / exchangeRate : 0;
                      double transferCostUSD = exchangeRate > 0 ? transferCost / exchangeRate : 0;
                      double clearanceCostUSD = exchangeRate > 0 ? clearanceCost / exchangeRate : 0;
                      double discountUSD = exchangeRate > 0 ? discount / exchangeRate : 0;
                      
                      finalPrice = totalPrice + loadingCostUSD + transferCostUSD + clearanceCostUSD - discountUSD;
                      // ✅ Save AFN equivalent (USD * rate)
                      oppositeEquivalent = finalPrice * exchangeRate;
                    }
                    
                    // Create separate invoice rows for each service item with SAME invoice number
                    List<int> insertedIds = [];
                    
                    for (var item in _serviceItems) {
                      if ((item['service_type'] != null && item['service_type']!.toString().isNotEmpty) &&
                          (item['total_weight'] ?? 0) > 0) {
                        
                        double itemTotalWeight = item['total_weight'] ?? 0;
                        String itemUnit = item['unit'] ?? 'TON';
                        double itemTotalPrice = item['total_price'] ?? 0;
                        
                        final payload = {
                          'invoice_number': invoiceNumber,
                          'customer_name': customerName,
                          'customer_phone': customerPhoneController.text.trim(),
                          'customer_address': customerAddressController.text.trim(),
                          'service_type': item['service_type']?.toString() ?? '',
                          'size': item['size']?.toString() ?? '',
                          'thickness': item['thickness']?.toString() ?? '',
                          'total_weight': itemTotalWeight,
                          'unit': itemUnit,
                          'unit_price': item['unit_price'] ?? 0,
                          'total_price': itemTotalPrice,
                          'currency': selectedCurrency,
                          'exchange_rate': exchangeRate,
                          'loading_cost': loadingCost,
                          'transfer_cost': transferCost,
                          'clearance_cost': clearanceCost,
                          'discount': discount,
                          'final_price': finalPrice,
                          'afn_equivalent': oppositeEquivalent,
                          'date': dateController.text.trim(),
                          'date_en': selectedEnglishDate,
                        };
                        
                        final id = await _db.insertServiceInvoice(payload);
                        if (id != -1) {
                          insertedIds.add(id);
                        }
                      }
                    }
                    
                    if (insertedIds.isEmpty) {
                      _showSnackbar('❌ خطا در ذخیره خدمات', Colors.red);
                      return;
                    }
                    
                    if (!mounted) return;
                    Navigator.pop(context);
                    await _loadServices();
                    
                    // Show the invoice modal after saving
                    final allInvoices = await _db.getServiceInvoices();
                    List<Map<String, dynamic>> allItems = [];
                    Map<String, dynamic>? firstInvoice;
                    
                    for (var inv in allInvoices) {
                      if (inv['invoice_number'] == invoiceNumber) {
                        allItems.add(inv);
                        if (firstInvoice == null) {
                          firstInvoice = inv;
                        }
                      }
                    }
                    
                    if (firstInvoice != null) {
                      firstInvoice['items'] = allItems;
                      _showServiceInvoiceModal(context, invoiceNumber, firstInvoice, l10n);
                    }
                    
                    _showSnackbar(
                      '✅ ${insertedIds.length} خدمت با موفقیت ثبت شد', 
                      Colors.green
                    );
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

  // ============================================
  // SERVICE INVOICE MODAL - "بل ثبت خدمات"
  // ============================================
  void _showServiceInvoiceModal(BuildContext context, String invoiceNumber, Map<String, dynamic> invoice, AppLocalizations l10n) {
    List<Map<String, dynamic>> items = [];
    if (invoice.containsKey('items') && invoice['items'] is List) {
      items = List<Map<String, dynamic>>.from(invoice['items']);
    } else {
      if (invoice['service_type'] != null && invoice['service_type']!.toString().isNotEmpty) {
        items.add({
          'service_type': invoice['service_type'],
          'size': invoice['size'] ?? '-',
          'thickness': invoice['thickness'] ?? '-',
          'total_weight': double.tryParse(invoice['total_weight']?.toString() ?? '0') ?? 0,
          'unit': invoice['unit']?.toString() ?? 'TON',
          'unit_price': double.tryParse(invoice['unit_price']?.toString() ?? '0') ?? 0,
          'total_price': double.tryParse(invoice['total_price']?.toString() ?? '0') ?? 0,
        });
      }
    }

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
                          // HEADER
                          Container(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: const Color(0xFFCB001D), width: 3)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.companyName,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.integratedSystem,
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCB001D),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'بل ثبت خدمات',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // CUSTOMER & INVOICE INFO
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 1),
                            ),
                            child: Column(
                              children: [
                                // Row 1: Customer & Invoice Number
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
                                              const Text('مشتری', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Container(
                                                  decoration: const BoxDecoration(
                                                    border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                                                  ),
                                                  child: Text(
                                                    invoice['customer_name']?.toString() ?? '-',
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
                                              const Text('شماره فاکتور', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                                // Row 2: Phone & Date
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
                                              const Text('تلفن', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Container(
                                                  decoration: const BoxDecoration(
                                                    border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                                                  ),
                                                  child: Text(
                                                    invoice['customer_phone']?.toString() ?? '',
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
                                              const Text('تاریخ شمسی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Container(
                                                  decoration: const BoxDecoration(
                                                    border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                                                  ),
                                                  child: Text(
                                                    invoice['date']?.toString() ?? '-',
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
                                // Row 3: Address & Date EN
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
                                            const Text('آدرس', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                                                ),
                                                child: Text(
                                                  invoice['customer_address']?.toString() ?? '',
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
                                            const Text('تاریخ میلادی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                                                ),
                                                child: Text(
                                                  invoice['date_en']?.toString() ?? '-',
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
                          ),
                          const SizedBox(height: 20),

                          // SERVICES TABLE
                          _buildServiceInvoiceTable(items, invoice, l10n),
                          const SizedBox(height: 20),

                          // FINANCIAL SUMMARY
                          _buildServiceFinancialSummary(invoice, l10n),
                          const SizedBox(height: 20),

                          // SIGNATURE ROW
                          _buildInvoiceSignatureRow(),
                          const SizedBox(height: 20),

                          // LEGAL TERMS
                          _buildInvoiceLegalTerms(),
                          const SizedBox(height: 16),

                          // OFFICE REGISTRY
                          _buildInvoiceOfficeRegistry(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    // BUTTONS
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
                            await _saveServiceInvoicePdf(invoice, invoiceNumber, l10n);
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
                            await _printServiceInvoicePdf(invoice, invoiceNumber, l10n);
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

  // ============================================
  // SERVICE INVOICE TABLE
  // ============================================
  Widget _buildServiceInvoiceTable(List<Map<String, dynamic>> items, Map<String, dynamic> invoice, AppLocalizations l10n) {
    const headerFont = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black);
    const bodyFont = TextStyle(fontSize: 11, color: Colors.black);

    List<List<String>> tableData = [];
    int rowIndex = 1;
    double totalWeightSum = 0;
    double totalPriceSum = 0;

    for (var item in items) {
      String serviceType = item['service_type']?.toString() ?? '-';
      String size = item['size']?.toString() ?? '-';
      String thickness = item['thickness']?.toString() ?? '-';
      double totalWeight = item['total_weight'] ?? 0;
      String unit = item['unit']?.toString() ?? 'TON';
      double unitPrice = item['unit_price'] ?? 0;
      double totalPrice = item['total_price'] ?? 0;

      totalWeightSum += totalWeight;
      totalPriceSum += totalPrice;

      String displayWeight = unit == 'KG' || unit == 'kg' 
          ? (totalWeight / 1000).toStringAsFixed(2)
          : totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2);
      String displayUnit = unit == 'KG' || unit == 'kg' ? 'تن' : unit;

      tableData.add([
        rowIndex.toString(),
        serviceType,
        size,
        thickness,
        '$displayWeight $displayUnit',
        unitPrice.toStringAsFixed(0),
        totalPrice.toStringAsFixed(0),
      ]);
      rowIndex++;
    }

    // Add empty rows to fill table
    while (tableData.length < 4) {
      tableData.add(['', '', '', '', '', '', '']);
    }

    // Summary row
    tableData.add([
      'مجموعه:',
      '',
      '',
      '',
      totalWeightSum > 0 
          ? '${(totalWeightSum / 1000).toStringAsFixed(2)} تن'
          : '0',
      '',
      totalPriceSum.toStringAsFixed(0),
    ]);

    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: const {
        0: FixedColumnWidth(40),
        1: FixedColumnWidth(100),
        2: FixedColumnWidth(70),
        3: FixedColumnWidth(70),
        4: FixedColumnWidth(90),
        5: FixedColumnWidth(80),
        6: FixedColumnWidth(90),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.blue[100]),
          children: [
            'شماره',
            'نوع خدمت',
            'سایز',
            'ضخامت',
            'مجموع وزن',
            'قیمت واحد',
            'قیمت کل',
          ].map((title) => Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            alignment: Alignment.center,
            child: Text(title, style: headerFont, textAlign: TextAlign.center),
          )).toList(),
        ),
        ...tableData.map((row) {
          bool isSummary = row[0] == 'مجموعه:';
          return TableRow(
            decoration: isSummary ? BoxDecoration(color: Colors.blue[50]) : null,
            children: row.map((cellValue) => Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              alignment: Alignment.center,
              child: Text(
                cellValue,
                style: isSummary 
                    ? const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCB001D))
                    : bodyFont,
                textAlign: TextAlign.center,
              ),
            )).toList(),
          );
        }),
      ],
    );
  }

  // ============================================
  // SERVICE FINANCIAL SUMMARY
  // ============================================
  Widget _buildServiceFinancialSummary(Map<String, dynamic> invoice, AppLocalizations l10n) {
    List<Map<String, dynamic>> items = [];
    if (invoice.containsKey('items') && invoice['items'] is List) {
      items = List<Map<String, dynamic>>.from(invoice['items']);
    } else if (invoice['service_type'] != null && invoice['service_type']!.toString().isNotEmpty) {
      items.add({
        'total_price': double.tryParse(invoice['total_price']?.toString() ?? '0') ?? 0,
        'total_weight': double.tryParse(invoice['total_weight']?.toString() ?? '0') ?? 0,
      });
    }

    double totalPrice = 0;
    for (var item in items) {
      totalPrice += double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
    }

    double finalPrice = double.tryParse(invoice['final_price']?.toString() ?? '0') ?? 0;
    double discount = double.tryParse(invoice['discount']?.toString() ?? '0') ?? 0;
    double afnEquivalent = double.tryParse(invoice['afn_equivalent']?.toString() ?? '0') ?? 0;
    String currency = invoice['currency']?.toString() ?? 'USD';
    double exchangeRate = double.tryParse(invoice['exchange_rate']?.toString() ?? '65') ?? 65;

    // ✅ Determine opposite currency label and value
    String oppositeLabel;
    String oppositeValue;
    if (currency == 'USD') {
      oppositeLabel = 'معادل به افغانی';
      oppositeValue = '${_formatCurrency(afnEquivalent)} AFN';
    } else {
      oppositeLabel = 'معادل به دالر';
      oppositeValue = '\$${_formatCurrency(afnEquivalent)}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اطلاعات مالی مجموعه',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFCB001D)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCB001D).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'مجموع قیمت کل',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCB001D)),
                      ),
                      Text(
                        '${currency == 'AFN' ? 'AFN ' : '\$'}${_formatCurrency(totalPrice)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCB001D)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'نرخ ارز',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                      ),
                      Text(
                        exchangeRate.toString(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        oppositeLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.green.shade700),
                      ),
                      Text(
                        oppositeValue,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تخفیف',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.orange.shade700),
                      ),
                      Text(
                        'AFN ${_formatCurrency(discount)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'قیمت نهایی',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.purple.shade700),
                      ),
                      Text(
                        '${currency == 'AFN' ? 'AFN ' : '\$'}${_formatCurrency(finalPrice)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
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

  // ============================================
  // SERVICE PDF GENERATION
  // ============================================
  Future<Uint8List> _generateServiceInvoicePdfBytes(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    String getPdfValue(String key, {String defaultValue = '-'}) {
      return invoice[key]?.toString() ?? defaultValue;
    }

    List<Map<String, dynamic>> items = [];
    if (invoice.containsKey('items') && invoice['items'] is List) {
      items = List<Map<String, dynamic>>.from(invoice['items']);
    } else {
      if (invoice['service_type'] != null && invoice['service_type']!.toString().isNotEmpty) {
        items.add({
          'service_type': invoice['service_type'],
          'size': invoice['size'] ?? '-',
          'thickness': invoice['thickness'] ?? '-',
          'total_weight': double.tryParse(invoice['total_weight']?.toString() ?? '0') ?? 0,
          'unit': invoice['unit']?.toString() ?? 'TON',
          'unit_price': double.tryParse(invoice['unit_price']?.toString() ?? '0') ?? 0,
          'total_price': double.tryParse(invoice['total_price']?.toString() ?? '0') ?? 0,
        });
      }
    }

    List<List<String>> tableData = [];
    int rowIndex = 1;
    double totalWeightSum = 0;
    double totalPriceSum = 0;

    for (var item in items) {
      String serviceType = item['service_type']?.toString() ?? '-';
      String size = item['size']?.toString() ?? '-';
      String thickness = item['thickness']?.toString() ?? '-';
      double totalWeight = item['total_weight'] ?? 0;
      String unit = item['unit']?.toString() ?? 'TON';
      double unitPrice = item['unit_price'] ?? 0;
      double totalPrice = item['total_price'] ?? 0;

      totalWeightSum += totalWeight;
      totalPriceSum += totalPrice;

      String displayWeight = unit == 'KG' || unit == 'kg' 
          ? (totalWeight / 1000).toStringAsFixed(2)
          : totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2);
      String displayUnit = unit == 'KG' || unit == 'kg' ? 'تن' : unit;

      tableData.add([
        rowIndex.toString(),
        serviceType,
        size,
        thickness,
        '$displayWeight $displayUnit',
        unitPrice.toStringAsFixed(0),
        totalPrice.toStringAsFixed(0),
      ]);
      rowIndex++;
    }

    if (tableData.isEmpty) {
      tableData.add(['1', '-', '-', '-', '0', '0', '0']);
    }

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
                          pw.Text(l10n.companyName, style: pw.TextStyle(font: ttf, fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                          pw.SizedBox(height: 6),
                          pw.Text(l10n.integratedManagementSystem, style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
                        ]),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                          decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(10)),
                          child: pw.Text(
                            'بل ثبت خدمات',
                            style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                          ),
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
                              pw.Expanded(child: pw.Text('${l10n.customer}: ${getPdfValue('customer_name')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black))),
                              pw.SizedBox(width: 12),
                              pw.Expanded(child: pw.Text('${l10n.invoiceNumberLabel}: $invoiceNumber', style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
                              pw.SizedBox(width: 12),
                              pw.Expanded(child: pw.Text('${l10n.date}: ${getPdfValue('date')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black))),
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
                              'نوع خدمت',
                              'سایز',
                              'ضخامت',
                              'مجموع وزن',
                              'قیمت واحد',
                              'قیمت کل',
                            ],
                            data: tableData,
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
                                pw.Text('${l10n.totalPrice}: ${_formatCurrency(totalPriceSum)} ${getPdfValue('currency')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black)),
                                pw.Text('${l10n.discount}: ${_formatCurrency(invoice['discount'])} AFN', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black)),
                              ]),
                              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                                pw.Text('${l10n.amountDue}: ${_formatCurrency(invoice['final_price'])} ${getPdfValue('currency') != '-' ? getPdfValue('currency') : 'USD'}', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                                pw.Text('${invoice['currency'] == 'USD' ? l10n.afnEquivalent : 'USD Equivalent'}: ${_formatCurrency(invoice['afn_equivalent'])} ${invoice['currency'] == 'USD' ? 'AFN' : 'USD'}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
                              ]),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 24),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                              pw.Text('${l10n.printDate}: ${DateTime.now().year}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
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

  Future<void> _saveServiceInvoicePdf(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    try {
      Uint8List? bytes;
      try {
        if (_invoicePreviewKey.currentContext != null) {
          final boundary = _invoicePreviewKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
          if (boundary != null) {
            final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              final pngBytes = byteData.buffer.asUint8List();
              final pdf = pw.Document();
              final pwImage = pw.MemoryImage(pngBytes);
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
      bytes ??= await _generateServiceInvoicePdfBytes(invoice, invoiceNumber, l10n);
      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.savePdf,
        fileName: 'service_invoice_${invoiceNumber.replaceAll(' ', '_')}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (filePath == null) return;
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      _showSnackbar('${l10n.fileSaved}', Colors.green);
    } catch (e) {
      _showSnackbar('${l10n.errorPrintingInvoice}: $e', Colors.red);
    }
  }

  Future<void> _printServiceInvoicePdf(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    try {
      Uint8List? bytes;
      try {
        if (_invoicePreviewKey.currentContext != null) {
          final boundary = _invoicePreviewKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
          if (boundary != null) {
            final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              final pngBytes = byteData.buffer.asUint8List();
              final pdf = pw.Document();
              final pwImage = pw.MemoryImage(pngBytes);
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
      bytes ??= await _generateServiceInvoicePdfBytes(invoice, invoiceNumber, l10n);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes!,
        name: 'service_invoice_${invoiceNumber.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      _showSnackbar('${l10n.errorPrintingInvoice}: $e', Colors.red);
    }
  }

  // ============================================
  // REUSABLE WIDGETS
  // ============================================
  Widget _buildFinancialSummaryItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
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
  // EXISTING UI BUILDERS
  // ============================================
  Widget _buildSectionTitle(String title, AppLocalizations l10n) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A1A1A),
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

  String _formatCurrency(dynamic value) {
    if (value == null) return '0';
    final number = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
    return number.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), 
      (m) => '${m[1]},'
    );
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

  // ============================================
  // DELETE SERVICE
  // ============================================
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

  // ============================================
  // BUILD HEADER
  // ============================================
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
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _importExcel,
              icon: const Icon(Icons.upload_file, color: Color(0xFFCB001D), size: 18),
              label: const Text('Import Excel', style: TextStyle(color: Color(0xFFCB001D), fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCB001D)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
            const SizedBox(width: 10),
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
        ),
      ],
    );
  }

  // ============================================
  // QUICK STATS
  // ============================================
  Widget _buildQuickStats(AppLocalizations l10n) {
    final totalServices = _services.length;
    
    // Calculate total revenue from final_price of each service
    final totalRevenue = _services.fold<double>(0, (sum, item) => sum + (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0));
    
    // Calculate total weight
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
    
    // Calculate USD total
    final usdTotal = _services.fold<double>(0, (sum, item) => sum + ((item['currency'] == 'USD' ? (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0) : 0)));
    
    return Row(
      children: [
        _buildStatCard(l10n.totalRevenue, '\$${_formatCurrency(totalRevenue)}', Icons.attach_money_outlined, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard(l10n.totalServicesCount, totalServices.toString(), Icons.design_services_outlined, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard(l10n.usdTotalServices, '\$${_formatCurrency(usdTotal)}', Icons.currency_exchange, Colors.green.shade700),
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

  // ============================================
  // FILTER & SEARCH
  // ============================================
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

  // ============================================
  // SERVICES TABLE - CLEANER VIEW
  // ============================================
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
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                      ),
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
                          _buildHeaderCell(l10n.invoiceNumberLabel, 100),
                          _buildHeaderCell(l10n.customer, 140),
                          _buildHeaderCell(l10n.customerPhone, 110),
                          _buildHeaderCell('خدمات', 140),
                          _buildHeaderCell('مجموع وزن', 90),
                          _buildHeaderCell('قیمت کل', 100),
                          _buildHeaderCell('بارگیری (AFN)', 90),
                          _buildHeaderCell('حمل (AFN)', 90),
                          _buildHeaderCell('ترخیص (AFN)', 90),
                          _buildHeaderCell('تخفیف (AFN)', 90),
                          _buildHeaderCell('قیمت نهایی (USD)', 110),
                          _buildHeaderCell('معادل (AFN)', 100),
                          _buildHeaderCell('تاریخ', 100),
                          _buildHeaderCell(l10n.actions, 140),
                        ],
                      ),
                    ),

                    if (paged.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            l10n.noServicesFound,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ...paged.map((service) {
                        final id = (service['invoice_number'] ?? service['id'] ?? '').toString();
                        final checked = _selectedServices.contains(id);
                        
                        String unit = service['unit']?.toString() ?? 'TON';
                        double totalWeight = double.tryParse(service['total_weight']?.toString() ?? '0') ?? 0;
                        String displayWeight = unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم' 
                            ? _formatWeightWithConversion(totalWeight) 
                            : '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2)} تن';
                        
                        final serviceTypes = service['service_types'] as List?;
                        final serviceCount = service['service_count'] ?? 1;
                        
                        double loadingCost = double.tryParse(service['loading_cost']?.toString() ?? '0') ?? 0;
                        double transferCost = double.tryParse(service['transfer_cost']?.toString() ?? '0') ?? 0;
                        double clearanceCost = double.tryParse(service['clearance_cost']?.toString() ?? '0') ?? 0;
                        double discount = double.tryParse(service['discount']?.toString() ?? '0') ?? 0;
                        String currency = service['currency']?.toString() ?? 'USD';
                        
                        double exchangeRate = double.tryParse(service['exchange_rate']?.toString() ?? '65') ?? 65;
                        if (exchangeRate <= 0) exchangeRate = 1;
                        
                        double finalPriceRaw = double.tryParse(service['final_price']?.toString() ?? '0') ?? 0;
                        double totalPriceRaw = double.tryParse(service['total_price']?.toString() ?? '0') ?? 0;
                        
                        // ✅ FINAL PRICE: always USD
                        // If currency is USD → use directly
                        // If currency is AFN → convert to USD
                        double finalPriceUSD = currency == 'USD' 
                            ? finalPriceRaw 
                            : finalPriceRaw / exchangeRate;
                        double totalPriceUSD = currency == 'USD' 
                            ? totalPriceRaw 
                            : totalPriceRaw / exchangeRate;
                        
                        // ✅ EQUIVALENT: always AFN
                        // If currency is AFN → use directly
                        // If currency is USD → convert to AFN
                        double equivalentAFN = currency == 'AFN' 
                            ? finalPriceRaw 
                            : finalPriceRaw * exchangeRate;
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: checked ? const Color(0xFFCB001D).withOpacity(0.03) : Colors.white,
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
                              _buildDataCell(service['invoice_number']?.toString() ?? '-', 100, isBold: true),
                              _buildDataCell(service['customer_name'] ?? '-', 140, isBold: true),
                              _buildDataCell(service['customer_phone'] ?? '-', 110),
                              SizedBox(
                                width: 140,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (serviceTypes != null && serviceTypes.isNotEmpty)
                                      ...serviceTypes.take(2).map((name) => 
                                        Text(
                                          name?.toString() ?? '-', 
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      )
                                    else
                                      Text(service['service_type'] ?? '-', style: const TextStyle(fontSize: 11)),
                                    if (serviceTypes != null && serviceTypes.length > 2)
                                      Text(
                                        'و ${serviceTypes.length - 2} خدمت دیگر...',
                                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCB001D).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$serviceCount خدمت',
                                        style: const TextStyle(fontSize: 9, color: Color(0xFFCB001D), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildDataCell(displayWeight, 90),
                              // قمیت کل — always in the original currency (as user entered)
                              _buildDataCell('\$${_formatCurrency(totalPriceUSD)}', 100),
                              
                              _buildDataCell(
                                loadingCost > 0 ? _formatCurrency(loadingCost) : '-', 
                                90, 
                                color: loadingCost > 0 ? Colors.orange.shade700 : Colors.grey,
                              ),
                              _buildDataCell(
                                transferCost > 0 ? _formatCurrency(transferCost) : '-', 
                                90, 
                                color: transferCost > 0 ? Colors.orange.shade700 : Colors.grey,
                              ),
                              _buildDataCell(
                                clearanceCost > 0 ? _formatCurrency(clearanceCost) : '-', 
                                90, 
                                color: clearanceCost > 0 ? Colors.orange.shade700 : Colors.grey,
                              ),
                              _buildDataCell(
                                discount > 0 ? _formatCurrency(discount) : '-', 
                                90, 
                                color: discount > 0 ? Colors.red.shade700 : Colors.grey,
                              ),
                              
                              // ✅ قیمت نهایی — ALWAYS USD
                              _buildDataCell('\$${_formatCurrency(finalPriceUSD)}', 110, isBold: true, color: const Color(0xFFCB001D)),
                              // ✅ معادل — ALWAYS AFN
                              _buildDataCell('AFN ${_formatCurrency(equivalentAFN)}', 100, color: Colors.green.shade700),
                              _buildDataCell(service['date'] ?? '-', 100),
                              
                              SizedBox(
                                width: 140,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        _showServiceInvoiceModal(context, service['invoice_number'] ?? '-', service, l10n);
                                      },
                                      icon: const Icon(Icons.visibility_outlined, color: Colors.blue, size: 20),
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'مشاهده فاکتور',
                                    ),
                                    IconButton(
                                      onPressed: () => _showServiceDialog(service: service),
                                      icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'ویرایش',
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteService(service),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'حذف',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
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

  // ============================================
  // MAIN BUILD
  // ============================================
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
          (service['display_services'] ?? '').toString().toLowerCase().contains(search) ||
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
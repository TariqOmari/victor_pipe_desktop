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

  List<Map<String, dynamic>> _serviceItems = [];
  int _nextServiceItemIndex = 1;

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

  String _normalizeHeader(String input) {
    if (input.isEmpty) return '';
    String s = input;
    s = s.replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]'), '');
    s = s.replaceAll('ي', 'ی');
    s = s.replaceAll('ك', 'ک');
    s = s.replaceAll('ۀ', 'ه');
    s = s.replaceAll('ة', 'ه');
    s = s.replaceAll('أ', 'ا');
    s = s.replaceAll('إ', 'ا');
    s = s.replaceAll('آ', 'ا');
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s.trim();
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
            children: const [
              CircularProgressIndicator(color: Color(0xFFCB001D)),
              SizedBox(height: 16),
              Text('در حال وارد کردن اکسل...', style: TextStyle(fontSize: 14)),
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
      List<String> rawHeaders = [];
      for (var cell in headersRow) {
        if (cell != null && cell.value != null) {
          rawHeaders.add(cell.value.toString());
        } else {
          rawHeaders.add('');
        }
      }

      List<String> headers = rawHeaders.map(_normalizeHeader).toList();
      print('📋 Raw Headers: $rawHeaders');
      print('📋 Normalized: $headers');

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

      // -------- EXACT MATCHES --------
      for (int i = 0; i < headers.length; i++) {
        String h = headers[i];
        if (h.isEmpty) continue;

        if (h == 'تاریخ' || h == 'date') { dateIndex = i; continue; }
        if (h == 'نمبربل' || h == 'نمبر' || h == 'شمارهبل' || 
            h == 'شماره' || h == 'invoice' || h == 'invoicenumber' || 
            h == 'نمبرفاکتور' || h == 'شمارهفاکتور') { invoiceNumberIndex = i; continue; }
        if (h == 'اسممشتری' || h == 'مشتری' || h == 'ناممشتری' || 
            h == 'خریدار' || h == 'customer' || h == 'customername' ||
            h == 'اسمخریدار') { customerNameIndex = i; continue; }
        if (h == 'تلفن' || h == 'شمارهتماس' || h == 'موبایل' || 
            h == 'phone' || h == 'telephone' || h == 'tel') { customerPhoneIndex = i; continue; }
        if (h == 'آدرس' || h == 'ادرس' || h == 'address') { customerAddressIndex = i; continue; }
        if (h == 'نوعخدمات' || h == 'نوعخدمت' || h == 'خدمات' || 
            h == 'خدمت' || h == 'service' || h == 'servicetype') { serviceTypeIndex = i; continue; }
        if (h == 'سایز' || h == 'size' || h == 'ابعاد') { sizeIndex = i; continue; }
        if (h == 'ضخامت' || h == 'thickness') { thicknessIndex = i; continue; }
        if (h == 'مجموعوزن' || h == 'وزنکل' || h == 'وزن' || 
            h == 'totalweight' || h == 'weight') { totalWeightIndex = i; continue; }
        if (h == 'واحد' || h == 'unit') { unitIndex = i; continue; }
        if (h == 'قیمتواحد' || h == 'unitprice' || h == 'فی' ||
            h == 'قیمتهرتن') { unitPriceIndex = i; continue; }
        if (h == 'مجموعقیمت' || h == 'قیمتکل' || h == 'totalprice' || 
            h == 'مبلغکل') { totalPriceIndex = i; continue; }
        if (h == 'واحدپول' || h == 'ارز' || h == 'currency' || h == 'پول') { currencyIndex = i; continue; }
        if (h == 'نرخارز' || h == 'نرخ' || h == 'exchange' || 
            h == 'exchangerate' || h == 'rate') { exchangeRateIndex = i; continue; }
        if (h == 'بارگیری' || h == 'هزینهبارگیری' || h == 'loading') { loadingCostIndex = i; continue; }
        if (h == 'حمل' || h == 'هزینهحمل' || h == 'transfer' || h == 'نقلوانتقال') { transferCostIndex = i; continue; }
        if (h == 'ترخیص' || h == 'هزینهترخیص' || h == 'clearance') { clearanceCostIndex = i; continue; }
        if (h == 'تخفیف' || h == 'discount') { discountIndex = i; continue; }
        if (h == 'قیمتنهایی' || h == 'finalprice' || h == 'قیمتتمام') { finalPriceIndex = i; continue; }
        if (h == 'معادل' || h == 'معادلافغانی' || h == 'معادلارزی' || 
            h == 'afn' || h == 'افغانی') { afnEquivalentIndex = i; continue; }
      }

      // -------- FUZZY FALLBACK --------
      for (int i = 0; i < headers.length; i++) {
        String h = headers[i];
        if (h.isEmpty) continue;
        if (invoiceNumberIndex == -1 && (h.contains('نمبر') || h.contains('invoice') || h.contains('شماره'))) invoiceNumberIndex = i;
        else if (customerNameIndex == -1 && (h.contains('مشتری') || h.contains('customer') || h.contains('خریدار'))) customerNameIndex = i;
        else if (customerPhoneIndex == -1 && (h.contains('تلفن') || h.contains('phone') || h.contains('موبایل'))) customerPhoneIndex = i;
        else if (customerAddressIndex == -1 && (h.contains('آدرس') || h.contains('ادرس') || h.contains('address'))) customerAddressIndex = i;
        else if (serviceTypeIndex == -1 && (h.contains('خدمت') || h.contains('service'))) serviceTypeIndex = i;
        else if (sizeIndex == -1 && (h.contains('سایز') || h.contains('size'))) sizeIndex = i;
        else if (thicknessIndex == -1 && (h.contains('ضخامت') || h.contains('thickness'))) thicknessIndex = i;
        else if (totalWeightIndex == -1 && (h.contains('وزن') || h.contains('weight'))) totalWeightIndex = i;
        else if (unitPriceIndex == -1 && (h.contains('قیمتواحد') || h.contains('unitprice'))) unitPriceIndex = i;
        else if (totalPriceIndex == -1 && (h.contains('مجموعقیمت') || h.contains('totalprice') || h.contains('قیمتکل'))) totalPriceIndex = i;
        else if (currencyIndex == -1 && (h.contains('واحدپول') || h.contains('currency'))) currencyIndex = i;
        else if (exchangeRateIndex == -1 && (h.contains('نرخ') || h.contains('exchange') || h.contains('rate'))) exchangeRateIndex = i;
        else if (dateIndex == -1 && (h.contains('تاریخ') || h.contains('date'))) dateIndex = i;
        else if (unitIndex == -1 && (h == 'واحد' || h == 'unit')) unitIndex = i;
      }

      print('📋 Matched → Inv:$invoiceNumberIndex Cust:$customerNameIndex Svc:$serviceTypeIndex Weight:$totalWeightIndex Unit:$unitIndex UnitPrice:$unitPriceIndex TotalPrice:$totalPriceIndex Cur:$currencyIndex Rate:$exchangeRateIndex');

      if (invoiceNumberIndex == -1 || customerNameIndex == -1) {
        return {
          'success': false,
          'message': 'فیلدهای مورد نیاز پیدا نشد.\nهدرها: ${rawHeaders.where((h) => h.isNotEmpty).join(" | ")}'
        };
      }

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        bool hasData = false;
        for (var cell in row) {
          if (cell != null && cell.value != null) {
            String val = cell.value.toString().trim();
            if (val.isNotEmpty && val != '0' && val != '-' && val != '\$') { hasData = true; break; }
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

          print('📝 Row ${i+1}: Inv=$invoiceNumber | Cust=$customerName | Svc=$serviceType | W=$totalWeightStr | U=$unit | UP=$unitPriceStr | TP=$totalPriceStr | Cur=$currency | Rate=$exchangeRateStr');

          if (invoiceNumber.isEmpty || customerName.isEmpty) {
            skippedCount++;
            errors.add('ردیف ${i+1}: فیلدهای مورد نیاز کامل نیستند');
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

          // ==========================================
          // WEIGHT CONVERSION: if weight > 1000 → treat as KG
          // ==========================================
          String unitNormalized = unit.trim().toLowerCase();
          bool isKiloUnit = unitNormalized.contains('kg') || 
                            unitNormalized.contains('کیلو') || 
                            unitNormalized.contains('kilo');
          if (totalWeight > 1000) {
            isKiloUnit = true;
            print('⚠️ Weight ($totalWeight) > 1000 → KG.');
          }

          double totalWeightInTons = isKiloUnit ? totalWeight / 1000 : totalWeight;
          print('📏 Weight: $totalWeight ${isKiloUnit ? "KG" : "TON"} → $totalWeightInTons TON');

          // ==========================================
          // TOTAL PRICE
          // Prefer Excel's own مجموع قیمت, else: TON × unitPrice
          // ==========================================
          if (totalPrice <= 0 && unitPrice > 0 && totalWeightInTons > 0) {
            totalPrice = totalWeightInTons * unitPrice;
            print('💰 Calculated totalPrice: $totalWeightInTons × $unitPrice = $totalPrice');
          } else {
            print('💰 Using Excel totalPrice: $totalPrice');
          }

          // ==========================================
          // CURRENCY & AFN
          // ==========================================
          String currencyFinal = currency.toUpperCase().contains('AFN') ||
                                  currency.contains('افغانی') ? 'AFN' : 'USD';

          // Convert expenses to item currency (for final_price calc)
          double loadingCostItem = currencyFinal == 'USD' ? loadingCost / exchangeRate : loadingCost;
          double transferCostItem = currencyFinal == 'USD' ? transferCost / exchangeRate : transferCost;
          double clearanceCostItem = currencyFinal == 'USD' ? clearanceCost / exchangeRate : clearanceCost;
          double discountItem = currencyFinal == 'USD' ? discount / exchangeRate : discount;

          if (finalPrice <= 0 && totalPrice > 0) {
            finalPrice = totalPrice + loadingCostItem + transferCostItem + clearanceCostItem - discountItem;
          }

          // AFN equivalent of the final price
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
            'total_weight': totalWeightInTons,   // always TON
            'unit': 'TON',
            'unit_price': unitPrice,             // <-- the unit price 60
            'total_price': totalPrice,           // <-- 755.7
            'currency': currencyFinal,
            'exchange_rate': exchangeRate,
            'loading_cost': loadingCost,
            'transfer_cost': transferCost,
            'clearance_cost': clearanceCost,
            'discount': discount,
            'final_price': finalPrice,
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
            errors.add('ردیف ${i+1}: خطا در ذخیره‌سازی');
          }
        } catch (e) {
          skippedCount++;
          errors.add('ردیف ${i+1}: خطا - $e');
          print('❌ Error: $e');
        }
      }

      return {
        'success': true,
        'successCount': successCount,
        'skippedCount': skippedCount,
        'importedData': importedData,
        'errors': errors,
        'message': '✅ $successCount ردیف وارد شد. $skippedCount ردیف نادیده گرفته شد.',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {'success': false, 'message': 'خطا در پردازش فایل: $e'};
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
                Text('✅ ${result['successCount']} رکورد با موفقیت وارد شد',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                if (result['skippedCount'] > 0) ...[
                  const SizedBox(height: 8),
                  Text('⚠️ ${result['skippedCount']} رکورد نادیده گرفته شد',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
                if (result['errors'] != null && result['errors'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('خطاها:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            .map((error) => Text(error,
                                  style: const TextStyle(fontSize: 11, color: Colors.red)))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('باشه')),
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

  // ============================================
  // LOAD SERVICES — CORRECT CALCULATIONS
  // total_usd = Σ (weight_tons × unit_price)  OR Σ total_price
  // total_afn = total_usd × exchange_rate
  // ============================================
  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final services = await _db.getServiceInvoices();
      
      final Map<String, List<Map<String, dynamic>>> groupedServices = {};
      for (var service in services) {
        final invoiceNumber = service['invoice_number']?.toString() ?? 'unknown';
        if (!groupedServices.containsKey(invoiceNumber)) {
          groupedServices[invoiceNumber] = [];
        }
        groupedServices[invoiceNumber]!.add(service);
      }
      
      final List<Map<String, dynamic>> consolidatedServices = [];
      for (var entry in groupedServices.entries) {
        final items = entry.value;
        final firstItem = items.first;
        
        final consolidated = Map<String, dynamic>.from(firstItem);
        consolidated['items'] = items;
        
        double totalWeightTons = 0;
        double totalPriceUsd = 0;   // ✅ sum of unit_price × weight (or total_price)
        double totalPriceAfn = 0;   // ✅ totalPriceUsd × exchange_rate
        double totalFinalUsd = 0;
        double totalFinalAfn = 0;
        String unit = 'TON';

        // Use the first item's exchange rate as default for AFN conversion
        double exchangeRate = double.tryParse(firstItem['exchange_rate']?.toString() ?? '65') ?? 65;
        String firstCurrency = firstItem['currency']?.toString() ?? 'USD';
        
        for (var item in items) {
          final weight = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;   // already TON
          final uPrice = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
          final tPrice = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
          final fPrice = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0;
          final rate = double.tryParse(item['exchange_rate']?.toString() ?? '1') ?? 1;
          final cur = item['currency']?.toString() ?? 'USD';

          totalWeightTons += weight;
          if (item['unit'] != null) unit = item['unit'].toString();

          // ===========================================================
          // KEY FIX: total USD = weight_tons × unit_price  (not final_price)
          // If total_price exists use it, else weight×unit_price
          // ===========================================================
          double rowTotalPrice = tPrice > 0 ? tPrice : (weight * uPrice);
          double rowFinalPrice = fPrice > 0 ? fPrice : rowTotalPrice;

          double rowUsd;
          double rowAfn;
          if (cur == 'USD') {
            rowUsd = rowTotalPrice;
            rowAfn = rowTotalPrice * rate;
          } else {
            rowAfn = rowTotalPrice;
            rowUsd = rate > 0 ? rowTotalPrice / rate : 0;
          }
          totalPriceUsd += rowUsd;
          totalPriceAfn += rowAfn;

          // final equivalents
          double rowFinalUsd;
          double rowFinalAfn;
          if (cur == 'USD') {
            rowFinalUsd = rowFinalPrice;
            rowFinalAfn = rowFinalPrice * rate;
          } else {
            rowFinalAfn = rowFinalPrice;
            rowFinalUsd = rate > 0 ? rowFinalPrice / rate : 0;
          }
          totalFinalUsd += rowFinalUsd;
          totalFinalAfn += rowFinalAfn;
        }

        consolidated['total_weight'] = totalWeightTons;
        consolidated['total_price'] = totalPriceUsd;
        consolidated['final_price'] = totalFinalUsd;
        consolidated['unit'] = unit;
        consolidated['service_count'] = items.length;

        consolidated['total_sell_usd'] = totalPriceUsd;
        consolidated['total_sell_afn'] = totalPriceAfn;
        consolidated['total_final_usd'] = totalFinalUsd;
        consolidated['total_final_afn'] = totalFinalAfn;
        
        // Also store unit_price from first item for table display
        consolidated['unit_price'] = double.tryParse(firstItem['unit_price']?.toString() ?? '0') ?? 0;
        
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
        _selectedServices.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar(l10n.errorLoadingServices, Colors.red);
    }
  }

  // ============================================
  // SERVICE DIALOG (create / edit)
  // ============================================
  Future<void> _showServiceDialog({Map<String, dynamic>? service}) async {
    final l10n = AppLocalizations.of(context)!;
    _serviceItems = [];
    _nextServiceItemIndex = 1;
    
    final invoiceNumberController = TextEditingController(text: service?['invoice_number']?.toString() ?? '');
    final customerNameController = TextEditingController(text: service?['customer_name']?.toString() ?? '');
    final customerPhoneController = TextEditingController(text: service?['customer_phone']?.toString() ?? '');
    final customerAddressController = TextEditingController(text: service?['customer_address']?.toString() ?? '');
    
    final loadingController = TextEditingController(text: service?['loading_cost']?.toString() ?? '');
    final transferController = TextEditingController(text: service?['transfer_cost']?.toString() ?? '');
    final clearanceController = TextEditingController(text: service?['clearance_cost']?.toString() ?? '');
    final discountController = TextEditingController(text: service?['discount']?.toString() ?? '');
    
    final dateController = TextEditingController(
      text: service?['date']?.toString() ?? PersianDateConverter.getCurrentPersianDate());
    String selectedEnglishDate = service?['date_en']?.toString() ?? 
        PersianDateConverter.getEnglishDate(DateTime.now());

    if (service != null && service['items'] is List && (service['items'] as List).isNotEmpty) {
      final existingItems = List<Map<String, dynamic>>.from(service['items']);
      for (var item in existingItems) {
        double w = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
        double up = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
        double tp = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
        double rate = double.tryParse(item['exchange_rate']?.toString() ?? '1') ?? 1;
        String cur = item['currency']?.toString() ?? 'USD';

        _serviceItems.add({
          'id': item['id'],
          'service_type': item['service_type']?.toString() ?? '',
          'size': item['size']?.toString() ?? '',
          'thickness': item['thickness']?.toString() ?? '',
          'total_weight': w,
          'unit': item['unit']?.toString() ?? 'TON',
          'unit_price': up,
          'total_price': tp,
          'currency': cur,
          'exchange_rate': rate,
          'serviceTypeCtrl': TextEditingController(text: item['service_type']?.toString() ?? ''),
          'sizeCtrl': TextEditingController(text: item['size']?.toString() ?? ''),
          'thicknessCtrl': TextEditingController(text: item['thickness']?.toString() ?? ''),
          'weightCtrl': TextEditingController(text: w > 0 ? w.toString() : ''),
          'unitPriceCtrl': TextEditingController(text: up > 0 ? up.toString() : ''),
          'rateCtrl': TextEditingController(text: rate.toString()),
        });
      }
    } else {
      _serviceItems.add({
        'id': _nextServiceItemIndex++,
        'service_type': '', 'size': '', 'thickness': '',
        'total_weight': 0.0, 'unit': 'TON',
        'unit_price': 0.0, 'total_price': 0.0,
        'currency': 'USD', 'exchange_rate': 65.0,
        'serviceTypeCtrl': TextEditingController(),
        'sizeCtrl': TextEditingController(),
        'thicknessCtrl': TextEditingController(),
        'weightCtrl': TextEditingController(),
        'unitPriceCtrl': TextEditingController(),
        'rateCtrl': TextEditingController(text: '65'),
      });
    }

    double getTotalWeight() {
      double total = 0;
      for (var item in _serviceItems) {
        double weight = item['total_weight'] ?? 0;
        String unit = item['unit'] ?? 'TON';
        if (unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم') total += weight / 1000;
        else total += weight;
      }
      return total;
    }

    double getTotalPrice() {
      double total = 0;
      for (var item in _serviceItems) total += item['total_price'] ?? 0;
      return total;
    }

    double getTotalAfn() {
      double total = 0;
      for (var item in _serviceItems) {
        final tp = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
        final rate = double.tryParse(item['exchange_rate']?.toString() ?? '1') ?? 1;
        final cur = item['currency']?.toString() ?? 'USD';
        if (cur == 'USD') total += tp * rate;
        else total += tp;
      }
      return total;
    }

    double getTotalUsd() {
      double total = 0;
      for (var item in _serviceItems) {
        final tp = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
        final rate = double.tryParse(item['exchange_rate']?.toString() ?? '1') ?? 1;
        final cur = item['currency']?.toString() ?? 'USD';
        if (cur == 'USD') total += tp;
        else total += rate > 0 ? tp / rate : 0;
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
          double totalAfn = getTotalAfn();
          double totalUsd = getTotalUsd();
          double loadingCost = double.tryParse(loadingController.text) ?? 0;
          double transferCost = double.tryParse(transferController.text) ?? 0;
          double clearanceCost = double.tryParse(clearanceController.text) ?? 0;
          double discount = double.tryParse(discountController.text) ?? 0;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                service == null ? l10n.addNewService : l10n.editServiceLabel2,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: SizedBox(
                width: 950,
                height: MediaQuery.of(context).size.height * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('اطلاعات فاکتور', l10n),
                      const SizedBox(height: 8),
                      _buildTextField(controller: invoiceNumberController, label: l10n.invoiceNumberLabel, icon: Icons.numbers, l10n: l10n),
                      const SizedBox(height: 12),
                      _buildTextField(controller: customerNameController, label: l10n.customerName, icon: Icons.person_outline, l10n: l10n),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _buildTextField(controller: customerPhoneController, label: l10n.customerPhone, icon: Icons.phone_outlined, keyboardType: TextInputType.phone, l10n: l10n)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(controller: customerAddressController, label: l10n.customerAddress, icon: Icons.location_on_outlined, l10n: l10n)),
                      ]),
                      const SizedBox(height: 16),
                      _buildSectionTitle('خدمات', l10n),
                      const SizedBox(height: 8),
                      ..._serviceItems.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> item = entry.value;
                        String itemCurrency = item['currency']?.toString() ?? 'USD';
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
                                  Text('خدمت ${index + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFCB001D))),
                                  if (_serviceItems.length > 1)
                                    IconButton(
                                      onPressed: () => setDialogState(() => _serviceItems.removeAt(index)),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: item['serviceTypeCtrl'] as TextEditingController,
                                label: l10n.serviceTypeLabel2, icon: Icons.design_services_outlined, l10n: l10n,
                                onChanged: (v) { item['service_type'] = v; setDialogState(() {}); },
                              ),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: _buildTextField(
                                  controller: item['sizeCtrl'] as TextEditingController,
                                  label: l10n.size, icon: Icons.aspect_ratio_outlined, l10n: l10n,
                                  onChanged: (v) { item['size'] = v; setDialogState(() {}); },
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _buildTextField(
                                  controller: item['thicknessCtrl'] as TextEditingController,
                                  label: l10n.thickness, icon: Icons.straighten_outlined, l10n: l10n,
                                  onChanged: (v) { item['thickness'] = v; setDialogState(() {}); },
                                )),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _buildTextField(
                                    controller: item['weightCtrl'] as TextEditingController,
                                    label: l10n.totalWeight, icon: Icons.monitor_weight_outlined,
                                    keyboardType: TextInputType.number, l10n: l10n,
                                    onChanged: (v) {
                                      item['total_weight'] = double.tryParse(v) ?? 0;
                                      updateServiceItemTotals(item);
                                      setDialogState(() {});
                                    },
                                  ),
                                  if (item['total_weight'] != null && item['total_weight'] > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        item['unit'] == 'KG' || item['unit'] == 'kg'
                                            ? '${item['total_weight']} kg = ${(item['total_weight'] / 1000).toStringAsFixed(2)} تن'
                                            : '${item['total_weight']} تن',
                                        style: const TextStyle(fontSize: 10, color: Colors.blue),
                                      ),
                                    ),
                                ])),
                                const SizedBox(width: 12),
                                Expanded(child: DropdownButtonFormField<String>(
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
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setDialogState(() { item['unit'] = v; updateServiceItemTotals(item); });
                                  },
                                )),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: _buildTextField(
                                  controller: item['unitPriceCtrl'] as TextEditingController,
                                  label: '${l10n.unitPrice} (قیمت هر تن)',
                                  icon: Icons.price_check_outlined,
                                  keyboardType: TextInputType.number, l10n: l10n,
                                  onChanged: (v) {
                                    item['unit_price'] = double.tryParse(v) ?? 0;
                                    updateServiceItemTotals(item);
                                    setDialogState(() {});
                                  },
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _buildTextField(
                                  controller: TextEditingController(
                                    text: item['total_price'] != null && item['total_price'] > 0
                                        ? item['total_price'].toStringAsFixed(0) : '',
                                  ),
                                  label: l10n.totalPrice, icon: Icons.attach_money_outlined,
                                  readOnly: true, l10n: l10n,
                                )),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: DropdownButtonFormField<String>(
                                  value: itemCurrency,
                                  decoration: InputDecoration(
                                    labelText: l10n.currency,
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.currency_exchange, color: Color(0xFFCB001D)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                                    DropdownMenuItem(value: 'AFN', child: Text('AFN')),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setDialogState(() { item['currency'] = v; });
                                  },
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _buildTextField(
                                  controller: item['rateCtrl'] as TextEditingController,
                                  label: itemCurrency == 'USD' ? 'نرخ ارز (USD→AFN)' : 'نرخ ارز (AFN→USD)',
                                  icon: Icons.currency_exchange,
                                  keyboardType: TextInputType.number, l10n: l10n,
                                  onChanged: (v) { item['exchange_rate'] = double.tryParse(v) ?? 1; setDialogState(() {}); },
                                )),
                              ]),
                            ],
                          ),
                        );
                      }).toList(),
                      ElevatedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            _serviceItems.add({
                              'id': _nextServiceItemIndex++,
                              'service_type': '', 'size': '', 'thickness': '',
                              'total_weight': 0.0, 'unit': 'TON',
                              'unit_price': 0.0, 'total_price': 0.0,
                              'currency': 'USD', 'exchange_rate': 65.0,
                              'serviceTypeCtrl': TextEditingController(),
                              'sizeCtrl': TextEditingController(),
                              'thicknessCtrl': TextEditingController(),
                              'weightCtrl': TextEditingController(),
                              'unitPriceCtrl': TextEditingController(),
                              'rateCtrl': TextEditingController(text: '65'),
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
                      _buildSectionTitle('هزینه‌ها (به افغانی)', l10n),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _buildTextField(controller: loadingController, label: 'هزینه بارگیری (AFN)', icon: Icons.local_shipping_outlined, keyboardType: TextInputType.number, l10n: l10n, onChanged: (_) => setDialogState(() {}))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(controller: transferController, label: 'هزینه حمل (AFN)', icon: Icons.drive_eta_outlined, keyboardType: TextInputType.number, l10n: l10n, onChanged: (_) => setDialogState(() {}))),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _buildTextField(controller: clearanceController, label: 'هزینه ترخیص (AFN)', icon: Icons.inventory_2_outlined, keyboardType: TextInputType.number, l10n: l10n, onChanged: (_) => setDialogState(() {}))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(controller: discountController, label: 'تخفیف (AFN)', icon: Icons.discount_outlined, keyboardType: TextInputType.number, l10n: l10n, onChanged: (_) => setDialogState(() {}))),
                      ]),
                      const SizedBox(height: 16),
                      _buildSectionTitle(l10n.financialInfo, l10n),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1)),
                        ),
                        child: Column(children: [
                          Row(children: [
                            Expanded(child: _buildFinancialSummaryItem('مجموع وزن', '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2)} تن', const Color(0xFFCB001D))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildFinancialSummaryItem('تعداد خدمات', _serviceItems.length.toString(), Colors.blue.shade700)),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _buildFinancialSummaryItem('مجموع قیمت (دالر)', totalUsd.toStringAsFixed(2), Colors.green.shade700)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildFinancialSummaryItem('مجموع قیمت (افغانی)', totalAfn.toStringAsFixed(0), Colors.purple.shade700)),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: dateController, label: l10n.date,
                        icon: Icons.calendar_today_outlined, readOnly: true, l10n: l10n,
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
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
                ElevatedButton.icon(
                  onPressed: () async {
                    final invoiceNumber = invoiceNumberController.text.trim();
                    final customerName = customerNameController.text.trim();
                    if (invoiceNumber.isEmpty) { _showSnackbar('شماره فاکتور الزامی است', Colors.red); return; }
                    if (customerName.isEmpty) { _showSnackbar('نام مشتری الزامی است', Colors.red); return; }

                    bool hasValidItem = false;
                    for (var item in _serviceItems) {
                      if ((item['service_type'] != null && item['service_type']!.toString().isNotEmpty) && (item['total_weight'] ?? 0) > 0) { hasValidItem = true; break; }
                    }
                    if (!hasValidItem) { _showSnackbar('حداقل یک خدمت معتبر باید انتخاب شود', Colors.red); return; }

                    if (service != null) {
                      final oldItems = (service['items'] is List) ? List<Map<String, dynamic>>.from(service['items']) : <Map<String, dynamic>>[];
                      for (var oldItem in oldItems) {
                        if (oldItem['id'] != null) await _db.deleteServiceInvoice(oldItem['id'] as int);
                      }
                    }

                    double loadingCost = double.tryParse(loadingController.text) ?? 0;
                    double transferCost = double.tryParse(transferController.text) ?? 0;
                    double clearanceCost = double.tryParse(clearanceController.text) ?? 0;
                    double discount = double.tryParse(discountController.text) ?? 0;

                    List<int> insertedIds = [];
                    for (var item in _serviceItems) {
                      if ((item['service_type'] != null && item['service_type']!.toString().isNotEmpty) && (item['total_weight'] ?? 0) > 0) {
                        double itemTotalWeight = item['total_weight'] ?? 0;
                        String itemUnit = item['unit'] ?? 'TON';
                        double itemTotalPrice = item['total_price'] ?? 0;
                        String itemCurrency = item['currency']?.toString() ?? 'USD';
                        double itemRate = double.tryParse(item['rateCtrl'].text) ?? 65.0;

                        double loadingCostItem, transferCostItem, clearanceCostItem, discountItem;
                        if (itemCurrency == 'AFN') {
                          loadingCostItem = loadingCost; transferCostItem = transferCost;
                          clearanceCostItem = clearanceCost; discountItem = discount;
                        } else {
                          loadingCostItem = itemRate > 0 ? loadingCost / itemRate : 0;
                          transferCostItem = itemRate > 0 ? transferCost / itemRate : 0;
                          clearanceCostItem = itemRate > 0 ? clearanceCost / itemRate : 0;
                          discountItem = itemRate > 0 ? discount / itemRate : 0;
                        }

                        double itemFinalPrice = itemTotalPrice + loadingCostItem + transferCostItem + clearanceCostItem - discountItem;

                        double itemAfnEquivalent;
                        if (itemCurrency == 'USD') itemAfnEquivalent = itemFinalPrice * itemRate;
                        else itemAfnEquivalent = itemFinalPrice;

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
                          'currency': itemCurrency,
                          'exchange_rate': itemRate,
                          'loading_cost': loadingCost,
                          'transfer_cost': transferCost,
                          'clearance_cost': clearanceCost,
                          'discount': discount,
                          'final_price': itemFinalPrice,
                          'afn_equivalent': itemAfnEquivalent,
                          'date': dateController.text.trim(),
                          'date_en': selectedEnglishDate,
                        };

                        final id = await _db.insertServiceInvoice(payload);
                        if (id != -1) insertedIds.add(id);
                      }
                    }

                    if (insertedIds.isEmpty) { _showSnackbar('❌ خطا در ذخیره خدمات', Colors.red); return; }
                    if (!mounted) return;
                    Navigator.pop(context);
                    await _loadServices();

                    final allInvoices = await _db.getServiceInvoices();
                    List<Map<String, dynamic>> allItems = [];
                    Map<String, dynamic>? firstInvoice;
                    for (var inv in allInvoices) {
                      if (inv['invoice_number'] == invoiceNumber) {
                        allItems.add(inv);
                        if (firstInvoice == null) firstInvoice = inv;
                      }
                    }
                    if (firstInvoice != null) {
                      firstInvoice['items'] = allItems;
                      _showServiceInvoiceModal(context, invoiceNumber, firstInvoice, l10n);
                    }
                    _showSnackbar('✅ ${insertedIds.length} خدمت با موفقیت ثبت شد', Colors.green);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(service == null ? l10n.saveService : l10n.saveChanges),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // INVOICE MODAL
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
          'currency': invoice['currency']?.toString() ?? 'USD',
          'exchange_rate': double.tryParse(invoice['exchange_rate']?.toString() ?? '65') ?? 65,
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
                          Container(
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: const Color(0xFFCB001D), width: 3))),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(l10n.companyName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                                  const SizedBox(height: 4),
                                  Text(l10n.integratedSystem, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ]),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(color: const Color(0xFFCB001D), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('بل ثبت خدمات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                            child: Column(children: [
                              Container(
                                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
                                child: Row(children: [
                                  Expanded(child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    child: Row(children: [
                                      const Text('مشتری', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Container(
                                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
                                        child: Text(invoice['customer_name']?.toString() ?? '-', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                                      )),
                                    ]),
                                  )),
                                  Container(width: 1, height: 30, color: Colors.black),
                                  Expanded(child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    child: Row(children: [
                                      const Text('شماره فاکتور', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Container(
                                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
                                        child: Text(invoiceNumber, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                                      )),
                                    ]),
                                  )),
                                ]),
                              ),
                              Container(
                                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
                                child: Row(children: [
                                  Expanded(child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    child: Row(children: [
                                      const Text('تلفن', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Container(
                                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
                                        child: Text(invoice['customer_phone']?.toString() ?? '', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                                      )),
                                    ]),
                                  )),
                                  Container(width: 1, height: 30, color: Colors.black),
                                  Expanded(child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    child: Row(children: [
                                      const Text('تاریخ شمسی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Container(
                                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
                                        child: Text(invoice['date']?.toString() ?? '-', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                                      )),
                                    ]),
                                  )),
                                ]),
                              ),
                              Row(children: [
                                Expanded(flex: 2, child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1))),
                                  child: Row(children: [
                                    const Text('آدرس', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Container(
                                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
                                      child: Text(invoice['customer_address']?.toString() ?? '', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                                    )),
                                  ]),
                                )),
                                Container(width: 1, height: 30, color: Colors.black),
                                Expanded(child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  child: Row(children: [
                                    const Text('تاریخ میلادی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Container(
                                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
                                      child: Text(invoice['date_en']?.toString() ?? '-', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                                    )),
                                  ]),
                                )),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 20),
                          _buildServiceInvoiceTable(items, invoice, l10n),
                          const SizedBox(height: 20),
                          _buildServiceFinancialSummary(invoice, l10n),
                          const SizedBox(height: 20),
                          _buildInvoiceSignatureRow(),
                          const SizedBox(height: 20),
                          _buildInvoiceLegalTerms(),
                          const SizedBox(height: 16),
                          _buildInvoiceOfficeRegistry(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.close, style: const TextStyle(fontSize: 12))),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _saveServiceInvoicePdf(invoice, invoiceNumber, l10n);
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                          label: Text(l10n.savePdf, style: const TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _printServiceInvoicePdf(invoice, invoiceNumber, l10n);
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.print, size: 18, color: Colors.white),
                          label: Text(l10n.print, style: const TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
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

  Widget _buildServiceInvoiceTable(List<Map<String, dynamic>> items, Map<String, dynamic> invoice, AppLocalizations l10n) {
    const headerFont = TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black);
    const bodyFont = TextStyle(fontSize: 10, color: Colors.black);

    List<List<String>> tableData = [];
    int rowIndex = 1;
    double totalWeightSum = 0;

    for (var item in items) {
      String serviceType = item['service_type']?.toString() ?? '-';
      String size = item['size']?.toString() ?? '-';
      String thickness = item['thickness']?.toString() ?? '-';
      double totalWeight = item['total_weight'] ?? 0;
      String unit = item['unit']?.toString() ?? 'TON';
      double unitPrice = item['unit_price'] ?? 0;
      double totalPrice = item['total_price'] ?? 0;
      String cur = item['currency']?.toString() ?? 'USD';
      double rate = double.tryParse(item['exchange_rate']?.toString() ?? '1') ?? 1;

      totalWeightSum += totalWeight;

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
        cur,
        rate.toStringAsFixed(0),
      ]);
      rowIndex++;
    }

    while (tableData.length < 4) {
      tableData.add(['', '', '', '', '', '', '', '', '']);
    }

    tableData.add([
      'مجموعه:',
      '',
      '',
      '',
      totalWeightSum > 0 ? '${totalWeightSum.toStringAsFixed(2)} تن' : '0',
      '',
      '',
      '',
      '',
    ]);

    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: const {
        0: FixedColumnWidth(35),
        1: FixedColumnWidth(90),
        2: FixedColumnWidth(55),
        3: FixedColumnWidth(55),
        4: FixedColumnWidth(75),
        5: FixedColumnWidth(65),
        6: FixedColumnWidth(75),
        7: FixedColumnWidth(45),
        8: FixedColumnWidth(50),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.blue[100]),
          children: [
            'شماره', 'نوع خدمت', 'سایز', 'ضخامت', 'مجموع وزن',
            'قیمت واحد', 'قیمت کل', 'واحد پول', 'نرخ ارز',
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

  Widget _buildServiceFinancialSummary(Map<String, dynamic> invoice, AppLocalizations l10n) {
    List<Map<String, dynamic>> items = [];
    if (invoice.containsKey('items') && invoice['items'] is List) {
      items = List<Map<String, dynamic>>.from(invoice['items']);
    }

    // ==========================================
    // مجموع دالر = Σ (weight_tons × unit_price) 
    // مجموع افغانی = مجموع دالر × نرخ ارز
    // ==========================================
    double totalUsd = 0;
    double totalAfn = 0;
    double discountAfn = 0;

    // Use first item's exchange rate as the representative rate
    double exchangeRate = 65;
    if (items.isNotEmpty) {
      exchangeRate = double.tryParse(items.first['exchange_rate']?.toString() ?? '65') ?? 65;
      if (exchangeRate <= 0) exchangeRate = 65;
    }

    for (var item in items) {
      final weight = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
      final uPrice = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
      final tPrice = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
      final rate = double.tryParse(item['exchange_rate']?.toString() ?? '1') ?? 1;
      final cur = item['currency']?.toString() ?? 'USD';
      final disc = double.tryParse(item['discount']?.toString() ?? '0') ?? 0;

      // Prefer Excel-provided total_price; else compute weight × unit_price
      double rowTotal = tPrice > 0 ? tPrice : (weight * uPrice);

      double rowUsd;
      double rowAfn;
      if (cur == 'USD') {
        rowUsd = rowTotal;
        rowAfn = rowTotal * rate;
      } else {
        rowAfn = rowTotal;
        rowUsd = rate > 0 ? rowTotal / rate : 0;
      }
      totalUsd += rowUsd;
      totalAfn += rowAfn;
      discountAfn += disc;
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
          const Text('اطلاعات مالی مجموعه',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFCB001D))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('مجموع قیمت (دالر)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCB001D))),
                  Text('\$${_formatCurrency(totalUsd)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCB001D))),
                ],
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('مجموع قیمت (افغانی)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                  Text('AFN ${_formatCurrency(totalAfn)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                ],
              ),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تخفیف',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.orange.shade700)),
                  Text('AFN ${_formatCurrency(discountAfn)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                ],
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('نرخ ارز',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.green.shade700)),
                  Text(exchangeRate.toStringAsFixed(0),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                ],
              ),
            )),
          ]),
        ],
      ),
    );
  }

  Future<Uint8List> _generateServiceInvoicePdfBytes(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    String getPdfValue(String key, {String defaultValue = '-'}) => invoice[key]?.toString() ?? defaultValue;

    List<Map<String, dynamic>> items = [];
    if (invoice.containsKey('items') && invoice['items'] is List) {
      items = List<Map<String, dynamic>>.from(invoice['items']);
    }

    List<List<String>> tableData = [];
    int rowIndex = 1;
    double totalWeightSum = 0;
    double totalUsdSum = 0;
    double totalAfnSum = 0;
    double exchangeRate = 65;

    if (items.isNotEmpty) {
      exchangeRate = double.tryParse(items.first['exchange_rate']?.toString() ?? '65') ?? 65;
      if (exchangeRate <= 0) exchangeRate = 65;
    }

    for (var item in items) {
      String serviceType = item['service_type']?.toString() ?? '-';
      String size = item['size']?.toString() ?? '-';
      String thickness = item['thickness']?.toString() ?? '-';
      double totalWeight = item['total_weight'] ?? 0;
      double unitPrice = item['unit_price'] ?? 0;
      double totalPrice = item['total_price'] ?? 0;
      String cur = item['currency']?.toString() ?? 'USD';
      double rate = double.tryParse(item['exchange_rate']?.toString() ?? '1') ?? 1;

      totalWeightSum += totalWeight;

      double rowTotal = totalPrice > 0 ? totalPrice : (totalWeight * unitPrice);
      if (cur == 'USD') {
        totalUsdSum += rowTotal;
        totalAfnSum += rowTotal * rate;
      } else {
        totalAfnSum += rowTotal;
        totalUsdSum += rate > 0 ? rowTotal / rate : 0;
      }

      tableData.add([
        rowIndex.toString(),
        serviceType,
        size,
        thickness,
        '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2)} تن',
        unitPrice.toStringAsFixed(0),
        totalPrice.toStringAsFixed(0),
      ]);
      rowIndex++;
    }

    if (tableData.isEmpty) tableData.add(['1', '-', '-', '-', '0', '0', '0']);

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
                          child: pw.Text('بل ثبت خدمات', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
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
                            headers: ['شماره', 'نوع خدمت', 'سایز', 'ضخامت', 'مجموع وزن', 'قیمت واحد', 'قیمت کل'],
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
                                pw.Text('مجموع دالر: ${totalUsdSum.toStringAsFixed(2)} USD', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.green)),
                              ]),
                              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                                pw.Text('مجموع افغانی: ${_formatCurrency(totalAfnSum)} AFN', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
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
              pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (context) => pw.Center(child: pw.Image(pwImage, fit: pw.BoxFit.contain))));
              bytes = await pdf.save();
            }
          }
        }
      } catch (e) { bytes = null; }
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
              pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (context) => pw.Center(child: pw.Image(pwImage, fit: pw.BoxFit.contain))));
              bytes = await pdf.save();
            }
          }
        }
      } catch (e) { bytes = null; }
      bytes ??= await _generateServiceInvoicePdfBytes(invoice, invoiceNumber, l10n);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes!, name: 'service_invoice_${invoiceNumber.replaceAll(' ', '_')}.pdf');
    } catch (e) {
      _showSnackbar('${l10n.errorPrintingInvoice}: $e', Colors.red);
    }
  }

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
          child: Column(children: [
            const Text('امضا مسئول', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(width: 140, height: 1.2, color: Colors.black),
          ]),
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
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          Text('Before carry, please check quality & quantity.', style: termsStyleEn, textDirection: TextDirection.ltr),
          Text('.لطفا قبل از انتقال کیفیت، تعداد ومقدار جنس را چک نمائید', style: termsStyleFa),
        ]),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          Text('Transportation services will provide by carrier company against specified freight.', style: termsStyleEn, textDirection: TextDirection.ltr),
          Text('.خدمات ترانسپورتی درمقابل کرایه معین توسط شرکت باربری مهیا میگردد', style: termsStyleFa),
        ]),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          Text('Terms & conditions of seller are applicable.', style: termsStyleEn, textDirection: TextDirection.ltr),
          Text('.مقررات و شرایط فروشنده قابل تطبیق میباشد', style: termsStyleFa),
        ]),
      ],
    );
  }

  Widget _buildInvoiceOfficeRegistry() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.yellow[600],
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            child: const Text('مخصوص ثبت دفاتر:',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(child: _buildInvoiceInlineInput('شماره:', '')),
              const SizedBox(width: 10),
              Expanded(child: _buildInvoiceInlineInput('صفحه:', '')),
              const SizedBox(width: 10),
              Expanded(child: _buildInvoiceInlineInput('جلد:', '')),
              const SizedBox(width: 10),
              Expanded(child: _buildInvoiceInlineInput('مؤرخ:', '    /    /  ')),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _buildInvoiceInlineInput('امضا ثبت کننده:', '')),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceInlineInput(String label, String explicitValue) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(width: 6),
      Expanded(child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black54, width: 1))),
        child: Text(explicitValue, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      )),
    ]);
  }

  Widget _buildSectionTitle(String title, AppLocalizations l10n) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)));
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
        duration: const Duration(seconds: 3),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final items = (service['items'] is List) ? List<Map<String, dynamic>>.from(service['items']) : <Map<String, dynamic>>[];
      if (items.isNotEmpty) {
        for (var it in items) {
          if (it['id'] != null) await _db.deleteServiceInvoice(it['id'] as int);
        }
      } else {
        await _db.deleteServiceInvoice(service['id']);
      }
      await _loadServices();
      _showSnackbar(l10n.serviceDeletedSuccess, Colors.orange);
    } catch (e) {
      _showSnackbar(l10n.errorDeletingService, Colors.red);
    }
  }

  void _showBulkDeleteDialog(BuildContext context, AppLocalizations l10n) {
    final count = _selectedServices.length;
    if (count == 0) return;
    final selectedServices = _services.where((s) => _selectedServices.contains((s['invoice_number'] ?? s['id'] ?? '').toString())).toList();
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_sweep, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('حذف خدمات انتخاب شده', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          ]),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.2), width: 1),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('هشدار!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                      const SizedBox(height: 4),
                      Text('شما در حال حذف $count فاکتور خدمت هستید. تمام اقلام این فاکتورها نیز پاک می‌شوند. این عمل قابل بازگشت نیست!',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),
                const Text('خدمات زیر حذف خواهند شد:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: selectedServices.map((service) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• ${service['invoice_number'] ?? '-'} — ${service['customer_name'] ?? '-'}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A))),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف', style: TextStyle(color: Colors.grey))),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _performBulkDelete(_selectedServices.toList());
              },
              icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
              label: Text('حذف $count مورد', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAllDialog(BuildContext context, AppLocalizations l10n) {
    final count = _services.length;
    if (count == 0) return;
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.dangerous, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('حذف تمام خدمات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)))),
          ]),
          content: SizedBox(
            width: 420,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                    const SizedBox(width: 10),
                    Expanded(child: Text('هشدار جدی!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade800))),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'شما در حال حذف تمام $count فاکتور خدمت هستید.\nتمام اقلام این فاکتورها نیز پاک خواهند شد.\nاین عمل کاملاً غیرقابل بازگشت است!',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف', style: TextStyle(color: Colors.grey))),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _performDeleteAll();
              },
              icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
              label: const Text('حذف همه', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performBulkDelete(List<String> invoiceNumbers) async {
    setState(() => _isLoading = true);
    try {
      final deleted = await _db.deleteServiceInvoicesByNumbers(invoiceNumbers);
      if (!mounted) return;
      if (deleted > 0) {
        _showSnackbar('✅ $deleted فاکتور خدمت با موفقیت حذف شد', Colors.green);
        _selectedServices.clear();
        await _loadServices();
      } else {
        setState(() => _isLoading = false);
        _showSnackbar('❌ خطا در حذف خدمات', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('❌ خطا: $e', Colors.red);
    }
  }

  Future<void> _performDeleteAll() async {
    setState(() => _isLoading = true);
    try {
      final deleted = await _db.deleteAllServiceInvoices();
      if (!mounted) return;
      if (deleted >= 0) {
        _showSnackbar('🗑️ تمام $deleted فاکتور خدمت حذف شدند', Colors.red.shade700);
        _selectedServices.clear();
        await _loadServices();
      } else {
        setState(() => _isLoading = false);
        _showSnackbar('❌ خطا در حذف تمام خدمات', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('❌ خطا: $e', Colors.red);
    }
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.design_services, color: Color(0xFFCB001D), size: 28),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.servicesManagement, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            Text(l10n.servicesManagementSubtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ]),
        ]),
        Row(children: [
          if (_selectedServices.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Color(0xFFCB001D), size: 14),
                const SizedBox(width: 4),
                Text('${_selectedServices.length} ${l10n.selected}',
                  style: const TextStyle(color: Color(0xFFCB001D), fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          if (_selectedServices.isNotEmpty) const SizedBox(width: 8),
          if (_selectedServices.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () => _showBulkDeleteDialog(context, l10n),
              icon: const Icon(Icons.delete_sweep, color: Colors.white, size: 18),
              label: Text('حذف ${_selectedServices.length} مورد', style: const TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          if (_selectedServices.isNotEmpty) const SizedBox(width: 10),
          if (_services.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => _showDeleteAllDialog(context, l10n),
              icon: Icon(Icons.delete_forever, color: Colors.red.shade700, size: 18),
              label: Text('حذف همه', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade700, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          if (_services.isNotEmpty) const SizedBox(width: 10),
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
        ]),
      ],
    );
  }

  Widget _buildQuickStats(AppLocalizations l10n) {
    final totalServices = _services.length;
    double totalUsd = 0;
    double totalAfn = 0;
    for (var service in _services) {
      final usd = double.tryParse(service['total_sell_usd']?.toString() ?? '0') ?? 0;
      final afn = double.tryParse(service['total_sell_afn']?.toString() ?? '0') ?? 0;
      totalUsd += usd;
      totalAfn += afn;
    }
    double totalWeightInTons = 0;
    for (var service in _services) {
      String unit = service['unit']?.toString() ?? 'TON';
      double weight = double.tryParse(service['total_weight']?.toString() ?? '0') ?? 0;
      if (unit == 'KG' || unit == 'kg' || unit == 'کیلوگرم') totalWeightInTons += weight / 1000;
      else totalWeightInTons += weight;
    }
    return Row(children: [
      _buildStatCard(l10n.totalServicesCount, totalServices.toString(), Icons.design_services_outlined, Colors.blue.shade700),
      const SizedBox(width: 12),
      _buildStatCard('مجموع دالر', '\$${_formatCurrency(totalUsd)}', Icons.attach_money, Colors.green.shade700),
      const SizedBox(width: 12),
      _buildStatCard('مجموع افغانی', 'AFN ${_formatCurrency(totalAfn)}', Icons.currency_exchange, Colors.purple.shade700),
      const SizedBox(width: 12),
      _buildStatCard('مجموع وزن', '${totalWeightInTons.toStringAsFixed(totalWeightInTons % 1 == 0 ? 0 : 2)} تن', Icons.scale, const Color(0xFFCB001D)),
    ]);
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
            child: Icon(icon, color: color, size: 18),
          ),
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
    final filters = [l10n.allFilter, l10n.servicesFilter];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: l10n.searchServices,
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2)),
          ),
        )),
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
  // MAIN TABLE — NOW WITH قیمت واحد column
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
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
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
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
                        ),
                        child: Row(children: [
                          SizedBox(width: 50, child: Checkbox(
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
                          )),
                          _buildHeaderCell(l10n.invoiceNumberLabel, 100),
                          _buildHeaderCell(l10n.customer, 140),
                          _buildHeaderCell(l10n.customerPhone, 110),
                          _buildHeaderCell('خدمات', 130),
                          _buildHeaderCell('مجموع وزن', 80),
                          _buildHeaderCell('قیمت واحد', 80),     // ✅ NEW
                          _buildHeaderCell('نرخ ارز', 70),       // ✅ NEW
                          _buildHeaderCell('مجموع دالر', 110),
                          _buildHeaderCell('مجموع افغانی', 110),
                          _buildHeaderCell('بارگیری', 80),
                          _buildHeaderCell('حمل', 80),
                          _buildHeaderCell('ترخیص', 80),
                          _buildHeaderCell('تخفیف', 80),
                          _buildHeaderCell('تاریخ', 100),
                          _buildHeaderCell(l10n.actions, 130),
                        ]),
                      ),

                      if (paged.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          child: Center(child: Text(l10n.noServicesFound, style: const TextStyle(color: Colors.grey, fontSize: 13))),
                        )
                      else
                        ...paged.map((service) {
                          final id = (service['invoice_number'] ?? service['id'] ?? '').toString();
                          final checked = _selectedServices.contains(id);
                          
                          double totalWeight = double.tryParse(service['total_weight']?.toString() ?? '0') ?? 0;
                          String displayWeight = '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 2)} تن';
                          
                          final serviceTypes = service['service_types'] as List?;
                          final serviceCount = service['service_count'] ?? 1;
                          
                          double loadingCost = double.tryParse(service['loading_cost']?.toString() ?? '0') ?? 0;
                          double transferCost = double.tryParse(service['transfer_cost']?.toString() ?? '0') ?? 0;
                          double clearanceCost = double.tryParse(service['clearance_cost']?.toString() ?? '0') ?? 0;
                          double discount = double.tryParse(service['discount']?.toString() ?? '0') ?? 0;

                          double unitPrice = double.tryParse(service['unit_price']?.toString() ?? '0') ?? 0;
                          double exchangeRate = double.tryParse(service['exchange_rate']?.toString() ?? '0') ?? 0;

                          double totalUsd = double.tryParse(service['total_sell_usd']?.toString() ?? '0') ?? 0;
                          double totalAfn = double.tryParse(service['total_sell_afn']?.toString() ?? '0') ?? 0;
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: checked ? const Color(0xFFCB001D).withOpacity(0.03) : Colors.white,
                              border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
                            ),
                            child: Row(children: [
                              SizedBox(width: 50, child: Checkbox(
                                value: checked,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) _selectedServices.add(id);
                                    else _selectedServices.remove(id);
                                  });
                                },
                              )),
                              _buildDataCell(service['invoice_number']?.toString() ?? '-', 100, isBold: true),
                              _buildDataCell(service['customer_name'] ?? '-', 140, isBold: true),
                              _buildDataCell(service['customer_phone'] ?? '-', 110),
                              SizedBox(width: 130, child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (serviceTypes != null && serviceTypes.isNotEmpty)
                                    ...serviceTypes.take(2).map((name) => Text(name?.toString() ?? '-',
                                      style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))
                                  else
                                    Text(service['service_type'] ?? '-', style: const TextStyle(fontSize: 11)),
                                  if (serviceTypes != null && serviceTypes.length > 2)
                                    Text('و ${serviceTypes.length - 2} خدمت دیگر...',
                                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCB001D).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('$serviceCount خدمت',
                                      style: const TextStyle(fontSize: 9, color: Color(0xFFCB001D), fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              )),
                              _buildDataCell(displayWeight, 80),
                              _buildDataCell(unitPrice > 0 ? unitPrice.toStringAsFixed(0) : '-', 80),   // ✅ قیمت واحد
                              _buildDataCell(exchangeRate > 0 ? exchangeRate.toStringAsFixed(0) : '-', 70), // ✅ نرخ ارز
                              _buildDataCell('\$${_formatCurrency(totalUsd)}', 110, isBold: true, color: Colors.green.shade700),
                              _buildDataCell('AFN ${_formatCurrency(totalAfn)}', 110, isBold: true, color: Colors.purple.shade700),
                              _buildDataCell(loadingCost > 0 ? _formatCurrency(loadingCost) : '-', 80, color: loadingCost > 0 ? Colors.orange.shade700 : Colors.grey),
                              _buildDataCell(transferCost > 0 ? _formatCurrency(transferCost) : '-', 80, color: transferCost > 0 ? Colors.orange.shade700 : Colors.grey),
                              _buildDataCell(clearanceCost > 0 ? _formatCurrency(clearanceCost) : '-', 80, color: clearanceCost > 0 ? Colors.orange.shade700 : Colors.grey),
                              _buildDataCell(discount > 0 ? _formatCurrency(discount) : '-', 80, color: discount > 0 ? Colors.red.shade700 : Colors.grey),
                              _buildDataCell(service['date'] ?? '-', 100),
                              SizedBox(width: 130, child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () => _showServiceInvoiceModal(context, service['invoice_number'] ?? '-', service, l10n),
                                    icon: const Icon(Icons.visibility_outlined, color: Colors.blue, size: 20),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    padding: EdgeInsets.zero, tooltip: 'مشاهده فاکتور',
                                  ),
                                  IconButton(
                                    onPressed: () => _showServiceDialog(service: service),
                                    icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    padding: EdgeInsets.zero, tooltip: 'ویرایش',
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteService(service),
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    padding: EdgeInsets.zero, tooltip: 'حذف',
                                  ),
                                ],
                              )),
                            ]),
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
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Text('${l10n.page} ${_currentPage + 1} ${l10n.pageOf} ${totalPages == 0 ? 1 : totalPages}'),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                    icon: const Icon(Icons.chevron_left),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30), padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: (_currentPage + 1) < totalPages ? () => setState(() => _currentPage++) : null,
                    icon: const Icon(Icons.chevron_right),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30), padding: EdgeInsets.zero,
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
                    onChanged: (v) => setState(() { _rowsPerPage = v ?? 10; _currentPage = 0; }),
                  ),
                ]),
                Row(children: [
                  Text('${l10n.selected}: ${_selectedServices.length}'),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedServices.isEmpty ? null : () => _showBulkDeleteDialog(context, l10n),
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
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A1A1A)),
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
      final matchesFilter = _selectedFilter == 'همه' || (service['service_type'] ?? '').toString().isNotEmpty;
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
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
  final GlobalKey _invoicePreviewKey = GlobalKey();

  // ============================================
  // PRODUCT ITEMS - For multi-product support
  // ============================================
  List<Map<String, dynamic>> _invoiceItems = [];
  int _nextItemIndex = 1;

  bool _isWeightUnit(String unit) {
    return unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg' || 
           unit == 'تن' || unit == 'ton' || unit == 'Ton';
  }

  String _formatWeightWithConversion(String unit, double weight) {
    if (_isWeightUnit(unit)) {
      double tons = weight / 1000;
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} $unit';
  }

  String _formatWeightForInvoice(String unit, double weight) {
    if (weight == 0) return '0';
    if (_isWeightUnit(unit)) {
      double tons = weight / 1000;
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)}';
    }
    return weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1);
  }

  String _formatRawWeightForInvoice(String unit, double weight) {
    if (weight == 0) return '0';
    if (_isWeightUnit(unit)) {
      return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)}';
    }
    return weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1);
  }

  double _getTotalTons() {
    double totalTons = 0;
    for (var sale in _sales) {
      String unit = sale['unit']?.toString() ?? '';
      double weight = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
      
      if (_isWeightUnit(unit)) {
        if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
          totalTons += weight / 1000;
        } else {
          totalTons += weight;
        }
      }
    }
    return totalTons;
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
        await _loadData();
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

      int invoiceNumberIndex = -1;
      int customerNameIndex = -1;
      int productNameIndex = -1;
      int unitPriceIndex = -1;
      int totalWeightIndex = -1;
      int finalPriceIndex = -1;
      int dateIndex = -1;
      int currencyIndex = -1;
      int paymentMethodIndex = -1;
      int descriptionIndex = -1;
      int customerPhoneIndex = -1;
      int customerAddressIndex = -1;
      int companyIndex = -1;
      int genderIndex = -1;
      int sizeIndex = -1;
      int thicknessIndex = -1;
      int weightPerUnitIndex = -1;
      int unitCountIndex = -1;
      int unitIndex = -1;
      int totalPriceIndex = -1;
      int loadingCostIndex = -1;
      int transferCostIndex = -1;
      int clearanceCostIndex = -1;
      int discountIndex = -1;
      int saleTypeIndex = -1;
      int priceRateIndex = -1;

      for (int i = 0; i < headers.length; i++) {
        String h = headers[i];
        String hLower = h.toLowerCase();
        if (hLower.contains('شماره') || hLower.contains('فاکتور') || hLower.contains('invoice')) {
          invoiceNumberIndex = i;
        } else if (hLower.contains('مشتری') || hLower.contains('خریدار') || hLower.contains('نام مشتری') || hLower.contains('customer')) {
          customerNameIndex = i;
        } else if (hLower.contains('محصول') || hLower.contains('کالا') || hLower.contains('product')) {
          productNameIndex = i;
        } else if (hLower.contains('قیمت واحد') || hLower.contains('unit price')) {
          unitPriceIndex = i;
        } else if (hLower.contains('وزن کل') || hLower.contains('total weight')) {
          totalWeightIndex = i;
        } else if (hLower.contains('قیمت نهایی') || hLower.contains('final price')) {
          finalPriceIndex = i;
        } else if (hLower.contains('تاریخ') || hLower.contains('date')) {
          dateIndex = i;
        } else if (hLower.contains('ارز') || hLower.contains('واحد پول') || hLower.contains('currency')) {
          currencyIndex = i;
        } else if (hLower.contains('پرداخت') || hLower.contains('payment')) {
          paymentMethodIndex = i;
        } else if (hLower.contains('توضیحات') || hLower.contains('شرح') || hLower.contains('description')) {
          descriptionIndex = i;
        } else if (hLower.contains('تلفن') || hLower.contains('phone')) {
          customerPhoneIndex = i;
        } else if (hLower.contains('آدرس') || hLower.contains('address')) {
          customerAddressIndex = i;
        } else if (hLower.contains('شرکت') || hLower.contains('company')) {
          companyIndex = i;
        } else if (hLower.contains('نوغ') || hLower.contains('gender')) {
          genderIndex = i;
        } else if (hLower.contains('سایز') || hLower.contains('size')) {
          sizeIndex = i;
        } else if (hLower.contains('ضخامت') || hLower.contains('thickness')) {
          thicknessIndex = i;
        } else if (hLower.contains('وزن واحد') || hLower.contains('weight per unit')) {
          weightPerUnitIndex = i;
        } else if (hLower.contains('تعداد') || hLower.contains('unit count')) {
          unitCountIndex = i;
        } else if (hLower.contains('واحد') && !hLower.contains('پول')) {
          unitIndex = i;
        } else if (hLower.contains('قیمت کل') || hLower.contains('total price')) {
          totalPriceIndex = i;
        } else if (hLower.contains('بارگیری') || hLower.contains('loading cost')) {
          loadingCostIndex = i;
        } else if (hLower.contains('حمل') || hLower.contains('transfer cost')) {
          transferCostIndex = i;
        } else if (hLower.contains('ترخیص') || hLower.contains('clearance cost')) {
          clearanceCostIndex = i;
        } else if (hLower.contains('تخفیف') || hLower.contains('discount')) {
          discountIndex = i;
        } else if (hLower.contains('نوع') || hLower.contains('sale type')) {
          saleTypeIndex = i;
        } else if (hLower.contains('نرخ') || hLower.contains('price rate')) {
          priceRateIndex = i;
        }
      }

      if (invoiceNumberIndex == -1 || customerNameIndex == -1 || productNameIndex == -1) {
        return {
          'success': false,
          'message': 'فیلدهای مورد نیاز پیدا نشد: شماره فاکتور، مشتری، محصول'
        };
      }

      final customers = await _db.getCustomers();
      final companies = await _db.getCompanies();
      Map<String, int> customerMap = {};
      for (var c in customers) {
        customerMap[c['name']?.toString() ?? ''] = c['id'];
      }
      for (var c in companies) {
        customerMap[c['name']?.toString() ?? ''] = c['id'];
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
          String productName = _getCellValueDirect(row, productNameIndex);
          
          String unitPriceStr = unitPriceIndex != -1 ? _getCellValueDirect(row, unitPriceIndex) : '0';
          String totalWeightStr = totalWeightIndex != -1 ? _getCellValueDirect(row, totalWeightIndex) : '0';
          String finalPriceStr = finalPriceIndex != -1 ? _getCellValueDirect(row, finalPriceIndex) : '0';
          String date = dateIndex != -1 ? _getCellValueDirect(row, dateIndex) : '';
          String currency = currencyIndex != -1 ? _getCellValueDirect(row, currencyIndex) : 'USD';
          String paymentMethod = paymentMethodIndex != -1 ? _getCellValueDirect(row, paymentMethodIndex) : 'cash';
          String description = descriptionIndex != -1 ? _getCellValueDirect(row, descriptionIndex) : '';
          String phone = customerPhoneIndex != -1 ? _getCellValueDirect(row, customerPhoneIndex) : '';
          String address = customerAddressIndex != -1 ? _getCellValueDirect(row, customerAddressIndex) : '';
          String company = companyIndex != -1 ? _getCellValueDirect(row, companyIndex) : '';
          String gender = genderIndex != -1 ? _getCellValueDirect(row, genderIndex) : '';
          String size = sizeIndex != -1 ? _getCellValueDirect(row, sizeIndex) : '';
          String thickness = thicknessIndex != -1 ? _getCellValueDirect(row, thicknessIndex) : '';
          String weightPerUnitStr = weightPerUnitIndex != -1 ? _getCellValueDirect(row, weightPerUnitIndex) : '0';
          String unitCountStr = unitCountIndex != -1 ? _getCellValueDirect(row, unitCountIndex) : '0';
          String unit = unitIndex != -1 ? _getCellValueDirect(row, unitIndex) : 'کیلوگرم';
          String totalPriceStr = totalPriceIndex != -1 ? _getCellValueDirect(row, totalPriceIndex) : '0';
          String loadingCostStr = loadingCostIndex != -1 ? _getCellValueDirect(row, loadingCostIndex) : '0';
          String transferCostStr = transferCostIndex != -1 ? _getCellValueDirect(row, transferCostIndex) : '0';
          String clearanceCostStr = clearanceCostIndex != -1 ? _getCellValueDirect(row, clearanceCostIndex) : '0';
          String discountStr = discountIndex != -1 ? _getCellValueDirect(row, discountIndex) : '0';
          String saleType = saleTypeIndex != -1 ? _getCellValueDirect(row, saleTypeIndex) : 'فروش';
          String priceRateStr = priceRateIndex != -1 ? _getCellValueDirect(row, priceRateIndex) : '1';

          unitPriceStr = unitPriceStr.replaceAll(RegExp(r'[$,]'), '').trim();
          totalWeightStr = totalWeightStr.replaceAll(RegExp(r'[$,]'), '').trim();
          finalPriceStr = finalPriceStr.replaceAll(RegExp(r'[$,]'), '').trim();
          totalPriceStr = totalPriceStr.replaceAll(RegExp(r'[$,]'), '').trim();
          loadingCostStr = loadingCostStr.replaceAll(RegExp(r'[$,]'), '').trim();
          transferCostStr = transferCostStr.replaceAll(RegExp(r'[$,]'), '').trim();
          clearanceCostStr = clearanceCostStr.replaceAll(RegExp(r'[$,]'), '').trim();
          discountStr = discountStr.replaceAll(RegExp(r'[$,]'), '').trim();
          weightPerUnitStr = weightPerUnitStr.replaceAll(RegExp(r'[$,]'), '').trim();
          unitCountStr = unitCountStr.replaceAll(RegExp(r'[$,]'), '').trim();
          priceRateStr = priceRateStr.replaceAll(RegExp(r'[$,]'), '').trim();

          if (invoiceNumber.isEmpty || customerName.isEmpty || productName.isEmpty) {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': فیلدهای مورد نیاز کامل نیستند');
            continue;
          }

          final existing = await _db.getSalesInvoiceByNumber(invoiceNumber);
          if (existing != null) {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': شماره فاکتور "' + invoiceNumber + '" تکراری است');
            continue;
          }

          double unitPrice = _parseNumber(unitPriceStr);
          double totalWeight = _parseNumber(totalWeightStr);
          double finalPrice = _parseNumber(finalPriceStr);
          double totalPrice = _parseNumber(totalPriceStr);
          double loadingCost = _parseNumber(loadingCostStr);
          double transferCost = _parseNumber(transferCostStr);
          double clearanceCost = _parseNumber(clearanceCostStr);
          double discount = _parseNumber(discountStr);
          double weightPerUnit = _parseNumber(weightPerUnitStr);
          double unitCount = _parseNumber(unitCountStr);
          double priceRate = _parseNumber(priceRateStr);

          if (finalPrice <= 0 && totalPrice > 0) {
            finalPrice = totalPrice + loadingCost + transferCost + clearanceCost - discount;
          }

          if (totalWeight <= 0 && weightPerUnit > 0 && unitCount > 0) {
            totalWeight = weightPerUnit * unitCount;
          }

          double usdEquivalent = 0;
          double afnEquivalent = 0;
          String currencyFinal = 'USD';
          if (currency == 'USD' || currency == 'دلار' || currency == '\$') {
            usdEquivalent = finalPrice;
            afnEquivalent = finalPrice * priceRate;
            currencyFinal = 'USD';
          } else if (currency == 'AFN' || currency == 'افغانی') {
            afnEquivalent = finalPrice;
            usdEquivalent = priceRate > 0 ? finalPrice / priceRate : 0;
            currencyFinal = 'AFN';
          } else {
            usdEquivalent = finalPrice;
            afnEquivalent = finalPrice * priceRate;
            currencyFinal = 'USD';
          }

          if (date.isEmpty) {
            date = PersianDateConverter.gregorianToJalali(DateTime.now());
          }
          String dateEn = PersianDateConverter.getEnglishDate(DateTime.now());

          String paymentMethodFinal = 'cash';
          String pLower = paymentMethod.toLowerCase();
          if (pLower.contains('نقد') || pLower.contains('cash')) {
            paymentMethodFinal = 'cash';
          } else if (pLower.contains('قرض کامل') || pLower.contains('full')) {
            paymentMethodFinal = 'loan_full';
          } else if (pLower.contains('قرض جزئی') || pLower.contains('partial')) {
            paymentMethodFinal = 'loan_partial';
          }

          Map<String, dynamic> sale = {
            'invoice_number': invoiceNumber,
            'customer_name': customerName,
            'customer_phone': phone,
            'customer_address': address,
            'customer_company': company,
            'product_name': productName,
            'gender': gender,
            'size': size,
            'thickness': thickness,
            'weight': totalWeight > 0 ? totalWeight.toString() : '0',
            'weight_per_unit': weightPerUnit > 0 ? weightPerUnit.toString() : '0',
            'unit_count': unitCount > 0 ? unitCount.toString() : '0',
            'total_weight': totalWeight > 0 ? totalWeight.toString() : '0',
            'unit': unit.isNotEmpty ? unit : 'کیلوگرم',
            'unit_price': unitPrice,
            'total_price': totalPrice > 0 ? totalPrice : finalPrice,
            'price_rate': priceRate > 0 ? priceRate : 1,
            'currency': currencyFinal,
            'usd_equivalent': usdEquivalent,
            'afn_equivalent': afnEquivalent,
            'loading_cost': loadingCost,
            'transfer_cost': transferCost,
            'clearance_cost': clearanceCost,
            'discount': discount,
            'final_price': finalPrice > 0 ? finalPrice : totalPrice,
            'payment_method': paymentMethodFinal,
            'loan_type': paymentMethodFinal == 'loan_full' ? 'full' : paymentMethodFinal == 'loan_partial' ? 'partial' : 'cash',
            'paid_amount': paymentMethodFinal == 'cash' ? finalPrice : 0,
            'remaining_amount': paymentMethodFinal == 'cash' ? 0 : finalPrice,
            'description': description,
            'sale_type': saleType.isNotEmpty ? saleType : 'فروش',
            'date': date,
            'date_en': dateEn,
            'produced_product_id': null,
            'driver_name': '',
            'number_plate': '',
          };

          int result = await _db.insertSalesInvoice(sale);
          if (result != -1) {
            successCount++;
            importedData.add(sale);
          } else {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': خطا در ذخیره‌سازی');
          }
        } catch (e) {
          skippedCount++;
          errors.add('ردیف ' + (i+1).toString() + ': خطا - ' + e.toString());
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
                            .map((error) => Text(error, style: const TextStyle(fontSize: 11, color: Colors.red)))
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
      
      // Group invoices by invoice_number
      final Map<String, List<Map<String, dynamic>>> groupedSales = {};
      for (var sale in sales) {
        final invoiceNumber = sale['invoice_number']?.toString() ?? 'unknown';
        if (!groupedSales.containsKey(invoiceNumber)) {
          groupedSales[invoiceNumber] = [];
        }
        groupedSales[invoiceNumber]!.add(sale);
      }
      
      // Convert grouped to a list of consolidated invoices
      final List<Map<String, dynamic>> consolidatedSales = [];
      for (var entry in groupedSales.entries) {
        final items = entry.value;
        final firstItem = items.first;
        
        final consolidated = Map<String, dynamic>.from(firstItem);
        consolidated['items'] = items;
        
        double totalWeight = 0;
        double totalPrice = 0;
        double totalFinalPrice = 0;
        String unit = 'کیلوگرم';
        
        for (var item in items) {
          final weight = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
          final price = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
          final fPrice = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0;
          totalWeight += weight;
          totalPrice += price;
          totalFinalPrice += fPrice;
          if (item['unit'] != null) unit = item['unit'].toString();
        }
        
        consolidated['total_weight'] = totalWeight.toString();
        consolidated['total_price'] = totalPrice;
        consolidated['final_price'] = totalFinalPrice;
        consolidated['unit'] = unit;
        consolidated['product_count'] = items.length;
        
        final productNames = items.map((item) => item['product_name']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
        consolidated['product_names'] = productNames;
        consolidated['display_products'] = productNames.join('، ');
        
        consolidatedSales.add(consolidated);
      }
      
      consolidatedSales.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
      
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _companies = companies;
        _sales = consolidatedSales;
        _partyOptions = options;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar(l10n.errorLoadingSales, Colors.red);
    }
  }

  // ============================================
  // ADD SALE DIALOG WITH MULTI-PRODUCT SUPPORT
  // ============================================
Future<void> _showAddSaleDialog() async {
  final l10n = AppLocalizations.of(context)!;
  
  _invoiceItems = [];
  _nextItemIndex = 1;
  
  final customerNameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final companyController = TextEditingController();
  final timeController = TextEditingController(text: _formatTimeOfDay(TimeOfDay.now()));
  final exchangeRateController = TextEditingController(text: '1');
  final descriptionController = TextEditingController();
  final dateController = TextEditingController(text: PersianDateConverter.getCurrentPersianDate());
  final invoiceNumberController = TextEditingController();
  final driverNameController = TextEditingController();
  final numberPlateController = TextEditingController();
  
  final barchalaniController = TextEditingController();
  final ghurfedariController = TextEditingController();
  final commissionController = TextEditingController();
  final transferCostController = TextEditingController();
  final miscellaneousController = TextEditingController();
  final discountController = TextEditingController();
  
  String selectedPaymentMethod = 'cash';
  String selectedCurrency = 'USD';
  String selectedType = 'فروش';
  Map<String, dynamic>? selectedParty;
  String selectedEnglishDate = PersianDateConverter.getEnglishDate(DateTime.now());
  String selectedEnglishTime = _formatTimeOfDay(TimeOfDay.now());

  final List<Map<String, dynamic>> producedProducts = await _db.getProducedProducts();
  final List<Map<String, dynamic>> productOptions = producedProducts.map((product) {
    return {
      'id': product['id'],
      'name': product['production_type']?.toString() ?? '-',
      'unit': product['unit']?.toString() ?? 'کیلوگرم',
      'thickness': product['thickness']?.toString() ?? '',
      'size': product['size']?.toString() ?? '',
      'length': product['length']?.toString() ?? '',
      'raw_weight': double.tryParse(product['raw_weight']?.toString() ?? '0') ?? 0,
      'raw_count': int.tryParse(product['raw_count']?.toString() ?? '0') ?? 0,
      'total_weight': double.tryParse(product['total_weight']?.toString() ?? '0') ?? 0,
    };
  }).toList();

  _invoiceItems.add({
    'id': _nextItemIndex++,
    'product_id': null,
    'product_name': '',
    'size': '',
    'thickness': '',
    'weight_per_unit': 0.0,
    'unit_count': 0.0,
    'total_weight': 0.0,
    'unit': 'کیلوگرم',
    'unit_price': 0.0,
    'total_price': 0.0,
    'gender': '',
    'weightCtrl': TextEditingController(),
    'countCtrl': TextEditingController(),
    'priceCtrl': TextEditingController(),
  });

  double getTotalWeight() {
    double total = 0;
    for (var item in _invoiceItems) {
      total += item['total_weight'] ?? 0;
    }
    return total;
  }

  double getTotalPrice() {
    double total = 0;
    for (var item in _invoiceItems) {
      total += item['total_price'] ?? 0;
    }
    return total;
  }

  void updateItemTotals(Map<String, dynamic> item) {
    double weightPerUnit = item['weight_per_unit'] ?? 0;
    double unitCount = item['unit_count'] ?? 0;
    double unitPrice = item['unit_price'] ?? 0;
    
    double totalWeight = weightPerUnit * unitCount;
    double totalWeightInTons = totalWeight / 1000;
    double totalPrice = totalWeightInTons * unitPrice;
    
    item['total_weight'] = totalWeight;
    item['total_price'] = totalPrice;
  }

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        double totalWeight = getTotalWeight();
        double totalPrice = getTotalPrice();
        double exchangeRate = double.tryParse(exchangeRateController.text) ?? 1;
        
        double barchalani = double.tryParse(barchalaniController.text) ?? 0;
        double ghurfedari = double.tryParse(ghurfedariController.text) ?? 0;
        double commission = double.tryParse(commissionController.text) ?? 0;
        double transferCost = double.tryParse(transferCostController.text) ?? 0;
        double miscellaneous = double.tryParse(miscellaneousController.text) ?? 0;
        double discount = double.tryParse(discountController.text) ?? 0;
        
        double barchalaniUSD = exchangeRate > 0 ? barchalani / exchangeRate : 0;
        double ghurfedariUSD = exchangeRate > 0 ? ghurfedari / exchangeRate : 0;
        double commissionUSD = exchangeRate > 0 ? commission / exchangeRate : 0;
        double transferCostUSD = exchangeRate > 0 ? transferCost / exchangeRate : 0;
        double miscellaneousUSD = exchangeRate > 0 ? miscellaneous / exchangeRate : 0;
        double discountUSD = exchangeRate > 0 ? discount / exchangeRate : 0;
        
        double finalPrice = totalPrice + barchalaniUSD + ghurfedariUSD + commissionUSD + transferCostUSD + miscellaneousUSD - discountUSD;
        
        double usdEquivalent = selectedCurrency == 'USD' ? finalPrice : (exchangeRate > 0 ? finalPrice / exchangeRate : 0);
        double afnEquivalent = selectedCurrency == 'AFN' ? finalPrice : (finalPrice * exchangeRate);

        String invoiceNumber = invoiceNumberController.text.trim();

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.add_circle_outline, color: Color(0xFFCB001D)),
                const SizedBox(width: 12),
                Text(l10n.addNewSale, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1A1A1A))),
              ],
            ),
            content: SizedBox(
              width: 900,
              height: MediaQuery.of(context).size.height * 0.85,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSectionTitle('اطلاعات فاکتور', l10n),
                    const SizedBox(height: 8),
                    
                    _buildTextField(
                      controller: invoiceNumberController,
                      label: l10n.invoiceNumberLabel,
                      icon: Icons.numbers,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedParty,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.selectCustomerCompany,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.history_rounded, color: Color(0xFFCB001D)),
                          tooltip: l10n.viewCustomerHistory,
                          onPressed: selectedParty == null
                              ? null
                              : () => _showPartyTransactionHistory(selectedParty),
                        ),
                      ),
                      items: _partyOptions.map((option) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: option,
                          child: Text('${option['name']} (${option['source'] == 'company' ? l10n.company : l10n.customer})'),
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
                        Expanded(
                          child: _buildTextField(
                            controller: customerNameController,
                            label: l10n.customerName,
                            icon: Icons.person_outline,
                            l10n: l10n,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: companyController,
                            label: l10n.companyName,
                            icon: Icons.business_outlined,
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: phoneController,
                            label: l10n.phoneNumber,
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            l10n: l10n,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: addressController,
                            label: l10n.address,
                            icon: Icons.location_on_outlined,
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _buildSectionTitle('محصولات', l10n),
                    const SizedBox(height: 8),
                    
                    ..._invoiceItems.asMap().entries.map((entry) {
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
                                  'محصول ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFFCB001D),
                                  ),
                                ),
                                if (_invoiceItems.length > 1)
                                  IconButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        _invoiceItems.removeAt(index);
                                      });
                                    },
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    padding: EdgeInsets.zero,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // ============================================
                            // FIXED: Use int (ID) instead of String (Name) to prevent duplicate crash
                            // ============================================
                            // ============================================
// FIXED: Use Row instead of Column for horizontal display
// ============================================
DropdownButtonFormField<int>(
  value: item['product_id'] as int?,
  isExpanded: true,
  menuMaxHeight: 250, // Increased slightly to fit the row
  decoration: const InputDecoration(
    labelText: 'انتخاب نوع تولید',
    border: OutlineInputBorder(),
    prefixIcon: Icon(Icons.inventory_2_outlined, color: Color(0xFFCB001D)),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    isDense: true,
  ),
  items: [
    const DropdownMenuItem<int>(
      value: null,
      child: Text('انتخاب نوع تولید', style: TextStyle(color: Colors.grey)),
    ),
    ...productOptions.map((product) {
      final id = product['id'] as int;
      final name = product['name']?.toString() ?? '-';
      final size = product['size']?.toString() ?? '';
      final thickness = product['thickness']?.toString() ?? '';
      
      return DropdownMenuItem<int>(
        value: id,
        child: Row(
          children: [
            // 1. Product Name
            Expanded(
              flex: 3,
              child: Text(
                name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 2. Size (if available)
            if (size.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text('سایز: $size', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            // 3. Thickness (if available)
            if (thickness.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text('ضخامت: $thickness', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ],
        ),
      );
    }).toList(),
  ],
  onChanged: (value) {
    if (value == null) {
      setDialogState(() {
        item['product_id'] = null;
        item['product_name'] = '';
        item['unit'] = 'کیلوگرم';
        item['thickness'] = '';
        item['size'] = '';
        item['weight_per_unit'] = 0;
        item['unit_count'] = 0;
        item['total_weight'] = 0;
        item['total_price'] = 0;
        item['weightCtrl']?.clear();
        item['countCtrl']?.clear();
      });
      return;
    }
    final selected = productOptions.firstWhere(
      (p) => p['id'] == value,
      orElse: () => {},
    );
    if (selected.isEmpty) return;
    setDialogState(() {
      item['product_id'] = value;
      item['product_name'] = selected['name']?.toString() ?? '';
      item['unit'] = selected['unit']?.toString() ?? 'کیلوگرم';
      item['thickness'] = selected['thickness']?.toString() ?? '';
      item['size'] = selected['size']?.toString() ?? '';
      item['weight_per_unit'] = selected['raw_weight'] ?? 0;
      item['unit_count'] = (selected['raw_count'] ?? 0).toDouble();
      // Fill the controllers with product data
      item['weightCtrl']?.text = (selected['raw_weight'] ?? 0) > 0 
          ? (selected['raw_weight']).toString() 
          : '';
      item['countCtrl']?.text = (selected['raw_count'] ?? 0) > 0 
          ? (selected['raw_count']).toString() 
          : '';
      updateItemTotals(item);
    });
  },
),
                            // ============================================
                            
                            const SizedBox(height: 8),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSmallTextField(
                                    controller: TextEditingController(text: item['size']?.toString() ?? ''),
                                    label: 'سایز',
                                    icon: Icons.straighten,
                                    readOnly: true,
                                    l10n: l10n,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSmallTextField(
                                    controller: TextEditingController(text: item['thickness']?.toString() ?? ''),
                                    label: 'ضخامت (mm)',
                                    icon: Icons.height,
                                    readOnly: true,
                                    l10n: l10n,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSmallTextFieldWithCallback(
                                    controller: item['weightCtrl'] as TextEditingController,
                                    label: 'وزن فی خاده (kg)',
                                    icon: Icons.scale_outlined,
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      item['weight_per_unit'] = double.tryParse(value) ?? 0;
                                      updateItemTotals(item);
                                      setDialogState(() {});
                                    },
                                    l10n: l10n,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSmallTextFieldWithCallback(
                                    controller: item['countCtrl'] as TextEditingController,
                                    label: 'تعداد خاده',
                                    icon: Icons.numbers,
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      item['unit_count'] = double.tryParse(value) ?? 0;
                                      updateItemTotals(item);
                                      setDialogState(() {});
                                    },
                                    l10n: l10n,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSmallTextField(
                                    controller: TextEditingController(
                                      text: item['total_weight'] != null && item['total_weight'] > 0 
                                          ? (item['total_weight'] / 1000).toStringAsFixed(2) 
                                          : ''
                                    ),
                                    label: 'مجموع وزن (تن)',
                                    icon: Icons.monitor_weight_outlined,
                                    readOnly: true,
                                    l10n: l10n,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSmallTextFieldWithCallback(
                                    controller: item['priceCtrl'] as TextEditingController,
                                    label: 'قیمت هر تن (USD)',
                                    icon: Icons.attach_money_outlined,
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      item['unit_price'] = double.tryParse(value) ?? 0;
                                      updateItemTotals(item);
                                      setDialogState(() {});
                                    },
                                    l10n: l10n,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSmallTextField(
                                    controller: TextEditingController(
                                      text: item['total_price'] != null && item['total_price'] > 0 
                                          ? item['total_price'].toStringAsFixed(0) 
                                          : ''
                                    ),
                                    label: 'قیمت کل (USD)',
                                    icon: Icons.receipt_long_outlined,
                                    readOnly: true,
                                    l10n: l10n,
                                  ),
                                ),
                              ],
                            ),
                            if (item['weight_per_unit'] != null && item['weight_per_unit'] > 0 && item['unit_count'] != null && item['unit_count'] > 0)
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
                                    '${item['weight_per_unit']} kg × ${item['unit_count']} = ${(item['weight_per_unit'] * item['unit_count']).toStringAsFixed(0)} kg = ${((item['weight_per_unit'] * item['unit_count']) / 1000).toStringAsFixed(2)} تن',
                                    style: const TextStyle(fontSize: 10, color: Colors.blue),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    ElevatedButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          _invoiceItems.add({
                            'id': _nextItemIndex++,
                            'product_id': null,
                            'product_name': '',
                            'size': '',
                            'thickness': '',
                            'weight_per_unit': 0.0,
                            'unit_count': 0.0,
                            'total_weight': 0.0,
                            'unit': 'کیلوگرم',
                            'unit_price': 0.0,
                            'total_price': 0.0,
                            'gender': '',
                            'weightCtrl': TextEditingController(),
                            'countCtrl': TextEditingController(),
                            'priceCtrl': TextEditingController(),
                          });
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('افزودن محصول'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: const Color(0xFFCB001D),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildSectionTitle('هزینه‌ها', l10n),
const SizedBox(height: 8),

Row(
  children: [
    Expanded(
      child: _buildTextField(
        controller: barchalaniController,
        label: 'هزینه بارگیری',
        icon: Icons.local_shipping_outlined,
        keyboardType: TextInputType.number,
        onChanged: (_) => setDialogState(() {}),
        l10n: l10n,
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _buildTextField(
        controller: transferCostController,
        label: 'هزینه حمل',
        icon: Icons.drive_eta_outlined,
        keyboardType: TextInputType.number,
        onChanged: (_) => setDialogState(() {}),
        l10n: l10n,
      ),
    ),
  ],
),
const SizedBox(height: 12),
Row(
  children: [
    Expanded(
      child: _buildTextField(
        controller: ghurfedariController,
        label: 'هزینه ترخیص',
        icon: Icons.storefront_outlined,
        keyboardType: TextInputType.number,
        onChanged: (_) => setDialogState(() {}),
        l10n: l10n,
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _buildTextField(
        controller: discountController,
        label: 'تخفیف',
        icon: Icons.discount_outlined,
        keyboardType: TextInputType.number,
        onChanged: (_) => setDialogState(() {}),
        l10n: l10n,
      ),
    ),
  ],
),
                    
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
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildFinancialSummaryItem(
                              'مجموع وزن',
                              '${(totalWeight / 1000).toStringAsFixed((totalWeight / 1000) % 1 == 0 ? 0 : 2)} تن',
                              const Color(0xFFCB001D),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFinancialSummaryItem(
                              'قیمت کل',
                              '\$${totalPrice.toStringAsFixed(0)}',
                              const Color(0xFFCB001D),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFinancialSummaryItem(
                              'تعداد اقلام',
                              _invoiceItems.length.toString(),
                              Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFinancialSummaryItem(
                              'قیمت نهایی',
                              '\$${finalPrice.toStringAsFixed(2)}',
                              const Color(0xFFCB001D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildTextField(
                      controller: exchangeRateController,
                      label: 'نرخ ارز (USD به AFN) *',
                      icon: Icons.currency_exchange,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: TextEditingController(
                              text: selectedCurrency == 'USD' 
                                  ? afnEquivalent.toStringAsFixed(0)
                                  : usdEquivalent.toStringAsFixed(2)
                            ),
                            label: selectedCurrency == 'USD' 
                                ? 'معادل به افغانی (AFN)' 
                                : 'معادل به دالر (USD)',
                            icon: Icons.currency_exchange,
                            readOnly: true,
                            l10n: l10n,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCurrency,
                            decoration: const InputDecoration(labelText: 'ارز نهایی', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'USD', child: Text('USD')),
                              DropdownMenuItem(value: 'AFN', child: Text('AFN')),
                            ],
                            onChanged: (value) => setDialogState(() {
                              selectedCurrency = value ?? 'USD';
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: const InputDecoration(labelText: 'نوع تراکنش', border: OutlineInputBorder()),
                            items: [
                              DropdownMenuItem(value: 'فروش', child: Text('فروش')),
                              DropdownMenuItem(value: 'پیش‌فاکتور', child: Text('پیش‌فاکتور')),
                            ],
                            onChanged: (value) => setDialogState(() => selectedType = value ?? 'فروش'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedPaymentMethod,
                            decoration: const InputDecoration(labelText: 'روش پرداخت', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'cash', child: Text('نقد')),
                              DropdownMenuItem(value: 'loan_full', child: Text('قرض کامل')),
                              DropdownMenuItem(value: 'loan_partial', child: Text('قرض جزئی')),
                            ],
                            onChanged: (value) => setDialogState(() => selectedPaymentMethod = value ?? 'cash'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: dateController,
                            label: l10n.persianDate,
                            icon: Icons.date_range_outlined,
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
                            l10n: l10n,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: timeController,
                            label: l10n.loadingTime,
                            icon: Icons.access_time_outlined,
                            readOnly: true,
                            onTap: () async {
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
                            },
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    _buildTextField(
                      controller: descriptionController,
                      label: l10n.description,
                      icon: Icons.notes_outlined,
                      maxLines: 2,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: driverNameController,
                            label: 'نام دریور',
                            icon: Icons.person_outline,
                            l10n: l10n,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: numberPlateController,
                            label: 'شماره پلیت',
                            icon: Icons.local_shipping_outlined,
                            l10n: l10n,
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
                child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
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

                  bool hasValidItem = false;
                  for (var item in _invoiceItems) {
                    if (item['product_name'] != null &&
                        item['product_name']!.toString().isNotEmpty &&
                        (item['total_weight'] ?? 0) > 0) {
                      hasValidItem = true;
                      break;
                    }
                  }
                  if (!hasValidItem) {
                    _showSnackbar('حداقل یک محصول معتبر باید انتخاب شود', Colors.red);
                    return;
                  }

                  double finalTotalWeight = getTotalWeight();
                  double finalTotalPrice = getTotalPrice();
                  double exchangeRate = double.tryParse(exchangeRateController.text) ?? 1;

                  double barchalani = double.tryParse(barchalaniController.text) ?? 0;
                  double ghurfedari = double.tryParse(ghurfedariController.text) ?? 0;
                  double commission = double.tryParse(commissionController.text) ?? 0;
                  double transferCost = double.tryParse(transferCostController.text) ?? 0;
                  double miscellaneous = double.tryParse(miscellaneousController.text) ?? 0;
                  double discount = double.tryParse(discountController.text) ?? 0;

                  double barchalaniUSD = exchangeRate > 0 ? barchalani / exchangeRate : 0;
                  double ghurfedariUSD = exchangeRate > 0 ? ghurfedari / exchangeRate : 0;
                  double commissionUSD = exchangeRate > 0 ? commission / exchangeRate : 0;
                  double transferCostUSD = exchangeRate > 0 ? transferCost / exchangeRate : 0;
                  double miscellaneousUSD = exchangeRate > 0 ? miscellaneous / exchangeRate : 0;
                  double discountUSD = exchangeRate > 0 ? discount / exchangeRate : 0;

                  double finalPrice = finalTotalPrice + barchalaniUSD + ghurfedariUSD + commissionUSD + transferCostUSD + miscellaneousUSD - discountUSD;

                  double usdEquiv = selectedCurrency == 'USD' ? finalPrice : (exchangeRate > 0 ? finalPrice / exchangeRate : 0);
                  double afnEquiv = selectedCurrency == 'AFN' ? finalPrice : (finalPrice * exchangeRate);

                  List<int> insertedIds = [];

                  for (var item in _invoiceItems) {
                    if (item['product_name'] != null &&
                        item['product_name']!.toString().isNotEmpty) {

                      final payload = {
                        'invoice_number': invoiceNumber,
                        'customer_name': customerName,
                        'customer_phone': phoneController.text.trim(),
                        'customer_address': addressController.text.trim(),
                        'customer_company': companyController.text.trim(),
                        'product_name': item['product_name'],
                        'gender': item['gender'] ?? '',
                        'size': item['size'] ?? '',
                        'thickness': item['thickness'] ?? '',
                        'weight': item['total_weight']?.toString() ?? '0',
                        'weight_per_unit': item['weight_per_unit']?.toString() ?? '0',
                        'unit_count': item['unit_count']?.toString() ?? '0',
                        'total_weight': item['total_weight']?.toString() ?? '0',
                        'unit': item['unit'] ?? 'کیلوگرم',
                        'unit_price': item['unit_price'] ?? 0,
                        'total_price': item['total_price'] ?? 0,
                        'price_rate': exchangeRate,
                        'currency': selectedCurrency,
                        'usd_equivalent': usdEquiv,
                        'afn_equivalent': afnEquiv,
                        'loading_cost': barchalani + transferCost + commission,
                        'transfer_cost': 0,
                        'clearance_cost': ghurfedari,
                        'discount': discount,
                        'loading_time': timeController.text.trim(),
                        'loading_time_en': selectedEnglishTime,
                        'final_price': finalPrice,
                        'payment_method': selectedPaymentMethod,
                        'loan_type': selectedPaymentMethod == 'loan_full' ? 'full' : selectedPaymentMethod == 'loan_partial' ? 'partial' : 'cash',
                        'paid_amount': selectedPaymentMethod == 'cash' ? finalPrice : 0,
                        'remaining_amount': selectedPaymentMethod == 'cash' ? 0 : finalPrice,
                        'description': descriptionController.text.trim(),
                        'sale_type': selectedType,
                        'date': dateController.text.trim(),
                        'date_en': selectedEnglishDate,
                        'produced_product_id': item['product_id'],
                        'driver_name': driverNameController.text.trim(),
                        'number_plate': numberPlateController.text.trim(),
                      };

                      final id = await _db.insertSalesInvoice(payload);
                      if (id != -1) {
                        insertedIds.add(id);
                      }
                    }
                  }

                if (insertedIds.isEmpty) {
  _showSnackbar('❌ خطا در ذخیره فروش', Colors.red);
  return;
}

Navigator.pop(context);
await _loadData();

// Get all items for this invoice
final allInvoices = await _db.getSalesInvoices();
List<Map<String, dynamic>> allItems = [];
Map<String, dynamic>? baseInvoice;

// Find all items with this invoice number
for (var inv in allInvoices) {
  if (inv['invoice_number'] == invoiceNumber) {
    allItems.add(inv);
    if (baseInvoice == null) {
      baseInvoice = Map<String, dynamic>.from(inv);
    }
  }
}

if (baseInvoice != null && allItems.isNotEmpty) {
  // Add items to the base invoice
  baseInvoice['items'] = allItems;
  
  // Calculate totals
  double totalWeight = 0;
  double totalPrice = 0;
  double totalFinalPrice = 0;
  String unit = 'کیلوگرم';
  List<String> productNames = [];
  
  for (var item in allItems) {
    final weight = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
    final price = double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
    final fPrice = double.tryParse(item['final_price']?.toString() ?? '0') ?? 0;
    totalWeight += weight;
    totalPrice += price;
    totalFinalPrice += fPrice;
    if (item['unit'] != null && item['unit'].toString().isNotEmpty) {
      unit = item['unit'].toString();
    }
    final name = item['product_name']?.toString() ?? '';
    if (name.isNotEmpty) productNames.add(name);
  }
  
  baseInvoice['total_weight'] = totalWeight.toString();
  baseInvoice['total_price'] = totalPrice;
  baseInvoice['final_price'] = totalFinalPrice;
  baseInvoice['unit'] = unit;
  baseInvoice['product_count'] = allItems.length;
  baseInvoice['product_names'] = productNames;
  baseInvoice['display_products'] = productNames.join('، ');
  
  // Show the invoice modal
  _showInvoiceModal(context, invoiceNumber, baseInvoice, l10n);
} else {
  // Fallback - try to find the sale in _sales list
  final sale = _sales.firstWhere(
    (s) => s['invoice_number'] == invoiceNumber,
    orElse: () => {},
  );
  if (sale.isNotEmpty) {
    _showInvoiceModal(context, invoiceNumber, sale, l10n);
  }
}

_showSnackbar('✅ ${insertedIds.length} محصول با موفقیت ثبت شد', Colors.green);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCB001D),
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.saveSale),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  // ============================================
  // HELPER WIDGETS
  // ============================================
  
  Widget _buildSmallTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppLocalizations l10n,
    TextInputType? keyboardType,
    bool readOnly = false,
    void Function(String)? onChanged,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onChanged: onChanged,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
        prefixIcon: Icon(icon, color: const Color(0xFFCB001D), size: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildSmallTextFieldWithCallback({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppLocalizations l10n,
    TextInputType? keyboardType,
    required void Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
        prefixIcon: Icon(icon, color: const Color(0xFFCB001D), size: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 12),
      onChanged: onChanged,
    );
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

  // ============================================
  // EDIT SALE DIALOG
  // ============================================
  Future<void> _showEditSaleDialog(Map<String, dynamic> sale) async {
    final l10n = AppLocalizations.of(context)!;
    
    final customerNameController = TextEditingController(text: sale['customer_name']?.toString() ?? '');
    final phoneController = TextEditingController(text: sale['customer_phone']?.toString() ?? '');
    final addressController = TextEditingController(text: sale['customer_address']?.toString() ?? '');
    final companyController = TextEditingController(text: sale['customer_company']?.toString() ?? '');
    final productController = TextEditingController(text: sale['product_name']?.toString() ?? '');
    final genderController = TextEditingController(text: sale['gender']?.toString() ?? '');
    final sizeController = TextEditingController(text: sale['size']?.toString() ?? '');
    final thicknessController = TextEditingController(text: sale['thickness']?.toString() ?? '');
    final weightPerUnitController = TextEditingController(text: sale['weight_per_unit']?.toString() ?? '');
    final unitCountController = TextEditingController(text: sale['unit_count']?.toString() ?? '');
    final totalWeightController = TextEditingController(text: sale['total_weight']?.toString() ?? '');
    final timeController = TextEditingController(text: sale['loading_time']?.toString() ?? _formatTimeOfDay(TimeOfDay.now()));
    final unitController = TextEditingController(text: sale['unit']?.toString() ?? 'کیلو');
    final unitPriceController = TextEditingController(text: sale['unit_price']?.toString() ?? '');
    final totalPriceController = TextEditingController(text: sale['total_price']?.toString() ?? '');
    final finalPriceController = TextEditingController(text: sale['final_price']?.toString() ?? '');
    final exchangeRateController = TextEditingController(text: sale['price_rate']?.toString() ?? '1');
    final loadingController = TextEditingController(text: sale['loading_cost']?.toString() ?? '');
    final transferController = TextEditingController(text: sale['transfer_cost']?.toString() ?? '');
    final clearanceController = TextEditingController(text: sale['clearance_cost']?.toString() ?? '');
    final discountController = TextEditingController(text: sale['discount']?.toString() ?? '');
    final descriptionController = TextEditingController(text: sale['description']?.toString() ?? '');
    final equivalentController = TextEditingController();
    final dateController = TextEditingController(text: sale['date']?.toString() ?? PersianDateConverter.getCurrentPersianDate());
    final paidAmountController = TextEditingController(text: sale['paid_amount']?.toString() ?? '');
    final invoiceNumberController = TextEditingController(text: sale['invoice_number']?.toString() ?? '');
    final driverNameController = TextEditingController(text: sale['driver_name']?.toString() ?? '');
    final numberPlateController = TextEditingController(text: sale['number_plate']?.toString() ?? '');
    
    String selectedPaymentMethod = sale['payment_method']?.toString() ?? 'cash';
    String selectedCurrency = sale['currency']?.toString() ?? 'USD';
    String selectedType = sale['sale_type']?.toString() ?? 'فروش';
    Map<String, dynamic>? selectedParty;
    String selectedEnglishDate = sale['date_en']?.toString() ?? PersianDateConverter.getEnglishDate(DateTime.now());
    String selectedEnglishTime = sale['loading_time_en']?.toString() ?? _formatTimeOfDay(TimeOfDay.now());

    final List<Map<String, dynamic>> producedProducts = await _db.getProducedProducts();
    final List<Map<String, dynamic>> productOptions = producedProducts.map((product) {
      return {
        'id': product['id'],
        'name': product['production_type']?.toString() ?? '-',
        'unit': product['unit']?.toString() ?? 'کیلوگرم',
        'thickness': product['thickness']?.toString() ?? '',
        'size': product['size']?.toString() ?? '',
        'length': product['length']?.toString() ?? '',
        'raw_weight': double.tryParse(product['raw_weight']?.toString() ?? '0') ?? 0,
        'raw_count': int.tryParse(product['raw_count']?.toString() ?? '0') ?? 0,
        'total_weight': double.tryParse(product['total_weight']?.toString() ?? '0') ?? 0,
      };
    }).toList();

    int? selectedProductId = sale['produced_product_id'] as int?;
    String? selectedProductName = sale['product_name']?.toString();
    String? selectedProductUnit = sale['unit']?.toString();
    String? selectedProductThickness = sale['thickness']?.toString();
    String? selectedProductSize = sale['size']?.toString();

    if (sale['customer_name'] != null) {
      selectedParty = _partyOptions.firstWhere(
        (p) => p['name']?.toString() == sale['customer_name']?.toString(),
        orElse: () => {
          'id': null,
          'name': sale['customer_name']?.toString() ?? '',
          'phone': sale['customer_phone']?.toString() ?? '',
          'address': sale['customer_address']?.toString() ?? '',
          'company': sale['customer_company']?.toString() ?? '',
          'source': 'customer',
        },
      );
    }

    void updateTotals() {
      double weightPerUnit = double.tryParse(weightPerUnitController.text) ?? 0;
      String currentUnit = unitController.text;
      double weightPerUnitInTons = weightPerUnit;
      bool isKg = currentUnit == 'کیلوگرم' || currentUnit == 'kg' || currentUnit == 'Kg';
      if (isKg) {
        weightPerUnitInTons = weightPerUnit / 1000;
      }
      double unitCount = double.tryParse(unitCountController.text) ?? 0;
      double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      double exchangeRate = double.tryParse(exchangeRateController.text) ?? 1;
      
      double loadingCost = double.tryParse(loadingController.text) ?? 0;
      double transferCost = double.tryParse(transferController.text) ?? 0;
      double clearanceCost = double.tryParse(clearanceController.text) ?? 0;
      double discount = double.tryParse(discountController.text) ?? 0;
      
      double loadingCostUSD = exchangeRate > 0 ? loadingCost / exchangeRate : 0;
      double transferCostUSD = exchangeRate > 0 ? transferCost / exchangeRate : 0;
      double clearanceCostUSD = exchangeRate > 0 ? clearanceCost / exchangeRate : 0;
      double discountUSD = exchangeRate > 0 ? discount / exchangeRate : 0;
      
      double totalWeight = weightPerUnit * unitCount;
      double totalWeightInTons = weightPerUnitInTons * unitCount;
      double totalPrice = totalWeightInTons * unitPrice;

      totalWeightController.text = totalWeight > 0 ? totalWeight.toStringAsFixed(2) : '';
      totalPriceController.text = totalPrice > 0 ? totalPrice.toStringAsFixed(0) : '';

      double finalPrice = totalPrice + loadingCostUSD + transferCostUSD + clearanceCostUSD - discountUSD;
      finalPriceController.text = finalPrice > 0 ? finalPrice.toStringAsFixed(2) : '';

      if (selectedCurrency == 'USD') {
        equivalentController.text = totalPrice > 0 
            ? (totalPrice * (exchangeRate <= 0 ? 1 : exchangeRate)).toStringAsFixed(0) 
            : '';
      } else {
        equivalentController.text = totalPrice > 0 
            ? (totalPrice / (exchangeRate <= 0 ? 1 : exchangeRate)).toStringAsFixed(2) 
            : '';
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double weightPerUnit = double.tryParse(weightPerUnitController.text) ?? 0;
          double unitCount = double.tryParse(unitCountController.text) ?? 0;
          String currentUnit = unitController.text;
          bool isKg = currentUnit == 'کیلوگرم' || currentUnit == 'kg' || currentUnit == 'Kg';
          double weightPerUnitInTons = isKg ? weightPerUnit / 1000 : weightPerUnit;
          double totalWeight = weightPerUnit * unitCount;
          double totalWeightInTons = isKg ? totalWeight / 1000 : totalWeight;
          double unitPrice = double.tryParse(unitPriceController.text) ?? 0;
          String pricePerTonHint = '';
          if (currentUnit.isNotEmpty && weightPerUnit > 0 && unitPrice > 0) {
            double weightPerUnitInTonsCalc = isKg ? weightPerUnit / 1000 : weightPerUnit;
            if (weightPerUnitInTonsCalc > 0) {
              pricePerTonHint = 'قیمت هر تن: ${unitPrice.toStringAsFixed(0)}';
            }
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('${l10n.edit} ${l10n.sale}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1A1A1A))),
              content: SizedBox(
                width: 700,
                height: MediaQuery.of(context).size.height * 0.7,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSectionTitle('ویرایش فروش', l10n),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: invoiceNumberController,
                        label: l10n.invoiceNumberLabel,
                        icon: Icons.numbers,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedParty,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.selectCustomerCompany,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.history_rounded, color: Color(0xFFCB001D)),
                            tooltip: l10n.viewCustomerHistory,
                            onPressed: selectedParty == null
                                ? null
                                : () => _showPartyTransactionHistory(selectedParty),
                          ),
                        ),
                        items: _partyOptions.map((option) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: option,
                            child: Text('${option['name']} (${option['source'] == 'company' ? l10n.company : l10n.customer})'),
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
                          Expanded(
                            child: _buildTextField(
                              controller: customerNameController,
                              label: l10n.customerName,
                              icon: Icons.person_outline,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: companyController,
                              label: l10n.companyName,
                              icon: Icons.business_outlined,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: phoneController,
                              label: l10n.phoneNumber,
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: addressController,
                              label: l10n.address,
                              icon: Icons.location_on_outlined,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle(l10n.productDetails, l10n),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        
                        // ============================================
                        // FIXED: Use int (ID) instead of String (Name) to prevent duplicate crash
                        // ============================================
                        child: DropdownButtonFormField<int>(
                          value: selectedProductId,
                          isExpanded: true,
                          menuMaxHeight: 200,
                          decoration: InputDecoration(
                            labelText: 'انتخاب نوع تولید',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.inventory_2_outlined, color: Color(0xFFCB001D)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('انتخاب نوع تولید', style: TextStyle(color: Colors.grey)),
                            ),
                            ...productOptions.map((product) {
                              final id = product['id'] as int;
                              final name = product['name']?.toString() ?? '-';
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 2,
                                        children: [
                                          if (product['size'].toString().isNotEmpty) 
                                            Text('سایز: ${product['size']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          if (product['thickness'].toString().isNotEmpty) 
                                            Text('ضخامت: ${product['thickness']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          if (product['total_weight'] > 0) 
                                            Text('وزن: ${product['total_weight']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              setDialogState(() {
                                selectedProductId = null;
                                selectedProductName = null;
                                selectedProductUnit = null;
                                selectedProductThickness = null;
                                selectedProductSize = null;
                                productController.text = '';
                                weightPerUnitController.text = '';
                                unitCountController.text = '';
                                totalWeightController.text = '';
                                thicknessController.text = '';
                                sizeController.text = '';
                              });
                              return;
                            }
                            final selected = productOptions.firstWhere(
                              (p) => p['id'] == value,
                              orElse: () => {},
                            );
                            if (selected.isEmpty) return;
                            setDialogState(() {
                              selectedProductId = selected['id'] as int?;
                              selectedProductName = selected['name']?.toString();
                              selectedProductUnit = selected['unit']?.toString() ?? 'کیلوگرم';
                              selectedProductThickness = selected['thickness']?.toString() ?? '';
                              selectedProductSize = selected['size']?.toString() ?? '';
                              productController.text = selectedProductName ?? '';
                              thicknessController.text = selectedProductThickness ?? '';
                              sizeController.text = selectedProductSize ?? '';
                              unitController.text = selectedProductUnit ?? '';
                              double rawWeight = selected['raw_weight'] ?? 0;
                              int rawCount = selected['raw_count'] ?? 0;
                              double totalWeight = selected['total_weight'] ?? 0;
                              weightPerUnitController.text = rawWeight > 0 ? rawWeight.toString() : '';
                              unitCountController.text = rawCount > 0 ? rawCount.toString() : '';
                              totalWeightController.text = totalWeight > 0 ? totalWeight.toStringAsFixed(2) : '';
                              updateTotals();
                            });
                          },
                        )
                        // ============================================
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: productController,
                              label: 'نوع تولید',
                              icon: Icons.inventory_2_outlined,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: genderController,
                              label: l10n.gender,
                              icon: Icons.category_outlined,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: sizeController,
                              label: l10n.size,
                              icon: Icons.straighten,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: thicknessController,
                              label: l10n.thickness,
                              icon: Icons.height,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: weightPerUnitController,
                                  label: 'وزن فی خاده (کیلوگرم)',
                                  icon: Icons.scale_outlined,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setDialogState(() {
                                    updateTotals();
                                    setDialogState(() {});
                                  }),
                                  l10n: l10n,
                                ),
                                if (weightPerUnit > 0 && isKg)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCB001D).withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
                                            ),
                                            child: Text(
                                              '$weightPerUnit kg',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
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
                                              border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              '${weightPerUnitInTons.toStringAsFixed(weightPerUnitInTons % 1 == 0 ? 0 : 2)} تن',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFCB001D)),
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
                            child: _buildTextField(
                              controller: unitCountController,
                              label: 'تعداد خاده',
                              icon: Icons.numbers,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  controller: totalWeightController,
                                  label: 'مجموع وزن (تن)',
                                  icon: Icons.monitor_weight_outlined,
                                  keyboardType: TextInputType.number,
                                  readOnly: true,
                                  l10n: l10n,
                                ),
                                if (totalWeight > 0 && isKg)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCB001D).withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.1)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
                                            ),
                                            child: Text(
                                              '$totalWeight kg',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
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
                                              border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              '${totalWeightInTons.toStringAsFixed(totalWeightInTons % 1 == 0 ? 0 : 2)} تن',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFCB001D)),
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
                            child: _buildTextField(
                              controller: unitController,
                              label: l10n.unit,
                              icon: Icons.scale,
                              readOnly: true,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle(l10n.financialInfo, l10n),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: unitPriceController,
                              label: '${l10n.unitPricePerKg} (قیمت هر تن)',
                              icon: Icons.attach_money_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: unitController,
                              label: l10n.unit,
                              icon: Icons.widgets_outlined,
                              readOnly: true,
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      if (currentUnit.isNotEmpty && weightPerUnit > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 14),
                                const SizedBox(width: 6),
                                Text('قیمت بر اساس هر تن محاسبه می‌شود', style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                                if (pricePerTonHint.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCB001D).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
                                    ),
                                    child: Text(pricePerTonHint, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFCB001D))),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: totalPriceController,
                              label: l10n.totalPrice,
                              icon: Icons.receipt_long_outlined,
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: exchangeRateController,
                              label: selectedCurrency == 'USD' 
                                  ? 'نرخ ارز (USD به AFN) *' 
                                  : 'نرخ ارز (AFN به USD) *',
                              icon: Icons.currency_exchange,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: equivalentController,
                        label: selectedCurrency == 'USD' 
                            ? 'معادل به افغانی (AFN)' 
                            : 'معادل به دالر (USD)',
                        icon: Icons.currency_exchange,
                        readOnly: true,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: loadingController,
                              label: l10n.loadingCost,
                              icon: Icons.local_shipping_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: transferController,
                              label: l10n.transferCost,
                              icon: Icons.drive_eta_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
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
                              label: l10n.clearanceCost,
                              icon: Icons.fact_check_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: discountController,
                              label: l10n.discount,
                              icon: Icons.discount_outlined,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(updateTotals),
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: finalPriceController,
                              label: l10n.finalPrice,
                              icon: Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: dateController,
                              label: l10n.persianDate,
                              icon: Icons.date_range_outlined,
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
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: timeController,
                              label: l10n.loadingTime,
                              icon: Icons.access_time_outlined,
                              readOnly: true,
                              onTap: () async {
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
                              },
                              l10n: l10n,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCurrency,
                        decoration: InputDecoration(
                          labelText: l10n.finalCurrency,
                          border: const OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'AFN', child: Text('AFN')),
                        ],
                        onChanged: (value) => setDialogState(() {
                          selectedCurrency = value ?? 'USD';
                          updateTotals();
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: InputDecoration(
                          labelText: l10n.transactionType,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(value: 'فروش', child: Text('فروش')),
                          DropdownMenuItem(value: 'پیش‌فاکتور', child: Text('پیش‌فاکتور')),
                        ],
                        onChanged: (value) => setDialogState(() => selectedType = value ?? 'فروش'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethod,
                        decoration: InputDecoration(
                          labelText: l10n.paymentMethod,
                          border: const OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('نقد')),
                          DropdownMenuItem(value: 'loan_full', child: Text('قرض کامل')),
                          DropdownMenuItem(value: 'loan_partial', child: Text('قرض جزئی')),
                        ],
                        onChanged: (value) => setDialogState(() => selectedPaymentMethod = value ?? 'cash'),
                      ),
                      if (selectedPaymentMethod == 'loan_partial') const SizedBox(height: 12),
                      if (selectedPaymentMethod == 'loan_partial')
                        _buildTextField(
                          controller: paidAmountController,
                          label: l10n.initialPaymentAmount,
                          icon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          l10n: l10n,
                        ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: descriptionController,
                        label: l10n.description,
                        icon: Icons.notes_outlined,
                        maxLines: 2,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: driverNameController,
                        label: 'نام دریور',
                        icon: Icons.person_outline,
                        l10n: l10n,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: numberPlateController,
                        label: 'شماره پلیت',
                        icon: Icons.local_shipping_outlined,
                        l10n: l10n,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    final invoiceNumber = invoiceNumberController.text.trim();
                    final customerName = customerNameController.text.trim();
                    final phone = phoneController.text.trim();
                    final address = addressController.text.trim();
                    final company = companyController.text.trim();
                    final product = productController.text.trim();
                    
                    if (invoiceNumber.isEmpty) {
                      _showSnackbar('شماره فاکتور الزامی است', Colors.red);
                      return;
                    }
                    if (customerName.isEmpty || product.isEmpty) {
                      _showSnackbar(l10n.customerAndProductRequired, Colors.red);
                      return;
                    }
                    
                    final unitPrice = double.tryParse(unitPriceController.text) ?? 0;
                    final totalPrice = double.tryParse(totalPriceController.text) ?? 0;
                    final discount = double.tryParse(discountController.text) ?? 0;
                    final loadingCost = double.tryParse(loadingController.text) ?? 0;
                    final transferCost = double.tryParse(transferController.text) ?? 0;
                    final clearanceCost = double.tryParse(clearanceController.text) ?? 0;
                    final exchangeRate = double.tryParse(exchangeRateController.text) ?? 1;
                    final totalWeight = double.tryParse(totalWeightController.text) ?? 0;
                    final paidAmount = double.tryParse(paidAmountController.text) ?? 0;
                    final finalPrice = double.tryParse(finalPriceController.text) ?? 0;

                    final currencyType = selectedCurrency;
                    final usdEquivalent = currencyType == 'USD' ? finalPrice : (exchangeRate <= 0 ? finalPrice : finalPrice / exchangeRate);
                    final afnEquivalent = currencyType == 'AFN' ? finalPrice : (finalPrice * (exchangeRate <= 0 ? 1 : exchangeRate));
                    final remainingAmount = selectedPaymentMethod == 'cash'
                        ? 0
                        : (finalPrice - paidAmount) < 0
                            ? 0
                            : finalPrice - paidAmount;

                    final existingInvoice = await _db.getSalesInvoiceByNumber(invoiceNumber);
                    if (existingInvoice != null && existingInvoice['id'] != sale['id']) {
                      _showSnackbar('این شماره فاکتور قبلاً ثبت شده است', Colors.red);
                      return;
                    }
                    
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
                      'price_rate': exchangeRate,
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
                      'produced_product_id': selectedProductId,
                      'driver_name': driverNameController.text.trim(),
                      'number_plate': numberPlateController.text.trim(),
                    };
                    
                    final result = await _db.updateSalesInvoice(sale['id'], payload);
                    if (result == -1) {
                      _showSnackbar('❌ خطا در ویرایش فروش', Colors.red);
                      return;
                    }

                    Navigator.pop(context);
                    await _loadData();
                    _showSnackbar('✅ فروش با موفقیت ویرایش شد', Colors.green);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white),
                  child: Text(l10n.update),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // PARTY TRANSACTION HISTORY
  // ============================================
  void _showPartyTransactionHistory(Map<String, dynamic>? initialParty) {
    final l10n = AppLocalizations.of(context)!;
    Map<String, dynamic>? selectedParty = initialParty ?? (_partyOptions.isNotEmpty ? _partyOptions.first : null);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
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
                            Text(l10n.customerTransactionHistory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                            const SizedBox(height: 4),
                            Text(currentParty == null ? l10n.noCustomerSelected : currentParty['name']?.toString() ?? '-', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                          ],
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey, size: 24)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedParty,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.selectCustomerCompany, border: const OutlineInputBorder()),
                      items: _partyOptions.map((option) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: option,
                          child: Text('${option['name']?.toString() ?? '-'} (${option['source']?.toString() == 'company' ? l10n.company : l10n.customer})'),
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
                        _buildKeyValueChip(l10n.invoicesCount, totalInvoices.toString(), Colors.blue, l10n),
                        const SizedBox(width: 12),
                        _buildKeyValueChip(l10n.totalAmount, _formatCurrency(totalAmount), Colors.green, l10n),
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
                                  Text(l10n.noHistoryForCustomer, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
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
                                  subtitle: Text('${sale['display_products'] ?? sale['product_name'] ?? '-'} • ${sale['date'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: Text('${_formatCurrency(sale['final_price'])} ${sale['currency'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFCB001D))),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showInvoiceModal(context, sale['invoice_number'] ?? '-', sale, l10n);
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
        );
      },
    );
  }

  Widget _buildKeyValueChip(String label, String value, Color color, AppLocalizations l10n) {
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

  // ============================================
  // INVOICE MODAL - WITH MULTI-PRODUCT SUPPORT
  // ============================================
void _showInvoiceModal(BuildContext context, String invoiceNumber, Map<String, dynamic> invoice, AppLocalizations l10n) {
  final isWaybill = invoice['sale_type']?.toString() == 'بارنامه' || invoice['sale_type']?.toString() == 'پیش‌فاکتور';
  final isSale = invoice['sale_type']?.toString() == 'فروش';
  
  List<Map<String, dynamic>> items = [];
  if (invoice.containsKey('items') && invoice['items'] is List) {
    items = List<Map<String, dynamic>>.from(invoice['items']);
  } else {
    if (invoice['product_name'] != null && invoice['product_name']!.toString().isNotEmpty) {
      items.add({
        'product_name': invoice['product_name'],
        'size': invoice['size'] ?? '-',
        'thickness': invoice['thickness'] ?? '-',
        'weight_per_unit': double.tryParse(invoice['weight_per_unit']?.toString() ?? '0') ?? 0,
        'unit_count': double.tryParse(invoice['unit_count']?.toString() ?? '0') ?? 0,
        'total_weight': double.tryParse(invoice['total_weight']?.toString() ?? '0') ?? 0,
        'unit': invoice['unit']?.toString() ?? 'کیلوگرم',
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
                        Center(
                          child: Text(
                            isWaybill ? 'بارنامه' : 'بل ثبت فروش',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildInvoiceUpperSection(invoice, invoiceNumber, l10n),
                        const SizedBox(height: 25),
                        // Use the new table builder
                        _buildInvoiceTableWithItems(items, invoice, l10n),
                        const SizedBox(height: 20),
                        // Only show financial summary for Sale (not waybill)
                        if (isSale) _buildFinancialSummary(invoice, l10n),
                        if (isSale) const SizedBox(height: 20),
                        _buildInvoiceSignatureRow(),
                        const SizedBox(height: 25),
                        _buildInvoiceDriverSection(invoice),
                        const SizedBox(height: 15),
                        _buildInvoiceCustomerSection(),
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

  // ============================================
  // INVOICE TABLE WITH MULTI-PRODUCT SUPPORT
  // ============================================
 Widget _buildInvoiceTableWithItems(List<Map<String, dynamic>> items, Map<String, dynamic> invoice, AppLocalizations l10n) {
  const headerFont = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black);
  const bodyFont = TextStyle(fontSize: 11, color: Colors.black);
  
  final isSale = invoice['sale_type']?.toString() == 'فروش';
  
  // Column headers based on invoice type
  List<String> columnHeaders;
  Map<int, FixedColumnWidth> columnWidths;
  
  if (isSale) {
    columnHeaders = [
      'شماره', 
      'نوع تولید',
      'سایز', 
      'ضخامت\nmm', 
      'وزن فی\nخاده (kg)', 
      'تعداد خاده', 
      'مجموع وزن (ton)',
      'قیمت\nواحد (USD)',
      'قیمت کل\n(USD)',
    ];
    columnWidths = {
      0: const FixedColumnWidth(40),
      1: const FixedColumnWidth(80),
      2: const FixedColumnWidth(55),
      3: const FixedColumnWidth(55),
      4: const FixedColumnWidth(60),
      5: const FixedColumnWidth(55),
      6: const FixedColumnWidth(70),
      7: const FixedColumnWidth(65),
      8: const FixedColumnWidth(70),
    };
  } else {
    columnHeaders = [
      'شماره', 
      'نوع تولید',
      'سایز', 
      'ضخامت\nmm', 
      'وزن فی\nخاده (kg)', 
      'تعداد خاده', 
      'مجموع وزن (ton)',
    ];
    columnWidths = {
      0: const FixedColumnWidth(40),
      1: const FixedColumnWidth(90),
      2: const FixedColumnWidth(70),
      3: const FixedColumnWidth(65),
      4: const FixedColumnWidth(75),
      5: const FixedColumnWidth(70),
      6: const FixedColumnWidth(100),
    };
  }

  List<List<String>> tableData = [];
  int rowIndex = 1;
  double totalWeightSum = 0;
  double totalPriceSum = 0;
  
  for (var item in items) {
    String productName = item['product_name']?.toString() ?? '-';
    String size = item['size']?.toString() ?? '-';
    String thickness = item['thickness']?.toString() ?? '-';
    String weightPerUnit = item['weight_per_unit']?.toString() ?? '0';
    String unitCount = item['unit_count']?.toString() ?? '0';
    String unit = item['unit']?.toString() ?? 'کیلوگرم';
    String unitPrice = item['unit_price']?.toString() ?? '0';
    String totalPrice = item['total_price']?.toString() ?? '0';
    
    double weightPerUnitVal = double.tryParse(weightPerUnit) ?? 0;
    double totalWeightVal = double.tryParse(item['total_weight']?.toString() ?? '0') ?? 0;
    double totalPriceVal = double.tryParse(totalPrice) ?? 0;
    totalWeightSum += totalWeightVal;
    totalPriceSum += totalPriceVal;
    
    String displayWeightPerUnit = _formatRawWeightForInvoice(unit, weightPerUnitVal);
    String displayTotalWeight = _formatWeightForInvoice(unit, totalWeightVal);
    String displayUnitPrice = double.tryParse(unitPrice)?.toStringAsFixed(0) ?? '0';
    String displayTotalPrice = totalPriceVal.toStringAsFixed(0);
    
    if (isSale) {
      tableData.add([
        rowIndex.toString(),
        productName,
        size,
        thickness,
        displayWeightPerUnit,
        unitCount,
        displayTotalWeight,
        displayUnitPrice,
        displayTotalPrice,
      ]);
    } else {
      tableData.add([
        rowIndex.toString(),
        productName,
        size,
        thickness,
        displayWeightPerUnit,
        unitCount,
        displayTotalWeight,
      ]);
    }
    rowIndex++;
  }

  while (tableData.length < 5) {
    if (isSale) {
      tableData.add(['', '', '', '', '', '', '', '', '']);
    } else {
      tableData.add(['', '', '', '', '', '', '']);
    }
  }

  // Summary row
  if (isSale) {
    tableData.add([
      'مجموعه:',
      '',
      '',
      '',
      '',
      '',
      _formatWeightForInvoice('kg', totalWeightSum),
      '',
      _formatCurrency(totalPriceSum),
    ]);
  } else {
    tableData.add([
      'مجموعه:',
      '',
      '',
      '',
      '',
      '',
      _formatWeightForInvoice('kg', totalWeightSum),
    ]);
  }

  return Table(
    border: TableBorder.all(color: Colors.black, width: 1),
    columnWidths: columnWidths,
    children: [
      TableRow(
        decoration: BoxDecoration(color: Colors.blue[100]),
        children: columnHeaders.map((title) => Container(
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
              style: isSummary ? const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCB001D)) : bodyFont,
              textAlign: TextAlign.center,
            ),
          )).toList(),
        );
      }),
    ],
  );
}
Widget _buildFinancialSummary(Map<String, dynamic> invoice, AppLocalizations l10n) {
  // Only show for Sale invoices
  final isSale = invoice['sale_type']?.toString() == 'فروش';
  if (!isSale) return const SizedBox.shrink();
  
  // Get items to calculate totals
  List<Map<String, dynamic>> items = [];
  if (invoice.containsKey('items') && invoice['items'] is List) {
    items = List<Map<String, dynamic>>.from(invoice['items']);
  } else if (invoice['product_name'] != null && invoice['product_name']!.toString().isNotEmpty) {
    items.add({
      'total_price': double.tryParse(invoice['total_price']?.toString() ?? '0') ?? 0,
      'total_weight': double.tryParse(invoice['total_weight']?.toString() ?? '0') ?? 0,
    });
  }
  
  double totalPrice = 0;
  for (var item in items) {
    totalPrice += double.tryParse(item['total_price']?.toString() ?? '0') ?? 0;
  }
  
  final exchangeRate = invoice['price_rate']?.toString() ?? '1';
  final afnEquivalent = invoice['afn_equivalent']?.toString() ?? '0';
  
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
                      '\$${_formatCurrency(totalPrice)}',
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
                      exchangeRate,
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
                      'معادل به افغانی',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.green.shade700),
                    ),
                    Text(
                      '${_formatCurrency(afnEquivalent)} AFN',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
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
                        Text('مشتری', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                        const Text('تیلفون', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                        const Text('ساعت بارگیری', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                            ),
                            child: Text(
                              invoice['loading_time']?.toString() ?? '',
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
                      const Text('آدرس', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
                          ),
                          child: Text(
                            invoice['customer_address']?.toString() ?? invoice['location']?.toString() ?? '',
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
    String driverName = invoice['driver_name']?.toString() ?? '';
    String numberPlate = invoice['number_plate']?.toString() ?? '';
    
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
                Expanded(child: _buildInvoiceInlineInput('اسم :', driverName)),
                const SizedBox(width: 15),
                Expanded(child: _buildInvoiceInlineInput('نمبر پلیت:', numberPlate)),
                const SizedBox(width: 15),
                Expanded(child: _buildInvoiceInlineInput('امضا/شصت دریور:', '')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCustomerSection() {
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
                Expanded(child: _buildInvoiceInlineInput('اسم :', '')),
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

    final bool isWaybill = invoice['sale_type']?.toString() == 'بارنامه' || invoice['sale_type']?.toString() == 'پیش\u200cفاکتور';
    final String headerTitle = isWaybill ? 'بارنامه' : 'بل ثبت فروش';

    List<Map<String, dynamic>> items = [];
    if (invoice.containsKey('items') && invoice['items'] is List) {
      items = List<Map<String, dynamic>>.from(invoice['items']);
    } else {
      if (invoice['product_name'] != null && invoice['product_name']!.toString().isNotEmpty) {
        items.add({
          'product_name': invoice['product_name'],
          'size': invoice['size'] ?? '-',
          'thickness': invoice['thickness'] ?? '-',
          'weight_per_unit': double.tryParse(invoice['weight_per_unit']?.toString() ?? '0') ?? 0,
          'unit_count': double.tryParse(invoice['unit_count']?.toString() ?? '0') ?? 0,
          'total_weight': double.tryParse(invoice['total_weight']?.toString() ?? '0') ?? 0,
          'unit': invoice['unit']?.toString() ?? 'کیلوگرم',
          'unit_price': double.tryParse(invoice['unit_price']?.toString() ?? '0') ?? 0,
          'total_price': double.tryParse(invoice['total_price']?.toString() ?? '0') ?? 0,
        });
      }
    }

    List<List<String>> tableData = [];
    int rowIndex = 1;
    double totalWeightSum = 0;
    for (var item in items) {
      String productName = item['product_name']?.toString() ?? '-';
      String size = item['size']?.toString() ?? '-';
      String thickness = item['thickness']?.toString() ?? '-';
      double weightPerUnit = item['weight_per_unit'] ?? 0;
      String unitCount = item['unit_count']?.toString() ?? '0';
      String unit = item['unit']?.toString() ?? 'کیلوگرم';
      double totalWeight = item['total_weight'] ?? 0;
      totalWeightSum += totalWeight;
      
      String displayWeightPerUnit = _formatRawWeightForInvoice(unit, weightPerUnit);
      String displayTotalWeight = _formatWeightForInvoice(unit, totalWeight);
      
      tableData.add([
        rowIndex.toString(),
        productName,
        size,
        thickness,
        displayWeightPerUnit,
        unitCount,
        displayTotalWeight,
      ]);
      rowIndex++;
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
                          child: pw.Text(headerTitle, style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
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
                              pw.Expanded(child: pw.Text('${l10n.company}: ${getPdfValue('customer_company')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black))),
                              pw.SizedBox(width: 12),
                              pw.Expanded(child: pw.Text('${l10n.dischargeLocation}: ${getPdfValue('location') != '-' ? getPdfValue('location') : getPdfValue('customer_address')}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black))),
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
                                pw.Text('${l10n.invoiceNumberLabel}: $invoiceNumber', style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 6),
                                pw.Text('${l10n.persianDate}: ${getPdfValue('date')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                                pw.Text('Date (EN): ${getPdfValue('date_en')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                              ]),
                              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                                pw.Text('${l10n.paymentMethod}: ${getPdfValue('payment_method') == 'cash' ? l10n.cash : l10n.loan}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black)),
                                pw.SizedBox(height: 6),
                                if (getPdfValue('loading_time') != '-' && getPdfValue('loading_time').isNotEmpty)
                                  pw.Text('${l10n.loadingTime}: ${getPdfValue('loading_time')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                                if (getPdfValue('loading_time_en') != '-' && getPdfValue('loading_time_en').isNotEmpty)
                                  pw.Text('Loading (EN): ${getPdfValue('loading_time_en')}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
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
                              'نوع تولید',
                              'سایز',
                              'ضخامت',
                              'وزن فی (kg)',
                              'تعداد',
                              'مجموع وزن (ton)',
                            ],
                            data: tableData.isEmpty 
                                ? [['1', '-', '-', '-', '0', '0', '0']]
                                : tableData,
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
                                pw.Text('${l10n.loadingCost}: ${_formatCurrency(invoice?['loading_cost'])}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                                pw.Text('${l10n.transferCost}: ${_formatCurrency(invoice?['transfer_cost'])}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                                pw.Text('${l10n.clearanceCost}: ${_formatCurrency(invoice?['clearance_cost'])}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                              ]),
                              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                                pw.Text('${l10n.totalPrice}: ${_formatCurrency(invoice?['total_price'])}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black)),
                                pw.Text('${l10n.discount}: ${_formatCurrency(invoice?['discount'])}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.black)),
                                pw.SizedBox(height: 6),
                                pw.Text('${l10n.amountDue}: ${_formatCurrency(invoice?['final_price'])} ${getPdfValue('currency') != '-' ? getPdfValue('currency') : 'USD'}', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                              ]),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 24),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(10)),
                          child: pw.Column(
                            children: [
                              pw.Container(
                                color: PdfColors.blue900,
                                width: double.infinity,
                                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                                child: pw.Text(
                                  'تسلیم دهی دریور:',
                                  style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8.0),
                                child: pw.Row(
                                  children: [
                                    pw.Expanded(child: pw.Text('اسم : ${getPdfValue('driver_name')}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                                    pw.SizedBox(width: 15),
                                    pw.Expanded(child: pw.Text('نمبر پلیت: ${getPdfValue('number_plate')}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                                    pw.SizedBox(width: 15),
                                    pw.Expanded(child: pw.Text('امضا/شصت دریور:', style: pw.TextStyle(font: ttf, fontSize: 10))),
                                  ],
                                ),
                              ),
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

  Future<void> _saveInvoicePdf(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
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
      bytes ??= await _generateInvoicePdfBytes(invoice, invoiceNumber, l10n);
      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.savePdf,
        fileName: 'invoice_${invoiceNumber.replaceAll(' ', '_')}.pdf',
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

  Future<void> _printInvoicePdf(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
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
      bytes ??= await _generateInvoicePdfBytes(invoice, invoiceNumber, l10n);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes!,
        name: 'invoice_${invoiceNumber.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      _showSnackbar('${l10n.errorPrintingInvoice}: $e', Colors.red);
    }
  }

  // ============================================
  // BUILD HELPER METHODS
  // ============================================
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteInvoice),
        content: Text('${l10n.deleteConfirmation} ${sale['invoice_number']}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _db.deleteSalesInvoice(sale['id']);
    if (result == -1) {
      _showSnackbar(l10n.errorDeletingInvoice, Colors.red);
      return;
    }
    await _loadData();
    _showSnackbar(l10n.invoiceDeletedSuccess, Colors.red);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildSectionTitle(String title, AppLocalizations l10n) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppLocalizations l10n,
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
    return number.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), 
      (m) => '${m[1]},'
    );
  }

  Widget _buildReturnStatusCell(Map<String, dynamic> sale, AppLocalizations l10n) {
    final isReturned = sale['is_back_returned'] == 1 || sale['is_back_returned']?.toString() == '1';
    if (!isReturned) {
      return Text(l10n.normal, style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFEBF1FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
      child: Text(l10n.returned, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF034ADE))),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: Color(0xFFCB001D), size: 28)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.salesManagement, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              Text(l10n.salesManagementSubtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ]),
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
              onPressed: _showAddSaleDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(l10n.addNewSale),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats(AppLocalizations l10n) {
    final totalSales = _sales.fold<double>(0, (sum, item) => sum + (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0));
    final totalInvoices = _sales.length;
    final totalTons = _getTotalTons();
    
    return Row(
      children: [
        _buildStatCard(l10n.totalSales, _formatCurrency(totalSales), Icons.attach_money_outlined, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard(l10n.totalInvoices, totalInvoices.toString(), Icons.receipt_long_outlined, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard(l10n.usdTotal, _formatCurrency(_sales.fold<double>(0, (sum, item) => sum + ((item['currency'] == 'USD' ? (double.tryParse(item['final_price']?.toString() ?? '0') ?? 0) : 0)))), Icons.currency_exchange, Colors.green.shade700),
        const SizedBox(width: 12),
        _buildStatCard('مجموع وزن', '${totalTons.toStringAsFixed(totalTons % 1 == 0 ? 0 : 2)} تن', Icons.scale, const Color(0xFFCB001D)),
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

  Widget _buildFilterAndSearch(AppLocalizations l10n) {
    final filters = [l10n.all, l10n.sale, l10n.proformaInvoice];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Row(children: [Expanded(child: TextField(controller: _searchController, onChanged: (value) => setState(() => _searchQuery = value), decoration: InputDecoration(hintText: l10n.searchByCustomerOrInvoice, prefixIcon: Icon(Icons.search, color: Colors.grey.shade400), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2))))), const SizedBox(width: 12), ...filters.map((filter) => Padding(padding: const EdgeInsets.only(left: 8), child: FilterChip(label: Text(filter, style: TextStyle(color: _selectedFilter == filter ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w600)), selected: _selectedFilter == filter, onSelected: (selected) => setState(() => _selectedFilter = filter), selectedColor: const Color(0xFFCB001D), backgroundColor: Colors.grey.shade100, checkmarkColor: Colors.white)))]), 
    );
  }

  Widget _buildSalesTable(List<Map<String, dynamic>> data, AppLocalizations l10n) {
  final totalPages = (data.length / _rowsPerPage).ceil();
  final start = (_currentPage * _rowsPerPage).clamp(0, data.length);
  final paged = data.skip(start).take(_rowsPerPage).toList();
  final allSelectedOnPage = paged.isNotEmpty && paged.every((s) => _selectedInvoices.contains((s['invoice_number'] ?? '').toString()));

  return Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))]),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14))
        ),
        child: Row(children: [
          SizedBox(width: 40, child: Checkbox(
            value: allSelectedOnPage,
            onChanged: (v) {
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
            }
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: Text(l10n.invoiceNumberLabel)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Text(l10n.customer)),
          Expanded(flex: 2, child: Text(l10n.product)),
          Expanded(flex: 1, child: Text(l10n.finalPrice)),
          Expanded(flex: 1, child: Text(l10n.status)),
          Expanded(flex: 1, child: Text(l10n.date)),
          Expanded(flex: 1, child: Text(l10n.actions))
        ]),
      ),
      Expanded(child: paged.isEmpty ? Center(child: Text(l10n.noInvoicesFound, style: const TextStyle(color: Colors.grey))) : ListView.builder(itemCount: paged.length, itemBuilder: (context, index) {
        final sale = paged[index];
        final inv = (sale['invoice_number'] ?? '').toString();
        final checked = _selectedInvoices.contains(inv);
        
        // Get product names safely
        final productNames = sale['product_names'] as List?;
        final productCount = sale['product_count'] ?? 1;
        
        return InkWell(
          onTap: () async {
            _showInvoiceModal(context, sale['invoice_number'] ?? '-', sale, l10n);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1))),
            child: Row(children: [
              SizedBox(width: 40, child: Checkbox(
                value: checked,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedInvoices.add(inv);
                    } else {
                      _selectedInvoices.remove(inv);
                    }
                  });
                }
              )),
              Expanded(flex: 1, child: Text(inv.isNotEmpty ? inv : '-', style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sale['customer_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(sale['customer_company'] ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))
              ])),
              Expanded(flex: 2, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (productNames != null && productNames.isNotEmpty)
                    ...productNames.take(2).map((name) => 
                      Text(name?.toString() ?? '-', style: const TextStyle(fontSize: 12))
                    ).toList()
                  else
                    Text(sale['product_name'] ?? '-', style: const TextStyle(fontSize: 13)),
                  if (productNames != null && productNames.length > 2)
                    Text(
                      'و ${productNames.length - 2} محصول دیگر...',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  Text(
                    '$productCount محصول',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              )),
              Expanded(flex: 1, child: Text(_formatCurrency(sale['final_price']), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFCB001D)))),
              Expanded(flex: 1, child: _buildReturnStatusCell(sale, l10n)),
              Expanded(flex: 1, child: Text(sale['date'] ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
              Expanded(flex: 1, child: SizedBox(
                width: 104,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        _showInvoiceModal(context, sale['invoice_number'] ?? '-', sale, l10n);
                      },
                      icon: const Icon(Icons.visibility_outlined, color: Colors.blue),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      onPressed: () => _showEditSaleDialog(sale),
                      icon: const Icon(Icons.edit_outlined, color: Colors.orange),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      onPressed: () => _deleteSale(sale),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ))
            ])
          )
        );
      })),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Text('${l10n.page} ${_currentPage + 1} ${l10n.pageOf} ${totalPages == 0 ? 1 : totalPages}'),
          const SizedBox(width: 12),
          IconButton(onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: (_currentPage + 1) < totalPages ? () => setState(() => _currentPage++) : null, icon: const Icon(Icons.chevron_right)),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _rowsPerPage,
            items: const [
              DropdownMenuItem(value: 5, child: Text('5')),
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 20, child: Text('20')),
              DropdownMenuItem(value: 50, child: Text('50'))
            ],
            onChanged: (v) => setState(() { _rowsPerPage = v ?? 10; _currentPage = 0; })
          ),
        ]),
        Row(children: [
          Text('${l10n.selected}: ${_selectedInvoices.length}'),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _selectedInvoices.isEmpty ? null : () { /* placeholder for bulk actions */ },
            child: Text(l10n.bulkActions)
          )
        ])
      ])),
    ]),
  );
}

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final filteredData = _sales.where((sale) {
      final search = _searchQuery.toLowerCase();
      final matchesSearch = (sale['invoice_number'] ?? '').toString().toLowerCase().contains(search) || 
                           (sale['customer_name'] ?? '').toString().toLowerCase().contains(search) || 
                           (sale['display_products'] ?? '').toString().toLowerCase().contains(search) ||
                           (sale['product_name'] ?? '').toString().toLowerCase().contains(search);
      final matchesFilter = _selectedFilter == 'همه' || (sale['sale_type'] ?? 'فروش') == _selectedFilter;
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(l10n),
                    const SizedBox(height: 20),
                    _buildQuickStats(l10n),
                    const SizedBox(height: 20),
                    _buildFilterAndSearch(l10n),
                    const SizedBox(height: 16),
                    Expanded(child: _buildSalesTable(filteredData, l10n))
                  ]
                ),
        ),
      ),
    );
  }
}
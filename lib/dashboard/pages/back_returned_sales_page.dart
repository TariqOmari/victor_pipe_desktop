// ============================================
// BACK_RETURNED_SALES_PAGE - COMPLETE FIXED VERSION
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
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
      return weight / 1000;
    } else if (unit == 'تن' || unit == 'ton' || unit == 'Ton') {
      return weight;
    }
    return weight;
  }

  // Convert weight to KG
  double _convertToKg(String unit, double weight) {
    if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
      return weight;
    } else if (unit == 'تن' || unit == 'ton' || unit == 'Ton') {
      return weight * 1000;
    }
    return weight;
  }

  // Format weight for display
  String _formatWeight(String unit, double weight, {bool showUnit = true}) {
    if (weight == 0) return '0';
    String formatted = weight.toStringAsFixed(weight % 1 == 0 ? 0 : 2);
    if (!showUnit) return formatted;
    
    if (_isWeightUnit(unit)) {
      double tons = _convertToTons(unit, weight);
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
    }
    return '$formatted $unit';
  }

  // Get total tons of all returned sales
  double _getTotalTons() {
    double totalTons = 0;
    for (var sale in _returnedSales) {
      String unit = sale['unit']?.toString() ?? '';
      double weight = double.tryParse(sale['returned_weight']?.toString() ?? '0') ?? 0;
      
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
      total += double.tryParse(sale['returned_price']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  String _formatCurrency(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '0') ?? 0;
    return number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
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

      print('📋 Headers: $headers');

      int invoiceNumberIndex = -1;
      int customerNameIndex = -1;
      int customerCompanyIndex = -1;
      int productNameIndex = -1;
      int genderIndex = -1;
      int sizeIndex = -1;
      int thicknessIndex = -1;
      int weightPerUnitIndex = -1;
      int unitCountIndex = -1;
      int totalWeightIndex = -1;
      int unitIndex = -1;
      int unitPriceIndex = -1;
      int totalPriceIndex = -1;
      int discountIndex = -1;
      int finalPriceIndex = -1;
      int currencyIndex = -1;
      int returnDateIndex = -1;
      int returnReasonIndex = -1;
      int customerPhoneIndex = -1;
      int customerAddressIndex = -1;
      int returnedCountIndex = -1;

      for (int i = 0; i < headers.length; i++) {
        String h = headers[i];
        String hLower = h.toLowerCase();
        
        if (hLower.contains('شماره') || hLower.contains('فاکتور') || hLower.contains('invoice')) {
          invoiceNumberIndex = i;
        } else if (hLower.contains('مشتری') || hLower.contains('خریدار') || hLower.contains('customer')) {
          customerNameIndex = i;
        } else if (hLower.contains('شرکت') || hLower.contains('company')) {
          customerCompanyIndex = i;
        } else if (hLower.contains('محصول') || hLower.contains('product')) {
          productNameIndex = i;
        } else if (hLower.contains('جنسیت') || hLower.contains('gender')) {
          genderIndex = i;
        } else if (hLower.contains('سایز') || hLower.contains('size')) {
          sizeIndex = i;
        } else if (hLower.contains('ضخامت') || hLower.contains('thickness')) {
          thicknessIndex = i;
        } else if (hLower.contains('وزن فی') || hLower.contains('weight per unit')) {
          weightPerUnitIndex = i;
        } else if (hLower.contains('تعداد') || hLower.contains('unit count') || hLower.contains('خاده')) {
          unitCountIndex = i;
        } else if (hLower.contains('وزن کل') || hLower.contains('total weight')) {
          totalWeightIndex = i;
        } else if (hLower.contains('واحد') && !hLower.contains('پول')) {
          unitIndex = i;
        } else if (hLower.contains('قیمت واحد') || hLower.contains('unit price')) {
          unitPriceIndex = i;
        } else if (hLower.contains('قیمت کل') || hLower.contains('total price')) {
          totalPriceIndex = i;
        } else if (hLower.contains('تخفیف') || hLower.contains('discount')) {
          discountIndex = i;
        } else if (hLower.contains('قیمت نهایی') || hLower.contains('final price')) {
          finalPriceIndex = i;
        } else if (hLower.contains('ارز') || hLower.contains('واحد پول') || hLower.contains('currency')) {
          currencyIndex = i;
        } else if (hLower.contains('تاریخ برگشت') || hLower.contains('return date')) {
          returnDateIndex = i;
        } else if (hLower.contains('دلیل برگشت') || hLower.contains('return reason')) {
          returnReasonIndex = i;
        } else if (hLower.contains('تلفن') || hLower.contains('phone')) {
          customerPhoneIndex = i;
        } else if (hLower.contains('آدرس') || hLower.contains('address')) {
          customerAddressIndex = i;
        } else if (hLower.contains('تعداد برگشت') || hLower.contains('returned count')) {
          returnedCountIndex = i;
        }
      }

      print('📋 Invoice: $invoiceNumberIndex, Customer: $customerNameIndex');

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
          
          if (invoiceNumber.isEmpty || customerName.isEmpty) {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': فیلدهای مورد نیاز کامل نیستند');
            continue;
          }

          // Get the existing sale
          final existingSale = await _db.getSalesInvoiceByNumber(invoiceNumber);
          if (existingSale == null) {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': فاکتور "' + invoiceNumber + '" در سیستم وجود ندارد');
            continue;
          }

          // Check if already returned
          if ((existingSale['is_back_returned'] ?? 0) == 1) {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': فاکتور "' + invoiceNumber + '" قبلاً برگشت داده شده است');
            continue;
          }

          String returnDate = returnDateIndex != -1 ? _getCellValueDirect(row, returnDateIndex) : PersianDateConverter.getCurrentPersianDate();
          String returnReason = returnReasonIndex != -1 ? _getCellValueDirect(row, returnReasonIndex) : '';
          String returnDateEn = PersianDateConverter.getEnglishDate(DateTime.now());

          // Get original values
          String unit = existingSale['unit']?.toString() ?? 'کیلوگرم';
          double originalUnitCount = double.tryParse(existingSale['unit_count']?.toString() ?? '0') ?? 0;
          double weightPerUnit = double.tryParse(existingSale['weight_per_unit']?.toString() ?? '0') ?? 0;
          double originalTotalWeight = double.tryParse(existingSale['total_weight']?.toString() ?? '0') ?? 0;
          double originalFinalPrice = double.tryParse(existingSale['final_price']?.toString() ?? '0') ?? 0;
          double originalUnitPrice = double.tryParse(existingSale['unit_price']?.toString() ?? '0') ?? 0;

          // Get returned count (how many units to return)
          double returnedCount = originalUnitCount;
          if (returnedCountIndex != -1) {
            String returnedCountStr = _getCellValueDirect(row, returnedCountIndex);
            double parsed = _parseNumber(returnedCountStr);
            if (parsed > 0 && parsed <= originalUnitCount) {
              returnedCount = parsed;
            }
          }

          // Calculate returned weight and price based on returned count
          double weightPerUnitInKg = _convertToKg(unit, weightPerUnit);
          double returnedWeightKg = weightPerUnitInKg * returnedCount;
          double pricePerUnit = originalUnitCount > 0 ? originalFinalPrice / originalUnitCount : 0;
          double returnedPrice = pricePerUnit * returnedCount;

          // Remaining counts
          double remainingCount = originalUnitCount - returnedCount;
          double remainingWeightKg = weightPerUnitInKg * remainingCount;
          double remainingPrice = pricePerUnit * remainingCount;

          // Update the original sale with remaining values
          final updatePayload = {
            'unit_count': remainingCount > 0 ? remainingCount.toString() : '0',
            'total_weight': remainingWeightKg > 0 ? remainingWeightKg.toString() : '0',
            'final_price': remainingPrice > 0 ? remainingPrice : 0,
            'is_back_returned': 1,
            'back_return_reason': returnReason,
            'back_return_date': returnDate,
            'back_return_date_en': returnDateEn,
            'returned_count': returnedCount,
            'returned_weight': returnedWeightKg,
            'returned_price': returnedPrice,
            'original_unit_count': originalUnitCount,
            'original_total_weight': originalTotalWeight,
            'original_final_price': originalFinalPrice,
          };

          // Update the sale
          final result = await _db.updateSalesInvoice(existingSale['id'], updatePayload);
          if (result == -1) {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': خطا در به‌روزرسانی فاکتور');
            continue;
          }

          // If product exists, update stock
          final productId = existingSale['produced_product_id'];
          if (productId != null && returnedWeightKg > 0) {
            await _db.addProductStock(productId, returnedWeightKg, 'kg');
          }

          successCount++;
          importedData.add({
            ...existingSale,
            ...updatePayload,
            'returned_count': returnedCount,
            'returned_weight': returnedWeightKg,
            'returned_price': returnedPrice,
            'remaining_count': remainingCount,
            'remaining_weight': remainingWeightKg,
            'remaining_price': remainingPrice,
          });
          print('✅ Row ${i+1} imported! Returned: $returnedCount units, ${returnedWeightKg}kg');

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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allSales = await _db.getSalesInvoices();
      // Filter only returned sales
      final returnedSales = allSales.where((sale) => (sale['is_back_returned'] ?? 0) == 1).toList();
      
      print('📊 Loaded ${returnedSales.length} returned sales out of ${allSales.length} total');
      
      if (!mounted) return;
      setState(() {
        _allSales = allSales;
        _returnedSales = returnedSales;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar(l10n.errorLoadingReturnedSales, Colors.red);
    }
  }

  // ============================================
  // ADD RETURN DIALOG - COMPLETE WITH ALL FIELDS
  // ============================================
  Future<void> _showAddReturnedSaleDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    final dateController = TextEditingController(text: PersianDateConverter.getCurrentPersianDate());
    String selectedEnglishDate = PersianDateConverter.getEnglishDate(DateTime.now());
    Map<String, dynamic>? selectedSale;
    double returnedCount = 0;
    double maxCount = 0;
    
    // Get available sales (not returned yet)
    final availableSales = _allSales.where((sale) => (sale['is_back_returned'] ?? 0) != 1).toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Update max count when sale changes
          if (selectedSale != null) {
            maxCount = double.tryParse(selectedSale!['unit_count']?.toString() ?? '0') ?? 0;
            if (returnedCount > maxCount) {
              returnedCount = maxCount;
            }
          }

          // Calculate values based on returned count
          double weightPerUnit = 0;
          double originalTotalWeight = 0;
          double originalFinalPrice = 0;
          double originalUnitCount = 0;
          String unit = 'کیلوگرم';
          String productName = '';
          String customerName = '';
          String company = '';
          String invoiceNumber = '';
          String gender = '';
          String size = '';
          String thickness = '';
          String weightPerUnitStr = '';
          String unitCountStr = '';
          String totalWeightStr = '';
          String unitPriceStr = '';
          String totalPriceStr = '';
          String finalPriceStr = '';
          String currency = 'USD';
          String customerPhone = '';
          String customerAddress = '';

          if (selectedSale != null) {
            unit = selectedSale!['unit']?.toString() ?? 'کیلوگرم';
            weightPerUnit = double.tryParse(selectedSale!['weight_per_unit']?.toString() ?? '0') ?? 0;
            originalTotalWeight = double.tryParse(selectedSale!['total_weight']?.toString() ?? '0') ?? 0;
            originalFinalPrice = double.tryParse(selectedSale!['final_price']?.toString() ?? '0') ?? 0;
            originalUnitCount = double.tryParse(selectedSale!['unit_count']?.toString() ?? '0') ?? 0;
            productName = selectedSale!['product_name']?.toString() ?? '-';
            customerName = selectedSale!['customer_name']?.toString() ?? '-';
            company = selectedSale!['customer_company']?.toString() ?? '-';
            invoiceNumber = selectedSale!['invoice_number']?.toString() ?? '-';
            gender = selectedSale!['gender']?.toString() ?? '-';
            size = selectedSale!['size']?.toString() ?? '-';
            thickness = selectedSale!['thickness']?.toString() ?? '-';
            weightPerUnitStr = selectedSale!['weight_per_unit']?.toString() ?? '0';
            unitCountStr = selectedSale!['unit_count']?.toString() ?? '0';
            totalWeightStr = selectedSale!['total_weight']?.toString() ?? '0';
            unitPriceStr = selectedSale!['unit_price']?.toString() ?? '0';
            totalPriceStr = selectedSale!['total_price']?.toString() ?? '0';
            finalPriceStr = selectedSale!['final_price']?.toString() ?? '0';
            currency = selectedSale!['currency']?.toString() ?? 'USD';
            customerPhone = selectedSale!['customer_phone']?.toString() ?? '';
            customerAddress = selectedSale!['customer_address']?.toString() ?? '';
          }

          // Calculate returned values
          double weightPerUnitInKg = _convertToKg(unit, weightPerUnit);
          double returnedWeightKg = weightPerUnitInKg * returnedCount;
          double returnedWeightTons = _convertToTons(unit, returnedWeightKg);
          double pricePerUnit = originalUnitCount > 0 ? originalFinalPrice / originalUnitCount : 0;
          double returnedPrice = pricePerUnit * returnedCount;

          // Remaining values
          double remainingCount = originalUnitCount - returnedCount;
          double remainingWeightKg = weightPerUnitInKg * remainingCount;
          double remainingWeightTons = _convertToTons(unit, remainingWeightKg);
          double remainingPrice = pricePerUnit * remainingCount;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                l10n.addReturnedSale,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1A1A1A)),
              ),
              content: SizedBox(
                width: 750,
                height: MediaQuery.of(context).size.height * 0.75,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Select Sale
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedSale,
                        decoration: InputDecoration(
                          labelText: l10n.selectSaleInvoice,
                          border: const OutlineInputBorder(),
                        ),
                        items: availableSales.map((sale) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: sale,
                            child: Text(
                              '${sale['invoice_number'] ?? '-'} | ${sale['customer_name'] ?? '-'} | ${sale['product_name'] ?? '-'}',
                            ),
                          );
                        }).toList(),
                        onChanged: (sale) {
                          setDialogState(() {
                            selectedSale = sale;
                            returnedCount = 0;
                            if (sale != null) {
                              maxCount = double.tryParse(sale!['unit_count']?.toString() ?? '0') ?? 0;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // ALL SALE DETAILS - ZERO TO HERO
                      if (selectedSale != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '📋 اطلاعات کامل فاکتور',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFCB001D)),
                              ),
                              const SizedBox(height: 12),
                              
                              // Row 1: Invoice & Customer
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildReadOnlyField('شماره فاکتور', invoiceNumber, l10n),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildReadOnlyField(l10n.customerName, customerName, l10n),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Row 2: Company & Phone
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildReadOnlyField(l10n.company, company, l10n),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildReadOnlyField(l10n.phoneNumber, customerPhone, l10n),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Row 3: Address
                              _buildReadOnlyField(l10n.address, customerAddress, l10n),
                              const SizedBox(height: 8),
                              
                              const Divider(),
                              const SizedBox(height: 8),
                              
                              // Row 4: Product Details
                              const Text(
                                '📦 جزئیات محصول',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildReadOnlyField(l10n.productName, productName, l10n),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildReadOnlyField(l10n.gender, gender, l10n),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildReadOnlyField(l10n.size, size, l10n),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildReadOnlyField(l10n.thickness, thickness, l10n),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Row 5: Weight Details
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildReadOnlyField('وزن فی خاده (kg)', weightPerUnitStr, l10n),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildReadOnlyField('تعداد خاده', unitCountStr, l10n),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildReadOnlyField('وزن کل', _formatWeight(unit, originalTotalWeight), l10n),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Row 6: Price Details
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildReadOnlyField('قیمت واحد', _formatCurrency(unitPriceStr), l10n),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildReadOnlyField('قیمت کل', _formatCurrency(totalPriceStr), l10n),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildReadOnlyField('قیمت نهایی', '${_formatCurrency(finalPriceStr)} $currency', l10n),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Return Count Input
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '🔄 تعداد برگشت (خاده)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: returnedCount > 0 ? returnedCount.toString() : '',
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'تعداد خاده برای برگشت',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        suffixText: '(حداکثر ${maxCount.toStringAsFixed(maxCount % 1 == 0 ? 0 : 2)})',
                                      ),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          double val = _parseNumber(value);
                                          if (val < 0) val = 0;
                                          if (val > maxCount) val = maxCount;
                                          returnedCount = val;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Text(
                                      'از ${originalUnitCount.toStringAsFixed(originalUnitCount % 1 == 0 ? 0 : 2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Text(
                                        '✅ باقی‌مانده: ${remainingCount.toStringAsFixed(remainingCount % 1 == 0 ? 0 : 2)} خاده',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Text(
                                        '🔴 برگشت: ${returnedCount.toStringAsFixed(returnedCount % 1 == 0 ? 0 : 2)} خاده',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Return Details with Calculations
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '📊 محاسبات برگشت',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFCB001D)),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('🔄 برگشت', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                          Text('خاده: ${returnedCount.toStringAsFixed(returnedCount % 1 == 0 ? 0 : 2)}', style: const TextStyle(fontSize: 12)),
                                          Text('وزن: ${_formatWeight(unit, returnedWeightKg)}', style: const TextStyle(fontSize: 12)),
                                          Text('قیمت: ${_formatCurrency(returnedPrice)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('✅ باقی‌مانده', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                          Text('خاده: ${remainingCount.toStringAsFixed(remainingCount % 1 == 0 ? 0 : 2)}', style: const TextStyle(fontSize: 12)),
                                          Text('وزن: ${_formatWeight(unit, remainingWeightKg)}', style: const TextStyle(fontSize: 12)),
                                          Text('قیمت: ${_formatCurrency(remainingPrice)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Return Reason
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: l10n.returnReason,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Return Date
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
                  onPressed: selectedSale == null || returnedCount <= 0 || reasonController.text.trim().isEmpty
                      ? null
                      : () async {
                          // Get original values
                          final originalUnitCount = double.tryParse(selectedSale!['unit_count']?.toString() ?? '0') ?? 0;
                          final originalTotalWeight = double.tryParse(selectedSale!['total_weight']?.toString() ?? '0') ?? 0;
                          final originalFinalPrice = double.tryParse(selectedSale!['final_price']?.toString() ?? '0') ?? 0;
                          final unit = selectedSale!['unit']?.toString() ?? 'کیلوگرم';
                          final weightPerUnit = double.tryParse(selectedSale!['weight_per_unit']?.toString() ?? '0') ?? 0;
                          
                          // Calculate returned values
                          double weightPerUnitInKg = _convertToKg(unit, weightPerUnit);
                          double returnedWeightKg = weightPerUnitInKg * returnedCount;
                          double pricePerUnit = originalUnitCount > 0 ? originalFinalPrice / originalUnitCount : 0;
                          double returnedPrice = pricePerUnit * returnedCount;
                          
                          // Remaining values
                          double remainingCount = originalUnitCount - returnedCount;
                          double remainingWeightKg = weightPerUnitInKg * remainingCount;
                          double remainingPrice = pricePerUnit * remainingCount;

                          // Product ID for stock
                          final productId = selectedSale!['produced_product_id'];

                          // Update the sale with partial return
                          final updatePayload = {
                            'unit_count': remainingCount > 0 ? remainingCount.toString() : '0',
                            'total_weight': remainingWeightKg > 0 ? remainingWeightKg.toString() : '0',
                            'final_price': remainingPrice > 0 ? remainingPrice : 0,
                            'is_back_returned': 1,
                            'back_return_reason': reasonController.text.trim(),
                            'back_return_date': dateController.text.trim(),
                            'back_return_date_en': selectedEnglishDate,
                            'returned_count': returnedCount,
                            'returned_weight': returnedWeightKg,
                            'returned_price': returnedPrice,
                            'original_unit_count': originalUnitCount,
                            'original_total_weight': originalTotalWeight,
                            'original_final_price': originalFinalPrice,
                          };

                          print('📝 Updating sale with payload: $updatePayload');

                          final result = await _db.updateSalesInvoice(selectedSale!['id'], updatePayload);
                          if (result == -1) {
                            _showSnackbar(l10n.errorSavingReturnedSale, Colors.red);
                            return;
                          }

                          // Restore stock for returned items
                          if (productId != null && returnedWeightKg > 0) {
                            final stockRestored = await _db.addProductStock(
                              productId,
                              returnedWeightKg,
                              'kg'
                            );
                            if (!stockRestored) {
                              _showSnackbar('⚠️ خطا در بازگرداندن موجودی به انبار', Colors.orange);
                            } else {
                              _showSnackbar('✅ ${returnedCount} خاده (${_formatWeight(unit, returnedWeightKg, showUnit: false)} تن) به انبار بازگردانده شد', Colors.green);
                            }
                          }

                          // IMPORTANT: Reload data to refresh the table
                          await _loadData();
                          
                          Navigator.pop(context);
                          _showSnackbar(
                            '✅ ${returnedCount} خاده برگشت داده شد. باقی‌مانده: ${remainingCount.toStringAsFixed(remainingCount % 1 == 0 ? 0 : 2)} خاده',
                            Colors.green
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                    foregroundColor: Colors.white,
                  ),
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
        labelStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 12),
    );
  }

  // ============================================
  // PDF GENERATION - FIXED
  // ============================================
  Future<void> _generatePdfReturnInvoice(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    String unit = invoice['unit']?.toString() ?? '';
    double returnedCount = double.tryParse(invoice['returned_count']?.toString() ?? '0') ?? 0;
    double returnedWeight = double.tryParse(invoice['returned_weight']?.toString() ?? '0') ?? 0;
    double returnedPrice = double.tryParse(invoice['returned_price']?.toString() ?? '0') ?? 0;
    double originalCount = double.tryParse(invoice['original_unit_count']?.toString() ?? '0') ?? 0;
    double remainingCount = originalCount - returnedCount;

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
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(l10n.companyName, style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('رسید برگشت', style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.red,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            'RETURN',
                            style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text('${l10n.invoiceNumberLabel}: $invoiceNumber', style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${l10n.returnDate}: ${invoice['back_return_date'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                
                // Customer Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('${l10n.customer}: ${invoice['customer_name'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                      pw.Expanded(child: pw.Text('${l10n.company}: ${invoice['customer_company'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                      pw.Expanded(child: pw.Text('${l10n.address}: ${invoice['customer_address'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                
                // Return Details - FIXED: No withOpacity
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                    color: PdfColor.fromInt(0x0DCB001D), // Red with ~5% opacity
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                        children: [
                          pw.Text('تعداد برگشت: ${returnedCount.toStringAsFixed(returnedCount % 1 == 0 ? 0 : 2)}', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                          pw.Text('وزن برگشت: ${_formatWeight(unit, returnedWeight)}', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                          pw.Text('قیمت برگشت: ${_formatCurrency(returnedPrice)}', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                        children: [
                          pw.Text('کل خاده: ${originalCount.toStringAsFixed(originalCount % 1 == 0 ? 0 : 2)}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
                          pw.Text('باقی‌مانده: ${remainingCount.toStringAsFixed(remainingCount % 1 == 0 ? 0 : 2)}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.green700)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                
                // Return Reason
                pw.Text('${l10n.returnReason}: ${invoice['back_return_reason'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                pw.SizedBox(height: 12),
                
                // Product Table
                pw.Table.fromTextArray(
                  headers: [
                    l10n.productName, l10n.gender, l10n.size, l10n.thickness,
                    'وزن فی (kg)', 'تعداد خاده', 'وزن کل', l10n.finalPrice
                  ],
                  data: [
                    [
                      invoice['product_name'] ?? '-',
                      invoice['gender'] ?? '-',
                      invoice['size'] ?? '-',
                      invoice['thickness'] ?? '-',
                      _formatWeight(unit, double.tryParse(invoice['weight_per_unit']?.toString() ?? '0') ?? 0, showUnit: true),
                      invoice['unit_count']?.toString() ?? '-',
                      _formatWeight(unit, double.tryParse(invoice['total_weight']?.toString() ?? '0') ?? 0, showUnit: true),
                      '${_formatCurrency(invoice['final_price'])} ${invoice['currency'] ?? ''}',
                    ],
                  ],
                  headerStyle: pw.TextStyle(font: ttf, fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 8),
                  cellAlignment: pw.Alignment.center,
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(l10n.signature, style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('${l10n.printDate}: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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

  // ============================================
  // UI BUILD METHODS
  // ============================================
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
              onPressed: _showAddReturnedSaleDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(l10n.addReturnedSale),
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

  Widget _buildStatsCards(AppLocalizations l10n) {
    final totalTons = _getTotalTons();
    final totalCount = _getReturnedCount();
    
    double totalAFN = 0;
    double totalUSD = 0;
    
    for (var sale in _returnedSales) {
      double price = double.tryParse(sale['returned_price']?.toString() ?? '0') ?? 0;
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
                        'مجموع وزن برگشت (تن)',
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
                        'مجموع ارزش برگشت',
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
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
                  _buildHeaderCell('مشتری', 90),
                  _buildHeaderCell('شرکت', 90),
                  _buildHeaderCell('محصول', 80),
                  _buildHeaderCell('جنسیت', 50),
                  _buildHeaderCell('سایز', 50),
                  _buildHeaderCell('کل خاده', 60),
                  _buildHeaderCell('برگشت (خاده)', 80),
                  _buildHeaderCell('وزن برگشت', 80),
                  _buildHeaderCell('قیمت برگشت', 80),
                  _buildHeaderCell('باقی‌مانده (خاده)', 90),
                  _buildHeaderCell('وزن باقی‌مانده', 90),
                  _buildHeaderCell('قیمت باقی‌مانده', 90),
                  _buildHeaderCell('تاریخ برگشت', 70),
                  _buildHeaderCell('عملیات', 60),
                ],
              ),
            ),
          ),
          Expanded(
            child: paged.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'هیچ برگشتی ثبت نشده است',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'برای ثبت برگشت روی دکمه "افزودن برگشت" کلیک کنید',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: paged.length,
                    itemBuilder: (context, index) {
                      final sale = paged[index];
                      final isEven = index % 2 == 0;
                      
                      String unit = sale['unit']?.toString() ?? '';
                      double returnedCount = double.tryParse(sale['returned_count']?.toString() ?? '0') ?? 0;
                      double returnedWeight = double.tryParse(sale['returned_weight']?.toString() ?? '0') ?? 0;
                      double returnedPrice = double.tryParse(sale['returned_price']?.toString() ?? '0') ?? 0;
                      double originalCount = double.tryParse(sale['original_unit_count']?.toString() ?? '0') ?? 0;
                      double remainingCount = originalCount - returnedCount;
                      double remainingWeight = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
                      double remainingPrice = double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;
                      
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
                              _buildDataCell(
                                sale['invoice_number']?.toString() ?? '-',
                                80,
                                isBold: true,
                                color: const Color(0xFFCB001D),
                              ),
                              _buildDataCell(
                                sale['customer_name']?.toString() ?? '-',
                                90,
                                isBold: true,
                              ),
                              _buildDataCell(
                                sale['customer_company']?.toString() ?? '-',
                                90,
                              ),
                              _buildDataCell(
                                sale['product_name']?.toString() ?? '-',
                                80,
                              ),
                              _buildDataCell(
                                sale['gender']?.toString() ?? '-',
                                50,
                              ),
                              _buildDataCell(
                                sale['size']?.toString() ?? '-',
                                50,
                              ),
                              _buildDataCell(
                                originalCount.toStringAsFixed(originalCount % 1 == 0 ? 0 : 2),
                                60,
                                isBold: true,
                              ),
                              _buildDataCell(
                                returnedCount.toStringAsFixed(returnedCount % 1 == 0 ? 0 : 2),
                                80,
                                isBold: true,
                                color: Colors.red,
                              ),
                              _buildDataCell(
                                _formatWeight(unit, returnedWeight),
                                80,
                                isBold: true,
                                color: Colors.red,
                              ),
                              _buildDataCell(
                                '${_formatCurrency(returnedPrice)}',
                                80,
                                isBold: true,
                                color: Colors.red,
                              ),
                              _buildDataCell(
                                remainingCount.toStringAsFixed(remainingCount % 1 == 0 ? 0 : 2),
                                90,
                                isBold: true,
                                color: Colors.green,
                              ),
                              _buildDataCell(
                                _formatWeight(unit, remainingWeight),
                                90,
                                color: Colors.green,
                              ),
                              _buildDataCell(
                                '${_formatCurrency(remainingPrice)}',
                                90,
                                color: Colors.green,
                              ),
                              _buildDataCell(
                                sale['back_return_date']?.toString() ?? '-',
                                70,
                              ),
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
          fontSize: 9,
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
          fontSize: 9,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showReturnDetailsDialog(Map<String, dynamic> sale, AppLocalizations l10n) {
    String unit = sale['unit']?.toString() ?? '';
    double returnedCount = double.tryParse(sale['returned_count']?.toString() ?? '0') ?? 0;
    double returnedWeight = double.tryParse(sale['returned_weight']?.toString() ?? '0') ?? 0;
    double returnedPrice = double.tryParse(sale['returned_price']?.toString() ?? '0') ?? 0;
    double originalCount = double.tryParse(sale['original_unit_count']?.toString() ?? '0') ?? 0;
    double remainingCount = originalCount - returnedCount;
    double remainingWeight = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
    double remainingPrice = double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;
    
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
            Text('جزئیات برگشت - ${sale['invoice_number'] ?? '-'}'),
          ],
        ),
        content: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('شماره فاکتور', sale['invoice_number']?.toString() ?? '-'),
              _buildDetailRow(l10n.customerName, sale['customer_name'] ?? '-'),
              _buildDetailRow(l10n.company, sale['customer_company'] ?? '-'),
              _buildDetailRow(l10n.productName, sale['product_name'] ?? '-'),
              _buildDetailRow('جنسیت', sale['gender'] ?? '-'),
              _buildDetailRow('سایز', sale['size'] ?? '-'),
              _buildDetailRow('ضخامت', sale['thickness'] ?? '-'),
              const Divider(),
              _buildDetailRow('کل خاده', originalCount.toStringAsFixed(originalCount % 1 == 0 ? 0 : 2), isHighlight: true),
              _buildDetailRow('تعداد برگشت', returnedCount.toStringAsFixed(returnedCount % 1 == 0 ? 0 : 2), isHighlight: true, color: Colors.red),
              _buildDetailRow('وزن برگشت', _formatWeight(unit, returnedWeight), isHighlight: true, color: Colors.red),
              _buildDetailRow('قیمت برگشت', '${_formatCurrency(returnedPrice)} ${sale['currency'] ?? ''}', isHighlight: true, color: Colors.red),
              const Divider(),
              _buildDetailRow('باقی‌مانده (خاده)', remainingCount.toStringAsFixed(remainingCount % 1 == 0 ? 0 : 2), isHighlight: true, color: Colors.green),
              _buildDetailRow('وزن باقی‌مانده', _formatWeight(unit, remainingWeight), isHighlight: true, color: Colors.green),
              _buildDetailRow('قیمت باقی‌مانده', '${_formatCurrency(remainingPrice)} ${sale['currency'] ?? ''}', isHighlight: true, color: Colors.green),
              const Divider(),
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

  Widget _buildDetailRow(String label, String value, {bool isReason = false, bool isHighlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: isHighlight ? Colors.grey.shade200 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: isHighlight ? Border.all(color: color ?? Colors.grey, width: 1) : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
                fontSize: 11,
                color: color ?? Colors.black87,
              ),
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
                  color: isReason ? Colors.orange.shade800 : (color ?? Colors.black87),
                  fontWeight: isHighlight ? FontWeight.w700 : FontWeight.normal,
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
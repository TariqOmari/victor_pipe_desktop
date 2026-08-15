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

  // Format weight for display - ALWAYS shows in tons for weight units (for total weight)
  String _formatWeightWithConversion(String unit, double weight) {
    if (_isWeightUnit(unit)) {
      double tons = _convertToTons(unit, weight);
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} $unit';
  }

  // Format raw weight - ALWAYS in KG
  String _formatRawWeight(String unit, double weight) {
    if (_isWeightUnit(unit)) {
      // Always show raw weight in kg
      return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} کیلوگرم';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} $unit';
  }

  // Format weight per unit - ALWAYS in KG
  String _formatWeightPerUnit(String unit, double weight) {
    if (_isWeightUnit(unit)) {
      return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} کیلوگرم';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} $unit';
  }

  // Get total tons of all returned sales
  double _getTotalTons() {
    double totalTons = 0;
    for (var sale in _returnedSales) {
      String unit = sale['unit']?.toString() ?? '';
      double weight = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
      
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
      total += double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;
    }
    return total;
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

      // گرفتن هدرها از ردیف اول
      final headersRow = sheet.rows.first;
      List<String> headers = [];
      for (var cell in headersRow) {
        if (cell != null && cell.value != null) {
          headers.add(cell.value.toString().trim());
        }
      }

      print('📋 Headers: $headers');

      // پیدا کردن ایندکس فیلدها
      int invoiceNumberIndex = -1;
      int customerNameIndex = -1;
      int customerCompanyIndex = -1;
      int productNameIndex = -1;
      int genderIndex = -1;
      int sizeIndex = -1;
      int thicknessIndex = -1;
      int weightIndex = -1;
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
        } else if (hLower.contains('وزن') && !hLower.contains('فی') && !hLower.contains('کل') || hLower.contains('weight')) {
          weightIndex = i;
        } else if (hLower.contains('وزن فی') || hLower.contains('weight per unit')) {
          weightPerUnitIndex = i;
        } else if (hLower.contains('تعداد') || hLower.contains('unit count')) {
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
        }
      }

      print('📋 Invoice: $invoiceNumberIndex, Customer: $customerNameIndex, Return Date: $returnDateIndex');

      if (invoiceNumberIndex == -1 || customerNameIndex == -1 || returnDateIndex == -1) {
        return {
          'success': false,
          'message': 'فیلدهای مورد نیاز پیدا نشد: شماره فاکتور، مشتری، تاریخ برگشت'
        };
      }

      // پردازش ردیف‌ها
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
          String returnDate = _getCellValueDirect(row, returnDateIndex);
          
          String customerCompany = customerCompanyIndex != -1 ? _getCellValueDirect(row, customerCompanyIndex) : '';
          String productName = productNameIndex != -1 ? _getCellValueDirect(row, productNameIndex) : '';
          String gender = genderIndex != -1 ? _getCellValueDirect(row, genderIndex) : '';
          String size = sizeIndex != -1 ? _getCellValueDirect(row, sizeIndex) : '';
          String thickness = thicknessIndex != -1 ? _getCellValueDirect(row, thicknessIndex) : '';
          String weightStr = weightIndex != -1 ? _getCellValueDirect(row, weightIndex) : '0';
          String weightPerUnitStr = weightPerUnitIndex != -1 ? _getCellValueDirect(row, weightPerUnitIndex) : '0';
          String unitCountStr = unitCountIndex != -1 ? _getCellValueDirect(row, unitCountIndex) : '0';
          String totalWeightStr = totalWeightIndex != -1 ? _getCellValueDirect(row, totalWeightIndex) : '0';
          String unit = unitIndex != -1 ? _getCellValueDirect(row, unitIndex) : 'کیلوگرم';
          String unitPriceStr = unitPriceIndex != -1 ? _getCellValueDirect(row, unitPriceIndex) : '0';
          String totalPriceStr = totalPriceIndex != -1 ? _getCellValueDirect(row, totalPriceIndex) : '0';
          String discountStr = discountIndex != -1 ? _getCellValueDirect(row, discountIndex) : '0';
          String finalPriceStr = finalPriceIndex != -1 ? _getCellValueDirect(row, finalPriceIndex) : '0';
          String currency = currencyIndex != -1 ? _getCellValueDirect(row, currencyIndex) : 'USD';
          String returnReason = returnReasonIndex != -1 ? _getCellValueDirect(row, returnReasonIndex) : '';
          String phone = customerPhoneIndex != -1 ? _getCellValueDirect(row, customerPhoneIndex) : '';
          String address = customerAddressIndex != -1 ? _getCellValueDirect(row, customerAddressIndex) : '';

          // پاک کردن علامت‌های اضافی
          weightStr = weightStr.replaceAll(RegExp(r'[$,]'), '').trim();
          weightPerUnitStr = weightPerUnitStr.replaceAll(RegExp(r'[$,]'), '').trim();
          unitCountStr = unitCountStr.replaceAll(RegExp(r'[$,]'), '').trim();
          totalWeightStr = totalWeightStr.replaceAll(RegExp(r'[$,]'), '').trim();
          unitPriceStr = unitPriceStr.replaceAll(RegExp(r'[$,]'), '').trim();
          totalPriceStr = totalPriceStr.replaceAll(RegExp(r'[$,]'), '').trim();
          discountStr = discountStr.replaceAll(RegExp(r'[$,]'), '').trim();
          finalPriceStr = finalPriceStr.replaceAll(RegExp(r'[$,]'), '').trim();

          print('📝 Row ${i+1}: Invoice="$invoiceNumber", Customer="$customerName", Return Date="$returnDate"');

          if (invoiceNumber.isEmpty || customerName.isEmpty || returnDate.isEmpty) {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': فیلدهای مورد نیاز کامل نیستند');
            continue;
          }

          double weight = _parseNumber(weightStr);
          double weightPerUnit = _parseNumber(weightPerUnitStr);
          double unitCount = _parseNumber(unitCountStr);
          double totalWeight = _parseNumber(totalWeightStr);
          double unitPrice = _parseNumber(unitPriceStr);
          double totalPrice = _parseNumber(totalPriceStr);
          double discount = _parseNumber(discountStr);
          double finalPrice = _parseNumber(finalPriceStr);

          // اگر وزن کل خالی بود محاسبه کن
          if (totalWeight <= 0 && weightPerUnit > 0 && unitCount > 0) {
            totalWeight = weightPerUnit * unitCount;
          }

          // تاریخ برگشت میلادی
          String returnDateEn = PersianDateConverter.getEnglishDate(DateTime.now());

          // ساخت داده
          Map<String, dynamic> sale = {
            'invoice_number': invoiceNumber,
            'customer_name': customerName,
            'customer_phone': phone,
            'customer_address': address,
            'customer_company': customerCompany,
            'product_name': productName,
            'gender': gender,
            'size': size,
            'thickness': thickness,
            'weight': weight.toString(),
            'weight_per_unit': weightPerUnit.toString(),
            'unit_count': unitCount.toString(),
            'total_weight': totalWeight.toString(),
            'unit': unit.isNotEmpty ? unit : 'کیلوگرم',
            'unit_price': unitPrice,
            'total_price': totalPrice > 0 ? totalPrice : finalPrice,
            'currency': currency == 'دلار' || currency == '\$' ? 'USD' : 'AFN',
            'discount': discount,
            'final_price': finalPrice > 0 ? finalPrice : totalPrice,
            'is_back_returned': 1,
            'back_return_reason': returnReason,
            'back_return_date': returnDate,
            'back_return_date_en': returnDateEn,
          };

          print('📦 Inserting: ${sale['invoice_number']}');
          
          int result = await _db.insertSalesInvoice(sale);
          if (result != -1) {
            successCount++;
            importedData.add(sale);
            print('✅ Row ${i+1} imported!');
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
                        _buildReadOnlyField(
                          'وزن فی خاده', 
                          _formatWeightPerUnit(
                            selectedSale!['unit']?.toString() ?? '',
                            double.tryParse(selectedSale!['weight_per_unit']?.toString() ?? '0') ?? 0
                          ), 
                          l10n
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyField(
                          'وزن کل', 
                          _formatWeightWithConversion(
                            selectedSale!['unit']?.toString() ?? '',
                            double.tryParse(selectedSale!['total_weight']?.toString() ?? '0') ?? 0
                          ), 
                          l10n
                        ),
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
                          final productId = selectedSale!['produced_product_id'];
                          final totalWeight = double.tryParse(selectedSale!['total_weight']?.toString() ?? '0') ?? 0;
                          final unit = selectedSale!['unit']?.toString() ?? '';
                          
                          if (productId != null && totalWeight > 0) {
                            final stockRestored = await _db.addProductStock(
                              productId,
                              totalWeight,
                              unit
                            );
                            if (!stockRestored) {
                              _showSnackbar('⚠️ خطا در بازگرداندن موجودی به انبار', Colors.orange);
                            } else {
                              _showSnackbar('✅ موجودی به انبار بازگردانده شد', Colors.green);
                            }
                          }

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

  Future<void> _generatePdfReturnInvoice(Map<String, dynamic> invoice, String invoiceNumber, AppLocalizations l10n) async {
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    String unit = invoice['unit']?.toString() ?? '';
    double weightRaw = double.tryParse(invoice['weight']?.toString() ?? '0') ?? 0;
    double weightPerUnitRaw = double.tryParse(invoice['weight_per_unit']?.toString() ?? '0') ?? 0;
    double totalWeightRaw = double.tryParse(invoice['total_weight']?.toString() ?? '0') ?? 0;
    
    // وزن - always in kg
    String displayWeight = _formatRawWeight(unit, weightRaw);
    // وزن فی خاده - always in kg
    String displayWeightPerUnit = _formatWeightPerUnit(unit, weightPerUnitRaw);
    // وزن کل - always in tons
    String displayTotalWeight = _formatWeightWithConversion(unit, totalWeightRaw);

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
                  headers: [
                    l10n.customerName, l10n.company, l10n.productName, 
                    l10n.gender, l10n.size, 'وزن (kg)', 
                    'وزن فی خاده (kg)', 'تعداد خاده', 'وزن کل (ton)', 
                    l10n.finalPrice
                  ],
                  data: [
                    [
                      invoice['customer_name'] ?? '-',
                      invoice['customer_company'] ?? '-',
                      invoice['product_name'] ?? '-',
                      invoice['gender'] ?? '-',
                      invoice['size'] ?? '-',
                      displayWeight,
                      displayWeightPerUnit,
                      invoice['unit_count']?.toString() ?? '-',
                      displayTotalWeight,
                      '${_formatCurrency(invoice['final_price'])} ${invoice['currency'] ?? ''}',
                    ],
                  ],
                  headerStyle: pw.TextStyle(font: ttf, fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
                  cellStyle: pw.TextStyle(font: ttf, fontSize: 8),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
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
      double price = double.tryParse(sale['final_price']?.toString() ?? '0') ?? 0;
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
                        'مجموع وزن (تن)',
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
                        'مجموع ارزش',
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
                  _buildHeaderCell('مشتری', 100),
                  _buildHeaderCell('شرکت', 100),
                  _buildHeaderCell('محصول', 90),
                  _buildHeaderCell('جنسیت', 60),
                  _buildHeaderCell('سایز', 60),
                  _buildHeaderCell('ضخامت', 60),
                  _buildHeaderCell('وزن (kg)', 75),
                  _buildHeaderCell('وزن فی (kg)', 85),
                  _buildHeaderCell('تعداد', 60),
                  _buildHeaderCell('وزن کل (ton)', 85),
                  _buildHeaderCell('قیمت واحد', 80),
                  _buildHeaderCell('قیمت کل', 80),
                  _buildHeaderCell('تخفیف', 60),
                  _buildHeaderCell('قیمت نهایی', 80),
                  _buildHeaderCell('تاریخ برگشت', 80),
                  _buildHeaderCell('دلیل برگشت', 90),
                  _buildHeaderCell('عملیات', 70),
                ],
              ),
            ),
          ),
          Expanded(
            child: paged.isEmpty
                ? Center(child: Text(l10n.noReturnedSales, style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: paged.length,
                    itemBuilder: (context, index) {
                      final sale = paged[index];
                      final isEven = index % 2 == 0;
                      
                      String unit = sale['unit']?.toString() ?? '';
                      double weightRaw = double.tryParse(sale['weight']?.toString() ?? '0') ?? 0;
                      double weightPerUnitRaw = double.tryParse(sale['weight_per_unit']?.toString() ?? '0') ?? 0;
                      double totalWeightRaw = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
                      
                      // وزن - always in kg
                      String displayWeight = _formatRawWeight(unit, weightRaw);
                      // وزن فی خاده - always in kg
                      String displayWeightPerUnit = _formatWeightPerUnit(unit, weightPerUnitRaw);
                      // وزن کل - always in tons
                      String displayTotalWeight = _formatWeightWithConversion(unit, totalWeightRaw);
                      
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
                                100,
                                isBold: true,
                              ),
                              _buildDataCell(
                                sale['customer_company']?.toString() ?? '-',
                                100,
                              ),
                              _buildDataCell(
                                sale['product_name']?.toString() ?? '-',
                                90,
                              ),
                              _buildDataCell(
                                sale['gender']?.toString() ?? '-',
                                60,
                              ),
                              _buildDataCell(
                                sale['size']?.toString() ?? '-',
                                60,
                              ),
                              _buildDataCell(
                                sale['thickness']?.toString() ?? '-',
                                60,
                              ),
                              _buildDataCell(
                                displayWeight,
                                75,
                                isBold: true,
                              ),
                              _buildDataCell(
                                displayWeightPerUnit,
                                85,
                              ),
                              _buildDataCell(
                                sale['unit_count']?.toString() ?? '-',
                                60,
                              ),
                              _buildDataCell(
                                displayTotalWeight,
                                85,
                                isBold: true,
                                color: const Color(0xFFCB001D),
                              ),
                              _buildDataCell(
                                _formatCurrency(sale['unit_price']),
                                80,
                              ),
                              _buildDataCell(
                                _formatCurrency(sale['total_price']),
                                80,
                              ),
                              _buildDataCell(
                                _formatCurrency(sale['discount']),
                                60,
                              ),
                              _buildDataCell(
                                '${_formatCurrency(sale['final_price'])} ${sale['currency'] ?? ''}',
                                80,
                                isBold: true,
                                color: const Color(0xFFCB001D),
                              ),
                              _buildDataCell(
                                sale['back_return_date']?.toString() ?? '-',
                                80,
                              ),
                              Container(
                                width: 90,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Text(
                                  sale['back_return_reason']?.toString() ?? '-',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
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
          fontSize: 10,
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
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showReturnDetailsDialog(Map<String, dynamic> sale, AppLocalizations l10n) {
    String unit = sale['unit']?.toString() ?? '';
    double weightRaw = double.tryParse(sale['weight']?.toString() ?? '0') ?? 0;
    double weightPerUnitRaw = double.tryParse(sale['weight_per_unit']?.toString() ?? '0') ?? 0;
    double totalWeightRaw = double.tryParse(sale['total_weight']?.toString() ?? '0') ?? 0;
    
    // وزن - always in kg
    String displayWeight = _formatRawWeight(unit, weightRaw);
    // وزن فی خاده - always in kg
    String displayWeightPerUnit = _formatWeightPerUnit(unit, weightPerUnitRaw);
    // وزن کل - always in tons
    String displayTotalWeight = _formatWeightWithConversion(unit, totalWeightRaw);
    
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
            Text('${l10n.returnedSales} - ${sale['invoice_number'] ?? '-'}'),
          ],
        ),
        content: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('شماره بل', sale['invoice_number']?.toString() ?? '-'),
              _buildDetailRow(l10n.customerName, sale['customer_name'] ?? '-'),
              _buildDetailRow(l10n.company, sale['customer_company'] ?? '-'),
              _buildDetailRow(l10n.productName, sale['product_name'] ?? '-'),
              _buildDetailRow(l10n.gender, sale['gender'] ?? '-'),
              _buildDetailRow(l10n.size, sale['size'] ?? '-'),
              _buildDetailRow('ضخامت', sale['thickness'] ?? '-'),
              _buildDetailRow('وزن (kg)', displayWeight),
              _buildDetailRow('وزن فی خاده (kg)', displayWeightPerUnit),
              _buildDetailRow('تعداد خاده', sale['unit_count']?.toString() ?? '-'),
              _buildDetailRow('وزن کل (ton)', displayTotalWeight),
              _buildDetailRow('واحد', sale['unit']?.toString() ?? '-'),
              _buildDetailRow(l10n.finalPrice, '${_formatCurrency(sale['final_price'])} ${sale['currency'] ?? ''}'),
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

  Widget _buildDetailRow(String label, String value, {bool isReason = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
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
                  color: isReason ? Colors.orange.shade800 : Colors.black87,
                  fontWeight: isReason ? FontWeight.w500 : FontWeight.normal,
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
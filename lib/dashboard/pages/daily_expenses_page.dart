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

class DailyExpensesPage extends StatefulWidget {
  const DailyExpensesPage({super.key});

  @override
  State<DailyExpensesPage> createState() => _DailyExpensesPageState();
}

class _DailyExpensesPageState extends State<DailyExpensesPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  final List<Map<String, dynamic>> _expensesData = [];

  String _searchQuery = '';
  String _selectedCategory = 'همه';
  DateTime? _selectedDate;
  String _selectedCurrency = 'همه';

  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _registrationNumberController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController();
  final TextEditingController _exchangeRateController = TextEditingController();
  final TextEditingController _equivalentController = TextEditingController();

  final List<String> _categories = [
    'همه',
    'سوخت',
    'مواد اولیه',
    'حقوق کارگران',
    'تعمیرات',
    'حمل و نقل',
    'سایر',
  ];

  final List<String> _currencies = [
    'همه',
    'افغانی',
    'دالر',
    'یورو',
  ];

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _registrationNumberController.dispose();
    _dateController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _exchangeRateController.dispose();
    _equivalentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  // ============================================================
  // LOAD EXPENSES
  // ============================================================
  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getDailyExpenses();
      if (!mounted) return;
      setState(() {
        _expensesData.clear();
        for (final r in list) {
          double price = 0.0;
          if (r['price'] is int) {
            price = (r['price'] as int).toDouble();
          } else if (r['price'] is double) {
            price = r['price'] as double;
          } else if (r['price'] is String) {
            price = double.tryParse(r['price'].toString()) ?? 0.0;
          } else {
            price = double.tryParse(r['price']?.toString() ?? '0') ?? 0.0;
          }
          
          int usdEquivalent = 0;
          if (r['usd_equivalent'] is int) {
            usdEquivalent = r['usd_equivalent'] as int;
          } else if (r['usd_equivalent'] is double) {
            usdEquivalent = (r['usd_equivalent'] as double).round();
          } else {
            usdEquivalent = int.tryParse(r['usd_equivalent']?.toString() ?? '0') ?? 0;
          }

          int afnEquivalent = 0;
          if (r['afn_equivalent'] is int) {
            afnEquivalent = r['afn_equivalent'] as int;
          } else if (r['afn_equivalent'] is double) {
            afnEquivalent = (r['afn_equivalent'] as double).round();
          } else {
            afnEquivalent = int.tryParse(r['afn_equivalent']?.toString() ?? '0') ?? 0;
          }
          
          _expensesData.add({
            'id': r['id'],
            'invoiceNumber': r['invoice_number'] ?? '-',
            'registrationNumber': r['registration_number'] ?? '-',
            'date': r['date'] ?? '',
            'date_en': r['date_en'] ?? '',
            'category': r['category'] ?? 'سایر',
            'description': r['description'] ?? '',
            'price': price,
            'currency': r['currency'] ?? 'افغانی',
            'exchangeRate': double.tryParse(r['exchange_rate']?.toString() ?? '1') ?? 1.0,
            'usdEquivalent': usdEquivalent,
            'afnEquivalent': afnEquivalent,
          });
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackBar(l10n.errorLoadingExpenses, Colors.red);
    }
  }

  // ============================================================
  // HELPER: Detect Currency Type
  // ============================================================
  bool _isUSD(String? currency) {
    if (currency == null) return false;
    final c = currency.trim().toLowerCase();
    return c == 'usd' || 
           c == 'دالر' || 
           c == 'دلار' || 
           c == '\$' ||
           c.contains('usd') ||
           c.contains('دالر') ||
           c.contains('دلار');
  }

  bool _isAFN(String? currency) {
    if (currency == null) return false;
    final c = currency.trim().toLowerCase();
    return c == 'afn' || 
           c == 'افغانی' || 
           c == 'افغاني' || 
           c.contains('afn') ||
           c.contains('افغانی') ||
           c.contains('افغاني');
  }

  // ============================================================
  // HELPER: Persian Date Conversion
  // ============================================================
  int _getPersianMonthDays(int month, int year) {
    const List<int> daysInMonth = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29];
    if (month == 12 && _isPersianLeapYear(year)) {
      return 30;
    }
    return daysInMonth[month - 1];
  }

  bool _isPersianLeapYear(int year) {
    int mod = year % 33;
    return mod == 1 || mod == 5 || mod == 9 || mod == 13 || 
           mod == 17 || mod == 22 || mod == 26 || mod == 30;
  }

  String _convertPersianToEnglish(int persianYear, int persianMonth, int persianDay) {
    try {
      DateTime refDate = DateTime(2021, 3, 21);
      int refYear = 1400;
      int refMonth = 1;
      int refDay = 1;
      
      int daysDiff = 0;
      
      for (int y = refYear; y < persianYear; y++) {
        daysDiff += _isPersianLeapYear(y) ? 366 : 365;
      }
      
      for (int m = 1; m < persianMonth; m++) {
        daysDiff += _getPersianMonthDays(m, persianYear);
      }
      
      daysDiff += (persianDay - refDay);
      
      DateTime result = refDate.add(Duration(days: daysDiff));
      return '${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error in _convertPersianToEnglish: $e');
      return PersianDateConverter.getCurrentEnglishDate();
    }
  }

  // ============================================================
  // EXCEL IMPORT
  // ============================================================
  Future<void> _importExcel() async {
    final l10n = AppLocalizations.of(context)!;
    
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
        await _loadExpenses();
      } else {
        _showSnackBar(result['message'] ?? 'خطا در وارد کردن فایل', Colors.red);
      }
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('خطا در وارد کردن: $e', Colors.red);
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

  String _getCellValue(List<excel.Data?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    final cell = row[index];
    if (cell == null) return '';
    if (cell.value == null) return '';
    
    String value;
    if (cell.value is String) {
      value = (cell.value as String).trim();
    } else if (cell.value is num) {
      num val = cell.value as num;
      if (val is double) {
        if (val == val.roundToDouble()) {
          value = val.round().toString();
        } else {
          value = val.toString();
        }
      } else {
        value = val.toInt().toString();
      }
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

  // ============================================================
  // PARSE EXCEL SHEET
  // ============================================================
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
      int registrationNumberIndex = -1;
      int dateIndex = -1;
      int categoryIndex = -1;
      int descriptionIndex = -1;
      int priceIndex = -1;
      int currencyIndex = -1;
      int exchangeRateIndex = -1;
      int usdEquivalentIndex = -1;

      for (int i = 0; i < headers.length; i++) {
        String h = headers[i].trim();
        
        if (h == 'شماره بل' || h.contains('نمبر بل')) {
          invoiceNumberIndex = i;
        } else if (h == 'شماره ثبت' || h.contains('شماره ثبت')) {
          registrationNumberIndex = i;
        } else if (h == 'تاریخ' || h.contains('تاریخ')) {
          dateIndex = i;
        } else if (h == 'كتگوری' || h == 'کتگوری' || h.contains('کتگوری') || h.contains('كتگوری')) {
          categoryIndex = i;
        } else if (h == 'توضیحات' || h.contains('توضیحات')) {
          descriptionIndex = i;
        } else if (h == 'قیمت' || h.contains('قیمت')) {
          priceIndex = i;
        } else if (h == 'واحد پول' || h.contains('واحد پول')) {
          currencyIndex = i;
        } else if (h == 'نرخ تبدیل' || h.contains('نرخ تبدیل')) {
          exchangeRateIndex = i;
        } else if (h == 'معادل دلاری' || h.contains('معادل دلاری')) {
          usdEquivalentIndex = i;
        }
      }

      print('📍 Column Indices:');
      print('  - Date Column: $dateIndex');
      print('  - Price Column: $priceIndex');
      print('  - Currency Column: $currencyIndex');
      print('  - Exchange Rate Column: $exchangeRateIndex');

      if (dateIndex == -1) {
        return {'success': false, 'message': 'ستون تاریخ پیدا نشد'};
      }
      if (priceIndex == -1) {
        return {'success': false, 'message': 'ستون قیمت پیدا نشد'};
      }

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        
        bool hasData = false;
        for (var cell in row) {
          if (cell != null && cell.value != null) {
            String val = cell.value.toString().trim();
            if (val.isNotEmpty && val != '0') {
              hasData = true;
              break;
            }
          }
        }
        if (!hasData) continue;

        try {
          String invoiceNumber = invoiceNumberIndex != -1 ? _getCellValue(row, invoiceNumberIndex) : '';
          String registrationNumber = registrationNumberIndex != -1 ? _getCellValue(row, registrationNumberIndex) : '';
          
          String dateStr = _getCellValue(row, dateIndex);
          String category = categoryIndex != -1 ? _getCellValue(row, categoryIndex) : 'سایر';
          String description = descriptionIndex != -1 ? _getCellValue(row, descriptionIndex) : '';
          String priceStr = _getCellValue(row, priceIndex);
          
          String currency = 'افغانی';
          if (currencyIndex != -1) {
            String currencyVal = _getCellValue(row, currencyIndex);
            if (currencyVal.isNotEmpty) {
              currency = currencyVal;
            }
          }
          
          String exchangeRateStr = '64.8';
          if (exchangeRateIndex != -1) {
            String rateVal = _getCellValue(row, exchangeRateIndex);
            if (rateVal.isNotEmpty) {
              exchangeRateStr = rateVal;
            }
          }

          print('📝 Row ${i+1}:');
          print('  - Date RAW: "$dateStr"');
          print('  - Price RAW: "$priceStr"');
          print('  - Currency: "$currency"');
          print('  - Exchange Rate: "$exchangeRateStr"');

          if ((invoiceNumber.isEmpty && registrationNumber.isEmpty) || 
              dateStr.isEmpty || 
              priceStr.isEmpty) {
            skippedCount++;
            errors.add('ردیف ${i+1}: داده‌ها کامل نیستند');
            continue;
          }

          String persianDate = '';
          String englishDate = '';
          
          dateStr = dateStr.replaceAll(RegExp(r'[^0-9\-]'), '');
          
          bool isPersianDate = false;
          try {
            List<String> parts = dateStr.split('-');
            if (parts.length == 3) {
              int year = int.parse(parts[0]);
              if (year > 1000 && year < 1500) {
                isPersianDate = true;
              }
            }
          } catch (e) {
            isPersianDate = false;
          }

          if (isPersianDate) {
            persianDate = dateStr;
            try {
              List<String> parts = dateStr.split('-');
              int persianYear = int.parse(parts[0]);
              int persianMonth = int.parse(parts[1]);
              int persianDay = int.parse(parts[2]);
              
              englishDate = _convertPersianToEnglish(persianYear, persianMonth, persianDay);
            } catch (e) {
              englishDate = PersianDateConverter.getCurrentEnglishDate();
            }
          } else {
            englishDate = dateStr;
            try {
              DateTime dateTime = DateTime.parse(dateStr);
              persianDate = PersianDateConverter.gregorianToJalali(dateTime);
            } catch (e) {
              persianDate = PersianDateConverter.getCurrentPersianDate();
            }
          }

          if (persianDate.isEmpty) {
            persianDate = PersianDateConverter.getCurrentPersianDate();
          }
          if (englishDate.isEmpty) {
            englishDate = PersianDateConverter.getCurrentEnglishDate();
          }

          double price = _parseNumber(priceStr);
          double exchangeRate = _parseNumber(exchangeRateStr);
          
          if (exchangeRate <= 0) exchangeRate = 64.8;

          if (price <= 0) {
            skippedCount++;
            errors.add('ردیف ${i+1}: قیمت نامعتبر (قیمت: "$priceStr")');
            continue;
          }

          // Check for duplicates
          final existing = await _db.getDailyExpenses();
          bool duplicate = false;
          String duplicateField = '';
          
          if (invoiceNumber.isNotEmpty) {
            duplicate = existing.any((e) => e['invoice_number'] == invoiceNumber);
            if (duplicate) duplicateField = 'شماره بل';
          }
          
          if (!duplicate && registrationNumber.isNotEmpty) {
            duplicate = existing.any((e) => e['registration_number'] == registrationNumber);
            if (duplicate) duplicateField = 'شماره ثبت';
          }
          
          if (duplicate) {
            skippedCount++;
            errors.add('ردیف ${i+1}: $duplicateField تکراری است');
            continue;
          }

          // ✅ DB function computes both equivalents from currency + price + rate
          Map<String, dynamic> expense = {
            'invoice_number': invoiceNumber.isNotEmpty ? invoiceNumber : null,
            'registration_number': registrationNumber.isNotEmpty ? registrationNumber : null,
            'date': persianDate,
            'date_en': englishDate,
            'category': category.isNotEmpty ? category : 'سایر',
            'description': description,
            'price': price,
            'currency': currency.isNotEmpty ? currency : 'افغانی',
            'exchange_rate': exchangeRate,
          };

          int result = await _db.insertDailyExpense(expense);
          if (result != -1) {
            successCount++;
            importedData.add(expense);
          } else {
            skippedCount++;
            errors.add('ردیف ${i+1}: خطا در ذخیره‌سازی');
          }

        } catch (e) {
          skippedCount++;
          errors.add('ردیف ${i+1}: خطا - $e');
          print('❌ Error on row ${i+1}: $e');
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
      print('❌ Error processing file: $e');
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

  // ============================================================
  // ADD EXPENSE
  // ============================================================
  Future<void> _addExpense() async {
    final l10n = AppLocalizations.of(context)!;
    _invoiceNumberController.clear();
    _registrationNumberController.clear();
    _dateController.clear();
    _categoryController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _currencyController.clear();
    _exchangeRateController.clear();
    _equivalentController.clear();
    
    String? selectedEnglishDate;
    String selectedCurrency = 'افغانی';
    String selectedPersianDate = '';
    
    void updateEquivalent() {
      final price = double.tryParse(_priceController.text) ?? 0;
      final rate = double.tryParse(_exchangeRateController.text) ?? 1;
      
      if (_isAFN(selectedCurrency)) {
        _equivalentController.text = rate > 0 ? (price / rate).toStringAsFixed(2) : '0';
      } else if (_isUSD(selectedCurrency)) {
        _equivalentController.text = (price * rate).toStringAsFixed(0);
      } else {
        _equivalentController.text = '0';
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              l10n.addNewExpense,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF1A1A1A),
              ),
            ),
            content: SizedBox(
              width: 650,
              height: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: _invoiceNumberController,
                      label: 'شماره بل',
                      icon: Icons.receipt_outlined,
                      hint: 'شماره بل را وارد کنید',
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _registrationNumberController,
                      label: 'شماره ثبت',
                      icon: Icons.numbers_outlined,
                      hint: 'شماره ثبت را وارد کنید',
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: l10n.persianDate,
                        suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 18),
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          String persianDate = PersianDateConverter.gregorianToJalali(picked);
                          String englishDate = PersianDateConverter.getEnglishDate(picked);
                          setDialogState(() {
                            _dateController.text = persianDate;
                            selectedPersianDate = persianDate;
                            selectedEnglishDate = englishDate;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _categoryController,
                      label: l10n.category,
                      icon: Icons.category_outlined,
                      hint: l10n.categoryHint,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descriptionController,
                      label: l10n.description,
                      icon: Icons.description_outlined,
                      hint: l10n.descriptionHint,
                      maxLines: 2,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _priceController,
                      label: l10n.price,
                      icon: Icons.money_outlined,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(updateEquivalent),
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.currency_exchange_outlined, color: const Color(0xFFCB001D), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedCurrency,
                                      isExpanded: true,
                                      items: ['افغانی', 'دالر', 'یورو'].map((item) {
                                        return DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(item),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() {
                                            selectedCurrency = value;
                                            updateEquivalent();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _exchangeRateController,
                            label: _isAFN(selectedCurrency) 
                                ? 'نرخ ارز (AFN به USD) *' 
                                : 'نرخ ارز (USD به AFN) *',
                            icon: Icons.trending_up_outlined,
                            hint: _isAFN(selectedCurrency) ? '0.015' : '66',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(updateEquivalent),
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _equivalentController,
                      label: _isAFN(selectedCurrency) 
                          ? 'معادل به دالر (USD)' 
                          : 'معادل به افغانی (AFN)',
                      icon: Icons.attach_money_outlined,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      readOnly: true,
                      l10n: l10n,
                    ),
                  ],
                ),
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_invoiceNumberController.text.isEmpty && _registrationNumberController.text.isEmpty) {
                    _showSnackBar('لطفاً شماره بل یا شماره ثبت را وارد کنید', Colors.red);
                    return;
                  }
                  if (_dateController.text.isEmpty) {
                    _showSnackBar(l10n.pleaseEnterDate, Colors.red);
                    return;
                  }
                  if (_priceController.text.isEmpty) {
                    _showSnackBar(l10n.pleaseEnterPrice, Colors.red);
                    return;
                  }

                  Navigator.of(context).pop();
                  final price = double.tryParse(_priceController.text) ?? 0;
                  final rate = double.tryParse(_exchangeRateController.text) ?? 1;

                  String persianDate = _dateController.text;
                  String englishDate = selectedEnglishDate ?? PersianDateConverter.getCurrentEnglishDate();

                  final insertPayload = {
                    'invoice_number': _invoiceNumberController.text.isNotEmpty ? _invoiceNumberController.text.trim() : null,
                    'registration_number': _registrationNumberController.text.isNotEmpty ? _registrationNumberController.text.trim() : null,
                    'date': persianDate,
                    'date_en': englishDate,
                    'category': _categoryController.text.isNotEmpty ? _categoryController.text : 'سایر',
                    'description': _descriptionController.text,
                    'price': price,
                    'currency': selectedCurrency,
                    'exchange_rate': rate,
                  };

                  final id = await _db.insertDailyExpense(insertPayload);
                  if (id != -1) {
                    await _loadExpenses();
                    _showSnackBar(l10n.expenseAddedSuccess, Colors.green);
                  } else {
                    _showSnackBar('شماره بل یا شماره ثبت تکراری است یا خطایی رخ داد', Colors.red);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCB001D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.addExpense),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // EDIT EXPENSE
  // ============================================================
  void _editExpense(Map<String, dynamic> expense) {
    final l10n = AppLocalizations.of(context)!;
    _invoiceNumberController.text = expense['invoiceNumber'] ?? '';
    _registrationNumberController.text = expense['registrationNumber'] ?? '';
    _dateController.text = expense['date'] ?? '';
    _categoryController.text = expense['category'] ?? '';
    _descriptionController.text = expense['description'] ?? '';
    _priceController.text = expense['price'].toString();
    String selectedCurrency = expense['currency'] ?? 'افغانی';
    _exchangeRateController.text = expense['exchangeRate'].toString();
    _equivalentController.text = expense['usdEquivalent'].toString();

    String? selectedEnglishDate = expense['date_en'];
    
    void updateEquivalent() {
      final price = double.tryParse(_priceController.text) ?? 0;
      final rate = double.tryParse(_exchangeRateController.text) ?? 1;
      
      if (_isAFN(selectedCurrency)) {
        _equivalentController.text = rate > 0 ? (price / rate).toStringAsFixed(2) : '0';
      } else if (_isUSD(selectedCurrency)) {
        _equivalentController.text = (price * rate).toStringAsFixed(0);
      } else {
        _equivalentController.text = '0';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              l10n.editExpense,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF1A1A1A),
              ),
            ),
            content: SizedBox(
              width: 650,
              height: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      controller: _invoiceNumberController,
                      label: 'شماره بل',
                      icon: Icons.receipt_outlined,
                      hint: 'شماره بل را وارد کنید',
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _registrationNumberController,
                      label: 'شماره ثبت',
                      icon: Icons.numbers_outlined,
                      hint: 'شماره ثبت را وارد کنید',
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: l10n.persianDate,
                        suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 18),
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          String persianDate = PersianDateConverter.gregorianToJalali(picked);
                          String englishDate = PersianDateConverter.getEnglishDate(picked);
                          setDialogState(() {
                            _dateController.text = persianDate;
                            selectedEnglishDate = englishDate;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _categoryController,
                      label: l10n.category,
                      icon: Icons.category_outlined,
                      hint: l10n.categoryHint,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descriptionController,
                      label: l10n.description,
                      icon: Icons.description_outlined,
                      maxLines: 2,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _priceController,
                      label: l10n.price,
                      icon: Icons.money_outlined,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(updateEquivalent),
                      l10n: l10n,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.currency_exchange_outlined, color: const Color(0xFFCB001D), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedCurrency,
                                      isExpanded: true,
                                      items: ['افغانی', 'دالر', 'یورو'].map((item) {
                                        return DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(item),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() {
                                            selectedCurrency = value;
                                            updateEquivalent();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _exchangeRateController,
                            label: _isAFN(selectedCurrency) 
                                ? 'نرخ ارز (AFN به USD) *' 
                                : 'نرخ ارز (USD به AFN) *',
                            icon: Icons.trending_up_outlined,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(updateEquivalent),
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _equivalentController,
                      label: _isAFN(selectedCurrency) 
                          ? 'معادل به دالر (USD)' 
                          : 'معادل به افغانی (AFN)',
                      icon: Icons.attach_money_outlined,
                      keyboardType: TextInputType.number,
                      readOnly: true,
                      l10n: l10n,
                    ),
                  ],
                ),
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_invoiceNumberController.text.isEmpty && _registrationNumberController.text.isEmpty) {
                    _showSnackBar('لطفاً شماره بل یا شماره ثبت را وارد کنید', Colors.red);
                    return;
                  }
                  if (_dateController.text.isEmpty) {
                    _showSnackBar(l10n.pleaseEnterDate, Colors.red);
                    return;
                  }

                  final price = double.tryParse(_priceController.text) ?? 0;
                  final rate = double.tryParse(_exchangeRateController.text) ?? 1;

                  final payload = {
                    'invoice_number': _invoiceNumberController.text.isNotEmpty ? _invoiceNumberController.text.trim() : null,
                    'registration_number': _registrationNumberController.text.isNotEmpty ? _registrationNumberController.text.trim() : null,
                    'date': _dateController.text,
                    'date_en': selectedEnglishDate ?? PersianDateConverter.getEnglishDate(DateTime.now()),
                    'category': _categoryController.text.isNotEmpty ? _categoryController.text : 'سایر',
                    'description': _descriptionController.text,
                    'price': price,
                    'currency': selectedCurrency,
                    'exchange_rate': rate,
                  };

                  final res = await _db.updateDailyExpense(expense['id'] as int, payload);
                  if (res != -1) {
                    await _loadExpenses();
                    Navigator.pop(context);
                    _showSnackBar(l10n.expenseUpdatedSuccess, Colors.blue);
                  } else {
                    _showSnackBar('شماره بل یا شماره ثبت تکراری است یا خطایی رخ داد', Colors.red);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCB001D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.saveChanges),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteExpense(Map<String, dynamic> expense) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.deleteExpense,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          '${l10n.deleteConfirmation} "${expense['invoiceNumber'] ?? expense['registrationNumber']}"؟',
          style: const TextStyle(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _db.deleteDailyExpense(expense['id'] as int).then((res) async {
                if (res != -1) {
                  await _loadExpenses();
                  _showSnackBar(l10n.expenseDeletedSuccess, Colors.red);
                } else {
                  _showSnackBar(l10n.errorDeletingExpense, Colors.red);
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppLocalizations l10n,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: const Color(0xFFCB001D), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final filteredData = _expensesData.where((expense) {
      final matchesSearch = 
        (expense['invoiceNumber'] ?? '').toString().contains(_searchQuery) ||
        (expense['registrationNumber'] ?? '').toString().contains(_searchQuery) ||
        (expense['description'] ?? '').toString().contains(_searchQuery) ||
        (expense['category'] ?? '').toString().contains(_searchQuery);
      final matchesCategory = _selectedCategory == 'همه' ||
          expense['category'] == _selectedCategory;
      final matchesCurrency = _selectedCurrency == 'همه' ||
          expense['currency'] == _selectedCurrency;
      return matchesSearch && matchesCategory && matchesCurrency;
    }).toList();

    final totalPrice = filteredData.fold<double>(
      0.0,
      (sum, expense) => sum + (expense['price'] as double),
    );
    final totalUsd = filteredData.fold<int>(
      0,
      (sum, expense) => sum + (expense['usdEquivalent'] as int),
    );

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
              _buildHeader(totalPrice, totalUsd, l10n),
              const SizedBox(height: 24),
              _buildQuickStats(l10n),
              const SizedBox(height: 24),
              _buildFilterAndSearch(l10n),
              const SizedBox(height: 20),
              Expanded(child: _buildExpensesTable(filteredData, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD HEADER
  // ============================================================
  Widget _buildHeader(double totalPrice, int totalUsd, AppLocalizations l10n) {
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
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFFCB001D),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dailyExpensesManagement,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${l10n.totalAmount}: ${totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} ${l10n.afghani}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB001D).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${l10n.usdEquivalent}: ${totalUsd.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} \$',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFCB001D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
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
              onPressed: _addExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                l10n.addNewExpense,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // BUILD QUICK STATS
  // ============================================================
  Widget _buildQuickStats(AppLocalizations l10n) {
    final totalExpenses = _expensesData.length;
    final totalAmount = _expensesData.fold<double>(
      0.0,
      (sum, expense) => sum + (expense['price'] as double),
    );
    final totalUsd = _expensesData.fold<int>(
      0,
      (sum, expense) => sum + (expense['usdEquivalent'] as int),
    );
    final todayExpenses = _expensesData.where(
      (e) => e['date'] == PersianDateConverter.getCurrentPersianDate(),
    ).length;

    return Row(
      children: [
        _buildStatCard(
          title: l10n.totalExpenses,
          value: totalExpenses.toString(),
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFFCB001D),
          subtitle: l10n.totalRecords,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: l10n.totalAmount,
          value: totalAmount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          ),
          icon: Icons.money_outlined,
          color: Colors.blue.shade700,
          subtitle: l10n.afghani,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: l10n.usdEquivalent,
          value: totalUsd.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          ),
          icon: Icons.attach_money_outlined,
          color: Colors.green.shade700,
          subtitle: l10n.usd,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: l10n.todayExpenses,
          value: todayExpenses.toString(),
          icon: Icons.today_outlined,
          color: Colors.orange.shade700,
          subtitle: l10n.recordedToday,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndSearch(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: l10n.searchExpenses,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCB001D), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterDropdown(
              value: _selectedCategory,
              items: _categories,
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
              label: l10n.category,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterDropdown(
              value: _selectedCurrency,
              items: _currencies,
              onChanged: (value) {
                setState(() => _selectedCurrency = value!);
              },
              label: l10n.currency,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD EXPENSES TABLE
  // ============================================================
  Widget _buildExpensesTable(List<Map<String, dynamic>> data, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 1, child: Text('شماره بل', style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('شماره ثبت', style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.persianDate, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.englishDate, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.category, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text(l10n.description, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.price, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text(l10n.currency, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text(l10n.exchangeRate, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('معادل دالری', style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text('معادل افغانی', style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(flex: 1, child: Text(l10n.actions, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
              ],
            ),
          ),
          Expanded(
            child: data.isEmpty
                ? Center(
                    child: Text(
                      l10n.noExpensesFound,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final expense = data[index];
                      return _buildTableRow(expense, l10n);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD TABLE ROW
  // ============================================================
  Widget _buildTableRow(Map<String, dynamic> expense, AppLocalizations l10n) {
    double price = expense['price'] is double ? expense['price'] as double : 0.0;
    String priceDisplay = price.toStringAsFixed(0);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              expense['invoiceNumber'] ?? '-',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['registrationNumber'] ?? '-',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['date'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['date_en'] ?? '-',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getCategoryColor(expense['category']).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                expense['category'] ?? 'سایر',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getCategoryColor(expense['category']),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              expense['description'] ?? '-',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF333333),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              priceDisplay.replaceAllMapped(
                RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]},',
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['currency'] ?? 'افغانی',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expense['exchangeRate'].toString(),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // ✅ USD equivalent — show only if currency is AFN
          Expanded(
            flex: 1,
            child: _isAFN(expense['currency'])
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      expense['usdEquivalent'].toString().replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  )
                : const Center(
                    child: Text(
                      '-',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
          // ✅ AFN equivalent — show only if currency is USD
          Expanded(
            flex: 1,
            child: _isUSD(expense['currency'])
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      expense['afnEquivalent'].toString().replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  )
                : const Center(
                    child: Text(
                      '-',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _editExpense(expense),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: Colors.grey.shade600,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _deleteExpense(expense),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.grey.shade600,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'سوخت':
        return Colors.orange.shade700;
      case 'مواد اولیه':
        return Colors.blue.shade700;
      case 'حقوق کارگران':
        return Colors.purple.shade700;
      case 'تعمیرات':
        return Colors.red.shade700;
      case 'حمل و نقل':
        return Colors.green.shade700;
      case 'سایر':
        return Colors.grey.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}
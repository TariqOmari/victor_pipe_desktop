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
  int _currentPage = 1;
  int _rowsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50];
  final Set<int> _selectedWastes = {};
  String _searchQuery = '';
  String _selectedFilter = 'همه';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
      int dateIndex = -1;
      int partyDetailsIndex = -1;
      int wasteTypeIndex = -1;
      int weightIndex = -1;
      int quantityIndex = -1;
      int valueIndex = -1;
      int currencyIndex = -1;
      int exchangeRateIndex = -1;
      int afnEquivalentIndex = -1;
      int descriptionIndex = -1;

      for (int i = 0; i < headers.length; i++) {
        String h = headers[i];
        String hLower = h.toLowerCase();
        
        if (hLower.contains('شماره') || hLower.contains('فاکتور') || hLower.contains('invoice')) {
          invoiceNumberIndex = i;
        } else if (hLower.contains('تاریخ') || hLower.contains('date')) {
          dateIndex = i;
        } else if (hLower.contains('طرف') || hLower.contains('خریدار') || hLower.contains('فروشنده') || hLower.contains('party')) {
          partyDetailsIndex = i;
        } else if (hLower.contains('نوع ضایعات') || hLower.contains('ضایعات') || hLower.contains('waste') || hLower.contains('type')) {
          wasteTypeIndex = i;
        } else if (hLower.contains('وزن') && !hLower.contains('ناخالص') && !hLower.contains('خالص') || hLower.contains('weight')) {
          weightIndex = i;
        } else if (hLower.contains('تعداد') || hLower.contains('quantity') || hLower.contains('quantity')) {
          quantityIndex = i;
        } else if (hLower.contains('ارزش') || hLower.contains('مبلغ') || hLower.contains('value') || hLower.contains('amount')) {
          valueIndex = i;
        } else if (hLower.contains('ارز') || hLower.contains('واحد پول') || hLower.contains('currency')) {
          currencyIndex = i;
        } else if (hLower.contains('نرخ') || hLower.contains('exchange') || hLower.contains('rate')) {
          exchangeRateIndex = i;
        } else if (hLower.contains('معادل') || hLower.contains('afn') || hLower.contains('افغانی')) {
          afnEquivalentIndex = i;
        } else if (hLower.contains('توضیحات') || hLower.contains('شرح') || hLower.contains('description')) {
          descriptionIndex = i;
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
          String invoiceNumber = invoiceNumberIndex != -1 ? _getCellValueDirect(row, invoiceNumberIndex) : '';
          String date = _getCellValueDirect(row, dateIndex);
          String partyDetails = partyDetailsIndex != -1 ? _getCellValueDirect(row, partyDetailsIndex) : '';
          String wasteType = wasteTypeIndex != -1 ? _getCellValueDirect(row, wasteTypeIndex) : '';
          String weightStr = weightIndex != -1 ? _getCellValueDirect(row, weightIndex) : '0';
          String quantityStr = quantityIndex != -1 ? _getCellValueDirect(row, quantityIndex) : '0';
          String valueStr = valueIndex != -1 ? _getCellValueDirect(row, valueIndex) : '0';
          String currency = currencyIndex != -1 ? _getCellValueDirect(row, currencyIndex) : 'USD';
          String exchangeRateStr = exchangeRateIndex != -1 ? _getCellValueDirect(row, exchangeRateIndex) : '1';
          String afnEquivalentStr = afnEquivalentIndex != -1 ? _getCellValueDirect(row, afnEquivalentIndex) : '0';
          String description = descriptionIndex != -1 ? _getCellValueDirect(row, descriptionIndex) : '';

          weightStr = weightStr.replaceAll(RegExp(r'[$,]'), '').trim();
          quantityStr = quantityStr.replaceAll(RegExp(r'[$,]'), '').trim();
          valueStr = valueStr.replaceAll(RegExp(r'[$,]'), '').trim();
          exchangeRateStr = exchangeRateStr.replaceAll(RegExp(r'[$,]'), '').trim();
          afnEquivalentStr = afnEquivalentStr.replaceAll(RegExp(r'[$,]'), '').trim();

          if (date.isEmpty) {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': تاریخ الزامی است');
            continue;
          }

          if (invoiceNumber.isEmpty) {
            final nextNumber = await _db.getNextWasteInvoiceNumber();
            invoiceNumber = nextNumber.toString().padLeft(5, '0');
          }

          final existing = await _db.getWasteRecords();
          bool duplicate = existing.any((e) => e['invoice_number'] == invoiceNumber);
          if (duplicate) {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': شماره بل "' + invoiceNumber + '" تکراری است');
            continue;
          }

          double weight = _parseNumber(weightStr);
          double quantity = _parseNumber(quantityStr);
          double value = _parseNumber(valueStr);
          double exchangeRate = _parseNumber(exchangeRateStr);
          double afnEquivalent = _parseNumber(afnEquivalentStr);

          String currencyFinal = currency == 'AFN' || currency == 'افغانی' ? 'AFN' : 'USD';
          if (afnEquivalent <= 0 && value > 0) {
            if (currencyFinal == 'USD') {
              afnEquivalent = value * exchangeRate;
            } else {
              afnEquivalent = value;
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
            'value': value,
            'currency': currencyFinal,
            'exchange_rate': exchangeRate > 0 ? exchangeRate : 1,
            'afn_equivalent': afnEquivalent > 0 ? afnEquivalent : (value * exchangeRate),
            'description': description,
            'is_sold': 0,
            'sell_currency': null,
            'sell_price': null,
            'sell_date': null,
            'sell_date_en': null,
          };
          
          int result = await _db.insertWasteRecord(waste);
          if (result != -1) {
            successCount++;
            importedData.add(waste);
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

  // ============ SELL MODAL ============
  Future<void> _showSellModal(Map<String, dynamic> waste) async {
    String selectedCurrency = 'USD';
    final TextEditingController priceController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    
    bool isSold = waste['is_sold'] == 1;
    String? sellCurrency = waste['sell_currency']?.toString();
    double? sellPrice = double.tryParse(waste['sell_price']?.toString() ?? '');
    String? sellDate = waste['sell_date']?.toString();
    String? sellDateEn = waste['sell_date_en']?.toString();
    
    if (isSold) {
      selectedCurrency = sellCurrency ?? 'USD';
      priceController.text = sellPrice?.toString() ?? '';
      dateController.text = sellDate ?? PersianDateConverter.getCurrentPersianDate();
    } else {
      dateController.text = PersianDateConverter.getCurrentPersianDate();
    }
    
    String selectedEnglishDate = sellDateEn ?? PersianDateConverter.getEnglishDate(DateTime.now());
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isSold ? Icons.edit : Icons.sell,
                    color: const Color(0xFFCB001D),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isSold ? 'ویرایش فروش ضایعات' : 'ثبت فروش ضایعات',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'شماره بل: ${waste['invoice_number'] ?? '-'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'نوع ضایعات: ${waste['waste_type'] ?? '-'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            'وزن: ${_getDisplayWeight(waste['weight'])}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            'ارزش: ${_formatNumber(waste['value'])} ${waste['currency'] ?? 'USD'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Sell Date
                    TextFormField(
                      controller: dateController,
                      decoration: InputDecoration(
                        labelText: 'تاریخ فروش *',
                        labelStyle: TextStyle(color: const Color(0xFFCB001D), fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
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
                            dateController.text = persianDate;
                            selectedEnglishDate = englishDate;
                          });
                        }
                      },
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    
                    // Currency Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedCurrency,
                      decoration: InputDecoration(
                        labelText: 'واحد پول *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.currency_exchange),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'USD', child: Text('USD (دالر)')),
                        DropdownMenuItem(value: 'AFN', child: Text('AFN (افغانی)')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedCurrency = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Price Input
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'قیمت فروش *',
                        hintText: 'مبلغ فروش را وارد کنید',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    if (isSold) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'این ضایعات قبلاً به قیمت $sellPrice $sellCurrency در تاریخ $sellDate فروخته شده است',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('لغو', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final price = double.tryParse(priceController.text.trim());
                    final sellDate = dateController.text.trim();
                    
                    if (sellDate.isEmpty) {
                      _showSnackbar('لطفاً تاریخ فروش را انتخاب کنید', Colors.orange);
                      return;
                    }
                    
                    if (price == null || price <= 0) {
                      _showSnackbar('لطفاً قیمت معتبر وارد کنید', Colors.orange);
                      return;
                    }
                    
                    try {
                      final result = await _db.updateWasteSellInfo(
                        waste['id'],
                        selectedCurrency,
                        price,
                        sellDate,
                        selectedEnglishDate,
                      );
                      
                      if (result != -1) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        await _loadWastes();
                        _showSnackbar(
                          'فروش ضایعات با موفقیت ثبت شد',
                          Colors.green,
                        );
                      } else {
                        _showSnackbar('خطا در ثبت فروش', Colors.red);
                      }
                    } catch (e) {
                      _showSnackbar('خطا: $e', Colors.red);
                    }
                  },
                  icon: Icon(
                    isSold ? Icons.update : Icons.check_circle,
                    color: Colors.white,
                  ),
                  label: Text(
                    isSold ? 'به‌روزرسانی فروش' : 'ثبت فروش',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadWastes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
          'is_sold': item['is_sold'] ?? 0,
          'sell_currency': item['sell_currency'],
          'sell_price': item['sell_price'],
          'sell_date': item['sell_date'],
          'sell_date_en': item['sell_date_en'],
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
    final dateController = TextEditingController(text: waste?['date']?.toString() ?? PersianDateConverter.getCurrentPersianDate());
    final partyDetailsController = TextEditingController(text: waste?['party_details']?.toString() ?? '');
    final wasteTypeController = TextEditingController(text: waste?['waste_type']?.toString() ?? '');
    final descriptionController = TextEditingController(text: waste?['description']?.toString() ?? '');
    final weightController = TextEditingController(text: waste?['weight']?.toString() ?? '');
    final quantityController = TextEditingController(
      text: (waste != null && waste['quantity'] != null && waste['quantity'] != 1) 
        ? waste['quantity'].toString() 
        : ''
    );
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
        equivalentController.text = value > 0 && rate > 0 ? (value / rate).toStringAsFixed(2) : '';
      } else {
        equivalentController.text = value > 0 && rate > 0 ? (value * rate).toStringAsFixed(0) : '';
      }
    }

    void updateTotalWeight() {
      final weight = double.tryParse(weightController.text) ?? 0;
      final quantityText = quantityController.text.trim();
      double quantity;
      
      // If quantity is empty or 0, treat it as 1
      if (quantityText.isEmpty || quantityText == '0') {
        quantity = 1;
      } else {
        quantity = double.tryParse(quantityText) ?? 0;
        // If parsed to 0, treat as 1
        if (quantity == 0) quantity = 1;
      }
      
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
                waste == null ? 'افزودن ضایعات جدید' : 'ویرایش ضایعات',
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
                              dateController.text = PersianDateConverter.gregorianToJalali(picked);
                              selectedEnglishDate = PersianDateConverter.getEnglishDate(picked);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(controller: partyDetailsController, label: 'طرف حساب', icon: Icons.business_outlined),
                      const SizedBox(height: 12),
                      _buildTextField(controller: wasteTypeController, label: 'نوع ضایعات', icon: Icons.category_outlined),
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
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: valueController, label: 'ارزش مالی', icon: Icons.attach_money_outlined, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(controller: priceRateController, label: selectedCurrency == 'USD' ? 'نرخ ارز (USD به AFN) *' : 'نرخ ارز (AFN به USD) *', icon: Icons.currency_exchange, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(updateTotals))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(controller: equivalentController, label: selectedCurrency == 'AFN' ? 'معادل به دالر (USD)' : 'معادل به افغانی (AFN)', icon: Icons.currency_exchange, readOnly: true)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCurrency,
                              decoration: InputDecoration(
                                labelText: 'واحد پول',
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
                      _buildTextField(controller: descriptionController, label: 'توضیحات', icon: Icons.description_outlined, maxLines: 3),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو', style: TextStyle(color: Colors.grey))),
                ElevatedButton.icon(
                  onPressed: () async {
                    final payload = {
                      'invoice_number': waste?['invoice_number']?.toString() ?? '',
                      'date': dateController.text.trim(),
                      'date_en': selectedEnglishDate,
                      'party_details': partyDetailsController.text.trim(),
                      'waste_type': wasteTypeController.text.trim(),
                      'weight': double.tryParse(weightController.text) ?? 0,
                      'quantity': (() {
                        final q = double.tryParse(quantityController.text.trim()) ?? 0;
                        return q > 0 ? q : 1;  // If quantity is 0 or empty, use 1
                      })(),
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
                      _showSnackbar(waste == null ? 'ضایعات با موفقیت اضافه شد' : 'ضایعات با موفقیت ویرایش شد', Colors.green);
                    } catch (e) {
                      if (!mounted) return;
                      _showSnackbar('خطا در ذخیره ضایعات', Colors.red);
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(waste == null ? 'افزودن ضایعات' : 'ذخیره تغییرات'),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700), child: const Text('حذف')),
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

  Future<void> _printWasteInvoice(Map<String, dynamic> waste) async {
    try {
      final pdf = await _generateWastePDF(waste);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
        name: 'waste_invoice_${waste['id']}',
      );
    } catch (e) {
      _showSnackbar('خطا در چاپ: $e', Colors.red);
    }
  }

  Future<Uint8List> _generateWastePDF(Map<String, dynamic> waste) async {
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
                        pw.Text('شرکت ویکتور', style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.SizedBox(height: 4),
                        pw.Text('سیستم یکپارچه', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
                      ]),
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(6)),
                          child: pw.Text('فاکتور ضایعات', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text('شماره بل: ${waste['invoice_number'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('تاریخ: ${waste['date'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
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
                    pw.Expanded(child: pw.Text('طرف حساب: ${waste['party_details'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                    pw.Expanded(child: pw.Text('نوع ضایعات: ${waste['waste_type'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10))),
                  ]),
                ),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: ['شرح', 'مبلغ'],
                  data: [
                    ['وزن', displayWeight],
                    ['تعداد', _formatNumber(waste['quantity'])],
                    ['مجموع وزن', displayTotalWeight],
                    ['ارزش مالی', '${_formatNumber(waste['value'])} ${waste['currency'] ?? 'USD'}'],
                    ['نرخ ارز', _formatNumber(waste['exchange_rate'])],
                    ['معادل افغانی', '${_formatNumber(waste['afn_equivalent'])} AFN'],
                    if (waste['is_sold'] == 1) ...[
                      ['تاریخ فروش', waste['sell_date'] ?? '-'],
                      ['وضعیت فروش', '✅ فروخته شده'],
                      ['قیمت فروش', '${_formatNumber(waste['sell_price'])} ${waste['sell_currency'] ?? 'USD'}'],
                    ],
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
                    child: pw.Text('توضیحات: ${waste['description']}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                  ),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('امضا', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('تاریخ چاپ: ${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}', style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
                ]),
                pw.Center(
                  child: pw.Text('سیستم مدیریت یکپارچه شرکت ویکتور', style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey500)),
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
              child: const Icon(Icons.delete_outline, color: Color(0xFFCB001D), size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مدیریت کسرات',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
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
    final totalValue = _wastes.fold<double>(0, (sum, item) => sum + (double.tryParse(item['value']?.toString() ?? '0') ?? 0));
    final totalAfn = _wastes.fold<double>(0, (sum, item) => sum + (double.tryParse(item['afn_equivalent']?.toString() ?? '0') ?? 0));
    final totalWeight = _wastes.fold<double>(0, (sum, item) => sum + (double.tryParse(item['weight']?.toString() ?? '0') ?? 0));
    final totalWeightInTons = totalWeight / 1000;
    final soldCount = _wastes.where((w) => w['is_sold'] == 1).length;
    final soldTotal = _wastes.fold<double>(0, (sum, item) => sum + (double.tryParse(item['sell_price']?.toString() ?? '0') ?? 0));
    
    return Row(
      children: [
        _buildStatCard('تعداد', totalWastes.toString(), Icons.delete_outline, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        _buildStatCard('فروخته شده', soldCount.toString(), Icons.sell, Colors.green.shade700),
        const SizedBox(width: 12),
        _buildStatCard('کل فروش', _formatNumber(soldTotal), Icons.attach_money, Colors.orange.shade700),
        const SizedBox(width: 12),
        _buildStatCard('جمع ارزش مالی', _formatNumber(totalValue), Icons.attach_money_outlined, Colors.blue.shade700),
        const SizedBox(width: 12),
        _buildStatCard('جمع معادل افغانی', _formatNumber(totalAfn), Icons.currency_exchange, Colors.green.shade700),
        const SizedBox(width: 12),
        _buildStatCard('وزن (تن)', '${totalWeightInTons.toStringAsFixed(totalWeightInTons % 1 == 0 ? 0 : 3)} تن', Icons.scale, const Color(0xFFCB001D)),
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
    final filters = ['همه', 'کسرات', 'فروخته شده', 'فروخته نشده'];
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
              hintText: 'جستجو بر اساس طرف، نوع کسرات یا شماره...',
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

  // ==================== MAIN TABLE ====================
  Widget _buildMainTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)));
    }

    if (_wastes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('هیچ ضایعاتی یافت نشد', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    final filteredData = _wastes.where((waste) {
      final search = _searchQuery.toLowerCase();
      final matchesSearch = (waste['party_details'] ?? '').toString().toLowerCase().contains(search) ||
          (waste['waste_type'] ?? '').toString().toLowerCase().contains(search) ||
          (waste['invoice_number'] ?? '').toString().toLowerCase().contains(search) ||
          (waste['description'] ?? '').toString().toLowerCase().contains(search);
      
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Table with header and body in ONE scroll view
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB001D).withOpacity(0.05),
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 40),
                          _buildHeaderCell('#', 50),
                          _buildHeaderCell('شماره بل', 100),
                          _buildHeaderCell('تاریخ', 100),
                          _buildHeaderCell('طرف حساب', 140),
                          _buildHeaderCell('نوع کسرات', 130),
                          _buildHeaderCell('وزن (تن)', 90),
                          _buildHeaderCell('تعداد', 70),
                          _buildHeaderCell('مجموع وزن', 110),
                          _buildHeaderCell('ارزش مالی', 100),
                          _buildHeaderCell('واحد پول', 70),
                          _buildHeaderCell('نرخ تبدیل', 90),
                          _buildHeaderCell('معادل افغانی', 120),
                          _buildHeaderCell('توضیحات', 150),
                          _buildHeaderCell('تاریخ فروش', 120),
                          _buildHeaderCell('وضعیت فروش', 130),
                          _buildHeaderCell('ارز فروش', 100),
                          _buildHeaderCell('قیمت فروش', 140),
                          _buildHeaderCell('عملیات', 200),
                        ],
                      ),
                    ),
                    // ===== BODY ROWS =====
                    if (paged.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('هیچ داده‌ای یافت نشد', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...paged.asMap().entries.map((entry) {
                        final index = entry.key;
                        final waste = entry.value;
                        final id = waste['id'] as int;
                        final isSelected = _selectedWastes.contains(id);
                        bool isSold = waste['is_sold'] == 1;
                        String displayWeight = _getDisplayWeight(waste['weight']);
                        String totalWeightDisplay = _getTotalWeightDisplay(waste['weight'], waste['quantity']);
                        String sellDisplay = isSold 
                          ? '${_formatNumber(waste['sell_price'])}'
                          : '-';
                        String sellCurrencyDisplay = isSold 
                          ? (waste['sell_currency'] ?? 'USD')
                          : '-';
                        String sellDateDisplay = isSold 
                          ? (waste['sell_date'] ?? '-')
                          : '-';
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  onChanged: (_) => _toggleSelection(id),
                                  activeColor: const Color(0xFFCB001D),
                                  checkColor: Colors.white,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              _buildDataCell((start + index + 1).toString(), 50),
                              _buildDataCell(waste['invoice_number']?.toString() ?? '-', 100, isBold: true),
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
                              _buildDataCell(waste['party_details']?.toString() ?? '-', 140),
                              _buildDataCell(waste['waste_type']?.toString() ?? '-', 130),
                              _buildDataCell(displayWeight, 90),
                              _buildDataCell(
                                (waste['quantity'] != null && waste['quantity'] != 1 && waste['quantity'] != 0) 
                                  ? _formatNumber(waste['quantity']) 
                                  : '-', 
                                70
                              ),
                              _buildDataCell(totalWeightDisplay, 110, isBold: true, color: const Color(0xFFCB001D)),
                              _buildDataCell(_formatNumber(waste['value']), 100, isBold: true, color: const Color(0xFFCB001D)),
                              _buildDataCell(waste['currency']?.toString() ?? '-', 70),
                              _buildDataCell(_formatNumber(waste['exchange_rate']), 90),
                              _buildDataCell(_formatNumber(waste['afn_equivalent']), 120),
                              _buildDataCell(waste['description']?.toString() ?? '-', 150),
                              _buildDataCell(sellDateDisplay, 120, isBold: isSold, color: isSold ? const Color(0xFFCB001D) : Colors.grey),
                              _buildDataCell(
                                isSold ? '✅ فروخته شده' : '⬜️ فروخته نشده',
                                130,
                                isBold: isSold,
                                color: isSold ? Colors.green : Colors.grey,
                              ),
                              _buildDataCell(sellCurrencyDisplay, 100, isBold: isSold, color: isSold ? const Color(0xFFCB001D) : Colors.grey),
                              _buildDataCell(sellDisplay, 140, isBold: isSold, color: isSold ? const Color(0xFFCB001D) : Colors.grey),
                              SizedBox(
                                width: 200,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () => _showWasteDialog(waste: waste),
                                      icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700, size: 20),
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'ویرایش',
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteWaste(waste),
                                      icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'حذف',
                                    ),
                                    IconButton(
                                      onPressed: () => _printWasteInvoice(waste),
                                      icon: const Icon(Icons.print_outlined, color: Color(0xFFCB001D), size: 20),
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'چاپ',
                                    ),
                                    IconButton(
                                      onPressed: () => _showSellModal(waste),
                                      icon: Icon(
                                        isSold ? Icons.sell : Icons.sell_outlined,
                                        color: isSold ? Colors.green : const Color(0xFFCB001D),
                                        size: 20,
                                      ),
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      padding: EdgeInsets.zero,
                                      tooltip: isSold ? 'ویرایش فروش' : 'ثبت فروش',
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
              border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('نمایش', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _rowsPerPage,
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFCB001D), size: 16),
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
                      icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFFCB001D), size: 16),
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
                      style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                    ),
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
                      onPressed: _currentPage < totalPages ? () => _changePage(_currentPage + 1) : null,
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
      inputFormatters: keyboardType == TextInputType.number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))] : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
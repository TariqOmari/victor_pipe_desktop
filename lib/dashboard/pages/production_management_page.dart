import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class ProductionManagementPage extends StatefulWidget {
  const ProductionManagementPage({super.key});

  @override
  State<ProductionManagementPage> createState() => _ProductionManagementPageState();
}

class _ProductionManagementPageState extends State<ProductionManagementPage> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> productions = [];
  bool isLoading = true;
  Map<String, dynamic> stockData = {};

  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50, 100];
  final Set<int> _selectedIds = {};

  // Helper to check if unit is weight-based
  bool _isWeightUnit(String unit) {
    return unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg' || 
           unit == 'تن' || unit == 'ton' || unit == 'Ton';
  }

  // Format weight with conversion - ALWAYS shows kg as tons
  String _formatWeightWithConversion(String unit, double weight) {
    if (_isWeightUnit(unit)) {
      double tons = weight / 1000;
      
      // For very small weights, show more decimal places
      if (tons < 0.01) {
        return '${tons.toStringAsFixed(3)} تن';  // 0.003 for 3 kg
      }
      
      return '${tons.toStringAsFixed(2)} تن';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} $unit';
  }

  // Get total tons of all productions
  double _getTotalTons() {
    double totalTons = 0;
    for (var product in productions) {
      String unit = product['unit']?.toString() ?? '';
      double weight = double.tryParse(product['total_weight']?.toString() ?? '0') ?? 0;
      
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

  // Get total weight display
  String _getTotalWeightDisplay() {
    double totalTons = _getTotalTons();
    return '${totalTons.toStringAsFixed(totalTons % 1 == 0 ? 0 : 2)} تن';
  }

  // Get total weight in kg for display
  double _getTotalWeightInKg() {
    double totalKg = 0;
    for (var product in productions) {
      String unit = product['unit']?.toString() ?? '';
      double weight = double.tryParse(product['total_weight']?.toString() ?? '0') ?? 0;
      
      if (_isWeightUnit(unit)) {
        if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
          totalKg += weight;
        } else if (unit == 'تن' || unit == 'ton' || unit == 'Ton') {
          totalKg += weight * 1000;
        }
      }
    }
    return totalKg;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'خطا در وارد کردن فایل'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در وارد کردن: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      int productionTypeIndex = -1;
      int sizeIndex = -1;
      int thicknessIndex = -1;
      int lengthIndex = -1;
      int rawCountIndex = -1;
      int rawWeightIndex = -1;
      int totalWeightIndex = -1;
      int unitIndex = -1;
      int dateIndex = -1;
      int statusIndex = -1;
      int descriptionIndex = -1;

      for (int i = 0; i < headers.length; i++) {
        String h = headers[i];
        String hLower = h.toLowerCase();
        
        if (hLower.contains('نوع تولید') || hLower.contains('production') || hLower.contains('نوع')) {
          productionTypeIndex = i;
        } else if (hLower.contains('سایز') || hLower.contains('size')) {
          sizeIndex = i;
        } else if (hLower.contains('ضخامت') || hLower.contains('thickness')) {
          thicknessIndex = i;
        } else if (hLower.contains('طول') || hLower.contains('length')) {
          lengthIndex = i;
        } else if (hLower.contains('تعداد خاده') || hLower.contains('raw count') || hLower.contains('تعداد')) {
          rawCountIndex = i;
        } else if (hLower.contains('وزن فی خاده') || hLower.contains('raw weight') || hLower.contains('وزن فی')) {
          rawWeightIndex = i;
        } else if (hLower.contains('مجموع وزن') || hLower.contains('total weight') || hLower.contains('وزن کل')) {
          totalWeightIndex = i;
        } else if (hLower.contains('واحد') && !hLower.contains('پول')) {
          unitIndex = i;
        } else if (hLower.contains('تاریخ') || hLower.contains('date')) {
          dateIndex = i;
        } else if (hLower.contains('وضعیت') || hLower.contains('status')) {
          statusIndex = i;
        } else if (hLower.contains('توضیحات') || hLower.contains('شرح') || hLower.contains('description')) {
          descriptionIndex = i;
        }
      }

      print('📋 Production Type: $productionTypeIndex, Date: $dateIndex');

      if (productionTypeIndex == -1 || dateIndex == -1) {
        return {
          'success': false,
          'message': 'فیلدهای مورد نیاز پیدا نشد: نوع تولید، تاریخ'
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
          String productionType = _getCellValueDirect(row, productionTypeIndex);
          String size = sizeIndex != -1 ? _getCellValueDirect(row, sizeIndex) : '';
          String thickness = thicknessIndex != -1 ? _getCellValueDirect(row, thicknessIndex) : '';
          String length = lengthIndex != -1 ? _getCellValueDirect(row, lengthIndex) : '';
          String rawCountStr = rawCountIndex != -1 ? _getCellValueDirect(row, rawCountIndex) : '1';
          String rawWeightStr = rawWeightIndex != -1 ? _getCellValueDirect(row, rawWeightIndex) : '0';
          String totalWeightStr = totalWeightIndex != -1 ? _getCellValueDirect(row, totalWeightIndex) : '';
          String unit = unitIndex != -1 ? _getCellValueDirect(row, unitIndex) : 'متر';
          String date = _getCellValueDirect(row, dateIndex);
          String status = statusIndex != -1 ? _getCellValueDirect(row, statusIndex) : 'در حال تولید';
          String description = descriptionIndex != -1 ? _getCellValueDirect(row, descriptionIndex) : '';

          // پاک کردن علامت‌های اضافی
          rawCountStr = rawCountStr.replaceAll(RegExp(r'[$,]'), '').trim();
          rawWeightStr = rawWeightStr.replaceAll(RegExp(r'[$,]'), '').trim();
          totalWeightStr = totalWeightStr.replaceAll(RegExp(r'[$,]'), '').trim();

          print('📝 Row ${i+1}: Type="$productionType", Date="$date"');

          if (productionType.isEmpty || date.isEmpty) {
            skippedCount++;
            errors.add('ردیف ' + (i+1).toString() + ': فیلدهای مورد نیاز کامل نیستند');
            continue;
          }

          int rawCount = _parseNumber(rawCountStr).toInt();
          double rawWeight = _parseNumber(rawWeightStr);
          
          // اگر مجموع وزن خالی بود، محاسبه کن
          double totalWeight = _parseNumber(totalWeightStr);
          if (totalWeight <= 0 && rawCount > 0 && rawWeight > 0) {
            totalWeight = rawCount * rawWeight;
          }

          // تاریخ
          if (date.isEmpty) {
            date = PersianDateConverter.gregorianToJalali(DateTime.now());
          }
          String dateEn = PersianDateConverter.getEnglishDate(DateTime.now());

          // تعیین واحد مناسب
          String unitFinal = unit;
          if (unit.isEmpty) {
            if (_isWeightUnit(unit)) {
              unitFinal = 'کیلوگرم';
            } else {
              unitFinal = 'متر';
            }
          }

          // ============================================
          // ساخت داده - فقط فیلدهای موجود در جدول
          // ============================================
          Map<String, dynamic> product = {
            'product_name': productionType,
            'production_type': productionType,
            'size': size,
            'thickness': thickness,
            'length': length,
            'raw_count': rawCount,
            'raw_weight': rawWeight,
            'total_weight': totalWeight,
            'unit': unitFinal,
            'production_date': date,
            'production_date_en': dateEn,
            'status': status,
            'description': description,
            'remaining_stock': totalWeight,
          };

          print('📦 Inserting: ${product['production_type']}');
          
          int result = await _db.insertProducedProduct(product);
          if (result != -1) {
            successCount++;
            importedData.add(product);
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
    setState(() => isLoading = true);
    try {
      await _db.initializeProductStock();
      final data = await _db.getProducedProductsWithSaleStatus();
      final stock = await _db.getTotalProductStock();
      if (!mounted) return;
      setState(() {
        productions = data;
        stockData = stock;
        isLoading = false;
        _selectedIds.clear();
        _currentPage = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorLoadingProduction), backgroundColor: Colors.red),
      );
    }
  }

  List<Map<String, dynamic>> get _paginatedProductions {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= productions.length) {
      _currentPage = 1;
      return productions.take(_itemsPerPage).toList();
    }
    return productions.sublist(start, end > productions.length ? productions.length : end);
  }

  int get _totalPages {
    if (productions.isEmpty) return 1;
    return (productions.length / _itemsPerPage).ceil();
  }

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
      final currentIds = _paginatedProductions.map((item) => item['id'] as int).toList();
      final allSelected = currentIds.every((id) => _selectedIds.contains(id));
      if (allSelected) {
        _selectedIds.removeAll(currentIds);
      } else {
        _selectedIds.addAll(currentIds);
      }
    });
  }

  Map<String, double> _getUnitTotals() {
    final totals = <String, double>{};
    for (final product in productions) {
      final unit = product['unit']?.toString() ?? 'نامشخص';
      final rawCount = double.tryParse(product['raw_count']?.toString() ?? '0') ?? 0;
      double weight = double.tryParse(product['total_weight']?.toString() ?? '0') ?? 0;
      
      if (_isWeightUnit(unit)) {
        double weightInTons = weight / 1000;
        totals[unit] = (totals[unit] ?? 0) + rawCount + weightInTons;
      } else {
        totals[unit] = (totals[unit] ?? 0) + rawCount + weight;
      }
    }
    return totals;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: color.withOpacity(0.08), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard(AppLocalizations l10n) {
    final totalTons = stockData['total_tons'] ?? 0.0;
    final totalKg = stockData['total_kg'] ?? 0.0;
    final productCount = stockData['product_count'] ?? 0;
    final unitBreakdown = stockData['unit_breakdown'] ?? {};
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCB001D), Color(0xFF8B0015)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCB001D).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warehouse, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                '📦 ${l10n.stock}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$productCount ${l10n.totalItems}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وزن کل',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalTons.toStringAsFixed(totalTons % 1 == 0 ? 0 : 2)} تن',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${totalKg.toStringAsFixed(totalKg % 1 == 0 ? 0 : 0)} کیلوگرم',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.2),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'تعداد محصولات',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$productCount',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${productions.where((p) => p['status'] == 'تکمیل شده').length} ${l10n.completedStatus}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (unitBreakdown.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: unitBreakdown.entries.map((entry) {
                  final unit = entry.key;
                  final weight = entry.value;
                  String displayValue;
                  if (_isWeightUnit(unit)) {
                    double tons = weight / 1000;
                    displayValue = '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
                  } else {
                    displayValue = '$weight $unit';
                  }
                  return Column(
                    children: [
                      Text(
                        displayValue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        unit,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  );
                }).toList().cast<Widget>(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.productionManagementTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 2),
            Text(l10n.productionManagementSubtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          ],
        ),
        Row(
          children: [
            if (_selectedIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFCB001D).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFFCB001D), size: 14),
                    const SizedBox(width: 4),
                    Text('${_selectedIds.length} ${l10n.selected}', style: const TextStyle(color: Color(0xFFCB001D), fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            const SizedBox(width: 8),
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
              onPressed: () => _showProductDialog(context, l10n),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: Text(l10n.addProductionRecord, style: const TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCards(AppLocalizations l10n) {
    final total = productions.length;
    final totalWeight = _getTotalWeightDisplay();
    final totalKg = _getTotalWeightInKg();

    return Row(
      children: [
        _buildStatCard(l10n.totalProductionsCount, total.toString(), Icons.factory_rounded, const Color(0xFFCB001D)),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
              ],
              border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.15), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCB001D).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.scale, color: Color(0xFFCB001D), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مجموع وزن',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        totalWeight,
                        style: const TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFFCB001D)
                        ),
                      ),
                      if (totalKg > 0)
                        Text(
                          '(${totalKg.toStringAsFixed(totalKg % 1 == 0 ? 0 : 0)} کیلوگرم)',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
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

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text, 
        style: const TextStyle(
          fontWeight: FontWeight.bold, 
          fontSize: 9, 
          color: Color(0xFF1A1A2E)
        ), 
        textAlign: TextAlign.center, 
        maxLines: 2, 
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
          fontSize: 9
        ), 
        textAlign: TextAlign.center, 
        maxLines: 2, 
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusChip(String? status, AppLocalizations l10n) {
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'تکمیل شده':
        color = Colors.green.shade700;
        icon = Icons.check_circle_rounded;
        label = l10n.completedStatus;
        break;
      case 'در حال تولید':
        color = Colors.blue.shade700;
        icon = Icons.pending_rounded;
        label = l10n.inProgressStatus;
        break;
      case 'در انتظار':
        color = Colors.orange.shade700;
        icon = Icons.hourglass_empty_rounded;
        label = l10n.pendingStatus;
        break;
      default:
        color = Colors.grey.shade600;
        icon = Icons.help_rounded;
        label = status ?? '-';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 2),
          Text(
            label, 
            style: TextStyle(
              color: color, 
              fontSize: 8, 
              fontWeight: FontWeight.w600
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSoldStatusChip(Map<String, dynamic> product, AppLocalizations l10n) {
    final isSold = (product['is_sold'] == 1 || product['is_sold']?.toString() == '1');
    final saleCount = (product['sale_count'] as int? ?? 0);
    final availableStock = double.tryParse(product['remaining_stock']?.toString() ?? '0') ?? 0;
    
    String unit = product['unit']?.toString() ?? '';
    String stockDisplay = _formatWeightWithConversion(unit, availableStock);
    
    if (isSold && availableStock <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        child: Text(
          'فروخته شده',
          style: const TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: availableStock > 0 ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: availableStock > 0 ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3), 
          width: 1
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            availableStock > 0 ? Icons.check_circle : Icons.warning_amber_rounded, 
            color: availableStock > 0 ? Colors.green : Colors.orange, 
            size: 8
          ),
          const SizedBox(width: 2),
          Text(
            availableStock > 0 ? '$stockDisplay موجود' : 'موجودی: $stockDisplay',
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w600,
              color: availableStock > 0 ? Colors.green : Colors.orange,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showProductDialog(BuildContext context, AppLocalizations l10n, {Map<String, dynamic>? product}) {
    final isEditing = product != null;
    
    // Field controllers
    final productionTypeController = TextEditingController(text: product?['production_type']?.toString() ?? '');
    final sizeController = TextEditingController(text: product?['size']?.toString() ?? '');
    final thicknessController = TextEditingController(text: product?['thickness']?.toString() ?? '');
    final lengthController = TextEditingController(text: product?['length']?.toString() ?? '');
    final rawCountController = TextEditingController(text: product?['raw_count']?.toString() ?? '');
    final rawWeightController = TextEditingController(text: product?['raw_weight']?.toString() ?? '');
    final totalWeightController = TextEditingController(text: product?['total_weight']?.toString() ?? '0');
    final dateController = TextEditingController(text: product?['production_date']?.toString() ?? '');
    final descriptionController = TextEditingController(text: product?['description']?.toString() ?? '');

    String? selectedEnglishDate = product?['production_date_en']?.toString();
    String? selectedUnit = product?['unit']?.toString() ?? 'متر';
    String? selectedStatus = product?['status']?.toString() ?? 'در حال تولید';

    void _calculateTotalWeight() {
      final rawCount = int.tryParse(rawCountController.text) ?? 0;
      final rawWeight = double.tryParse(rawWeightController.text) ?? 0;
      final total = rawCount * rawWeight;
      totalWeightController.text = total > 0 ? total.toStringAsFixed(2) : '0';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double rawWeight = double.tryParse(rawWeightController.text) ?? 0;
          int rawCount = int.tryParse(rawCountController.text) ?? 0;
          double totalWeight = double.tryParse(totalWeightController.text) ?? 0;
          
          // Check if unit is weight-based
          bool isWeightUnit = selectedUnit == 'کیلوگرم' || selectedUnit == 'kg' || selectedUnit == 'Kg' || 
                             selectedUnit == 'تن' || selectedUnit == 'ton' || selectedUnit == 'Ton';
          
          // Convert total weight to tons if it's in kg
          String totalWeightDisplay;
          String totalWeightInTons;
          String rawWeightDisplay;
          
          if (isWeightUnit) {
            // Raw weight always in kg
            rawWeightDisplay = '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} کیلوگرم';
            // Total weight in tons
            double tons = totalWeight / 1000;
            totalWeightInTons = tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2);
            totalWeightDisplay = '$totalWeightInTons تن';
          } else {
            rawWeightDisplay = '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} $selectedUnit';
            totalWeightDisplay = '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 1)} $selectedUnit';
            totalWeightInTons = totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 1);
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(isEditing ? l10n.editProductionRecord : l10n.addProductionRecord),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. نوع تولید (FIRST FIELD - Required)
                      TextField(
                        controller: productionTypeController,
                        decoration: InputDecoration(
                          labelText: 'نوع تولید *',
                          border: const OutlineInputBorder(), 
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // 2. سایز
                      TextField(
                        controller: sizeController,
                        decoration: InputDecoration(
                          labelText: 'سایز',
                          border: const OutlineInputBorder(), 
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // 3. ضخامت & 4. طول - Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: thicknessController,
                              decoration: InputDecoration(
                                labelText: 'ضخامت',
                                border: const OutlineInputBorder(), 
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lengthController,
                              decoration: InputDecoration(
                                labelText: 'طول',
                                border: const OutlineInputBorder(), 
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // 5. تعداد خاده & 6. وزن فی خاده - Row (Required)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: rawCountController,
                              decoration: InputDecoration(
                                labelText: 'تعداد خاده *',
                                border: const OutlineInputBorder(), 
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(() {
                                _calculateTotalWeight();
                                setDialogState(() {});
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: rawWeightController,
                              decoration: InputDecoration(
                                labelText: 'وزن فی خاده * (کیلوگرم)', 
                                border: const OutlineInputBorder(), 
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                helperText: 'همیشه بر حسب کیلوگرم وارد کنید',
                                helperStyle: const TextStyle(fontSize: 9, color: Colors.grey),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(() {
                                _calculateTotalWeight();
                                setDialogState(() {});
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // 7. مجموع وزن (Auto-calculated, Read-only) - Show in TONS
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFCB001D).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calculate, color: Color(0xFFCB001D), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'مجموع وزن',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const Spacer(),
                                if (totalWeight > 0 && isWeightUnit) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCB001D).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      totalWeightDisplay,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFCB001D),
                                      ),
                                    ),
                                  ),
                                ] else if (totalWeight > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCB001D).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      totalWeightDisplay,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFCB001D),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const Text(
                                    '0',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (totalWeight > 0 && isWeightUnit) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$totalWeight kg',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward, color: Color(0xFFCB001D), size: 12),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCB001D).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFCB001D).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$totalWeightInTons تن',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFCB001D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'محاسبه خودکار: تعداد خاده × وزن فی خاده',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // 8. واحد & 9. تاریخ - Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'واحد *', 
                                border: const OutlineInputBorder(), 
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              value: selectedUnit,
                              items: const [
                                DropdownMenuItem(value: 'متر', child: Text('متر')),
                                DropdownMenuItem(value: 'عدد', child: Text('عدد')),
                                DropdownMenuItem(value: 'کیلوگرم', child: Text('کیلوگرم')),
                                DropdownMenuItem(value: 'تن', child: Text('تن')),
                              ],
                              onChanged: (value) => setDialogState(() {
                                selectedUnit = value;
                                _calculateTotalWeight();
                                setDialogState(() {});
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: dateController,
                              decoration: InputDecoration(
                                labelText: 'تاریخ *', 
                                border: const OutlineInputBorder(), 
                                suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 18), 
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              readOnly: true,
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context, 
                                  initialDate: DateTime.now(), 
                                  firstDate: DateTime(2020), 
                                  lastDate: DateTime(2030)
                                );
                                if (picked != null) {
                                  final persianDate = PersianDateConverter.gregorianToJalali(picked);
                                  final englishDate = PersianDateConverter.getEnglishDate(picked);
                                  setDialogState(() {
                                    dateController.text = persianDate;
                                    selectedEnglishDate = englishDate;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // 10. وضعیت
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'وضعیت', 
                          border: const OutlineInputBorder(), 
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: selectedStatus,
                        items: const [
                          DropdownMenuItem(value: 'در حال تولید', child: Text('در حال تولید')),
                          DropdownMenuItem(value: 'تکمیل شده', child: Text('تکمیل شده')),
                          DropdownMenuItem(value: 'در انتظار', child: Text('در انتظار')),
                        ],
                        onChanged: (value) => setDialogState(() => selectedStatus = value),
                      ),
                      const SizedBox(height: 8),
                      
                      // 11. توضیحات
                      TextField(
                        controller: descriptionController, 
                        maxLines: 2, 
                        decoration: InputDecoration(
                          labelText: 'توضیحات', 
                          border: const OutlineInputBorder(), 
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF888888)))
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validate required fields
                    if (productionTypeController.text.isEmpty || 
                        rawCountController.text.isEmpty || 
                        selectedUnit == null || 
                        dateController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('لطفاً تمام فیلدهای الزامی (*) را پر کنید'), 
                          backgroundColor: Colors.red
                        )
                      );
                      return;
                    }

                    final rawCount = int.tryParse(rawCountController.text) ?? 0;
                    final rawWeight = double.tryParse(rawWeightController.text) ?? 0;
                    final totalWeight = rawCount * rawWeight;

                    final payload = {
                      'production_type': productionTypeController.text,
                      'size': sizeController.text,
                      'thickness': thicknessController.text,
                      'length': lengthController.text,
                      'raw_count': rawCount,
                      'raw_weight': rawWeight,
                      'total_weight': totalWeight.toDouble(),
                      'unit': selectedUnit,
                      'production_date': dateController.text,
                      'production_date_en': selectedEnglishDate ?? '',
                      'status': selectedStatus ?? 'در حال تولید',
                      'description': descriptionController.text,
                      'remaining_stock': totalWeight.toDouble(),
                    };

                    Navigator.pop(context);
                    final result = isEditing 
                      ? await _db.updateProducedProduct(product!['id'], payload) 
                      : await _db.insertProducedProduct(payload);
                    
                    if (!mounted) return;
                    if (result != -1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditing ? l10n.productUpdatedSuccess : l10n.productAddedSuccess), 
                          backgroundColor: Colors.green
                        )
                      );
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.errorSavingProduct), 
                          backgroundColor: Colors.red
                        )
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D)),
                  child: Text(isEditing ? l10n.update : l10n.save),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> product, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(l10n.deleteProductionRecord),
          content: Text('${l10n.deleteConfirmation} "${product['production_type']}"؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF888888)))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await _db.deleteProducedProduct(product['id']);
                if (!mounted) return;
                if (result != -1) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.productDeletedSuccess), backgroundColor: Colors.green));
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorDeletingProduct), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            _buildHeader(l10n),
            const SizedBox(height: 16),
            _buildStockCard(l10n),
            const SizedBox(height: 12),
            _buildStatsCards(l10n),
            const SizedBox(height: 14),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
                  : productions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.factory_outlined, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(l10n.noProductsFound, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                  border: Border.all(
                                    color: const Color(0xFFCB001D).withOpacity(0.06),
                                    width: 1,
                                  ),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Fixed column widths - adjusted to prevent overflow
                                    final columnWidths = {
                                      'checkbox': 32.0,
                                      'id': 35.0,
                                      'type': 90.0,
                                      'size': 45.0,
                                      'thickness': 45.0,
                                      'length': 45.0,
                                      'rawCount': 50.0,
                                      'rawWeight': 65.0,
                                      'totalWeight': 70.0,
                                      'unit': 40.0,
                                      'date': 80.0,
                                      'status': 65.0,
                                      'saleStatus': 70.0,
                                      'actions': 60.0,
                                    };

                                    double totalColumnsWidth = columnWidths.values.reduce((a, b) => a + b) + 40;

                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: totalColumnsWidth > constraints.maxWidth ? totalColumnsWidth : constraints.maxWidth,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.vertical,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // HEADER ROW
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFCB001D).withOpacity(0.05),
                                                  border: const Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: columnWidths['checkbox'],
                                                      child: Checkbox(
                                                        value: _paginatedProductions.isNotEmpty && 
                                                               _paginatedProductions.every((p) => _selectedIds.contains(p['id'] as int)),
                                                        onChanged: (_) => _toggleSelectAll(),
                                                        activeColor: const Color(0xFFCB001D),
                                                        checkColor: Colors.white,
                                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    ),
                                                    _buildHeaderCell(l10n.idLabelProd, columnWidths['id']!),
                                                    _buildHeaderCell('نوع تولید', columnWidths['type']!),
                                                    _buildHeaderCell('سایز', columnWidths['size']!),
                                                    _buildHeaderCell('ضخامت', columnWidths['thickness']!),
                                                    _buildHeaderCell('طول', columnWidths['length']!),
                                                    _buildHeaderCell('تعداد خاده', columnWidths['rawCount']!),
                                                    _buildHeaderCell('وزن فی خاده', columnWidths['rawWeight']!),
                                                    _buildHeaderCell('مجموع وزن', columnWidths['totalWeight']!),
                                                    _buildHeaderCell('واحد', columnWidths['unit']!),
                                                    _buildHeaderCell('تاریخ', columnWidths['date']!),
                                                    _buildHeaderCell('وضعیت', columnWidths['status']!),
                                                    _buildHeaderCell('وضعیت فروش', columnWidths['saleStatus']!),
                                                    _buildHeaderCell('عملیات', columnWidths['actions']!),
                                                  ],
                                                ),
                                              ),

                                              // DATA ROWS
                                              ..._paginatedProductions.map((product) {
                                                final isSelected = _selectedIds.contains(product['id'] as int);
                                                
                                                String unit = product['unit']?.toString() ?? '';
                                                double rawWeight = double.tryParse(product['raw_weight']?.toString() ?? '0') ?? 0;
                                                double totalWeight = double.tryParse(product['total_weight']?.toString() ?? '0') ?? 0;
                                                
                                                // For rawWeight: ALWAYS show in kg (no conversion)
                                                String displayRawWeight;
                                                if (_isWeightUnit(unit)) {
                                                  displayRawWeight = '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} کیلوگرم';
                                                } else {
                                                  displayRawWeight = '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} $unit';
                                                }
                                                
                                                // For totalWeight: ALWAYS show in tons (with conversion)
                                                String displayTotalWeight;
                                                if (_isWeightUnit(unit)) {
                                                  double tons = totalWeight / 1000;
                                                  if (tons < 0.01) {
                                                    displayTotalWeight = '${tons.toStringAsFixed(3)} تن';
                                                  } else {
                                                    displayTotalWeight = '${tons.toStringAsFixed(2)} تن';
                                                  }
                                                } else {
                                                  displayTotalWeight = '${totalWeight.toStringAsFixed(totalWeight % 1 == 0 ? 0 : 1)} $unit';
                                                }
                                                
                                                String displayUnit = _isWeightUnit(unit) ? 'تن' : unit;

                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? const Color(0xFFCB001D).withOpacity(0.04) : null,
                                                    border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        width: columnWidths['checkbox'],
                                                        child: Checkbox(
                                                          value: isSelected,
                                                          onChanged: (_) => _toggleSelection(product['id'] as int),
                                                          activeColor: const Color(0xFFCB001D),
                                                          checkColor: Colors.white,
                                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        ),
                                                      ),
                                                      _buildDataCell(product['id'].toString(), columnWidths['id']!),
                                                      _buildDataCell(product['production_type']?.toString() ?? '-', columnWidths['type']!, isBold: true),
                                                      _buildDataCell(product['size']?.toString() ?? '-', columnWidths['size']!),
                                                      _buildDataCell(product['thickness']?.toString() ?? '-', columnWidths['thickness']!),
                                                      _buildDataCell(product['length']?.toString() ?? '-', columnWidths['length']!),
                                                      _buildDataCell(product['raw_count']?.toString() ?? '0', columnWidths['rawCount']!, isBold: true),
                                                      _buildDataCell(displayRawWeight, columnWidths['rawWeight']!),
                                                      _buildDataCell(displayTotalWeight, columnWidths['totalWeight']!, isBold: true, isRed: true),
                                                      _buildDataCell(displayUnit, columnWidths['unit']!),
                                                      
                                                      // DATE COLUMN
                                                      SizedBox(
                                                        width: columnWidths['date'],
                                                        child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            Text(
                                                              product['production_date']?.toString() ?? '-',
                                                              style: const TextStyle(fontSize: 8, color: Color(0xFF1A1A2E)),
                                                              textAlign: TextAlign.center,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            Text(
                                                              product['production_date_en']?.toString() ?? '-',
                                                              style: const TextStyle(fontSize: 6, color: Colors.grey),
                                                              textAlign: TextAlign.center,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                      // STATUS COLUMN
                                                      SizedBox(
                                                        width: columnWidths['status']!,
                                                        child: Center(
                                                          child: _buildStatusChip(product['status']?.toString(), l10n),
                                                        ),
                                                      ),
                                                      
                                                      // SALE STATUS COLUMN
                                                      SizedBox(
                                                        width: columnWidths['saleStatus']!,
                                                        child: Center(
                                                          child: _buildSoldStatusChip(product, l10n),
                                                        ),
                                                      ),
                                                      
                                                      // ACTIONS COLUMN
                                                      SizedBox(
                                                        width: columnWidths['actions']!,
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            Container(
                                                              width: 24,
                                                              height: 24,
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFCB001D).withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: IconButton(
                                                                icon: const Icon(Icons.edit_outlined, color: Color(0xFFCB001D), size: 13),
                                                                padding: EdgeInsets.zero,
                                                                constraints: const BoxConstraints(),
                                                                onPressed: () => _showProductDialog(context, l10n, product: product),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 2),
                                                            Container(
                                                              width: 24,
                                                              height: 24,
                                                              decoration: BoxDecoration(
                                                                color: Colors.red.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: IconButton(
                                                                icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 13),
                                                                padding: EdgeInsets.zero,
                                                                constraints: const BoxConstraints(),
                                                                onPressed: () => _showDeleteDialog(context, product, l10n),
                                                              ),
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
                                    );
                                  },
                                ),
                              ),
                            ),
                            // FOOTER PAGINATION
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                                border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(l10n.show, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)), borderRadius: BorderRadius.circular(6)),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _itemsPerPage,
                                            onChanged: _changeItemsPerPage,
                                            items: _pageSizeOptions.map((size) => DropdownMenuItem<int>(
                                              value: size,
                                              child: Text(size.toString(), style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 12)),
                                            )).toList(),
                                            dropdownColor: Colors.white,
                                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFCB001D), size: 18),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(l10n.perPage, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text('${l10n.page} $_currentPage ${l10n.pageOf} $_totalPages', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
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
}
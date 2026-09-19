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

    print('📋 Total rows: ${sheet.rows.length}');

    final headersRow = sheet.rows.first;
    List<String> headers = [];
    for (var cell in headersRow) {
      if (cell != null && cell.value != null) {
        headers.add(cell.value.toString().trim());
      } else {
        headers.add('');
      }
    }

    print('📋 Headers: $headers');

    String normalize(String h) {
      return h
          .trim()
          .replaceAll('\u200c', '')
          .replaceAll(' ', '')
          .replaceAll('ي', 'ی')
          .replaceAll('ك', 'ک')
          .toLowerCase();
    }

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
      String h = normalize(headers[i]);
      if (h.isEmpty) continue;

      if (h == 'نوعتولید' || h == 'نوعتولیدات') {
        productionTypeIndex = i;
      } else if (h == 'سایز' || h == 'اندازه') {
        sizeIndex = i;
      } else if (h == 'ضخامت') {
        thicknessIndex = i;
      } else if (h == 'طول') {
        lengthIndex = i;
      } else if (h == 'تعدادخاده' || h == 'تعدادخادها' || h == 'تعداد') {
        rawCountIndex = i;
      } else if (h == 'وزنفیخاده' || h == 'وزنفیخادها' || h == 'وزنخاده') {
        rawWeightIndex = i;
      } else if (h == 'مجموعوزن' || h == 'وزنکل' || h == 'وزنمجموعی') {
        totalWeightIndex = i;
      } else if (h == 'واحد') {
        unitIndex = i;
      } else if (h == 'تاریخ') {
        dateIndex = i;
      } else if (h == 'وضعیت') {
        statusIndex = i;
      } else if (h == 'توضیحات' || h == 'شرح' || h == 'ملاحظات') {
        descriptionIndex = i;
      }
    }

    print('📋 INDEX MAP:');
    print('  productionType = $productionTypeIndex');
    print('  size           = $sizeIndex');
    print('  thickness      = $thicknessIndex');
    print('  length         = $lengthIndex');
    print('  rawCount       = $rawCountIndex');
    print('  rawWeight      = $rawWeightIndex');
    print('  totalWeight    = $totalWeightIndex');
    print('  unit           = $unitIndex');
    print('  date           = $dateIndex');
    print('  status         = $statusIndex');
    print('  description    = $descriptionIndex');

    if (productionTypeIndex == -1) {
      return {
        'success': false,
        'message': 'ستون «نوع تولید» پیدا نشد.\nهدرها: $headers'
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
        String productionType = _getCellValueDirect(row, productionTypeIndex);
        String size = sizeIndex != -1 ? _getCellValueDirect(row, sizeIndex) : '';
        String thickness = thicknessIndex != -1 ? _getCellValueDirect(row, thicknessIndex) : '';
        String length = lengthIndex != -1 ? _getCellValueDirect(row, lengthIndex) : '';
        String rawCountStr = rawCountIndex != -1 ? _getCellValueDirect(row, rawCountIndex) : '';
        String rawWeightStr = rawWeightIndex != -1 ? _getCellValueDirect(row, rawWeightIndex) : '';
        String totalWeightStr = totalWeightIndex != -1 ? _getCellValueDirect(row, totalWeightIndex) : '';
        String unit = unitIndex != -1 ? _getCellValueDirect(row, unitIndex) : 'کیلوگرم';
        String date = dateIndex != -1 ? _getCellValueDirect(row, dateIndex) : '';
        String status = statusIndex != -1 ? _getCellValueDirect(row, statusIndex) : 'در حال تولید';
        String description = descriptionIndex != -1 ? _getCellValueDirect(row, descriptionIndex) : '';

        rawCountStr = rawCountStr.replaceAll(RegExp(r'[$,]'), '').trim();
        rawWeightStr = rawWeightStr.replaceAll(RegExp(r'[$,]'), '').trim();
        totalWeightStr = totalWeightStr.replaceAll(RegExp(r'[$,]'), '').trim();

        print('📝 ROW $i:');
        print('  prodType   = "$productionType"');
        print('  size       = "$size"');
        print('  thickness  = "$thickness"');
        print('  length     = "$length"');
        print('  rawCount   = "$rawCountStr"');
        print('  rawWeight  = "$rawWeightStr"');
        print('  totalWeight= "$totalWeightStr"');
        print('  unit       = "$unit"');
        print('  date       = "$date"');

        if (productionType.isEmpty) {
          skippedCount++;
          errors.add('ردیف $i: نوع تولید خالی است');
          continue;
        }

        int rawCount = _parseNumber(rawCountStr).toInt();
        double rawWeight = _parseNumber(rawWeightStr);
        double totalWeight = _parseNumber(totalWeightStr);

        if (totalWeight <= 0 && rawCount > 0 && rawWeight > 0) {
          totalWeight = rawCount * rawWeight;
        }
        if (rawWeight <= 0 && rawCount > 0 && totalWeight > 0) {
          rawWeight = totalWeight / rawCount;
        }
        if (rawCount <= 0 && rawWeight > 0 && totalWeight > 0) {
          rawCount = (totalWeight / rawWeight).round();
        }

        String dateFinal = date.isEmpty
            ? PersianDateConverter.gregorianToJalali(DateTime.now())
            : date;
        String dateEn = PersianDateConverter.getEnglishDate(DateTime.now());

        String unitFinal = unit.isEmpty ? 'کیلوگرم' : unit;

        final trimmedSize = size.trim();
        final trimmedThickness = thickness.trim();

        if (trimmedSize.isNotEmpty && trimmedThickness.isNotEmpty) {
          try {
            final db = await _db.database;
            final existing = await db.query(
              'produced_products',
              where: 'TRIM(COALESCE(size, \'\')) = ? AND TRIM(COALESCE(thickness, \'\')) = ?',
              whereArgs: [trimmedSize, trimmedThickness],
              limit: 1,
            );

            if (existing.isNotEmpty) {
              final e = existing.first;
              final existingId = e['id'] as int;
              final existingRawCount = int.tryParse(e['raw_count']?.toString() ?? '0') ?? 0;
              final existingTotalWeight = double.tryParse(e['total_weight']?.toString() ?? '0') ?? 0;
              final existingRemainingStock = double.tryParse(e['remaining_stock']?.toString() ?? '0') ?? 0;

              final newRawCount = existingRawCount + rawCount;
              final newTotalWeight = existingTotalWeight + totalWeight;
              final newRemainingStock = existingRemainingStock + totalWeight;
              final newRawWeight = newRawCount > 0 ? newTotalWeight / newRawCount : rawWeight;

              final updatePayload = {
                'raw_count': newRawCount,
                'raw_weight': newRawWeight,
                'total_weight': newTotalWeight,
                'remaining_stock': newRemainingStock,
                'unit': e['unit']?.toString() ?? unitFinal,
                'production_date': dateFinal,
                'production_date_en': dateEn,
                'status': status,
                'description': description,
              };

              await _db.updateProducedProduct(existingId, updatePayload);

              // ✅ Save this production separately in production_logs
              try {
                final db2 = await _db.database;
                await db2.insert('production_logs', {
                  'produced_product_id': existingId,
                  'production_type': productionType,
                  'size': trimmedSize,
                  'thickness': trimmedThickness,
                  'length': length,
                  'raw_count': rawCount,
                  'raw_weight': rawWeight,
                  'total_weight': totalWeight,
                  'unit': unitFinal,
                  'production_date': dateFinal,
                  'production_date_en': dateEn,
                  'status': status,
                  'description': description,
                });
              } catch (logErr) {
                print('⚠️ Failed to save production log: $logErr');
              }

              successCount++;
              importedData.add(updatePayload);
              print('🔀 Row $i merged into #$existingId');
              continue;
            }
          } catch (e) {
            print('⚠️ Duplicate check error: $e');
          }
        }

        final product = {
          'product_name': productionType,
          'production_type': productionType,
          'size': size,
          'thickness': thickness,
          'length': length,
          'raw_count': rawCount,
          'raw_weight': rawWeight,
          'total_weight': totalWeight,
          'unit': unitFinal,
          'production_date': dateFinal,
          'production_date_en': dateEn,
          'status': status,
          'description': description,
          'remaining_stock': totalWeight,
        };

        int result = await _db.insertProducedProduct(product);
        if (result != -1) {
          successCount++;
          importedData.add(product);
        } else {
          skippedCount++;
          errors.add('ردیف $i: خطا در ذخیره‌سازی');
        }

      } catch (e) {
        skippedCount++;
        errors.add('ردیف $i: خطا - ${e.toString()}');
        print('❌ Row error: $e');
      }
    }

    return {
      'success': true,
      'successCount': successCount,
      'skippedCount': skippedCount,
      'mergedCount': 0,
      'importedData': importedData,
      'errors': errors,
      'message': '✅ $successCount ردیف وارد شد. '
          '$skippedCount نادیده گرفته شد.',
    };

  } catch (e) {
    print('❌ Fatal error: $e');
    return {'success': false, 'message': 'خطا: $e'};
  }
}

  void _showImportResultDialog(BuildContext context, Map<String, dynamic> result) {
    final merged = result['mergedCount'] ?? 0;
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
                if (merged > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '🔀 $merged رکورد با محصولات موجود تلفیق شد',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ],
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
        child: const Text(
          'فروخته شده',
          style: TextStyle(
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

  // ============================================================
  // PRODUCTION DETAILS FOR A SINGLE PRODUCT
  // ============================================================
  Future<Map<String, dynamic>> _getProductProductionDetails(
    int currentProductId,
    String size,
    String thickness, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final db = await _db.database;

      final trimmedSize = size.trim();
      final trimmedThickness = thickness.trim();

      if (trimmedSize.isEmpty || trimmedThickness.isEmpty) {
        final row = await db.query(
          'produced_products',
          where: 'id = ?',
          whereArgs: [currentProductId],
          limit: 1,
        );
        if (row.isEmpty) {
          return {
            'rows': <Map<String, dynamic>>[],
            'produced_weight': 0.0,
            'produced_units': 0,
            'row_count': 0,
          };
        }
        final r = row.first;
        final w = double.tryParse(r['total_weight']?.toString() ?? '0') ?? 0;
        final u = int.tryParse(r['raw_count']?.toString() ?? '0') ?? 0;
        return {
          'rows': [r],
          'produced_weight': w,
          'produced_units': u,
          'row_count': 1,
        };
      }

      String dateClause = '';
      final List<dynamic> dateArgs = [];
      if (fromDate != null && toDate != null) {
        final toInclusive = toDate.add(const Duration(days: 1));
        dateClause = " AND date(COALESCE(production_date_en, '')) >= date(?) "
                     "AND date(COALESCE(production_date_en, '')) < date(?)";
        dateArgs.add(fromDate.toIso8601String().split('T').first);
        dateArgs.add(toInclusive.toIso8601String().split('T').first);
      }

      final rows = await db.rawQuery('''
        SELECT *
        FROM produced_products
        WHERE TRIM(COALESCE(size, '')) = ?
          AND TRIM(COALESCE(thickness, '')) = ?
          $dateClause
        ORDER BY created_at DESC
      ''', [trimmedSize, trimmedThickness, ...dateArgs]);

      double producedWeight = 0;
      int producedUnits = 0;
      for (final r in rows) {
        final w = double.tryParse(r['total_weight']?.toString() ?? '0') ?? 0;
        final u = int.tryParse(r['raw_count']?.toString() ?? '0') ?? 0;
        producedWeight += w;
        producedUnits += u;
      }

      return {
        'rows': rows,
        'produced_weight': producedWeight,
        'produced_units': producedUnits,
        'row_count': rows.length,
      };
    } catch (e) {
      print('❌ Error getting product production details: $e');
      return {
        'rows': <Map<String, dynamic>>[],
        'produced_weight': 0.0,
        'produced_units': 0,
        'row_count': 0,
      };
    }
  }

  String _formatWeightForUnit(double weight, String unit) {
    if (_isWeightUnit(unit)) {
      final tons = weight / 1000;
      if (tons < 0.01 && tons > 0) return '${tons.toStringAsFixed(3)} تن';
      return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} $unit';
  }

  Widget _specItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _miniHeader(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A2E),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _miniCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: Color(0xFF1A1A2E)),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ============================================================
  // VIEW PRODUCT DETAILS MODAL (PRODUCTION HISTORY)
  // ============================================================
  void _showProductDetailsDialog(
    BuildContext context,
    Map<String, dynamic> product,
    AppLocalizations l10n,
  ) {
    String selectedFilter = 'today';
    Map<String, dynamic> prodDetails = {
      'rows': <Map<String, dynamic>>[],
      'produced_weight': 0.0,
      'produced_units': 0,
      'row_count': 0,
    };
    bool loadingDetails = true;
    bool loadedOnce = false;

    final unit = product['unit']?.toString() ?? '';
    final totalWeight = double.tryParse(product['total_weight']?.toString() ?? '0') ?? 0;
    final remainingStock = double.tryParse(product['remaining_stock']?.toString() ?? '0') ?? 0;
    final rawCount = int.tryParse(product['raw_count']?.toString() ?? '0') ?? 0;
    final rawWeight = double.tryParse(product['raw_weight']?.toString() ?? '0') ?? 0;
    final size = product['size']?.toString() ?? '';
    final thickness = product['thickness']?.toString() ?? '';
    final isWeight = _isWeightUnit(unit);

    String fmtWeight(double kg) {
      if (isWeight) {
        final tons = kg / 1000;
        if (tons < 0.01 && tons > 0) return '${tons.toStringAsFixed(3)} تن';
        return '${tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2)} تن';
      }
      return '${kg.toStringAsFixed(kg % 1 == 0 ? 0 : 1)} $unit';
    }

    (DateTime?, DateTime?) rangeForFilter(String filter) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      switch (filter) {
        case 'today':
          return (todayStart, now);
        case 'week':
          return (todayStart.subtract(const Duration(days: 6)), now);
        case 'month':
          return (DateTime(now.year, now.month, 1), now);
        default:
          return (null, null);
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) {
          Future<void> loadForFilter() async {
            setModalState(() => loadingDetails = true);
            final range = rangeForFilter(selectedFilter);

            // ✅ Fetch from production_logs (separate entries) instead of produced_products
            final logs = await _db.getProductionLogsBySizeThickness(
              size,
              thickness,
              fromDate: range.$1,
              toDate: range.$2,
            );

            double producedWeight = 0;
            int producedUnits = 0;
            for (final r in logs) {
              producedWeight += double.tryParse(r['total_weight']?.toString() ?? '0') ?? 0;
              producedUnits += int.tryParse(r['raw_count']?.toString() ?? '0') ?? 0;
            }

            final details = {
              'rows': logs,
              'produced_weight': producedWeight,
              'produced_units': producedUnits,
              'row_count': logs.length,
            };

            if (!dialogContext.mounted) return;
            setModalState(() {
              prodDetails = details;
              loadingDetails = false;
              loadedOnce = true;
            });
          }

          if (!loadedOnce) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialogContext.mounted && !loadedOnce) {
                loadForFilter();
              }
            });
          }

          final producedWeight = (prodDetails['produced_weight'] as double?) ?? 0;
          final producedUnits = (prodDetails['produced_units'] as int?) ?? 0;
          final rowsList = (prodDetails['rows'] as List?) ?? [];

          Widget statTile({
            required String label,
            required String value,
            required IconData icon,
            required Color color,
            String? sub,
          }) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.18), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            );
          }

          Widget filterChip(String key, String label) {
            final active = selectedFilter == key;
            return GestureDetector(
              onTap: () {
                if (selectedFilter == key) return;
                setModalState(() => selectedFilter = key);
                loadForFilter();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFCB001D) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? const Color(0xFFCB001D)
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCB001D).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2,
                        color: Color(0xFFCB001D), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['production_type']?.toString() ?? '-',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          'شناسه #${product['id']} • '
                          'سایز: ${size.isEmpty ? "-" : size} • '
                          'ضخامت: ${thickness.isEmpty ? "-" : thickness}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 640,
                height: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SPECS
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _specItem('سایز', size.isEmpty ? '-' : size),
                            _specItem('ضخامت', thickness.isEmpty ? '-' : thickness),
                            _specItem('طول', product['length']?.toString() ?? '-'),
                            _specItem('واحد', unit.isEmpty ? '-' : unit),
                            _specItem('وضعیت', product['status']?.toString() ?? '-'),
                            _specItem(
                              'وزن فی خاده',
                              '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} ${isWeight ? "کیلوگرم" : unit}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // FILTERS
                      Row(
                        children: [
                          const Icon(Icons.filter_alt,
                              size: 16, color: Color(0xFFCB001D)),
                          const SizedBox(width: 6),
                          const Text(
                            'دوره تولید:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(width: 10),
                          filterChip('today', 'امروز'),
                          const SizedBox(width: 6),
                          filterChip('week', 'این هفته'),
                          const SizedBox(width: 6),
                          filterChip('month', 'این ماه'),
                          const SizedBox(width: 6),
                          filterChip('all', 'همه'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // STATS
                      Row(
                        children: [
                          Expanded(
                            child: statTile(
                              label: 'تولید کل (کل تاریخچه)',
                              value: fmtWeight(totalWeight),
                              sub: '$rawCount خاده • روی این ردیف',
                              icon: Icons.factory_rounded,
                              color: const Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: statTile(
                              label: 'موجود در گدام',
                              value: fmtWeight(remainingStock),
                              sub: totalWeight > 0
                                  ? '${((remainingStock / totalWeight) * 100).clamp(0, 100).toStringAsFixed(1)}% از کل'
                                  : '-',
                              icon: Icons.warehouse_rounded,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: statTile(
                              label: 'تولید در دوره انتخابی',
                              value: fmtWeight(producedWeight),
                              sub: '$producedUnits خاده • ${rowsList.length} ردیف',
                              icon: Icons.add_box_rounded,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: statTile(
                              label: 'تعداد ردیف‌های دوره',
                              value: '${rowsList.length}',
                              sub: 'مطابق سایز + ضخامت',
                              icon: Icons.list_alt_rounded,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // PRODUCTION HISTORY LIST
                      Row(
                        children: [
                          const Icon(Icons.history,
                              size: 16, color: Color(0xFFCB001D)),
                          const SizedBox(width: 6),
                          Text(
                            'سوابق تولید (${rowsList.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (loadingDetails)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFCB001D),
                            ),
                          ),
                        )
                      else if (rowsList.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.inbox_outlined,
                                  color: Colors.grey.shade400, size: 32),
                              const SizedBox(height: 6),
                              Text(
                                'تولیدی در این دوره برای این سایز و ضخامت ثبت نشده',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCB001D).withOpacity(0.06),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _miniHeader('شناسه', 45),
                                    _miniHeader('نوع تولید', 100),
                                    _miniHeader('تعداد خاده', 60),
                                    _miniHeader('وزن فی خاده', 70),
                                    _miniHeader('مجموع وزن', 80),
                                    _miniHeader('وضعیت', 65),
                                    _miniHeader('تاریخ', 80),
                                  ],
                                ),
                              ),
                              ...rowsList.map((r) {
                                final rUnit = r['unit']?.toString() ?? unit;
                                final rRawWeight =
                                    double.tryParse(r['raw_weight']?.toString() ?? '0') ?? 0;
                                final rTotalWeight =
                                    double.tryParse(r['total_weight']?.toString() ?? '0') ?? 0;
                                final rCount = int.tryParse(r['raw_count']?.toString() ?? '0') ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                          color: Colors.grey.shade100,
                                          width: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _miniCell('#${r['id'] ?? '-'}', 45),
                                      _miniCell(
                                          r['production_type']?.toString() ?? '-', 100),
                                      _miniCell('$rCount', 60),
                                      _miniCell(
                                        '${rRawWeight.toStringAsFixed(rRawWeight % 1 == 0 ? 0 : 1)} ${_isWeightUnit(rUnit) ? "kg" : rUnit}',
                                        70,
                                      ),
                                      _miniCell(
                                        _formatWeightForUnit(rTotalWeight, rUnit),
                                        80,
                                      ),
                                      _miniCell(r['status']?.toString() ?? '-', 65),
                                      _miniCell(
                                        r['production_date']?.toString() ??
                                            r['production_date_en']?.toString() ??
                                            '-',
                                        80,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),
                      if (product['description']?.toString().isNotEmpty == true)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.notes,
                                  size: 16, color: Colors.amber.shade800),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  product['description'].toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('بستن',
                      style: TextStyle(color: Color(0xFF888888))),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showProductDialog(context, l10n, product: product);
                  },
                  icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                  label: const Text('ویرایش',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // PRODUCT DIALOG (ADD / EDIT)
  // ============================================================
  void _showProductDialog(BuildContext context, AppLocalizations l10n, {Map<String, dynamic>? product}) {
    final isEditing = product != null;
    
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
          double totalWeight = double.tryParse(totalWeightController.text) ?? 0;
          
          bool isWeightUnit = selectedUnit == 'کیلوگرم' || selectedUnit == 'kg' || selectedUnit == 'Kg' || 
                             selectedUnit == 'تن' || selectedUnit == 'ton' || selectedUnit == 'Ton';
          
          String totalWeightDisplay;
          String totalWeightInTons;
          
          if (isWeightUnit) {
            double tons = totalWeight / 1000;
            totalWeightInTons = tons.toStringAsFixed(tons % 1 == 0 ? 0 : 2);
            totalWeightDisplay = '$totalWeightInTons تن';
          } else {
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
                      TextField(
                        controller: productionTypeController,
                        decoration: const InputDecoration(
                          labelText: 'نوع تولید *',
                          border: OutlineInputBorder(), 
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      TextField(
                        controller: sizeController,
                        decoration: const InputDecoration(
                          labelText: 'سایز',
                          border: OutlineInputBorder(), 
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: thicknessController,
                              decoration: const InputDecoration(
                                labelText: 'ضخامت',
                                border: OutlineInputBorder(), 
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lengthController,
                              decoration: const InputDecoration(
                                labelText: 'طول',
                                border: OutlineInputBorder(), 
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: rawCountController,
                              decoration: const InputDecoration(
                                labelText: 'تعداد خاده *',
                                border: OutlineInputBorder(), 
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(() {
                                _calculateTotalWeight();
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: rawWeightController,
                              decoration: const InputDecoration(
                                labelText: 'وزن فی خاده * (کیلوگرم)', 
                                border: OutlineInputBorder(), 
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                helperText: 'همیشه بر حسب کیلوگرم وارد کنید',
                                helperStyle: TextStyle(fontSize: 9, color: Colors.grey),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(() {
                                _calculateTotalWeight();
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
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
                                const Text(
                                  'مجموع وزن',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const Spacer(),
                                if (totalWeight > 0)
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
                                  )
                                else
                                  const Text(
                                    '0',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
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
                      
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'واحد *', 
                                border: OutlineInputBorder(), 
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: dateController,
                              decoration: const InputDecoration(
                                labelText: 'تاریخ *', 
                                border: OutlineInputBorder(), 
                                suffixIcon: Icon(Icons.calendar_today, color: Color(0xFFCB001D), size: 18), 
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'وضعیت', 
                          border: OutlineInputBorder(), 
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      
                      TextField(
                        controller: descriptionController, 
                        maxLines: 2, 
                        decoration: const InputDecoration(
                          labelText: 'توضیحات', 
                          border: OutlineInputBorder(), 
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    if (productionTypeController.text.isEmpty || 
                        rawCountController.text.isEmpty || 
                        selectedUnit == null || 
                        dateController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لطفاً تمام فیلدهای الزامی (*) را پر کنید'), 
                          backgroundColor: Colors.red
                        )
                      );
                      return;
                    }

                    final rawCount = int.tryParse(rawCountController.text) ?? 0;
                    final rawWeight = double.tryParse(rawWeightController.text) ?? 0;
                    final totalWeight = rawCount * rawWeight;

                    final trimmedSize = sizeController.text.trim();
                    final trimmedThickness = thicknessController.text.trim();

                    Navigator.pop(context);

                    if (!isEditing && trimmedSize.isNotEmpty && trimmedThickness.isNotEmpty) {
                      try {
                        final db = await _db.database;
                        final existing = await db.query(
                          'produced_products',
                          where: 'TRIM(COALESCE(size, \'\')) = ? AND TRIM(COALESCE(thickness, \'\')) = ?',
                          whereArgs: [trimmedSize, trimmedThickness],
                          limit: 1,
                        );

                        if (existing.isNotEmpty) {
                          final e = existing.first;
                          final existingId = e['id'] as int;
                          final existingRawCount = int.tryParse(e['raw_count']?.toString() ?? '0') ?? 0;
                          final existingTotalWeight = double.tryParse(e['total_weight']?.toString() ?? '0') ?? 0;
                          final existingRemainingStock = double.tryParse(e['remaining_stock']?.toString() ?? '0') ?? 0;

                          final newRawCount = existingRawCount + rawCount;
                          final newTotalWeight = existingTotalWeight + totalWeight;
                          final newRemainingStock = existingRemainingStock + totalWeight;
                          final newRawWeight = newRawCount > 0 ? newTotalWeight / newRawCount : rawWeight;

                          final updatePayload = {
                            'raw_count': newRawCount,
                            'raw_weight': newRawWeight,
                            'total_weight': newTotalWeight,
                            'remaining_stock': newRemainingStock,
                            'unit': e['unit']?.toString() ?? selectedUnit ?? 'متر',
                            'production_date': dateController.text,
                            'production_date_en': selectedEnglishDate ?? e['production_date_en'] ?? '',
                            'status': selectedStatus ?? e['status'] ?? 'در حال تولید',
                            'description': descriptionController.text.isNotEmpty
                                ? descriptionController.text
                                : (e['description']?.toString() ?? ''),
                          };

                          final upd = await _db.updateProducedProduct(existingId, updatePayload);

                          // ✅ Save this production separately in production_logs
                          try {
                            final db2 = await _db.database;
                            await db2.insert('production_logs', {
                              'produced_product_id': existingId,
                              'production_type': productionTypeController.text,
                              'size': trimmedSize,
                              'thickness': trimmedThickness,
                              'length': lengthController.text,
                              'raw_count': rawCount,
                              'raw_weight': rawWeight,
                              'total_weight': totalWeight,
                              'unit': selectedUnit ?? e['unit'] ?? '',
                              'production_date': dateController.text,
                              'production_date_en': selectedEnglishDate ?? '',
                              'status': selectedStatus ?? 'در حال تولید',
                              'description': descriptionController.text,
                            });
                          } catch (logErr) {
                            print('⚠️ Failed to save production log: $logErr');
                          }

                          if (!mounted) return;

                          if (upd != -1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '🔀 سایز و ضخامت یکسان یافت شد — به محصول موجود اضافه شد\n'
                                  'تعداد خاده: $existingRawCount + $rawCount = $newRawCount\n'
                                  'مجموع وزن: ${existingTotalWeight.toStringAsFixed(1)} + ${totalWeight.toStringAsFixed(1)} = ${newTotalWeight.toStringAsFixed(1)} کیلوگرم'
                                ),
                                backgroundColor: Colors.blue.shade700,
                                duration: const Duration(seconds: 5),
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
                          return;
                        }
                      } catch (err) {
                        print('⚠️ Error during duplicate check: $err');
                      }
                    }

                    final payload = {
                      'production_type': productionTypeController.text,
                      'size': trimmedSize,
                      'thickness': trimmedThickness,
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
                                      'actions': 88.0,
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
                                                
                                                String displayRawWeight;
                                                if (_isWeightUnit(unit)) {
                                                  displayRawWeight = '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} کیلوگرم';
                                                } else {
                                                  displayRawWeight = '${rawWeight.toStringAsFixed(rawWeight % 1 == 0 ? 0 : 1)} $unit';
                                                }
                                                
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

                                                      SizedBox(
                                                        width: columnWidths['status']!,
                                                        child: Center(
                                                          child: _buildStatusChip(product['status']?.toString(), l10n),
                                                        ),
                                                      ),
                                                      
                                                      SizedBox(
                                                        width: columnWidths['saleStatus']!,
                                                        child: Center(
                                                          child: _buildSoldStatusChip(product, l10n),
                                                        ),
                                                      ),
                                                      
                                                      // ACTIONS COLUMN (View + Edit + Delete)
                                                      SizedBox(
                                                        width: columnWidths['actions']!,
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            // VIEW
                                                            Container(
                                                              width: 24,
                                                              height: 24,
                                                              decoration: BoxDecoration(
                                                                color: Colors.blue.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: IconButton(
                                                                icon: Icon(Icons.visibility_outlined,
                                                                    color: Colors.blue.shade700, size: 13),
                                                                padding: EdgeInsets.zero,
                                                                constraints: const BoxConstraints(),
                                                                onPressed: () => _showProductDetailsDialog(context, product, l10n),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 2),
                                                            // EDIT
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
                                                            // DELETE
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class RawMaterialsPage extends StatefulWidget {
  const RawMaterialsPage({super.key});

  @override
  State<RawMaterialsPage> createState() => _RawMaterialsPageState();
}

class _RawMaterialsPageState extends State<RawMaterialsPage> {
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> suppliers = [];
  bool isLoading = true;
  final DatabaseHelper _db = DatabaseHelper();

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;

  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50, 100];

  // Selection
  final Set<int> _selectedIds = {};

  // Class level variable for English date
  String? selectedEnglishDate;

  // Scroll controller for horizontal scrolling
  final ScrollController _horizontalScrollController = ScrollController();

  // Helper to check if unit is weight-based
  bool _isWeightUnit(String unit) {
    return unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg' ||
        unit == 'تن' || unit == 'ton' || unit == 'Ton';
  }

  // Get total tons of all raw materials
  double _getTotalTons() {
    double totalTons = 0;
    for (var material in materials) {
      String unit = material['unit'] ?? '';
      double grossWeight = double.tryParse(material['gross_weight']?.toString() ?? '0') ?? 0;

      if (_isWeightUnit(unit)) {
        if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') {
          totalTons += grossWeight / 1000;
        } else {
          totalTons += grossWeight;
        }
      }
    }
    return totalTons;
  }

  // ============================================================
  // ✅ TOTAL VALUE BY CURRENCY (sum of final_price)
  // ============================================================
  double _getTotalValueByCurrency(String currencyCode) {
    double total = 0;
    for (var material in materials) {
      final String currency = material['currency']?.toString() ?? 'AFN';
      if (currency == currencyCode) {
        total += double.tryParse(material['final_price']?.toString() ?? '0') ?? 0;
      }
    }
    return total;
  }

  // ============================================================
  // ✅ FORMAT NUMBER WITH THOUSANDS SEPARATOR
  // ============================================================
  String _formatNumber(double value) {
    final String s = value.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';
    final RegExp re = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final String withSep = intPart.replaceAllMapped(re, (m) => ',');
    return '$withSep.$decPart';
  }

  // Unit translation helper - FOR TABLE DISPLAY ONLY
  String _translateUnit(String unit, AppLocalizations l10n) {
    if (_isWeightUnit(unit)) return l10n.tonUnit;
    if (unit == 'متر' || unit == 'm' || unit == 'M') return l10n.meterUnit;
    if (unit == 'عدد' || unit == 'pcs' || unit == 'Pcs') return l10n.pcsUnit;
    if (unit == 'لیتر' || unit == 'l' || unit == 'L') return l10n.literUnit;
    return unit;
  }

  // Format unit with conversion for table display
  String _formatUnitWithConversion(String unit, double weight, AppLocalizations l10n) {
    if (_isWeightUnit(unit)) {
      double tons = weight / 1000;
      return '${tons.toStringAsFixed(1)} ${l10n.tonUnit}';
    }
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} ${_translateUnit(unit, l10n)}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final materialsData = await _db.getRawMaterials();
      final suppliersData = await _db.getSuppliers();
      setState(() {
        materials = materialsData;
        suppliers = suppliersData;
        isLoading = false;
        _selectedIds.clear();
        _currentPage = 1;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
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
    String cleaned = value.replaceAll(RegExp(r'[,\s]'), '');
    if (cleaned.isEmpty) return 0;
    try {
      return double.parse(cleaned);
    } catch (e) {
      return 0;
    }
  }

  // ============================================================
  // ✅ ROBUST HEADER NORMALIZER
  // ============================================================
  String _normalizeHeaderForMatch(String input) {
    if (input.isEmpty) return '';
    return input
        .replaceAll('\u200e', '')
        .replaceAll('\u200f', '')
        .replaceAll('\u200c', '')
        .replaceAll('\u200d', '')
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('«', '')
        .replaceAll('»', '')
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ة', 'ه')
        .replaceAll('ۀ', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '')
        .trim()
        .toLowerCase();
  }

  // ============================================================
  // ✅ FLEXIBLE HEADER MAP BUILDER
  // ============================================================
  Map<String, int> _buildHeaderIndexMap(List<String> headers) {
    final Map<String, List<String>> aliases = {
      'name': [
        'ناممواد', 'نامماده', 'نام', 'اسممواد', 'اسمماده',
        'نام کالا', 'نامکالا', 'کالا', 'ماده', 'مواد',
        'material', 'materialname', 'name',
      ],
      'supplier': [
        'اسمفروشنده', 'نامفروشنده', 'فروشنده', 'اسم فروشنده', 'نام فروشنده',
        'تأمینکننده', 'تامینکننده', 'تامین کننده', 'تأمین کننده',
        'supplier', 'suppliername', 'vendor',
      ],
      'net_weight': [
        'وزنخالص', 'وزن خالص', 'وزنخالص(kg)', 'وزنخالص(کیلوگرم)',
        'netweight', 'netwt', 'net',
      ],
      'gross_weight': [
        'وزنناخالص', 'وزن ناخالص', 'وزنناخالص(kg)', 'وزنناخالص(کیلوگرم)',
        'grossweight', 'grosswt', 'gross',
      ],
      'date': [
        'تاریخ', 'تاریخورود', 'تاریخ خرید', 'تاریخخرید',
        'date', 'datein', 'entrydate',
      ],
      'unit': [
        'واحد', 'واحد اندازهگیری', 'واحداندازهگیری', 'یونیت',
        'unit', 'uom',
      ],
      'unit_price': [
        'قیمتواحد', 'قیمت واحد', 'قیمت هر تن', 'قیمتهرتن', 'قیمت تن',
        'unitprice', 'price', 'priceperton',
      ],
      'location': [
        'محلتخلیه', 'محل تخلیه', 'محل', 'تخلیه', 'انبار',
        'location', 'dischargelocation', 'warehouse',
      ],
      'material_type': [
        'نوعمواد', 'نوع ماده', 'نوعماده', 'نوع', 'دسته',
        'materialtype', 'type', 'category',
      ],
      'thickness': [
        'ضخامت', 'ضخامت(mm)', 'ضخامتملیمتر', 'ضخامت میل',
        'thickness', 'thick', 'mm',
      ],
      'product': [
        'قیمتمحصول', 'قیمت محصول', 'محصول', 'هزینه محصول',
        'product', 'productprice', 'productcost',
      ],
      'commission': [
        'کمیشن', 'کمیسیون', 'پورسانت', 'دلالی',
        'commission', 'brokerage',
      ],
      'transfer_cost': [
        'هزینهحمل', 'هزینه حمل', 'حمل', 'کرایه', 'ترانسپورت',
        'transfercost', 'transport', 'freight', 'shipping',
      ],
      'miscellaneous': [
        'متفرقه', 'متفرق', 'هزینههایمتفرقه', 'سایر',
        'miscellaneous', 'misc', 'other',
      ],
      'ghurfedari': [
        'غرفهداری', 'غرفه داری', 'غرفه', 'انبارداری',
        'ghurfedari', 'storage', 'warehousing',
      ],
      'barchalani': [
        'برچالانی', 'برچالان', 'بارچالانی', 'بارگیری',
        'barchalani', 'loading',
      ],
      'purchase_type': [
        'نوعخرید', 'نوع خرید', 'خرید',
        'purchasetype', 'purchase',
      ],
      'payment_method': [
        'روشپرداخت', 'روش پرداخت', 'نحوهپرداخت', 'نحوه پرداخت',
        'پرداخت', 'نوع پرداخت',
        'paymentmethod', 'payment', 'paytype',
      ],
      'currency': [
        'واحدپول', 'واحد پول', 'واحدپولی', 'ارز', 'نوعارز', 'نوع ارز', 'پول',
        'currency', 'curr', 'money',
      ],
      'exchange_rate': [
        'نرخارز', 'نرخ ارز', 'نرخ', 'تبدیل',
        'exchangerate', 'rate', 'fx',
      ],
    };

    final List<String> normHeaders = headers.map(_normalizeHeaderForMatch).toList();

    final Map<String, int> result = {};
    for (final field in aliases.keys) {
      result[field] = -1;
      final fieldAliases = aliases[field]!
          .map(_normalizeHeaderForMatch)
          .toList();

      for (int i = 0; i < normHeaders.length; i++) {
        if (fieldAliases.contains(normHeaders[i])) {
          result[field] = i;
          break;
        }
      }
      if (result[field] == -1) {
        for (int i = 0; i < normHeaders.length; i++) {
          final h = normHeaders[i];
          if (h.isEmpty) continue;
          final matches = fieldAliases.any((a) =>
              h == a ||
              h.startsWith(a) ||
              h.endsWith(a) ||
              (a.length >= 3 && h.contains(a)));
          if (matches) {
            result[field] = i;
            break;
          }
        }
      }
    }

    return result;
  }

  // ============================================================
  // ✅ PARSE PERSIAN DATE FROM EXCEL → RETURN BOTH FA & EN
  // ============================================================
  ({String persian, String english})? _parsePersianDateFromExcel(String raw) {
    if (raw.isEmpty) return null;

    String cleaned = _convertPersianToEnglishDigits(raw.trim());
    cleaned = cleaned.replaceAll(RegExp(r'[/\.\-\s]+'), '-');

    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(cleaned);
    if (match == null) return null;

    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);

    if (year < 1300 || year > 1500 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final persian = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    try {
      final DateTime gregorian = _jalaliToGregorian(year, month, day);
      final english = PersianDateConverter.getEnglishDate(gregorian);
      return (persian: persian, english: english);
    } catch (e) {
      print('⚠️ Failed to convert Persian date "$raw": $e');
      return null;
    }
  }

  // ============================================================
  // ✅ JALALI → GREGORIAN (self-contained)
  // ============================================================
  DateTime _jalaliToGregorian(int jy, int jm, int jd) {
    int gy;
    if (jy > 979) {
      gy = 1600;
      jy -= 979;
    } else {
      gy = 621;
    }
    int days = (365 * jy) +
        ((jy ~/ 33) * 8) +
        (((jy % 33) + 3) ~/ 4) +
        78 +
        jd +
        ((jm < 7) ? (jm - 1) * 31 : ((jm - 7) * 30) + 186);
    gy += 400 * (days ~/ 146097);
    days %= 146097;
    if (days > 36524) {
      gy += 100 * (--days ~/ 36524);
      days %= 36524;
      if (days >= 365) days++;
    }
    gy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      gy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    int gd = days + 1;
    final sal_a = [
      0, 31, ((gy % 4 == 0 && gy % 100 != 0) || (gy % 400 == 0)) ? 29 : 28,
      31, 30, 31, 30, 31, 31, 30, 31, 30, 31
    ];
    int gm;
    for (gm = 0; gm < 13; gm++) {
      final v = sal_a[gm];
      if (gd <= v) break;
      gd -= v;
    }
    return DateTime(gy, gm, gd);
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
      final excelFile = excel.Excel.decodeBytes(bytes);

      final sheet = excelFile.tables[excelFile.tables.keys.first];
      if (sheet == null) {
        return {'success': false, 'message': 'فایل اکسل معتبر نیست'};
      }

      return await _parseExcelSheet(sheet);
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

      print('=== EXCEL SHEET DEBUG ===');
      print('Total rows: ${sheet.rows.length}');
      for (int i = 0; i < sheet.rows.length && i < 5; i++) {
        final row = sheet.rows[i];
        List<String> cellValues = [];
        for (var cell in row) {
          cellValues.add(cell?.value?.toString() ?? '');
        }
        print('Row $i: $cellValues');
      }
      print('=== END DEBUG ===');

      // ============ FIND HEADER ROW ============
      List<String> headers = [];
      int headerRowIndex = -1;

      for (int i = 0; i < sheet.rows.length && i < 20; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final List<String> potentialHeaders = [];
        for (var cell in row) {
          if (cell != null && cell.value != null) {
            final val = cell.value.toString().trim();
            if (val.isNotEmpty) potentialHeaders.add(val);
          }
        }

        final norm = potentialHeaders.map(_normalizeHeaderForMatch).toList();

        final hasName = norm.any((h) =>
            h.contains('ناممواد') || h.contains('نامماده') || h == 'نام' || h.contains('اسممواد'));
        final hasSupplier = norm.any((h) =>
            h.contains('فروشنده') || h.contains('تأمین') || h.contains('تامین'));
        final hasWeight = norm.any((h) => h.contains('وزن'));
        final hasDate = norm.any((h) => h.contains('تاریخ'));

        final score = [hasName, hasSupplier, hasWeight, hasDate].where((b) => b).length;

        if (score >= 2 && potentialHeaders.length >= 3) {
          headers = potentialHeaders;
          headerRowIndex = i;
          break;
        }
      }

      if (headers.isEmpty) {
        return {'success': false, 'message': 'هیچ ستونی پیدا نشد'};
      }

      print('=== HEADERS FOUND (row $headerRowIndex) ===');
      for (int i = 0; i < headers.length; i++) {
        print('  [$i] "${headers[i]}"  →  "${_normalizeHeaderForMatch(headers[i])}"');
      }

      // ============ BUILD COLUMN INDEX MAP ============
      final Map<String, int> idx = _buildHeaderIndexMap(headers);

      final int nameIndex = idx['name']!;
      final int supplierIndex = idx['supplier']!;
      final int netWeightIndex = idx['net_weight']!;
      final int grossWeightIndex = idx['gross_weight']!;
      final int dateIndex = idx['date']!;
      final int unitIndex = idx['unit']!;
      final int unitPriceIndex = idx['unit_price']!;
      final int locationIndex = idx['location']!;
      final int materialTypeIndex = idx['material_type']!;
      final int thicknessIndex = idx['thickness']!;
      final int productIndex = idx['product']!;
      final int commissionIndex = idx['commission']!;
      final int transferCostIndex = idx['transfer_cost']!;
      final int miscellaneousIndex = idx['miscellaneous']!;
      final int ghurfedariIndex = idx['ghurfedari']!;
      final int barchalaniIndex = idx['barchalani']!;
      final int purchaseTypeIndex = idx['purchase_type']!;
      final int paymentMethodIndex = idx['payment_method']!;
      final int currencyIndex = idx['currency']!;
      final int exchangeRateIndex = idx['exchange_rate']!;

      print('=== COLUMN INDICES ===');
      print('  name:           $nameIndex');
      print('  supplier:       $supplierIndex');
      print('  net_weight:     $netWeightIndex');
      print('  gross_weight:   $grossWeightIndex');
      print('  date:           $dateIndex');
      print('  currency:       $currencyIndex');
      print('  exchange_rate:  $exchangeRateIndex');
      print('=== END INDICES ===');

      if (nameIndex == -1 || supplierIndex == -1 || netWeightIndex == -1 || grossWeightIndex == -1) {
        String msg = '';
        if (nameIndex == -1) msg += 'نام مواد، ';
        if (supplierIndex == -1) msg += 'اسم فروشنده، ';
        if (netWeightIndex == -1) msg += 'وزن خالص، ';
        if (grossWeightIndex == -1) msg += 'وزن ناخالص، ';
        return {
          'success': false,
          'message': 'فیلدهای مورد نیاز پیدا نشد: $msg'
        };
      }

      final suppliers = await _db.getSuppliers();
      Map<String, int> supplierMap = {};
      for (var supplier in suppliers) {
        supplierMap[supplier['name']?.toString() ?? ''] = supplier['id'];
      }

      for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        bool rowHasData = false;
        for (var cell in row) {
          if (cell != null && cell.value != null) {
            String val = cell.value.toString().trim();
            if (val.isNotEmpty && val != '0' && val != '-') {
              rowHasData = true;
              break;
            }
          }
        }

        if (!rowHasData) continue;

        try {
          String name = _getCellValueDirect(row, nameIndex);
          String supplierName = _getCellValueDirect(row, supplierIndex);
          String netWeightStr = _getCellValueDirect(row, netWeightIndex);
          String grossWeightStr = _getCellValueDirect(row, grossWeightIndex);

          String date = _getCellValueDirect(row, dateIndex);
          String unit = _getCellValueDirect(row, unitIndex);
          String unitPriceStr = _getCellValueDirect(row, unitPriceIndex);
          String location = _getCellValueDirect(row, locationIndex);
          String materialType = _getCellValueDirect(row, materialTypeIndex);
          String thickness = _getCellValueDirect(row, thicknessIndex);
          String productStr = _getCellValueDirect(row, productIndex);
          String commissionStr = _getCellValueDirect(row, commissionIndex);
          String transferCostStr = _getCellValueDirect(row, transferCostIndex);
          String miscellaneousStr = _getCellValueDirect(row, miscellaneousIndex);
          String ghurfedariStr = _getCellValueDirect(row, ghurfedariIndex);
          String barchalaniStr = _getCellValueDirect(row, barchalaniIndex);
          String purchaseType = _getCellValueDirect(row, purchaseTypeIndex);
          String paymentMethod = _getCellValueDirect(row, paymentMethodIndex);
          String currency = _getCellValueDirect(row, currencyIndex);
          String exchangeRateStr = _getCellValueDirect(row, exchangeRateIndex);

          // AUTO DEFAULTS
          if (unit.isEmpty) unit = 'کیلوگرم';
          if (currency.isEmpty) currency = 'AFN';
          if (exchangeRateStr.isEmpty) exchangeRateStr = '1';
          if (paymentMethod.isEmpty) paymentMethod = 'cash';
          if (purchaseType.isEmpty) purchaseType = 'مستقیم';

          print('=== ROW ${i+1} RAW VALUES ===');
          print('  currency raw: "$currency"');
          print('  exchangeRate raw: "$exchangeRateStr"');
          print('  unitPrice raw: "$unitPriceStr"');
          print('  netWeight raw: "$netWeightStr"');
          print('  date raw: "$date"');
          print('=== END ROW ===');

          // Normalize currency
          String currencyNorm = currency.trim().toLowerCase();
          if (currencyNorm == 'افغانی' || currencyNorm == 'afn' || currencyNorm.isEmpty ||
              currencyNorm == 'افغانى' || currencyNorm == 'افغانی' || currencyNorm.contains('افغان')) {
            currency = 'AFN';
          } else if (currencyNorm == 'دالر' || currencyNorm == 'دلار' || currencyNorm == 'usd' ||
              currencyNorm == 'دالر امریکایی' || currencyNorm == 'دالر امریکائی' ||
              currencyNorm.contains('دالر') || currencyNorm.contains('دلار') ||
              currencyNorm.contains('usd')) {
            currency = 'USD';
          } else {
            currency = 'AFN';
          }

          print('  currency normalized: "$currency"');

          // Normalize payment method
          String pmNorm = paymentMethod.trim();
          if (pmNorm == 'نقد' || pmNorm == 'cash' || pmNorm == 'Cash' || pmNorm.contains('نقد')) {
            paymentMethod = 'cash';
          } else if (pmNorm == 'قرض کامل' || pmNorm == 'loan_full' || pmNorm.contains('قرض کامل')) {
            paymentMethod = 'loan_full';
          } else if (pmNorm == 'قرض جزئی' || pmNorm == 'loan_partial' || pmNorm.contains('قرض جزئ')) {
            paymentMethod = 'loan_partial';
          } else {
            paymentMethod = 'cash';
          }

          if (name.isEmpty || supplierName.isEmpty || netWeightStr.isEmpty || grossWeightStr.isEmpty) {
            skippedCount++;
            errors.add('ردیف ${i+1}: فیلدهای مورد نیاز کامل نیستند');
            continue;
          }

          double netWeight = _parseNumber(netWeightStr);
          double grossWeight = _parseNumber(grossWeightStr);

          if (netWeight <= 0 || grossWeight <= 0) {
            skippedCount++;
            errors.add('ردیف ${i+1}: وزن نامعتبر');
            continue;
          }

          int? supplierId = supplierMap[supplierName];
          if (supplierId == null) {
            supplierId = await _db.insertSupplier({
              'name': supplierName,
              'phone': '',
              'address': location,
            });
            if (supplierId != -1) {
              supplierMap[supplierName] = supplierId;
            } else {
              skippedCount++;
              errors.add('ردیف ${i+1}: خطا در ایجاد فروشنده');
              continue;
            }
          }

          // ============================================================
          // CALCULATION - expenses always in AFN
          // ============================================================
          double unitPrice = _parseNumber(unitPriceStr);
          double product = _parseNumber(productStr);
          double commission = _parseNumber(commissionStr);
          double transferCost = _parseNumber(transferCostStr);
          double miscellaneous = _parseNumber(miscellaneousStr);
          double ghurfedari = _parseNumber(ghurfedariStr);
          double barchalani = _parseNumber(barchalaniStr);
          double exchangeRate = _parseNumber(exchangeRateStr);

          if (exchangeRate <= 0) exchangeRate = 1;

          double netWeightInTons = (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg')
              ? netWeight / 1000
              : netWeight;

          double basePrice = netWeightInTons * unitPrice;

          double totalAfnExpenses = product + commission + transferCost +
              miscellaneous + ghurfedari + barchalani;

          double expensesInPriceCurrency;
          if (currency == 'USD') {
            expensesInPriceCurrency = totalAfnExpenses / exchangeRate;
          } else {
            expensesInPriceCurrency = totalAfnExpenses;
          }

          double finalPrice = basePrice + expensesInPriceCurrency;
          double sellerPayment = basePrice;

          double sellerPaidAmount = 0;
          if (paymentMethod == 'cash') {
            sellerPaidAmount = basePrice;
          } else {
            sellerPaidAmount = 0;
          }

          print('=== CALCULATION ROW ${i+1} ===');
          print('  finalPrice: $finalPrice');
          print('=== END CALC ===');

          // ============================================================
          // FIXED DATE HANDLING — Parse Persian date from Excel
          // ============================================================
          String dateEn;
          if (date.isEmpty) {
            final now = DateTime.now();
            date = PersianDateConverter.gregorianToJalali(now);
            dateEn = PersianDateConverter.getEnglishDate(now);
          } else {
            final parsed = _parsePersianDateFromExcel(date);
            if (parsed != null) {
              date = parsed.persian;
              dateEn = parsed.english;
            } else {
              final now = DateTime.now();
              date = PersianDateConverter.gregorianToJalali(now);
              dateEn = PersianDateConverter.getEnglishDate(now);
            }
          }

          print('📅 Row ${i+1}: Excel date="$date" | English date="$dateEn"');

          Map<String, dynamic> material = {
            'supplier_id': supplierId,
            'name': name,
            'location': location,
            'material_type': materialType,
            'thickness': thickness,
            'net_weight': netWeight.toString(),
            'gross_weight': grossWeight.toString(),
            'date': date,
            'date_en': dateEn,
            'unit': unit,
            'unit_price': unitPrice.toString(),
            'product': product > 0 ? product.toString() : '0',
            'commission': commission > 0 ? commission.toString() : '0',
            'transfer_cost': transferCost > 0 ? transferCost.toString() : '0',
            'miscellaneous': miscellaneous > 0 ? miscellaneous.toString() : '0',
            'ghurfedari': ghurfedari > 0 ? ghurfedari.toString() : '0',
            'barchalani': barchalani > 0 ? barchalani.toString() : '0',
            'purchase_type': purchaseType,
            'seller_payment': sellerPayment.toStringAsFixed(0),
            'seller_payment_method': paymentMethod,
            'seller_paid_amount': sellerPaidAmount.toStringAsFixed(0),
            'currency': currency,
            'exchange_rate': exchangeRate,
            'final_price': finalPrice.toStringAsFixed(1),
          };

          int result = await _db.insertRawMaterial(material);
          if (result != -1) {
            successCount++;
            importedData.add(material);

            if (paymentMethod != 'cash') {
              final remainingSeller = (sellerPayment - sellerPaidAmount) < 0
                  ? 0.0
                  : (sellerPayment - sellerPaidAmount);

              final loanPayload = {
                'supplier_id': supplierId,
                'raw_material_id': result,
                'invoice_number': 'SL-${DateTime.now().millisecondsSinceEpoch}',
                'supplier_name': supplierName,
                'supplier_company': location,
                'total_amount': sellerPayment,
                'paid_amount': paymentMethod == 'loan_full' ? 0.0 : sellerPaidAmount,
                'remaining_amount': remainingSeller,
                'loan_type': paymentMethod == 'loan_full' ? 'full' : 'partial',
                'currency': currency,
                'date': date.trim(),
                'date_en': dateEn,
                'description': 'خرید مواد خام از فروشنده (وارد شده از اکسل)',
              };

              final loanId = await _db.insertSupplierLoan(loanPayload);

              if (loanId != -1 && sellerPaidAmount > 0 && paymentMethod == 'loan_partial') {
                await _db.insertSupplierLoanPayment({
                  'loan_id': loanId,
                  'amount': sellerPaidAmount,
                  'note': 'پرداخت اولیه فروشنده هنگام وارد کردن از اکسل',
                  'date': date.trim(),
                  'date_en': dateEn,
                });
              }
            }
          } else {
            skippedCount++;
            errors.add('ردیف ${i+1}: خطا در ذخیره‌سازی');
          }

        } catch (e) {
          skippedCount++;
          errors.add('ردیف ${i+1}: خطا - $e');
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

  String _getCellValueDirect(List<excel.Data?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    final cell = row[index];
    if (cell == null) return '';
    if (cell.value == null) return '';

    String value = cell.value.toString().trim();
    if (value.isNotEmpty) {
      value = _convertPersianToEnglishDigits(value);
    }
    return value;
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

  // ============ BUILD UNIT SUMMARY CARDS ============
  List<Widget> _buildUnitSummaryCards(AppLocalizations l10n) {
    Map<String, Map<String, double>> unitTotals = {};

    for (var material in materials) {
      String unit = material['unit'] ?? 'نامشخص';
      double netWeight = double.tryParse(material['net_weight']?.toString() ?? '0') ?? 0;
      double grossWeight = double.tryParse(material['gross_weight']?.toString() ?? '0') ?? 0;

      if (!unitTotals.containsKey(unit)) {
        unitTotals[unit] = {'net': 0, 'gross': 0};
      }
      unitTotals[unit]!['net'] = (unitTotals[unit]!['net'] ?? 0) + netWeight;
      unitTotals[unit]!['gross'] = (unitTotals[unit]!['gross'] ?? 0) + grossWeight;
    }

    if (unitTotals.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFCB001D).withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Text(
            l10n.noRawMaterialsInStock,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 13,
            ),
          ),
        ),
      ];
    }

    List<Widget> cards = [];
    unitTotals.forEach((unit, totals) {
      final translatedUnit = _translateUnit(unit, l10n);

      String displayNet = _formatUnitWithConversion(unit, totals['net']!, l10n);
      String displayGross = _formatUnitWithConversion(unit, totals['gross']!, l10n);

      cards.add(
        Container(
          width: 170,
          margin: const EdgeInsets.only(left: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFCB001D).withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCB001D).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.scale,
                      color: Color(0xFFCB001D),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    unit == 'نامشخص' ? l10n.noUnit : translatedUnit,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCB001D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.netWeight,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888),
                    ),
                  ),
                  Text(
                    displayNet,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.grossWeight,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888),
                    ),
                  ),
                  Text(
                    displayGross,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFFCB001D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });

    return cards;
  }

  // ============================================================
  // ✅ SMALL TILE WIDGET USED INSIDE THE TOP SUMMARY CARD
  // ============================================================
  Widget _buildValueSummaryTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ BUILD MAIN TABLE ============
  Widget _buildMainTable(AppLocalizations l10n) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)));
    }

    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warehouse_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(l10n.noRawMaterialsFound, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.06), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.05),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: _paginatedMaterials.isNotEmpty &&
                                    _paginatedMaterials.every((m) =>
                                        _selectedIds.contains(m['id'] as int)),
                                onChanged: (_) => _toggleSelectAll(),
                                activeColor: const Color(0xFFCB001D),
                                checkColor: Colors.white,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildHeaderCell(l10n.id, 60),
                            _buildHeaderCell(l10n.materialName, 90),
                            _buildHeaderCell(l10n.supplierName, 120),
                            _buildHeaderCell(l10n.supplierPhone, 90),
                            _buildHeaderCell(l10n.supplierAddress, 120),
                            _buildHeaderCell(l10n.date, 100),
                            _buildHeaderCell(l10n.unit, 60),
                            _buildHeaderCell(l10n.netWeight, 65),
                            _buildHeaderCell(l10n.grossWeight, 65),
                            _buildHeaderCell('ضخامت', 60),
                            _buildHeaderCell(l10n.unitPrice, 65),
                            _buildHeaderCell('واحد پول', 65),
                            _buildHeaderCell('نرخ ارز', 60),
                            _buildHeaderCell(l10n.sellerBasePrice, 80),
                            _buildHeaderCell(l10n.initialPayment, 80),
                            _buildHeaderCell(l10n.paymentMethod, 80),
                            _buildHeaderCell(l10n.product, 60),
                            _buildHeaderCell(l10n.commission, 60),
                            _buildHeaderCell(l10n.transferCost, 60),
                            _buildHeaderCell(l10n.miscellaneous, 60),
                            _buildHeaderCell(l10n.ghurfedari, 60),
                            _buildHeaderCell(l10n.barchalani, 60),
                            _buildHeaderCell(l10n.purchaseType, 70),
                            _buildHeaderCell(l10n.finalPrice, 80),
                            _buildHeaderCell(l10n.actions, 80),
                          ],
                        ),
                      ),
                      ..._paginatedMaterials.map((material) {
                        final isSelected = _selectedIds.contains(material['id'] as int);
                        final translatedUnit = _translateUnit(material['unit'] ?? '-', l10n);

                        double netWeight = double.tryParse(material['net_weight']?.toString() ?? '0') ?? 0;
                        double grossWeight = double.tryParse(material['gross_weight']?.toString() ?? '0') ?? 0;
                        String unit = material['unit'] ?? '-';

                        String displayNet = _formatUnitWithConversion(unit, netWeight, l10n);
                        String displayGross = _formatUnitWithConversion(unit, grossWeight, l10n);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                  onChanged: (_) => _toggleSelection(material['id'] as int),
                                  activeColor: const Color(0xFFCB001D),
                                  checkColor: Colors.white,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildDataCell(material['id'].toString(), 60),
                              _buildDataCell(material['name'] ?? '-', 90),
                              _buildDataCell(material['supplier_name'] ?? '-', 120),
                              _buildDataCell(material['supplier_phone'] ?? '-', 90),
                              _buildDataCell(material['supplier_address'] ?? '-', 120),
                              Container(
                                width: 100,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      material['date_en'] ?? '-',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      material['date'] ?? '-',
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
                              _buildDataCell(translatedUnit, 60),
                              _buildDataCell(displayNet, 65),
                              _buildDataCell(displayGross, 65),
                              _buildDataCell(material['thickness'] ?? '-', 60),
                              _buildDataCell(material['unit_price'] ?? '-', 65),
                              _buildDataCell(material['currency']?.toString() ?? 'AFN', 65),
                              _buildDataCell(material['exchange_rate']?.toString() ?? '1', 60),
                              _buildDataCell('${material['seller_payment'] ?? '-'} ${material['currency'] ?? 'AFN'}', 80),
                              _buildDataCell('${material['seller_paid_amount'] ?? '-'} ${material['currency'] ?? 'AFN'}', 80),
                              _buildDataCell(material['seller_payment_method'] == 'cash'
                                  ? l10n.cash
                                  : material['seller_payment_method'] == 'loan_full'
                                      ? l10n.fullLoan
                                      : material['seller_payment_method'] == 'loan_partial'
                                          ? l10n.partialLoan
                                          : '-', 80),
                              _buildDataCell(material['product'] ?? '-', 60),
                              _buildDataCell(material['commission'] ?? '-', 60),
                              _buildDataCell(material['transfer_cost'] ?? '-', 60),
                              _buildDataCell(material['miscellaneous'] ?? '-', 60),
                              _buildDataCell(material['ghurfedari'] ?? '-', 60),
                              _buildDataCell(material['barchalani'] ?? '-', 60),
                              Container(
                                width: 70,
                                child: _buildPurchaseTypeChip(material['purchase_type'], l10n),
                              ),
                              _buildDataCell('${material['final_price'] ?? '-'} ${material['currency'] ?? 'AFN'}', 80, isBold: true, isRed: true),
                              SizedBox(
                                width: 80,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, color: const Color(0xFFCB001D), size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showEditDialog(context, material, l10n),
                                      tooltip: l10n.edit,
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showDeleteDialog(context, material, l10n),
                                      tooltip: l10n.delete,
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
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
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
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _itemsPerPage,
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
                  Text(l10n.perPage, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFCB001D), size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30),
                    onPressed: () {
                      _horizontalScrollController.animateTo(
                        _horizontalScrollController.offset - 200,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    tooltip: 'Scroll Left',
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFFCB001D), size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30),
                    onPressed: () {
                      _horizontalScrollController.animateTo(
                        _horizontalScrollController.offset + 200,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    tooltip: 'Scroll Right',
                  ),
                  const SizedBox(width: 8),
                  Text('${l10n.page} $_currentPage ${l10n.pageOf} $_totalPages',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
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
    );
  }

  List<Map<String, dynamic>> get _paginatedMaterials {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= materials.length) {
      _currentPage = 1;
      return materials.take(_itemsPerPage).toList();
    }
    return materials.sublist(
      start,
      end > materials.length ? materials.length : end,
    );
  }

  int get _totalPages => (materials.length / _itemsPerPage).ceil();

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
      final currentIds = _paginatedMaterials
          .map((item) => item['id'] as int)
          .toList();
      final allSelected =
          currentIds.every((id) => _selectedIds.contains(id));
      if (allSelected) {
        _selectedIds.removeAll(currentIds);
      } else {
        _selectedIds.addAll(currentIds);
      }
    });
  }

  // ============================================================
  // BULK DELETE - SELECTED RAW MATERIALS
  // ============================================================
  void _showBulkDeleteDialog(BuildContext context, AppLocalizations l10n) {
    final count = _selectedIds.length;
    if (count == 0) return;

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_sweep,
                    color: Colors.red, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'حذف مواد خام انتخاب شده',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
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
                    border: Border.all(
                        color: Colors.red.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'هشدار!',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'شما در حال حذف $count ماده خام هستید. '
                              'قرض‌های مربوطه نیز پاک می‌شوند. '
                              'این عمل قابل بازگشت نیست!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'مواد خام زیر حذف خواهند شد:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _selectedIds.map((id) {
                        final material = materials.firstWhere(
                          (m) => m['id'] == id,
                          orElse: () => {},
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• #$id — ${material['name'] ?? '-'} '
                            '(فروشنده: ${material['supplier_name'] ?? '-'})',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF1A1A2E)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف',
                  style: TextStyle(color: Color(0xFF888888))),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _performBulkDelete(_selectedIds.toList());
              },
              icon: const Icon(Icons.delete_forever,
                  color: Colors.white, size: 18),
              label: Text('حذف $count مورد',
                  style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BULK DELETE - ALL RAW MATERIALS
  // ============================================================
  void _showDeleteAllDialog(BuildContext context, AppLocalizations l10n) {
    final count = materials.length;
    if (count == 0) return;

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dangerous,
                    color: Colors.red, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'حذف تمام مواد خام',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.red.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'هشدار جدی!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'شما در حال حذف تمام $count ماده خام هستید.\n'
                    'تمام قرض‌های فروشندگان و پرداخت‌های مربوطه نیز پاک خواهند شد.\n'
                    'این عمل کاملاً غیرقابل بازگشت است!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف',
                  style: TextStyle(color: Color(0xFF888888))),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _performDeleteAll();
              },
              icon: const Icon(Icons.delete_forever,
                  color: Colors.white, size: 18),
              label: const Text('حذف همه',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PERFORM BULK DELETE
  // ============================================================
  Future<void> _performBulkDelete(List<int> ids) async {
    setState(() => isLoading = true);
    try {
      final deleted = await _db.deleteMultipleRawMaterials(ids);
      if (!mounted) return;

      if (deleted > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $deleted ماده خام با موفقیت حذف شد'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        await _loadData();
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ خطا در حذف مواد خام'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطا: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // PERFORM DELETE ALL
  // ============================================================
  Future<void> _performDeleteAll() async {
    setState(() => isLoading = true);
    try {
      final deleted = await _db.deleteAllRawMaterials();
      if (!mounted) return;

      if (deleted >= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ تمام $deleted ماده خام حذف شدند'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        await _loadData();
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ خطا در حذف تمام مواد خام'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطا: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 9,
          color: Color(0xFF1A1A2E),
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
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
          fontSize: 9,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPurchaseTypeChip(String? purchaseType, AppLocalizations l10n) {
    final type = purchaseType ?? l10n.unknown;
    final isDirect = type == l10n.direct;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDirect ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDirect ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDirect ? Icons.check_circle : Icons.remove_circle,
            color: isDirect ? Colors.green : Colors.orange,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            type,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: isDirect ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ============ ADD DIALOG ============
  void _showAddDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final netWeightController = TextEditingController();
    final grossWeightController = TextEditingController();
    final thicknessController = TextEditingController();
    final materialTypeController = TextEditingController();
    final locationController = TextEditingController();
    final dateController = TextEditingController();
    final unitController = TextEditingController();
    final unitPriceController = TextEditingController();
    final productController = TextEditingController();
    final commissionController = TextEditingController();
    final transferCostController = TextEditingController();
    final miscellaneousController = TextEditingController();
    final ghurfedariController = TextEditingController();
    final barchalaniController = TextEditingController();
    final finalPriceController = TextEditingController();
    final sellerPaymentController = TextEditingController();
    final sellerPaidAmountController = TextEditingController();
    final exchangeRateController = TextEditingController(text: '1');
    final afnEquivalentController = TextEditingController();

    String selectedSellerPaymentMethod = 'cash';
    String selectedCurrency = 'AFN';
    String? selectedPurchaseType;
    String? selectedSupplierId;
    String? selectedDate;

    String _convertToTon(double weight) {
      if (weight <= 0) return '0';
      double tons = weight / 1000;
      return tons.toStringAsFixed(1);
    }

    String _getUnitSymbol(String unit) {
      if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') return 'تن';
      if (unit == 'تن' || unit == 'ton' || unit == 'Ton') return 'تن';
      if (unit == 'متر' || unit == 'm' || unit == 'M') return 'متر';
      if (unit == 'عدد' || unit == 'pcs' || unit == 'Pcs') return 'عدد';
      if (unit == 'لیتر' || unit == 'l' || unit == 'L') return 'لیتر';
      return unit;
    }

    void _updateFinalPrice() {
      double netWeight = double.tryParse(netWeightController.text) ?? 0;
      String selectedUnit = unitController.text;

      double netWeightInTons = netWeight;
      if (selectedUnit == 'کیلوگرم' || selectedUnit == 'kg' || selectedUnit == 'Kg') {
        netWeightInTons = netWeight / 1000;
      }

      double unitPrice = double.tryParse(unitPriceController.text) ?? 0;

      double productCost = double.tryParse(productController.text) ?? 0;
      double commission = double.tryParse(commissionController.text) ?? 0;
      double transferCost = double.tryParse(transferCostController.text) ?? 0;
      double miscellaneous = double.tryParse(miscellaneousController.text) ?? 0;
      double ghurfedari = double.tryParse(ghurfedariController.text) ?? 0;
      double barchalani = double.tryParse(barchalaniController.text) ?? 0;

      double exchangeRate = double.tryParse(exchangeRateController.text) ?? 1;
      if (exchangeRate <= 0) exchangeRate = 1;

      double basePrice = netWeightInTons * unitPrice;

      double totalAfnExpenses = productCost + commission + transferCost +
          miscellaneous + ghurfedari + barchalani;

      double expensesInPriceCurrency;
      if (selectedCurrency == 'USD') {
        expensesInPriceCurrency = totalAfnExpenses / exchangeRate;
      } else {
        expensesInPriceCurrency = totalAfnExpenses;
      }

      double finalPrice = basePrice + expensesInPriceCurrency;

      finalPriceController.text = finalPrice.toStringAsFixed(2);

      double afnEquivalent;
      if (selectedCurrency == 'USD') {
        afnEquivalent = finalPrice * exchangeRate;
      } else {
        afnEquivalent = finalPrice;
      }

      afnEquivalentController.text = afnEquivalent.toStringAsFixed(0);

      sellerPaymentController.text = basePrice.toStringAsFixed(2);

      if (selectedSellerPaymentMethod == 'cash') {
        sellerPaidAmountController.text = sellerPaymentController.text;
      } else if ((selectedSellerPaymentMethod == 'loan_full' || selectedSellerPaymentMethod == 'loan_partial') && sellerPaidAmountController.text.isEmpty) {
        sellerPaidAmountController.text = '0';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          double netWeight = double.tryParse(netWeightController.text) ?? 0;
          double grossWeight = double.tryParse(grossWeightController.text) ?? 0;
          String selectedUnit = unitController.text;

          String netTon = _convertToTon(netWeight);
          String grossTon = _convertToTon(grossWeight);
          bool isKg = selectedUnit == 'کیلوگرم' || selectedUnit == 'kg' || selectedUnit == 'Kg';

          String unitDisplay = '';
          if (selectedUnit == 'کیلوگرم' || selectedUnit == 'kg' || selectedUnit == 'Kg') {
            unitDisplay = 'kg';
          } else if (selectedUnit == 'تن' || selectedUnit == 'ton' || selectedUnit == 'Ton') {
            unitDisplay = 'تن';
          } else {
            unitDisplay = selectedUnit;
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(l10n.addRawMaterial),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.selectSupplier,
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: selectedSupplierId,
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text(l10n.selectSupplier)),
                          ...suppliers.map((supplier) {
                            return DropdownMenuItem<String>(
                              value: supplier['id'].toString(),
                              child: Text(supplier['name']),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedSupplierId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: dateController,
                        decoration: InputDecoration(
                          labelText: l10n.dateRequired,
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: const OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            setStateDialog(() {
                              dateController.text = persianDate;
                              selectedDate = persianDate;
                              selectedEnglishDate = englishDate;
                            });
                          }
                        },
                        readOnly: true,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n.materialNameRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText: l10n.dischargeLocationRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: materialTypeController,
                        decoration: InputDecoration(
                          labelText: l10n.materialTypeRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.unitRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: unitController.text.isNotEmpty ? unitController.text : null,
                        items: [
                          DropdownMenuItem<String>(value: 'کیلوگرم', child: Text(l10n.kgUnit)),
                          DropdownMenuItem<String>(value: 'تن', child: Text(l10n.tonUnit)),
                          DropdownMenuItem<String>(value: 'متر', child: Text(l10n.meterUnit)),
                          DropdownMenuItem<String>(value: 'عدد', child: Text(l10n.pcsUnit)),
                          DropdownMenuItem<String>(value: 'لیتر', child: Text(l10n.literUnit)),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            unitController.text = value ?? '';
                            _updateFinalPrice();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: thicknessController,
                        decoration: InputDecoration(
                          labelText: l10n.thicknessRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.purchaseTypeRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: selectedPurchaseType,
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text(l10n.selectPurchaseType)),
                          DropdownMenuItem<String>(value: 'مستقیم', child: Text(l10n.direct)),
                          DropdownMenuItem<String>(value: 'غیر مستقیم', child: Text(l10n.indirect)),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedPurchaseType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: netWeightController,
                            decoration: InputDecoration(
                              labelText: l10n.netWeightRequired,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              setStateDialog(() {});
                              _updateFinalPrice();
                            },
                          ),
                          if (netWeight > 0 && selectedUnit.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                    if (isKg) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$netWeight kg',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, color: const Color(0xFFCB001D), size: 14),
                                      const SizedBox(width: 8),
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
                                          '$netTon تن',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFCB001D),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$netWeight $unitDisplay',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: grossWeightController,
                            decoration: InputDecoration(
                              labelText: l10n.grossWeightRequired,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              setStateDialog(() {});
                              _updateFinalPrice();
                            },
                          ),
                          if (grossWeight > 0 && selectedUnit.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                    if (isKg) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$grossWeight kg',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, color: const Color(0xFFCB001D), size: 14),
                                      const SizedBox(width: 8),
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
                                          '$grossTon تن',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFCB001D),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$grossWeight $unitDisplay',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: unitPriceController,
                                  decoration: InputDecoration(
                                    labelText: '${l10n.unitPrice} (${selectedCurrency}) *',
                                    hintText: 'قیمت هر تن',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _updateFinalPrice(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedCurrency,
                                  decoration: InputDecoration(
                                    labelText: l10n.currencyPrice,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'AFN', child: Text('افغانی')),
                                    DropdownMenuItem(value: 'USD', child: Text('دلار')),
                                  ],
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      selectedCurrency = value ?? 'AFN';
                                      _updateFinalPrice();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (selectedUnit.isNotEmpty && netWeight > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'قیمت بر اساس هر تن محاسبه می‌شود',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: exchangeRateController,
                        decoration: InputDecoration(
                          labelText: selectedCurrency == 'USD'
                              ? 'نرخ ارز (USD به AFN)'
                              : 'نرخ ارز (AFN به USD)',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateFinalPrice(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: productController,
                        decoration: InputDecoration(
                          labelText: l10n.productPrice,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateFinalPrice(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sellerPaymentController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: '${l10n.sellerAmount} (${selectedCurrency})',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB001D)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSellerPaymentMethod,
                              decoration: InputDecoration(
                                labelText: l10n.sellerPaymentMethod,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'cash', child: Text('نقد')),
                                DropdownMenuItem(value: 'loan_full', child: Text('قرض کامل')),
                                DropdownMenuItem(value: 'loan_partial', child: Text('قرض جزئی')),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  selectedSellerPaymentMethod = value ?? 'cash';
                                  if (selectedSellerPaymentMethod == 'cash') {
                                    sellerPaidAmountController.text = sellerPaymentController.text;
                                  } else {
                                    sellerPaidAmountController.text = '0';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (selectedSellerPaymentMethod == 'loan_partial') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: sellerPaidAmountController,
                          decoration: InputDecoration(
                            labelText: l10n.sellerInitialPayment,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        l10n.sellerLoanNote,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commissionController,
                              decoration: InputDecoration(
                                labelText: l10n.commission,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: transferCostController,
                              decoration: InputDecoration(
                                labelText: l10n.transferCost,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ghurfedariController,
                              decoration: InputDecoration(
                                labelText: l10n.ghurfedari,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: barchalaniController,
                              decoration: InputDecoration(
                                labelText: l10n.barchalani,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: miscellaneousController,
                              decoration: InputDecoration(
                                labelText: l10n.miscellaneous,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: finalPriceController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: '${l10n.finalTotalPrice} (${selectedCurrency})',
                                border: const OutlineInputBorder(),
                                fillColor: const Color(0xFFF5F0EB),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFCB001D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: afnEquivalentController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: selectedCurrency == 'USD'
                              ? 'معادل به افغانی (AFN)'
                              : 'معادل به دالر (USD)',
                          border: const OutlineInputBorder(),
                          fillColor: const Color(0xFFF5F0EB),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFCB001D),
                        ),
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
                    if (selectedSupplierId == null || nameController.text.isEmpty || selectedPurchaseType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.fillAllRequiredFields), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final sellerPayment = double.tryParse(sellerPaymentController.text) ?? 0;
                    final sellerPaidAmount = selectedSellerPaymentMethod == 'cash'
                        ? sellerPayment
                        : double.tryParse(sellerPaidAmountController.text) ?? 0;

                    if ((selectedSellerPaymentMethod == 'loan_full' || selectedSellerPaymentMethod == 'loan_partial') && sellerPaidAmount > sellerPayment) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.sellerPaymentExceedsBase), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final material = {
                      'supplier_id': int.parse(selectedSupplierId!),
                      'name': nameController.text,
                      'location': locationController.text,
                      'material_type': materialTypeController.text,
                      'thickness': thicknessController.text,
                      'net_weight': netWeightController.text,
                      'gross_weight': grossWeightController.text,
                      'date': dateController.text,
                      'date_en': selectedEnglishDate,
                      'unit': unitController.text,
                      'unit_price': unitPriceController.text,
                      'product': productController.text,
                      'commission': commissionController.text,
                      'transfer_cost': transferCostController.text,
                      'miscellaneous': miscellaneousController.text,
                      'ghurfedari': ghurfedariController.text,
                      'barchalani': barchalaniController.text,
                      'purchase_type': selectedPurchaseType,
                      'seller_payment': sellerPayment.toStringAsFixed(0),
                      'seller_payment_method': selectedSellerPaymentMethod,
                      'seller_paid_amount': sellerPaidAmount.toStringAsFixed(0),
                      'currency': selectedCurrency,
                      'exchange_rate': double.tryParse(exchangeRateController.text) ?? 1,
                      'final_price': finalPriceController.text,
                    };

                    final result = await _db.insertRawMaterial(material);

                    if (selectedSellerPaymentMethod != 'cash') {
                      final supplier = suppliers.firstWhere((s) => s['id'].toString() == selectedSupplierId, orElse: () => {});
                      final remainingSeller = (sellerPayment - sellerPaidAmount) < 0 ? 0 : (sellerPayment - sellerPaidAmount);
                      final loanPayload = {
                        'supplier_id': int.parse(selectedSupplierId!),
                        'raw_material_id': result,
                        'invoice_number': 'SL-${DateTime.now().millisecondsSinceEpoch}',
                        'supplier_name': supplier['name'] ?? 'فروشنده',
                        'supplier_company': supplier['address'] ?? '',
                        'total_amount': sellerPayment,
                        'paid_amount': selectedSellerPaymentMethod == 'loan_full' ? 0 : sellerPaidAmount,
                        'remaining_amount': remainingSeller,
                        'loan_type': selectedSellerPaymentMethod == 'loan_full' ? 'full' : 'partial',
                        'currency': selectedCurrency,
                        'date': dateController.text.trim(),
                        'date_en': selectedEnglishDate,
                        'description': 'خرید مواد خام از فروشنده',
                      };
                      final loanId = await _db.insertSupplierLoan(loanPayload);
                      if (loanId != -1 && sellerPaidAmount > 0) {
                        await _db.insertSupplierLoanPayment({
                          'loan_id': loanId,
                          'amount': sellerPaidAmount,
                          'note': 'پرداخت اولیه فروشنده هنگام ثبت ماده خام',
                          'date': dateController.text.trim(),
                          'date_en': selectedEnglishDate,
                        });
                      }
                    }

                    Navigator.pop(context);

                    if (result != -1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.rawMaterialAddedSuccess), backgroundColor: Colors.green),
                      );
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.errorAddingRawMaterial), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                  ),
                  child: Text(l10n.save),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> material, AppLocalizations l10n) {
    final nameController = TextEditingController(text: material['name']?.toString() ?? '');
    final netWeightController = TextEditingController(text: material['net_weight']?.toString() ?? '');
    final grossWeightController = TextEditingController(text: material['gross_weight']?.toString() ?? '');
    final thicknessController = TextEditingController(text: material['thickness']?.toString() ?? '');
    final materialTypeController = TextEditingController(text: material['material_type']?.toString() ?? '');
    final locationController = TextEditingController(text: material['location']?.toString() ?? '');
    final dateController = TextEditingController(text: material['date']?.toString() ?? '');
    final unitController = TextEditingController(text: material['unit']?.toString() ?? '');
    final unitPriceController = TextEditingController(text: material['unit_price']?.toString() ?? '');
    final productController = TextEditingController(text: material['product']?.toString() ?? '');
    final commissionController = TextEditingController(text: material['commission']?.toString() ?? '');
    final transferCostController = TextEditingController(text: material['transfer_cost']?.toString() ?? '');
    final miscellaneousController = TextEditingController(text: material['miscellaneous']?.toString() ?? '');
    final ghurfedariController = TextEditingController(text: material['ghurfedari']?.toString() ?? '');
    final barchalaniController = TextEditingController(text: material['barchalani']?.toString() ?? '');
    final finalPriceController = TextEditingController(text: material['final_price']?.toString() ?? '');
    final sellerPaymentController = TextEditingController(text: material['seller_payment']?.toString() ?? '');
    final sellerPaidAmountController = TextEditingController(text: material['seller_paid_amount']?.toString() ?? '');
    final exchangeRateController = TextEditingController(text: material['exchange_rate']?.toString() ?? '1');
    final afnEquivalentController = TextEditingController();

    String selectedSellerPaymentMethod = material['seller_payment_method']?.toString() ?? 'cash';
    String selectedCurrency = material['currency']?.toString() ?? 'AFN';
    String? selectedPurchaseType = material['purchase_type']?.toString();
    String? selectedSupplierId = material['supplier_id']?.toString();
    String? selectedDate = material['date']?.toString();
    String? selectedEnglishDate = material['date_en']?.toString();

    String _convertToTon(double weight) {
      if (weight <= 0) return '0';
      double tons = weight / 1000;
      return tons.toStringAsFixed(1);
    }

    String _getUnitSymbol(String unit) {
      if (unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg') return 'تن';
      if (unit == 'تن' || unit == 'ton' || unit == 'Ton') return 'تن';
      if (unit == 'متر' || unit == 'm' || unit == 'M') return 'متر';
      if (unit == 'عدد' || unit == 'pcs' || unit == 'Pcs') return 'عدد';
      if (unit == 'لیتر' || unit == 'l' || unit == 'L') return 'لیتر';
      return unit;
    }

    void _updateFinalPrice() {
      double netWeight = double.tryParse(netWeightController.text) ?? 0;
      String selectedUnit = unitController.text;

      double netWeightInTons = netWeight;
      if (selectedUnit == 'کیلوگرم' || selectedUnit == 'kg' || selectedUnit == 'Kg') {
        netWeightInTons = netWeight / 1000;
      }

      double unitPrice = double.tryParse(unitPriceController.text) ?? 0;

      double productCost = double.tryParse(productController.text) ?? 0;
      double commission = double.tryParse(commissionController.text) ?? 0;
      double transferCost = double.tryParse(transferCostController.text) ?? 0;
      double miscellaneous = double.tryParse(miscellaneousController.text) ?? 0;
      double ghurfedari = double.tryParse(ghurfedariController.text) ?? 0;
      double barchalani = double.tryParse(barchalaniController.text) ?? 0;

      double exchangeRate = double.tryParse(exchangeRateController.text) ?? 1;
      if (exchangeRate <= 0) exchangeRate = 1;

      double basePrice = netWeightInTons * unitPrice;

      double totalAfnExpenses = productCost + commission + transferCost +
          miscellaneous + ghurfedari + barchalani;

      double expensesInPriceCurrency;
      if (selectedCurrency == 'USD') {
        expensesInPriceCurrency = totalAfnExpenses / exchangeRate;
      } else {
        expensesInPriceCurrency = totalAfnExpenses;
      }

      double finalPrice = basePrice + expensesInPriceCurrency;
      finalPriceController.text = finalPrice.toStringAsFixed(1);

      if (selectedCurrency == 'USD') {
        afnEquivalentController.text = (finalPrice * exchangeRate).toStringAsFixed(1);
      } else {
        afnEquivalentController.text = exchangeRate > 0
            ? (finalPrice * exchangeRate).toStringAsFixed(1)
            : '0';
      }

      sellerPaymentController.text = basePrice.toStringAsFixed(0);
      if (selectedSellerPaymentMethod == 'cash') {
        sellerPaidAmountController.text = sellerPaymentController.text;
      } else if ((selectedSellerPaymentMethod == 'loan_full' || selectedSellerPaymentMethod == 'loan_partial') && sellerPaidAmountController.text.isEmpty) {
        sellerPaidAmountController.text = '0';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          double netWeight = double.tryParse(netWeightController.text) ?? 0;
          double grossWeight = double.tryParse(grossWeightController.text) ?? 0;
          String selectedUnit = unitController.text;

          String netTon = _convertToTon(netWeight);
          String grossTon = _convertToTon(grossWeight);
          bool isKg = selectedUnit == 'کیلوگرم' || selectedUnit == 'kg' || selectedUnit == 'Kg';

          String unitDisplay = '';
          if (selectedUnit == 'کیلوگرم' || selectedUnit == 'kg' || selectedUnit == 'Kg') {
            unitDisplay = 'kg';
          } else if (selectedUnit == 'تن' || selectedUnit == 'ton' || selectedUnit == 'Ton') {
            unitDisplay = 'تن';
          } else {
            unitDisplay = selectedUnit;
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('${l10n.edit} ${l10n.rawMaterial}'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.selectSupplier,
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: selectedSupplierId,
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text(l10n.selectSupplier)),
                          ...suppliers.map((supplier) {
                            return DropdownMenuItem<String>(
                              value: supplier['id'].toString(),
                              child: Text(supplier['name']),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedSupplierId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: dateController,
                        decoration: InputDecoration(
                          labelText: l10n.dateRequired,
                          labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                          border: const OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            setStateDialog(() {
                              dateController.text = persianDate;
                              selectedDate = persianDate;
                              selectedEnglishDate = englishDate;
                            });
                          }
                        },
                        readOnly: true,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n.materialNameRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText: l10n.dischargeLocationRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: materialTypeController,
                        decoration: InputDecoration(
                          labelText: l10n.materialTypeRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.unitRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: unitController.text.isNotEmpty ? unitController.text : null,
                        items: [
                          DropdownMenuItem<String>(value: 'کیلوگرم', child: Text(l10n.kgUnit)),
                          DropdownMenuItem<String>(value: 'تن', child: Text(l10n.tonUnit)),
                          DropdownMenuItem<String>(value: 'متر', child: Text(l10n.meterUnit)),
                          DropdownMenuItem<String>(value: 'عدد', child: Text(l10n.pcsUnit)),
                          DropdownMenuItem<String>(value: 'لیتر', child: Text(l10n.literUnit)),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            unitController.text = value ?? '';
                            _updateFinalPrice();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: thicknessController,
                        decoration: InputDecoration(
                          labelText: l10n.thicknessRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.purchaseTypeRequired,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        value: selectedPurchaseType,
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text(l10n.selectPurchaseType)),
                          DropdownMenuItem<String>(value: 'مستقیم', child: Text(l10n.direct)),
                          DropdownMenuItem<String>(value: 'غیر مستقیم', child: Text(l10n.indirect)),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedPurchaseType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: netWeightController,
                            decoration: InputDecoration(
                              labelText: l10n.netWeightRequired,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              setStateDialog(() {});
                              _updateFinalPrice();
                            },
                          ),
                          if (netWeight > 0 && selectedUnit.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                    if (isKg) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$netWeight kg',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, color: const Color(0xFFCB001D), size: 14),
                                      const SizedBox(width: 8),
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
                                          '$netTon تن',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFCB001D),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$netWeight $unitDisplay',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: grossWeightController,
                            decoration: InputDecoration(
                              labelText: l10n.grossWeightRequired,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              setStateDialog(() {});
                              _updateFinalPrice();
                            },
                          ),
                          if (grossWeight > 0 && selectedUnit.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                    if (isKg) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$grossWeight kg',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, color: const Color(0xFFCB001D), size: 14),
                                      const SizedBox(width: 8),
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
                                          '$grossTon تن',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFCB001D),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$grossWeight $unitDisplay',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: unitPriceController,
                                  decoration: InputDecoration(
                                    labelText: '${l10n.unitPrice} (${selectedCurrency}) *',
                                    hintText: 'قیمت هر تن',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _updateFinalPrice(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedCurrency,
                                  decoration: InputDecoration(
                                    labelText: l10n.currencyPrice,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'AFN', child: Text('افغانی')),
                                    DropdownMenuItem(value: 'USD', child: Text('دلار')),
                                  ],
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      selectedCurrency = value ?? 'AFN';
                                      _updateFinalPrice();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (selectedUnit.isNotEmpty && netWeight > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'قیمت بر اساس هر تن محاسبه می‌شود',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: exchangeRateController,
                        decoration: InputDecoration(
                          labelText: selectedCurrency == 'USD'
                              ? 'نرخ ارز (USD به AFN)'
                              : 'نرخ ارز (AFN به USD)',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateFinalPrice(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: productController,
                        decoration: InputDecoration(
                          labelText: l10n.productPrice,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateFinalPrice(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sellerPaymentController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: '${l10n.sellerAmount} (${selectedCurrency})',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCB001D)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSellerPaymentMethod,
                              decoration: InputDecoration(
                                labelText: l10n.sellerPaymentMethod,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'cash', child: Text('نقد')),
                                DropdownMenuItem(value: 'loan_full', child: Text('قرض کامل')),
                                DropdownMenuItem(value: 'loan_partial', child: Text('قرض جزئی')),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  selectedSellerPaymentMethod = value ?? 'cash';
                                  if (selectedSellerPaymentMethod == 'cash') {
                                    sellerPaidAmountController.text = sellerPaymentController.text;
                                  } else {
                                    sellerPaidAmountController.text = '0';
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (selectedSellerPaymentMethod == 'loan_partial') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: sellerPaidAmountController,
                          decoration: InputDecoration(
                            labelText: l10n.sellerInitialPayment,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        l10n.sellerLoanNote,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commissionController,
                              decoration: InputDecoration(
                                labelText: l10n.commission,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: transferCostController,
                              decoration: InputDecoration(
                                labelText: l10n.transferCost,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ghurfedariController,
                              decoration: InputDecoration(
                                labelText: l10n.ghurfedari,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: barchalaniController,
                              decoration: InputDecoration(
                                labelText: l10n.barchalani,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: miscellaneousController,
                              decoration: InputDecoration(
                                labelText: l10n.miscellaneous,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _updateFinalPrice(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: finalPriceController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: '${l10n.finalTotalPrice} (${selectedCurrency})',
                                border: const OutlineInputBorder(),
                                fillColor: const Color(0xFFF5F0EB),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFCB001D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: afnEquivalentController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: selectedCurrency == 'USD'
                              ? 'معادل به افغانی (AFN)'
                              : 'معادل به دالر (USD)',
                          border: const OutlineInputBorder(),
                          fillColor: const Color(0xFFF5F0EB),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFCB001D),
                        ),
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
                    if (selectedSupplierId == null || nameController.text.isEmpty || selectedPurchaseType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.fillAllRequiredFields), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final sellerPayment = double.tryParse(sellerPaymentController.text) ?? 0;
                    final sellerPaidAmount = selectedSellerPaymentMethod == 'cash'
                        ? sellerPayment
                        : double.tryParse(sellerPaidAmountController.text) ?? 0;

                    if ((selectedSellerPaymentMethod == 'loan_full' || selectedSellerPaymentMethod == 'loan_partial') && sellerPaidAmount > sellerPayment) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.sellerPaymentExceedsBase), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final updatedMaterial = {
                      'supplier_id': int.parse(selectedSupplierId!),
                      'name': nameController.text,
                      'location': locationController.text,
                      'material_type': materialTypeController.text,
                      'thickness': thicknessController.text,
                      'net_weight': netWeightController.text,
                      'gross_weight': grossWeightController.text,
                      'date': dateController.text,
                      'date_en': selectedEnglishDate,
                      'unit': unitController.text,
                      'unit_price': unitPriceController.text,
                      'product': productController.text,
                      'commission': commissionController.text,
                      'transfer_cost': transferCostController.text,
                      'miscellaneous': miscellaneousController.text,
                      'ghurfedari': ghurfedariController.text,
                      'barchalani': barchalaniController.text,
                      'purchase_type': selectedPurchaseType,
                      'seller_payment': sellerPayment.toStringAsFixed(0),
                      'seller_payment_method': selectedSellerPaymentMethod,
                      'seller_paid_amount': sellerPaidAmount.toStringAsFixed(0),
                      'currency': selectedCurrency,
                      'exchange_rate': double.tryParse(exchangeRateController.text) ?? 1,
                      'final_price': finalPriceController.text,
                    };

                    final result = await _db.updateRawMaterial(material['id'], updatedMaterial);

                    Navigator.pop(context);

                    if (result != -1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.rawMaterialUpdatedSuccess), backgroundColor: Colors.green),
                      );
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.errorUpdatingRawMaterial), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                  ),
                  child: Text(l10n.update),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> material, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(l10n.deleteRawMaterial),
          content: Text('${l10n.deleteConfirmation} "${material['name']}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final result = await _db.deleteRawMaterial(material['id']);
                Navigator.pop(context);
                if (result != -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.rawMaterialDeletedSuccess), backgroundColor: Colors.green),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.errorDeletingRawMaterial), backgroundColor: Colors.red),
                  );
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Text(
                      l10n.rawMaterialsManagement,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.rawMaterialsSubtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFFCB001D), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${_selectedIds.length} ${l10n.selected}',
                              style: const TextStyle(
                                color: Color(0xFFCB001D),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_selectedIds.isNotEmpty) const SizedBox(width: 8),
                    if (_selectedIds.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => _showBulkDeleteDialog(context, l10n),
                        icon: const Icon(Icons.delete_sweep, color: Colors.white, size: 18),
                        label: Text(
                          'حذف ${_selectedIds.length} مورد',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    if (_selectedIds.isNotEmpty) const SizedBox(width: 10),
                    if (materials.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _showDeleteAllDialog(context, l10n),
                        icon: Icon(Icons.delete_forever, color: Colors.red.shade700, size: 18),
                        label: Text(
                          'حذف همه',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade700, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    if (materials.isNotEmpty) const SizedBox(width: 10),
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
                      onPressed: () { _showAddDialog(context); },
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: Text(l10n.addRawMaterial, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB001D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ============================================================
            // ✅ TOP SUMMARY CARD — Tons + AFN Value + USD Value
            // ============================================================
            Container(
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
                  // ---- Total tons (left) ----
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCB001D).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.scale, color: Color(0xFFCB001D), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مجموع وزن به تن',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${_getTotalTons().toStringAsFixed(1)} تن',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFCB001D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  const SizedBox(width: 16),
                  // ---- AFN value ----
                  Expanded(
                    child: _buildValueSummaryTile(
                      label: 'ارزش به افغانی',
                      value: '${_formatNumber(_getTotalValueByCurrency('AFN'))} AFN',
                      icon: Icons.currency_exchange,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ---- USD value ----
                  Expanded(
                    child: _buildValueSummaryTile(
                      label: 'ارزش به دالر',
                      value: '\$${_formatNumber(_getTotalValueByCurrency('USD'))}',
                      icon: Icons.attach_money,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (materials.isNotEmpty) ...[
              Text(
                l10n.stockSummaryByUnit,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _buildUnitSummaryCards(l10n)),
              ),
            ],
            const SizedBox(height: 14),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: _buildMainTable(l10n),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
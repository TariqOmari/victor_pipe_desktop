// lib/utils/excel_import_helper.dart
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../utils/date_converter.dart';

class ExcelImportHelper {
  static final DatabaseHelper _db = DatabaseHelper();

  // Define the expected columns (exact Persian names as per your client)
  static const List<String> EXPECTED_COLUMNS = [
    'نام مواد',
    'اسم فروشنده',
    'وزن خالص',
    'وزن ناخالص',
    'واحد',
    'قیمت واحد',
    'تاریخ',
    'ضخامت',
    'نوع مواد',
    'محل تخلیه',
    'قیمت محصول',
    'کمیسیون',
    'هزینه حمل',
    'متفرقه',
    'غرفه‌داری',
    'برچالانی',
    'نوع خرید',
    'قیمت نهایی',
  ];

  static Future<Map<String, dynamic>> pickAndImportExcel() async {
    try {
      // Pick Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) {
        return {'success': false, 'message': 'فایلی انتخاب نشد'};
      }

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      // Get first sheet
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        return {'success': false, 'message': 'فایل اکسل معتبر نیست'};
      }

      // Parse the data
      return await parseExcelSheet(sheet);
    } catch (e) {
      return {'success': false, 'message': 'خطا در خواندن فایل: $e'};
    }
  }

  static Future<Map<String, dynamic>> parseExcelSheet(Sheet sheet) async {
    try {
      List<Map<String, dynamic>> importedData = [];
      int successCount = 0;
      int skippedCount = 0;
      List<String> errors = [];

      // Get headers from first row
      final headersRow = sheet.rows.first;
      List<String> headers = [];
      
      for (var cell in headersRow) {
        if (cell != null && cell.value != null) {
          String header = cell.value.toString().trim();
          if (header.isNotEmpty) {
            headers.add(header);
          }
        }
      }

      print('📋 Found headers: $headers');

      // Check if required columns exist (case insensitive)
      bool hasMaterialName = headers.any((h) => h.contains('نام مواد') || h.contains('نام') && h.contains('مواد'));
      bool hasSupplierName = headers.any((h) => h.contains('اسم فروشنده') || h.contains('فروشنده'));
      bool hasNetWeight = headers.any((h) => h.contains('وزن خالص') || h.contains('خالص'));
      bool hasGrossWeight = headers.any((h) => h.contains('وزن ناخالص') || h.contains('ناخالص'));

      if (!hasMaterialName || !hasSupplierName || !hasNetWeight || !hasGrossWeight) {
        return {
          'success': false,
          'message': 'ستون‌های مورد نیاز یافت نشد. ستون‌های مورد نیاز: نام مواد، اسم فروشنده، وزن خالص، وزن ناخالص'
        };
      }

      // Get suppliers for matching
      final suppliers = await _db.getSuppliers();
      Map<String, int> supplierMap = {};
      for (var supplier in suppliers) {
        supplierMap[supplier['name']?.toString() ?? ''] = supplier['id'];
      }

      // Process each row (skip header row)
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        try {
          // Map columns to values
          Map<String, String> rowData = {};
          for (int j = 0; j < headers.length && j < row.length; j++) {
            final cell = row[j];
            if (cell != null && cell.value != null) {
              String value = cell.value.toString().trim();
              if (value.isNotEmpty) {
                rowData[headers[j]] = value;
              }
            }
          }

          // Skip empty rows
          if (rowData.isEmpty) continue;

          // Extract data
          String materialName = _findValue(rowData, ['نام مواد', 'نام', 'مواد', 'Material Name', 'material_name']);
          String supplierName = _findValue(rowData, ['اسم فروشنده', 'فروشنده', 'Supplier', 'supplier_name']);
          String netWeightStr = _findValue(rowData, ['وزن خالص', 'خالص', 'Net Weight', 'net_weight']);
          String grossWeightStr = _findValue(rowData, ['وزن ناخالص', 'ناخالص', 'Gross Weight', 'gross_weight']);

          // Skip if required fields are missing
          if (materialName.isEmpty || supplierName.isEmpty || netWeightStr.isEmpty || grossWeightStr.isEmpty) {
            skippedCount++;
            errors.add('ردیف ${i+1}: فیلدهای مورد نیاز کامل نیستند');
            continue;
          }

          // Parse numeric values
          double netWeight = _parseDouble(netWeightStr);
          double grossWeight = _parseDouble(grossWeightStr);

          if (netWeight <= 0 || grossWeight <= 0) {
            skippedCount++;
            errors.add('ردیف ${i+1}: وزن نامعتبر');
            continue;
          }

          // Get supplier ID (create new supplier if not exists)
          int? supplierId = supplierMap[supplierName];
          if (supplierId == null) {
            // Create new supplier
            supplierId = await _db.insertSupplier({
              'name': supplierName,
              'phone': _findValue(rowData, ['تلفن', 'شماره', 'Phone', 'phone']) ?? '',
              'address': _findValue(rowData, ['آدرس', 'Address', 'address']) ?? '',
            });
            if (supplierId != -1) {
              supplierMap[supplierName] = supplierId;
              print('✅ Created new supplier: $supplierName');
            } else {
              skippedCount++;
              errors.add('ردیف ${i+1}: خطا در ایجاد فروشنده');
              continue;
            }
          }

          // Prepare material data
          String unit = _findValue(rowData, ['واحد', 'Unit', 'unit']) ?? 'کیلوگرم';
          String date = _findValue(rowData, ['تاریخ', 'Date', 'date']) ?? PersianDateConverter.gregorianToJalali(DateTime.now());
          String englishDate = _findValue(rowData, ['تاریخ میلادی', 'English Date', 'date_en']) ?? PersianDateConverter.getEnglishDate(DateTime.now());

          double unitPrice = _parseDouble(_findValue(rowData, ['قیمت واحد', 'قیمت', 'Unit Price', 'unit_price']) ?? '0');
          double productPrice = _parseDouble(_findValue(rowData, ['قیمت محصول', 'Product Price', 'product']) ?? '0');
          double commission = _parseDouble(_findValue(rowData, ['کمیسیون', 'Commission', 'commission']) ?? '0');
          double transferCost = _parseDouble(_findValue(rowData, ['هزینه حمل', 'Transfer Cost', 'transfer_cost']) ?? '0');
          double miscellaneous = _parseDouble(_findValue(rowData, ['متفرقه', 'Miscellaneous', 'miscellaneous']) ?? '0');
          double ghurfedari = _parseDouble(_findValue(rowData, ['غرفه‌داری', 'Ghurfedari', 'ghurfedari']) ?? '0');
          double barchalani = _parseDouble(_findValue(rowData, ['برچالانی', 'Barchalani', 'barchalani']) ?? '0');

          // Calculate final price
          double netWeightInTons = unit == 'کیلوگرم' || unit == 'kg' || unit == 'Kg' ? netWeight / 1000 : netWeight;
          double basePrice = netWeightInTons * unitPrice;
          double finalPrice = basePrice + productPrice + commission + transferCost + miscellaneous + ghurfedari + barchalani;

          // Build material data
          Map<String, dynamic> material = {
            'supplier_id': supplierId!,
            'name': materialName,
            'location': _findValue(rowData, ['محل تخلیه', 'Location', 'location']) ?? '',
            'material_type': _findValue(rowData, ['نوع مواد', 'Material Type', 'material_type']) ?? '',
            'thickness': _findValue(rowData, ['ضخامت', 'Thickness', 'thickness']) ?? '',
            'net_weight': netWeight.toString(),
            'gross_weight': grossWeight.toString(),
            'date': date,
            'date_en': englishDate,
            'unit': unit,
            'unit_price': unitPrice.toString(),
            'product': productPrice > 0 ? productPrice.toString() : '0',
            'commission': commission > 0 ? commission.toString() : '0',
            'transfer_cost': transferCost > 0 ? transferCost.toString() : '0',
            'miscellaneous': miscellaneous > 0 ? miscellaneous.toString() : '0',
            'ghurfedari': ghurfedari > 0 ? ghurfedari.toString() : '0',
            'barchalani': barchalani > 0 ? barchalani.toString() : '0',
            'purchase_type': _findValue(rowData, ['نوع خرید', 'Purchase Type', 'purchase_type']) ?? 'مستقیم',
            'seller_payment': basePrice.toStringAsFixed(0),
            'seller_payment_method': _findValue(rowData, ['روش پرداخت', 'Payment Method', 'payment_method']) ?? 'cash',
            'seller_paid_amount': (basePrice > 0 ? basePrice / 2 : 0).toStringAsFixed(0),
            'currency': 'AFN',
            'exchange_rate': 1.0,
            'final_price': finalPrice.toStringAsFixed(0),
          };

          // Insert into database
          int result = await _db.insertRawMaterial(material);
          if (result != -1) {
            successCount++;
            importedData.add(material);
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
        'totalRows': sheet.rows.length - 1,
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

  static String _findValue(Map<String, String> data, List<String> keys) {
    for (String key in keys) {
      for (String dataKey in data.keys) {
        if (dataKey.contains(key) || key.contains(dataKey)) {
          return data[dataKey] ?? '';
        }
      }
    }
    return '';
  }

  static double _parseDouble(String value) {
    value = value.replaceAll(',', '').replaceAll(' ', '');
    return double.tryParse(value) ?? 0.0;
  }
}
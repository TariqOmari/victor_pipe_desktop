// lib/services/excel_service.dart
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

class ExcelService {
  // Field mapping for import/export
  static const Map<String, String> fieldMapping = {
    'id': 'شناسه',
    'supplier_id': 'شناسه تامین‌کننده',
    'supplier_name': 'نام تامین‌کننده',
    'name': 'نام ماده خام',
    'location': 'محل تخلیه',
    'material_type': 'نوع ماده',
    'thickness': 'ضخامت',
    'net_weight': 'وزن خالص',
    'gross_weight': 'وزن ناخالص',
    'date': 'تاریخ (شمسی)',
    'date_en': 'تاریخ (میلادی)',
    'unit': 'واحد',
    'unit_price': 'قیمت واحد',
    'product': 'قیمت محصول',
    'commission': 'کمیسیون',
    'transfer_cost': 'هزینه حمل',
    'miscellaneous': 'متفرقه',
    'ghurfedari': 'غرفه‌داری',
    'barchalani': 'بارچالانی',
    'purchase_type': 'نوع خرید',
    'seller_payment': 'مبلغ فروشنده',
    'seller_payment_method': 'روش پرداخت فروشنده',
    'seller_paid_amount': 'مبلغ پرداختی فروشنده',
    'currency': 'واحد پول',
    'exchange_rate': 'نرخ ارز',
    'final_price': 'قیمت نهایی',
    'created_at': 'تاریخ ایجاد',
  };

  // Reverse mapping for import
  static Map<String, String> get reverseMapping {
    Map<String, String> reverse = {};
    fieldMapping.forEach((key, value) {
      reverse[value] = key;
    });
    return reverse;
  }

  // Get all field names for Excel header
  static List<String> getExportHeaders() {
    return fieldMapping.values.toList();
  }

  // Get database field names
  static List<String> getDbFields() {
    return fieldMapping.keys.toList();
  }

  // Export raw materials to Excel
  static Future<String?> exportRawMaterials(List<Map<String, dynamic>> materials) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['RawMaterials'];

      // Add headers
      final headers = getExportHeaders();
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = headers[i];
        // Style headers
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = CellStyle(
          bold: true,
          fontSize: 11,
          backgroundColorHex: 'FFCB001D',
          fontColorHex: 'FFFFFFFF',
        );
      }

      // Add data rows
      for (int row = 0; row < materials.length; row++) {
        final material = materials[row];
        for (int col = 0; col < headers.length; col++) {
          final dbField = getDbFields()[col];
          String value = material[dbField]?.toString() ?? '';
          
          // Special handling for supplier_name (joined field)
          if (dbField == 'supplier_name' && material.containsKey('supplier_name')) {
            value = material['supplier_name']?.toString() ?? '';
          }
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1)).value = value;
        }
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'raw_materials_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${directory.path}/$fileName';
      
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      print('❌ Export error: $e');
      return null;
    }
  }

  // Import raw materials from Excel
  static Future<List<Map<String, dynamic>>> importRawMaterials(String? filePath) async {
    try {
      if (filePath == null) return [];

      final file = File(filePath);
      if (!await file.exists()) return [];

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;

      // Read headers
      final headers = <String>[];
      final columns = <int>{};
      for (int col = 0; col < sheet.maxColumns; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        if (cell.value != null && cell.value!.toString().isNotEmpty) {
          headers.add(cell.value!.toString().trim());
          columns.add(col);
        }
      }

      // Validate headers - check if any known fields exist
      final reverseMap = reverseMapping;
      final validHeaders = headers.where((h) => reverseMap.containsKey(h)).toList();
      
      if (validHeaders.isEmpty) {
        throw Exception('هیچ ستون معتبری در فایل پیدا نشد');
      }

      // Parse data rows
      final materials = <Map<String, dynamic>>[];
      for (int row = 1; row < sheet.maxRows; row++) {
        final material = <String, dynamic>{};
        bool hasData = false;

        for (int col = 0; col < headers.length; col++) {
          final header = headers[col];
          final dbField = reverseMap[header];
          
          if (dbField != null) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
            String value = cell.value?.toString() ?? '';
            
            // Skip empty values
            if (value.trim().isEmpty) continue;
            
            // Handle numeric fields
            if (['id', 'supplier_id', 'exchange_rate'].contains(dbField) ||
                dbField.endsWith('_price') ||
                dbField.endsWith('_weight') ||
                dbField.endsWith('_amount') ||
                dbField.contains('payment') ||
                dbField.contains('cost')) {
              try {
                final numValue = double.tryParse(value.trim().replaceAll(',', ''));
                if (numValue != null) {
                  material[dbField] = numValue;
                  hasData = true;
                }
              } catch (_) {}
            } else {
              material[dbField] = value.trim();
              hasData = true;
            }
          }
        }

        // Only add if there's data and required fields are present
        if (hasData) {
          // Validate required fields
          if (material['name'] != null && material['name'].toString().isNotEmpty) {
            // Set default values for missing fields
            if (material['unit'] == null || material['unit'].toString().isEmpty) {
              material['unit'] = 'کیلوگرم';
            }
            if (material['currency'] == null || material['currency'].toString().isEmpty) {
              material['currency'] = 'AFN';
            }
            if (material['seller_payment_method'] == null) {
              material['seller_payment_method'] = 'cash';
            }
            if (material['purchase_type'] == null) {
              material['purchase_type'] = 'مستقیم';
            }
            
            materials.add(material);
          }
        }
      }

      return materials;
    } catch (e) {
      print('❌ Import error: $e');
      rethrow;
    }
  }

  // Validate Excel file before import
  static Future<Map<String, dynamic>> validateExcelFile(String? filePath) async {
    try {
      if (filePath == null) {
        return {'valid': false, 'message': 'مسیر فایل معتبر نیست'};
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return {'valid': false, 'message': 'فایل پیدا نشد'};
      }

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;

      // Read headers
      final headers = <String>[];
      for (int col = 0; col < sheet.maxColumns; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        if (cell.value != null && cell.value!.toString().isNotEmpty) {
          headers.add(cell.value!.toString().trim());
        }
      }

      // Check if headers match our expected fields
      final reverseMap = reverseMapping;
      final validHeaders = headers.where((h) => reverseMap.containsKey(h)).toList();
      final invalidHeaders = headers.where((h) => !reverseMap.containsKey(h)).toList();

      // Check for required fields
      final requiredFields = ['نام ماده خام', 'وزن ناخالص', 'قیمت واحد'];
      final missingRequired = requiredFields.where((f) => !headers.contains(f)).toList();

      return {
        'valid': validHeaders.isNotEmpty && missingRequired.isEmpty,
        'headers': headers,
        'validHeaders': validHeaders,
        'invalidHeaders': invalidHeaders,
        'missingRequired': missingRequired,
        'rowCount': sheet.maxRows - 1,
        'message': _getValidationMessage(validHeaders, invalidHeaders, missingRequired),
      };
    } catch (e) {
      return {'valid': false, 'message': 'خطا در خواندن فایل: $e'};
    }
  }

  static String _getValidationMessage(List<String> valid, List<String> invalid, List<String> missing) {
    if (valid.isEmpty) {
      return 'هیچ ستون معتبری در فایل پیدا نشد';
    }
    if (missing.isNotEmpty) {
      return 'ستون‌های اجباری زیر پیدا نشدند: ${missing.join(', ')}';
    }
    if (invalid.isNotEmpty) {
      return '${valid.length} ستون معتبر پیدا شد. ${invalid.length} ستون ناشناخته نادیده گرفته می‌شوند.';
    }
    return 'فایل معتبر است. ${valid.length} ستون شناسایی شد.';
  }

  // Pick Excel file
  static Future<String?> pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        dialogTitle: 'انتخاب فایل اکسل',
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files.single.path;
      }
      return null;
    } catch (e) {
      print('❌ File picker error: $e');
      return null;
    }
  }

  // Save exported file to Downloads or Documents
  static Future<bool> saveExportedFile(String sourcePath, String fileName) async {
    try {
      // Try to save to Downloads folder on Android
      String? savePath;
      
      if (Platform.isAndroid) {
        // For Android, try to use external storage
        try {
          final dir = Directory('/storage/emulated/0/Download');
          if (await dir.exists()) {
            savePath = '${dir.path}/$fileName';
          }
        } catch (_) {}
      }
      
      // Fallback to app documents
      if (savePath == null) {
        final directory = await getApplicationDocumentsDirectory();
        savePath = '${directory.path}/$fileName';
      }

      final sourceFile = File(sourcePath);
      final targetFile = File(savePath);
      
      await sourceFile.copy(targetFile.path);
      return true;
    } catch (e) {
      print('❌ Error saving exported file: $e');
      return false;
    }
  }
}
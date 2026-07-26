// lib/utils/date_converter.dart
import 'package:persian/persian.dart';

class PersianDateConverter {
  // Gregorian to Jalali conversion
  static String gregorianToJalali(DateTime date) {
    try {
      final persianDate = date.toPersian();
      String monthStr = persianDate.month.toString().padLeft(2, '0');
      String dayStr = persianDate.day.toString().padLeft(2, '0');
      return '${persianDate.year}-$monthStr-$dayStr';
    } catch (e) {
      print('Error converting date: $e');
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  // Get English date in YYYY-MM-DD format
  static String getEnglishDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Get current English date
  static String getCurrentEnglishDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // Get current Persian date
  static String getCurrentPersianDate() {
    try {
      final now = DateTime.now().toPersian();
      String monthStr = now.month.toString().padLeft(2, '0');
      String dayStr = now.day.toString().padLeft(2, '0');
      return '${now.year}-$monthStr-$dayStr';
    } catch (e) {
      print('Error getting current date: $e');
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
  }

  // Get current Persian date with time
  static String getCurrentPersianDateTime() {
    try {
      final now = DateTime.now().toPersian();
      final nowGregorian = DateTime.now();
      String monthStr = now.month.toString().padLeft(2, '0');
      String dayStr = now.day.toString().padLeft(2, '0');
      final time = '${nowGregorian.hour.toString().padLeft(2, '0')}:${nowGregorian.minute.toString().padLeft(2, '0')}';
      return '${now.year}-$monthStr-$dayStr $time';
    } catch (e) {
      print('Error getting current datetime: $e');
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
  }
}
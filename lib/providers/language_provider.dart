import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('fa', 'IR'); // Default: Persian
  
  Locale get locale => _locale;
  
  // Check if current language is English
  bool get isEnglish => _locale.languageCode == 'en';
  
  // Change language
  void setLanguage(String languageCode) {
    if (languageCode == 'en') {
      _locale = const Locale('en', 'US');
    } else {
      _locale = const Locale('fa', 'IR');
    }
    notifyListeners();
  }
  
  // Toggle between Persian and English
  void toggleLanguage() {
    if (_locale.languageCode == 'fa') {
      _locale = const Locale('en', 'US');
    } else {
      _locale = const Locale('fa', 'IR');
    }
    notifyListeners();
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'providers/language_provider.dart';
import 'l10n/app_localizations.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  DatabaseHelper.init();
  
  // Load saved language preference
  final prefs = await SharedPreferences.getInstance();
  final savedLanguage = prefs.getString('language') ?? 'fa';
  
  runApp(MyApp(savedLanguage: savedLanguage));
}

class MyApp extends StatelessWidget {
  final String savedLanguage;
  
  const MyApp({super.key, required this.savedLanguage});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = LanguageProvider();
        provider.setLanguage(savedLanguage);
        return provider;
      },
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'Victor Pipe Management',
            debugShowCheckedModeBanner: false,
            
            locale: languageProvider.locale,
            
            supportedLocales: const [
              Locale('fa', 'IR'),
              Locale('en', 'US'),
            ],
            
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Vazir',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFCB001D),
              ),
              scaffoldBackgroundColor: const Color(0xFFF8F8F8),
            ),
            
            initialRoute: '/login',
            routes: {
              '/login': (context) => const LoginScreen(),
              '/dashboard': (context) => DashboardScreen(
                    user: {
                      'id': 1,
                      'username': 'admin',
                      // Dynamic full_name based on language
                      'full_name': languageProvider.isEnglish ? 'System Admin' : 'مدیر سیستم',
                      // Dynamic role based on language
                      'role': languageProvider.isEnglish ? 'Admin' : 'مدیر',
                      'profile_pic': null,
                    },
                  ),
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ← ADD THIS
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import 'dashboard_screen.dart'; // ← ADD THIS IMPORT

class Navbar extends StatelessWidget {
  final Map<String, dynamic> user;

  const Navbar({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Container(
      height: isMobile ? 80.0 : 96.0,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : (isTablet ? 24.0 : 32.0),
        vertical: 0.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 60,
            offset: const Offset(0, 0),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFCB001D).withOpacity(0.06),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LEFT - LOGO
          _buildLogo(isMobile, isTablet, isDesktop),
          
          // RIGHT - LANGUAGE SWITCHER + NOTIFICATIONS
          Row(
            children: [
              // Language Switcher
              _buildLanguageSwitcher(context, isMobile, languageProvider, l10n),
              const SizedBox(width: 8),
              // Notification Bell
              _buildNotificationBell(context, isMobile, l10n),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(bool isMobile, bool isTablet, bool isDesktop) {
    final double logoSize = isMobile ? 80.0 : (isTablet ? 100.0 : 120.0);
    
    return Row(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(isMobile ? 12.0 : 16.0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? 12.0 : 16.0),
            child: Image.asset(
              'assets/images/companylogo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    'VP',
                    style: TextStyle(
                      color: const Color(0xFFCB001D),
                      fontSize: isMobile ? 32.0 : 48.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(width: isMobile ? 14.0 : 20.0),
      ],
    );
  }

  Widget _buildLanguageSwitcher(
    BuildContext context,
    bool isMobile,
    LanguageProvider languageProvider,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          languageProvider.setLanguage(value);
          // Save preference
          _saveLanguagePreference(value);
          
          // Rebuild the entire app with new direction
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(user: user),
            ),
          );
        },
        offset: const Offset(0, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language,
                color: Colors.grey.shade700,
                size: isMobile ? 18 : 22,
              ),
              const SizedBox(width: 6),
              Text(
                languageProvider.isEnglish ? 'EN' : 'FA',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                color: Colors.grey.shade600,
                size: isMobile ? 18 : 22,
              ),
            ],
          ),
        ),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'fa',
            child: Row(
              children: [
                const Icon(Icons.flag, color: Colors.green),
                const SizedBox(width: 12),
                Text(l10n.persian),
                if (!languageProvider.isEnglish) ...[
                  const Spacer(),
                  const Icon(Icons.check, color: Color(0xFFCB001D), size: 18),
                ],
              ],
            ),
          ),
          PopupMenuItem(
            value: 'en',
            child: Row(
              children: [
                const Icon(Icons.flag, color: Colors.blue),
                const SizedBox(width: 12),
                Text(l10n.english),
                if (languageProvider.isEnglish) ...[
                  const Spacer(),
                  const Icon(Icons.check, color: Color(0xFFCB001D), size: 18),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveLanguagePreference(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
  }

  Widget _buildNotificationBell(
    BuildContext context,
    bool isMobile,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      child: Stack(
        children: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.noNotifications),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              );
            },
            icon: Icon(
              Icons.notifications_outlined,
              color: Colors.grey.shade700,
              size: isMobile ? 30.0 : 36.0,
            ),
            splashRadius: 20,
            padding: const EdgeInsets.all(8.0),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.all(4.0),
              decoration: const BoxDecoration(
                color: Color(0xFFCB001D),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
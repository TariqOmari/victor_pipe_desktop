// navbar.dart
import 'package:flutter/material.dart';

class Navbar extends StatelessWidget {
  final Map<String, dynamic> user;

  const Navbar({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return Container(
      height: isMobile ? 80.0 : 96.0, // ← INCREASED HEIGHT TO FIT BIG LOGO
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
          // LEFT SIDE - LOGO ONLY (CLEAN)
          _buildLogo(isMobile, isTablet, isDesktop),
          
          // RIGHT SIDE - NOTIFICATION BELL ONLY
          _buildNotificationBell(context, isMobile),
        ],
      ),
    );
  }

  // ======================== CLEAN LOGO ========================
  Widget _buildLogo(bool isMobile, bool isTablet, bool isDesktop) {
    // ← MASSIVE LOGO SIZE
    final double logoSize = isMobile ? 80.0 : (isTablet ? 100.0 : 120.0);
    
    return Row(
      children: [
        // Logo - Clean without background
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
        
        // Company Name
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
         
        ),
      ],
    );
  }

  // ======================== NOTIFICATION BELL ========================
  Widget _buildNotificationBell(BuildContext context, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      child: Stack(
        children: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔔 هیچ اعلان جدیدی وجود ندارد'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
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
          // Notification Badge
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
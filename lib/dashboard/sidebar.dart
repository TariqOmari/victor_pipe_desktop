// sidebar.dart
import 'package:flutter/material.dart';
import 'dart:io';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final Map<String, dynamic> user;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1200;
    final sidebarWidth = isSmallScreen ? 220.0 : 260.0;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFCB001D),
            Color(0xFFA80018),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(4, 0),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 60,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // User Profile Header
          _buildUserProfile(isSmallScreen),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 8 : 12,
                horizontal: isSmallScreen ? 8 : 12,
              ),
              children: [
                // Dashboard
                _buildMenuItem(
                  context: context,
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  title: 'داشبورد',
                  isSelected: selectedIndex == 0,
                ),
                // Customers
                _buildMenuItem(
                  context: context,
                  index: 1,
                  icon: Icons.people_alt_outlined,
                  title: 'مدیریت مشتریان',
                  isSelected: selectedIndex == 1,
                ),
                // Suppliers
                _buildMenuItem(
                  context: context,
                  index: 2,
                  icon: Icons.local_shipping_outlined,
                  title: 'مدیریت فروشندگان',
                  isSelected: selectedIndex == 2,
                ),
                // Raw Materials
                _buildMenuItem(
                  context: context,
                  index: 3,
                  icon: Icons.warehouse_outlined,
                  title: 'مدیریت مواد خام',
                  isSelected: selectedIndex == 3,
                ),
                _buildMenuItem(
                  context: context,
                  index: 4,
                  icon: Icons.trending_up_rounded,
                  title: 'مدیریت فروشات',
                  isSelected: selectedIndex == 4,
                ),
                // Daily Expenses
                _buildMenuItem(
                  context: context,
                  index: 5,
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'مصارف روزمره',
                  isSelected: selectedIndex == 5,
                ),
                // Customers & Companies
                _buildMenuItem(
                context: context,
                index: 6,  // ایندکس جدید
                icon: Icons.people_alt_outlined,
                title: 'مشتریان و شرکت‌ها',
                 isSelected: selectedIndex == 6,
                ),
                
                // Admins Management
                _buildMenuItem(
                  context: context,
                  index: 7,
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'مدیریت مدیران',
                  isSelected: selectedIndex == 7,
                ),
                
                // Divider
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 8 : 12,
                    horizontal: 4,
                  ),
                  child: Divider(
                    color: Colors.white.withOpacity(0.2),
                    thickness: 1.5,
                    height: 1,
                  ),
                ),
                
                // Logout
                _buildMenuItem(
                  context: context,
                  index: -1,
                  icon: Icons.logout,
                  title: 'خروج از سیستم',
                  isSelected: false,
                  isLogout: true,
                ),
              ],
            ),
          ),

          // Footer با استایل جدید
          _buildFooter(isSmallScreen),
        ],
      ),
    );
  }

  // ======================== USER PROFILE HEADER ========================
  Widget _buildUserProfile(bool isSmallScreen) {
    final String fullName = user['full_name'] ?? 'کاربر';
    final String username = user['username'] ?? '';
    final String? profilePic = user['profile_pic'];
    final String firstLetter = fullName.isNotEmpty ? fullName[0] : '?';

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Profile Photo - Circle with nice border
          Container(
            width: isSmallScreen ? 70 : 85,
            height: isSmallScreen ? 70 : 85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ClipOval(
              child: profilePic != null && profilePic.isNotEmpty
                  ? Image.file(
                      File(profilePic),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildAvatarFallback(firstLetter, isSmallScreen);
                      },
                    )
                  : _buildAvatarFallback(firstLetter, isSmallScreen),
            ),
          ),
          
          const SizedBox(height: 10),
          
          // User Name
          Text(
            fullName,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 14 : 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 2),
          
          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white.withOpacity(0.8),
                  size: isSmallScreen ? 12 : 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'مدیر',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Username (small)
          if (username.isNotEmpty)
            Text(
              '@$username',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: isSmallScreen ? 9 : 11,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  // ======================== Avatar Fallback ========================
  Widget _buildAvatarFallback(String letter, bool isSmallScreen) {
    return Container(
      color: const Color(0xFF8B0000),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 28 : 36,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ======================== Menu Item ========================
  Widget _buildMenuItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String title,
    required bool isSelected,
    bool isLogout = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1200;

    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: EdgeInsets.only(bottom: isSmallScreen ? 2 : 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.05),
                    ],
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isLogout
                    ? Colors.white.withOpacity(0.6)
                    : isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                size: isSmallScreen ? 20 : 22,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: isLogout
                    ? Colors.white.withOpacity(0.6)
                    : isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.85),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: isSmallScreen ? 12 : 14,
                letterSpacing: 0.3,
              ),
            ),
            trailing: isSelected && !isLogout
                ? Container(
                    width: 4,
                    height: isSmallScreen ? 24 : 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  )
                : null,
            tileColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              side: isSelected
                  ? BorderSide(
                      color: Colors.white.withOpacity(0.15),
                      width: 1.5,
                    )
                  : BorderSide.none,
            ),
            onTap: () {
              if (isLogout) {
                _showLogoutDialog(context);
              } else {
                onItemSelected(index);
              }
            },
            hoverColor: Colors.white.withOpacity(0.08),
            splashColor: Colors.white.withOpacity(0.15),
          ),
        ),
      ),
    );
  }

  // ======================== فوتر جدید ========================
  Widget _buildFooter(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Text(
              '●  نسخه ۲.۰  ●',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: isSmallScreen ? 10 : 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======================== Logout Dialog ========================
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 24,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCB001D).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFCB001D),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'خروج از سیستم',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'آیا مطمئن هستید که می‌خواهید خارج شوید؟',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.grey.shade100,
                      ),
                      child: const Text(
                        'انصراف',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB001D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'خروج',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
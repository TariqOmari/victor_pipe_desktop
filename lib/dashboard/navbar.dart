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
      height: isMobile ? 64 : 72,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (isTablet ? 20 : 28),
        vertical: 0,
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
          // LEFT SIDE - عنوان صفحه با استایل جدید
          _buildPageTitle(isMobile, isTablet, isDesktop),
          
          // RIGHT SIDE - پروفایل ادمین با استایل جدید
          _buildProfileSection(context, isMobile, isTablet, isDesktop),
        ],
      ),
    );
  }

  // ======================== عنوان صفحه ========================
  Widget _buildPageTitle(bool isMobile, bool isTablet, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFCB001D).withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFCB001D).withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // آیکون با پس‌زمینه
          Container(
            padding: EdgeInsets.all(isMobile ? 4 : 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFCB001D), Color(0xFFE53E3E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFCB001D).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.dashboard_outlined,
              color: Colors.white,
              size: isMobile ? 16 : 20,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          // عنوان
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getPageTitle(),
                style: TextStyle(
                  fontSize: isMobile ? 14 : (isTablet ? 16 : 18),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                  letterSpacing: 0.3,
                ),
              ),
              if (!isMobile)
                Text(
                  'سیستم مدیریت ویکتور پایپ',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ======================== بخش پروفایل ========================
  Widget _buildProfileSection(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return Row(
      children: [
        // دکمه اعلان‌ها (برای دسکتاپ)
        if (!isMobile)
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔔 هیچ اعلان جدیدی وجود ندارد'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: Stack(
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: Colors.grey.shade600,
                    size: 24,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCB001D),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              splashRadius: 20,
              padding: const EdgeInsets.all(8),
            ),
          ),

        // منوی پروفایل
        PopupMenuButton<String>(
          offset: Offset(0, isMobile ? 55 : 60),
          color: Colors.white,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 4 : 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // آواتار
                _buildAvatar(isMobile),
                
                if (!isMobile) ...[
                  const SizedBox(width: 10),
                  // اطلاعات کاربر
                  _buildUserInfo(),
                ],
                
                SizedBox(width: isMobile ? 4 : 8),
                // آیکون پایین
                Icon(
                  Icons.arrow_drop_down,
                  color: const Color(0xFFCB001D),
                  size: isMobile ? 20 : 24,
                ),
              ],
            ),
          ),
          itemBuilder: (BuildContext context) => [
            // هدر پروفایل
            PopupMenuItem<String>(
              enabled: false,
              child: Container(
                width: isMobile ? 200 : 260,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildAvatar(true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['full_name'] ?? 'مدیر سیستم',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              Text(
                                user['role'] ?? 'مدیر',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFFCB001D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user['email'] ?? 'admin@victorpipe.com',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            
            // پروفایل
            _buildPopupItem(
              icon: Icons.person_outline,
              title: 'پروفایل',
              subtitle: 'مشاهده',
              color: Colors.grey.shade700,
            ),
            
            // تنظیمات
            _buildPopupItem(
              icon: Icons.settings_outlined,
              title: 'تنظیمات',
              subtitle: 'سیستم',
              color: Colors.grey.shade700,
            ),
            
            // راهنما
            if (!isMobile)
              _buildPopupItem(
                icon: Icons.help_outline,
                title: 'راهنما',
                subtitle: 'پشتیبانی',
                color: Colors.grey.shade700,
              ),
            
            const PopupMenuDivider(),
            
            // خروج
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: Colors.red,
                  ),
                  SizedBox(width: 14),
                  Text(
                    'خروج از سیستم',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
          onSelected: (String value) {
            if (value == 'logout') {
              _showLogoutDialog(context);
            } else if (value == 'profile') {
              _showSnackBar(context, '👤 پروفایل کاربر');
            } else if (value == 'settings') {
              _showSnackBar(context, '⚙️ تنظیمات سیستم');
            }
          },
        ),
      ],
    );
  }

  // ======================== آواتار ========================
  Widget _buildAvatar(bool isMobile) {
    return Container(
      width: isMobile ? 32 : 38,
      height: isMobile ? 32 : 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCB001D), Color(0xFFE53E3E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCB001D).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          user['full_name']?.isNotEmpty == true
              ? user['full_name'][0]
              : 'م',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ======================== اطلاعات کاربر ========================
  Widget _buildUserInfo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user['full_name'] ?? 'مدیر سیستم',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF1A1A2E),
            letterSpacing: 0.2,
          ),
        ),
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFCB001D),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              user['role'] ?? 'مدیر',
              style: TextStyle(
                color: const Color(0xFFCB001D),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            // وضعیت آنلاین
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.green.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'آنلاین',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ======================== آیتم پاپ‌آپ ========================
  PopupMenuItem<String> _buildPopupItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return PopupMenuItem<String>(
      value: title.toLowerCase(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFCB001D).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFFCB001D),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  // ======================== دریافت عنوان صفحه ========================
  String _getPageTitle() {
    // این تابع را می‌توانید با توجه به صفحه فعلی توسعه دهید
    return 'داشبورد مدیریت';
  }

  // ======================== اسنک‌بار ========================
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: Colors.grey.shade900,
      ),
    );
  }

  // ======================== دیالوگ خروج ========================
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
              // آیکون خروج
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
                  color: Color(0xFF1A1A2E),
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import 'dashboard_screen.dart';
import '../database/database_helper.dart';

class Navbar extends StatefulWidget {
  final Map<String, dynamic> user;

  const Navbar({super.key, required this.user});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;
  bool _showDropdown = false;
  final GlobalKey _bellKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _checkInventory();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleDropdown() {
    if (_showDropdown) {
      _removeOverlay();
      setState(() {
        _showDropdown = false;
      });
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    
    final RenderBox renderBox = _bellKey.currentContext?.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final dropdownWidth = screenWidth < 600 ? screenWidth - 32 : 420;
    
    double rightPosition = screenWidth - position.dx - size.width;
    if (rightPosition < 0) rightPosition = 16;
    if (rightPosition + dropdownWidth > screenWidth) {
      rightPosition = screenWidth - dropdownWidth - 16;
    }
    
    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _toggleDropdown();
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
              ),
            ),
            Positioned(
              top: position.dy + size.height + 8,
              right: rightPosition,
              child: GestureDetector(
                onTap: () {},
                child: _buildDropdown(context),
              ),
            ),
          ],
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _showDropdown = true;
    });
  }

  Future<void> _checkInventory() async {
    setState(() => _isLoading = true);
    
    try {
      final db = DatabaseHelper();
      final notifications = <NotificationItem>[];
      
      // ONLY CHECK RAW MATERIALS - LESS THAN 10 IN ANY UNIT
      final rawMaterials = await db.getRawMaterials();
      for (var material in rawMaterials) {
        final weight = double.tryParse(material['net_weight']?.toString() ?? '0') ?? 0;
        final unit = material['unit']?.toString() ?? 'kg';
        final name = material['name']?.toString() ?? 'Unknown';
        
        // Check if less than 10 in any unit
        if (weight < 10) {
          notifications.add(NotificationItem(
            id: 'raw_${material['id']}',
            title: '⚠️ کمبود مواد خام',
            description: '$name: فقط $weight $unit باقی مانده (کمتر از 10)',
            type: NotificationType.warning,
            timestamp: DateTime.now(),
            isRead: false,
          ));
        }
      }
      
      setState(() {
        _notifications = notifications;
        _unreadCount = notifications.where((n) => !n.isRead).length;
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ Error checking inventory: $e');
      setState(() => _isLoading = false);
    }
  }

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
          _buildLogo(isMobile, isTablet, isDesktop),
          Row(
            children: [
              _buildLanguageSwitcher(context, isMobile, languageProvider, l10n),
              const SizedBox(width: 8),
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
          _saveLanguagePreference(value);
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(user: widget.user),
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
    return GestureDetector(
      key: _bellKey,
      onTap: _toggleDropdown,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: _showDropdown ? Colors.grey.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            Icon(
              _unreadCount > 0 ? Icons.notifications_active : Icons.notifications_outlined,
              color: _unreadCount > 0 ? const Color(0xFFCB001D) : Colors.grey.shade700,
              size: isMobile ? 28.0 : 34.0,
            ),
            if (_unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFCB001D),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
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
      ),
    );
  }

  Widget _buildDropdown(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      width: isMobile ? MediaQuery.of(context).size.width - 32 : 420,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: const Color(0xFFCB001D),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'هشدار موجودی مواد خام',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    if (_unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_notifications.isNotEmpty)
                  TextButton(
                    onPressed: _markAllRead,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFCB001D),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'خوانده شد',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCB001D)),
                      ),
                    ),
                  )
                : _notifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 48,
                                color: Colors.green.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'همه مواد خام کافی است',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'هیچ ماده خام ای کمتر از 10 واحد نیست',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _checkInventory,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('بررسی مجدد'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFCB001D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _buildNotificationItem(context, notification);
                        },
                      ),
          ),
          
          // Footer
          if (_notifications.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _checkInventory,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('بررسی موجودی'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        backgroundColor: Colors.grey.shade50,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        _toggleDropdown();
                      },
                      icon: const Icon(Icons.inventory, size: 16),
                      label: const Text('مدیریت مواد خام'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFFCB001D),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _markAllRead() {
    setState(() {
      for (var n in _notifications) {
        n.isRead = true;
      }
      _unreadCount = 0;
    });
  }

  Widget _buildNotificationItem(
    BuildContext context,
    NotificationItem notification,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: notification.isRead ? Colors.grey.shade100 : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFCB001D),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  notification.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimeAgo(notification.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} هفته پیش';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }
}

enum NotificationType {
  warning,
  success,
  error,
  info,
}

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscurePassword = true;
  bool isLoading = false;
  bool dbReady = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackbar('لطفاً نام کاربری و رمز عبور را وارد کنید', Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await _db.loginUser(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        _showSuccessToast(context, user['full_name']);
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(user: user),
            ),
          );
        });
      } else {
        _showSnackbar('نام کاربری یا رمز عبور اشتباه است', Colors.red);
        setState(() => isLoading = false);
      }
    } catch (e) {
      _showSnackbar('خطا در اتصال به پایگاه داده', Colors.red);
      setState(() => isLoading = false);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessToast(BuildContext context, String userName) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFCB001D).withOpacity(0.15),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCB001D).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFFCB001D),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '✅ ورود موفق',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        'خوش آمدید $userName',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  @override
  void initState() {
    super.initState();
    SystemChannels.textInput.invokeMethod('TextInput.setDirection', 1);
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      await _db.database;
      setState(() => dbReady = true);
    } catch (e) {
      setState(() => dbReady = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // اندازه‌های رسپانسیو
    final bool isMobile = screenWidth < 600;
    final bool isTablet = screenWidth >= 600 && screenWidth < 1200;
    final bool isDesktop = screenWidth >= 1200;
    
    final double containerWidth = isMobile 
        ? screenWidth * 0.9 
        : (isTablet ? 440 : 480);
    
    final double containerPadding = isMobile ? 24 : 40;
    final double logoSize = isMobile ? 80 : 120;
    final double titleSize = isMobile ? 18 : 22;
    final double buttonHeight = isMobile ? 48 : 54;
    final double fontSize = isMobile ? 14 : 17;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFCB001D).withOpacity(0.02),
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Container(
                width: containerWidth,
                padding: EdgeInsets.all(containerPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCB001D).withOpacity(0.08),
                      blurRadius: 60,
                      offset: const Offset(0, 20),
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFCB001D).withOpacity(0.06),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // وضعیت اتصال
                    _buildConnectionStatus(isMobile),
                    
                    const SizedBox(height: 24),
                    
                    // لوگو
                    _buildLogo(logoSize, isMobile),
                    
                    const SizedBox(height: 20),
                    
                    // عنوان
                    _buildTitle(titleSize, isMobile),
                    
                    const SizedBox(height: 32),
                    
                    // فیلد نام کاربری
                    _buildUsernameField(isMobile),
                    
                    const SizedBox(height: 16),
                    
                    // فیلد رمز عبور
                    _buildPasswordField(isMobile),
                    
                    const SizedBox(height: 8),
                    
                    // فراموشی رمز
                    _buildForgotPassword(isMobile),
                    
                    const SizedBox(height: 12),
                    
                    // دکمه ورود
                    _buildLoginButton(buttonHeight, fontSize, isMobile),
                    
                    const SizedBox(height: 24),
                    
                    // فوتر
                    _buildFooter(isMobile),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ======================== وضعیت اتصال ========================
  Widget _buildConnectionStatus(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: dbReady 
            ? Colors.green.withOpacity(0.08) 
            : Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dbReady 
              ? Colors.green.withOpacity(0.2) 
              : Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dbReady ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dbReady 
                      ? Colors.green.withOpacity(0.4) 
                      : Colors.red.withOpacity(0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            dbReady ? 'اتصال برقرار' : 'بدون اتصال',
            style: TextStyle(
              color: dbReady ? Colors.green : Colors.red,
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ======================== لوگو ========================
  Widget _buildLogo(double size, bool isMobile) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCB001D).withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.asset(
          'assets/images/companylogo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFCB001D), 
                    Color(0xFFA80018),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(size / 2),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VICTOR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 14 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'PIPE',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isMobile ? 10 : 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ======================== عنوان ========================
  Widget _buildTitle(double fontSize, bool isMobile) {
    return Column(
      children: [
        Text(
          "ویکتور پایپ صنعت",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A2E),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 60,
          height: 3,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFCB001D), Color(0xFFE53E3E)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "سیستم مدیریت یکپارچه",
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            color: const Color(0xFF888888),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ======================== فیلد نام کاربری ========================
  Widget _buildUsernameField(bool isMobile) {
    return TextField(
      controller: _usernameController,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: isMobile ? 14 : 16),
      decoration: InputDecoration(
        labelText: "نام کاربری",
        labelStyle: const TextStyle(
          color: Color(0xFFCB001D),
          fontWeight: FontWeight.w600,
        ),
        hintText: "نام کاربری خود را وارد کنید",
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w300,
          fontSize: isMobile ? 12 : 14,
        ),
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          child: const Icon(
            Icons.person_outline,
            color: Color(0xFFCB001D),
            size: 20,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFFCB001D).withOpacity(0.15),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFCB001D),
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 14 : 16,
        ),
      ),
    );
  }

  // ======================== فیلد رمز عبور ========================
  Widget _buildPasswordField(bool isMobile) {
    return TextField(
      controller: _passwordController,
      obscureText: obscurePassword,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: isMobile ? 14 : 16),
      decoration: InputDecoration(
        labelText: "رمز عبور",
        labelStyle: const TextStyle(
          color: Color(0xFFCB001D),
          fontWeight: FontWeight.w600,
        ),
        hintText: "رمز عبور خود را وارد کنید",
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w300,
          fontSize: isMobile ? 12 : 14,
        ),
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          child: const Icon(
            Icons.lock_outline,
            color: Color(0xFFCB001D),
            size: 20,
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: const Color(0xFFCB001D),
            size: 20,
          ),
          onPressed: () {
            setState(() {
              obscurePassword = !obscurePassword;
            });
          },
          padding: const EdgeInsets.all(8),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFFCB001D).withOpacity(0.15),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFCB001D),
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 14 : 16,
        ),
      ),
    );
  }

  // ======================== فراموشی رمز ========================
  Widget _buildForgotPassword(bool isMobile) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {
          _showSnackbar('با پشتیبانی تماس بگیرید', Colors.blue);
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          "رمز عبور خود را فراموش کرده‌اید؟",
          style: TextStyle(
            color: const Color(0xFFCB001D),
            fontWeight: FontWeight.w500,
            fontSize: isMobile ? 11 : 12,
          ),
        ),
      ),
    );
  }

  // ======================== دکمه ورود ========================
  Widget _buildLoginButton(double height, double fontSize, bool isMobile) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: (isLoading || !dbReady) ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCB001D),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
          shadowColor: const Color(0xFFCB001D).withOpacity(0.3),
          disabledBackgroundColor: const Color(0xFFCB001D).withOpacity(0.5),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "ورود به سیستم",
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: isMobile ? 18 : 20,
                  ),
                ],
              ),
      ),
    );
  }

  // ======================== فوتر ========================
  Widget _buildFooter(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFCB001D),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "نسخه ۲.۰ - سامانه مدیریت ویکتور پایپ",
            style: TextStyle(
              color: const Color(0xFF999999),
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFCB001D),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
// lib/dashboard/pages/admins_page.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../database/database_helper.dart';

class AdminsPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const AdminsPage({super.key, required this.currentUser});

  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50, 100];

  // Selection
  final Set<int> _selectedIds = {};

  // Form controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  int? _editingId;
  String? _selectedImagePath;
  XFile? _selectedImageFile;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    try {
      final admins = await _db.getAdmins();
      setState(() {
        _admins = admins;
        _isLoading = false;
        _selectedIds.clear();
        _currentPage = 1;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('خطا در بارگذاری مدیران', Colors.red);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  List<Map<String, dynamic>> get _paginatedAdmins {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= _admins.length) {
      _currentPage = 1;
      return _admins.take(_itemsPerPage).toList();
    }
    return _admins.sublist(
      start,
      end > _admins.length ? _admins.length : end,
    );
  }

  int get _totalPages => (_admins.length / _itemsPerPage).ceil();

  void _changePage(int newPage) {
    if (newPage >= 1 && newPage <= _totalPages) {
      setState(() {
        _currentPage = newPage;
        _selectedIds.clear();
      });
    }
  }

  void _changeItemsPerPage(int? newSize) {
    if (newSize != null) {
      setState(() {
        _itemsPerPage = newSize;
        _currentPage = 1;
        _selectedIds.clear();
      });
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final currentIds = _paginatedAdmins.map((m) => m['id'] as int).toList();
      final allSelected = currentIds.every((id) => _selectedIds.contains(id));
      if (allSelected) {
        _selectedIds.removeAll(currentIds);
      } else {
        _selectedIds.addAll(currentIds);
      }
    });
  }

  void _clearForm() {
    _usernameController.clear();
    _passwordController.clear();
    _fullNameController.clear();
    _emailController.clear();
    _selectedImagePath = null;
    _selectedImageFile = null;
    setState(() => _editingId = null);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImageFile = image;
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      _showSnackbar('خطا در انتخاب عکس', Colors.red);
    }
  }

  void _openAddDialog() {
    _clearForm();
    showDialog(
      context: context,
      builder: (context) => _buildDialog(
        title: 'افزودن مدیر جدید',
        isEdit: false,
      ),
    );
  }

  void _openEditDialog(Map<String, dynamic> admin) {
    _usernameController.text = admin['username'] ?? '';
    _passwordController.text = '';
    _fullNameController.text = admin['full_name'] ?? '';
    _emailController.text = admin['email'] ?? '';
    _selectedImagePath = admin['profile_pic'];
    _selectedImageFile = null;
    setState(() => _editingId = admin['id']);

    showDialog(
      context: context,
      builder: (context) => _buildDialog(
        title: 'ویرایش مدیر',
        isEdit: true,
      ),
    );
  }

  Widget _buildDialog({
    required String title,
    required bool isEdit,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            Icon(
              isEdit ? Icons.edit : Icons.person_add,
              color: const Color(0xFFCB001D),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile Photo
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade100,
                      border: Border.all(
                        color: const Color(0xFFCB001D),
                        width: 2,
                      ),
                      image: _selectedImagePath != null && _selectedImagePath!.isNotEmpty
                          ? DecorationImage(
                              image: FileImage(File(_selectedImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _selectedImagePath == null || _selectedImagePath!.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                color: Colors.grey.shade400,
                                size: 32,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'انتخاب عکس',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _fullNameController,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: 'نام کامل *',
                    labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCB001D)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _usernameController,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: 'نام کاربری *',
                    labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCB001D)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'رمز عبور جدید (اختیاری)' : 'رمز عبور *',
                    labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCB001D)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'ایمیل',
                    labelStyle: const TextStyle(color: Color(0xFFCB001D), fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCB001D)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'لغو',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: _isProcessing ? null : () => _saveAdmin(isEdit),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB001D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    isEdit ? 'ذخیره' : 'افزودن',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAdmin(bool isEdit) async {
    if (_fullNameController.text.trim().isEmpty) {
      _showSnackbar('لطفاً نام کامل را وارد کنید', Colors.red);
      return;
    }
    if (_usernameController.text.trim().isEmpty) {
      _showSnackbar('لطفاً نام کاربری را وارد کنید', Colors.red);
      return;
    }
    if (!isEdit && _passwordController.text.trim().isEmpty) {
      _showSnackbar('لطفاً رمز عبور را وارد کنید', Colors.red);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final adminData = {
        'full_name': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'admin',
        'profile_pic': _selectedImagePath,
      };

      if (isEdit) {
        if (_passwordController.text.trim().isNotEmpty) {
          adminData['password'] = _passwordController.text.trim();
        }
        await _db.updateAdmin(_editingId!, adminData);
        _showSnackbar('مدیر ویرایش شد ✅', Colors.green);
      } else {
        adminData['password'] = _passwordController.text.trim();
        await _db.insertAdmin(adminData);
        _showSnackbar('مدیر اضافه شد ✅', Colors.green);
      }

      Navigator.pop(context);
      _clearForm();
      await _loadAdmins();
    } catch (e) {
      _showSnackbar(e.toString(), Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteAdmin(Map<String, dynamic> admin) async {
    if (admin['id'] == widget.currentUser['id']) {
      _showSnackbar('نمی‌توانید خودتان را حذف کنید', Colors.red);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              SizedBox(width: 10),
              Text(
                'حذف مدیر',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          content: Text(
            'آیا از حذف "${admin['full_name']}" اطمینان دارید؟',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو', style: TextStyle(fontSize: 13)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('حذف', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _db.deleteAdmin(admin['id']);
        _showSnackbar('مدیر حذف شد 🗑️', Colors.green);
        await _loadAdmins();
      } catch (e) {
        _showSnackbar(e.toString(), Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              SizedBox(width: 10),
              Text(
                'حذف انتخاب‌شده‌ها',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          content: Text(
            'آیا از حذف ${_selectedIds.length} مدیر انتخاب‌شده اطمینان دارید؟',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو', style: TextStyle(fontSize: 13)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('حذف همه', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        setState(() => _isLoading = true);
        try {
          for (var id in _selectedIds) {
            if (id == widget.currentUser['id']) continue;
            await _db.deleteAdmin(id);
          }
          _showSnackbar('${_selectedIds.length} مدیر حذف شدند 🗑️', Colors.green);
          await _loadAdmins();
        } catch (e) {
          _showSnackbar(e.toString(), Colors.red);
          setState(() => _isLoading = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مدیران سیستم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                    SizedBox(height: 2),
                    Text('مدیریت حساب‌های کاربری با دسترسی کامل', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  ],
                ),
                Row(
                  children: [
                    if (_selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFFCB001D), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${_selectedIds.length} انتخاب شده',
                              style: const TextStyle(color: Color(0xFFCB001D), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    if (_selectedIds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        tooltip: 'حذف انتخاب‌شده‌ها',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _openAddDialog,
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: const Text('مدیر جدید', style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB001D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                _buildStatCard('تعداد کل مدیران', _admins.length.toString()),
                const SizedBox(width: 12),
                _buildStatCard('مدیران فعال', _admins.length.toString()),
                const SizedBox(width: 12),
                _buildStatCard('خودتان', '1', Icons.person, Colors.blue),
              ],
            ),
            const SizedBox(height: 16),

            // Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
                  : _admins.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('هیچ مدیری یافت نشد', style: TextStyle(fontSize: 14, color: Colors.grey)),
                              SizedBox(height: 6),
                              Text('روی دکمه "مدیر جدید" کلیک کنید', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
                                  ],
                                  border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.06), width: 1),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: 900,
                                    child: ListView.builder(
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _paginatedAdmins.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          final currentIds = _paginatedAdmins.map((m) => m['id'] as int).toList();
                                          final allSelected = currentIds.every((id) => _selectedIds.contains(id));
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFCB001D).withOpacity(0.05),
                                              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 40,
                                                  child: Checkbox(
                                                    value: allSelected && currentIds.isNotEmpty,
                                                    onChanged: (_) => _toggleSelectAll(),
                                                    activeColor: const Color(0xFFCB001D),
                                                    checkColor: Colors.white,
                                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                _buildHeaderCell('عکس', 50),
                                                _buildHeaderCell('#', 35),
                                                _buildHeaderCell('نام کامل', 150),
                                                _buildHeaderCell('نام کاربری', 120),
                                                _buildHeaderCell('ایمیل', 180),
                                                _buildHeaderCell('وضعیت', 80),
                                                const SizedBox(width: 80),
                                              ],
                                            ),
                                          );
                                        }

                                        final admin = _paginatedAdmins[index - 1];
                                        final isSelected = _selectedIds.contains(admin['id'] as int);
                                        final isSelf = admin['id'] == widget.currentUser['id'];

                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFFCB001D).withOpacity(0.04) : null,
                                            border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 40,
                                                child: Checkbox(
                                                  value: isSelected,
                                                  onChanged: isSelf ? null : (_) => _toggleSelection(admin['id'] as int),
                                                  activeColor: const Color(0xFFCB001D),
                                                  checkColor: Colors.white,
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              // Profile Photo
                                              SizedBox(
                                                width: 50,
                                                child: Container(
                                                  width: 35,
                                                  height: 35,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.grey.shade100,
                                                    image: admin['profile_pic'] != null && admin['profile_pic'].isNotEmpty
                                                        ? DecorationImage(
                                                            image: FileImage(File(admin['profile_pic'])),
                                                            fit: BoxFit.cover,
                                                          )
                                                        : null,
                                                    border: Border.all(
                                                      color: isSelf ? const Color(0xFFCB001D) : Colors.grey.shade300,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: admin['profile_pic'] == null || admin['profile_pic'].isEmpty
                                                      ? Center(
                                                          child: Text(
                                                            admin['full_name']?.isNotEmpty == true
                                                                ? admin['full_name'][0]
                                                                : '?',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: isSelf ? const Color(0xFFCB001D) : Colors.grey.shade600,
                                                            ),
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              _buildDataCell((index).toString(), 35),
                                              SizedBox(
                                                width: 150,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        admin['full_name'] ?? '-',
                                                        style: TextStyle(
                                                          fontWeight: isSelf ? FontWeight.w600 : FontWeight.normal,
                                                          fontSize: 12,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (isSelf) ...[
                                                      const SizedBox(width: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFCB001D),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Text(
                                                          'خود',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 8,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              _buildDataCell(admin['username'] ?? '-', 120),
                                              _buildDataCell(admin['email'] ?? '-', 180),
                                              SizedBox(
                                                width: 80,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Text(
                                                    'فعال',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.green,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.edit_outlined, color: const Color(0xFFCB001D), size: 18),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    onPressed: () => _openEditDialog(admin),
                                                    tooltip: 'ویرایش',
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.delete_outline,
                                                      color: isSelf ? Colors.grey.shade400 : Colors.red.shade400,
                                                      size: 18,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    onPressed: isSelf ? null : () => _deleteAdmin(admin),
                                                    tooltip: isSelf ? 'نمی‌توانید خود را حذف کنید' : 'حذف',
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Pagination
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('نمایش:', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFCB001D).withOpacity(0.2)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _itemsPerPage,
                                            onChanged: _changeItemsPerPage,
                                            items: _pageSizeOptions.map((size) {
                                              return DropdownMenuItem<int>(
                                                value: size,
                                                child: Text(size.toString(), style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 12)),
                                              );
                                            }).toList(),
                                            dropdownColor: Colors.white,
                                            icon: Icon(Icons.arrow_drop_down, color: const Color(0xFFCB001D), size: 18),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text('در هر صفحه', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text('صفحه $_currentPage از $_totalPages', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right, color: Color(0xFFCB001D), size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left, color: Color(0xFFCB001D), size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: Color(0xFF1A1A2E),
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF1A1A2E),
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, [IconData? icon, Color? color]) {
    final cardColor = color ?? const Color(0xFFCB001D);
    final cardIcon = icon ?? Icons.admin_panel_settings;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: cardColor.withOpacity(0.06), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(cardIcon, color: cardColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 1),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
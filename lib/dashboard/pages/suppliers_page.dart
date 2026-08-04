import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  final DatabaseHelper _db = DatabaseHelper();
  String _searchQuery = '';

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _pageSizeOptions = [5, 10, 20, 30, 50, 100];

  // Selection
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getSuppliers();
      setState(() {
        _suppliers = data;
        _isLoading = false;
        _selectedIds.clear();
        _currentPage = 1;
      });
    } catch (e) {
      print('Error loading suppliers: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSuppliers {
    if (_searchQuery.isEmpty) return _suppliers;
    return _suppliers.where((supplier) {
      return supplier['name'].toString().contains(_searchQuery) ||
          supplier['phone'].toString().contains(_searchQuery) ||
          supplier['email'].toString().contains(_searchQuery) ||
          supplier['address'].toString().contains(_searchQuery);
    }).toList();
  }

  // Get paginated data
  List<Map<String, dynamic>> get _paginatedSuppliers {
    final filtered = _filteredSuppliers;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= filtered.length) {
      _currentPage = 1;
      return filtered.take(_itemsPerPage).toList();
    }
    return filtered.sublist(
      start,
      end > filtered.length ? filtered.length : end,
    );
  }

  int get _totalPages => (_filteredSuppliers.length / _itemsPerPage).ceil();

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
      final currentIds = _paginatedSuppliers.map((m) => m['id'] as int).toList();
      final allSelected = currentIds.every((id) => _selectedIds.contains(id));
      if (allSelected) {
        _selectedIds.removeAll(currentIds);
      } else {
        _selectedIds.addAll(currentIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Text(
                      l10n.suppliers,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.suppliersSubtitle ?? 'مدیریت اطلاعات فروشندگان و تامین‌کنندگان',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFFCB001D),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_selectedIds.length} ${l10n.selected}',
                              style: const TextStyle(
                                color: Color(0xFFCB001D),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showAddSupplierDialog,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(
                        l10n.addSupplier,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCB001D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats Cards
            Row(
              children: [
                _buildStatCard(l10n.totalSuppliers, _suppliers.length.toString(), Icons.business_outlined, l10n),
                const SizedBox(width: 16),
                _buildStatCard(l10n.active, _suppliers.length.toString(), Icons.check_circle_outline, l10n, Colors.green),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFCB001D).withOpacity(0.1),
                ),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _currentPage = 1;
                  });
                },
                decoration: InputDecoration(
                  hintText: l10n.searchSuppliers,
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: const Color(0xFFCB001D),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Table with Pagination
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFCB001D),
                      ),
                    )
                  : _filteredSuppliers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.business_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noSuppliersFound,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Table with Checkbox
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: const Color(0xFFCB001D).withOpacity(0.06),
                                    width: 1,
                                  ),
                                ),
                                child: ListView.builder(
                                  itemCount: _paginatedSuppliers.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      // Header Row with Select All
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCB001D).withOpacity(0.05),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey.shade200,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 44,
                                              child: Checkbox(
                                                value: _paginatedSuppliers.isNotEmpty &&
                                                    _paginatedSuppliers.every(
                                                      (m) => _selectedIds.contains(m['id'] as int),
                                                    ),
                                                onChanged: (_) => _toggleSelectAll(),
                                                activeColor: const Color(0xFFCB001D),
                                                checkColor: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                l10n.supplierName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Color(0xFF1A1A2E),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                l10n.phone,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Color(0xFF1A1A2E),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                l10n.email,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Color(0xFF1A1A2E),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                l10n.address,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Color(0xFF1A1A2E),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            const SizedBox(width: 80),
                                          ],
                                        ),
                                      );
                                    }

                                    final supplier = _paginatedSuppliers[index - 1];
                                    final isSelected = _selectedIds.contains(supplier['id'] as int);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFCB001D).withOpacity(0.04)
                                            : null,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade100,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Checkbox
                                          SizedBox(
                                            width: 44,
                                            child: Checkbox(
                                              value: isSelected,
                                              onChanged: (_) => _toggleSelection(supplier['id'] as int),
                                              activeColor: const Color(0xFFCB001D),
                                              checkColor: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Name
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  supplier['name'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Color(0xFF1A1A2E),
                                                  ),
                                                ),
                                                Text(
                                                  supplier['email'] ?? '-',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Phone
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              supplier['phone'] ?? '-',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13,
                                                color: Color(0xFF1A1A2E),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          // Email
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              supplier['email'] ?? '-',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13,
                                                color: Color(0xFF1A1A2E),
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Address
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              supplier['address'] ?? '-',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13,
                                                color: Color(0xFF1A1A2E),
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Actions
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.info_outline,
                                                  color: Colors.blue.shade700,
                                                  size: 20,
                                                ),
                                                tooltip: l10n.supplierDetails,
                                                onPressed: () {
                                                  _showSupplierDetailsDialog(supplier, l10n);
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit_outlined,
                                                  color: const Color(0xFFCB001D),
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  _showEditSupplierDialog(supplier, l10n);
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red.shade400,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  _showDeleteDialog(supplier, l10n);
                                                },
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

                            // Pagination Controls
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Items per page
                                  Row(
                                    children: [
                                      Text(
                                        l10n.show,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFFCB001D).withOpacity(0.2),
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _itemsPerPage,
                                            onChanged: _changeItemsPerPage,
                                            items: _pageSizeOptions.map((size) {
                                              return DropdownMenuItem<int>(
                                                value: size,
                                                child: Text(
                                                  size.toString(),
                                                  style: const TextStyle(
                                                    color: Color(0xFF1A1A2E),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            dropdownColor: Colors.white,
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                              color: const Color(0xFFCB001D),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.perPage,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Page info and controls
                                  Row(
                                    children: [
                                   Text('${l10n.page} $_currentPage ${l10n.pageOf} $_totalPages',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.chevron_right,
                                          color: Color(0xFFCB001D),
                                        ),
                                        onPressed: _currentPage > 1
                                            ? () => _changePage(_currentPage - 1)
                                            : null,
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.chevron_left,
                                          color: Color(0xFFCB001D),
                                        ),
                                        onPressed: _currentPage < _totalPages
                                            ? () => _changePage(_currentPage + 1)
                                            : null,
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

  Widget _buildStatCard(String title, String value, IconData icon, AppLocalizations l10n, [Color? color]) {
    final cardColor = color ?? const Color(0xFFCB001D);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: cardColor.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cardColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
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

  void _showAddSupplierDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.addSupplier,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(l10n.supplierNameRequired, Icons.business_outlined, nameController, l10n),
              const SizedBox(height: 12),
              _buildTextField(l10n.phoneRequired, Icons.phone_outlined, phoneController, l10n),
              const SizedBox(height: 12),
              _buildTextField(l10n.email, Icons.email_outlined, emailController, l10n),
              const SizedBox(height: 12),
              _buildTextField(l10n.address, Icons.location_on_outlined, addressController, l10n),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.pleaseEnterNameAndPhone),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final supplier = {
                'name': nameController.text,
                'phone': phoneController.text,
                'email': emailController.text,
                'address': addressController.text,
              };

              final result = await _db.insertSupplier(supplier);
              Navigator.pop(context);

              if (result != -1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.supplierAddedSuccess),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadSuppliers();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.errorAddingSupplier),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB001D),
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showEditSupplierDialog(Map<String, dynamic> supplier, AppLocalizations l10n) {
    final nameController = TextEditingController(text: supplier['name']);
    final phoneController = TextEditingController(text: supplier['phone']);
    final emailController = TextEditingController(text: supplier['email'] ?? '');
    final addressController = TextEditingController(text: supplier['address'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.editSupplier,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(l10n.supplierNameRequired, Icons.business_outlined, nameController, l10n),
              const SizedBox(height: 12),
              _buildTextField(l10n.phoneRequired, Icons.phone_outlined, phoneController, l10n),
              const SizedBox(height: 12),
              _buildTextField(l10n.email, Icons.email_outlined, emailController, l10n),
              const SizedBox(height: 12),
              _buildTextField(l10n.address, Icons.location_on_outlined, addressController, l10n),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.pleaseEnterNameAndPhone),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final updatedSupplier = {
                'name': nameController.text,
                'phone': phoneController.text,
                'email': emailController.text,
                'address': addressController.text,
              };

              final result = await _db.updateSupplier(supplier['id'], updatedSupplier);
              Navigator.pop(context);

              if (result != -1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.supplierUpdatedSuccess),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadSuppliers();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.errorUpdatingSupplier),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB001D),
            ),
            child: Text(l10n.update),
          ),
        ],
      ),
    );
  }

void _showSupplierDetailsDialog(Map<String, dynamic> supplier, AppLocalizations l10n) async {
  final rawMaterials = await _db.getRawMaterialsBySupplier(supplier['id']);
  // FIX: Change this line
  // OLD: final loans = await _db.getSellLoans(source: 'supplier', supplierId: supplier['id']);
  // NEW:
  final loans = await _db.getSupplierLoans(supplierId: supplier['id']);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${l10n.supplierDetails}: ${supplier['name'] ?? '-'}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.phone}: ${supplier['phone'] ?? '-'}'),
              const SizedBox(height: 6),
              Text('${l10n.email}: ${supplier['email'] ?? '-'}'),
              const SizedBox(height: 6),
              Text('${l10n.address}: ${supplier['address'] ?? '-'}'),
              const SizedBox(height: 12),
              Text(l10n.relatedRawMaterials, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (rawMaterials.isEmpty)
                Text(l10n.noRawMaterialsFound)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rawMaterials.map((material) {
                    final currency = material['currency'] ?? 'AFN';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ${material['name'] ?? '-'} - ${material['seller_payment'] ?? '-'} $currency / ${l10n.initialPayment}: ${material['seller_paid_amount'] ?? '-'} $currency - ${l10n.method}: ${material['seller_payment_method'] == 'cash' ? l10n.cash : material['seller_payment_method'] == 'loan_full' ? l10n.fullLoan : material['seller_payment_method'] == 'loan_partial' ? l10n.partialLoan : '-'}'),
                        const SizedBox(height: 4),
                      ],
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              Text(l10n.supplierLoans, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (loans.isEmpty)
                Text(l10n.noLoansFound)
              else
                Column(
                  children: loans.map((loan) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${l10n.invoiceNumber}: ${loan['invoice_number'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${l10n.loanType}: ${loan['loan_type'] == 'full' ? l10n.fullLoan : loan['loan_type'] == 'partial' ? l10n.partialLoan : '-'}'),
                          Text('${l10n.totalAmount}: ${loan['total_amount'] ?? 0} ${loan['currency'] ?? ''}'),
                          Text('${l10n.paidAmount}: ${loan['paid_amount'] ?? 0} ${loan['currency'] ?? ''}'),
                          Text('${l10n.remainingAmount}: ${loan['remaining_amount'] ?? 0} ${loan['currency'] ?? ''}'),
                          Text('${l10n.date}: ${loan['date'] ?? '-'}'),
                          if (loan['created_at'] != null) Text('${l10n.createdAt}: ${loan['created_at']}'),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close, style: const TextStyle(color: Color(0xFF888888))),
        ),
      ],
    ),
  );
}
  void _showDeleteDialog(Map<String, dynamic> supplier, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.deleteSupplier,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        content: Text(
          '${l10n.deleteConfirmation} "${supplier['name']}"؟',
          style: const TextStyle(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await _db.deleteSupplier(supplier['id']);
              Navigator.pop(context);

              if (result != -1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.supplierDeletedSuccess),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadSuppliers();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.errorDeletingSupplier),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, AppLocalizations l10n) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFFCB001D),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFCB001D), size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: const Color(0xFFCB001D).withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFCB001D),
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: const Color(0xFFCB001D).withOpacity(0.2),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
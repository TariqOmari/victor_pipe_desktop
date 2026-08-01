import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class CustomersCompaniesPage extends StatefulWidget {
  const CustomersCompaniesPage({super.key});

  @override
  State<CustomersCompaniesPage> createState() => _CustomersCompaniesPageState();
}

class _CustomersCompaniesPageState extends State<CustomersCompaniesPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _companies = [];

  String _searchQuery = '';
  String _selectedTab = 'customers';

  // Customer form controllers
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerNicknameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerEmailController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();
  final TextEditingController _customerTypeController = TextEditingController();

  // Company form controllers
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyPhoneController = TextEditingController();
  final TextEditingController _companyEmailController = TextEditingController();
  final TextEditingController _companyAddressController = TextEditingController();
  final TextEditingController _companyTypeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerNicknameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _customerAddressController.dispose();
    _customerTypeController.dispose();
    _companyNameController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _companyAddressController.dispose();
    _companyTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _db.getCustomers();
      final companies = await _db.getCompanies();
      if (!mounted) return;
      setState(() {
        _customers = customers.map((item) {
          final transactions = _decodeTransactions(item['transactions']);
          return {
            ...item,
            'transactions': transactions,
          };
        }).toList();
        _companies = companies.map((item) {
          final transactions = _decodeTransactions(item['transactions']);
          return {
            ...item,
            'transactions': transactions,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar(l10n.errorLoadingDataCC, Colors.red);
    }
  }

  List<Map<String, dynamic>> _decodeTransactions(dynamic value) {
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map<Map<String, dynamic>>((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return {'date': '', 'product': '', 'amount': 0, 'status': ''};
          }).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  String _encodeTransactions(List<Map<String, dynamic>> transactions) {
    return jsonEncode(transactions);
  }

  // ======================== Customer Management Methods ========================
  void _addCustomer() {
    final l10n = AppLocalizations.of(context)!;
    _customerNameController.clear();
    _customerNicknameController.clear();
    _customerPhoneController.clear();
    _customerEmailController.clear();
    _customerAddressController.clear();
    _customerTypeController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addCustomer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF1A1A1A))),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller: _customerNameController, label: l10n.fullNameLabel, icon: Icons.person_outline, hint: l10n.fullNameHint, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _customerNicknameController, label: l10n.nickname, icon: Icons.badge_outlined, hint: l10n.nicknameHint, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _customerPhoneController, label: l10n.phoneNumberLabel, icon: Icons.phone_outlined, hint: l10n.phoneHint, keyboardType: TextInputType.phone, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _customerEmailController, label: l10n.emailLabel, icon: Icons.email_outlined, hint: l10n.emailHint, keyboardType: TextInputType.emailAddress, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _customerAddressController, label: l10n.addressLabel, icon: Icons.location_on_outlined, hint: l10n.addressHint, maxLines: 2, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _customerTypeController, label: l10n.type, icon: Icons.category_outlined, hint: l10n.typeHint, l10n: l10n),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (_customerNameController.text.trim().isEmpty) {
                _showSnackbar(l10n.pleaseEnterCustomerName, Colors.red);
                return;
              }
              final type = _customerTypeController.text.trim().isEmpty ? l10n.individual : _customerTypeController.text.trim();
              final payload = {
                'name': _customerNameController.text.trim(),
                'nickname': _customerNicknameController.text.trim(),
                'phone': _customerPhoneController.text.trim(),
                'email': _customerEmailController.text.trim(),
                'address': _customerAddressController.text.trim(),
                'type': type,
                'transactions': _encodeTransactions([]),
              };
              final id = await _db.insertCustomer(payload);
              if (id == -1) {
                _showSnackbar(l10n.errorAddingCustomer, Colors.red);
                return;
              }
              if (!mounted) return;
              setState(() {
                _customers.add({
                  ...payload,
                  'id': id,
                  'transactions': <Map<String, dynamic>>[],
                });
              });
              Navigator.pop(context);
              _showSnackbar(l10n.customerAddedSuccess, Colors.green);
            },
            style: _buildButtonStyle(),
            child: Text(l10n.addCustomer),
          ),
        ],
      ),
    );
  }

  void _editCustomer(Map<String, dynamic> customer) {
    final l10n = AppLocalizations.of(context)!;
    _customerNameController.text = customer['name']?.toString() ?? '';
    _customerNicknameController.text = customer['nickname']?.toString() ?? '';
    _customerPhoneController.text = customer['phone']?.toString() ?? '';
    _customerEmailController.text = customer['email']?.toString() ?? '';
    _customerAddressController.text = customer['address']?.toString() ?? '';
    _customerTypeController.text = customer['type']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editCustomer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF1A1A1A))),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller: _customerNameController, label: l10n.fullNameLabel, icon: Icons.person_outline, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _customerNicknameController, label: l10n.nickname, icon: Icons.badge_outlined, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _customerPhoneController, label: l10n.phoneNumberLabel, icon: Icons.phone_outlined, keyboardType: TextInputType.phone, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _customerEmailController, label: l10n.emailLabel, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _customerAddressController, label: l10n.addressLabel, icon: Icons.location_on_outlined, maxLines: 2, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _customerTypeController, label: l10n.type, icon: Icons.category_outlined, hint: l10n.typeHint, l10n: l10n),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (_customerNameController.text.trim().isEmpty) {
                _showSnackbar(l10n.pleaseEnterCustomerName, Colors.red);
                return;
              }
              final type = _customerTypeController.text.trim().isEmpty ? l10n.individual : _customerTypeController.text.trim();
              final transactions = List<Map<String, dynamic>>.from(customer['transactions'] ?? []);
              final payload = {
                'name': _customerNameController.text.trim(),
                'nickname': _customerNicknameController.text.trim(),
                'phone': _customerPhoneController.text.trim(),
                'email': _customerEmailController.text.trim(),
                'address': _customerAddressController.text.trim(),
                'type': type,
                'transactions': _encodeTransactions(transactions),
              };
              final result = await _db.updateCustomer(customer['id'], payload);
              if (result == -1) {
                _showSnackbar(l10n.errorUpdatingCustomer, Colors.red);
                return;
              }
              if (!mounted) return;
              setState(() {
                final index = _customers.indexWhere((c) => c['id'] == customer['id']);
                if (index != -1) {
                  _customers[index] = {
                    'id': customer['id'],
                    ...payload,
                    'transactions': transactions,
                  };
                }
              });
              Navigator.pop(context);
              _showSnackbar(l10n.customerUpdatedSuccess, Colors.blue);
            },
            style: _buildButtonStyle(),
            child: Text(l10n.saveChangesPage),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(Map<String, dynamic> customer) {
    final l10n = AppLocalizations.of(context)!;
    _showDeleteDialog(
      context,
      title: l10n.deleteCustomer,
      content: '${l10n.deleteConfirmation} "${customer['name']}"؟',
      l10n: l10n,
      onConfirm: () async {
        final result = await _db.deleteCustomer(customer['id']);
        if (result == -1) {
          _showSnackbar(l10n.errorDeletingCustomer, Colors.red);
          return;
        }
        if (!mounted) return;
        setState(() {
          _customers.removeWhere((c) => c['id'] == customer['id']);
        });
        _showSnackbar(l10n.customerDeletedSuccess, Colors.red);
      },
    );
  }

  // ======================== Company Management Methods ========================
  void _addCompany() {
    final l10n = AppLocalizations.of(context)!;
    _companyNameController.clear();
    _companyPhoneController.clear();
    _companyEmailController.clear();
    _companyAddressController.clear();
    _companyTypeController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addCompany, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF1A1A1A))),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller: _companyNameController, label: l10n.companyNameLabelPage, icon: Icons.business_outlined, hint: l10n.companyNameHint, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _companyPhoneController, label: l10n.phoneNumberLabel, icon: Icons.phone_outlined, hint: l10n.phoneHint, keyboardType: TextInputType.phone, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _companyEmailController, label: l10n.emailLabel, icon: Icons.email_outlined, hint: l10n.emailHint, keyboardType: TextInputType.emailAddress, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _companyAddressController, label: l10n.addressLabel, icon: Icons.location_on_outlined, hint: l10n.companyAddressHint, maxLines: 2, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _companyTypeController, label: l10n.type, icon: Icons.category_outlined, hint: l10n.typeHint, l10n: l10n),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (_companyNameController.text.trim().isEmpty) {
                _showSnackbar(l10n.pleaseEnterCompanyName, Colors.red);
                return;
              }
              final type = _companyTypeController.text.trim().isEmpty ? l10n.corporate : _companyTypeController.text.trim();
              final payload = {
                'name': _companyNameController.text.trim(),
                'phone': _companyPhoneController.text.trim(),
                'email': _companyEmailController.text.trim(),
                'address': _companyAddressController.text.trim(),
                'type': type,
                'transactions': _encodeTransactions([]),
              };
              final id = await _db.insertCompany(payload);
              if (id == -1) {
                _showSnackbar(l10n.errorAddingCompany, Colors.red);
                return;
              }
              if (!mounted) return;
              setState(() {
                _companies.add({
                  ...payload,
                  'id': id,
                  'transactions': <Map<String, dynamic>>[],
                });
              });
              Navigator.pop(context);
              _showSnackbar(l10n.companyAddedSuccess, Colors.green);
            },
            style: _buildButtonStyle(),
            child: Text(l10n.addCompany),
          ),
        ],
      ),
    );
  }

  void _editCompany(Map<String, dynamic> company) {
    final l10n = AppLocalizations.of(context)!;
    _companyNameController.text = company['name']?.toString() ?? '';
    _companyPhoneController.text = company['phone']?.toString() ?? '';
    _companyEmailController.text = company['email']?.toString() ?? '';
    _companyAddressController.text = company['address']?.toString() ?? '';
    _companyTypeController.text = company['type']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editCompany, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF1A1A1A))),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller: _companyNameController, label: l10n.companyNameLabelPage, icon: Icons.business_outlined, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _companyPhoneController, label: l10n.phoneNumberLabel, icon: Icons.phone_outlined, keyboardType: TextInputType.phone, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _companyEmailController, label: l10n.emailLabel, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _companyAddressController, label: l10n.addressLabel, icon: Icons.location_on_outlined, maxLines: 2, l10n: l10n),
              const SizedBox(height: 10),
              _buildTextField(controller: _companyTypeController, label: l10n.type, icon: Icons.category_outlined, hint: l10n.typeHint, l10n: l10n),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (_companyNameController.text.trim().isEmpty) {
                _showSnackbar(l10n.pleaseEnterCompanyName, Colors.red);
                return;
              }
              final type = _companyTypeController.text.trim().isEmpty ? l10n.corporate : _companyTypeController.text.trim();
              final transactions = List<Map<String, dynamic>>.from(company['transactions'] ?? []);
              final payload = {
                'name': _companyNameController.text.trim(),
                'phone': _companyPhoneController.text.trim(),
                'email': _companyEmailController.text.trim(),
                'address': _companyAddressController.text.trim(),
                'type': type,
                'transactions': _encodeTransactions(transactions),
              };
              final result = await _db.updateCompany(company['id'], payload);
              if (result == -1) {
                _showSnackbar(l10n.errorUpdatingCompany, Colors.red);
                return;
              }
              if (!mounted) return;
              setState(() {
                final index = _companies.indexWhere((c) => c['id'] == company['id']);
                if (index != -1) {
                  _companies[index] = {
                    'id': company['id'],
                    ...payload,
                    'transactions': transactions,
                  };
                }
              });
              Navigator.pop(context);
              _showSnackbar(l10n.companyUpdatedSuccess, Colors.blue);
            },
            style: _buildButtonStyle(),
            child: Text(l10n.saveChangesPage),
          ),
        ],
      ),
    );
  }

  void _deleteCompany(Map<String, dynamic> company) {
    final l10n = AppLocalizations.of(context)!;
    _showDeleteDialog(
      context,
      title: l10n.deleteCompany,
      content: '${l10n.deleteConfirmation} "${company['name']}"؟',
      l10n: l10n,
      onConfirm: () async {
        final result = await _db.deleteCompany(company['id']);
        if (result == -1) {
          _showSnackbar(l10n.errorDeletingCompany, Colors.red);
          return;
        }
        if (!mounted) return;
        setState(() {
          _companies.removeWhere((c) => c['id'] == company['id']);
        });
        _showSnackbar(l10n.companyDeletedSuccess, Colors.red);
      },
    );
  }

  // ======================== Transaction History Display ========================
  Future<void> _showTransactionHistory(Map<String, dynamic> entity, bool isCustomer) async {
    final l10n = AppLocalizations.of(context)!;
    final entityName = entity['name']?.toString() ?? '';
    final embeddedTransactions = List<Map<String, dynamic>>.from(entity['transactions'] ?? []);
    final salesHistory = await _getSalesHistoryForEntity(entityName, isCustomer);
    final transactions = salesHistory.isNotEmpty ? salesHistory : embeddedTransactions;
    final title = isCustomer ? l10n.customerTransactionHistoryPage : l10n.companyTransactionHistoryPage;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 24,
        backgroundColor: Colors.white,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB001D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isCustomer ? Icons.person : Icons.business,
                          color: const Color(0xFFCB001D),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            entity['name'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildTransactionStats(transactions, l10n),
              const SizedBox(height: 16),
              Expanded(
                child: transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isCustomer ? l10n.noCustomerTransactions : l10n.noCompanyTransactions,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          return _buildTransactionItem(transaction, index, l10n);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionStats(List<Map<String, dynamic>> transactions, AppLocalizations l10n) {
    int total = 0;
    for (var t in transactions) {
      final amount = t['amount'];
      if (amount is int) {
        total += amount;
      } else if (amount is double) {
        total += amount.toInt();
      }
    }
    
    final completed = transactions.where((t) => t['status'] == l10n.completedStatusPage).length;
    final pending = transactions.where((t) => t['status'] == l10n.pendingStatusPage).length;

    return Row(
      children: [
        _buildStatChip(l10n.totalAmountPage, total.toString(), Colors.blue),
        const SizedBox(width: 12),
        _buildStatChip(l10n.completedStatusPage, completed.toString(), Colors.green),
        const SizedBox(width: 12),
        _buildStatChip(l10n.pendingStatusPage, pending.toString(), Colors.orange),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction, int index, AppLocalizations l10n) {
    Color statusColor;
    switch (transaction['status']) {
      case 'تکمیل شده':
        statusColor = Colors.green;
        break;
      case 'در انتظار':
        statusColor = Colors.orange;
        break;
      case 'ارسال شده':
        statusColor = Colors.blue;
        break;
      case 'لغو شده':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(transaction['status']),
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['product'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  transaction['date'],
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              transaction['status'],
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            transaction['amount'].toString().replaceAllMapped(
              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'تکمیل شده':
        return Icons.check_circle_rounded;
      case 'در انتظار':
        return Icons.pending_rounded;
      case 'ارسال شده':
        return Icons.local_shipping_rounded;
      case 'لغو شده':
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  Future<List<Map<String, dynamic>>> _getSalesHistoryForEntity(String entityName, bool isCustomer) async {
    try {
      final allSales = await _db.getSalesInvoices();
      final normalized = entityName.trim().toLowerCase();
      if (normalized.isEmpty) return [];

      return allSales.where((sale) {
        final customerName = sale['customer_name']?.toString().trim().toLowerCase() ?? '';
        final customerCompany = sale['customer_company']?.toString().trim().toLowerCase() ?? '';
        return isCustomer ? customerName == normalized : customerCompany == normalized;
      }).map((sale) {
        return {
          'date': sale['date'] ?? sale['created_at'] ?? '',
          'product': sale['product_name'] ?? '',
          'amount': sale['final_price'] ?? 0,
          'status': 'تکمیل شده',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ======================== Helper Widgets ========================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppLocalizations l10n,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 12,
        ),
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFCB001D),
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFCB001D),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildEntityCard(Map<String, dynamic> entity, bool isCustomer, AppLocalizations l10n) {
    final transactions = List<Map<String, dynamic>>.from(entity['transactions'] ?? []);
    final totalTransactions = transactions.length;
    final entityType = (entity['type'] ?? '').toString().trim();
    final typeLabel = entityType.isNotEmpty ? entityType : (isCustomer ? l10n.individual : l10n.corporate);
    
    int totalAmount = 0;
    for (var t in transactions) {
      final amount = t['amount'];
      if (amount is int) {
        totalAmount += amount;
      } else if (amount is double) {
        totalAmount += amount.toInt();
      }
    }

    final Color primaryColor = isCustomer 
        ? const Color(0xFF2563EB)
        : const Color(0xFF7C3AED);
    
    final IconData mainIcon = isCustomer ? Icons.person_rounded : Icons.business_center_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: primaryColor.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      entity['name'][0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entity['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF1A1A1A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (entity['nickname'] != null && entity['nickname'].isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${l10n.nickname}: ${entity['nickname']}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCustomer
                                  ? Colors.blue.withOpacity(0.12)
                                  : Colors.purple.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCustomer ? Icons.person_outline : Icons.business_outlined,
                                  size: 12,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 12,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$totalTransactions ${l10n.transactionsLabel}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        icon: Icons.phone_outlined,
                        value: entity['phone'] ?? '-',
                        color: primaryColor,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoRow(
                        icon: Icons.email_outlined,
                        value: entity['email'] ?? '-',
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                if (entity['address'] != null && entity['address'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    icon: Icons.location_on_outlined,
                    value: entity['address'],
                    color: primaryColor,
                  ),
                ],
                
                const SizedBox(height: 14),
                Divider(
                  color: Colors.grey.shade200,
                  height: 1,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_money_rounded,
                            size: 16,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            totalAmount > 0
                                ? '${totalAmount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} ${l10n.rial}'
                                : l10n.noTransaction,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: totalAmount > 0 ? primaryColor : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _showTransactionHistory(entity, isCustomer),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: primaryColor.withOpacity(0.06),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: primaryColor,
                          ),
                          label: Text(
                            l10n.history,
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey.shade100,
                          child: IconButton(
                            onPressed: () => isCustomer
                                ? _editCustomer(entity)
                                : _editCompany(entity),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.red.shade50,
                          child: IconButton(
                            onPressed: () => isCustomer
                                ? _deleteCustomer(entity)
                                : _deleteCompany(entity),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 14,
                              color: Colors.red.shade400,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isCustomer, AppLocalizations l10n) {
    final count = isCustomer ? _customers.length : _companies.length;
    final title = isCustomer ? l10n.customersCompaniesPage : l10n.companiesListPage;
    final icon = isCustomer
        ? Icons.people_alt_outlined
        : Icons.business_outlined;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFCB001D).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFCB001D),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.manage} $title',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  '${l10n.totalCount}: $count',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: isCustomer ? _addCustomer : _addCompany,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCB001D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            isCustomer ? l10n.addCustomer : l10n.addCompany,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: l10n.searchByCustomerName,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFCB001D),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              title: l10n.customersCompaniesPage,
              icon: Icons.people_alt_outlined,
              isSelected: _selectedTab == 'customers',
              count: _customers.length,
              onTap: () => setState(() => _selectedTab = 'customers'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTab(
              title: l10n.companiesListPage,
              icon: Icons.business_outlined,
              isSelected: _selectedTab == 'companies',
              count: _companies.length,
              onTap: () => setState(() => _selectedTab = 'companies'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCB001D).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: const Color(0xFFCB001D).withOpacity(0.2),
                )
              : Border.all(
                  color: Colors.transparent,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFFCB001D)
                  : Colors.grey.shade500,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFFCB001D)
                    : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFCB001D).withOpacity(0.15)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? const Color(0xFFCB001D)
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context, {
    required String title,
    required String content,
    required AppLocalizations l10n,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  ButtonStyle _buildButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFCB001D),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final searchText = _searchQuery.trim().toLowerCase();
    final filteredCustomers = _customers.where((c) {
      final haystack = '${c['name'] ?? ''} ${c['nickname'] ?? ''} ${c['phone'] ?? ''} ${c['type'] ?? ''}'.toLowerCase();
      return haystack.contains(searchText);
    }).toList();

    final filteredCompanies = _companies.where((c) {
      final haystack = '${c['name'] ?? ''} ${c['phone'] ?? ''} ${c['email'] ?? ''} ${c['type'] ?? ''}'.toLowerCase();
      return haystack.contains(searchText);
    }).toList();

    final bool isEmpty = (_selectedTab == 'customers' && filteredCustomers.isEmpty) ||
        (_selectedTab == 'companies' && filteredCompanies.isEmpty);

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              _buildTabs(l10n),
              const SizedBox(height: 24),
              _buildHeader(_selectedTab == 'customers', l10n),
              const SizedBox(height: 20),
              _buildSearchAndFilter(l10n),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
                    : Container(
                        decoration: BoxDecoration(color: Colors.transparent),
                        child: isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedTab == 'customers' ? Icons.people_outline : Icons.business_outlined,
                                      size: 80,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _selectedTab == 'customers' ? l10n.noCustomersFound : l10n.noCompaniesFound,
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(l10n.clickAddButton, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  children: [
                                    if (_selectedTab == 'customers')
                                      ...filteredCustomers.map((customer) => _buildEntityCard(customer, true, l10n)),
                                    if (_selectedTab == 'companies')
                                      ...filteredCompanies.map((company) => _buildEntityCard(company, false, l10n)),
                                  ],
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
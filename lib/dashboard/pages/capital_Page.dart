import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';

class CapitalPage extends StatefulWidget {
  const CapitalPage({super.key});

  @override
  State<CapitalPage> createState() => _CapitalPageState();
}

class _CapitalPageState extends State<CapitalPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _assets = [];
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final assets = await _db.getCapitalAssets();
      final transactions = await _db.getCapitalTransactions();
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _transactions = transactions;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_findAsset('fixed') == null || _findAsset('cash') == null) {
          _showInitialSetupDialog();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('❌ خطا در بارگذاری اطلاعات سرمایه', Colors.red);
    }
  }

  Map<String, dynamic>? _findAsset(String type) {
    for (final asset in _assets) {
      if (asset['asset_type'] == type) {
        return asset;
      }
    }
    return null;
  }

  String _formatCurrency(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '0') ?? 0;
    final fixed = number.toStringAsFixed(0);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < integerPart.length; i++) {
      final index = integerPart.length - i;
      buffer.write(integerPart[i]);
      if (index > 1 && index % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  Future<void> _showInitialSetupDialog() async {
    final fixedController = TextEditingController(text: '10000');
    final cashController = TextEditingController(text: '20000');
    final existingFixed = _findAsset('fixed');
    final existingCash = _findAsset('cash');

    if (existingFixed != null) {
      fixedController.text = (existingFixed['current_balance'] ?? 0).toString();
    }
    if (existingCash != null) {
      cashController.text = (existingCash['current_balance'] ?? 0).toString();
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تنظیم دارایی‌های اولیه'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fixedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'مقدار اولیهسرمایه ثابت',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cashController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'مقدار اولیهسرمایه نقدی',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final fixedValue = double.tryParse(fixedController.text) ?? 0;
                final cashValue = double.tryParse(cashController.text) ?? 0;
                if (fixedValue < 0 || cashValue < 0) {
                  _showSnackbar('مقدار منفی مجاز نیست', Colors.red);
                  return;
                }
                Navigator.pop(context);
                if (existingFixed == null) {
                  await _db.insertCapitalAsset({
                    'asset_type': 'fixed',
                    'name': 'سرمایه ثابت',
                    'current_balance': fixedValue,
                    'initial_balance': fixedValue,
                  });
                } else {
                  await _db.updateCapitalAsset(existingFixed['id'], {
                    'current_balance': fixedValue,
                    'initial_balance': fixedValue,
                  });
                }
                if (existingCash == null) {
                  await _db.insertCapitalAsset({
                    'asset_type': 'cash',
                    'name': 'سرمایه نقدی',
                    'current_balance': cashValue,
                    'initial_balance': cashValue,
                  });
                } else {
                  await _db.updateCapitalAsset(existingCash['id'], {
                    'current_balance': cashValue,
                    'initial_balance': cashValue,
                  });
                }
                _showSnackbar('✅ مقادیر اولیه دارایی‌ها ذخیره شد', Colors.green);
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D)),
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMovementDialog(String assetType, {bool isWithdrawal = false}) async {
    final asset = _findAsset(assetType);
    if (asset == null) {
      _showSnackbar('ابتداسرمایه را تنظیم کنید', Colors.red);
      return;
    }

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = isWithdrawal ? 'برداشت' : 'افزایش';
    String? selectedEnglishDate;
    final dateController = TextEditingController(text: PersianDateConverter.getCurrentPersianDate());

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(assetType == 'fixed' ? 'ثبت افزایش/برداشتسرمایه ثابت' : 'ثبت افزایش/برداشتسرمایه نقدی'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'نوع', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'افزایش', child: Text('افزایش')),
                      DropdownMenuItem(value: 'برداشت', child: Text('برداشت')),
                    ],
                    onChanged: (value) => setDialogState(() => selectedType = value ?? 'افزایش'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'مبلغ', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'توضیحات', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'تاریخ',
                      border: const OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today, color: const Color(0xFFCB001D), size: 18),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          dateController.text = PersianDateConverter.gregorianToJalali(picked);
                          selectedEnglishDate = PersianDateConverter.getEnglishDate(picked);
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount <= 0) {
                      _showSnackbar('مبلغ معتبر وارد کنید', Colors.red);
                      return;
                    }
                    Navigator.pop(context);
                    final delta = selectedType == 'افزایش' ? amount : -amount;
                    final newBalance = (asset['current_balance'] ?? 0) + delta;
                    final transactionPayload = {
                      'asset_type': assetType,
                      'asset_name': assetType == 'fixed' ? 'سرمایه ثابت' : 'سرمایه نقدی',
                      'transaction_type': selectedType,
                      'amount': amount,
                      'description': descriptionController.text.isEmpty ? 'ثبت از صفحه سرمایه' : descriptionController.text,
                      'date': dateController.text,
                      'date_en': selectedEnglishDate ?? PersianDateConverter.getEnglishDate(DateTime.now()),
                    };
                    final txId = await _db.insertCapitalTransaction(transactionPayload);
                    if (txId == -1) {
                      _showSnackbar('❌ خطا در ثبت تراکنش', Colors.red);
                      return;
                    }
                    await _db.updateCapitalAsset(asset['id'], {'current_balance': newBalance});
                    _showSnackbar(selectedType == 'افزایش' ? '✅ افزایش ثبت شد' : '✅ برداشت ثبت شد', Colors.green);
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D)),
                  child: const Text('ذخیره'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteTransaction(Map<String, dynamic> transaction) async {
    final asset = _findAsset(transaction['asset_type']);
    if (asset == null) {
      _showSnackbar('سرمایه پیدا نشد', Colors.red);
      return;
    }
    final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0;
    final delta = transaction['transaction_type'] == 'افزایش' ? -amount : amount;
    final newBalance = (asset['current_balance'] ?? 0) + delta;
    final result = await _db.deleteCapitalTransaction(transaction['id']);
    if (result == -1) {
      _showSnackbar('❌ خطا در حذف تراکنش', Colors.red);
      return;
    }
    await _db.updateCapitalAsset(asset['id'], {'current_balance': newBalance});
    _showSnackbar('✅ تراکنش حذف شد', Colors.green);
    _loadData();
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetCard(String type, String title, String subtitle, Color color) {
    final asset = _findAsset(type);
    final amount = asset != null ? (asset['current_balance'] ?? 0) : 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(type == 'fixed' ? Icons.account_balance : Icons.account_balance_wallet, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('${_formatCurrency(amount)} افغانی', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showMovementDialog(type, isWithdrawal: false),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('افزایش'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showMovementDialog(type, isWithdrawal: true),
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('برداشت'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    final isDeposit = transaction['transaction_type'] == 'افزایش';
    final color = isDeposit ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(isDeposit ? Icons.add_circle_outline : Icons.remove_circle_outline, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction['asset_name'] ?? 'سرمایه', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(transaction['description']?.toString() ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isDeposit ? '+' : '-'}${_formatCurrency(transaction['amount'])} افغانی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 4),
              Text(transaction['date']?.toString() ?? '-', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _deleteTransaction(transaction),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixedAsset = _findAsset('fixed');
    final cashAsset = _findAsset('cash');
    final totalAssets = (fixedAsset != null ? (fixedAsset['current_balance'] ?? 0) : 0) + (cashAsset != null ? (cashAsset['current_balance'] ?? 0) : 0);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مدیریت سرمایه', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                          SizedBox(height: 4),
                          Text('سرمایه ثابت وسرمایه نقدی با ثبت افزایش و برداشت', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showInitialSetupDialog,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('تنظیم دارایی‌ها'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCB001D), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildSummaryCard('جمع سرمایه', '${_formatCurrency(totalAssets)} افغانی', Icons.account_balance_wallet_rounded, const Color(0xFFCB001D)),
                      const SizedBox(width: 8),
                      _buildSummaryCard('سرمایه ثابت', '${_formatCurrency(fixedAsset != null ? (fixedAsset['current_balance'] ?? 0) : 0)} افغانی', Icons.business_center_rounded, Colors.blue.shade700),
                      const SizedBox(width: 8),
                      _buildSummaryCard('سرمایه نقدی', '${_formatCurrency(cashAsset != null ? (cashAsset['current_balance'] ?? 0) : 0)} افغانی', Icons.attach_money_rounded, Colors.green.shade700),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildAssetCard('fixed', 'سرمایه ثابت', 'مقدار اولیه و تغییرات آن', const Color(0xFFCB001D))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildAssetCard('cash', 'سرمایه نقدی', 'موجودی نقد و برداشت‌های آن', Colors.green.shade700)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('تراکنش‌های اخیر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _transactions.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                            child: const Center(child: Text('هنوز تراکنشی ثبت نشده است', style: TextStyle(color: Colors.grey))),
                          )
                        : ListView.builder(
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) => _buildTransactionTile(_transactions[index]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

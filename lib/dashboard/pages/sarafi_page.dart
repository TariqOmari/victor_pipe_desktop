import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';
import '../../utils/sarafi_balance_utils.dart';

class SarafiPage extends StatefulWidget {
  const SarafiPage({super.key});

  @override
  State<SarafiPage> createState() => _SarafiPageState();
}

class _SarafiPageState extends State<SarafiPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _db.getSarafiAccounts();
      final transactions = await _db.getSarafiTransactions();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('خطا در بارگذاری اطلاعات صرافی', Colors.red.shade700);
    }
  }

  Map<String, dynamic>? get _activeAccount {
    if (_accounts.isEmpty) return null;
    return _accounts.first;
  }

  String _formatCurrency(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  String _formatBalance(double balance) {
    return '${_formatCurrency(balance)} USD';
  }

  // ==================== PDF & PRINT FUNCTIONS ====================

  Future<void> _printTransactionReceipt(Map<String, dynamic> transaction) async {
    try {
      final pdf = await _generateReceiptPDF(transaction);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
        name: 'رسید_تراکنش_صرافی_${transaction['id']}',
      );
    } catch (e) {
      _showSnackbar('خطا در چاپ رسید: $e', Colors.red.shade700);
    }
  }

  Future<Uint8List> _generateReceiptPDF(Map<String, dynamic> transaction) async {
    final isDeposit = transaction['transaction_type'] == 'deposit';
    final amount = double.tryParse(transaction['amount_usd']?.toString() ?? '0') ?? 0;
    final balanceAfter = double.tryParse(transaction['balance_after']?.toString() ?? '0') ?? 0;
    final exchangeRate = double.tryParse(transaction['exchange_rate']?.toString() ?? '1') ?? 1;
    final afnAmount = amount * exchangeRate;
    final balanceBefore = isDeposit ? balanceAfter - amount : balanceAfter + amount;

    // Load font
    late final pw.Font ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.grey300,
                  width: 1.5,
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.all(14),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header - Company Logo & Title
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.red,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            'صرافی',
                            style: pw.TextStyle(
                              font: ttf,
                              color: PdfColors.white,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          isDeposit ? 'رسید واریز' : 'رسید برداشت',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: isDeposit ? PdfColors.green : PdfColors.red,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'شماره تراکنش: ${transaction['id']}',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          transaction['date']?.toString() ?? '-',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1, color: PdfColors.grey300),

                  // Amount
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'مبلغ:',
                        style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '${isDeposit ? '+' : '-'} ${_formatCurrency(amount)} USD',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: isDeposit ? PdfColors.green : PdfColors.red,
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey200),

                  // Exchange Rate & AFN
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'نرخ ارز:',
                        style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        '${_formatCurrency(exchangeRate)} AFN',
                        style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'معادل افغانی:',
                        style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        '${_formatCurrency(afnAmount)} AFN',
                        style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 1, color: PdfColors.grey300),

                  // Source Info
                  pw.SizedBox(height: 6),
                  _buildPdfRow(ttf, 'نام فرد/شرکت', transaction['source_name']?.toString() ?? '-', PdfColors.black),
                  _buildPdfRow(ttf, 'شماره حساب منبع', transaction['source_account']?.toString() ?? '-', PdfColors.black),
                  _buildPdfRow(ttf, 'ایمیل', transaction['source_email']?.toString() ?? '-', PdfColors.black),
                  _buildPdfRow(ttf, 'تلفن', transaction['source_phone']?.toString() ?? '-', PdfColors.black),
                  _buildPdfRow(ttf, 'آدرس', transaction['address']?.toString() ?? '-', PdfColors.black),

                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey200),

                  // Balance Info
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'موجودی قبل:',
                        style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        _formatBalance(balanceBefore),
                        style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'موجودی بعد:',
                        style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        _formatBalance(balanceAfter),
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 1, color: PdfColors.grey300),

                  // Note
                  if (transaction['note'] != null && transaction['note'] != 'بدون یادداشت' && transaction['note'] != '-') ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'یادداشت:',
                      style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      transaction['note']?.toString() ?? '',
                      style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700),
                      maxLines: 2,
                    ),
                  ],

                  pw.Spacer(),

                  // Footer
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'امضا: _________________',
                        style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'تاریخ چاپ: ${DateTime.now().year}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')}',
                        style: pw.TextStyle(font: ttf, fontSize: 6, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Center(
                    child: pw.Text(
                      'ویکتور پایپ صنعت - سامانه مدیریت یکپارچه',
                      style: pw.TextStyle(font: ttf, fontSize: 6, color: PdfColors.grey500),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildPdfRow(pw.Font font, String label, String value, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$label:',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 9, color: color),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== UI FUNCTIONS ====================

  Future<void> _showInitialSetupDialog() async {
    final accountController = TextEditingController();
    final balanceController = TextEditingController(text: '20000');
    final noteController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCB001D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance, color: Color(0xFFCB001D)),
              ),
              const SizedBox(width: 12),
              const Text('افزودن حساب صرافی',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: accountController,
                  decoration: InputDecoration(
                    labelText: 'شماره حساب',
                    hintText: 'مثال: 1234567890',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'مبلغ اولیه (USD)',
                    hintText: 'مثال: 20000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'یادداشت',
                    hintText: 'توضیحات اولیه...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.note_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لغو', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final accountNumber = accountController.text.trim();
                final amount = double.tryParse(balanceController.text) ?? 0;
                if (accountNumber.isEmpty) {
                  _showSnackbar('شماره حساب را وارد کنید', Colors.red.shade700);
                  return;
                }
                if (amount <= 0) {
                  _showSnackbar('مبلغ باید بیشتر از صفر باشد', Colors.red.shade700);
                  return;
                }

                Navigator.pop(context);
                final insertedId = await _db.insertSarafiAccount({
                  'account_number': accountNumber,
                  'current_usd_balance': amount,
                  'initial_usd_balance': amount,
                });

                if (insertedId == -1) {
                  _showSnackbar('ذخیره حساب انجام نشد', Colors.red.shade700);
                  return;
                }

                await _db.insertSarafiTransaction({
                  'account_id': insertedId,
                  'transaction_type': 'deposit',
                  'amount_usd': amount,
                  'exchange_rate': 1.0,
                  'amount_afn': amount,
                  'balance_after': amount,
                  'source_name': 'موجودی اولیه',
                  'source_account': accountNumber,
                  'source_email': '-',
                  'source_phone': '-',
                  'date': PersianDateConverter.getCurrentPersianDate(),
                  'date_en': PersianDateConverter.getCurrentEnglishDate(),
                  'address': '-',
                  'note': noteController.text.isEmpty ? 'موجودی اولیه' : noteController.text,
                });

                _showSnackbar('حساب با موفقیت ذخیره شد', Colors.green.shade700);
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCB001D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransactionDialog(String transactionType) async {
    final account = _activeAccount;
    if (account == null) {
      _showSnackbar('ابتدا حساب را ایجاد کنید', Colors.red.shade700);
      return;
    }

    final amountController = TextEditingController();
    final sourceNameController = TextEditingController();
    final sourceAccountController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final noteController = TextEditingController();
    final exchangeRateController = TextEditingController(text: '1');
    final dateController =
        TextEditingController(text: PersianDateConverter.getCurrentPersianDate());
    String? selectedEnglishDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (transactionType == 'deposit'
                              ? Colors.green
                              : Colors.red)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      transactionType == 'deposit'
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: transactionType == 'deposit'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    transactionType == 'deposit' ? 'واریز به موجودی' : 'برداشت از موجودی',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'مبلغ (USD)',
                        hintText: 'مثال: 1000',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sourceNameController,
                      decoration: InputDecoration(
                        labelText: 'نام فرد/شرکت',
                        hintText: 'نام کامل...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sourceAccountController,
                      decoration: InputDecoration(
                        labelText: 'شماره حساب منبع',
                        hintText: 'شماره حساب...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.account_balance_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emailController,
                            decoration: InputDecoration(
                              labelText: 'ایمیل',
                              hintText: 'example@email.com',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: phoneController,
                            decoration: InputDecoration(
                              labelText: 'تلفن',
                              hintText: '09xxxxxxxxx',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'آدرس',
                        hintText: 'آدرس کامل...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: exchangeRateController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'نرخ ارز (USD/AFN)',
                              hintText: 'مثال: 1.0',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.currency_exchange),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: dateController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'تاریخ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: Icon(
                                Icons.calendar_today,
                                color: const Color(0xFFCB001D),
                                size: 18,
                              ),
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
                                  dateController.text =
                                      PersianDateConverter.gregorianToJalali(
                                          picked);
                                  selectedEnglishDate =
                                      PersianDateConverter.getEnglishDate(
                                          picked);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'یادداشت',
                        hintText: 'توضیحات اضافی...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.note_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('لغو', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    final exchangeRate =
                        double.tryParse(exchangeRateController.text) ?? 1;
                    if (amount <= 0) {
                      _showSnackbar('مبلغ باید بیشتر از صفر باشد',
                          Colors.red.shade700);
                      return;
                    }
                    if (exchangeRate <= 0) {
                      _showSnackbar('نرخ ارز باید بیشتر از صفر باشد',
                          Colors.red.shade700);
                      return;
                    }

                    final currentBalance =
                        double.tryParse(
                              account['current_usd_balance']?.toString() ?? '0',
                            ) ??
                            0;
                    if (transactionType == 'withdrawal' &&
                        amount > currentBalance) {
                      _showSnackbar('مبلغ برداشت بیشتر از موجودی است',
                          Colors.red.shade700);
                      return;
                    }

                    Navigator.pop(context);
                    final newBalance = calculateBalanceAfterTransaction(
                      currentBalance,
                      transactionType,
                      amount,
                    );
                    final afnEquivalent = amount * exchangeRate;
                    final txId = await _db.insertSarafiTransaction({
                      'account_id': account['id'],
                      'transaction_type': transactionType,
                      'amount_usd': amount,
                      'exchange_rate': exchangeRate,
                      'amount_afn': afnEquivalent,
                      'balance_after': newBalance,
                      'source_name': sourceNameController.text.trim().isEmpty
                          ? '-'
                          : sourceNameController.text.trim(),
                      'source_account': sourceAccountController.text.trim()
                              .isEmpty
                          ? '-'
                          : sourceAccountController.text.trim(),
                      'source_email': emailController.text.trim().isEmpty
                          ? '-'
                          : emailController.text.trim(),
                      'source_phone': phoneController.text.trim().isEmpty
                          ? '-'
                          : phoneController.text.trim(),
                      'date': dateController.text,
                      'date_en': selectedEnglishDate ??
                          PersianDateConverter.getCurrentEnglishDate(),
                      'address': addressController.text.trim().isEmpty
                          ? '-'
                          : addressController.text.trim(),
                      'note': noteController.text.trim().isEmpty
                          ? 'بدون یادداشت'
                          : noteController.text.trim(),
                    });

                    if (txId == -1) {
                      _showSnackbar('ثبت تراکنش انجام نشد',
                          Colors.red.shade700);
                      return;
                    }

                    await _db.updateSarafiAccountBalance(
                      account['id'],
                      newBalance,
                    );
                    _showSnackbar(
                      transactionType == 'deposit'
                          ? 'واریز با موفقیت ثبت شد'
                          : 'برداشت با موفقیت ثبت شد',
                      Colors.green.shade700,
                    );
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('ثبت'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showTransactionDetails(Map<String, dynamic> transaction) async {
    final isDeposit = transaction['transaction_type'] == 'deposit';
    final amount = double.tryParse(transaction['amount_usd']?.toString() ?? '0') ?? 0;
    final balanceAfter = double.tryParse(transaction['balance_after']?.toString() ?? '0') ?? 0;
    final exchangeRate = double.tryParse(transaction['exchange_rate']?.toString() ?? '1') ?? 1;
    final afnAmount = amount * exchangeRate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isDeposit ? Colors.green : Colors.red).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isDeposit ? Icons.trending_up : Icons.trending_down,
                        color: isDeposit ? Colors.green : Colors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDeposit ? 'واریز' : 'برداشت',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            transaction['date']?.toString() ?? '-',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isDeposit ? '+' : '-'}${_formatCurrency(amount)} USD',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDeposit ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 30, thickness: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        icon: Icons.person_outline,
                        label: 'نام فرد/شرکت',
                        value: transaction['source_name']?.toString() ?? '-',
                      ),
                      _buildDetailRow(
                        icon: Icons.account_balance_outlined,
                        label: 'شماره حساب منبع',
                        value: transaction['source_account']?.toString() ?? '-',
                      ),
                      _buildDetailRow(
                        icon: Icons.email_outlined,
                        label: 'ایمیل',
                        value: transaction['source_email']?.toString() ?? '-',
                      ),
                      _buildDetailRow(
                        icon: Icons.phone_outlined,
                        label: 'تلفن',
                        value: transaction['source_phone']?.toString() ?? '-',
                      ),
                      _buildDetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'آدرس',
                        value: transaction['address']?.toString() ?? '-',
                      ),
                      const Divider(height: 24, thickness: 1),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailCard(
                              label: 'نرخ ارز',
                              value: '${_formatCurrency(exchangeRate)} AFN',
                              icon: Icons.currency_exchange,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailCard(
                              label: 'معادل افغانی',
                              value: '${_formatCurrency(afnAmount)} AFN',
                              icon: Icons.money,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailCard(
                              label: 'موجودی قبل',
                              value: _formatBalance(
                                isDeposit
                                    ? balanceAfter - amount
                                    : balanceAfter + amount,
                              ),
                              icon: Icons.account_balance_wallet,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailCard(
                              label: 'موجودی بعد',
                              value: _formatBalance(balanceAfter),
                              icon: Icons.account_balance,
                              color: const Color(0xFFCB001D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.note_outlined,
                        label: 'یادداشت',
                        value: transaction['note']?.toString() ?? 'بدون یادداشت',
                        isMultiline: true,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _printTransactionReceipt(transaction);
                              },
                              icon: const Icon(Icons.print, color: Color(0xFFCB001D)),
                              label: const Text('چاپ رسید', style: TextStyle(color: Color(0xFFCB001D))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCB001D)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteTransaction(transaction);
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              label: const Text('حذف تراکنش', style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: isMultiline ? 1.4 : 1,
                  ),
                  maxLines: isMultiline ? 3 : 1,
                  overflow: isMultiline ? TextOverflow.ellipsis : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(Map<String, dynamic> transaction) async {
    final account = _activeAccount;
    if (account == null) {
      _showSnackbar('حسابی برای ویرایش وجود ندارد', Colors.red.shade700);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف تراکنش'),
        content: const Text('آیا از حذف این تراکنش اطمینان دارید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final amount = double.tryParse(transaction['amount_usd']?.toString() ?? '0') ?? 0;
    final currentBalance = double.tryParse(account['current_usd_balance']?.toString() ?? '0') ?? 0;
    final newBalance = transaction['transaction_type'] == 'deposit'
        ? currentBalance - amount
        : currentBalance + amount;

    final result = await _db.deleteSarafiTransaction(transaction['id']);
    if (result == -1) {
      _showSnackbar('حذف تراکنش انجام نشد', Colors.red.shade700);
      return;
    }

    await _db.updateSarafiAccountBalance(account['id'], newBalance);
    _showSnackbar('تراکنش حذف شد', Colors.green.shade700);
    _loadData();
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

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    final isDeposit = transaction['transaction_type'] == 'deposit';
    final color = isDeposit ? Colors.green.shade700 : Colors.red.shade700;
    final amount = double.tryParse(transaction['amount_usd']?.toString() ?? '0') ?? 0;
    final balanceAfter = double.tryParse(transaction['balance_after']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () => _showTransactionDetails(transaction),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction['source_name']?.toString() ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        transaction['date']?.toString() ?? '-',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isDeposit ? '+' : '-'}${_formatCurrency(amount)} USD',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB001D).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'موجودی: ${_formatCurrency(balanceAfter)}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFCB001D),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (transaction['note'] != null &&
                    transaction['note'] != 'بدون یادداشت' &&
                    transaction['note'] != '-')
                  Expanded(
                    child: Text(
                      transaction['note'],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isDeposit ? 'واریز' : 'برداشت',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_left,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = _activeAccount;
    final currentBalance =
        account != null
            ? double.tryParse(account['current_usd_balance']?.toString() ?? '0') ??
                0
            : 0;
    final initialBalance =
        account != null
            ? double.tryParse(account['initial_usd_balance']?.toString() ?? '0') ??
                0
            : 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFCB001D),
                    ),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFCB001D), Color(0xFFA00016)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCB001D).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.currency_exchange_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'صرافی',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'مدیریت حساب و تراکنش‌ها',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (account != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'موجودی: ${_formatCurrency(currentBalance)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Account Section
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFCB001D).withOpacity(0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    account == null
                                        ? 'هنوز حسابی ثبت نشده'
                                        : 'حساب فعلی صرافی',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                                if (account == null)
                                  ElevatedButton.icon(
                                    onPressed: _showInitialSetupDialog,
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 18,
                                    ),
                                    label: const Text('افزودن حساب'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFCB001D),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (account == null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'شماره حساب و مبلغ اولیه را وارد کنید. این مقدار یک بار ثبت می‌شود و بعد از آن فقط با تراکنش‌های واریز/برداشت قابل تغییر است.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.account_balance,
                                      color: Color(0xFFCB001D),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'شماره حساب: ${account['account_number']}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildSummaryCard(
                                    'موجودی فعلی',
                                    '${_formatCurrency(currentBalance)} USD',
                                    Icons.account_balance_wallet_rounded,
                                    const Color(0xFFCB001D),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSummaryCard(
                                    'موجودی اولیه',
                                    '${_formatCurrency(initialBalance)} USD',
                                    Icons.savings_rounded,
                                    Colors.blue.shade700,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showTransactionDialog('deposit'),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 18,
                                      ),
                                      label: const Text('واریز'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showTransactionDialog('withdrawal'),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 18,
                                      ),
                                      label: const Text('برداشت'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Transactions Header
                      Row(
                        children: [
                          const Text(
                            'تراکنش‌ها',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCB001D).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_transactions.length} مورد',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFCB001D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Transactions List
                      Expanded(
                        child:
                            _transactions.isEmpty
                                ? Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 48,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'هنوز تراکنشی ثبت نشده است',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'با دکمه‌های واریز یا برداشت شروع کنید',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: _transactions.length,
                                  itemBuilder: (context, index) =>
                                      _buildTransactionTile(
                                        _transactions[index],
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
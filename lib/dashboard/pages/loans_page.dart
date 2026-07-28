import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';

class LoansPage extends StatefulWidget {
  final String? loanSource;
  const LoansPage({super.key, this.loanSource});

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isLoading = true;
  List<Map<String, dynamic>> _loans = [];

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    try {
      final loans = await _db.getSellLoans(source: widget.loanSource);
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('خطا در بارگذاری قرضه‌ها', Colors.red);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _openLoanDetail(Map<String, dynamic> loan) async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final payController = TextEditingController();
        return AlertDialog(
          title: Text('جزئیات قرض: ${loan['invoice_number'] ?? '-'}'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مشتری: ${loan['customer_name'] ?? '-'}'),
                Text('شرکت: ${loan['customer_company'] ?? '-'}'),
                const SizedBox(height: 8),
                Text('مبلغ کل: ${loan['total_amount'] ?? 0} ${loan['currency'] ?? ''}'),
                Text('پرداخت شده: ${loan['paid_amount'] ?? 0} ${loan['currency'] ?? ''}'),
                Text('باقی‌مانده: ${loan['remaining_amount'] ?? 0} ${loan['currency'] ?? ''}'),
                const SizedBox(height: 12),
                TextField(controller: payController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ بازپرداخت')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(payController.text) ?? 0;
                if (amount <= 0) {
                  _showSnackbar('مبلغ معتبر وارد کنید', Colors.red);
                  return;
                }
                final loanId = loan['id'] as int;
                final paid = (loan['paid_amount'] ?? 0) + amount;
                final remaining = (loan['total_amount'] ?? 0) - paid;
                final updatedRemaining = remaining < 0 ? 0 : remaining;
                final paymentId = await _db.insertSellLoanPayment({
                  'loan_id': loanId,
                  'amount': amount,
                  'note': 'بازپرداخت از طریق UI',
                  'date': PersianDateConverter.getCurrentPersianDate(),
                  'date_en': PersianDateConverter.getEnglishDate(DateTime.now()),
                });
                await _db.updateSellLoanPaid(loanId, paid, updatedRemaining);
                Navigator.pop(context);
                await _loadLoans();
                if (paymentId != -1) {
                  final payment = {'id': paymentId, 'loan_id': loanId, 'amount': amount, 'date': PersianDateConverter.getCurrentPersianDate()};
                  final updatedLoan = {
                    ...loan,
                    'paid_amount': paid,
                    'remaining_amount': updatedRemaining,
                  };
                  _generateRepaymentPdf(updatedLoan, payment);
                }
                _showSnackbar('بازپرداخت ثبت شد', Colors.green);
              },
              child: const Text('ثبت بازپرداخت'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _generateRepaymentPdf(Map<String, dynamic> loan, Map<String, dynamic> payment) async {
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
        pageFormat: PdfPageFormat(100 * PdfPageFormat.mm, 140 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(14),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red900,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Center(
                    child: pw.Text('رسید بازپرداخت قرض', style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('شماره فاکتور: ${loan['invoice_number'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('مشتری: ${loan['customer_name'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('شرکت: ${loan['customer_company'] ?? '-'}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    pw.Text('تاریخ: ${payment['date'] ?? ''}', style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700)),
                  ]),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red900, width: 1.5),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('جزئیات پرداخت', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                    pw.SizedBox(height: 6),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('مبلغ پرداختی', style: pw.TextStyle(font: ttf, fontSize: 11)),
                      pw.Text('${_formatCurrency(payment['amount'])} ${loan['currency'] ?? ''}', style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('نوع قرض', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      pw.Text('${loan['loan_type'] == 'full' ? 'قرض کامل' : loan['loan_type'] == 'partial' ? 'قرض جزئی' : '-'}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('کل قرض', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      pw.Text('${_formatCurrency(loan['total_amount'])} ${loan['currency'] ?? ''}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('پرداخت شده تا کنون', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      pw.Text('${_formatCurrency(loan['paid_amount'])} ${loan['currency'] ?? ''}', style: pw.TextStyle(font: ttf, fontSize: 10)),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('باقی‌مانده', style: pw.TextStyle(font: ttf, fontSize: 10)),
                      pw.Text('${_formatCurrency(loan['remaining_amount'])} ${loan['currency'] ?? ''}', style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      loan['remaining_amount'] != null && (loan['remaining_amount'] as num) <= 0
                        ? 'وضعیت: تسویه کامل'
                        : 'وضعیت: بدهی فعال',
                      style: pw.TextStyle(font: ttf, fontSize: 10, color: loan['remaining_amount'] != null && (loan['remaining_amount'] as num) <= 0 ? PdfColors.green800 : PdfColors.red800, fontWeight: pw.FontWeight.bold),
                    ),
                  ]),
                ),
                pw.Divider(color: PdfColors.grey500),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('باقی‌مانده: ${_formatCurrency(loan['remaining_amount'])} ${loan['currency'] ?? ''}', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  String _formatCurrency(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '0') ?? 0;
    final formatted = number.toStringAsFixed(0);
    return formatted.replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (match) => ',');
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey.shade900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanRow(Map<String, dynamic> loan) {
    final remaining = loan['remaining_amount'] ?? 0;
    final statusColor = remaining is num && remaining <= 0 ? Colors.green.shade700 : Colors.red.shade700;
    return InkWell(
      onTap: () => _openLoanDetail(loan),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${loan['invoice_number'] ?? '-'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 6),
                  Text('${loan['customer_name'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Color(0xFF4A4A4A))),
                  Text('${loan['customer_company'] ?? '-'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Text('تاریخ: ${loan['date'] ?? '-'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('جمع: ${_formatCurrency(loan['total_amount'])} ${loan['currency'] ?? ''}', style: const TextStyle(fontSize: 12)),
                  Text('پرداخت شده: ${_formatCurrency(loan['paid_amount'])} ${loan['currency'] ?? ''}', style: const TextStyle(fontSize: 12)),
                  Text('باقی: ${_formatCurrency(loan['remaining_amount'])} ${loan['currency'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      remaining is num && remaining <= 0 ? 'تسویه شده' : 'باقی مانده',
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFFCB001D)),
                    onPressed: () => _openLoanDetail(loan),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalLoanCount = _loans.length;
    final totalLoanAmount = _loans.fold<double>(0, (sum, loan) => sum + (double.tryParse(loan['total_amount']?.toString() ?? '0') ?? 0));
    final totalPaidAmount = _loans.fold<double>(0, (sum, loan) => sum + (double.tryParse(loan['paid_amount']?.toString() ?? '0') ?? 0));
    final totalRemainingAmount = _loans.fold<double>(0, (sum, loan) => sum + (double.tryParse(loan['remaining_amount']?.toString() ?? '0') ?? 0));

    final pageTitle = widget.loanSource == 'supplier' ? 'مدیریت قرضه فروشندگان' : 'مدیریت قرضه مشتریان و شرکت ها';
    return Scaffold(
      appBar: AppBar(title: Text(pageTitle), backgroundColor: const Color(0xFFCB001D)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatCard('قرض‌ها', totalLoanCount.toString(), Icons.account_balance_wallet, const Color(0xFFCB001D)),
                      const SizedBox(width: 12),
                      _buildStatCard('کل مبلغ', '${_formatCurrency(totalLoanAmount)} ${_loans.isNotEmpty ? _loans.first['currency'] ?? '' : ''}', Icons.payments, Colors.blue.shade700),
                      const SizedBox(width: 12),
                      _buildStatCard('مجموع پرداختی', '${_formatCurrency(totalPaidAmount)} ${_loans.isNotEmpty ? _loans.first['currency'] ?? '' : ''}', Icons.receipt_long, Colors.green.shade700),
                      const SizedBox(width: 12),
                      _buildStatCard('باقی‌مانده', '${_formatCurrency(totalRemainingAmount)} ${_loans.isNotEmpty ? _loans.first['currency'] ?? '' : ''}', Icons.pending, Colors.orange.shade700),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: _loans.isEmpty
                        ? const Center(child: Text('قرضی موجود نیست'))
                        : ListView.builder(
                            itemCount: _loans.length,
                            itemBuilder: (context, index) => _buildLoanRow(_loans[index]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

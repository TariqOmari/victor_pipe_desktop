import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../utils/date_converter.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class CustomerCompanyLoansPage extends StatefulWidget {
  const CustomerCompanyLoansPage({super.key});

  @override
  State<CustomerCompanyLoansPage> createState() => _CustomerCompanyLoansPageState();
}

class _CustomerCompanyLoansPageState extends State<CustomerCompanyLoansPage> {
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
      final loans = await _db.getSellLoans();
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final l10n = AppLocalizations.of(context)!;
      _showSnackbar(l10n.loansLoadingError, Colors.red);
    }
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

  Future<void> _openLoanDetail(Map<String, dynamic> loan) async {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.isEnglish;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final payController = TextEditingController();
          return Directionality(
            textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                '${l10n.loansLoanDetails}: ${loan['invoice_number'] ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l10n.loansCustomerName}: ${loan['customer_name'] ?? '-'}'),
                    Text('${l10n.loansCompanyName}: ${loan['customer_company'] ?? '-'}'),
                    const SizedBox(height: 8),
                    Text('${l10n.loansTotalAmount}: ${_formatCurrency(loan['total_amount'])} ${loan['currency'] ?? ''}'),
                    Text('${l10n.loansPaid}: ${_formatCurrency(loan['paid_amount'])} ${loan['currency'] ?? ''}'),
                    Text('${l10n.loansRemaining}: ${_formatCurrency(loan['remaining_amount'])} ${loan['currency'] ?? ''}'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: payController,
                      keyboardType: TextInputType.number,
                      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
                      textAlign: isEnglish ? TextAlign.left : TextAlign.right,
                      decoration: InputDecoration(
                        labelText: l10n.loansRepaymentAmount,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.loansClose),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(payController.text) ?? 0;
                    if (amount <= 0) {
                      _showSnackbar(l10n.loansEnterAmount, Colors.red);
                      return;
                    }
                    final loanId = loan['id'] as int;
                    final paid = (loan['paid_amount'] ?? 0) + amount;
                    final remaining = (loan['total_amount'] ?? 0) - paid;
                    final updatedRemaining = remaining < 0 ? 0 : remaining;

                    final paymentId = await _db.insertSellLoanPayment({
                      'loan_id': loanId,
                      'amount': amount,
                      'note': l10n.loansRegisterRepayment,
                      'date': PersianDateConverter.getCurrentPersianDate(),
                      'date_en': PersianDateConverter.getEnglishDate(DateTime.now()),
                    });
                    await _db.updateSellLoanPaid(loanId, paid, updatedRemaining);

                    Navigator.pop(context);
                    await _loadLoans();

                    if (paymentId != -1) {
                      final payment = {
                        'id': paymentId,
                        'loan_id': loanId,
                        'amount': amount,
                        'date': PersianDateConverter.getCurrentPersianDate()
                      };
                      final updatedLoan = {
                        ...loan,
                        'paid_amount': paid,
                        'remaining_amount': updatedRemaining,
                      };
                      _generateRepaymentPdf(updatedLoan, payment);
                    }
                    _showSnackbar(l10n.loansRepaymentSaved, Colors.green);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCB001D),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.loansRegisterRepayment),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _generateRepaymentPdf(Map<String, dynamic> loan, Map<String, dynamic> payment) async {
    final l10n = AppLocalizations.of(context)!;
    
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
                    child: pw.Text(
                      l10n.loansRepaymentReceipt,
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${l10n.loansInvoiceNumber}: ${loan['invoice_number'] ?? '-'}',
                        style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '${l10n.loansCustomerName}: ${loan['customer_name'] ?? '-'}',
                        style: pw.TextStyle(font: ttf, fontSize: 10),
                      ),
                      pw.Text(
                        '${l10n.loansCompanyName}: ${loan['customer_company'] ?? '-'}',
                        style: pw.TextStyle(font: ttf, fontSize: 10),
                      ),
                      pw.Text(
                        '${l10n.loansDate}: ${payment['date'] ?? ''}',
                        style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red900, width: 1.5),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        l10n.loansPaymentDetails,
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(l10n.loansPaymentAmount, style: pw.TextStyle(font: ttf, fontSize: 11)),
                          pw.Text(
                            '${_formatCurrency(payment['amount'])} ${loan['currency'] ?? ''}',
                            style: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(l10n.loansLoanType, style: pw.TextStyle(font: ttf, fontSize: 10)),
                          pw.Text(
                            loan['loan_type'] == 'full' 
                                ? l10n.loansFullLoan 
                                : loan['loan_type'] == 'partial' 
                                    ? l10n.loansPartialLoan 
                                    : '-',
                            style: pw.TextStyle(font: ttf, fontSize: 10),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(l10n.loansTotalLoan, style: pw.TextStyle(font: ttf, fontSize: 10)),
                          pw.Text(
                            '${_formatCurrency(loan['total_amount'])} ${loan['currency'] ?? ''}',
                            style: pw.TextStyle(font: ttf, fontSize: 10),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(l10n.loansPaidSoFar, style: pw.TextStyle(font: ttf, fontSize: 10)),
                          pw.Text(
                            '${_formatCurrency(loan['paid_amount'])} ${loan['currency'] ?? ''}',
                            style: pw.TextStyle(font: ttf, fontSize: 10),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(l10n.loansRemainingBalance, style: pw.TextStyle(font: ttf, fontSize: 10)),
                          pw.Text(
                            '${_formatCurrency(loan['remaining_amount'])} ${loan['currency'] ?? ''}',
                            style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        loan['remaining_amount'] != null && (loan['remaining_amount'] as num) <= 0
                            ? l10n.loansStatusSettled
                            : l10n.loansStatusActive,
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 10,
                          color: loan['remaining_amount'] != null && (loan['remaining_amount'] as num) <= 0 
                              ? PdfColors.green800 
                              : PdfColors.red800,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Divider(color: PdfColors.grey500),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '${l10n.loansRemaining}: ${_formatCurrency(loan['remaining_amount'])} ${loan['currency'] ?? ''}',
                    style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
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
    final l10n = AppLocalizations.of(context)!;
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
                  Text(
                    '${loan['invoice_number'] ?? '-'}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${loan['customer_name'] ?? '-'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4A4A4A)),
                  ),
                  Text(
                    '${loan['customer_company'] ?? '-'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.loansDate}: ${loan['date'] ?? '-'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.loansTotal}: ${_formatCurrency(loan['total_amount'])} ${loan['currency'] ?? ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${l10n.loansPaid}: ${_formatCurrency(loan['paid_amount'])} ${loan['currency'] ?? ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${l10n.loansRemaining}: ${_formatCurrency(loan['remaining_amount'])} ${loan['currency'] ?? ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
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
                      remaining is num && remaining <= 0 ? l10n.loansSettled : l10n.loansPending,
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
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isEnglish = languageProvider.isEnglish;

    final totalLoanCount = _loans.length;
    final totalLoanAmount = _loans.fold<double>(0, (sum, loan) => sum + (double.tryParse(loan['total_amount']?.toString() ?? '0') ?? 0));
    final totalPaidAmount = _loans.fold<double>(0, (sum, loan) => sum + (double.tryParse(loan['paid_amount']?.toString() ?? '0') ?? 0));
    final totalRemainingAmount = _loans.fold<double>(0, (sum, loan) => sum + (double.tryParse(loan['remaining_amount']?.toString() ?? '0') ?? 0));

    final currency = _loans.isNotEmpty ? _loans.first['currency'] ?? '' : '';

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.loansPageTitleCustomer),
          backgroundColor: const Color(0xFFCB001D),
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFCB001D)))
              : Column(
                  crossAxisAlignment: isEnglish ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        _buildStatCard(l10n.loansTotalLoans, totalLoanCount.toString(), Icons.account_balance_wallet, const Color(0xFFCB001D)),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          l10n.loansTotalAmount,
                          '${_formatCurrency(totalLoanAmount)} $currency',
                          Icons.payments,
                          Colors.blue.shade700,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          l10n.loansTotalPaid,
                          '${_formatCurrency(totalPaidAmount)} $currency',
                          Icons.receipt_long,
                          Colors.green.shade700,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          l10n.loansTotalRemaining,
                          '${_formatCurrency(totalRemainingAmount)} $currency',
                          Icons.pending,
                          Colors.orange.shade700,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _loans.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.credit_card_off, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.loansNoLoans,
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _loans.length,
                              itemBuilder: (context, index) => _buildLoanRow(_loans[index]),
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
import 'package:flutter_test/flutter_test.dart';
import 'package:victor_project/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sales invoice persistence', () {
    test('insert and fetch sales invoice', () async {
      final db = DatabaseHelper();
      await db.resetDatabase();

      final id = await db.insertSalesInvoice({
        'invoice_number': 'INV-TEST-001',
        'customer_name': 'رضا',
        'product_name': 'لوله',
        'unit_price': 100,
        'total_price': 200,
        'discount': 20,
        'final_price': 180,
        'currency': 'USD',
        'usd_equivalent': 180,
        'afn_equivalent': 1800,
        'date': '1405-01-01',
        'date_en': '2026-03-21',
      });

      expect(id, greaterThan(0));

      final invoices = await db.getSalesInvoices();
      expect(invoices.length, 1);
      expect(invoices.first['invoice_number'], 'INV-TEST-001');
      expect(invoices.first['final_price'], 180);
    });
  });
}

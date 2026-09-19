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

    test('stores multiple product entries in a single invoice', () async {
      final db = DatabaseHelper();
      await db.resetDatabase();

      final id = await db.insertSalesInvoice({
        'invoice_number': 'INV-TEST-002',
        'customer_name': 'نرگس',
        'product_name': 'لوله',
        'unit_price': 100,
        'total_price': 300,
        'final_price': 300,
        'currency': 'USD',
        'usd_equivalent': 300,
        'afn_equivalent': 3000,
        'date': '1405-01-01',
        'date_en': '2026-03-21',
        'items_json': '[{"product_name":"لوله","unit_count":"10","total_weight":"100","unit_price":100,"total_price":1000},{"product_name":"اتصال","unit_count":"2","total_weight":"20","unit_price":150,"total_price":300}]',
      });

      expect(id, greaterThan(0));

      final invoices = await db.getSalesInvoices();
      expect(invoices.length, 1);
      expect(invoices.first['invoice_number'], 'INV-TEST-002');
      expect(invoices.first['items_json'], isNotNull);
      expect(invoices.first['items_json'], contains('اتصال'));
    });
  });
}

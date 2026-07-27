import 'package:flutter_test/flutter_test.dart';
import 'package:victor_project/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Service invoice persistence', () {
    test('insert and fetch a service invoice', () async {
      final db = DatabaseHelper();
      await db.resetDatabase();

      final id = await db.insertServiceInvoice({
        'invoice_number': '10000',
        'customer_name': 'رضا',
        'service_title': 'نصب لوله',
        'service_type': 'سرویس نصب',
        'price': 500,
        'currency': 'USD',
        'exchange_rate': 85,
        'loading_cost': 20,
        'transfer_cost': 10,
        'clearance_cost': 5,
        'discount': 0,
        'final_price': 535,
        'date': '1405-01-01',
        'date_en': '2026-03-21',
      });

      expect(id, greaterThan(0));

      final invoices = await db.getServiceInvoices();
      expect(invoices.length, 1);
      expect(invoices.first['invoice_number'], '10000');
      expect(invoices.first['final_price'], 535);
    });
  });
}

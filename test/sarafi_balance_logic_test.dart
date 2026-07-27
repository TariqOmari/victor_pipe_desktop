import 'package:flutter_test/flutter_test.dart';
import 'package:victor_project/utils/sarafi_balance_utils.dart';

void main() {
  group('sarafi balance logic', () {
    test('deposit increases balance and withdrawal decreases balance', () {
      expect(calculateBalanceAfterTransaction(20000, 'deposit', 1000), 21000);
      expect(calculateBalanceAfterTransaction(20000, 'withdrawal', 1000), 19000);
    });

    test('initial balance can be created only once', () {
      expect(canCreateInitialBalance(false), isTrue);
      expect(canCreateInitialBalance(true), isFalse);
    });
  });
}

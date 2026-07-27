double calculateBalanceAfterTransaction(double currentBalance, String transactionType, double amount) {
  if (transactionType == 'deposit') {
    return currentBalance + amount;
  }
  return currentBalance - amount;
}

bool canCreateInitialBalance(bool hasInitialBalance) {
  return !hasInitialBalance;
}

import 'package:flutter/material.dart';
import 'loans_page.dart';

class SupplierLoansPage extends StatelessWidget {
  const SupplierLoansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoansPage(loanSource: 'supplier');
  }
}

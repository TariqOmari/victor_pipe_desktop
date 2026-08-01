import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);
  
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }
  
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  
  // ============ DASHBOARD ============
  String get dashboard => _get('dashboard');
  String get dashboardTitle => _get('dashboardTitle');
  String get dashboardSubtitle => _get('dashboardSubtitle');
  String get activeUsers => _get('activeUsers');
  String get ton => _get('ton');
  String get kg => _get('kg');
  String get items => _get('items');
  String get value => _get('value');
  String get totalSales => _get('totalSales');
  String get invoices => _get('invoices');
  String get paid => _get('paid');
  String get remaining => _get('remaining');
  String get productions => _get('productions');
  String get sold => _get('sold');
  String get available => _get('available');
  String get returnedSales => _get('returnedSales');
  String get returnedInvoices => _get('returnedInvoices');
  String get customerLoans => _get('customerLoans');
  String get supplierLoans => _get('supplierLoans');
  String get noUsdLoans => _get('noUsdLoans');
  String get totalCapital => _get('totalCapital');
  String get assets => _get('assets');
  String get activeCustomers => _get('activeCustomers');
  String get deposits => _get('deposits');
  String get withdrawals => _get('withdrawals');
  String get activeSuppliers => _get('activeSuppliers');
  String get salesTrend => _get('salesTrend');
  String get viewAll => _get('viewAll');
  String get noDataToDisplay => _get('noDataToDisplay');
  String get noData => _get('noData');
  String get materialDistribution => _get('materialDistribution');
  String get detailedStats => _get('detailedStats');
  String get remainingSales => _get('remainingSales');
  String get totalWaste => _get('totalWaste');
  String get totalExpenses => _get('totalExpenses');
  String get quickAccess => _get('quickAccess');
  String get goingTo => _get('goingTo');
  String get errorLoadingData => _get('errorLoadingData');
  
  // ============ SIDEBAR ============
  String get customers => _get('customers');
  String get customer => _get('customer');
  String get suppliers => _get('suppliers');
  String get rawMaterials => _get('rawMaterials');
  String get sales => _get('sales');
  String get backReturnedSales => _get('backReturnedSales');
  String get services => _get('services');
  String get dailyExpenses => _get('dailyExpenses');
  String get wastes => _get('wastes');
  String get customersCompanies => _get('customersCompanies');
  String get productionManagement => _get('productionManagement');
  String get reports => _get('reports');
  String get capital => _get('capital');
  String get sarafi => _get('sarafi');
  String get admins => _get('admins');
  String get loans => _get('loans');
  String get supplierLoansMenu => _get('supplierLoansMenu');
  String get logout => _get('logout');
  String get logoutTitle => _get('logoutTitle');
  String get logoutMessage => _get('logoutMessage');
  String get cancel => _get('cancel');
  String get confirm => _get('confirm');
  String get admin => _get('admin');
  String get noNotifications => _get('noNotifications');
  String get pageUnderConstruction => _get('pageUnderConstruction');
  String get pageNotAvailable => _get('pageNotAvailable');
  String get language => _get('language');
  String get persian => _get('persian');
  String get english => _get('english');
  
  // ============ EXPENSES ============
  String get expenses => _get('expenses');
  String get expense => _get('expense');
  String get date => _get('date');
  String get category => _get('category');
  String get description => _get('description');
  String get price => _get('price');
  String get currency => _get('currency');
  String get exchangeRate => _get('exchangeRate');
  String get usdEquivalent => _get('usdEquivalent');
  String get addExpense => _get('addExpense');
  String get editExpense => _get('editExpense');
  String get deleteExpense => _get('deleteExpense');
  String get invoiceNumber => _get('invoiceNumber');
  
  // ============ SALES ============
  String get customerName => _get('customerName');
  String get customerPhone => _get('customerPhone');
  String get customerAddress => _get('customerAddress');
  String get customerCompany => _get('customerCompany');
  String get productName => _get('productName');
  String get gender => _get('gender');
  String get size => _get('size');
  String get thickness => _get('thickness');
  String get weight => _get('weight');
  String get unit => _get('unit');
  String get unitPrice => _get('unitPrice');
  String get totalPrice => _get('totalPrice');
  String get loadingCost => _get('loadingCost');
  String get transferCost => _get('transferCost');
  String get clearanceCost => _get('clearanceCost');
  String get discount => _get('discount');
  String get finalPrice => _get('finalPrice');
  String get paymentMethod => _get('paymentMethod');
  String get loanType => _get('loanType');
  String get paidAmount => _get('paidAmount');
  String get remainingAmount => _get('remainingAmount');
  String get saleType => _get('saleType');
  String get addSale => _get('addSale');
  String get editSale => _get('editSale');
  String get deleteSale => _get('deleteSale');
  String get backReturn => _get('backReturn');
  String get backReturnReason => _get('backReturnReason');
  String get company => _get('company');
  String get product => _get('product');
  String get weightPerUnit => _get('weightPerUnit');
  String get unitCount => _get('unitCount');
  String get totalWeight => _get('totalWeight');
  String get unitPricePerKg => _get('unitPricePerKg');
  String get persianDate => _get('persianDate');
  String get loadingTime => _get('loadingTime');
  String get finalCurrency => _get('finalCurrency');
  // transactionType is already defined in CAPITAL section - DO NOT REDEFINE
  // String get transactionType => _get('transactionType'); // REMOVED - DUPLICATE
  String get initialPaymentAmount => _get('initialPaymentAmount');
  String get full => _get('full');
  String get partial => _get('partial');
  String get amountDue => _get('amountDue');
  String get basePrice => _get('basePrice');
  String get normal => _get('normal');
  String get returned => _get('returned');
  String get companyName => _get('companyName');
  String get thicknessShort => _get('thicknessShort');
  String get phoneNumber => _get('phoneNumber');
  String get companyNameLabel => _get('companyNameLabel');
  String get integratedSystem => _get('integratedSystem');
  
  // ============ PRODUCTION ============
  String get productionType => _get('productionType');
  String get loadingProduction => _get('loadingProduction');
  String get length => _get('length');
  String get quantity => _get('quantity');
  String get batch => _get('batch');
  String get status => _get('status');
  String get productionDate => _get('productionDate');
  String get addProduction => _get('addProduction');
  String get editProduction => _get('editProduction');
  String get deleteProduction => _get('deleteProduction');
  
  // ============ LOANS ============
  String get loan => _get('loan');
  String get totalAmount => _get('totalAmount');
  String get dueDate => _get('dueDate');
  String get addLoan => _get('addLoan');
  String get editLoan => _get('editLoan');
  String get deleteLoan => _get('deleteLoan');
  String get loanSource => _get('loanSource');
  String get payment => _get('payment');
  String get addPayment => _get('addPayment');
  String get fullLoan => _get('fullLoan');
  String get partialLoan => _get('partialLoan');
  
  // ============ CAPITAL ============
  String get assetType => _get('assetType');
  String get assetName => _get('assetName');
  String get currentBalance => _get('currentBalance');
  String get initialBalance => _get('initialBalance');
  String get addAsset => _get('addAsset');
  String get editAsset => _get('editAsset');
  String get deleteAsset => _get('deleteAsset');
  String get transactionType => _get('transactionType');
  
  // ============ SARAFI ============
  String get accountNumber => _get('accountNumber');
  String get usdBalance => _get('usdBalance');
  String get afnBalance => _get('afnBalance');
  String get deposit => _get('deposit');
  String get withdrawal => _get('withdrawal');
  String get sourceName => _get('sourceName');
  String get sourceAccount => _get('sourceAccount');
  String get sourceEmail => _get('sourceEmail');
  String get sourcePhone => _get('sourcePhone');
  String get address => _get('address');
  String get note => _get('note');
  String get addTransaction => _get('addTransaction');
  String get editTransaction => _get('editTransaction');
  String get deleteTransaction => _get('deleteTransaction');
  // afnEquivalent is already defined in WASTES section - DO NOT REDEFINE
  // String get afnEquivalent => _get('afnEquivalent'); // REMOVED - DUPLICATE
  
  // ============ WASTES ============
  String get wasteType => _get('wasteType');
  String get partyDetails => _get('partyDetails');
  String get weightKg => _get('weightKg');
  String get quantityAmount => _get('quantityAmount');
  String get wasteValue => _get('wasteValue');
  String get afnEquivalent => _get('afnEquivalent'); // Defined here
  String get addWaste => _get('addWaste');
  String get editWaste => _get('editWaste');
  String get deleteWaste => _get('deleteWaste');
  
  // ============ SERVICES ============
  String get serviceTitle => _get('serviceTitle');
  String get serviceType => _get('serviceType');
  String get serviceDescription => _get('serviceDescription');
  String get addService => _get('addService');
  String get editService => _get('editService');
  String get deleteService => _get('deleteService');
  
  // ============ USERS/ADMINS ============
  String get username => _get('username');
  String get password => _get('password');
  String get fullName => _get('fullName');
  String get email => _get('email');
  String get role => _get('role');
  String get addAdmin => _get('addAdmin');
  String get editAdmin => _get('editAdmin');
  String get deleteAdmin => _get('deleteAdmin');
  String get login => _get('login');
  String get loginError => _get('loginError');
  
  // ============ COMMON ============
  String get save => _get('save');
  String get update => _get('update');
  String get delete => _get('delete');
  String get cancelBtn => _get('cancelBtn');
  String get close => _get('close');
  String get confirmDelete => _get('confirmDelete');
  String get deleteConfirmation => _get('deleteConfirmation');
  String get success => _get('success');
  String get error => _get('error');
  String get loadingText => _get('loadingText');
  String get empty => _get('empty');
  String get search => _get('search');
  String get filter => _get('filter');
  String get export => _get('export');
  String get print => _get('print');
  String get refresh => _get('refresh');
  String get languageSelection => _get('languageSelection');
  String get selected => _get('selected');
  String get page => _get('page');
  String get pageOf => _get('pageOf');
  
  // ============ SUPPLIERS PAGE ============
  String get suppliersSubtitle => _get('suppliersSubtitle');
  String get addSupplier => _get('addSupplier');
  String get totalSuppliers => _get('totalSuppliers');
  String get active => _get('active');
  String get searchSuppliers => _get('searchSuppliers');
  String get noSuppliersFound => _get('noSuppliersFound');
  String get supplierName => _get('supplierName');
  String get phone => _get('phone');
  String get supplierDetails => _get('supplierDetails');
  String get supplierNameRequired => _get('supplierNameRequired');
  String get phoneRequired => _get('phoneRequired');
  String get pleaseEnterNameAndPhone => _get('pleaseEnterNameAndPhone');
  String get supplierAddedSuccess => _get('supplierAddedSuccess');
  String get errorAddingSupplier => _get('errorAddingSupplier');
  String get editSupplier => _get('editSupplier');
  String get supplierUpdatedSuccess => _get('supplierUpdatedSuccess');
  String get errorUpdatingSupplier => _get('errorUpdatingSupplier');
  String get deleteSupplier => _get('deleteSupplier');
  String get supplierDeletedSuccess => _get('supplierDeletedSuccess');
  String get errorDeletingSupplier => _get('errorDeletingSupplier');
  String get relatedRawMaterials => _get('relatedRawMaterials');
  String get noRawMaterialsFound => _get('noRawMaterialsFound');
  String get initialPayment => _get('initialPayment');
  String get method => _get('method');
  String get cash => _get('cash');
  String get noLoansFound => _get('noLoansFound');
  String get createdAt => _get('createdAt');
  String get show => _get('show');
  String get perPage => _get('perPage');
  String get invoiceNumberLabel => _get('invoiceNumberLabel');
  
  // ============ RAW MATERIALS PAGE ============
  String get rawMaterialsManagement => _get('rawMaterialsManagement');
  String get rawMaterialsSubtitle => _get('rawMaterialsSubtitle');
  String get addRawMaterial => _get('addRawMaterial');
  String get totalMaterials => _get('totalMaterials');
  String get stockSummaryByUnit => _get('stockSummaryByUnit');
  String get rawMaterialsTab => _get('rawMaterialsTab');
  String get stockTab => _get('stockTab');
  String get noRawMaterialsInStock => _get('noRawMaterialsInStock');
  String get stockByUnit => _get('stockByUnit');
  String get materialName => _get('materialName');
  String get supplierPhone => _get('supplierPhone');
  String get supplierAddress => _get('supplierAddress');
  String get netWeight => _get('netWeight');
  String get grossWeight => _get('grossWeight');
  String get sellerBasePrice => _get('sellerBasePrice');
  String get commission => _get('commission');
  String get miscellaneous => _get('miscellaneous');
  String get ghurfedari => _get('ghurfedari');
  String get barchalani => _get('barchalani');
  String get purchaseType => _get('purchaseType');
  String get actions => _get('actions');
  String get id => _get('id');
  String get materialNameRequired => _get('materialNameRequired');
  String get dischargeLocationRequired => _get('dischargeLocationRequired');
  String get materialTypeRequired => _get('materialTypeRequired');
  String get unitRequired => _get('unitRequired');
  String get thicknessRequired => _get('thicknessRequired');
  String get purchaseTypeRequired => _get('purchaseTypeRequired');
  String get netWeightRequired => _get('netWeightRequired');
  String get grossWeightRequired => _get('grossWeightRequired');
  String get currencyPrice => _get('currencyPrice');
  String get productPrice => _get('productPrice');
  String get sellerAmount => _get('sellerAmount');
  String get sellerPaymentMethod => _get('sellerPaymentMethod');
  String get sellerInitialPayment => _get('sellerInitialPayment');
  String get sellerLoanNote => _get('sellerLoanNote');
  String get selectSupplier => _get('selectSupplier');
  String get selectPurchaseType => _get('selectPurchaseType');
  String get direct => _get('direct');
  String get indirect => _get('indirect');
  String get fillAllRequiredFields => _get('fillAllRequiredFields');
  String get sellerPaymentExceedsBase => _get('sellerPaymentExceedsBase');
  String get rawMaterialAddedSuccess => _get('rawMaterialAddedSuccess');
  String get errorAddingRawMaterial => _get('errorAddingRawMaterial');
  String get editInDevelopment => _get('editInDevelopment');
  String get deleteRawMaterial => _get('deleteRawMaterial');
  String get rawMaterialDeletedSuccess => _get('rawMaterialDeletedSuccess');
  String get errorDeletingRawMaterial => _get('errorDeletingRawMaterial');
  String get cutFromStock => _get('cutFromStock');
  String get totalStockForUnit => _get('totalStockForUnit');
  String get cutType => _get('cutType');
  String get discharged => _get('discharged');
  String get cut => _get('cut');
  String get cutAmount => _get('cutAmount');
  String get enterValidAmount => _get('enterValidAmount');
  String get insufficientStock => _get('insufficientStock');
  String get from => _get('from');
  String get totalStock => _get('totalStock');
  String get itemsCount => _get('itemsCount');
  String get unknown => _get('unknown');
  String get noUnit => _get('noUnit');
  String get finalTotalPrice => _get('finalTotalPrice');
  String get edit => _get('edit');
  String get dateRequired => _get('dateRequired');
  
  // ============ UNITS ============
  String get kgUnit => _get('kgUnit');
  String get tonUnit => _get('tonUnit');
  String get meterUnit => _get('meterUnit');
  String get pcsUnit => _get('pcsUnit');
  String get literUnit => _get('literUnit');
  
  // ============ SALES PAGE ============
  String get salesManagement => _get('salesManagement');
  String get salesManagementSubtitle => _get('salesManagementSubtitle');
  String get addNewSale => _get('addNewSale');
  String get totalInvoices => _get('totalInvoices');
  String get usdTotal => _get('usdTotal');
  String get searchByCustomerOrInvoice => _get('searchByCustomerOrInvoice');
  String get all => _get('all');
  String get sale => _get('sale');
  String get proformaInvoice => _get('proformaInvoice');
  String get noInvoicesFound => _get('noInvoicesFound');
  String get bulkActions => _get('bulkActions');
  String get saveSale => _get('saveSale');
  String get saleSavedSuccess => _get('saleSavedSuccess');
  String get errorAddingSale => _get('errorAddingSale');
  String get deleteInvoice => _get('deleteInvoice');
  String get invoiceDeletedSuccess => _get('invoiceDeletedSuccess');
  String get errorDeletingInvoice => _get('errorDeletingInvoice');
  String get selectCustomerCompany => _get('selectCustomerCompany');
  String get viewCustomerHistory => _get('viewCustomerHistory');
  String get customerTransactionHistory => _get('customerTransactionHistory');
  String get noCustomerSelected => _get('noCustomerSelected');
  String get invoicesCount => _get('invoicesCount');
  String get noHistoryForCustomer => _get('noHistoryForCustomer');
  String get customerAndProductRequired => _get('customerAndProductRequired');
  String get errorLoadingSales => _get('errorLoadingSales');
  String get selectProductFromProduction => _get('selectProductFromProduction');
  String get selectProduct => _get('selectProduct');
  String get productDetails => _get('productDetails');
  String get financialInfo => _get('financialInfo');
  String get exchangeRateFromSystem => _get('exchangeRateFromSystem');
  String get initialPaymentNote => _get('initialPaymentNote');
  String get integratedManagementSystem => _get('integratedManagementSystem');
  String get statusReturned => _get('statusReturned');
  String get returnReason => _get('returnReason');
  String get returnDate => _get('returnDate');
  String get dischargeLocation => _get('dischargeLocation');
  String get signature => _get('signature');
  String get printDate => _get('printDate');
  String get pdf => _get('pdf');
  String get footerText => _get('footerText');
  String get errorSavingLoan => _get('errorSavingLoan');

  // ============ RETURNED SALES PAGE ============
// ============ RETURNED SALES PAGE ============
// Note: returnedSales is already defined in DASHBOARD section
// Use different names for other keys
String get returnedSalesSubtitle => _get('returnedSalesSubtitle');
String get addReturnedSale => _get('addReturnedSale');
String get selectSaleInvoice => _get('selectSaleInvoice');
String get returnInvoiceReceipt => _get('returnInvoiceReceipt');
String get returnedSaleSavedSuccess => _get('returnedSaleSavedSuccess');
String get errorSavingReturnedSale => _get('errorSavingReturnedSale');
String get errorLoadingReturnedSales => _get('errorLoadingReturnedSales');
String get saveReturnedSale => _get('saveReturnedSale');
String get noReturnedSales => _get('noReturnedSales');
String get returnReceipt => _get('returnReceipt');
String get searchReturnedSales => _get('searchReturnedSales');
String get rowsPerPage => _get('rowsPerPage');
String get returnDatePersian => _get('returnDatePersian');




// ============ SERVICES PAGE ============
// Use unique names to avoid conflicts
String get servicesManagement => _get('servicesManagement');
String get servicesManagementSubtitle => _get('servicesManagementSubtitle');
String get addNewService => _get('addNewService');
String get totalRevenue => _get('totalRevenue');
String get totalServicesCount => _get('totalServicesCount'); // Changed
String get usdTotalServices => _get('usdTotalServices'); // Changed
String get searchServices => _get('searchServices');
String get allFilter => _get('allFilter'); // Changed
String get servicesFilter => _get('servicesFilter'); // Changed
String get noServicesFound => _get('noServicesFound');
String get idLabel => _get('idLabel');
String get basePriceLabelService => _get('basePriceLabelService'); // Changed
String get basePriceRate => _get('basePriceRate');
String get serviceTypeLabel => _get('serviceTypeLabel'); // Changed
String get addServiceButton => _get('addServiceButton'); // Changed
String get editServiceLabel => _get('editServiceLabel'); // Changed
String get saveService => _get('saveService');
String get saveChanges => _get('saveChanges');
String get serviceAddedSuccess => _get('serviceAddedSuccess');
String get serviceUpdatedSuccess => _get('serviceUpdatedSuccess');
String get serviceDeletedSuccess => _get('serviceDeletedSuccess');
String get errorLoadingServices => _get('errorLoadingServices');
String get errorSavingService => _get('errorSavingService');
String get errorDeletingService => _get('errorDeletingService');
String get errorPrintingInvoice => _get('errorPrintingInvoice');
String get serviceInvoice => _get('serviceInvoice');
String get descriptionLabel => _get('descriptionLabel'); // Changed
String get amountLabel => _get('amountLabel'); // Changed
String get basePriceLabelService2 => _get('basePriceLabelService2'); // Changed
String get deleteServiceLabel => _get('deleteServiceLabel'); // Changed
String get editServiceLabel2 => _get('editServiceLabel2'); // Changed
String get serviceTypeLabel2 => _get('serviceTypeLabel2'); // Changed


// ============ DAILY EXPENSES PAGE ============
String get dailyExpensesManagement => _get('dailyExpensesManagement');
String get dailyExpensesTitle => _get('dailyExpensesTitle');  // Changed
String get addNewExpense => _get('addNewExpense');
String get totalExpensesCount => _get('totalExpensesCount');  // Changed
String get totalRecords => _get('totalRecords');
String get todayExpenses => _get('todayExpenses');
String get recordedToday => _get('recordedToday');
String get searchExpenses => _get('searchExpenses');
String get noExpensesFound => _get('noExpensesFound');
String get pleaseEnterDate => _get('pleaseEnterDate');
String get pleaseEnterPrice => _get('pleaseEnterPrice');
String get expenseAddedSuccess => _get('expenseAddedSuccess');
String get expenseUpdatedSuccess => _get('expenseUpdatedSuccess');
String get expenseDeletedSuccess => _get('expenseDeletedSuccess');
String get errorLoadingExpenses => _get('errorLoadingExpenses');
String get errorAddingExpense => _get('errorAddingExpense');
String get errorUpdatingExpense => _get('errorUpdatingExpense');
String get errorDeletingExpense => _get('errorDeletingExpense');
String get preparingPrint => _get('preparingPrint');
String get todayInvoice => _get('todayInvoice');
String get todayExpensesList => _get('todayExpensesList');
String get expenseInvoice => _get('expenseInvoice');
String get invoicePreview => _get('invoicePreview');
String get invoicePreviewMessage => _get('invoicePreviewMessage');
String get savePdf => _get('savePdf');
String get noExpensesToday => _get('noExpensesToday');
String get afghani => _get('afghani');
String get usd => _get('usd');
String get englishDate => _get('englishDate');
String get categoryHint => _get('categoryHint');
String get descriptionHint => _get('descriptionHint');
String get totalAmountLabel => _get('totalAmountLabel');


// ============ WASTES PAGE ============
// Use unique names to avoid conflicts
String get wastesManagement => _get('wastesManagement');
String get wastesManagementSubtitle => _get('wastesManagementSubtitle');
String get addWasteRecord => _get('addWasteRecord');  // Changed
String get editWasteRecord => _get('editWasteRecord');  // Changed
String get deleteWasteRecord => _get('deleteWasteRecord');  // Changed
String get totalWastesCount => _get('totalWastesCount');  // Changed
String get totalWasteValue => _get('totalWasteValue');  // Changed
String get totalAfnEquivalentWaste => _get('totalAfnEquivalentWaste');  // Changed
String get searchWastes => _get('searchWastes');
String get noWastesFound => _get('noWastesFound');
String get wasteAddedSuccess => _get('wasteAddedSuccess');
String get wasteUpdatedSuccess => _get('wasteUpdatedSuccess');
String get wasteDeletedSuccess => _get('wasteDeletedSuccess');
String get errorLoadingWastes => _get('errorLoadingWastes');
String get errorSavingWaste => _get('errorSavingWaste');
String get errorDeletingWaste => _get('errorDeletingWaste');
String get errorPrintingWasteInvoice => _get('errorPrintingWasteInvoice');  // Changed
String get wasteInvoiceTitle => _get('wasteInvoiceTitle');
String get partyDetailsLabel => _get('partyDetailsLabel');  // Changed
String get wasteTypeLabel => _get('wasteTypeLabel');  // Changed
String get weightKgLabel => _get('weightKgLabel');  // Changed
String get quantityAmountLabel => _get('quantityAmountLabel');  // Changed
String get wasteValueLabel => _get('wasteValueLabel');  // Changed
String get afnEquivalentLabel => _get('afnEquivalentLabel');  // Changed
String get usdEquivalentLabel => _get('usdEquivalentLabel');  // Changed

String get wastesFilter => _get('wastesFilter');  // Changed
String get wasteInvoice => _get('wasteInvoice');


// ============ PRODUCTION PAGE ============
String get productionManagementTitle => _get('productionManagementTitle');
String get productionManagementSubtitle => _get('productionManagementSubtitle');
String get addProductionRecord => _get('addProductionRecord');
String get editProductionRecord => _get('editProductionRecord');
String get deleteProductionRecord => _get('deleteProductionRecord');
String get totalProductionsCount => _get('totalProductionsCount');
String get completedStatus => _get('completedStatus');
String get inProgressStatus => _get('inProgressStatus');
String get pendingStatus => _get('pendingStatus');
String get productionSummaryByUnit => _get('productionSummaryByUnit');
String get totalLabel => _get('totalLabel');
String get itemsCountLabel => _get('itemsCountLabel');
String get noProductsFound => _get('noProductsFound');
String get productNameLabel => _get('productNameLabel');
String get productionTypeLabel => _get('productionTypeLabel');
String get productionDateLabel => _get('productionDateLabel');
String get saleStatusLabel => _get('saleStatusLabel');
String get soldLabel => _get('soldLabel');
String get availableLabel => _get('availableLabel');
String get productNameRequiredProd => _get('productNameRequiredProd');
String get productionTypeRequiredProd => _get('productionTypeRequiredProd');
String get quantityRequiredProd => _get('quantityRequiredProd');
String get unitRequiredProd => _get('unitRequiredProd');
String get dateRequiredProd => _get('dateRequiredProd');
String get fillRequiredFieldsProd => _get('fillRequiredFieldsProd');
String get productAddedSuccess => _get('productAddedSuccess');
String get productUpdatedSuccess => _get('productUpdatedSuccess');
String get productDeletedSuccess => _get('productDeletedSuccess');
String get errorLoadingProduction => _get('errorLoadingProduction');
String get errorSavingProduct => _get('errorSavingProduct');
String get errorDeletingProduct => _get('errorDeletingProduct');
String get idLabelProd => _get('idLabelProd');
String get quantityLabelProd => _get('quantityLabelProd');
String get weightLabelProd => _get('weightLabelProd');
String get unitLabelProd => _get('unitLabelProd');
String get batchLabelProd => _get('batchLabelProd');
String get statusLabelProd => _get('statusLabelProd');
String get actionsLabelProd => _get('actionsLabelProd');
String get productionSummary => _get('productionSummary');
String get thicknessLabelProd => _get('thicknessLabelProd');
String get lengthLabelProd => _get('lengthLabelProd');
String get loadingLabelProd => _get('loadingLabelProd');





// ============ CUSTOMERS & COMPANIES PAGE ============
String get customersCompaniesPage => _get('customersCompaniesPage');
String get companiesListPage => _get('companiesListPage');
String get manage => _get('manage');
String get totalCount => _get('totalCount');
String get addNew => _get('addNew');
String get addCustomer => _get('addCustomer');
String get addCompany => _get('addCompany');
String get editCustomer => _get('editCustomer');
String get editCompany => _get('editCompany');
String get deleteCustomer => _get('deleteCustomer');
String get deleteCompany => _get('deleteCompany');
String get fullNameLabel => _get('fullNameLabel');
String get fullNameHint => _get('fullNameHint');
String get nickname => _get('nickname');
String get nicknameHint => _get('nicknameHint');
String get phoneNumberLabel => _get('phoneNumberLabel');
String get phoneHint => _get('phoneHint');
String get emailLabel => _get('emailLabel');
String get emailHint => _get('emailHint');
String get addressLabel => _get('addressLabel');
String get addressHint => _get('addressHint');
String get companyAddressHint => _get('companyAddressHint');
String get type => _get('type');
String get typeHint => _get('typeHint');
String get individual => _get('individual');
String get corporate => _get('corporate');
String get companyNameLabelPage => _get('companyNameLabelPage');
String get companyNameHint => _get('companyNameHint');
String get customerAddedSuccess => _get('customerAddedSuccess');
String get customerUpdatedSuccess => _get('customerUpdatedSuccess');
String get customerDeletedSuccess => _get('customerDeletedSuccess');
String get companyAddedSuccess => _get('companyAddedSuccess');
String get companyUpdatedSuccess => _get('companyUpdatedSuccess');
String get companyDeletedSuccess => _get('companyDeletedSuccess');
String get errorLoadingDataCC => _get('errorLoadingDataCC');
String get errorAddingCustomer => _get('errorAddingCustomer');
String get errorUpdatingCustomer => _get('errorUpdatingCustomer');
String get errorDeletingCustomer => _get('errorDeletingCustomer');
String get errorAddingCompany => _get('errorAddingCompany');
String get errorUpdatingCompany => _get('errorUpdatingCompany');
String get errorDeletingCompany => _get('errorDeletingCompany');
String get pleaseEnterCustomerName => _get('pleaseEnterCustomerName');
String get pleaseEnterCompanyName => _get('pleaseEnterCompanyName');
String get customerTransactionHistoryPage => _get('customerTransactionHistoryPage');
String get companyTransactionHistoryPage => _get('companyTransactionHistoryPage');
String get noCustomerTransactions => _get('noCustomerTransactions');
String get noCompanyTransactions => _get('noCompanyTransactions');
String get noCustomersFound => _get('noCustomersFound');
String get noCompaniesFound => _get('noCompaniesFound');
String get clickAddButton => _get('clickAddButton');
String get searchByCustomerName => _get('searchByCustomerName');
String get transactionsLabel => _get('transactionsLabel');
String get history => _get('history');
String get noTransaction => _get('noTransaction');
String get rial => _get('rial');
String get totalAmountPage => _get('totalAmountPage');
String get completedStatusPage => _get('completedStatusPage');
String get pendingStatusPage => _get('pendingStatusPage');
String get saveChangesPage => _get('saveChangesPage');
// customer and company are already defined in SIDEBAR section - DO NOT REDEFINE










 // Changed
  
  String _get(String key) {
    if (locale.languageCode == 'en') {
      return enTranslations[key] ?? key;
    }
    return faTranslations[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  
  @override
  bool isSupported(Locale locale) => ['en', 'fa'].contains(locale.languageCode);
  
  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }
  
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
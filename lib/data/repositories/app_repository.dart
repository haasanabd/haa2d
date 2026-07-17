import 'package:sqflite/sqflite.dart';
import '../datasources/database_helper.dart';
import '../models/app_models.dart';

class AppRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- Customers Operations ---
  Future<int> addCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.insert('Customers', customer.toMap());
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await _dbHelper.database;
    final maps = await db.query('Customers', orderBy: 'name ASC');
    return maps.map((e) => Customer.fromMap(e)).toList();
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.update('Customers', customer.toMap(), where: 'id = ?', whereArgs: [customer.id]);
  }

  // --- Suppliers Operations ---
  Future<int> addSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.insert('Suppliers', supplier.toMap());
  }

  Future<List<Supplier>> getAllSuppliers() async {
    final db = await _dbHelper.database;
    final maps = await db.query('Suppliers', orderBy: 'name ASC');
    return maps.map((e) => Supplier.fromMap(e)).toList();
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.update('Suppliers', supplier.toMap(), where: 'id = ?', whereArgs: [supplier.id]);
  }

  // --- Raw Materials Operations ---
  Future<int> addRawMaterial(RawMaterial material) async {
    final db = await _dbHelper.database;
    return await db.insert('RawMaterials', material.toMap());
  }

  Future<List<RawMaterial>> getAllRawMaterials() async {
    final db = await _dbHelper.database;
    final maps = await db.query('RawMaterials', orderBy: 'name ASC');
    return maps.map((e) => RawMaterial.fromMap(e)).toList();
  }

  Future<int> updateRawMaterial(RawMaterial material) async {
    final db = await _dbHelper.database;
    return await db.update('RawMaterials', material.toMap(), where: 'id = ?', whereArgs: [material.id]);
  }

  // --- Products Operations ---
  Future<int> addProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.insert('Products', product.toMap());
  }

  Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final maps = await db.query('Products', orderBy: 'name ASC');
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.update('Products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  // --- Search Operations ---
  Future<List<Customer>> searchCustomers(String query) async {
    final db = await _dbHelper.database;
    final maps = await db.query('Customers', where: 'name LIKE ? OR phone LIKE ?', whereArgs: ['%$query%', '%$query%']);
    return maps.map((e) => Customer.fromMap(e)).toList();
  }

  Future<List<Supplier>> searchSuppliers(String query) async {
    final db = await _dbHelper.database;
    final maps = await db.query('Suppliers', where: 'name LIKE ? OR phone LIKE ?', whereArgs: ['%$query%', '%$query%']);
    return maps.map((e) => Supplier.fromMap(e)).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await _dbHelper.database;
    final maps = await db.query('Products', where: 'name LIKE ?', whereArgs: ['%$query%']);
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<RawMaterial>> searchRawMaterials(String query) async {
    final db = await _dbHelper.database;
    final maps = await db.query('RawMaterials', where: 'name LIKE ? OR color LIKE ?', whereArgs: ['%$query%', '%$query%']);
    return maps.map((e) => RawMaterial.fromMap(e)).toList();
  }

  // --- Sales Invoice (Complex Operation) ---
  Future<void> createSalesInvoice(SalesInvoice invoice, List<SaleInvoiceItem> items) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Get current cashbox balance before transaction
      final currentCashBoxBalance = await _getCashBoxBalance(txn);

      // 1. Insert Invoice
      final invoiceId = await txn.insert('SalesInvoices', invoice.toMap());

      // 2. Insert Items & Update Stock
      for (var item in items) {
        final itemMap = item.toMap();
        itemMap['invoice_id'] = invoiceId;
        await txn.insert('SaleInvoiceItems', itemMap);

        // Update Product Quantity
        await txn.execute(
          'UPDATE Products SET quantity = quantity - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }

      // 3. Update Customer Balance if Credit
      if (invoice.saleType == 'آجل' && invoice.customerId != null) {
        await txn.execute(
          'UPDATE Customers SET balance = balance + ? WHERE id = ?',
          [invoice.totalAmount, invoice.customerId],
        );
      }

      // 4. Update CashBox if Cash
      if (invoice.saleType == 'نقدي') {
        await txn.insert('CashBox', {
          'date': invoice.date,
          'time': invoice.time,
          'type': 'وارد',
          'amount': invoice.totalAmount,
          'description': 'فاتورة مبيعات رقم $invoiceId',
          'entity_type': 'زبون',
          'entity_id': invoice.customerId,
          'opening_balance': currentCashBoxBalance,
        });
      }
    });
  }

  // --- Purchase Invoice (Complex Operation) ---
  Future<void> createPurchaseInvoice(PurchaseInvoice invoice, List<PurchaseInvoiceItem> items) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Get current cashbox balance before transaction
      final currentCashBoxBalance = await _getCashBoxBalance(txn);

      // 1. Insert Invoice
      final invoiceId = await txn.insert('PurchaseInvoices', invoice.toMap());

      // 2. Insert Items & Update Stock
      for (var item in items) {
        final itemMap = item.toMap();
        itemMap['invoice_id'] = invoiceId;
        await txn.insert('PurchaseInvoiceItems', itemMap);

        // Update Raw Material Weight
        await txn.execute(
          'UPDATE RawMaterials SET weight_gram = weight_gram + ? WHERE id = ?',
          [item.quantityGram, item.rawMaterialId],
        );
      }

      // 3. Update Supplier Balance if Credit
      if (invoice.purchaseType == 'آجل' && invoice.supplierId != null) {
        await txn.execute(
          'UPDATE Suppliers SET balance = balance + ? WHERE id = ?',
          [invoice.totalAmount, invoice.supplierId],
        );
      }

      // 4. Update CashBox if Cash
      if (invoice.purchaseType == 'نقدي') {
        await txn.insert('CashBox', {
          'date': invoice.date,
          'time': invoice.time,
          'type': 'صادر',
          'amount': invoice.totalAmount,
          'description': 'فاتورة مشتريات رقم $invoiceId',
          'entity_type': 'مورد',
          'entity_id': invoice.supplierId,
          'opening_balance': currentCashBoxBalance,
        });
      }
    });
  }

  // --- Production (Complex Operation) ---
  Future<void> createProduction(Production production) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Insert Production Record
      await txn.insert('Production', production.toMap());

      // 2. Deduct Raw Material
      await txn.execute(
        'UPDATE RawMaterials SET weight_gram = weight_gram - ? WHERE id = ?',
        [production.consumedWeightGram, production.rawMaterialId],
      );

      // 3. Add Finished Product (Assume 1 unit per production for simplicity or based on weight)
      // If we produce 1 unit of product per record:
      await txn.execute(
        'UPDATE Products SET quantity = quantity + 1 WHERE id = ?',
        [production.productId],
      );
    });
  }

  // --- Vouchers ---
  Future<void> createReceiptVoucher(ReceiptVoucher voucher) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Get current cashbox balance before transaction
      final currentCashBoxBalance = await _getCashBoxBalance(txn);

      await txn.insert('ReceiptVouchers', voucher.toMap());
      // Update Customer Balance (Decrease debt)
      await txn.execute(
        'UPDATE Customers SET balance = balance - ? WHERE id = ?',
        [voucher.amount, voucher.customerId],
      );
      // Update CashBox
      await txn.insert('CashBox', {
        'date': voucher.date,
        'time': voucher.time,
        'type': 'وارد',
        'amount': voucher.amount,
        'description': 'سند قبض: ${voucher.description ?? ""}',
        'entity_type': 'زبون',
        'entity_id': voucher.customerId,
        'opening_balance': currentCashBoxBalance,
      });
    });
  }

  Future<void> createPaymentVoucher(PaymentVoucher voucher) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Get current cashbox balance before transaction
      final currentCashBoxBalance = await _getCashBoxBalance(txn);

      await txn.insert('PaymentVouchers', voucher.toMap());
      // Update Supplier Balance (Decrease debt)
      await txn.execute(
        'UPDATE Suppliers SET balance = balance - ? WHERE id = ?',
        [voucher.amount, voucher.supplierId],
      );
      // Update CashBox
      await txn.insert('CashBox', {
        'date': voucher.date,
        'time': voucher.time,
        'type': 'صادر',
        'amount': voucher.amount,
        'description': 'سند صرف: ${voucher.description ?? ""}',
        'entity_type': 'مورد',
        'entity_id': voucher.supplierId,
        'opening_balance': currentCashBoxBalance,
      });
    });
  }

  // --- Expenses ---
  Future<void> createExpense(Expense expense) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Get current cashbox balance before transaction
      final currentCashBoxBalance = await _getCashBoxBalance(txn);

      await txn.insert('Expenses', expense.toMap());
      // Update CashBox
      await txn.insert('CashBox', {
        'date': expense.date,
        'time': expense.time,
        'type': 'مصروف',
        'amount': expense.amount,
        'description': 'مصروف: ${expense.category} - ${expense.notes ?? ""}',
        'opening_balance': currentCashBoxBalance,
      });
    });
  }

  // --- Dashboard Data ---
  Future<Map<String, dynamic>> getDashboardData() async {
    final db = await _dbHelper.database;
    
    final cashResult = await db.rawQuery("SELECT SUM(CASE WHEN type='وارد' THEN amount ELSE -amount END) as total FROM CashBox");
    final productsCount = await db.rawQuery("SELECT COUNT(*) as count FROM Products");
    final materialsCount = await db.rawQuery("SELECT COUNT(*) as count FROM RawMaterials");
    final customersCount = await db.rawQuery("SELECT COUNT(*) as count FROM Customers");
    final suppliersCount = await db.rawQuery("SELECT COUNT(*) as count FROM Suppliers");
    final salesTotal = await db.rawQuery("SELECT SUM(total_amount) as total FROM SalesInvoices");
    final purchasesTotal = await db.rawQuery("SELECT SUM(total_amount) as total FROM PurchaseInvoices");

    return {
      'cash_balance': cashResult.first['total'] ?? 0.0,
      'products_count': productsCount.first['count'] ?? 0,
      'materials_count': materialsCount.first['count'] ?? 0,
      'customers_count': customersCount.first['count'] ?? 0,
      'suppliers_count': suppliersCount.first['count'] ?? 0,
      'sales_total': salesTotal.first['total'] ?? 0.0,
      'purchases_total': purchasesTotal.first['total'] ?? 0.0,
      'profit_total': (salesTotal.first['total'] as double? ?? 0.0) - (purchasesTotal.first['total'] as double? ?? 0.0),
    };
  }

  // --- Reports ---
  Future<List<Map<String, dynamic>>> getSalesInvoicesWithCustomer() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT SalesInvoices.*, Customers.name as customer_name 
      FROM SalesInvoices 
      LEFT JOIN Customers ON SalesInvoices.customer_id = Customers.id
      ORDER BY date DESC, time DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getCashBoxRecords() async {
    final db = await _dbHelper.database;
    return await db.query('CashBox', orderBy: 'date DESC, time DESC');
  }

  // Helper to get current cashbox balance
  Future<double> _getCashBoxBalance(Transaction txn) async {
    final cashResult = await txn.rawQuery("SELECT SUM(CASE WHEN type='وارد' THEN amount ELSE -amount END) as total FROM CashBox");
    return cashResult.first['total'] as double? ?? 0.0;
  }

  // --- Daily CashBox Summary Operations ---
  Future<int> addDailyCashBoxSummary(DailyCashBoxSummary summary) async {
    final db = await _dbHelper.database;
    return await db.insert('DailyCashBoxSummary', summary.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DailyCashBoxSummary?> getDailyCashBoxSummary(String date) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'DailyCashBoxSummary',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isNotEmpty) {
      return DailyCashBoxSummary.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<DailyCashBoxSummary>> getAllDailyCashBoxSummaries() async {
    final db = await _dbHelper.database;
    final maps = await db.query('DailyCashBoxSummary', orderBy: 'date DESC');
    return maps.map((e) => DailyCashBoxSummary.fromMap(e)).toList();
  }

  // --- Settings Operations ---
  Future<void> saveSetting(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert(
      'Settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    } else {
      return null;
    }
  }
}

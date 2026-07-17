import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/app_repository.dart';

class CashBoxPage extends StatefulWidget {
  const CashBoxPage({super.key});

  @override
  State<CashBoxPage> createState() => _CashBoxPageState();
}

class _CashBoxPageState extends State<CashBoxPage> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final repo = context.read<AppRepository>();
    final records = await repo.getCashBoxRecords();
    if (mounted) {
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الصادر والوارد (القاصة)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final rec = _records[index];
                      final isIncoming = rec['type'] == 'وارد';
                      return ListTile(
                        leading: Icon(
                          isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isIncoming ? Colors.green : Colors.red,
                        ),
                        title: Text(rec['description'] ?? 'بدون وصف'),
                        subtitle: Text('${rec['date']} ${rec['time']}'),
                        trailing: Text(
                          '${rec['amount']}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isIncoming ? Colors.green : Colors.red),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: _showReceiptVoucherDialog, child: const Text('سند قبض')),
            ElevatedButton(onPressed: _showPaymentVoucherDialog, child: const Text('سند صرف')),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    double totalIn = 0;
    double totalOut = 0;
    for (var r in _records) {
      if (r['type'] == 'وارد') {
        totalIn += r['amount'];
      } else {
        totalOut += r['amount'];
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueAccent.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('الوارد', totalIn, Colors.green),
          _buildSummaryItem('الصادر', totalOut, Colors.red),
          _buildSummaryItem('الرصيد', totalIn - totalOut, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _showReceiptVoucherDialog() async {
    final repo = context.read<AppRepository>();
    final customers = await repo.getAllCustomers();
    if (!mounted) return;

    Customer? selectedCustomer;
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء سند قبض'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Customer>(
              decoration: const InputDecoration(labelText: 'الزبون'),
              items: customers.map((c) => DropdownMenuItem(value: c, child: Text('${c.name} (الرصيد: ${c.balance})'))).toList(),
              onChanged: (v) => selectedCustomer = v,
            ),
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'الوصف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (selectedCustomer == null) return;
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0) return;

              final now = DateTime.now();
              final voucher = ReceiptVoucher(
                date: DateFormat('yyyy-MM-dd').format(now),
                time: DateFormat('HH:mm:ss').format(now),
                customerId: selectedCustomer!.id!,
                amount: amount,
                description: descController.text,
              );

              await repo.createReceiptVoucher(voucher);
              Navigator.pop(context);
              _loadRecords();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showPaymentVoucherDialog() async {
    final repo = context.read<AppRepository>();
    final suppliers = await repo.getAllSuppliers();
    if (!mounted) return;

    Supplier? selectedSupplier;
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء سند صرف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Supplier>(
              decoration: const InputDecoration(labelText: 'المورد'),
              items: suppliers.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (الرصيد: ${s.balance})'))).toList(),
              onChanged: (v) => selectedSupplier = v,
            ),
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'الوصف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (selectedSupplier == null) return;
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0) return;

              final now = DateTime.now();
              final voucher = PaymentVoucher(
                date: DateFormat('yyyy-MM-dd').format(now),
                time: DateFormat('HH:mm:ss').format(now),
                supplierId: selectedSupplier!.id!,
                amount: amount,
                description: descController.text,
              );

              await repo.createPaymentVoucher(voucher);
              Navigator.pop(context);
              _loadRecords();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

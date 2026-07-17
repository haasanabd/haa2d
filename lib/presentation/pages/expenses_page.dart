import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/datasources/database_helper.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final db = await DatabaseHelper.instance.database;
    final expenses = await db.query('Expenses', orderBy: 'date DESC, time DESC');
    if (mounted) {
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المصاريف اليومية')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? const Center(child: Text('لا توجد مصاريف مسجلة'))
              : ListView.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    final exp = _expenses[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.money_off, color: Colors.red)),
                        title: Text(exp['category']),
                        subtitle: Text('${exp['date']} ${exp['time']}\n${exp['notes'] ?? ""}'),
                        trailing: Text('${exp['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        label: const Text('إضافة مصروف'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddExpenseDialog() {
    final repo = context.read<AppRepository>();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مصروف جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'الفئة (مثلاً: إيجار، كهرباء)')),
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
            TextField(controller: notesController, decoration: const InputDecoration(labelText: 'ملاحظات')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              final category = categoryController.text;
              if (amount <= 0 || category.isEmpty) return;

              final now = DateTime.now();
              final expense = Expense(
                date: DateFormat('yyyy-MM-dd').format(now),
                time: DateFormat('HH:mm:ss').format(now),
                category: category,
                amount: amount,
                notes: notesController.text,
              );

              await repo.createExpense(expense);
              Navigator.pop(context);
              _loadExpenses();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

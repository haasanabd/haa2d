import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/datasources/database_helper.dart';
import 'package:intl/intl.dart';
import '../../data/datasources/pdf_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير والإحصائيات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDateRangePicker(),
          const SizedBox(height: 20),
          _buildReportSection('التقارير المالية', [
            _buildReportItem(context, 'تقرير المبيعات التفصيلي', Icons.sell, Colors.blue, _showSalesReport),
            _buildReportItem(context, 'تقرير المشتريات التفصيلي', Icons.shopping_cart, Colors.orange, _showPurchasesReport),
            _buildReportItem(context, 'تقرير المصاريف', Icons.money_off, Colors.red, _showExpensesReport),
            _buildReportItem(context, 'ملخص الأرباح والخسائر', Icons.trending_up, Colors.green, _showProfitLossReport),
          ]),
          const SizedBox(height: 20),
          _buildReportSection('تقارير المخزن والإنتاج', [
            _buildReportItem(context, 'جرد المخزن الحالي', Icons.inventory, Colors.teal, _showInventoryStatusReport),
            _buildReportItem(context, 'تقرير الإنتاج والهالك', Icons.precision_manufacturing, Colors.indigo, _showProductionReport),
            _buildReportItem(context, 'المواد الخام الأكثر استهلاكاً', Icons.category, Colors.brown, _showTopMaterialsReport),
          ]),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الفترة الزمنية للتقارير', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(context, true),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('من: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(context, false),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('إلى: ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked; else _endDate = picked;
      });
    }
  }

  Widget _buildReportSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 10),
        ...items,
      ],
    );
  }

  Widget _buildReportItem(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showSalesReport() async {
    final db = await DatabaseHelper.instance.database;
    final start = DateFormat('yyyy-MM-dd').format(_startDate);
    final end = DateFormat('yyyy-MM-dd').format(_endDate);
    
    final results = await db.rawQuery('''
      SELECT date, SUM(total_amount) as total, COUNT(*) as count 
      FROM SalesInvoices 
      WHERE date BETWEEN ? AND ? 
      GROUP BY date 
      ORDER BY date DESC
    ''', [start, end]);

    _showReportDialog('تقرير المبيعات', results, ['التاريخ', 'عدد الفواتير', 'الإجمالي']);
  }

  void _showPurchasesReport() async {
    final db = await DatabaseHelper.instance.database;
    final start = DateFormat('yyyy-MM-dd').format(_startDate);
    final end = DateFormat('yyyy-MM-dd').format(_endDate);
    
    final results = await db.rawQuery('''
      SELECT date, SUM(total_amount) as total, COUNT(*) as count 
      FROM PurchaseInvoices 
      WHERE date BETWEEN ? AND ? 
      GROUP BY date 
      ORDER BY date DESC
    ''', [start, end]);

    _showReportDialog('تقرير المشتريات', results, ['التاريخ', 'عدد الفواتير', 'الإجمالي']);
  }

  void _showExpensesReport() async {
    final db = await DatabaseHelper.instance.database;
    final start = DateFormat('yyyy-MM-dd').format(_startDate);
    final end = DateFormat('yyyy-MM-dd').format(_endDate);
    
    final results = await db.rawQuery('''
      SELECT category, SUM(amount) as total 
      FROM Expenses 
      WHERE date BETWEEN ? AND ? 
      GROUP BY category
    ''', [start, end]);

    _showReportDialog('تقرير المصاريف', results, ['الفئة', 'الإجمالي']);
  }

  void _showProfitLossReport() async {
    final db = await DatabaseHelper.instance.database;
    final start = DateFormat('yyyy-MM-dd').format(_startDate);
    final end = DateFormat('yyyy-MM-dd').format(_endDate);
    
    final sales = await db.rawQuery('SELECT SUM(total_amount) as total FROM SalesInvoices WHERE date BETWEEN ? AND ?', [start, end]);
    final purchases = await db.rawQuery('SELECT SUM(total_amount) as total FROM PurchaseInvoices WHERE date BETWEEN ? AND ?', [start, end]);
    final expenses = await db.rawQuery('SELECT SUM(amount) as total FROM Expenses WHERE date BETWEEN ? AND ?', [start, end]);

    final sTotal = (sales.first['total'] as num?) ?? 0.0;
    final pTotal = (purchases.first['total'] as num?) ?? 0.0;
    final eTotal = (expenses.first['total'] as num?) ?? 0.0;
    final profit = sTotal - pTotal - eTotal;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ملخص الأرباح والخسائر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('إجمالي المبيعات', sTotal, Colors.blue),
            _buildSummaryRow('إجمالي المشتريات', pTotal, Colors.orange),
            _buildSummaryRow('إجمالي المصاريف', eTotal, Colors.red),
            const Divider(),
            _buildSummaryRow('صافي الربح', profit, profit >= 0 ? Colors.green : Colors.red, isBold: true),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  Widget _buildSummaryRow(String label, num value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('$value', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: isBold ? 18 : 14)),
        ],
      ),
    );
  }

  void _showInventoryStatusReport() async {
    final db = await DatabaseHelper.instance.database;
    final materials = await db.query('RawMaterials');
    final products = await db.query('Products');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('جرد المخزن الحالي'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('المواد الخام', style: TextStyle(fontWeight: FontWeight.bold)),
                ...materials.map((m) => ListTile(title: Text(m['name'].toString()), trailing: Text('${m['weight_gram']} جم'))),
                const Divider(),
                const Text('المنتجات الجاهزة', style: TextStyle(fontWeight: FontWeight.bold)),
                ...products.map((p) => ListTile(title: Text(p['name'].toString()), trailing: Text('${p['quantity']} قطعة'))),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  void _showProductionReport() async {
    final db = await DatabaseHelper.instance.database;
    final start = DateFormat('yyyy-MM-dd').format(_startDate);
    final end = DateFormat('yyyy-MM-dd').format(_endDate);
    
    final results = await db.rawQuery('''
      SELECT date, SUM(produced_weight_gram) as total_produced, AVG(waste_percentage) as avg_waste 
      FROM Production 
      WHERE date BETWEEN ? AND ? 
      GROUP BY date
    ''', [start, end]);

    _showReportDialog('تقرير الإنتاج', results, ['التاريخ', 'إجمالي الإنتاج (جم)', 'متوسط الهالك %']);
  }

  void _showTopMaterialsReport() async {
    final db = await DatabaseHelper.instance.database;
    final start = DateFormat('yyyy-MM-dd').format(_startDate);
    final end = DateFormat('yyyy-MM-dd').format(_endDate);
    
    final results = await db.rawQuery('''
      SELECT RawMaterials.name, SUM(Production.consumed_weight_gram) as total_consumed 
      FROM Production 
      JOIN RawMaterials ON Production.raw_material_id = RawMaterials.id 
      WHERE date BETWEEN ? AND ? 
      GROUP BY raw_material_id 
      ORDER BY total_consumed DESC
    ''', [start, end]);

    _showReportDialog('المواد الأكثر استهلاكاً', results, ['المادة الخام', 'إجمالي الاستهلاك (جم)']);
  }

  void _showReportDialog(String title, List<Map<String, dynamic>> data, List<String> columns) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: data.isEmpty
              ? const Center(heightFactor: 2, child: Text('لا توجد بيانات لهذه الفترة'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
                    rows: data.map((row) {
                      return DataRow(cells: row.values.map((v) => DataCell(Text(v.toString()))).toList());
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ElevatedButton.icon(
            onPressed: () async {
              final repo = context.read<AppRepository>();
              final shopName = await repo.getSetting('shop_name') ?? 'Haa 3D';
              final headers = columns;
              final dataList = data.map((row) => row.values.map((v) => v.toString()).toList()).toList();
              await PdfService.generateReport(
                title: title,
                headers: headers,
                data: dataList,
                shopName: shopName,
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('تصدير PDF'),
          ),
        ],
      ),
    );
  }
}

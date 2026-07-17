import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/datasources/database_helper.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final db = await DatabaseHelper.instance.database;
    final invoices = await db.rawQuery('''
      SELECT PurchaseInvoices.*, Suppliers.name as supplier_name 
      FROM PurchaseInvoices 
      LEFT JOIN Suppliers ON PurchaseInvoices.supplier_id = Suppliers.id
      ORDER BY date DESC, time DESC
    ''');
    if (mounted) {
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فواتير المشتريات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(child: Text('لا توجد فواتير مشتريات'))
              : ListView.builder(
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final inv = _invoices[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text('فاتورة #${inv['id']} - ${inv['supplier_name'] ?? "مورد عام"}'),
                        subtitle: Text('${inv['date']} ${inv['time']} | النوع: ${inv['purchase_type']}'),
                        trailing: Text('${inv['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateInvoiceDialog,
        label: const Text('فاتورة جديدة'),
        icon: const Icon(Icons.add_shopping_cart),
      ),
    );
  }

  void _showCreateInvoiceDialog() async {
    final repo = context.read<AppRepository>();
    final suppliers = await repo.getAllSuppliers();
    final materials = await repo.getAllRawMaterials();

    if (!mounted) return;

    Supplier? selectedSupplier;
    String purchaseType = 'نقدي';
    List<PurchaseInvoiceItem> cartItems = [];
    double total = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إنشاء فاتورة مشتريات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Supplier>(
                        decoration: const InputDecoration(labelText: 'اختر المورد'),
                        items: suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (v) => setModalState(() => selectedSupplier = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: purchaseType,
                        decoration: const InputDecoration(labelText: 'نوع الشراء'),
                        items: ['نقدي', 'آجل'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setModalState(() => purchaseType = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('المواد في الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final material = materials.firstWhere((m) => m.id == item.rawMaterialId);
                      return ListTile(
                        title: Text(material.name),
                        subtitle: Text('${item.quantityGram} جم x ${item.pricePerGram}'),
                        trailing: Text('${item.subtotal}'),
                        leading: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () {
                          setModalState(() {
                            total -= item.subtotal;
                            cartItems.removeAt(index);
                          });
                        }),
                      );
                    },
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddMaterialToCartDialog(materials, (item) {
                    setModalState(() {
                      cartItems.add(item);
                      total += item.subtotal;
                    });
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة مادة خام'),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الإجمالي: $total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: cartItems.isEmpty ? null : () async {
                        final now = DateTime.now();
                        final invoice = PurchaseInvoice(
                          date: DateFormat('yyyy-MM-dd').format(now),
                          time: DateFormat('HH:mm:ss').format(now),
                          supplierId: selectedSupplier?.id,
                          purchaseType: purchaseType,
                          totalAmount: total,
                        );
                        await repo.createPurchaseInvoice(invoice, cartItems);
                        Navigator.pop(context);
                        _loadInvoices();
                      },
                      child: const Text('حفظ الفاتورة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMaterialToCartDialog(List<RawMaterial> materials, Function(PurchaseInvoiceItem) onAdd) {
    RawMaterial? selectedMaterial;
    final qtyController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مادة للفاتورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<RawMaterial>(
              decoration: const InputDecoration(labelText: 'المادة الخام'),
              items: materials.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(),
              onChanged: (v) {
                selectedMaterial = v;
                if (v != null) {
                  priceController.text = (v.pricePerKg / 1000).toString();
                }
              },
            ),
            TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'الكمية (جرام)'), keyboardType: TextInputType.number),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'السعر للجرام الواحد'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (selectedMaterial == null) return;
              final qty = double.tryParse(qtyController.text) ?? 0.0;
              final price = double.tryParse(priceController.text) ?? 0.0;
              if (qty <= 0) return;
              onAdd(PurchaseInvoiceItem(
                invoiceId: 0,
                rawMaterialId: selectedMaterial!.id!,
                quantityGram: qty,
                pricePerGram: price,
                subtotal: qty * price,
              ));
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/app_repository.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final repo = context.read<AppRepository>();
    final invoices = await repo.getSalesInvoicesWithCustomer();
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
      appBar: AppBar(title: const Text('فواتير المبيعات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(child: Text('لا توجد فواتير مبيعات'))
              : ListView.builder(
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final inv = _invoices[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text('فاتورة #${inv['id']} - ${inv['customer_name'] ?? "زبون عام"}'),
                        subtitle: Text('${inv['date']} ${inv['time']} | النوع: ${inv['sale_type']}'),
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
    final customers = await repo.getAllCustomers();
    final products = await repo.getAllProducts();

    if (!mounted) return;

    Customer? selectedCustomer;
    String saleType = 'نقدي';
    List<SaleInvoiceItem> cartItems = [];
    double total = 0.0;
    double discount = 0.0;

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
                const Text('إنشاء فاتورة مبيعات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Customer>(
                        decoration: const InputDecoration(labelText: 'اختر الزبون'),
                        items: customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                        onChanged: (v) => setModalState(() => selectedCustomer = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: saleType,
                        decoration: const InputDecoration(labelText: 'نوع البيع'),
                        items: ['نقدي', 'آجل'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setModalState(() => saleType = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('المنتجات في الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final product = products.firstWhere((p) => p.id == item.productId);
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text('${item.quantity} x ${item.price}'),
                        trailing: Text('${item.subtotal}'),
                        iconColor: Colors.red,
                        leading: IconButton(icon: const Icon(Icons.remove_circle), onPressed: () {
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
                  onPressed: () => _showAddProductToCartDialog(products, (item) {
                    setModalState(() {
                      cartItems.add(item);
                      total += item.subtotal;
                    });
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة منتج'),
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
                        final invoice = SalesInvoice(
                          date: DateFormat('yyyy-MM-dd').format(now),
                          time: DateFormat('HH:mm:ss').format(now),
                          customerId: selectedCustomer?.id,
                          saleType: saleType,
                          discount: discount,
                          totalAmount: total,
                        );
                        await repo.createSalesInvoice(invoice, cartItems);
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

  void _showAddProductToCartDialog(List<Product> products, Function(SaleInvoiceItem) onAdd) {
    Product? selectedProduct;
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة منتج للفاتورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Product>(
              decoration: const InputDecoration(labelText: 'المنتج'),
              items: products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (متوفر: ${p.quantity})'))).toList(),
              onChanged: (v) {
                selectedProduct = v;
                priceController.text = v?.price.toString() ?? '';
              },
            ),
            TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'السعر'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (selectedProduct == null) return;
              final qty = int.tryParse(qtyController.text) ?? 0;
              final price = double.tryParse(priceController.text) ?? 0.0;
              if (qty <= 0 || qty > selectedProduct!.quantity) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الكمية غير متوفرة')));
                return;
              }
              onAdd(SaleInvoiceItem(
                invoiceId: 0, // Will be set in repository
                productId: selectedProduct!.id!,
                quantity: qty,
                price: price,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/providers.dart';
import '../providers/appointments_provider.dart';
import '../providers/order_items_provider.dart';
import '../../reports/presentation/financial_provider.dart';
import '../../products/providers/products_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> appointment;

  const CheckoutScreen({super.key, required this.appointment});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _discountController = TextEditingController();
  final _extraNameController = TextEditingController();
  final _extraValueController = TextEditingController();

  List<Map<String, dynamic>> _orderItems = [];
  double _subtotal = 0.0;
  double _discount = 0.0;
  String? _selectedPaymentMethod;
  bool _isLoading = false;
  bool _loadingItems = true;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'pix', 'name': 'Pix', 'icon': Icons.qr_code},
    {'id': 'credit_card', 'name': 'Cartão de Crédito', 'icon': Icons.credit_card},
    {'id': 'debit_card', 'name': 'Cartão de Débito', 'icon': Icons.credit_score},
    {'id': 'cash', 'name': 'Dinheiro', 'icon': Icons.payments_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _subtotal = (widget.appointment['total'] as num?)?.toDouble() ?? 0.0;
    _discountController.addListener(_calculateDiscount);
    _loadOrderItems();
  }

  Future<void> _loadOrderItems() async {
    setState(() => _loadingItems = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final items = await fetchOrderItems(supabase, widget.appointment['id'] as String);
      setState(() {
        _orderItems = items;
        _calculateSubtotal();
      });
    } catch (e) {
      // Se não existirem items, apenas continuamos
    } finally {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  void _calculateSubtotal() {
    double total = 0.0;
    for (var item in _orderItems) {
      total += (item['unit_price'] as num).toDouble() * (item['quantity'] as num).toInt();
    }
    setState(() {
      _subtotal = total;
    });
  }

  void _calculateDiscount() {
    final text = _discountController.text.replaceAll(',', '.');
    final value = double.tryParse(text) ?? 0.0;
    setState(() {
      _discount = value > _subtotal ? _subtotal : value;
    });
  }

  double get _finalTotal => _subtotal - _discount;

  Future<void> _addProduct(Map<String, dynamic> product) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final item = await addOrderItem(
        supabase: supabase,
        orderId: widget.appointment['id'] as String,
        itemType: 'product',
        referenceId: product['id'] as String,
        name: product['name'] as String,
        unitPrice: (product['price'] as num).toDouble(),
        quantity: 1,
        commissionPct: 0,
      );
      setState(() {
        _orderItems.add(item);
        _calculateSubtotal();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar produto: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addExtra() async {
    final name = _extraNameController.text.trim();
    final value = double.tryParse(_extraValueController.text.replaceAll(',', '.'));

    if (name.isEmpty || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe nome e valor do adicional'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final supabase = ref.read(supabaseProvider);
      final item = await addOrderItem(
        supabase: supabase,
        orderId: widget.appointment['id'] as String,
        itemType: 'extra',
        name: name,
        unitPrice: value,
        quantity: 1,
        commissionPct: 0,
      );
      setState(() {
        _orderItems.add(item);
        _calculateSubtotal();
        _extraNameController.clear();
        _extraValueController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar extra: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeItem(String itemId) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await removeOrderItem(supabase, itemId);
      setState(() {
        _orderItems.removeWhere((item) => item['id'] == itemId);
        _calculateSubtotal();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover item: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showProductsBottomSheet(List<Map<String, dynamic>> products) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adicionar Produto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Flexible(
              child: products.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[600]),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum produto cadastrado',
                              style: TextStyle(fontSize: 16, color: Colors.grey[400], fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Acesse Configurações › Produtos\npara adicionar itens ao estoque.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final stock = (product['stock'] as num?)?.toInt() ?? 0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withValues(alpha: 0.2),
                            child: const Icon(Icons.inventory_2, color: Colors.blue, size: 20),
                          ),
                          title: Text(product['name'] as String),
                          subtitle: Text(
                            'R\$ ${(product['price'] as num).toStringAsFixed(2)}'
                            '${stock > 0 ? " · $stock em estoque" : " · Sem estoque"}',
                          ),
                          trailing: stock > 0
                              ? IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.green),
                                  onPressed: () {
                                    _addProduct(product);
                                    Navigator.pop(context);
                                  },
                                )
                              : const Icon(Icons.remove_circle_outline, color: Colors.grey),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _discountController.dispose();
    _extraNameController.dispose();
    _extraValueController.dispose();
    super.dispose();
  }

  Future<void> _processCheckout() async {
    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseProvider);

    try {
      await supabase.from('orders').update({
        'status': 'closed',
        'payment_method': _selectedPaymentMethod,
        'discount': _discount,
        'total': _finalTotal,
        'closed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.appointment['id'] as Object);

      ref.invalidate(appointmentsProvider);
      ref.invalidate(monthlyRevenueProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Atendimento finalizado! Valor lançado no caixa.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.appointment['client_name'] ?? 'Cliente Avulso';
    final barberName = widget.appointment['barbers']?['users']?['name'] ?? 'Desconhecido';
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Resumo do Atendimento
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[800]!)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resumo da Comanda', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(clientName as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [const Icon(Icons.face, size: 16, color: Colors.grey), const SizedBox(width: 8), Text('Atendido por $barberName', style: const TextStyle(color: Colors.grey))]),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Lista de Itens da Comanda
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Itens da Comanda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        productsAsync.whenData((products) {
                          _showProductsBottomSheet(products);
                        });
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Produto'),
                      style: TextButton.styleFrom(foregroundColor: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Lista de order items
            _loadingItems
                ? const Center(child: CircularProgressIndicator())
                : _orderItems.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('Nenhum item adicionado', style: TextStyle(color: Colors.grey))),
                      )
                    : Container(
                        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[800]!)),
                        child: Column(
                          children: _orderItems.map((item) {
                            return Dismissible(
                              key: Key(item['id'] as String),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: Colors.red.withValues(alpha: 0.2),
                                child: const Icon(Icons.delete, color: Colors.red),
                              ),
                              onDismissed: (_) => _removeItem(item['id'] as String),
                              child: ListTile(
                                title: Text(item['name'] as String),
                                subtitle: Text('Qtd: ${item['quantity']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'R\$ ${((item['unit_price'] as num).toDouble() * (item['quantity'] as num).toInt()).toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                      onPressed: () => _removeItem(item['id'] as String),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

            const SizedBox(height: 16),

            // 3. Seção Adicionais Avulsos
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[800]!)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adicionar Extra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _extraNameController,
                          decoration: InputDecoration(
                            hintText: 'Nome do extra',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[800],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _extraValueController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'Valor',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[800],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addExtra,
                        icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Valores e Desconto
            const Text('Valores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal dos Serviços', style: TextStyle(fontSize: 16)),
                Text('R\$ ${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Aplicar Desconto (R\$)',
                prefixIcon: const Icon(Icons.money_off, color: Colors.orange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
            const Divider(height: 32, color: Colors.white24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total a Pagar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('R\$ ${_finalTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 32),

            // 5. Forma de Pagamento
            const Text('Forma de Pagamento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
              physics: const NeverScrollableScrollPhysics(),
              children: _paymentMethods.map((method) {
                final isSelected = _selectedPaymentMethod == method['id'];
                return InkWell(
                  onTap: () => setState(() => _selectedPaymentMethod = method['id'] as String?),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.withValues(alpha: 0.2) : Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Colors.green : Colors.transparent, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(method['icon'] as IconData?, color: isSelected ? Colors.green : Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: Text(method['name'] as String, style: TextStyle(color: isSelected ? Colors.green : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16), color: const Color(0xFF1E1E1E),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedPaymentMethod != null && !_isLoading
                  ? _processCheckout
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                  : const Text('Confirmar Pagamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
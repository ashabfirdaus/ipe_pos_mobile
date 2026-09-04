import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/pos_models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/currency_formatter.dart';
import 'receipt_dialog.dart';

class CartSheet extends StatefulWidget {
  final List<CartItemModel> cartItems;
  final int branchId;
  final int warehouseId;
  final List<PaymentMethodModel> paymentMethods;
  final List<PromoModel> promos;
  final double ppnRate;
  final VoidCallback onCartUpdated;
  final VoidCallback onCartCleared;

  const CartSheet({
    super.key,
    required this.cartItems,
    required this.branchId,
    required this.warehouseId,
    required this.paymentMethods,
    required this.promos,
    required this.ppnRate,
    required this.onCartUpdated,
    required this.onCartCleared,
  });

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  late int _selectedPaymentMethodId;
  PromoModel? _selectedPromo;
  final _cashController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethodId = widget.paymentMethods.isNotEmpty
        ? widget.paymentMethods.first.id
        : 1;
    _setDefaultCash();
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _setDefaultCash() {
    final grandTotal = _calculateGrandTotal();
    _cashController.text = grandTotal.toStringAsFixed(0);
  }

  double _calculateSubTotal() {
    return widget.cartItems.fold(0.0, (sum, item) => sum + (item.price * item.qty));
  }

  double _calculateDiscount() {
    if (_selectedPromo == null) return 0.0;
    final subTotal = _calculateSubTotal();
    if (_selectedPromo!.discountType == 'percentage') {
      return (subTotal * _selectedPromo!.discountValue) / 100;
    }
    return _selectedPromo!.discountValue;
  }

  double _calculatePpn() {
    final subTotal = _calculateSubTotal();
    final discount = _calculateDiscount();
    final taxable = (subTotal - discount).clamp(0.0, double.infinity);
    return (taxable * widget.ppnRate) / 100;
  }

  double _calculateGrandTotal() {
    final subTotal = _calculateSubTotal();
    final discount = _calculateDiscount();
    final ppn = _calculatePpn();
    return (subTotal - discount + ppn).clamp(0.0, double.infinity);
  }

  double _getCashAmount() {
    return double.tryParse(_cashController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
  }

  double _calculateChange() {
    final cash = _getCashAmount();
    final grandTotal = _calculateGrandTotal();
    final diff = cash - grandTotal;
    return diff > 0 ? diff : 0.0;
  }

  Future<void> _handleCheckout() async {
    final grandTotal = _calculateGrandTotal();
    final cash = _getCashAmount();

    if (widget.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang belanja masih kosong!')),
      );
      return;
    }

    if (cash < grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal uang tunai kurang dari Grand Total!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final payload = {
      'branch_id': widget.branchId,
      'warehouse_id': widget.warehouseId,
      'payment_method_id': _selectedPaymentMethodId,
      'sub_total': _calculateSubTotal(),
      'discount': _calculateDiscount(),
      'ppn': _calculatePpn(),
      'grand_total': grandTotal,
      'cash': cash,
      'change': _calculateChange(),
      'promo_id': _selectedPromo?.id,
      'items': widget.cartItems.map((item) => item.toInvoiceItemJson()).toList(),
    };

    final res = await ApiService.saveInvoice(payload);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (res.isSuccess && res.data != null) {
      Navigator.of(context).pop(); // Tutup cart sheet
      widget.onCartCleared();

      // Tampilkan struk dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ReceiptDialog(invoice: res.data!),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty ? res.message : 'Gagal memproses transaksi'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subTotal = _calculateSubTotal();
    final discount = _calculateDiscount();
    final ppn = _calculatePpn();
    final grandTotal = _calculateGrandTotal();
    final change = _calculateChange();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXl)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
                    AppSizes.gapW8,
                    Text(
                      'Keranjang POS (${widget.cartItems.length} item)',
                      style: AppTextStyles.h3,
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: widget.cartItems.isEmpty
                      ? null
                      : () {
                          widget.onCartCleared();
                          setState(() {});
                        },
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  label: const Text('Kosongkan', style: TextStyle(color: AppColors.error, fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body List
          Expanded(
            child: widget.cartItems.isEmpty
                ? const Center(
                    child: Text('Keranjang belanja kosong', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.md),
                    itemCount: widget.cartItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = widget.cartItems[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                if (item.qrcode.isNotEmpty)
                                  Text(
                                    'QR: ${item.qrcode}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                AppSizes.gapH4,
                                Text(
                                  CurrencyFormatter.format(item.price),
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          // Qty counter
                          Row(
                            children: [
                              IconButton.filledTonal(
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () {
                                  setState(() {
                                    if (item.qty > 1) {
                                      item.qty--;
                                    } else {
                                      widget.cartItems.removeAt(index);
                                    }
                                  });
                                  widget.onCartUpdated();
                                  _setDefaultCash();
                                },
                                icon: const Icon(Icons.remove),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '${item.qty}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              IconButton.filledTonal(
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () {
                                  setState(() {
                                    item.qty++;
                                  });
                                  widget.onCartUpdated();
                                  _setDefaultCash();
                                },
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          AppSizes.gapW8,
                          SizedBox(
                            width: 80,
                            child: Text(
                              CurrencyFormatter.format(item.subTotal),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Payment & Checkout Summary Section
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Promo Selector
                if (widget.promos.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.local_offer_outlined, size: 18, color: AppColors.secondary),
                      AppSizes.gapW8,
                      const Text('Pilih Promo / Diskon:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  AppSizes.gapH4,
                  DropdownButtonFormField<PromoModel?>(
                    initialValue: _selectedPromo,
                    isDense: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tanpa Promo')),
                      ...widget.promos.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.name} (${p.discountType == 'percentage' ? '${p.discountValue.toStringAsFixed(0)}%' : CurrencyFormatter.format(p.discountValue)})'),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedPromo = val;
                      });
                      _setDefaultCash();
                    },
                  ),
                  AppSizes.gapH8,
                ],

                // Payment Method Selector
                Row(
                  children: [
                    const Icon(Icons.payment_rounded, size: 18, color: AppColors.primary),
                    AppSizes.gapW8,
                    const Text('Metode Pembayaran:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                AppSizes.gapH4,
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.paymentMethods.length,
                    separatorBuilder: (context, index) => AppSizes.gapW8,
                    itemBuilder: (context, index) {
                      final pm = widget.paymentMethods[index];
                      final isSelected = pm.id == _selectedPaymentMethodId;
                      return ChoiceChip(
                        label: Text(pm.name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedPaymentMethodId = pm.id;
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
                AppSizes.gapH8,

                // Calculation Breakdown
                _buildRow('Sub Total', CurrencyFormatter.format(subTotal)),
                if (discount > 0) _buildRow('Diskon Promo', '- ${CurrencyFormatter.format(discount)}', color: AppColors.success),
                if (ppn > 0) _buildRow('PPN (${widget.ppnRate.toStringAsFixed(0)}%)', '+ ${CurrencyFormatter.format(ppn)}'),
                const Divider(height: 12),
                _buildRow('Grand Total', CurrencyFormatter.format(grandTotal), isBold: true, fontSize: 16),
                AppSizes.gapH8,

                // Cash Input & Quick Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cashController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Uang Diterima (Cash)',
                          prefixText: 'Rp ',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    AppSizes.gapW8,
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          _cashController.text = grandTotal.toStringAsFixed(0);
                          setState(() {});
                        },
                        child: const Text('Uang Pas', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                AppSizes.gapH6,
                _buildRow('Kembalian', CurrencyFormatter.format(change), isBold: true, color: AppColors.primary),
                AppSizes.gapH12,

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isProcessing || widget.cartItems.isEmpty ? null : _handleCheckout,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text('Bayar Sekarang (${CurrencyFormatter.format(grandTotal)})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, double fontSize = 12, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

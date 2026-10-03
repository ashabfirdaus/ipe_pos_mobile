import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/pos_models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/currency_formatter.dart';
import 'camera_scanner_page.dart';
import 'receipt_dialog.dart';

class CartSheet extends StatefulWidget {
  final List<CartItemModel> cartItems;
  final int? branchId;
  final int? warehouseId;
  final List<PaymentMethodModel> paymentMethods;
  final List<PromoModel> promos;
  final double ppnRate;
  final VoidCallback onCartUpdated;
  final VoidCallback onCartCleared;

  const CartSheet({
    super.key,
    required this.cartItems,
    this.branchId,
    this.warehouseId,
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
  bool _isProcessing = false;

  List<PaymentMethodModel> get _nonCashPaymentMethods {
    return widget.paymentMethods.where((pm) {
      final n = pm.name.toLowerCase();
      final c = (pm.code ?? '').toLowerCase();
      final t = (pm.type ?? '').toLowerCase();
      return !n.contains('cash') &&
          !n.contains('tunai') &&
          !c.contains('cash') &&
          !c.contains('tunai') &&
          !t.contains('cash') &&
          !t.contains('tunai');
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final methods = _nonCashPaymentMethods;
    _selectedPaymentMethodId = methods.isNotEmpty
        ? methods.first.id
        : 2;
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

  Future<void> _incrementItem(int index) async {
    final item = widget.cartItems[index];

    // Jika barang menggunakan QR fisik (Satuan ber-QR atau Kardus)
    if (item.activeCodes.isNotEmpty || item.isKardus) {
      if (item.qty >= item.product.stock) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Batas stok tercapai: maks ${item.product.stock.toInt()} item'),
              duration: const Duration(milliseconds: 1200),
            ),
          );
        return;
      }

      final scannedCode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (ctx) => const CameraScannerPage()),
      );

      // Jika kasir batal scan / menutup kamera, Qty TIDAK bertambah!
      if (scannedCode == null ||
          scannedCode.trim().isEmpty ||
          scannedCode.trim().toLowerCase() == 'null') {
        return;
      }

      final cleanCode = scannedCode.trim();
      if (!mounted) return;

      final isDuplicate = widget.cartItems.any((it) => it.activeCodes.contains(cleanCode));
      if (isDuplicate) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('QR Code stok "$cleanCode" sudah ada di dalam keranjang!'),
              backgroundColor: AppColors.warning,
            ),
          );
        return;
      }

      final res = await ApiService.scanQr(
        qrcode: cleanCode,
        warehouseId: widget.warehouseId,
        branchId: widget.branchId,
      );

      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        final product = res.data!;
        final actualQrCode = product.qrcode?.isNotEmpty == true
            ? product.qrcode!
            : cleanCode;

        if (product.itemId != item.product.itemId) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('QR "$actualQrCode" adalah produk "${product.name}", bukan "${item.product.name}"'),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 3),
              ),
            );
          return;
        }

        if (product.isKardus != item.isKardus) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  product.isKardus
                      ? 'QR ini adalah Kardus, tidak bisa digabung dengan item Satuan!'
                      : 'QR ini adalah Satuan, tidak bisa digabung dengan item Kardus!',
                ),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 3),
              ),
            );
          return;
        }

        setState(() {
          if (!item.activeCodes.contains(actualQrCode)) {
            item.activeCodes.add(actualQrCode);
            if (item.isKardus) {
              item.wrapperQrcodes.add(actualQrCode);
              final addQty = product.qrStock.toInt() > 0 ? product.qrStock.toInt() : 1;
              item.qty += addQty;
            } else {
              item.qrcodes.add(actualQrCode);
              item.qty = item.activeCodes.length;
            }
          }
          if (item.qty > item.product.stock) {
            item.product.stock = item.qty.toDouble();
          }
        });
        widget.onCartUpdated();

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('${item.product.name} (QR: $actualQrCode) berhasil ditambahkan'),
              duration: const Duration(seconds: 2),
            ),
          );
      } else {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                res.message.isNotEmpty
                    ? res.message
                    : 'Stok barang dengan QR "$cleanCode" tidak ditemukan.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
      }
    } else {
      // Produk manual tanpa QR (ditambahkan dari katalog)
      if (item.qty >= item.product.stock) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Batas stok tercapai: maks ${item.product.stock.toInt()} item'),
              duration: const Duration(milliseconds: 1200),
            ),
          );
        return;
      }
      setState(() {
        item.qty++;
      });
      widget.onCartUpdated();
    }
  }

  Future<void> _handleCheckout() async {
    // Jaminan ketat: item Satuan ber-QR hanya boleh dijual sebanyak QR yang berhasil di-scan
    // Item Kardus tidak dipotong menjadi activeCodes.length karena 1 wrapper QR mewakili seluruh isi kemasan/kardus
    for (final item in widget.cartItems) {
      if (!item.isKardus && item.activeCodes.isNotEmpty && item.qty > item.activeCodes.length) {
        item.qty = item.activeCodes.length;
      }
    }

    final grandTotal = _calculateGrandTotal();

    if (widget.cartItems.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Keranjang belanja masih kosong!')),
        );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final itemsPayload = widget.cartItems.map((item) => item.toInvoiceItemJson()).toList();

    final payload = <String, dynamic>{
      if (widget.branchId != null) 'branch_id': widget.branchId,
      if (widget.warehouseId != null) 'warehouse_id': widget.warehouseId,
      'payment_method_id': _selectedPaymentMethodId,
      'sub_total': _calculateSubTotal(),
      'discount': _calculateDiscount(),
      'ppn': _calculatePpn(),
      'grand_total': grandTotal,
      'cash': grandTotal,
      'change': 0.0,
      if (_selectedPromo != null) 'promo_id': _selectedPromo!.id,
      'items': itemsPayload,
      'details': itemsPayload,
    };

    final res = await ApiService.saveInvoice(payload);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (res.isSuccess && res.data != null) {
      var invoice = res.data!;
      if (invoice.createdAt.isEmpty) {
        invoice = invoice.copyWith(createdAt: DateTime.now().toIso8601String());
      }
      if (invoice.items.isEmpty && widget.cartItems.isNotEmpty) {
        invoice = invoice.copyWith(
          items: widget.cartItems
              .map(
                (item) => InvoiceItemModel(
                  itemId: item.product.itemId,
                  itemName: item.product.name,
                  qty: item.qty,
                  price: item.price,
                  discount: item.discount,
                  subTotal: item.subTotal,
                  qrcode: item.qrcode.isNotEmpty ? item.qrcode : null,
                  unit: item.product.unit,
                  itemCode: item.product.code,
                ),
              )
              .toList(),
        );
      }
      if (invoice.cashierName == null ||
          invoice.cashierName!.trim().isEmpty ||
          invoice.cashierName == '-') {
        final cashier = await StorageService.getCashierName();
        if (cashier != null && cashier.isNotEmpty) {
          invoice = invoice.copyWith(cashierName: cashier);
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop(); // Tutup cart sheet
      widget.onCartCleared();

      // Tampilkan struk dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ReceiptDialog(invoice: invoice),
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
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final item = widget.cartItems[index];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Top Row: Product Name (Full Width) + Remove Button
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    widget.cartItems.removeAt(index);
                                  });
                                  widget.onCartUpdated();
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 19,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // 2. Badge Row: QR Kardus / Satuan
                          if (item.activeCodes.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: item.activeCodes.map((qr) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.isKardus
                                        ? const Color(0xFFFFF3E0)
                                        : const Color(0xFFE8EAF6),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: item.isKardus
                                          ? const Color(0xFFFFB74D)
                                          : const Color(0xFFC5CAE9),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item.isKardus
                                            ? Icons.inventory_2_outlined
                                            : Icons.qr_code_2_rounded,
                                        size: 13,
                                        color: item.isKardus
                                            ? const Color(0xFFE65100)
                                            : const Color(0xFF283593),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.isKardus ? 'Kardus: $qr' : 'Satuan: $qr',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: item.isKardus
                                              ? const Color(0xFFE65100)
                                              : const Color(0xFF283593),
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            item.activeCodes.remove(qr);
                                            if (item.isKardus) {
                                              item.wrapperQrcodes.remove(qr);
                                            } else {
                                              item.qrcodes.remove(qr);
                                            }
                                            if (item.activeCodes.isEmpty) {
                                              widget.cartItems.removeAt(index);
                                            } else {
                                              if (!item.isKardus) {
                                                item.qty = item.activeCodes.length;
                                              } else {
                                                final capacityPerKardus = item.product.qrStock.toInt() > 0 ? item.product.qrStock.toInt() : 1;
                                                item.qty = item.wrapperQrcodes.length * capacityPerKardus;
                                              }
                                            }
                                          });
                                          widget.onCartUpdated();
                                        },
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 13,
                                          color: item.isKardus
                                              ? const Color(0xFFE65100)
                                              : const Color(0xFF283593),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // 3. Bottom Row: Subtotal & Harga Satuan (Kiri) + Stepper Qty (Kanan)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Kolom Harga
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(item.subTotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@ ${CurrencyFormatter.format(item.price)} / ${item.product.unit ?? "pcs"}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),

                              // Qty Stepper Controls
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Tombol Minus
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                                        onTap: () {
                                          setState(() {
                                            if (item.qty > 1) {
                                              item.qty--;
                                              if (item.activeCodes.length > item.qty) {
                                                final removed = item.activeCodes.removeLast();
                                                if (item.isKardus) {
                                                  item.wrapperQrcodes.remove(removed);
                                                } else {
                                                  item.qrcodes.remove(removed);
                                                }
                                              }
                                            } else {
                                              widget.cartItems.removeAt(index);
                                            }
                                          });
                                          widget.onCartUpdated();
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 30,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            item.qty == 1 ? Icons.delete_outline_rounded : Icons.remove,
                                            size: item.qty == 1 ? 16 : 17,
                                            color: item.qty == 1 ? Colors.red.shade400 : Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Teks Qty
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 36),
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.symmetric(
                                          vertical: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Text(
                                        '${item.qty}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),

                                    // Tombol Plus
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                                        onTap: () => _incrementItem(index),
                                        child: Container(
                                          width: 32,
                                          height: 30,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.add,
                                            size: 17,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Payment Calculation & Action Form
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
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
                    key: ValueKey('promo_${_selectedPromo?.id}'),
                    initialValue: widget.promos.contains(_selectedPromo) ? _selectedPromo : null,
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
                    },
                  ),
                  AppSizes.gapH8,
                ],

                // Payment Method Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _nonCashPaymentMethods.map((pm) {
                      final isSelected = _selectedPaymentMethodId == pm.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(pm.name),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedPaymentMethodId = pm.id;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                AppSizes.gapH8,

                // Calculation Summary
                _buildSummaryRow('Subtotal', CurrencyFormatter.format(subTotal)),
                if (discount > 0)
                  _buildSummaryRow('Diskon', '- ${CurrencyFormatter.format(discount)}', color: AppColors.success),
                if (ppn > 0)
                  _buildSummaryRow('PPN (${widget.ppnRate.toStringAsFixed(0)}%)', CurrencyFormatter.format(ppn)),
                const Divider(height: 12),
                _buildSummaryRow('Grand Total', CurrencyFormatter.format(grandTotal), isBold: true, fontSize: 16),
                AppSizes.gapH12,

                // Submit Checkout Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
                    ),
                    onPressed: _isProcessing || widget.cartItems.isEmpty ? null : _handleCheckout,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Bayar Sekarang (${CurrencyFormatter.format(grandTotal)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSummaryRow(String title, String value, {bool isBold = false, Color? color, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

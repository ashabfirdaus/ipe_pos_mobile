import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/pos_models.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/currency_formatter.dart';
import 'widgets/camera_scanner_page.dart';
import 'widgets/receipt_dialog.dart';
import 'widgets/scan_qr_dialog.dart';
import 'widgets/stock_qty_confirm_dialog.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  bool _isLoadingInitial = true;
  bool _isProcessingCheckout = false;

  BranchModel? _defaultBranch;
  WarehouseModel? _defaultWarehouse;
  int? _selectedBranchId;
  int? _selectedWarehouseId;

  List<PaymentMethodModel> _paymentMethods = [];
  List<PromoModel> _promos = [];
  double _ppnRate = 0.0;

  final List<CartItemModel> _cartItems = [];
  late int _selectedPaymentMethodId;
  PromoModel? _selectedPromo;
  final TextEditingController _cashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethodId = 1;
    _loadInitialMasterData();
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMasterData() async {
    setState(() => _isLoadingInitial = true);

    final initialRes = await ApiService.getPosInitialData();

    if (!mounted) return;

    if (initialRes.isSuccess && initialRes.data != null) {
      final initData = initialRes.data!;
      _defaultBranch = initData.defaultBranch;
      _defaultWarehouse = initData.defaultWarehouse;
      _selectedBranchId = initData.defaultBranch?.id;
      _selectedWarehouseId = initData.defaultWarehouse?.id;

      _paymentMethods = initData.paymentMethods.isNotEmpty
          ? initData.paymentMethods
          : [PaymentMethodModel(id: 1, name: 'Tunai (Cash)')];

      _selectedPaymentMethodId = _paymentMethods.first.id;
      _promos = initData.promos;
      _ppnRate = initData.ppnRate;
    } else {
      _paymentMethods = [
        PaymentMethodModel(id: 1, name: 'Tunai (Cash)'),
        PaymentMethodModel(id: 2, name: 'QRIS'),
      ];
      _selectedPaymentMethodId = 1;
    }

    setState(() => _isLoadingInitial = false);
    _updateDefaultCash();
  }

  void _updateDefaultCash() {
    final grandTotal = _calculateGrandTotal();
    _cashController.text = grandTotal.toStringAsFixed(0);
  }

  double _calculateSubTotal() {
    return _cartItems.fold(0.0, (sum, item) => sum + (item.price * item.qty));
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
    return (taxable * _ppnRate) / 100;
  }

  double _calculateGrandTotal() {
    final subTotal = _calculateSubTotal();
    final discount = _calculateDiscount();
    final ppn = _calculatePpn();
    return (subTotal - discount + ppn).clamp(0.0, double.infinity);
  }

  double _getCashAmount() {
    return double.tryParse(
          _cashController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0.0;
  }

  double _calculateChange() {
    final cash = _getCashAmount();
    final grandTotal = _calculateGrandTotal();
    final diff = cash - grandTotal;
    return diff > 0 ? diff : 0.0;
  }

  void _onCartChanged() {
    setState(() {});
    _updateDefaultCash();
  }

  Future<void> _openProductCatalog() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.posProducts,
      arguments: {
        'branchId': _selectedBranchId,
        'warehouseId': _selectedWarehouseId,
        'cartItems': _cartItems,
        'onCartUpdated': _onCartChanged,
      },
    );

    if (!mounted) return;
    setState(() {});
    _updateDefaultCash();
  }

  Future<void> _openDirectCameraScanner() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (ctx) => const CameraScannerPage()),
    );

    // Jika scanner dibatalkan / ditutup tanpa mendapatkan QR code, jangan kirim request ke server
    if (scannedCode == null ||
        scannedCode.trim().isEmpty ||
        scannedCode.trim().toLowerCase() == 'null') {
      return;
    }

    final cleanCode = scannedCode.trim();
    if (!mounted) return;

    // Cek apakah QR stok ini sudah ada di dalam keranjang
    final isDuplicate = _cartItems.any((item) => item.qrcode == cleanCode);
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'QR Code stok "$cleanCode" sudah ada di dalam keranjang!',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mencari data stok QR: $cleanCode...'),
        duration: const Duration(seconds: 1),
      ),
    );

    final res = await ApiService.scanQr(
      qrcode: cleanCode,
      warehouseId: _selectedWarehouseId,
      branchId: _selectedBranchId,
    );

    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      final product = res.data!;
      final actualQrCode = product.qrcode?.isNotEmpty == true
          ? product.qrcode!
          : cleanCode;
      int finalQty = 1;
      if (product.stock > 1) {
        final chosenQty = await StockQtyConfirmDialog.show(
          context,
          product: product,
          qrcode: actualQrCode,
        );
        if (chosenQty == null) return;
        finalQty = chosenQty;
      }
      _addToCart(product, qrcode: actualQrCode, qty: finalQty);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
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
  }

  void _openScanQrDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ScanQrDialog(
        warehouseId: _selectedWarehouseId,
        branchId: _selectedBranchId,
        onProductFound: (product, qrcode, qty) {
          _addToCart(product, qrcode: qrcode, qty: qty);
        },
      ),
    );
  }

  Future<void> _scanQrForItem(int index) async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (ctx) => const CameraScannerPage()),
    );

    if (scannedCode == null ||
        scannedCode.trim().isEmpty ||
        scannedCode.trim().toLowerCase() == 'null') {
      return;
    }

    final cleanCode = scannedCode.trim();
    if (!mounted) return;

    final isDuplicate = _cartItems.any((item) => item.qrcode == cleanCode);
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'QR Code stok "$cleanCode" sudah digunakan di keranjang!',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _cartItems[index].qrcode = cleanCode;
    });
    _onCartChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('QR Code stok "$cleanCode" berhasil dipasangkan'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addToCart(ProductModel product, {String qrcode = '', int qty = 1}) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stok produk sedang kosong!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final effectiveQrcode = qrcode.isNotEmpty
        ? qrcode
        : (product.qrcode?.isNotEmpty == true ? product.qrcode! : '');

    // 1. Jika ditambahkan dengan QR Code stok fisik
    if (effectiveQrcode.isNotEmpty) {
      final isQrDuplicate = _cartItems.any(
        (item) => item.qrcode == effectiveQrcode,
      );
      if (isQrDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR Code stok "$effectiveQrcode" sudah ada di dalam keranjang!',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      // Cek apakah ada item produk sama yang belum punya QR stok
      final unassignedIdx = _cartItems.indexWhere(
        (item) => item.product.itemId == product.itemId && item.qrcode.isEmpty,
      );

      if (unassignedIdx >= 0) {
        if (_cartItems[unassignedIdx].qty > qty) {
          setState(() {
            _cartItems[unassignedIdx].qty -= qty;
            _cartItems.add(
              CartItemModel(
                product: product,
                qty: qty,
                price: product.price,
                qrcode: effectiveQrcode,
              ),
            );
          });
        } else {
          setState(() {
            _cartItems[unassignedIdx].qrcode = effectiveQrcode;
            _cartItems[unassignedIdx].qty = qty;
          });
        }
      } else {
        setState(() {
          _cartItems.add(
            CartItemModel(
              product: product,
              qty: qty,
              price: product.price,
              qrcode: effectiveQrcode,
            ),
          );
        });
      }
    } else {
      // 2. Jika ditambahkan manual dari katalog
      final existingIndex = _cartItems.indexWhere(
        (item) => item.product.itemId == product.itemId && item.qrcode.isEmpty,
      );

      if (existingIndex >= 0) {
        if (_cartItems[existingIndex].qty + qty <= product.stock) {
          setState(() {
            _cartItems[existingIndex].qty += qty;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Jumlah pesanan sudah mencapai batas stok tersedia!',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
          return;
        }
      } else {
        setState(() {
          _cartItems.add(
            CartItemModel(
              product: product,
              qty: qty,
              price: product.price,
              qrcode: '',
            ),
          );
        });
      }
    }

    _onCartChanged();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          qrcode.isNotEmpty
              ? '${product.name} (Qty: $qty, QR: $qrcode) ditambahkan'
              : '${product.name} dimasukkan ke keranjang',
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: qrcode.isNotEmpty
            ? SnackBarAction(
                label: 'Scan Lagi',
                textColor: Colors.white,
                onPressed: _openDirectCameraScanner,
              )
            : null,
      ),
    );
  }

  void _clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kosongkan Keranjang?'),
        content: const Text(
          'Semua produk yang ada di dalam keranjang kasir saat ini akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _cartItems.clear();
      });
      _onCartChanged();
    }
  }

  Future<void> _handleCheckout() async {
    final grandTotal = _calculateGrandTotal();
    final cash = _getCashAmount();

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Keranjang belanja masih kosong! Silakan pilih produk atau scan QR stok.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedBranchId == null || _selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih Cabang dan Gudang terlebih dahulu!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedPaymentMethodId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih metode pembayaran terlebih dahulu!'),
          backgroundColor: AppColors.warning,
        ),
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

    setState(() => _isProcessingCheckout = true);

    final itemsPayload = _cartItems
        .map((item) => item.toInvoiceItemJson())
        .toList();

    final payload = <String, dynamic>{
      'branch_id': _selectedBranchId,
      'warehouse_id': _selectedWarehouseId,
      'payment_method_id': _selectedPaymentMethodId,
      'sub_total': _calculateSubTotal(),
      'discount': _calculateDiscount(),
      'ppn': _calculatePpn(),
      'grand_total': grandTotal,
      'cash': cash,
      'change': _calculateChange(),
      if (_selectedPromo != null) 'promo_id': _selectedPromo!.id,
      'items': itemsPayload,
      'details': itemsPayload,
    };

    debugPrint(
      '[POS Checkout] Mengirim detail transaksi POS ke server: ${jsonEncode(payload)}',
    );
    final res = await ApiService.saveInvoice(payload);

    if (!mounted) return;
    setState(() => _isProcessingCheckout = false);

    if (res.isSuccess && res.data != null) {
      var invoice = res.data!;
      final cartItemsBackup = List<CartItemModel>.from(_cartItems);
      final promoUsed = _selectedPromo;

      // Pastikan items dan rincian transaksi terisi lengkap untuk struk cetak
      if (invoice.items.isEmpty && cartItemsBackup.isNotEmpty) {
        invoice = invoice.copyWith(
          items: cartItemsBackup
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

      final selectedPm = _paymentMethods
          .where((p) => p.id == _selectedPaymentMethodId)
          .firstOrNull;

      if (invoice.branchName == null && _defaultBranch != null) {
        invoice = invoice.copyWith(branchName: _defaultBranch!.name);
      }
      if (invoice.warehouseName == null && _defaultWarehouse != null) {
        invoice = invoice.copyWith(warehouseName: _defaultWarehouse!.name);
      }
      if (invoice.paymentMethodName == null && selectedPm != null) {
        invoice = invoice.copyWith(paymentMethodName: selectedPm.name);
      }
      if (invoice.promoName == null && promoUsed != null) {
        invoice = invoice.copyWith(promoName: promoUsed.name);
      }
      if (invoice.subTotal == 0) {
        invoice = invoice.copyWith(subTotal: _calculateSubTotal());
      }
      if (invoice.grandTotal == 0) {
        invoice = invoice.copyWith(grandTotal: grandTotal);
      }
      if (invoice.cash == 0) {
        invoice = invoice.copyWith(cash: cash);
      }
      if (invoice.change == 0) {
        invoice = invoice.copyWith(change: _calculateChange());
      }

      setState(() {
        _cartItems.clear();
        _selectedPromo = null;
      });
      _updateDefaultCash();

      // Tampilkan struk nota dialog dengan opsi cetak ke printer Bluetooth
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ReceiptDialog(invoice: invoice),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message.isNotEmpty
                ? res.message
                : 'Gagal memproses transaksi kasir.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItemsCount = _cartItems.fold(0, (sum, item) => sum + item.qty);
    final grandTotal = _calculateGrandTotal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir POS'),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.qr_code_scanner_rounded),
          //   tooltip: 'Input Kode QR Manual',
          //   onPressed: _openScanQrDialog,
          // ),
          // IconButton(
          //   icon: const Icon(Icons.camera_alt_rounded),
          //   tooltip: 'Scan QR Stok Kamera',
          //   onPressed: _openDirectCameraScanner,
          // ),
          if (_cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Kosongkan Keranjang',
              onPressed: _clearCart,
            ),
          // IconButton(
          //   icon: const Icon(Icons.print_outlined),
          //   tooltip: 'Pengaturan Printer',
          //   onPressed: () =>
          //       Navigator.of(context).pushNamed(AppRoutes.printerSettings),
          // ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang',
            onPressed: _loadInitialMasterData,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoadingInitial
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Scrollable POS Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: AppSizes.paddingPage,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Info Cabang & Gudang
                          // _buildLocationCard(),
                          // AppSizes.gapH16,

                          // 2. Tombol Aksi: Scan QR Stok & Katalog Produk
                          _buildActionButtons(totalItemsCount),
                          AppSizes.gapH20,

                          // 3. Section Daftar Item di Keranjang
                          _buildCartSection(),
                          AppSizes.gapH20,

                          // 4. Section Promo Diskon
                          if (_promos.isNotEmpty) ...[
                            _buildPromoSection(),
                            AppSizes.gapH20,
                          ],

                          // 5. Section Metode Pembayaran
                          _buildPaymentMethodSection(),
                          AppSizes.gapH20,

                          // 6. Rincian Tagihan & Input Uang Tunai
                          _buildFinancialSummarySection(),
                          AppSizes.gapH24,
                        ],
                      ),
                    ),
                  ),

                  // Fixed Bottom Checkout Bar
                  _buildBottomCheckoutBar(grandTotal),
                ],
              ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final branchName = _defaultBranch?.name ?? 'Cabang Aktif';
    final warehouseName = _defaultWarehouse?.name ?? 'Gudang Utama';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.storefront_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          AppSizes.gapW12,
          Expanded(
            child: Text(
              '$branchName  •  $warehouseName',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(int totalItemsCount) {
    return Column(
      children: [
        // 1 & 2: Tombol Terpisah: Scan QR Barang & Input Manual Kode (Ukuran Ringkas/Disesuaikan)
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  elevation: 1,
                ),
                onPressed: _openDirectCameraScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text(
                  'Scan QR Barang',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8EAF6),
                  foregroundColor: const Color(0xFF1A237E),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFC5CAE9)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
                onPressed: _openScanQrDialog,
                icon: const Icon(
                  Icons.keyboard_alt_outlined,
                  size: 18,
                  color: Color(0xFF1A237E),
                ),
                label: const Text(
                  'Input Kode Manual',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3: Tombol Katalog Produk (Ukuran kecil / compact)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: Colors.grey.shade300),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
            onPressed: _openProductCatalog,
            icon: const Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            label: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih dari Katalog Produk',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (totalItemsCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$totalItemsCount item di keranjang',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                AppSizes.gapW8,
                const Text('Keranjang Belanja', style: AppTextStyles.h3),
              ],
            ),
            if (_cartItems.isNotEmpty)
              Text(
                '${_cartItems.length} jenis item',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        AppSizes.gapH12,
        if (_cartItems.isEmpty)
          _buildEmptyCartCard()
        else
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return _buildCartItemTile(item, index);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyCartCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.remove_shopping_cart_outlined,
            size: 40,
            color: Colors.grey.shade400,
          ),
          AppSizes.gapH8,
          const Text(
            'Keranjang Masih Kosong',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          AppSizes.gapH4,
          const Text(
            'Gunakan tombol Scan QR, Input Manual, atau Katalog di atas untuk menambahkan barang.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(CartItemModel item, int index) {
    final hasQr = item.qrcode.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSizes.gapH4,
                Text(
                  '${CurrencyFormatter.format(item.price)} / ${item.product.unit ?? "pcs"}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (hasQr) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFC5CAE9)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          size: 13,
                          color: Color(0xFF283593),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'QR: ${item.qrcode}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF283593),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _scanQrForItem(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 12,
                            color: Colors.amber.shade900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+ Scan QR Stok',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppSizes.gapW8,

          // Qty Controls (Bisa dikurangi, tidak bisa ditambah melebihi stok QR/produk)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      if (item.qty > 1) {
                        item.qty--;
                      } else {
                        _cartItems.removeAt(index);
                      }
                    });
                    _onCartChanged();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${item.qty}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  // Tidak bisa ditambah melebihi remaining_qty stok yang ada
                  onPressed: item.qty >= item.product.stock
                      ? null
                      : () {
                          setState(() {
                            item.qty++;
                          });
                          _onCartChanged();
                        },
                ),
              ],
            ),
          ),
          AppSizes.gapW12,

          // Subtotal
          SizedBox(
            width: 80,
            child: Text(
              CurrencyFormatter.format(item.subTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Delete Button
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.error,
            ),
            tooltip: 'Hapus',
            onPressed: () {
              setState(() {
                _cartItems.removeAt(index);
              });
              _onCartChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.local_offer_outlined,
              color: AppColors.secondary,
              size: 20,
            ),
            AppSizes.gapW8,
            const Text('Promo & Diskon', style: AppTextStyles.h3),
          ],
        ),
        AppSizes.gapH8,
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PromoModel?>(
                value: _selectedPromo,
                isExpanded: true,
                hint: const Text('Pilih Promo (Opsional)'),
                items: [
                  const DropdownMenuItem<PromoModel?>(
                    value: null,
                    child: Text('Tanpa Promo'),
                  ),
                  ..._promos.map(
                    (p) => DropdownMenuItem<PromoModel?>(
                      value: p,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            p.discountType == 'percentage'
                                ? '${p.discountValue}% Off'
                                : '- ${CurrencyFormatter.format(p.discountValue)}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedPromo = val;
                  });
                  _updateDefaultCash();
                },
              ),
            ),
          ),
        ),

        // Banner Promo Aktif
        if (_selectedPromo != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Promo Aktif: ${_selectedPromo!.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        _selectedPromo!.discountType == 'percentage'
                            ? 'Diskon ${_selectedPromo!.discountValue}% (Hemat ${CurrencyFormatter.format(_calculateDiscount())})'
                            : 'Potongan ${CurrencyFormatter.format(_selectedPromo!.discountValue)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.payment_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            AppSizes.gapW8,
            const Text('Metode Pembayaran', style: AppTextStyles.h3),
          ],
        ),
        AppSizes.gapH8,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paymentMethods.map((pm) {
            final isSelected = _selectedPaymentMethodId == pm.id;
            return ChoiceChip(
              avatar: Icon(
                pm.name.toLowerCase().contains('qris')
                    ? Icons.qr_code_2_rounded
                    : Icons.money_rounded,
                size: 18,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              label: Text(pm.name),
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
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
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFinancialSummarySection() {
    final subTotal = _calculateSubTotal();
    final discount = _calculateDiscount();
    final ppn = _calculatePpn();
    final grandTotal = _calculateGrandTotal();
    final change = _calculateChange();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rincian Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Divider(height: 20),
            _buildFinancialRow('Sub Total', CurrencyFormatter.format(subTotal)),
            if (discount > 0) ...[
              AppSizes.gapH4,
              _buildFinancialRow(
                _selectedPromo != null
                    ? 'Diskon Promo (${_selectedPromo!.name})'
                    : 'Diskon Promo',
                '- ${CurrencyFormatter.format(discount)}',
                color: AppColors.success,
                isBold: true,
              ),
            ],
            if (ppn > 0) ...[
              AppSizes.gapH4,
              _buildFinancialRow(
                'PPN ($_ppnRate%)',
                '+ ${CurrencyFormatter.format(ppn)}',
              ),
            ],
            const Divider(height: 20),
            _buildFinancialRow(
              'Grand Total',
              CurrencyFormatter.format(grandTotal),
              isBold: true,
              fontSize: 16,
            ),
            AppSizes.gapH16,

            // Input Uang Tunai Diterima
            const Text(
              'Uang Diterima:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            AppSizes.gapH8,
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _cashController.clear();
                    setState(() {});
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const Divider(height: 24),

            // Kembalian
            _buildFinancialRow(
              'Kembalian',
              CurrencyFormatter.format(change),
              isBold: true,
              color: AppColors.primary,
              fontSize: 15,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomCheckoutBar(double grandTotal) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Pembayaran:',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(grandTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (_calculateDiscount() > 0)
                    Text(
                      'Hemat ${CurrencyFormatter.format(_calculateDiscount())}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            AppSizes.gapW16,
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
              onPressed: _isProcessingCheckout || _cartItems.isEmpty
                  ? null
                  : _handleCheckout,
              icon: _isProcessingCheckout
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                _isProcessingCheckout ? 'Memproses...' : 'Bayar Transaksi',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

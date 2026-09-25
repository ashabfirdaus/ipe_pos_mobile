import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/pos_models.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/currency_formatter.dart';
import 'widgets/camera_scanner_page.dart';
import 'widgets/kardus_conflict_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethodId = 1;
    _loadInitialMasterData();
  }

  @override
  void dispose() {
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

      final nonCashMethods = initData.paymentMethods.where((pm) {
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

      _paymentMethods = nonCashMethods.isNotEmpty
          ? nonCashMethods
          : [
              PaymentMethodModel(id: 2, name: 'QRIS'),
              PaymentMethodModel(id: 3, name: 'Transfer Bank'),
            ];

      _selectedPaymentMethodId = _paymentMethods.first.id;
      _promos = initData.promos;
      _ppnRate = initData.ppnRate;
    } else {
      _paymentMethods = [
        PaymentMethodModel(id: 2, name: 'QRIS'),
        PaymentMethodModel(id: 3, name: 'Transfer Bank'),
      ];
      _selectedPaymentMethodId = 2;
    }

    setState(() => _isLoadingInitial = false);
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

  void _onCartChanged() {
    setState(() {});
  }

  void _showNotification(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: duration,
          behavior: behavior,
        ),
      );
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
      _showNotification(
        'QR Code stok "$cleanCode" sudah ada di dalam keranjang!',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    _showNotification(
      'Mencari QR Kardus / Satuan: $cleanCode...',
      duration: const Duration(seconds: 1),
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

      // Cek konflik Kardus vs Satuan (Opsi 2)
      final canProceed = await KardusConflictHelper.checkAndResolve(
        context: context,
        product: product,
        cartItems: _cartItems,
        onCartModified: () {
          setState(() {});
          _onCartChanged();
        },
      );
      if (!canProceed || !mounted) return;

      int finalQty = 1;
      if (product.isKardus && product.qrStock > 1) {
        final chosenQty = await StockQtyConfirmDialog.show(
          context,
          product: product,
          qrcode: actualQrCode,
        );
        if (chosenQty == null) return;
        finalQty = chosenQty;
      } else if (product.isKardus) {
        finalQty = product.qrStock.toInt() > 0 ? product.qrStock.toInt() : 1;
      }
      _addToCart(product, qrcode: actualQrCode, qty: finalQty);
    } else {
      _showNotification(
        res.message.isNotEmpty
            ? res.message
            : 'Stok barang dengan QR Kardus / Satuan "$cleanCode" tidak ditemukan.',
        backgroundColor: AppColors.error,
      );
    }
  }

  void _openScanQrDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ScanQrDialog(
        warehouseId: _selectedWarehouseId,
        branchId: _selectedBranchId,
        onProductFound: (product, qrcode, qty) async {
          final canProceed = await KardusConflictHelper.checkAndResolve(
            context: context,
            product: product,
            cartItems: _cartItems,
            onCartModified: () {
              setState(() {});
              _onCartChanged();
            },
          );
          if (canProceed && mounted) {
            _addToCart(product, qrcode: qrcode, qty: qty);
          }
        },
      ),
    );
  }

  Future<void> _incrementItem(int index) async {
    final item = _cartItems[index];

    // Jika barang menggunakan QR fisik (Satuan ber-QR atau Kardus)
    if (item.activeCodes.isNotEmpty || item.isKardus) {
      if (item.qty >= item.product.stock) {
        _showNotification(
          'Batas stok tercapai: maks ${item.product.stock.toInt()} item',
          duration: const Duration(milliseconds: 1200),
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

      // Cek apakah QR sudah ada di dalam keranjang
      final isDuplicate = _cartItems.any((it) => it.activeCodes.contains(cleanCode));
      if (isDuplicate) {
        _showNotification(
          'QR Code stok "$cleanCode" sudah ada di dalam keranjang!',
          backgroundColor: AppColors.warning,
        );
        return;
      }

      _showNotification(
        'Mencari QR: $cleanCode...',
        duration: const Duration(seconds: 1),
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

        // Pastikan QR cocok dengan produk yang sama
        if (product.itemId != item.product.itemId) {
          _showNotification(
            'QR "$actualQrCode" adalah produk "${product.name}", bukan "${item.product.name}"',
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          );
          return;
        }

        // Pastikan jenis kardus / satuan konsisten
        if (product.isKardus != item.isKardus) {
          _showNotification(
            product.isKardus
                ? 'QR ini adalah Kardus, tidak bisa digabung dengan item Satuan!'
                : 'QR ini adalah Satuan, tidak bisa digabung dengan item Kardus!',
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
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
        _onCartChanged();

        _showNotification('${item.product.name} (QR: $actualQrCode) berhasil ditambahkan');
      } else {
        _showNotification(
          res.message.isNotEmpty
              ? res.message
              : 'Stok barang dengan QR "$cleanCode" tidak ditemukan.',
          backgroundColor: AppColors.error,
        );
      }
    } else {
      // Produk manual tanpa QR (ditambahkan dari katalog)
      if (item.qty >= item.product.stock) {
        _showNotification(
          'Batas stok tercapai: maks ${item.product.stock.toInt()} item',
          duration: const Duration(milliseconds: 1200),
        );
        return;
      }
      setState(() {
        item.qty++;
      });
      _onCartChanged();
    }
  }

  void _addToCart(ProductModel product, {String qrcode = '', int qty = 1}) {
    if (product.stock <= 0) {
      _showNotification(
        'Stok produk sedang kosong!',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final effectiveQrcode = qrcode.isNotEmpty
        ? qrcode
        : (product.qrcode?.isNotEmpty == true ? product.qrcode! : '');

    // 1. Jika ditambahkan dengan QR Code stok fisik
    if (effectiveQrcode.isNotEmpty) {
      final isQrDuplicate = _cartItems.any(
        (item) => item.activeCodes.contains(effectiveQrcode),
      );
      if (isQrDuplicate) {
        _showNotification(
          'QR Code stok "$effectiveQrcode" sudah ada di dalam keranjang!',
          backgroundColor: AppColors.warning,
        );
        return;
      }

      // Cek apakah produk dengan tipe yang SAMA (Kardus dengan Kardus, Satuan dengan Satuan) sudah ada
      final existingIndex = _cartItems.indexWhere(
        (item) => item.product.itemId == product.itemId && item.isKardus == product.isKardus,
      );

      if (existingIndex >= 0) {
        final existingItem = _cartItems[existingIndex];
        setState(() {
          if (!existingItem.activeCodes.contains(effectiveQrcode)) {
            existingItem.activeCodes.add(effectiveQrcode);
          }
          existingItem.qty += qty;
          if (existingItem.qty > existingItem.product.stock) {
            existingItem.product.stock = existingItem.qty.toDouble();
          }
        });
      } else {
        setState(() {
          _cartItems.add(
            CartItemModel(
              product: product,
              qty: qty,
              price: product.price,
              qrcodes: product.isKardus ? [] : [effectiveQrcode],
              wrapperQrcodes: product.isKardus ? [effectiveQrcode] : [],
            ),
          );
        });
      }
    } else {
      // 2. Jika ditambahkan manual dari katalog
      final existingIndex = _cartItems.indexWhere(
        (item) => item.product.itemId == product.itemId && !item.isKardus,
      );

      if (existingIndex >= 0) {
        final existingItem = _cartItems[existingIndex];
        if (existingItem.qty + qty <= product.stock) {
          setState(() {
            existingItem.qty += qty;
          });
        } else {
          _showNotification(
            'Jumlah pesanan sudah mencapai batas stok tersedia!',
            backgroundColor: AppColors.warning,
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
              qrcodes: [],
              wrapperQrcodes: [],
            ),
          );
        });
      }
    }

    _onCartChanged();

    _showNotification('${product.name} berhasil ditambahkan');
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
    // Jaminan ketat: item Satuan ber-QR hanya boleh dijual sebanyak QR yang berhasil di-scan
    // Item Kardus tidak dipotong menjadi activeCodes.length karena 1 wrapper QR mewakili seluruh isi kemasan/kardus
    for (final item in _cartItems) {
      if (!item.isKardus && item.activeCodes.isNotEmpty && item.qty > item.activeCodes.length) {
        item.qty = item.activeCodes.length;
      }
    }

    final grandTotal = _calculateGrandTotal();

    if (_cartItems.isEmpty) {
      _showNotification(
        'Keranjang belanja masih kosong! Silakan pilih produk atau scan QR stok.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    if (_selectedBranchId == null || _selectedWarehouseId == null) {
      _showNotification(
        'Silakan pilih Cabang dan Gudang terlebih dahulu!',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    if (_selectedPaymentMethodId <= 0) {
      _showNotification(
        'Silakan pilih metode pembayaran terlebih dahulu!',
        backgroundColor: AppColors.warning,
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
      'cash': grandTotal,
      'change': 0.0,
      if (_selectedPromo != null) 'promo_id': _selectedPromo!.id,
      'items': itemsPayload,
      'details': itemsPayload,
    };

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
                  qrcode: item.isKardus ? null : (item.qrcode.isNotEmpty ? item.qrcode : null),
                  wrapperQrcode: item.isKardus
                      ? (item.wrapperQrcodes.isNotEmpty
                          ? item.wrapperQrcodes.join(', ')
                          : item.product.wrapperQrcode)
                      : null,
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
      if (invoice.discount == 0 && promoUsed != null) {
        invoice = invoice.copyWith(discount: _calculateDiscount());
      }
      if (invoice.subTotal == 0) {
        invoice = invoice.copyWith(subTotal: _calculateSubTotal());
      }
      if (invoice.grandTotal == 0) {
        invoice = invoice.copyWith(grandTotal: grandTotal);
      }
      if (invoice.cash == 0) {
        invoice = invoice.copyWith(cash: grandTotal);
      }
      if (invoice.change == 0) {
        invoice = invoice.copyWith(change: 0.0);
      }

      setState(() {
        _cartItems.clear();
        _selectedPromo = null;
      });

      // Tampilkan struk nota dialog dengan opsi cetak ke printer Bluetooth
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ReceiptDialog(invoice: invoice),
      );
    } else {
      _showNotification(
        res.message.isNotEmpty
            ? res.message
            : 'Gagal memproses transaksi kasir.',
        backgroundColor: AppColors.error,
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
          if (_cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Kosongkan Keranjang',
              onPressed: _clearCart,
            ),
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
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.md,
                        AppSizes.md,
                        AppSizes.md,
                        8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Tombol Aksi Kasir: Scan QR Barang & Input Manual Kode & Katalog
                          _buildActionButtons(totalItemsCount),
                          const SizedBox(height: 10),

                          // 2. Section Daftar Barang Keranjang
                          _buildCartSection(),
                          const SizedBox(height: 12),

                          // 3. Section Pilihan Metode Pembayaran
                          _buildPaymentMethodSection(),
                          const SizedBox(height: 12),

                          // 4. Section Promo Diskon
                          if (_promos.isNotEmpty) ...[
                            _buildPromoSection(),
                            const SizedBox(height: 12),
                          ],

                          // 5. Section Ringkasan Perhitungan & Pembayaran
                          _buildFinancialSummarySection(),
                          const SizedBox(height: 16),
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
              separatorBuilder: (_, __) => const Divider(height: 1),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Row: Product Name (Full Width) + Delete Button
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
                    _cartItems.removeAt(index);
                  });
                  _onCartChanged();
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

          // 2. Badge Row: QR Kardus / Satuan / Pasangkan QR
          if (item.activeCodes.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...item.activeCodes.map((qr) {
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
                                _cartItems.removeAt(index);
                              } else {
                                if (!item.isKardus) {
                                  item.qty = item.activeCodes.length;
                                } else {
                                  final capacityPerKardus = item.product.qrStock.toInt() > 0 ? item.product.qrStock.toInt() : 1;
                                  item.qty = item.wrapperQrcodes.length * capacityPerKardus;
                                }
                              }
                            });
                            _onCartChanged();
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
                }),
                if (!item.isKardus && item.qty > item.qrcodes.length)
                  InkWell(
                    onTap: () => _incrementItem(index),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 13,
                            color: Colors.amber.shade900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+ Scan QR (${item.qrcodes.length}/${item.qty})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: () => _incrementItem(index),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 13,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+ Pasangkan QR Stok',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),

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
                              _cartItems.removeAt(index);
                            }
                          });
                          _onCartChanged();
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
                          child: Icon(
                            Icons.add,
                            size: 17,
                            color: item.qty >= item.product.stock
                                ? Colors.grey.shade300
                                : AppColors.primary,
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
                    : (pm.name.toLowerCase().contains('transfer') ||
                            pm.name.toLowerCase().contains('bank')
                        ? Icons.account_balance_rounded
                        : Icons.credit_card_rounded),
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

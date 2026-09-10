import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/pos_models.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/currency_formatter.dart';
import 'widgets/camera_scanner_page.dart';
import 'widgets/scan_qr_dialog.dart';
import 'widgets/stock_qty_confirm_dialog.dart';

class PosProductCatalogPage extends StatefulWidget {
  final int? branchId;
  final int? warehouseId;
  final List<CartItemModel> cartItems;
  final VoidCallback onCartUpdated;

  const PosProductCatalogPage({
    super.key,
    required this.branchId,
    required this.warehouseId,
    required this.cartItems,
    required this.onCartUpdated,
  });

  @override
  State<PosProductCatalogPage> createState() => _PosProductCatalogPageState();
}

class _PosProductCatalogPageState extends State<PosProductCatalogPage> {
  bool _isLoading = false;
  List<ProductModel> _products = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({String? search}) async {
    setState(() => _isLoading = true);

    final res = await ApiService.getProducts(
      warehouseId: widget.warehouseId,
      branchId: widget.branchId,
      search: search,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.isSuccess && res.data != null) {
      setState(() {
        _products = res.data!;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message.isNotEmpty ? res.message : 'Gagal memuat produk',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  int _getQtyInCart(int productId) {
    final idx = widget.cartItems.indexWhere((c) => c.product.id == productId);
    return idx >= 0 ? widget.cartItems[idx].qty : 0;
  }

  void _addToCart(ProductModel product, {String qrcode = '', int qty = 1}) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stok produk sedang kosong!'),
          backgroundColor: AppColors.warning,
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    if (qrcode.isNotEmpty) {
      final isDuplicate = widget.cartItems.any((item) => item.qrcode == qrcode);
      if (isDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR Code stok "$qrcode" sudah ada di dalam keranjang!',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      setState(() {
        widget.cartItems.add(
          CartItemModel(
            product: product,
            qty: qty,
            price: product.price,
            qrcode: qrcode,
          ),
        );
      });
      widget.onCartUpdated();
    } else {
      final existingIndex = widget.cartItems.indexWhere(
        (item) => item.product.itemId == product.itemId && item.qrcode.isEmpty,
      );

      if (existingIndex >= 0) {
        if (widget.cartItems[existingIndex].qty + qty <= product.stock) {
          setState(() {
            widget.cartItems[existingIndex].qty += qty;
          });
          widget.onCartUpdated();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jumlah pesanan mencapai batas stok tersedia!'),
              backgroundColor: AppColors.warning,
              duration: Duration(milliseconds: 1200),
            ),
          );
          return;
        }
      } else {
        setState(() {
          widget.cartItems.add(
            CartItemModel(
              product: product,
              qty: qty,
              price: product.price,
              qrcode: '',
            ),
          );
        });
        widget.onCartUpdated();
      }
    }

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

  void _removeFromCart(ProductModel product) {
    final existingIndex = widget.cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      setState(() {
        if (widget.cartItems[existingIndex].qty > 1) {
          widget.cartItems[existingIndex].qty--;
        } else {
          widget.cartItems.removeAt(existingIndex);
        }
      });
      widget.onCartUpdated();
    }
  }

  Future<void> _openDirectCameraScanner() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (ctx) => const CameraScannerPage()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mencari kode: $scannedCode...'),
          duration: const Duration(seconds: 1),
        ),
      );

      final res = await ApiService.scanQr(
        qrcode: scannedCode,
        warehouseId: widget.warehouseId,
        branchId: widget.branchId,
      );

      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        final product = res.data!;
        int finalQty = 1;
        if (product.stock > 1) {
          final chosenQty = await StockQtyConfirmDialog.show(
            context,
            product: product,
            qrcode: scannedCode,
          );
          if (chosenQty == null) return;
          finalQty = chosenQty;
        }
        _addToCart(product, qrcode: scannedCode, qty: finalQty);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.message.isNotEmpty
                  ? res.message
                  : 'Produk "$scannedCode" tidak ditemukan.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ignore: unused_element
  void _openScanQrDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ScanQrDialog(
        warehouseId: widget.warehouseId,
        branchId: widget.branchId,
        onProductFound: (product, qrcode, qty) {
          _addToCart(product, qrcode: qrcode, qty: qty);
        },
      ),
    );
  }

  int get _totalCartCount =>
      widget.cartItems.fold(0, (sum, item) => sum + item.qty);

  double get _totalCartPrice =>
      widget.cartItems.fold(0.0, (sum, item) => sum + item.subTotal);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Produk POS'),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.camera_alt_rounded),
          //   tooltip: 'Kamera Scanner Barcode',
          //   onPressed: _openDirectCameraScanner,
          // ),
          // IconButton(
          //   icon: const Icon(Icons.qr_code_scanner_rounded),
          //   tooltip: 'Input / Scan Kode',
          //   onPressed: _openScanQrDialog,
          // ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang',
            onPressed: () =>
                _loadProducts(search: _searchController.text.trim()),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama produk / kode / barcode...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _loadProducts();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (val) => _loadProducts(search: val.trim()),
              ),
            ),

            // Products List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () =>
                          _loadProducts(search: _searchController.text.trim()),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.md,
                          0,
                          AppSizes.md,
                          AppSizes.md,
                        ),
                        itemCount: _products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          final qtyInCart = _getQtyInCart(product.id);
                          return _buildProductCard(product, qtyInCart);
                        },
                      ),
                    ),
            ),

            // Sticky Bottom Cart Bar
            if (widget.cartItems.isNotEmpty) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            AppSizes.gapH16,
            const Text('Tidak ada produk ditemukan', style: AppTextStyles.h3),
            AppSizes.gapH8,
            const Text(
              'Pastikan filter pencarian sesuai atau produk sudah tersedia di gudang yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            AppSizes.gapH16,
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _loadProducts();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset Pencarian'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product, int qtyInCart) {
    final isOutOfStock = product.stock <= 0;

    return Card(
      elevation: qtyInCart > 0 ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        side: BorderSide(
          color: qtyInCart > 0 ? AppColors.primary : Colors.grey.shade200,
          width: qtyInCart > 0 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product Icon Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: qtyInCart > 0
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: qtyInCart > 0 ? AppColors.primary : Colors.grey.shade600,
                size: 28,
              ),
            ),
            AppSizes.gapW12,

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSizes.gapH4,
                  Row(
                    children: [
                      // Stock Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOutOfStock
                              ? 'Stok Habis'
                              : 'Stok: ${product.stock.toInt()} ${product.unit ?? "pcs"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOutOfStock
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ),
                      ),
                      if (product.barcode != null &&
                          product.barcode!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            product.barcode!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  AppSizes.gapH6,
                  Text(
                    CurrencyFormatter.format(product.price),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            AppSizes.gapW8,

            // Qty Action Controls
            if (qtyInCart > 0)
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
                      icon: const Icon(Icons.remove, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () => _removeFromCart(product),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$qtyInCart',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: isOutOfStock || qtyInCart >= product.stock
                          ? null
                          : () => _addToCart(product),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
                onPressed: isOutOfStock ? null : () => _addToCart(product),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: const Text('Tambah'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
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
            // Cart Summary
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_totalCartCount Produk Terpilih',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(_totalCartPrice),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            AppSizes.gapW16,

            // Selesai & Bayar Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text(
                'Selesai & Bayar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

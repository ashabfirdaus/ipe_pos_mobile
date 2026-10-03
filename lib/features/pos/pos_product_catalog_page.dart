import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/pos_models.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/currency_formatter.dart';
import 'widgets/camera_scanner_page.dart';

/// Halaman Katalog Produk POS (Hanya Menampilkan Informasi Barang & Stok)
/// Tanpa aksi penambahan ke keranjang belanja
class PosProductCatalogPage extends StatefulWidget {
  final int? branchId;
  final int? warehouseId;
  final List<CartItemModel>? cartItems;
  final VoidCallback? onCartUpdated;

  const PosProductCatalogPage({
    super.key,
    required this.branchId,
    required this.warehouseId,
    this.cartItems,
    this.onCartUpdated,
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

  Future<void> _loadProducts({String? search}) async {
    final query = search?.trim();
    if (query != null && query.isNotEmpty && query.length < 3) {
      _showNotification(
        'Minimal input pencarian adalah 3 karakter.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await ApiService.getProducts(
      warehouseId: widget.warehouseId,
      branchId: widget.branchId,
      search: query,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.isSuccess && res.data != null) {
      setState(() {
        _products = res.data!;
      });
    } else {
      _showNotification(
        res.message.isNotEmpty ? res.message : 'Gagal memuat produk',
        backgroundColor: AppColors.error,
      );
    }
  }

  /// Scan barcode / QR untuk mencari produk di dalam katalog
  Future<void> _scanToSearch() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (ctx) => const CameraScannerPage()),
    );

    if (scannedCode == null || scannedCode.trim().isEmpty) return;

    final cleanCode = scannedCode.trim();
    _searchController.text = cleanCode;
    _loadProducts(search: cleanCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Produk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan untuk Mencari',
            onPressed: _scanToSearch,
          ),
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

            // Indikator Jumlah Produk Ditemukan
            if (!_isLoading && _products.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, AppSizes.md, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Menampilkan ${_products.length} produk di katalog',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return _buildProductCard(product);
                        },
                      ),
                    ),
            ),
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

  Widget _buildProductCard(ProductModel product) {
    final isOutOfStock = product.stock <= 0;
    final unitName = product.unit?.isNotEmpty == true ? product.unit! : 'Pcs';

    return InkWell(
      onTap: () => _showProductDetailModal(context, product),
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          side: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product Icon / Image Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: (product.imagePath != null && product.imagePath!.isNotEmpty)
                      ? Image.network(
                          product.imagePath!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.grey.shade600,
                            size: 28,
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        )
                      : Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.grey.shade600,
                          size: 28,
                        ),
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
                        color: AppColors.textPrimary,
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
                                : 'Stok: ${product.stock.toInt()} $unitName',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOutOfStock
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                          ),
                        ),
                        if (product.code != null && product.code!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              product.code!,
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

              // Info Arrow
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menampilkan detail lengkap produk saat kartu ditekan
  void _showProductDetailModal(BuildContext context, ProductModel product) {
    final isOutOfStock = product.stock <= 0;
    final unitName = product.unit?.isNotEmpty == true ? product.unit! : 'Pcs';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Nama Produk
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Harga
                Text(
                  CurrencyFormatter.format(product.price),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Baris Info Detail
                _buildDetailRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Sisa Stok',
                  value: isOutOfStock
                      ? 'Stok Habis'
                      : '${product.stock.toInt()} $unitName',
                  valueColor: isOutOfStock ? AppColors.error : AppColors.success,
                ),
                if (product.code != null && product.code!.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.tag_rounded,
                    label: 'Kode / SKU',
                    value: product.code!,
                  ),
                if (product.barcode != null && product.barcode!.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.qr_code_2_rounded,
                    label: 'Barcode',
                    value: product.barcode!,
                  ),
                if (product.categoryName != null && product.categoryName!.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.category_outlined,
                    label: 'Kategori',
                    value: product.categoryName!,
                  ),
                _buildDetailRow(
                  icon: Icons.straighten_rounded,
                  label: 'Satuan',
                  value: unitName,
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

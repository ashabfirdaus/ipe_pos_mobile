import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/pos_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/currency_formatter.dart';
import 'widgets/cart_sheet.dart';
import 'widgets/scan_qr_dialog.dart';
import 'widgets/camera_scanner_page.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  bool _isLoadingInitial = true;
  bool _isLoadingProducts = false;

  List<BranchModel> _branches = [];
  List<WarehouseModel> _warehouses = [];
  List<PaymentMethodModel> _paymentMethods = [];
  List<PromoModel> _promos = [];
  double _ppnRate = 0.0;

  int? _selectedBranchId;
  int? _selectedWarehouseId;

  List<ProductModel> _products = [];
  final List<CartItemModel> _cartItems = [];

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialMasterData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMasterData() async {
    setState(() {
      _isLoadingInitial = true;
    });

    final savedBranchId = StorageService.getSelectedBranch();
    final savedWarehouseId = StorageService.getSelectedWarehouse();

    // 1. Fetch initial pos data
    final initialRes = await ApiService.getPosInitialData(
      branchId: savedBranchId,
      warehouseId: savedWarehouseId,
    );

    // 2. Fetch branches
    final branchesRes = await ApiService.getBranches();

    // 3. Fetch warehouses
    final warehousesRes = await ApiService.getWarehouses(branchId: savedBranchId);

    if (!mounted) return;

    if (branchesRes.isSuccess && branchesRes.data != null && branchesRes.data!.isNotEmpty) {
      _branches = branchesRes.data!;
      _selectedBranchId = savedBranchId ?? _branches.first.id;
    }

    if (warehousesRes.isSuccess && warehousesRes.data != null && warehousesRes.data!.isNotEmpty) {
      _warehouses = warehousesRes.data!;
      _selectedWarehouseId = savedWarehouseId ?? _warehouses.first.id;
    }

    if (initialRes.isSuccess && initialRes.data != null) {
      final initData = initialRes.data!;
      _paymentMethods = initData.paymentMethods.isNotEmpty
          ? initData.paymentMethods
          : [PaymentMethodModel(id: 1, name: 'Tunai (Cash)')];
      _promos = initData.promos;
      _ppnRate = initData.ppnRate;

      if (_selectedBranchId == null && initData.defaultBranch != null) {
        _selectedBranchId = initData.defaultBranch!.id;
      }
      if (_selectedWarehouseId == null && initData.defaultWarehouse != null) {
        _selectedWarehouseId = initData.defaultWarehouse!.id;
      }
    }

    // Fallback defaults if list is empty from server
    if (_branches.isEmpty) {
      _branches = [BranchModel(id: 1, name: 'Cabang Utama')];
      _selectedBranchId = 1;
    }
    if (_warehouses.isEmpty) {
      _warehouses = [WarehouseModel(id: 1, name: 'Gudang Pusat', branchId: 1)];
      _selectedWarehouseId = 1;
    }
    if (_paymentMethods.isEmpty) {
      _paymentMethods = [
        PaymentMethodModel(id: 1, name: 'Tunai (Cash)'),
        PaymentMethodModel(id: 2, name: 'QRIS'),
        PaymentMethodModel(id: 3, name: 'Transfer Bank'),
      ];
    }

    setState(() {
      _isLoadingInitial = false;
    });

    if (_selectedWarehouseId != null) {
      _loadProducts();
    }
  }

  Future<void> _loadWarehousesForBranch(int branchId) async {
    final res = await ApiService.getWarehouses(branchId: branchId);
    if (!mounted) return;

    if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
      setState(() {
        _warehouses = res.data!;
        _selectedWarehouseId = _warehouses.first.id;
      });
      StorageService.saveSelectedWarehouse(_selectedWarehouseId!);
      _loadProducts();
    }
  }

  Future<void> _loadProducts({String? search}) async {
    if (_selectedWarehouseId == null) return;

    setState(() {
      _isLoadingProducts = true;
    });

    final res = await ApiService.getProducts(
      warehouseId: _selectedWarehouseId!,
      branchId: _selectedBranchId,
      search: search,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingProducts = false;
    });

    if (res.isSuccess && res.data != null) {
      setState(() {
        _products = res.data!;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppColors.error),
      );
    }
  }

  void _addToCart(ProductModel product, {String qrcode = ''}) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stok produk di gudang ini sedang kosong!'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      final existingIndex = _cartItems.indexWhere((item) => item.product.id == product.id);
      if (existingIndex >= 0) {
        if (_cartItems[existingIndex].qty < product.stock) {
          _cartItems[existingIndex].qty++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jumlah pesanan sudah mencapai batas stok tersedia!'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      } else {
        _cartItems.add(CartItemModel(
          product: product,
          qty: 1,
          price: product.price,
          qrcode: qrcode,
        ));
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} ditambahkan ke keranjang'),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openScanQrDialog() {
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih gudang terlebih dahulu!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => ScanQrDialog(
        warehouseId: _selectedWarehouseId!,
        branchId: _selectedBranchId,
        onProductFound: (product, qrcode) {
          _addToCart(product, qrcode: qrcode);
        },
      ),
    );
  }

  Future<void> _openDirectCameraScanner() async {
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih gudang terlebih dahulu!')),
      );
      return;
    }

    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => const CameraScannerPage(),
      ),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Memindai kode: $scannedCode...'),
          duration: const Duration(seconds: 1),
        ),
      );

      final res = await ApiService.scanQr(
        qrcode: scannedCode,
        warehouseId: _selectedWarehouseId!,
        branchId: _selectedBranchId,
      );

      if (!mounted) return;

      if (res.isSuccess && res.data != null) {
        _addToCart(res.data!, qrcode: scannedCode);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : 'Produk dengan kode "$scannedCode" tidak ditemukan di gudang ini.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CartSheet(
        cartItems: _cartItems,
        branchId: _selectedBranchId ?? 1,
        warehouseId: _selectedWarehouseId ?? 1,
        paymentMethods: _paymentMethods,
        promos: _promos,
        ppnRate: _ppnRate,
        onCartUpdated: () => setState(() {}),
        onCartCleared: () => setState(() => _cartItems.clear()),
      ),
    );
  }

  double _getCartTotal() {
    return _cartItems.fold(0.0, (sum, item) => sum + item.subTotal);
  }

  int _getCartCount() {
    return _cartItems.fold(0, (sum, item) => sum + item.qty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir POS (Point of Sale)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_rounded),
            tooltip: 'Kamera Scanner',
            onPressed: _openDirectCameraScanner,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan / Input Kode',
            onPressed: _openScanQrDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang',
            onPressed: () => _loadProducts(search: _searchController.text.trim()),
          ),
        ],
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Branch & Warehouse Selector
                _buildBranchWarehouseBar(),

                // Search & Scan Bar
                _buildSearchBar(),

                // Products Grid List
                Expanded(
                  child: _isLoadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : _products.isEmpty
                          ? _buildEmptyState()
                          : _buildProductGrid(),
                ),

                // Floating Bottom Cart Bar
                if (_cartItems.isNotEmpty) _buildBottomCartBar(),
              ],
            ),
    );
  }

  Widget _buildBranchWarehouseBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Branch Dropdown
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedBranchId,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Cabang',
                prefixIcon: Icon(Icons.storefront_rounded, size: 18),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
              ),
              items: _branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedBranchId = val;
                  });
                  StorageService.saveSelectedBranch(val);
                  _loadWarehousesForBranch(val);
                }
              },
            ),
          ),
          AppSizes.gapW8,

          // Warehouse Dropdown
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedWarehouseId,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Gudang Stok',
                prefixIcon: Icon(Icons.warehouse_rounded, size: 18),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
              ),
              items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedWarehouseId = val;
                  });
                  StorageService.saveSelectedWarehouse(val);
                  _loadProducts(search: _searchController.text.trim());
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari produk / kode / barcode...',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (val) => _loadProducts(search: val.trim()),
            ),
          ),
          AppSizes.gapW8,
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            tooltip: 'Kamera Barcode Scanner',
            onPressed: _openDirectCameraScanner,
          ),
          AppSizes.gapW4,
          IconButton.filledTonal(
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            tooltip: 'Input / Dialog Scan',
            onPressed: _openScanQrDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    return RefreshIndicator(
      onRefresh: () => _loadProducts(search: _searchController.text.trim()),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: AppSizes.sm,
          mainAxisSpacing: AppSizes.sm,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          final hasStock = product.stock > 0;

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              onTap: () => _addToCart(product),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Icon / Category Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: hasStock ? AppColors.successContainer : AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            hasStock ? 'Stok: ${product.stock.toStringAsFixed(0)}' : 'Habis',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hasStock ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Product Details
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.code != null && product.code!.isNotEmpty)
                      Text(
                        product.code!,
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    AppSizes.gapH4,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            CurrencyFormatter.format(product.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: hasStock ? AppColors.primary : Colors.grey,
                          child: const Icon(Icons.add, size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
            const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary),
            AppSizes.gapH16,
            const Text(
              'Belum ada produk di gudang ini',
              style: AppTextStyles.h3,
            ),
            AppSizes.gapH8,
            const Text(
              'Pilih gudang lain atau cari dengan kata kunci berbeda.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            AppSizes.gapH16,
            ElevatedButton.icon(
              onPressed: () => _loadProducts(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Produk'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCartBar() {
    final total = _getCartTotal();
    final count = _getCartCount();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Badge(
              label: Text('$count'),
              child: const Icon(Icons.shopping_cart_rounded, color: AppColors.primary, size: 28),
            ),
            AppSizes.gapW16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total Pembayaran', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(
                    CurrencyFormatter.format(total),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _openCartSheet,
              child: const Row(
                children: [
                  Text('Bayar'),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
import 'widgets/offline_sync_dialog.dart';
import 'widgets/receipt_dialog.dart';
import 'widgets/scan_qr_dialog.dart';
import 'widgets/stock_qty_confirm_dialog.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/storage_service.dart';

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
  SpecialPriceConfigModel? _specialPriceConfig;

  final List<CartItemModel> _cartItems = [];
  late int _selectedPaymentMethodId;
  PromoModel? _selectedPromo;

  final _scannerInputController = TextEditingController();
  final _scannerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethodId = 1;
    _loadInitialMasterData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scannerFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scannerInputController.dispose();
    _scannerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMasterData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoadingInitial = true);
    }

    final initialRes = await ApiService.getPosInitialData(
      branchId: _selectedBranchId,
      warehouseId: _selectedWarehouseId,
    );

    if (!mounted) return;

    if (initialRes.isSuccess && initialRes.data != null) {
      // Trigger background sync for pending offline transactions if online
      OfflineSyncService.instance.syncPendingTransactions();

      final initData = initialRes.data!;
      _defaultBranch = initData.defaultBranch;
      _defaultWarehouse = initData.defaultWarehouse;
      _selectedBranchId = initData.defaultBranch?.id;
      _selectedWarehouseId = initData.defaultWarehouse?.id;

      // Pre-fetch dan sinkronkan katalog produk ke cache offline perangkat
      OfflineSyncService.instance.syncProductsCatalog(
        branchId: _selectedBranchId,
        warehouseId: _selectedWarehouseId,
      );

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
      _specialPriceConfig = initData.specialPriceConfig;
    } else {
      _paymentMethods = [
        PaymentMethodModel(id: 2, name: 'QRIS'),
        PaymentMethodModel(id: 3, name: 'Transfer Bank'),
      ];
      _selectedPaymentMethodId = 2;
    }

    if (mounted) {
      setState(() => _isLoadingInitial = false);
    }
  }

  /// Memperbarui sisa kuota harga khusus secara real-time dari server
  Future<void> _refreshSpecialPriceConfig() async {
    try {
      final initialRes = await ApiService.getPosInitialData(
        branchId: _selectedBranchId,
        warehouseId: _selectedWarehouseId,
      );
      if (initialRes.isSuccess &&
          initialRes.data?.specialPriceConfig != null &&
          mounted) {
        setState(() {
          _specialPriceConfig = initialRes.data!.specialPriceConfig;
        });
      }
    } catch (_) {}
  }

  bool get _isSpecialPriceActive {
    if (_specialPriceConfig == null || !_specialPriceConfig!.enabled) {
      return false;
    }
    final now = DateTime.now();
    try {
      final startParts = _specialPriceConfig!.startTime.split(':');
      final startHour = int.parse(startParts[0]);
      final startMinute = startParts.length > 1 ? int.parse(startParts[1]) : 0;
      if (now.hour < startHour ||
          (now.hour == startHour && now.minute < startMinute)) {
        return false;
      }

      final endParts = _specialPriceConfig!.endTime.split(':');
      final endHour = int.parse(endParts[0]);
      final endMinute = endParts.length > 1 ? int.parse(endParts[1]) : 59;
      if (now.hour > endHour ||
          (now.hour == endHour && now.minute > endMinute)) {
        return false;
      }
    } catch (_) {
      if (now.hour < 18) return false;
    }
    return true;
  }

  int get _usedSpecialQuotaInCart {
    return _cartItems
        .where((item) => item.isSpecialPrice)
        .fold(0, (sum, item) => sum + item.qty);
  }

  int get _availableSpecialQuota {
    if (_specialPriceConfig == null) return 0;
    final baseRemaining = _specialPriceConfig!.remainingQuotaToday;
    return (baseRemaining - _usedSpecialQuotaInCart)
        .clamp(0, _specialPriceConfig!.dailyQuota);
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

  /// Memproses kode hasil scan barcode/QR (berlaku untuk kamera maupun perangkat scanner)
  Future<void> _handleScannedCode(String rawCode) async {
    final cleanCode = rawCode.trim();
    if (cleanCode.isEmpty || cleanCode.toLowerCase() == 'null') {
      return;
    }

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
      final actualQrCode =
          product.qrcode?.isNotEmpty == true ? product.qrcode! : cleanCode;

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
      if (product.qrStock > 1) {
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

  Future<void> _openDirectCameraScanner() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (ctx) => const CameraScannerPage()),
    );

    if (scannedCode != null) {
      await _handleScannedCode(scannedCode);
    }
  }

  Future<void> _handleScannerFieldSubmitted(String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return;
    _scannerInputController.clear();
    await _handleScannedCode(clean);
    // Kembalikan fokus kursor ke input scanner agar kasir dapat langsung scan barang berikutnya
    if (mounted) {
      _scannerFocusNode.requestFocus();
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

    // Jika item harga khusus dan kuota sudah habis, alihkan ke harga normal
    if (item.isSpecialPrice && _availableSpecialQuota <= 0) {
      _showNotification(
        'Batas kuota harga khusus hari ini telah tercapai (${_specialPriceConfig?.dailyQuota ?? 140} pcs). Item dialihkan ke harga normal.',
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 3),
      );
      if (!item.activeCodes.isNotEmpty && !item.isKardus) {
        _addToCart(item.product, qty: 1, forceNormalPrice: true);
        return;
      }
    }

    // Jika barang menggunakan QR fisik (Satuan ber-QR atau Kardus)
    if (item.activeCodes.isNotEmpty || item.isKardus) {
      if (item.qty >= item.product.stock) {
        _showNotification(
          'Batas stok tercapai: maks ${item.product.stock.toInt()} item',
          duration: const Duration(milliseconds: 1200),
        );
        return;
      }

      // Jika produk Satuan dan QR yang aktif memiliki sisa stok yang cukup,
      // kasir bisa langsung menambah Qty dari QR yang sama tanpa perlu scan kamera ulang.
      if (!item.isKardus && item.activeCodes.toSet().length == 1) {
        final currentQr = item.activeCodes.first;
        final currentQrCount =
            item.qrcodes.where((c) => c == currentQr).length;
        final maxStockForQr =
            item.product.qrStock > 0 ? item.product.qrStock.toInt() : 1;
        if (currentQrCount < maxStockForQr) {
          setState(() {
            item.qrcodes.add(currentQr);
            item.qty++;
            if (item.qty > item.product.stock) {
              item.product.stock = item.qty.toDouble();
            }
          });
          _onCartChanged();
          _showNotification(
            '${item.product.name} (QR: $currentQr) ditambah (Qty: ${item.qty})',
          );
          return;
        }
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

      // Cek apakah QR sudah ada di dalam keranjang baris lain
      final isDuplicateOtherRow = _cartItems.asMap().entries.any(
            (entry) =>
                entry.key != index &&
                entry.value.activeCodes.contains(cleanCode),
          );
      if (isDuplicateOtherRow) {
        _showNotification(
          'QR Code stok "$cleanCode" sudah ada di baris keranjang lain!',
          backgroundColor: AppColors.warning,
        );
        return;
      }

      // Jika scan QR yang sama pada baris ini tapi stok QR sudah maksimal
      if (!item.isKardus && item.activeCodes.contains(cleanCode)) {
        final maxStock =
            item.product.qrStock > 0 ? item.product.qrStock.toInt() : 1;
        final currentCount =
            item.qrcodes.where((c) => c == cleanCode).length;
        if (currentCount >= maxStock) {
          _showNotification(
            'Batas stok pada QR "$cleanCode" sudah maksimal ($maxStock item)!',
            backgroundColor: AppColors.warning,
          );
          return;
        }
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
        final actualQrCode =
            product.qrcode?.isNotEmpty == true ? product.qrcode! : cleanCode;

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

        // Jika item ini adalah baris harga khusus tapi kuota habis, masukkan QR ke baris harga normal
        if (item.isSpecialPrice && _availableSpecialQuota <= 0) {
          _showNotification(
            'Batas kuota harga khusus hari ini telah tercapai (${_specialPriceConfig?.dailyQuota ?? 140} pcs). Item dialihkan ke harga normal.',
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          );
          _addToCart(product,
              qrcode: actualQrCode, qty: 1, forceNormalPrice: true);
          return;
        }

        setState(() {
          if (item.isKardus) {
            if (!item.activeCodes.contains(actualQrCode)) {
              item.activeCodes.add(actualQrCode);
              item.wrapperQrcodes.add(actualQrCode);
            }
            final addQty =
                product.qrStock.toInt() > 0 ? product.qrStock.toInt() : 1;
            item.qty += addQty;
          } else {
            item.qrcodes.add(actualQrCode);
            item.qty = item.qrcodes.length;
          }
          if (item.qty > item.product.stock) {
            item.product.stock = item.qty.toDouble();
          }
        });
        _onCartChanged();

        _showNotification(
          '${item.product.name} (QR: $actualQrCode) berhasil ditambahkan',
        );
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
      if (item.isSpecialPrice && _availableSpecialQuota <= 0) {
        _showNotification(
          'Batas kuota harga khusus hari ini telah tercapai (${_specialPriceConfig?.dailyQuota ?? 140} pcs). Qty tambahan menggunakan harga normal.',
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
        );
        _addToCart(item.product, qty: 1, forceNormalPrice: true);
        return;
      }

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

  void _addToCart(
    ProductModel product, {
    String qrcode = '',
    int qty = 1,
    bool forceNormalPrice = false,
  }) {
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

    final bool canUsePromo =
        !forceNormalPrice && product.hasSpecialPrice && _isSpecialPriceActive;

    if (canUsePromo) {
      final availableQuota = _availableSpecialQuota;
      if (availableQuota <= 0) {
        _showNotification(
          'Kuota promo sore hari ini (${_specialPriceConfig?.dailyQuota ?? 140} pcs) telah habis. Menggunakan harga normal master.',
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
        );
        _insertToCartItem(product,
            qrcode: effectiveQrcode, qty: qty, isSpecialPrice: false);
      } else if (availableQuota >= qty) {
        _insertToCartItem(product,
            qrcode: effectiveQrcode, qty: qty, isSpecialPrice: true);
      } else {
        // Kasus SPLIT LINE ITEMS: Kuota tersisa < Qty pembelian!
        final promoQty = availableQuota;
        final normalQty = qty - promoQty;
        _insertToCartItem(product,
            qrcode: effectiveQrcode, qty: promoQty, isSpecialPrice: true);
        _insertToCartItem(product,
            qrcode: '', qty: normalQty, isSpecialPrice: false);
        _showNotification(
          'Pecah baris harga: $promoQty pcs Harga Khusus (${CurrencyFormatter.format(product.specialPrice!)}) & $normalQty pcs Normal (${CurrencyFormatter.format(product.price)})',
          duration: const Duration(seconds: 4),
        );
      }
    } else {
      _insertToCartItem(product,
          qrcode: effectiveQrcode, qty: qty, isSpecialPrice: false);
    }

    _onCartChanged();
    _showNotification('${product.name} berhasil ditambahkan');
  }

  void _insertToCartItem(
    ProductModel product, {
    String qrcode = '',
    int qty = 1,
    required bool isSpecialPrice,
  }) {
    final double itemPrice =
        isSpecialPrice ? product.specialPrice! : product.price;

    // 1. Jika ditambahkan dengan QR Code stok fisik
    if (qrcode.isNotEmpty) {
      final isQrDuplicate = _cartItems.any(
        (item) => item.activeCodes.contains(qrcode),
      );
      if (isQrDuplicate) {
        _showNotification(
          'QR Code stok "$qrcode" sudah ada di dalam keranjang!',
          backgroundColor: AppColors.warning,
        );
        return;
      }

      // Cek apakah produk dengan tipe yang SAMA (Kardus vs Satuan) dan harga yang sama (isSpecialPrice) sudah ada
      final existingIndex = _cartItems.indexWhere(
        (item) =>
            item.product.itemId == product.itemId &&
            item.isKardus == product.isKardus &&
            item.isSpecialPrice == isSpecialPrice,
      );

      if (existingIndex >= 0) {
        final existingItem = _cartItems[existingIndex];
        setState(() {
          if (product.isKardus) {
            if (!existingItem.wrapperQrcodes.contains(qrcode)) {
              existingItem.wrapperQrcodes.add(qrcode);
            }
          } else {
            existingItem.qrcodes.addAll(List.filled(qty, qrcode));
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
              price: itemPrice,
              isSpecialPrice: isSpecialPrice,
              qrcodes: product.isKardus ? [] : List.filled(qty, qrcode),
              wrapperQrcodes: product.isKardus ? [qrcode] : [],
            ),
          );
        });
      }
    } else {
      // 2. Jika ditambahkan manual dari katalog
      final existingIndex = _cartItems.indexWhere(
        (item) =>
            item.product.itemId == product.itemId &&
            !item.isKardus &&
            item.isSpecialPrice == isSpecialPrice,
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
              price: itemPrice,
              isSpecialPrice: isSpecialPrice,
              qrcodes: [],
              wrapperQrcodes: [],
            ),
          );
        });
      }
    }
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

  Future<bool> _showBackConfirmationDialog() async {
    final totalItemsCount = _cartItems.fold(0, (sum, item) => sum + item.qty);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tinggalkan Kasir?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terdapat $totalItemsCount barang (${_cartItems.length} jenis item) di dalam keranjang kasir.',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jika Anda kembali ke halaman utama, daftar barang yang sudah di-scan/dimasukkan ke keranjang ini akan hilang. Yakin ingin keluar?',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal / Tetap di Kasir'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    return result ?? false;
  }


  Future<bool> _showPaymentConfirmationDialog({
    required double grandTotal,
    required double subTotal,
    required double discount,
    required double ppn,
    required int totalQty,
    required String paymentMethodName,
  }) async {
    final specialPriceItemsCount = _cartItems
        .where((item) => item.isSpecialPrice)
        .fold(0, (sum, item) => sum + item.qty);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konfirmasi Pembayaran',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Periksa kembali rincian transaksi',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kartu Ringkasan Pembayaran
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildConfirmRow(
                      'Metode Pembayaran',
                      paymentMethodName,
                      isBadge: true,
                    ),
                    const SizedBox(height: 8),
                    _buildConfirmRow(
                      'Total Barang',
                      '$totalQty pcs (${_cartItems.length} baris item)',
                    ),
                    const SizedBox(height: 8),
                    _buildConfirmRow(
                      'Sub Total',
                      CurrencyFormatter.format(subTotal),
                    ),
                    if (discount > 0) ...[
                      const SizedBox(height: 8),
                      _buildConfirmRow(
                        'Diskon Promo',
                        '- ${CurrencyFormatter.format(discount)}',
                        valueColor: AppColors.success,
                        isBold: true,
                      ),
                    ],
                    if (ppn > 0) ...[
                      const SizedBox(height: 8),
                      _buildConfirmRow(
                        'PPN ($_ppnRate%)',
                        '+ ${CurrencyFormatter.format(ppn)}',
                      ),
                    ],
                    if (specialPriceItemsCount > 0) ...[
                      const SizedBox(height: 8),
                      _buildConfirmRow(
                        'Promo Sore Terpakai',
                        '$specialPriceItemsCount pcs Harga Khusus',
                        valueColor: Colors.green.shade800,
                        isBold: true,
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Total Pembayaran',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
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
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pastikan pembayaran/bukti transfer pelanggan telah diterima sebelum menyelesaikan transaksi.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade900,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Periksa Kembali'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text(
              'Selesaikan Bayar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildConfirmRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    bool isBadge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
      ],
    );
  }

  Future<void> _handleCheckout() async {
    // 1. Validasi keranjang belanja
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

    // Jaminan ketat: item Satuan ber-QR hanya boleh dijual sebanyak QR yang berhasil di-scan
    // Item Kardus tidak dipotong menjadi activeCodes.length karena 1 wrapper QR mewakili seluruh isi kemasan/kardus
    for (final item in _cartItems) {
      if (!item.isKardus &&
          item.activeCodes.isNotEmpty &&
          item.qty > item.activeCodes.length) {
        item.qty = item.activeCodes.length;
      }
    }

    final grandTotal = _calculateGrandTotal();
    final subTotal = _calculateSubTotal();
    final discount = _calculateDiscount();
    final ppn = _calculatePpn();
    final totalQty = _cartItems.fold(0, (sum, item) => sum + item.qty);

    PaymentMethodModel? selectedMethod;
    try {
      selectedMethod = _paymentMethods.firstWhere(
        (pm) => pm.id == _selectedPaymentMethodId,
      );
    } catch (_) {
      selectedMethod = null;
    }
    final paymentMethodName = selectedMethod?.name ?? 'Pembayaran Non-Tunai';

    // 2. Tampilkan dialog validasi / konfirmasi sebelum menyelesaikan transaksi
    final isConfirmed = await _showPaymentConfirmationDialog(
      grandTotal: grandTotal,
      subTotal: subTotal,
      discount: discount,
      ppn: ppn,
      totalQty: totalQty,
      paymentMethodName: paymentMethodName,
    );

    if (!isConfirmed || !mounted) return;

    // 3. Eksekusi proses pembayaran ke API
    setState(() => _isProcessingCheckout = true);

    final itemsPayload =
        _cartItems.map((item) => item.toInvoiceItemJson()).toList();

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
                  qrcode: item.isKardus
                      ? null
                      : (item.qrcode.isNotEmpty ? item.qrcode : null),
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

      // Update sisa kuota harga khusus secara real-time dari respons server
      setState(() {
        if (invoice.specialPriceConfig != null) {
          _specialPriceConfig = invoice.specialPriceConfig;
        } else {
          final int soldSpecialQty = cartItemsBackup
              .where((it) => it.isSpecialPrice)
              .fold<int>(0, (sum, it) => sum + it.qty);
          if (soldSpecialQty > 0 && _specialPriceConfig != null) {
            final int newUsed =
                _specialPriceConfig!.usedQuotaToday + soldSpecialQty;
            final int newRemaining = (_specialPriceConfig!.dailyQuota - newUsed)
                .clamp(0, _specialPriceConfig!.dailyQuota)
                .toInt();
            _specialPriceConfig = SpecialPriceConfigModel(
              enabled: _specialPriceConfig!.enabled,
              isCurrentlyActive: _specialPriceConfig!.isCurrentlyActive,
              isTimeActive: _specialPriceConfig!.isTimeActive,
              isDayActive: _specialPriceConfig!.isDayActive,
              startTime: _specialPriceConfig!.startTime,
              endTime: _specialPriceConfig!.endTime,
              dailyQuota: _specialPriceConfig!.dailyQuota,
              scope: _specialPriceConfig!.scope,
              usedQuotaToday: newUsed,
              remainingQuotaToday: newRemaining,
              isQuotaAvailable: newRemaining > 0,
            );
          }
        }

        _cartItems.clear();
        _selectedPromo = null;
      });

      // Sinkronkan sisa kuota terbaru dari backend di background
      _refreshSpecialPriceConfig();

      // Tampilkan struk nota dialog dengan opsi cetak ke printer Bluetooth
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ReceiptDialog(invoice: invoice),
      );

      // Setelah dialog struk ditutup, otomatis muat ulang data master terkini
      if (mounted) {
        await _loadInitialMasterData(showLoading: false);
      }
    } else {
      final isConnectionIssue = res.statusCode == 503 ||
          res.statusCode == 408 ||
          res.statusCode == 502 ||
          res.statusCode == 504 ||
          res.statusCode == 0 ||
          res.message.toLowerCase().contains('tidak dapat terhubung') ||
          res.message.toLowerCase().contains('timeout') ||
          res.message.toLowerCase().contains('socketexception') ||
          res.message.toLowerCase().contains('network') ||
          res.message.toLowerCase().contains('offline');

      if (isConnectionIssue) {
        final confirmOffline = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Koneksi Terputus'),
              ],
            ),
            content: const Text(
              'Aplikasi tidak dapat terhubung ke server.\n\n'
              'Apakah Anda ingin menyimpan transaksi ini secara OFFLINE di perangkat dan langsung mencetak struk nota?\n\n'
              'Data akan tersimpan aman di antrean lokal dan dapat disinkronkan ke server saat jaringan kembali online.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Simpan Offline & Cetak'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        );

        if (confirmOffline == true && mounted) {
          final cashierName = await StorageService.getCashierName();
          final selectedPm = _paymentMethods
              .where((p) => p.id == _selectedPaymentMethodId)
              .firstOrNull;

          final offlineInvoice =
              await OfflineSyncService.instance.saveOfflineTransaction(
            payload: payload,
            cartItems: List<CartItemModel>.from(_cartItems),
            branchName: _defaultBranch?.name,
            warehouseName: _defaultWarehouse?.name,
            paymentMethodName: selectedPm?.name ?? 'Tunai',
            promoName: _selectedPromo?.name,
            cashierName: cashierName,
            discount: _calculateDiscount(),
            subTotal: _calculateSubTotal(),
            grandTotal: grandTotal,
            cash: grandTotal,
            change: 0.0,
          );

          setState(() {
            final int soldSpecialQty = _cartItems
                .where((it) => it.isSpecialPrice)
                .fold<int>(0, (sum, it) => sum + it.qty);
            if (soldSpecialQty > 0 && _specialPriceConfig != null) {
              final int newUsed =
                  _specialPriceConfig!.usedQuotaToday + soldSpecialQty;
              final int newRemaining = (_specialPriceConfig!.dailyQuota - newUsed)
                  .clamp(0, _specialPriceConfig!.dailyQuota)
                  .toInt();
              _specialPriceConfig = SpecialPriceConfigModel(
                enabled: _specialPriceConfig!.enabled,
                isCurrentlyActive: _specialPriceConfig!.isCurrentlyActive,
                isTimeActive: _specialPriceConfig!.isTimeActive,
                isDayActive: _specialPriceConfig!.isDayActive,
                startTime: _specialPriceConfig!.startTime,
                endTime: _specialPriceConfig!.endTime,
                dailyQuota: _specialPriceConfig!.dailyQuota,
                scope: _specialPriceConfig!.scope,
                usedQuotaToday: newUsed,
                remainingQuotaToday: newRemaining,
                isQuotaAvailable: newRemaining > 0,
              );
            }
            _cartItems.clear();
            _selectedPromo = null;
          });

          _showNotification(
            'Transaksi disimpan secara Offline (${offlineInvoice.invoiceNo}). Siap dicetak!',
            backgroundColor: AppColors.success,
          );

          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => ReceiptDialog(invoice: offlineInvoice),
            );
            if (mounted) {
              await _loadInitialMasterData(showLoading: false);
            }
          }
          return;
        }
      }

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

    return PopScope(
      canPop: _cartItems.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _showBackConfirmationDialog();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Kembali',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Kasir POS'),
        actions: [
          // Indikator & Tombol Antrean Transaksi Offline
          ValueListenableBuilder<int>(
            valueListenable: OfflineSyncService.instance.pendingCountNotifier,
            builder: (context, pendingCount, child) {
              if (pendingCount <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: IconButton(
                  icon: Badge(
                    label: Text('$pendingCount'),
                    backgroundColor: AppColors.warning,
                    textColor: Colors.black,
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: AppColors.warning,
                    ),
                  ),
                  tooltip: '$pendingCount Transaksi Offline Belum Disinkronkan',
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (ctx) => const OfflineSyncDialog(),
                    );
                    if (mounted) {
                      await _loadInitialMasterData(showLoading: false);
                    }
                  },
                ),
              );
            },
          ),
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
                  // Pinned Top Action Bar: Scan QR Barang & Input Kode Manual
                  _buildPinnedScanSection(),

                  // Scrollable POS Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.md,
                        2,
                        AppSizes.md,
                        8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 0. Banner Promo Harga Khusus Sore
                          _buildSpecialPricePromoBanner(),

                          // 1. Tombol Katalog Produk
                          _buildCatalogButton(totalItemsCount),
                          const SizedBox(height: 10),

                          // 2. Section Daftar Barang Keranjang
                          _buildCartSection(),
                          const SizedBox(height: 10),

                          // 3. Section Pilihan Metode Pembayaran
                          _buildPaymentMethodSection(),
                          const SizedBox(height: 10),

                          // 4. Section Promo Diskon
                          if (_promos.isNotEmpty) ...[
                            _buildPromoSection(),
                            const SizedBox(height: 10),
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
      ),
    );
  }

  Widget _buildPinnedScanSection() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          // Field input untuk perangkat scanner barcode / QR
          Expanded(
            child: TextField(
              controller: _scannerInputController,
              focusNode: _scannerFocusNode,
              textInputAction: TextInputAction.go,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Scan via perangkat scanner di sini...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                suffixIcon: _scannerInputController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _scannerInputController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onSubmitted: _handleScannerFieldSubmitted,
            ),
          ),
          const SizedBox(width: 8),
          // Tombol Scan Kamera
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              elevation: 1,
            ),
            onPressed: _openDirectCameraScanner,
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text(
              'Kamera',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          // Tombol Input Kode Manual / Cari
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE8EAF6),
              foregroundColor: const Color(0xFF1A237E),
              padding: const EdgeInsets.all(9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
            icon: const Icon(
              Icons.keyboard_alt_outlined,
              size: 20,
              color: Color(0xFF1A237E),
            ),
            tooltip: 'Input Kode Manual / Cari',
            onPressed: _openScanQrDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialPricePromoBanner() {
    if (_specialPriceConfig == null || !_specialPriceConfig!.enabled) {
      return const SizedBox.shrink();
    }

    final isTimeActive = _isSpecialPriceActive;
    final remaining = _availableSpecialQuota;
    final totalQuota = _specialPriceConfig!.dailyQuota;

    if (isTimeActive) {
      if (remaining > 0) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚡ Promo Sore Aktif • Sisa Kuota Khusus: $remaining / $totalQuota pcs',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Promo Sore: Kuota Hari Ini Habis ($totalQuota pcs). Diterapkan Harga Normal.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      final startTimeStr = _specialPriceConfig!.startTime.length >= 5
          ? _specialPriceConfig!.startTime.substring(0, 5)
          : _specialPriceConfig!.startTime;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded,
                color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Promo WeMeal Sore berlaku pk $startTimeStr WIB (Kuota: $totalQuota pcs gabungan)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCatalogButton(int totalItemsCount) {
    return SizedBox(
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
              'Katalog Produk',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            if (totalItemsCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
    );
  }

  Widget _buildCartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                AppSizes.gapW8,
                Text('Keranjang Belanja', style: AppTextStyles.h3),
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

          // Badge Khusus Harga Sore
          if (item.isSpecialPrice) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded,
                      size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Harga Khusus Sore: ${CurrencyFormatter.format(item.price)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. Badge Row: QR Kardus / Satuan / Pasangkan QR
          if (item.activeCodes.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...item.activeCodes.toSet().map((qr) {
                  final qrCount =
                      item.activeCodes.where((c) => c == qr).length;
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
                          item.isKardus
                              ? 'Kardus: $qr'
                              : (qrCount > 1
                                  ? 'Satuan: $qr ($qrCount pcs)'
                                  : 'Satuan: $qr'),
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
                              item.activeCodes.removeWhere((c) => c == qr);
                              if (item.isKardus) {
                                item.wrapperQrcodes.removeWhere((c) => c == qr);
                              } else {
                                item.qrcodes.removeWhere((c) => c == qr);
                              }
                              if (item.activeCodes.isEmpty) {
                                _cartItems.removeAt(index);
                              } else {
                                if (!item.isKardus) {
                                  item.qty = item.activeCodes.length;
                                } else {
                                  final capacityPerKardus =
                                      item.product.qrStock.toInt() > 0
                                          ? item.product.qrStock.toInt()
                                          : 1;
                                  item.qty = item.wrapperQrcodes.length *
                                      capacityPerKardus;
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
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(7),
                        ),
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
                            item.qty == 1
                                ? Icons.delete_outline_rounded
                                : Icons.remove,
                            size: item.qty == 1 ? 16 : 17,
                            color: item.qty == 1
                                ? Colors.red.shade400
                                : Colors.grey.shade800,
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
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(7),
                        ),
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
        const Row(
          children: [
            Icon(
              Icons.local_offer_outlined,
              color: AppColors.secondary,
              size: 20,
            ),
            AppSizes.gapW8,
            Text('Promo & Diskon', style: AppTextStyles.h3),
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
        const Row(
          children: [
            Icon(
              Icons.payment_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            AppSizes.gapW8,
            Text('Metode Pembayaran', style: AppTextStyles.h3),
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

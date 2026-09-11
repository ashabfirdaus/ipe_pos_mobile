import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/pos_models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/currency_formatter.dart';
import 'camera_scanner_page.dart';
import 'stock_qty_confirm_dialog.dart';

class ScanQrDialog extends StatefulWidget {
  final int? warehouseId;
  final int? branchId;
  final Function(ProductModel product, String qrcode, int qty) onProductFound;

  const ScanQrDialog({
    super.key,
    this.warehouseId,
    this.branchId,
    required this.onProductFound,
  });

  @override
  State<ScanQrDialog> createState() => _ScanQrDialogState();
}

class _ScanQrDialogState extends State<ScanQrDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  ProductModel? _scannedProduct;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openCameraScanner() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => const CameraScannerPage(),
      ),
    );

    if (scannedCode != null &&
        scannedCode.trim().isNotEmpty &&
        scannedCode.trim().toLowerCase() != 'null') {
      final cleanCode = scannedCode.trim();
      _codeController.text = cleanCode;
      _handleScan(cleanCode);
    }
  }

  Future<void> _handleScan(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

    if (cleanCode.length < 3) {
      setState(() {
        _errorMessage = 'Minimal input pencarian adalah 3 digit / karakter.';
        _scannedProduct = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _scannedProduct = null;
    });

    final res = await ApiService.scanQr(
      qrcode: cleanCode,
      warehouseId: widget.warehouseId,
      branchId: widget.branchId,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res.isSuccess && res.data != null) {
      setState(() {
        _scannedProduct = res.data;
      });
    } else {
      setState(() {
        _errorMessage = res.message.isNotEmpty
            ? res.message
            : 'Produk dengan kode "$cleanCode" tidak ditemukan.';
      });
    }
  }

  Future<void> _confirmAdd() async {
    if (_scannedProduct != null) {
      final code = _scannedProduct!.qrcode?.isNotEmpty == true
          ? _scannedProduct!.qrcode!
          : _codeController.text.trim();
      int finalQty = 1;
      if (_scannedProduct!.stock > 1) {
        final chosenQty = await StockQtyConfirmDialog.show(
          context,
          product: _scannedProduct!,
          qrcode: code,
        );
        if (chosenQty == null) return;
        finalQty = chosenQty;
      }
      widget.onProductFound(_scannedProduct!, code, finalQty);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppSizes.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                      AppSizes.gapW8,
                      Text('Scan / Cari Produk', style: AppTextStyles.h3),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              AppSizes.gapH12,

              // Input Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Kode Produk / Barcode / QR',
                        hintText: 'Misal: PRD-001 / Scan',
                        prefixIcon: Icon(Icons.barcode_reader),
                      ),
                      onSubmitted: _handleScan,
                    ),
                  ),
                  AppSizes.gapW8,
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                    tooltip: 'Buka Kamera Barcode',
                    onPressed: _openCameraScanner,
                  ),
                ],
              ),
              AppSizes.gapH12,

              // Search Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _handleScan(_codeController.text),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search_rounded),
                  label: const Text('Cari Item Produk'),
                ),
              ),
              AppSizes.gapH16,

              // Error State
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      AppSizes.gapW8,
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Product Result Card
              if (_scannedProduct != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                              ),
                              child: _scannedProduct!.imagePath != null &&
                                      _scannedProduct!.imagePath!.isNotEmpty
                                  ? Image.network(
                                      _scannedProduct!.imagePath!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                                    )
                                  : const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                            ),
                          ),
                          AppSizes.gapW12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _scannedProduct!.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                if (_scannedProduct!.code != null && _scannedProduct!.code!.isNotEmpty)
                                  Text(
                                    'Kode: ${_scannedProduct!.code}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                if (_scannedProduct!.qrcode != null && _scannedProduct!.qrcode!.isNotEmpty)
                                  Text(
                                    'QR Stok: ${_scannedProduct!.qrcode}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                AppSizes.gapH4,
                                Text(
                                  CurrencyFormatter.format(_scannedProduct!.price),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sisa Stok: ${_scannedProduct!.stock}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _scannedProduct!.stock > 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            onPressed: _scannedProduct!.stock > 0 ? _confirmAdd : null,
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                            label: const Text('Tambah ke Keranjang'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

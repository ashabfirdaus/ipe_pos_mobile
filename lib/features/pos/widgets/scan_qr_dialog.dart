import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/pos_models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/currency_formatter.dart';
import 'camera_scanner_page.dart';

class ScanQrDialog extends StatefulWidget {
  final int warehouseId;
  final int? branchId;
  final Function(ProductModel product, String qrcode) onProductFound;

  const ScanQrDialog({
    super.key,
    required this.warehouseId,
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

    if (scannedCode != null && scannedCode.isNotEmpty) {
      _codeController.text = scannedCode;
      _handleScan(scannedCode);
    }
  }

  Future<void> _handleScan(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

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
        _errorMessage = res.message;
      });
    }
  }

  void _confirmAdd() {
    if (_scannedProduct != null) {
      widget.onProductFound(_scannedProduct!, _codeController.text.trim());
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      child: Padding(
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                      ),
                      AppSizes.gapW12,
                      const Text('Scan QR / Barcode', style: AppTextStyles.h3),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              AppSizes.gapH16,

              // Camera Scanner Launch Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  onPressed: _openCameraScanner,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text(
                    'Buka Kamera Scanner',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              AppSizes.gapH16,

              // Divider with 'atau input manual'
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('atau input manual', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              AppSizes.gapH16,

              // Code Input Field
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Kode QR / Barcode',
                  hintText: 'contoh: STK-2026-0001 / 899123456',
                  prefixIcon: const Icon(Icons.barcode_reader),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _handleScan(_codeController.text),
                  ),
                ),
                onSubmitted: _handleScan,
              ),
              AppSizes.gapH12,

              // Quick demo sample buttons
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.auto_fix_high_rounded, size: 14),
                    label: const Text('Sample: STK-2026-0001', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      _codeController.text = 'STK-2026-0001';
                      _handleScan('STK-2026-0001');
                    },
                  ),
                ],
              ),
              AppSizes.gapH16,

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      AppSizes.gapW8,
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              if (_scannedProduct != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                          AppSizes.gapW8,
                          Expanded(
                            child: Text(
                              _scannedProduct!.name,
                              style: AppTextStyles.h3.copyWith(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      AppSizes.gapH8,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Harga Satuan:', style: AppTextStyles.bodySmall),
                          Text(
                            CurrencyFormatter.format(_scannedProduct!.price),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      AppSizes.gapH4,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sisa Stok Gudang:', style: AppTextStyles.bodySmall),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _scannedProduct!.stock > 0 ? AppColors.success : AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_scannedProduct!.stock.toStringAsFixed(0)} ${_scannedProduct!.unit ?? 'pcs'}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppSizes.gapH20,
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _scannedProduct!.stock > 0 ? _confirmAdd : null,
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('Tambahkan ke Keranjang'),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  List<ProductModel> _searchResults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
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
    // Hilangkan fokus kursor dan sembunyikan keypad
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();

    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

    if (cleanCode.length < 3) {
      setState(() {
        _errorMessage = 'Minimal input pencarian adalah 3 digit / karakter.';
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchResults = [];
    });

    final res = await ApiService.searchByQrCode(
      qrcode: cleanCode,
      warehouseId: widget.warehouseId,
      branchId: widget.branchId,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
      setState(() {
        _searchResults = res.data!;
      });
    } else {
      setState(() {
        _errorMessage = res.message.isNotEmpty
            ? res.message
            : 'Produk dengan QR Code berakhiran "$cleanCode" tidak ditemukan.';
      });
    }
  }

  Future<void> _confirmAdd(ProductModel product) async {
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

    final code = product.qrcode?.isNotEmpty == true
        ? product.qrcode!
        : _codeController.text.trim();
    int finalQty = 1;

    if (product.stock > 1) {
      final chosenQty = await StockQtyConfirmDialog.show(
        context,
        product: product,
        qrcode: code,
      );
      if (chosenQty == null) return;
      finalQty = chosenQty;
    }

    widget.onProductFound(product, code, finalQty);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final hasResults = _searchResults.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: hasResults ? screenHeight * 0.85 : screenHeight * 0.6,
        ),
        padding: const EdgeInsets.all(AppSizes.md),
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
                    Text('Scan / Cari QR Code', style: AppTextStyles.h3),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 12),

            // Input Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    focusNode: _focusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Kode QR Produk (Angka)',
                      hintText: 'Misal: 003 / Scan Barcode',
                      prefixIcon: Icon(Icons.barcode_reader),
                      isDense: true,
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
            const SizedBox(height: 6),

            // Helper Info Text
            Text(
              'Pencarian mencocokkan digit kode QR dari belakang (suffix match).',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),

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
                label: const Text('Cari Produk'),
              ),
            ),

            // Error State
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
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
            ],

            // Search Results
            if (hasResults) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ditemukan ${_searchResults.length} produk:',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.swipe_vertical_rounded, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      const Text(
                        'Bisa di-scroll',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 5,
                  radius: const Radius.circular(8),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(right: 6, bottom: 4),
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      final isOutOfStock = product.stock <= 0;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Colors.grey.shade50
                              : AppColors.primary.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          border: Border.all(
                            color: isOutOfStock
                                ? Colors.grey.shade300
                                : AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Nama Produk Tampil Penuh di Luar Kolom
                            Text(
                              product.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: isOutOfStock ? AppColors.textSecondary : AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 2. Baris Detail Produk (Thumbnail, QR/Kode, Harga, Stok, & Tombol)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Thumbnail Foto Produk
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                                    ),
                                    child: product.imagePath != null && product.imagePath!.isNotEmpty
                                        ? Image.network(
                                            product.imagePath!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                                          )
                                        : const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                                  ),
                                ),
                                AppSizes.gapW8,

                                // QR Code, Kode, Harga & Stok
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: [
                                          if (product.qrcode != null && product.qrcode!.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8EAF6),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.qr_code_2_rounded, size: 11, color: Color(0xFF1A237E)),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    'QR: ${product.qrcode}',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1A237E),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (product.code != null &&
                                              product.code!.isNotEmpty &&
                                              product.code != product.qrcode)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Kode: ${product.code}',
                                                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            CurrencyFormatter.format(product.price),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '•  Stok: ${product.stock.toInt()} ${product.unit ?? "pcs"}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isOutOfStock ? AppColors.error : AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                AppSizes.gapW8,

                                // Tombol Tambah
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isOutOfStock ? Colors.grey.shade400 : AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                                    ),
                                  ),
                                  onPressed: isOutOfStock ? null : () => _confirmAdd(product),
                                  child: Text(
                                    isOutOfStock ? 'Habis' : '+ Tambah',
                                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/models/pos_models.dart';
import '../../../core/utils/currency_formatter.dart';

/// Dialog konfirmasi Qty untuk stok QR yang memiliki remaining_qty > 1.
/// Memungkinkan kasir mengurangi Qty, namun tidak dapat menambah melebihi stok yang tersedia pada QR.
class StockQtyConfirmDialog extends StatefulWidget {
  final ProductModel product;
  final String qrcode;
  final int maxQty;

  const StockQtyConfirmDialog({
    super.key,
    required this.product,
    required this.qrcode,
    required this.maxQty,
  });

  /// Menampilkan popup konfirmasi qty stok QR
  static Future<int?> show(
    BuildContext context, {
    required ProductModel product,
    required String qrcode,
  }) {
    final maxQty = product.stock > 0 ? product.stock.toInt() : 1;
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StockQtyConfirmDialog(
        product: product,
        qrcode: qrcode,
        maxQty: maxQty,
      ),
    );
  }

  @override
  State<StockQtyConfirmDialog> createState() => _StockQtyConfirmDialogState();
}

class _StockQtyConfirmDialogState extends State<StockQtyConfirmDialog> {
  late int _currentQty;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Default qty awal adalah maksimal stok QR (remaining_qty)
    _currentQty = widget.maxQty;
    _controller = TextEditingController(text: _currentQty.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _decrement() {
    if (_currentQty > 1) {
      setState(() {
        _currentQty--;
        _controller.text = _currentQty.toString();
      });
    }
  }

  void _increment() {
    if (_currentQty < widget.maxQty) {
      setState(() {
        _currentQty++;
        _controller.text = _currentQty.toString();
      });
    }
  }

  void _onTextChanged(String val) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null) {
      if (parsed > widget.maxQty) {
        // Otomatis batasi tidak bisa melebihi remaining_qty
        setState(() {
          _currentQty = widget.maxQty;
          _controller.text = widget.maxQty.toString();
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      } else if (parsed >= 1) {
        setState(() {
          _currentQty = parsed;
        });
      }
    }
  }

  void _submit() {
    if (_currentQty < 1) {
      _currentQty = 1;
    }
    if (_currentQty > widget.maxQty) {
      _currentQty = widget.maxQty;
    }
    Navigator.of(context).pop(_currentQty);
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.product.unit?.isNotEmpty == true ? widget.product.unit! : 'Pcs';
    final subtotal = widget.product.price * _currentQty;
    final isAtMax = _currentQty >= widget.maxQty;
    final isAtMin = _currentQty <= 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Dialog
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAF6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Color(0xFF1A237E),
                    size: 22,
                  ),
                ),
                AppSizes.gapW12,
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konfirmasi Jumlah Qty',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Stok fisik QR memiliki > 1 barang',
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
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Info Barang & QR
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EAF6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_2_rounded, size: 12, color: Color(0xFF283593)),
                            const SizedBox(width: 4),
                            Text(
                              'QR: ${widget.qrcode}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF283593),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${CurrencyFormatter.format(widget.product.price)} / $unit',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sisa Stok QR: ${widget.maxQty} $unit',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stepper Input Qty
            const Text(
              'Masukkan Jumlah Barang (Qty):',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tombol Kurang (Bisa Dikurangi)
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: isAtMin ? Colors.grey.shade300 : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.remove_rounded, size: 20),
                    onPressed: isAtMin ? null : _decrement,
                    tooltip: 'Kurangi Qty',
                  ),

                  // Input Box Qty
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _controller,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: _onTextChanged,
                        ),
                      ),
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Tombol Tambah (Tidak Bisa Ditambah Melebihi remaining_qty)
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: isAtMax ? Colors.grey.shade300 : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    onPressed: isAtMax ? null : _increment,
                    tooltip: isAtMax ? 'Maksimal stok QR tercapai' : 'Tambah Qty',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Helper Info: bisa dikurangi, tidak bisa ditambah melebihi stok QR
            Row(
              children: [
                Icon(
                  isAtMax ? Icons.info_outline : Icons.check_circle_outline,
                  size: 13,
                  color: isAtMax ? Colors.orange.shade800 : AppColors.success,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isAtMax
                        ? 'Maksimal ${widget.maxQty} $unit (tidak dapat ditambah melebihi stok QR)'
                        : 'Bisa dikurangi atau disesuaikan hingga ${widget.maxQty} $unit',
                    style: TextStyle(
                      fontSize: 11,
                      color: isAtMax ? Colors.orange.shade800 : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Subtotal Preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Nilai Item:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    CurrencyFormatter.format(subtotal),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Aksi (Batal & Masuk Keranjang)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _submit,
                    child: const Text(
                      'Masuk Keranjang',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

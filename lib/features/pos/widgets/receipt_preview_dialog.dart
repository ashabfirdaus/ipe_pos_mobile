import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/pos_models.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/utils/currency_formatter.dart';

/// Dialog untuk menampilkan preview visual nota fisik thermal
/// sesuai ukuran kertas rol (58mm atau 80mm) sebelum dicetak.
class ReceiptPreviewDialog extends StatefulWidget {
  final InvoiceModel invoice;
  final bool isSample;

  const ReceiptPreviewDialog({
    super.key,
    required this.invoice,
    this.isSample = false,
  });

  /// Helper statis untuk menampilkan dialog preview nota
  static Future<void> show(
    BuildContext context, {
    required InvoiceModel invoice,
    bool isSample = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReceiptPreviewDialog(
        invoice: invoice,
        isSample: isSample,
      ),
    );
  }

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  final PrinterService _printerService = PrinterService.instance;
  late String _paperSize; // '58' or '80'
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _paperSize = _printerService.paperSize;
  }

  Future<void> _handlePrint() async {
    final isConnected = await _printerService.checkConnectionStatus();

    if (!isConnected && _printerService.connectedDevice == null) {
      if (!mounted) return;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.print_disabled_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Printer Belum Terhubung'),
            ],
          ),
          content: const Text(
            'Printer thermal Bluetooth belum terhubung. Buka Pengaturan Printer untuk menghubungkan printer thermal Anda?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );

      if (openSettings == true && mounted) {
        Navigator.of(context).pushNamed(AppRoutes.printerSettings);
      }
      return;
    }

    setState(() => _isPrinting = true);

    final ({bool success, String message}) result;
    if (widget.isSample) {
      result = await _printerService.testPrint();
    } else {
      result = await _printerService.printReceipt(
        widget.invoice,
        cashierName: widget.invoice.cashierName,
      );
    }

    if (!mounted) return;
    setState(() => _isPrinting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _printerService.isConnected;
    final connectedDevice = _printerService.connectedDevice;
    final is80mm = _paperSize == '80';
    final paperWidth = is80mm ? 360.0 : 300.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar: Title + Paper Size Toggle + Close Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isSample ? 'Preview Contoh Nota' : 'Preview Cetak Nota',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Toggle Ukuran Kertas 58mm / 80mm
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      _buildSizeChip('58', '58mm'),
                      _buildSizeChip('80', '80mm'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Receipt Body (Visual Kertas Thermal)
          Flexible(
            child: Container(
              color: const Color(0xFFE8ECEF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: paperWidth,
                  child: ClipPath(
                    clipper: _ReceiptPaperClipper(),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Logo Perusahaan
                          Center(
                            child: Image.asset(
                              'assets/icon/intipangan_logo.png',
                              height: 38,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Text(
                                'INTI PANGAN EKSPOR',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (widget.invoice.branchName != null)
                            Center(
                              child: Text(
                                widget.invoice.branchName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          _buildDashedLine(),

                          // 2. Info Transaksi
                          _buildMetaRow('No. Inv', widget.invoice.invoiceNo),
                          _buildMetaRow(
                            'Waktu',
                            CurrencyFormatter.formatDate(
                              widget.invoice.createdAt.isNotEmpty
                                  ? widget.invoice.createdAt
                                  : DateTime.now().toIso8601String(),
                            ),
                          ),
                          if (widget.invoice.cashierName != null &&
                              widget.invoice.cashierName!.isNotEmpty &&
                              widget.invoice.cashierName != '-')
                            _buildMetaRow('Kasir', widget.invoice.cashierName!),
                          if (widget.invoice.paymentMethodName != null)
                            _buildMetaRow('Metode', widget.invoice.paymentMethodName!),

                          _buildDashedLine(),

                          // 3. Daftar Produk
                          ...widget.invoice.items.map((item) => _buildItemRow(item)),

                          _buildDashedLine(),

                          // 4. Rekap Finansial
                          _buildSummaryRow(
                            'Sub Total',
                            CurrencyFormatter.format(widget.invoice.subTotal),
                          ),
                          if (widget.invoice.discount > 0)
                            _buildSummaryRow(
                              widget.invoice.promoName != null &&
                                      widget.invoice.promoName!.isNotEmpty
                                  ? 'Diskon (${widget.invoice.promoName})'
                                  : 'Diskon Promo',
                              '-${CurrencyFormatter.format(widget.invoice.discount)}',
                              isHighlight: true,
                            ),
                          if (widget.invoice.ppn > 0)
                            _buildSummaryRow(
                              'PPN',
                              '+${CurrencyFormatter.format(widget.invoice.ppn)}',
                            ),

                          _buildDashedLine(),

                          _buildSummaryRow(
                            'GRAND TOTAL',
                            CurrencyFormatter.format(widget.invoice.grandTotal),
                            isBold: true,
                            fontSize: 14,
                          ),
                          _buildSummaryRow(
                            'Pembayaran',
                            CurrencyFormatter.format(widget.invoice.cash),
                          ),
                          _buildSummaryRow(
                            'Kembalian',
                            CurrencyFormatter.format(widget.invoice.change),
                            isBold: true,
                          ),

                          // Catatan Hemat
                          if (widget.invoice.discount > 0) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                '* Anda hemat ${CurrencyFormatter.format(widget.invoice.discount)} pada transaksi ini',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          _buildDashedLine(),

                          // 5. Footer Struk
                          const Center(
                            child: Text(
                              'Terima Kasih atas Kunjungan Anda!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Center(
                            child: Text(
                              'Barang yang sudah dibeli\ntidak dapat ditukar/dikembalikan',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontFamily: 'monospace',
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Panel: Status Printer + Cetak Button
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indikator Status Printer
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isConnected
                            ? 'Printer: ${connectedDevice?.name ?? "Terhubung"} ($_paperSize mm)'
                            : 'Printer belum terhubung via Bluetooth',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isConnected ? Colors.black87 : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isConnected)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed(AppRoutes.printerSettings);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Hubungkan', style: TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Tombol Aksi
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Tutup', style: TextStyle(color: Colors.black87)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _isPrinting ? null : _handlePrint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.print_rounded, size: 18),
                        label: Text(
                          _isPrinting ? 'Mencetak...' : 'Cetak Nota',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeChip(String size, String label) {
    final isSelected = _paperSize == size;
    return InkWell(
      onTap: () {
        setState(() => _paperSize = size);
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildDashedLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 4.0;
          const dashSpace = 3.0;
          final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
          return Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return const SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black45),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              '$label :',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(InvoiceItemModel item) {
    final unitStr = item.unit != null && item.unit!.isNotEmpty ? ' ${item.unit}' : '';
    final qtyPriceStr = '${item.qty}$unitStr x ${CurrencyFormatter.format(item.price)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama Produk
          Text(
            item.itemName,
            style: const TextStyle(
              fontSize: 11.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 1),
          // Qty x Harga (kiri) & Subtotal (kanan)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '  $qtyPriceStr',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.black87,
                ),
              ),
              Text(
                CurrencyFormatter.format(item.subTotal),
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          // Diskon item jika ada
          if (item.discount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 1),
              child: Text(
                '(Diskon: -${CurrencyFormatter.format(item.discount)})',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    bool isHighlight = false,
    double fontSize = 11.5,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontFamily: 'monospace',
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? AppColors.success : Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontFamily: 'monospace',
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? AppColors.success : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clipper untuk memberikan efek sobekan zigzag kertas rol thermal di atas dan bawah
class _ReceiptPaperClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const triangleWidth = 8.0;
    const triangleHeight = 3.5;
    final path = Path();

    // Top Zigzag
    path.moveTo(0, triangleHeight);
    var x = 0.0;
    var up = true;
    while (x < size.width) {
      x += triangleWidth / 2;
      path.lineTo(x, up ? 0 : triangleHeight);
      up = !up;
    }
    path.lineTo(size.width, size.height - triangleHeight);

    // Bottom Zigzag
    x = size.width;
    up = true;
    while (x > 0) {
      x -= triangleWidth / 2;
      path.lineTo(x, up ? size.height : size.height - triangleHeight);
      up = !up;
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

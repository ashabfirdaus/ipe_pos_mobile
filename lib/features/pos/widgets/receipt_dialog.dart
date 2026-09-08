import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/pos_models.dart';
import '../../../core/utils/currency_formatter.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/services/printer_service.dart';

class ReceiptDialog extends StatefulWidget {
  final InvoiceModel invoice;

  const ReceiptDialog({super.key, required this.invoice});

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  bool _isPrinting = false;

  Future<void> _handlePrint() async {
    final printerService = PrinterService.instance;
    final isConnected = await printerService.checkConnectionStatus();

    if (!isConnected && printerService.connectedDevice == null) {
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
            'Printer thermal Bluetooth belum dikonfigurasi. Apakah Anda ingin membuka menu Pengaturan Printer sekarang?',
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
    final result = await printerService.printReceipt(widget.invoice);
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
    final invoice = widget.invoice;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppSizes.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
              ),
              AppSizes.gapH12,
              const Text('Transaksi Berhasil!', style: AppTextStyles.h2),
              Text(
                'Invoice: ${invoice.invoiceNo}',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              AppSizes.gapH16,
              const Divider(),

              // Metadata
              _buildReceiptRow('Tanggal & Waktu', CurrencyFormatter.formatDate(invoice.createdAt)),
              if (invoice.branchName != null) _buildReceiptRow('Cabang', invoice.branchName!),
              if (invoice.warehouseName != null) _buildReceiptRow('Gudang', invoice.warehouseName!),
              if (invoice.paymentMethodName != null) _buildReceiptRow('Metode Bayar', invoice.paymentMethodName!),
              const Divider(),

              // Items breakdown
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Daftar Produk:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              AppSizes.gapH8,
              ...invoice.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              if (item.qrcode != null && item.qrcode!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8EAF6),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'QR: ${item.qrcode}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF283593),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                '${item.qty} ${item.unit ?? "pcs"} x ${CurrencyFormatter.format(item.price)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(item.subTotal),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )),
              const Divider(),

              // Totals
              _buildReceiptRow('Sub Total', CurrencyFormatter.format(invoice.subTotal)),
              if (invoice.discount > 0)
                _buildReceiptRow(
                  invoice.promoName != null && invoice.promoName!.isNotEmpty
                      ? 'Diskon Promo (${invoice.promoName})'
                      : 'Diskon Promo',
                  '- ${CurrencyFormatter.format(invoice.discount)}',
                  color: AppColors.success,
                ),
              if (invoice.ppn > 0) _buildReceiptRow('PPN', '+ ${CurrencyFormatter.format(invoice.ppn)}'),
              const Divider(),
              _buildReceiptRow('Grand Total', CurrencyFormatter.format(invoice.grandTotal), isBold: true, fontSize: 16),
              _buildReceiptRow('Tunai (Diterima)', CurrencyFormatter.format(invoice.cash)),
              _buildReceiptRow('Kembalian', CurrencyFormatter.format(invoice.change), isBold: true, color: AppColors.primary),
              AppSizes.gapH24,

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPrinting ? null : _handlePrint,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_rounded),
                      label: Text(_isPrinting ? 'Mencetak...' : 'Cetak Struk'),
                    ),
                  ),
                  AppSizes.gapW12,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Selesai'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
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
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

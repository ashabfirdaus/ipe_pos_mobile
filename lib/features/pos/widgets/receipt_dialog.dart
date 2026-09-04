import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/pos_models.dart';
import '../../../core/utils/currency_formatter.dart';

class ReceiptDialog extends StatelessWidget {
  final InvoiceModel invoice;

  const ReceiptDialog({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
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
                              Text(item.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                '${item.qty} x ${CurrencyFormatter.format(item.price)}',
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
              if (invoice.discount > 0) _buildReceiptRow('Diskon', '- ${CurrencyFormatter.format(invoice.discount)}'),
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
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mencetak struk ke printer thermal...')),
                        );
                      },
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Cetak Struk'),
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

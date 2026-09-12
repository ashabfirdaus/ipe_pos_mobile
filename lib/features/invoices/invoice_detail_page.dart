import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/pos_models.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/api_service.dart';
import '../../core/services/printer_service.dart';
import '../../core/utils/currency_formatter.dart';

class InvoiceDetailPage extends StatefulWidget {
  final dynamic invoiceId;

  const InvoiceDetailPage({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  bool _isLoading = true;
  bool _isPrinting = false;
  InvoiceModel? _invoice;
  String? _errorMessage;

  Future<void> _handlePrint() async {
    if (_invoice == null) return;
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
    final result = await printerService.printReceipt(
      _invoice!,
      cashierName: _invoice!.cashierName,
    );
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
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.getInvoiceDetail(widget.invoiceId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res.isSuccess && res.data != null) {
      setState(() {
        _invoice = res.data;
      });
    } else {
      setState(() {
        _errorMessage = res.message;
      });
    }
  }

  void _showVoidDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Batalkan (Void) Transaksi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pembatalan transaksi akan mengembalikan stok produk ke gudang dan membatalkan jurnal kasir.',
              style: AppTextStyles.bodySmall,
            ),
            AppSizes.gapH16,
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan Pembatalan (Void Desc)',
                hintText: 'contoh: Kesalahan input kasir / nominal pembayaran',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Harap isi alasan pembatalan transaksi!'),
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              _processVoid(reason);
            },
            child: const Text('Ya, Void Transaksi'),
          ),
        ],
      ),
    );
  }

  Future<void> _processVoid(String reason) async {
    setState(() {
      _isLoading = true;
    });

    final res = await ApiService.voidInvoice(widget.invoiceId, reason);
    if (!mounted) return;

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi berhasil dibatalkan (VOID).'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadDetail();
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message.isNotEmpty
                ? res.message
                : 'Gagal membatalkan transaksi',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice != null ? _invoice!.invoiceNo : 'Detail Invoice'),
        actions: [
          if (_invoice != null)
            IconButton(
              icon: _isPrinting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.print_rounded),
              tooltip: 'Cetak Nota',
              onPressed: _isPrinting ? null : _handlePrint,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDetail),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      AppSizes.gapH16,
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      AppSizes.gapH16,
                      ElevatedButton(
                        onPressed: _loadDetail,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              )
            : _invoice == null
            ? const Center(child: Text('Data tidak ditemukan'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge Card
                    _buildStatusCard(),
                    AppSizes.gapH16,

                    // Information Card
                    _buildInfoCard(),
                    AppSizes.gapH16,

                    // Items List Card
                    _buildItemsCard(),
                    AppSizes.gapH16,

                    // Financial Breakdown Card
                    _buildFinancialCard(),
                    AppSizes.gapH24,

                    // Print Receipt Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.print_rounded),
                        label: Text(
                          _isPrinting ? 'Mencetak Nota...' : 'Cetak Nota',
                        ),
                        onPressed: _isPrinting ? null : _handlePrint,
                      ),
                    ),
                    AppSizes.gapH12,

                    // Void Button if Active
                    if (_invoice!.status == 1)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Batalkan Transaksi (Void)'),
                          onPressed: _showVoidDialog,
                        ),
                      ),
                    AppSizes.gapH24,
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isVoid = _invoice!.status == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: isVoid
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: isVoid
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVoid ? Icons.cancel_rounded : Icons.check_circle_rounded,
                color: isVoid ? AppColors.error : AppColors.success,
              ),
              AppSizes.gapW8,
              Text(
                isVoid
                    ? 'STATUS: DIBATALKAN (VOID)'
                    : 'STATUS: SELESAI / AKTIF',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isVoid ? AppColors.error : AppColors.success,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (isVoid && _invoice!.voidDesc != null) ...[
            AppSizes.gapH8,
            Text(
              'Alasan: ${_invoice!.voidDesc}',
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            _buildRow('No Invoice', _invoice!.invoiceNo, isBold: true),
            const Divider(),
            _buildRow(
              'Tanggal & Waktu',
              CurrencyFormatter.formatDate(_invoice!.createdAt),
            ),
            const Divider(),
            _buildRow(
              'Kasir',
              (_invoice!.cashierName != null &&
                      _invoice!.cashierName!.trim().isNotEmpty)
                  ? _invoice!.cashierName!
                  : '-',
            ),
            // if (_invoice!.branchName != null) ...[
            //   const Divider(),
            //   _buildRow('Cabang', _invoice!.branchName!),
            // ],
            // if (_invoice!.warehouseName != null) ...[
            //   const Divider(),
            //   _buildRow('Gudang', _invoice!.warehouseName!),
            // ],
            if (_invoice!.paymentMethodName != null) ...[
              const Divider(),
              _buildRow('Metode Pembayaran', _invoice!.paymentMethodName!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Item Transaksi', style: AppTextStyles.h3),
            AppSizes.gapH12,
            if (_invoice!.items.isEmpty)
              const Text(
                'Tidak ada rincian item.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _invoice!.items.length,
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final item = _invoice!.items[index];
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (item.qrcode != null &&
                                item.qrcode!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
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
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(item.subTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            _buildRow(
              'Sub Total',
              CurrencyFormatter.format(_invoice!.subTotal),
            ),
            if (_invoice!.discount > 0) ...[
              AppSizes.gapH4,
              _buildRow(
                _invoice!.promoName != null && _invoice!.promoName!.isNotEmpty
                    ? 'Diskon Promo (${_invoice!.promoName})'
                    : 'Diskon Promo',
                '- ${CurrencyFormatter.format(_invoice!.discount)}',
                color: AppColors.success,
              ),
            ],
            if (_invoice!.ppn > 0) ...[
              AppSizes.gapH4,
              _buildRow('PPN', '+ ${CurrencyFormatter.format(_invoice!.ppn)}'),
            ],
            const Divider(height: 16),
            _buildRow(
              'Grand Total',
              CurrencyFormatter.format(_invoice!.grandTotal),
              isBold: true,
              fontSize: 16,
            ),
            AppSizes.gapH4,
            _buildRow(
              'Pembayaran Diterima',
              CurrencyFormatter.format(_invoice!.cash),
            ),
            AppSizes.gapH4,
            _buildRow(
              'Kembalian',
              CurrencyFormatter.format(_invoice!.change),
              isBold: true,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
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
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

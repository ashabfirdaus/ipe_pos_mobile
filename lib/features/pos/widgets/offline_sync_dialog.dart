import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/utils/currency_formatter.dart';
import 'receipt_dialog.dart';

class OfflineSyncDialog extends StatefulWidget {
  const OfflineSyncDialog({super.key});

  @override
  State<OfflineSyncDialog> createState() => _OfflineSyncDialogState();
}

class _OfflineSyncDialogState extends State<OfflineSyncDialog> {
  bool _isLoading = true;
  bool _isSyncing = false;
  List<OfflineTransactionItem> _items = [];
  String? _syncSummary;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await OfflineSyncService.instance.getPendingTransactions();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _syncAll() async {
    setState(() {
      _isSyncing = true;
      _syncSummary = null;
    });

    final res = await OfflineSyncService.instance.syncPendingTransactions();

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _syncSummary = 'Total: ${res.total} | Berhasil: ${res.success} | Gagal: ${res.failed}';
    });

    await _loadItems();
  }

  Future<void> _deleteItem(OfflineTransactionItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi Offline?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus transaksi ${item.offlineCode}?\n\n'
          'Perhatian: Data ini belum disinkronkan ke server dan tidak dapat dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await OfflineSyncService.instance.removePendingTransaction(item.localId);
      await _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: AppColors.warning, size: 28),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Antrean Transaksi Offline',
                          style: AppTextStyles.h3,
                        ),
                        Text(
                          '${_items.length} transaksi menunggu sinkronisasi',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Summary status if any
              if (_syncSummary != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSizes.md),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _syncSummary!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Content Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_done_rounded, size: 64, color: AppColors.success.withValues(alpha: 0.7)),
                                const SizedBox(height: 12),
                                const Text(
                                  'Semua Data Sudah Tersinkron',
                                  style: AppTextStyles.h4,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tidak ada transaksi offline yang tertunda.',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (ctx, index) {
                              final item = _items[index];
                              final invoice = item.localInvoice;
                              final dateStr = '${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.year} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                                  side: BorderSide(
                                    color: item.syncError != null
                                        ? AppColors.error.withValues(alpha: 0.3)
                                        : AppColors.border,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSizes.md),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.offlineCode,
                                              style: AppTextStyles.bodyLarge.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.warning.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                                            ),
                                            child: const Text(
                                              'Offline',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.warning,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateStr,
                                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${invoice.items.length} Barang',
                                            style: AppTextStyles.bodySmall,
                                          ),
                                          Text(
                                            CurrencyFormatter.format(invoice.grandTotal),
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.syncError != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Error: ${item.syncError}',
                                          style: AppTextStyles.caption.copyWith(color: AppColors.error),
                                        ),
                                      ],
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.print_rounded, size: 16),
                                            label: const Text('Cetak Nota', style: TextStyle(fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) => ReceiptDialog(invoice: invoice),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                            tooltip: 'Hapus',
                                            onPressed: () => _deleteItem(item),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              const SizedBox(height: AppSizes.md),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                  ElevatedButton.icon(
                    onPressed: (_isSyncing || _items.isEmpty) ? null : _syncAll,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_rounded),
                    label: Text(_isSyncing ? 'Menyinkronkan...' : 'Sinkronkan Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
}

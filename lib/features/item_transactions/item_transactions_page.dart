import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/pos_models.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/currency_formatter.dart';

class ItemTransactionsPage extends StatefulWidget {
  final dynamic initialItemId;

  const ItemTransactionsPage({super.key, this.initialItemId});

  @override
  State<ItemTransactionsPage> createState() => _ItemTransactionsPageState();
}

class _ItemTransactionsPageState extends State<ItemTransactionsPage> {
  final _itemIdController = TextEditingController(text: '1');
  bool _isLoading = false;
  String? _errorMessage;

  ItemTransactionSummaryModel? _summary;
  List<ItemTransactionDetailModel> _details = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialItemId != null) {
      _itemIdController.text = widget.initialItemId.toString();
    }
    _fetchItemData();
  }

  @override
  void dispose() {
    _itemIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchItemData() async {
    final itemId = _itemIdController.text.trim();
    if (itemId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final summaryRes = await ApiService.getItemTransactionSummary(itemId);
    final detailsRes = await ApiService.getItemTransactionDetails(itemId);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (summaryRes.isSuccess || detailsRes.isSuccess) {
      setState(() {
        _summary = summaryRes.data ??
            ItemTransactionSummaryModel(
              itemId: itemId,
              itemName: 'Barang #$itemId',
              totalQtyIn: 0,
              totalQtyOut: 0,
              currentStock: 0,
              totalValue: 0,
              totalTransactions: 0,
              totalRows: 0,
            );
        _details = detailsRes.data ?? [];
      });
    } else {
      setState(() {
        _errorMessage = summaryRes.message.isNotEmpty ? summaryRes.message : detailsRes.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutasi & Transaksi Barang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchItemData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item ID Selector Card
            _buildSearchCard(),
            AppSizes.gapH16,

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              _buildErrorCard()
            else if (_summary != null) ...[
              // Summary Cards
              _buildSummarySection(),
              AppSizes.gapH16,

              // Details List Section
              _buildDetailsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih ID Barang / Item ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            AppSizes.gapH8,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Masukkan Item ID (cth: 1)',
                      prefixIcon: Icon(Icons.tag_rounded),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _fetchItemData(),
                  ),
                ),
                AppSizes.gapW8,
                ElevatedButton.icon(
                  onPressed: _fetchItemData,
                  icon: const Icon(Icons.search),
                  label: const Text('Cari'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Barang: ${_summary!.itemName}',
          style: AppTextStyles.h3,
        ),
        AppSizes.gapH12,
        Row(
          children: [
            Expanded(
              child: _buildSummaryTile(
                'Total Masuk',
                '${CurrencyFormatter.formatNumber(_summary!.totalQtyIn)} unit',
                Icons.arrow_downward_rounded,
                AppColors.success,
              ),
            ),
            AppSizes.gapW8,
            Expanded(
              child: _buildSummaryTile(
                'Total Keluar',
                '${CurrencyFormatter.formatNumber(_summary!.totalQtyOut)} unit',
                Icons.arrow_upward_rounded,
                AppColors.error,
              ),
            ),
          ],
        ),
        AppSizes.gapH8,
        Row(
          children: [
            Expanded(
              child: _buildSummaryTile(
                'Sisa Stok',
                '${CurrencyFormatter.formatNumber(_summary!.currentStock)} unit',
                Icons.inventory_2_rounded,
                AppColors.primary,
              ),
            ),
            AppSizes.gapW8,
            Expanded(
              child: _buildSummaryTile(
                'Total Nilai',
                CurrencyFormatter.format(_summary!.totalValue),
                Icons.account_balance_wallet_rounded,
                AppColors.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              AppSizes.gapW4,
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSizes.gapH4,
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rincian Riwayat Transaksi Mutasi', style: AppTextStyles.h3),
            AppSizes.gapH12,
            if (_details.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Belum ada data detail mutasi untuk barang ini.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _details.length,
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final d = _details[index];
                  final isPositive = d.qtyIn > 0;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isPositive ? AppColors.successContainer : AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        ),
                        child: Icon(
                          isPositive ? Icons.add_rounded : Icons.remove_rounded,
                          size: 18,
                          color: isPositive ? AppColors.success : AppColors.error,
                        ),
                      ),
                      AppSizes.gapW12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Ref: ${d.refNo}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            if (d.notes != null && d.notes!.isNotEmpty)
                              Text(d.notes!, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                            AppSizes.gapH2,
                            Text(CurrencyFormatter.formatDate(d.date), style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isPositive ? '+${d.qtyIn.toStringAsFixed(0)}' : '-${d.qtyOut.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isPositive ? AppColors.success : AppColors.error,
                            ),
                          ),
                          Text('Sisa: ${d.balance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
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

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 36),
          AppSizes.gapH8,
          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
        ],
      ),
    );
  }
}

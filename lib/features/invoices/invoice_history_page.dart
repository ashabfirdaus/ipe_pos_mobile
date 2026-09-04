import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/pos_models.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/currency_formatter.dart';
import 'invoice_detail_page.dart';

class InvoiceHistoryPage extends StatefulWidget {
  const InvoiceHistoryPage({super.key});

  @override
  State<InvoiceHistoryPage> createState() => _InvoiceHistoryPageState();
}

class _InvoiceHistoryPageState extends State<InvoiceHistoryPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<InvoiceModel> _invoices = [];

  int? _selectedStatus; // null = all, 1 = active, 0 = void
  final _searchController = TextEditingController();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.getInvoices(
      page: _currentPage,
      status: _selectedStatus,
      search: _searchController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res.isSuccess && res.data != null) {
      setState(() {
        _invoices = res.data!;
      });
    } else {
      setState(() {
        _errorMessage = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadInvoices(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          _buildFilterBar(),

          // List Invoices
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorState()
                    : _invoices.isEmpty
                        ? _buildEmptyState()
                        : _buildInvoiceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      color: Colors.white,
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari No Invoice / Transaksi...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _loadInvoices(refresh: true);
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onSubmitted: (_) => _loadInvoices(refresh: true),
          ),
          AppSizes.gapH8,

          // Status Filter Chips
          Row(
            children: [
              const Text('Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              AppSizes.gapW8,
              ChoiceChip(
                label: const Text('Semua', style: TextStyle(fontSize: 11)),
                selected: _selectedStatus == null,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedStatus = null);
                    _loadInvoices(refresh: true);
                  }
                },
              ),
              AppSizes.gapW8,
              ChoiceChip(
                label: const Text('Aktif', style: TextStyle(fontSize: 11)),
                selected: _selectedStatus == 1,
                selectedColor: AppColors.successContainer,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedStatus = 1);
                    _loadInvoices(refresh: true);
                  }
                },
              ),
              AppSizes.gapW8,
              ChoiceChip(
                label: const Text('Void', style: TextStyle(fontSize: 11)),
                selected: _selectedStatus == 0,
                selectedColor: AppColors.errorContainer,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedStatus = 0);
                    _loadInvoices(refresh: true);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList() {
    return RefreshIndicator(
      onRefresh: () => _loadInvoices(refresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.md),
        itemCount: _invoices.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final inv = _invoices[index];
          final isVoid = inv.status == 0;

          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: isVoid ? AppColors.errorContainer : AppColors.primaryContainer,
                child: Icon(
                  isVoid ? Icons.cancel_outlined : Icons.receipt_long_rounded,
                  color: isVoid ? AppColors.error : AppColors.primary,
                ),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      inv.invoiceNo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isVoid ? AppColors.errorContainer : AppColors.successContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isVoid ? 'VOID' : 'SUKSES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isVoid ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSizes.gapH4,
                  Text(CurrencyFormatter.formatDate(inv.createdAt), style: AppTextStyles.caption),
                  AppSizes.gapH4,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        inv.paymentMethodName ?? 'Tunai',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        CurrencyFormatter.format(inv.grandTotal),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isVoid ? AppColors.textSecondary : AppColors.primary,
                          decoration: isVoid ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => InvoiceDetailPage(invoiceId: inv.id),
                  ),
                );
                _loadInvoices();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary),
            AppSizes.gapH16,
            const Text('Belum ada transaksi ditemukan', style: AppTextStyles.h3),
            AppSizes.gapH8,
            const Text('Transaksi POS yang telah selesai akan muncul di sini.', style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            AppSizes.gapH16,
            Text(_errorMessage!, textAlign: TextAlign.center),
            AppSizes.gapH16,
            ElevatedButton(onPressed: () => _loadInvoices(refresh: true), child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

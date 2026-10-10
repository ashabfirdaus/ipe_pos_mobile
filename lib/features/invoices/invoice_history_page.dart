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
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  String? _loadMoreError;
  List<InvoiceModel> _invoices = [];
  int _totalInvoices = 0;

  int? _selectedStatus; // null = all, 1 = active, 0 = void
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInvoices();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // Load page berikutnya ketika scroll mendekati bagian bawah list (threshold 200px)
    if (currentScroll >= (maxScroll - 200)) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMoreInvoices();
      }
    }
  }

  Future<void> _loadInvoices({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _loadMoreError = null;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadMoreError = null;
    });

    final res = await ApiService.getInvoices(
      page: 1,
      status: _selectedStatus,
      search: _searchController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res.isSuccess && res.data != null) {
      final paginated = res.data!;
      setState(() {
        _invoices = List.from(paginated.items);
        _currentPage = paginated.currentPage;
        _hasMore = paginated.hasMore;
        _totalInvoices = paginated.total;
      });
    } else {
      setState(() {
        _errorMessage = res.message;
      });
    }
  }

  Future<void> _loadMoreInvoices() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    final nextPage = _currentPage + 1;
    final res = await ApiService.getInvoices(
      page: nextPage,
      status: _selectedStatus,
      search: _searchController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoadingMore = false;
    });

    if (res.isSuccess && res.data != null) {
      final paginated = res.data!;
      setState(() {
        _currentPage = paginated.currentPage;
        _invoices.addAll(paginated.items);
        _hasMore = paginated.hasMore;
        _totalInvoices = paginated.total;
      });
    } else {
      setState(() {
        _loadMoreError = res.message;
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
      body: SafeArea(
        top: false,
        child: Column(
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
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onSubmitted: (_) => _loadInvoices(refresh: true),
          ),
          AppSizes.gapH8,

          // Status Filter Chips & Result Counter
          Row(
            children: [
              const Text('Status:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              const Spacer(),
              if (!_isLoading && _totalInvoices > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_invoices.length}/$_totalInvoices data',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList() {
    final showFooter = _hasMore || _isLoadingMore || _loadMoreError != null;

    return RefreshIndicator(
      onRefresh: () => _loadInvoices(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSizes.md),
        itemCount: _invoices.length + (showFooter ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == _invoices.length) {
            return _buildLoadMoreFooter();
          }

          final inv = _invoices[index];
          final isVoid = inv.status == 0;

          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: isVoid
                    ? AppColors.errorContainer
                    : AppColors.primaryContainer,
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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isVoid
                          ? AppColors.errorContainer
                          : AppColors.successContainer,
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
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(CurrencyFormatter.formatDate(inv.createdAt),
                          style: AppTextStyles.caption),
                    ],
                  ),
                  if (inv.cashierName != null &&
                      inv.cashierName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Kasir: ${inv.cashierName}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isVoid &&
                      inv.voidByName != null &&
                      inv.voidByName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.cancel_outlined,
                            size: 13, color: AppColors.error),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Void oleh: ${inv.voidByName}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  AppSizes.gapH6,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        inv.paymentMethodName ?? 'Tunai',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        CurrencyFormatter.format(inv.grandTotal),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isVoid
                              ? AppColors.textSecondary
                              : AppColors.primary,
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
                _loadInvoices(refresh: true);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadMoreFooter() {
    if (_isLoadingMore) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Memuat transaksi berikutnya...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_loadMoreError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text(
              'Gagal memuat halaman berikutnya: $_loadMoreError',
              style: const TextStyle(fontSize: 12, color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _loadMoreInvoices,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary),
            AppSizes.gapH16,
            Text('Belum ada transaksi ditemukan', style: AppTextStyles.h3),
            AppSizes.gapH8,
            Text('Transaksi POS yang telah selesai akan muncul di sini.', style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
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

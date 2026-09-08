import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/pos_models.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  UserModel? _currentUser;
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final cached = await StorageService.getUserData();
    if (cached != null) {
      try {
        final json = jsonDecode(cached);
        setState(() {
          _currentUser = UserModel.fromJson(json);
        });
      } catch (_) {}
    }

    // Refresh profile from API
    setState(() => _isLoadingProfile = true);
    final res = await ApiService.getProfile();
    if (!mounted) return;
    setState(() => _isLoadingProfile = false);
    if (res.isSuccess && res.data != null) {
      setState(() {
        _currentUser = res.data;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari sesi kasir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Pengaturan Printer Thermal',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.printerSettings);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan API Server',
            onPressed: () async {
              await Navigator.of(context).pushNamed(AppRoutes.settings);
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar (Logout)',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserSession,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSizes.paddingPage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Card
              _buildGreetingCard(),
              AppSizes.gapH20,

              // Quick Actions Grid (Main POS modules)
              const Text('Menu Utama Kasir POS', style: AppTextStyles.h3),
              AppSizes.gapH12,
              _buildMenuGrid(),
              AppSizes.gapH24,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    final name = _currentUser?.name ?? 'Kasir / Staf POS';
    final role = _currentUser?.role ?? 'Kasir';

    return Container(
      width: double.infinity,
      padding: AppSizes.paddingCard,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Icon(
              Icons.person_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
          AppSizes.gapW16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $name',
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                AppSizes.gapH4,
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Peran: $role | POS Mobile',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingProfile)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    final menuItems = [
      _MenuItem(
        title: 'Kasir POS',
        subtitle: 'Transaksi penjualan & scan barcode',
        icon: Icons.point_of_sale_rounded,
        color: AppColors.primary,
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.pos),
      ),
      _MenuItem(
        title: 'Riwayat Transaksi',
        subtitle: 'Daftar invoice & pembatalan (void)',
        icon: Icons.receipt_long_rounded,
        color: AppColors.secondary,
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.invoices),
      ),
      // _MenuItem(
      //   title: 'Mutasi Barang',
      //   subtitle: 'Riwayat keluar masuk stok item',
      //   icon: Icons.inventory_rounded,
      //   color: const Color(0xFF00897B),
      //   onTap: () =>
      //       Navigator.of(context).pushNamed(AppRoutes.itemTransactions),
      // ),
      // _MenuItem(
      //   title: 'Lapor Pembayaran',
      //   subtitle: 'Konfirmasi bukti bayar masuk',
      //   icon: Icons.payment_rounded,
      //   color: const Color(0xFFD81B60),
      //   onTap: () =>
      //       Navigator.of(context).pushNamed(AppRoutes.paymentNotification),
      // ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: AppSizes.sm,
        mainAxisSpacing: AppSizes.sm,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            onTap: item.onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Icon(item.icon, color: item.color, size: 28),
                  ),
                  const Spacer(),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  AppSizes.gapH4,
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

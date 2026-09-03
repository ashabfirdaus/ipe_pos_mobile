import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routes/app_router.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/storage_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifikasi',
            onPressed: () {
              AppRouter.pushNamed(
                AppRoutes.details,
                arguments: {
                  'title': 'Notifikasi & Endpoints',
                  'content': 'Endpoint: ${ApiConfig.baseUrl}${ApiConfig.notifications}',
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar (Logout)',
            onPressed: () async {
              await StorageService.clearAuth();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSizes.paddingPage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            _buildWelcomeCard(),
            AppSizes.gapH16,

            // Config Information Section
            _buildSectionHeader('Konfigurasi Proyek (App & API Config)'),
            AppSizes.gapH8,
            _buildConfigCard(),
            AppSizes.gapH16,

            // Theme & Color Palette Section
            _buildSectionHeader('Pengaturan Warna (AppColors)'),
            AppSizes.gapH8,
            _buildColorsCard(),
            AppSizes.gapH16,

            // Routing & Navigation Section
            _buildSectionHeader('Manajemen Rute POS (AppRouter)'),
            AppSizes.gapH8,
            _buildNavigationCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.h3.copyWith(fontSize: 16),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: AppSizes.paddingCard,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat Datang di ${AppConfig.appName}',
            style: AppTextStyles.h2.copyWith(color: Colors.white),
          ),
          AppSizes.gapH8,
          Text(
            'Aplikasi Kasir & Point of Sale siap digunakan dengan arsitektur modular terstandarisasi.',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      child: Padding(
        padding: AppSizes.paddingCard,
        child: Column(
          children: [
            _buildInfoRow('Nama Aplikasi', AppConfig.appName),
            const Divider(height: 16),
            _buildInfoRow('Versi & Build', '${AppConfig.appVersion} (${AppConfig.buildNumber})'),
            const Divider(height: 16),
            _buildInfoRow('Environment', AppConfig.environment.name.toUpperCase()),
            const Divider(height: 16),
            _buildInfoRow('Base API URL', ApiConfig.baseUrl),
            const Divider(height: 16),
            _buildInfoRow('Auth Endpoint', ApiConfig.login),
            const Divider(height: 16),
            _buildInfoRow('Products Endpoint', ApiConfig.products),
            const Divider(height: 16),
            _buildInfoRow('Transactions Endpoint', ApiConfig.transactions),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        AppSizes.gapW8,
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildColorsCard() {
    return Card(
      child: Padding(
        padding: AppSizes.paddingCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Palet Warna Utama:', style: AppTextStyles.caption),
            AppSizes.gapH8,
            Row(
              children: [
                _buildColorChip('Primary', AppColors.primary),
                AppSizes.gapW8,
                _buildColorChip('Secondary', AppColors.secondary),
                AppSizes.gapW8,
                _buildColorChip('Success', AppColors.success),
                AppSizes.gapW8,
                _buildColorChip('Warning', AppColors.warning),
                AppSizes.gapW8,
                _buildColorChip('Error', AppColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorChip(String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
          ),
          AppSizes.gapH4,
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSizes.paddingCard,
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryContainer,
                child: Icon(Icons.point_of_sale, color: AppColors.primary),
              ),
              title: const Text('Navigasi dengan Argumen POS'),
              subtitle: const Text('AppRouter.pushNamed(AppRoutes.details, arguments: ...)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                AppRouter.pushNamed(
                  AppRoutes.details,
                  arguments: {
                    'title': 'Modul Transaksi POS',
                    'content': 'Mengakses endpoint API: ${ApiConfig.baseUrl}${ApiConfig.transactions}\n'
                        'Status Lingkungan: ${AppConfig.environment.name}\n'
                        'Koneksi Timeout: ${ApiConfig.connectTimeout.inSeconds} detik',
                  },
                );
              },
            ),
            const Divider(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.error.withValues(alpha: 0.15),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              ),
              title: const Text('Uji Coba Fallback Rute (404 Not Found)'),
              subtitle: const Text('Navigasi ke rute yang tidak terdaftar'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                AppRouter.pushNamed('/unknown-route-test');
              },
            ),
          ],
        ),
      ),
    );
  }
}

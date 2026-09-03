import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/storage_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  void _checkAuthAndNavigate() {
    _timer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;

      final hasToken = await StorageService.hasValidToken();
      if (!mounted) return;

      if (hasToken) {
        // Jika token sudah ada, langsung masuk ke Home POS
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      } else {
        // Jika belum ada token (akses pertama kali), arahkan ke Login
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                size: 72,
                color: Colors.white,
              ),
            ),
            AppSizes.gapH24,
            Text(
              AppConfig.appName,
              style: AppTextStyles.h1.copyWith(
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            AppSizes.gapH8,
            Text(
              'v${AppConfig.appVersion} (${AppConfig.environment.name})',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
            AppSizes.gapH32,
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

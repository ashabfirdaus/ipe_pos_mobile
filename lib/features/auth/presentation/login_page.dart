import 'package:flutter/material.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/storage_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    // Simulasi proses autentikasi kasir / admin ke ApiConfig.login
    await Future.delayed(const Duration(milliseconds: 1200));

    // Dummy token untuk simulasi berhasil login
    final generatedToken = 'jwt_token_${DateTime.now().millisecondsSinceEpoch}_${_usernameController.text.trim()}';

    // Simpan token ke LocalStorage (SharedPreferences) menggunakan keyAuthToken
    await StorageService.saveAuthToken(generatedToken);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login kasir berhasil! Selamat bekerja.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Pindah ke halaman utama POS dan hapus riwayat login dari stack navigasi
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  void _fillDemoCredentials() {
    _usernameController.text = 'kasir@ipe-pos.id';
    _passwordController.text = 'password123';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Logo & App Info
                _buildHeader(),
                AppSizes.gapH32,

                // Login Form Card
                _buildLoginForm(),
                AppSizes.gapH24,

                // Endpoint Info & Demo Helper
                _buildDemoHelper(),
                SizedBox(height: bottomInset > 0 ? bottomInset : 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.point_of_sale_rounded,
            size: 56,
            color: AppColors.primary,
          ),
        ),
        AppSizes.gapH16,
        Text(
          AppConfig.appName,
          style: AppTextStyles.h1.copyWith(color: AppColors.primary),
        ),
        AppSizes.gapH4,
        Text(
          'Silakan masuk dengan akun kasir / staf POS',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masuk Akun Kasir',
                style: AppTextStyles.h3,
              ),
              AppSizes.gapH16,

              // Email / Username Input
              TextFormField(
                controller: _usernameController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Username atau Email',
                  hintText: 'contoh: kasir@ipe-pos.id',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username/email tidak boleh kosong';
                  }
                  return null;
                },
              ),
              AppSizes.gapH16,

              // Password Input
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi',
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kata sandi tidak boleh kosong';
                  }
                  if (value.length < 6) {
                    return 'Kata sandi minimal 6 karakter';
                  }
                  return null;
                },
              ),
              AppSizes.gapH24,

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Masuk POS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemoHelper() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _fillDemoCredentials,
          icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
          label: const Text('Isi Akun Demo Cepat'),
        ),
        AppSizes.gapH16,
        Text(
          'Target Endpoint: ${ApiConfig.baseUrl}${ApiConfig.login}',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

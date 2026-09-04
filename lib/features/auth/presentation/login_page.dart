import 'package:flutter/material.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'password');

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

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
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final response = await ApiService.login(
      username: username,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login berhasil! Selamat datang, ${response.data?.name ?? username}.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    } else {
      setState(() {
        _errorMessage = response.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _fillDemoCredentials() {
    _usernameController.text = 'admin';
    _passwordController.text = 'password';
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
                AppSizes.gapH24,

                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        AppSizes.gapW8,
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSizes.gapH16,
                ],

                // Login Form Card
                _buildLoginForm(),
                AppSizes.gapH20,

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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            AppAssets.appIcon,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.point_of_sale_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
        ),
        AppSizes.gapH16,
        Text(
          AppConfig.appName,
          style: AppTextStyles.h1.copyWith(color: AppColors.primary),
        ),
        AppSizes.gapH4,
        Text(
          'Sistem Kasir & Transaksi POS Intipangan',
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

              // Username Input
              TextFormField(
                controller: _usernameController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'admin',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username tidak boleh kosong';
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _fillDemoCredentials,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('Isi Akun Default (admin)'),
            ),
            AppSizes.gapW12,
            IconButton(
              tooltip: 'Konfigurasi IP Server',
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        AppSizes.gapH12,
        Text(
          'API Server: ${ApiConfig.baseUrl}',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

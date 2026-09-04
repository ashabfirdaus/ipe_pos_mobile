import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/storage_service.dart';

class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({super.key});

  @override
  State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<ApiSettingsPage> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = StorageService.getBaseUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base URL tidak boleh kosong!')),
      );
      return;
    }

    await StorageService.saveBaseUrl(newUrl);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Konfigurasi API Server berhasil disimpan!'),
        backgroundColor: AppColors.success,
      ),
    );

    Navigator.of(context).pop();
  }

  void _resetToDefault() {
    _urlController.text = ApiConfig.defaultBaseUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan API Server'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dns_rounded, color: AppColors.primary),
                    AppSizes.gapW8,
                    Text('Konfigurasi URL REST API', style: AppTextStyles.h3),
                  ],
                ),
                AppSizes.gapH8,
                const Text(
                  'Sesuaikan IP Host dan Port backend server yang berjalan di jaringan lokal atau internet.',
                  style: AppTextStyles.bodySmall,
                ),
                AppSizes.gapH20,

                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'Base API URL',
                    hintText: 'http://192.168.1.6:8000/api',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.restore_rounded),
                      tooltip: 'Reset ke default',
                      onPressed: _resetToDefault,
                    ),
                  ),
                ),
                AppSizes.gapH12,

                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Dev (192.168.1.6:8000)', style: TextStyle(fontSize: 11)),
                      onPressed: () => _urlController.text = 'http://192.168.1.6:8000/api',
                    ),
                    ActionChip(
                      label: const Text('Emulator (10.0.2.2:8000)', style: TextStyle(fontSize: 11)),
                      onPressed: () => _urlController.text = 'http://10.0.2.2:8000/api',
                    ),
                    ActionChip(
                      label: const Text('Localhost (127.0.0.1:8000)', style: TextStyle(fontSize: 11)),
                      onPressed: () => _urlController.text = 'http://127.0.0.1:8000/api',
                    ),
                  ],
                ),
                AppSizes.gapH24,

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    child: const Text('Simpan Perubahan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

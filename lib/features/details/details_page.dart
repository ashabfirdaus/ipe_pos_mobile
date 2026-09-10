import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';

class DetailsPage extends StatelessWidget {
  final String title;
  final String content;

  const DetailsPage({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: AppSizes.paddingPage,
        child: Card(
          child: Padding(
            padding: AppSizes.paddingCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                      ),
                    ),
                    AppSizes.gapW16,
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.h3,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Text(
                  'Detail Informasi Rute & Data:',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                ),
                AppSizes.gapH8,
                Text(
                  content,
                  style: AppTextStyles.bodyMedium,
                ),
                AppSizes.gapH24,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Kembali ke Beranda'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

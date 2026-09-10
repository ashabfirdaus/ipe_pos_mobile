import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/api_service.dart';

class PaymentNotificationPage extends StatefulWidget {
  const PaymentNotificationPage({super.key});

  @override
  State<PaymentNotificationPage> createState() => _PaymentNotificationPageState();
}

class _PaymentNotificationPageState extends State<PaymentNotificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nominalController = TextEditingController(text: '500000');
  final _descriptionController = TextEditingController(text: 'Pembayaran invoice pelanggan');
  String _selectedMethod = 'BCA Transfer';

  final List<String> _methods = [
    'BCA Transfer',
    'Mandiri Transfer',
    'BRI Transfer',
    'BNI Transfer',
    'QRIS',
    'Tunai Kasir',
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _nominalController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final nominal = double.tryParse(_nominalController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pembayaran harus lebih dari 0!'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final res = await ApiService.savePaymentNotification(
      paymentMethod: _selectedMethod,
      nominal: nominal,
      description: _descriptionController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty ? res.message : 'Notifikasi pembayaran berhasil disimpan!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty ? res.message : 'Gagal menyimpan notifikasi pembayaran'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lapor Notifikasi Pembayaran'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Formulir Laporan Pembayaran', style: AppTextStyles.h3),
                    AppSizes.gapH8,
                    const Text(
                      'Simpan bukti dan notifikasi konfirmasi pembayaran masuk dari pelanggan.',
                      style: AppTextStyles.bodySmall,
                    ),
                    AppSizes.gapH20,

                    // Payment Method
                    DropdownButtonFormField<String>(
                      initialValue: _selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Metode Pembayaran',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMethod = val);
                      },
                    ),
                    AppSizes.gapH16,

                    // Nominal
                    TextFormField(
                      controller: _nominalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nominal Pembayaran (Rp)',
                        prefixIcon: Icon(Icons.monetization_on_outlined),
                        prefixText: 'Rp ',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Nominal wajib diisi';
                        return null;
                      },
                    ),
                    AppSizes.gapH16,

                    // Description / Ref
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan / No Referensi Transaksi',
                        hintText: 'contoh: Pembayaran invoice pelanggan INV-2026-001',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                      maxLines: 3,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Keterangan wajib diisi';
                        return null;
                      },
                    ),
                    AppSizes.gapH24,

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleSubmit,
                        icon: _isLoading ? null : const Icon(Icons.send_rounded),
                        label: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Kirim Notifikasi Pembayaran'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

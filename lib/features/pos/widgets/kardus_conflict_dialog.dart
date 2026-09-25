import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/models/pos_models.dart';

class KardusConflictHelper {
  /// Memeriksa dan menangani konflik antara Kardus dan Satuan di keranjang.
  /// Mengembalikan `true` jika proses penambahan produk boleh dilanjutkan,
  /// atau `false` jika dibatalkan karena konflik.
  static Future<bool> checkAndResolve({
    required BuildContext context,
    required ProductModel product,
    required List<CartItemModel> cartItems,
    required VoidCallback onCartModified,
  }) async {
    // KASUS 1: Yang di-scan adalah KARDUS
    if (product.isKardus) {
      final kardusCode = product.wrapperQrcode?.isNotEmpty == true
          ? product.wrapperQrcode!
          : (product.qrcode ?? '');

      // Cari item Satuan untuk produk yang sama
      final conflictingSatuanIndex = cartItems.indexWhere((item) {
        if (item.isKardus || item.product.itemId != product.itemId) return false;

        // Cek apakah ada QR code satuan yang terdaftar di dalam kardus ini
        final hasContainedQr = item.activeCodes.any(
          (code) => product.containedQrcodes.contains(code),
        );
        if (hasContainedQr) return true;

        // Cek jika satuan memiliki wrapper_qrcode yang sama
        if (item.product.wrapperQrcode != null &&
            kardusCode.isNotEmpty &&
            item.product.wrapperQrcode == kardusCode) {
          return true;
        }

        return false;
      });

      if (conflictingSatuanIndex >= 0) {
        final satuanItem = cartItems[conflictingSatuanIndex];
        final conflictingCodes = satuanItem.activeCodes
            .where((code) =>
                product.containedQrcodes.contains(code) ||
                (satuanItem.product.wrapperQrcode != null &&
                    satuanItem.product.wrapperQrcode == kardusCode))
            .toList();

        final kardusCapacity = product.qrStock.toInt();
        final unitName = product.unit ?? 'pcs';

        final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Konflik Satuan & Kardus',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Item Satuan berikut sudah ada di dalam keranjang:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        satuanItem.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (conflictingCodes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'QR Satuan: ${conflictingCodes.join(', ')}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kardus yang baru di-scan berisi $kardusCapacity $unitName dan mencakup item satuan tersebut.\n\nApakah Anda ingin menggantinya menjadi Kardus Utuh?',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Batal Scan Kardus',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Beli Kardus Utuh ($kardusCapacity $unitName)'),
              ),
            ],
          ),
        );

        if (proceed != true) {
          return false;
        }

        // Jika kasir memilih Beli Kardus Utuh:
        // Hapus QR satuan yang berkonflik dari item Satuan
        if (conflictingCodes.isNotEmpty) {
          satuanItem.activeCodes.removeWhere((c) => conflictingCodes.contains(c));
          satuanItem.qrcodes.removeWhere((c) => conflictingCodes.contains(c));
          satuanItem.qty -= conflictingCodes.length;
        } else {
          // Jika tidak ada code spesifik tapi wrapper sama, kurangi qty 1
          satuanItem.qty -= 1;
        }

        // Jika satuan habis atau QR kodenya kosong (jika asalnya berbasis QR), hapus baris satuan
        if (satuanItem.qty <= 0 || (conflictingCodes.isNotEmpty && satuanItem.activeCodes.isEmpty)) {
          cartItems.removeAt(conflictingSatuanIndex);
        }

        onCartModified();
        return true;
      }
    }

    // KASUS 2: Yang di-scan adalah SATUAN, tapi Kardus-nya SUDAH ada di keranjang
    if (!product.isKardus) {
      final satuanQr = product.qrcode?.isNotEmpty == true
          ? product.qrcode!
          : '';

      final kardusItem = cartItems.firstWhereOrNull((item) {
        if (!item.isKardus || item.product.itemId != product.itemId) return false;

        if (satuanQr.isNotEmpty && item.product.containedQrcodes.contains(satuanQr)) {
          return true;
        }

        if (product.wrapperQrcode != null &&
            item.activeCodes.contains(product.wrapperQrcode)) {
          return true;
        }

        return false;
      });

      if (kardusItem != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Item Satuan "$satuanQr" sudah termasuk di dalam Kardus "${kardusItem.product.name}" di keranjang!',
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 2),
            ),
          );
        return false;
      }
    }

    return true;
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

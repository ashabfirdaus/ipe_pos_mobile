import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/offline_sync_service.dart';

/// Global wrapper yang menampilkan status bar saat:
/// 1. Sedang proses SINKRONISASI data (biru dengan indikator putar)
/// 2. Selesai SINKRONISASI (hijau selama 3 detik)
/// 3. Perangkat OFFLINE (merah peringatan)
/// Saat ONLINE dan tidak ada proses sinkronisasi, layar 100% bersih tanpa ruang tambahan.
class GlobalNetworkStatusBar extends StatefulWidget {
  final Widget child;

  const GlobalNetworkStatusBar({
    super.key,
    required this.child,
  });

  @override
  State<GlobalNetworkStatusBar> createState() => _GlobalNetworkStatusBarState();
}

class _GlobalNetworkStatusBarState extends State<GlobalNetworkStatusBar> {
  bool _isChecking = false;

  Future<void> _handleRefreshConnection() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final isConnected = await OfflineSyncService.instance.checkConnectivity();

    if (!mounted) return;
    setState(() => _isChecking = false);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isConnected
                    ? 'Koneksi pulih! Terhubung ke server POS.'
                    : 'Masih offline. Server POS belum dapat dijangkau.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
          ],
        ),
        backgroundColor: isConnected ? AppColors.success : AppColors.error,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineSyncService.instance.isOnlineNotifier,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: OfflineSyncService.instance.isSyncingNotifier,
          builder: (context, isSyncing, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: OfflineSyncService.instance.syncStatusMessageNotifier,
              builder: (context, syncMsg, _) {
                final showSync = isSyncing || (syncMsg != null && syncMsg.isNotEmpty);
                final showOffline = !isOnline;

                // 1. Saat ONLINE & Tidak ada proses sinkronisasi: 100% bersih tanpa header tambahan
                if (!showSync && !showOffline) {
                  return widget.child;
                }

                final topPadding = MediaQuery.of(context).padding.top;

                // Tentukan warna bar
                final Color barColor = showSync
                    ? (isSyncing ? const Color(0xFF2563EB) : AppColors.success)
                    : AppColors.error;

                return ValueListenableBuilder<int>(
                  valueListenable: OfflineSyncService.instance.pendingCountNotifier,
                  builder: (context, pendingCount, _) {
                    Widget iconWidget;
                    String text;

                    if (showSync) {
                      if (isSyncing) {
                        iconWidget = const SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        );
                        text = syncMsg ?? 'Menyinkronkan data ke server...';
                      } else {
                        iconWidget = const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 13,
                          color: Colors.white,
                        );
                        text = syncMsg ?? 'Sinkronisasi data selesai!';
                      }
                    } else {
                      // Offline
                      iconWidget = const Icon(
                        Icons.cloud_off_rounded,
                        size: 13,
                        color: Colors.white,
                      );
                      text = pendingCount > 0
                          ? 'Offline • Simpan Lokal ($pendingCount antrean)'
                          : 'Offline • Transaksi Disimpan Lokal';
                    }

                    return Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            color: barColor,
                            padding: EdgeInsets.only(top: topPadding),
                            child: InkWell(
                              onTap: showOffline ? _handleRefreshConnection : null,
                              child: Container(
                                height: 26,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    iconWidget,
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        text,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (showOffline) ...[
                                      const SizedBox(width: 6),
                                      _isChecking
                                          ? const SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Cek',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Content utama tanpa double status bar padding
                          Expanded(
                            child: MediaQuery.removePadding(
                              context: context,
                              removeTop: true,
                              child: widget.child,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/pos_models.dart';
import 'api_service.dart';

class OfflineTransactionItem {
  final String localId;
  final String offlineCode;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final InvoiceModel localInvoice;
  final String? syncError;

  OfflineTransactionItem({
    required this.localId,
    required this.offlineCode,
    required this.createdAt,
    required this.payload,
    required this.localInvoice,
    this.syncError,
  });

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'offline_code': offlineCode,
      'created_at': createdAt.toIso8601String(),
      'payload': payload,
      'local_invoice': {
        'id': localInvoice.id,
        'pos_invoice_code': localInvoice.invoiceNo,
        'created_at': localInvoice.createdAt,
        'status': localInvoice.status,
        'branch_name': localInvoice.branchName,
        'warehouse_name': localInvoice.warehouseName,
        'payment_method_name': localInvoice.paymentMethodName,
        'promo_name': localInvoice.promoName,
        'cashier_name': localInvoice.cashierName,
        'sub_total': localInvoice.subTotal,
        'discount': localInvoice.discount,
        'ppn': localInvoice.ppn,
        'grand_total': localInvoice.grandTotal,
        'cash': localInvoice.cash,
        'change': localInvoice.change,
        'items': localInvoice.items
            .map((it) => {
                  'item_id': it.itemId,
                  'item_name': it.itemName,
                  'qty': it.qty,
                  'price': it.price,
                  'discount': it.discount,
                  'sub_total': it.subTotal,
                  'qrcode': it.qrcode,
                  'wrapper_qrcode': it.wrapperQrcode,
                  'unit': it.unit,
                  'item_code': it.itemCode,
                  'is_kardus': it.isKardus,
                })
            .toList(),
      },
      'sync_error': syncError,
    };
  }

  factory OfflineTransactionItem.fromJson(Map<String, dynamic> json) {
    return OfflineTransactionItem(
      localId: json['local_id']?.toString() ?? '',
      offlineCode: json['offline_code']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      payload: json['payload'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['payload'])
          : <String, dynamic>{},
      localInvoice: InvoiceModel.fromJson(
        json['local_invoice'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['local_invoice'])
            : <String, dynamic>{},
      ),
      syncError: json['sync_error']?.toString(),
    );
  }
}

class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  static const String _keyPendingTransactions = 'offline_pending_transactions';
  static const String _keyCachedInitialData = 'offline_cached_initial_data';

  /// ValueNotifier untuk memantau jumlah antrean offline secara reaktif di AppBar
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  /// ValueNotifier untuk memantau status koneksi online/offline secara live
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);

  Timer? _heartbeatTimer;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Inisialisasi awal saat aplikasi dibuka
  Future<void> init() async {
    await updatePendingCount();
    startConnectivityMonitoring();
  }

  /// Mulai monitoring koneksi ke server secara berkala
  void startConnectivityMonitoring({Duration interval = const Duration(seconds: 15)}) {
    _heartbeatTimer?.cancel();
    checkConnectivity();
    _heartbeatTimer = Timer.periodic(interval, (_) => checkConnectivity());
  }

  /// Hentikan monitoring koneksi
  void stopConnectivityMonitoring() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Cek konektivitas riil ke API server
  Future<bool> checkConnectivity() async {
    try {
      final uri = Uri.parse(ApiConfig.baseUrl);
      final socket = await Socket.connect(
        uri.host,
        uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80),
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();

      final wasOffline = !isOnlineNotifier.value;
      isOnlineNotifier.value = true;

      // Jika jaringan baru saja pulih dan ada antrean transaksi, picu auto-sync
      if (wasOffline && pendingCountNotifier.value > 0 && !_isSyncing) {
        syncPendingTransactions();
      }

      return true;
    } catch (_) {
      isOnlineNotifier.value = false;
      return false;
    }
  }

  /// Update status online secara instan saat ada panggilan API yang berhasil / gagal
  void setOnlineStatus(bool online) {
    final wasOffline = !isOnlineNotifier.value;
    isOnlineNotifier.value = online;
    if (online && wasOffline && pendingCountNotifier.value > 0 && !_isSyncing) {
      syncPendingTransactions();
    }
  }

  /// Update count notifier
  Future<int> updatePendingCount() async {
    try {
      final items = await getPendingTransactions();
      pendingCountNotifier.value = items.length;
      return items.length;
    } catch (_) {
      return 0;
    }
  }

  /// Cache master initial data (produk, cabang, gudang, payment methods, promos)
  Future<void> cacheInitialData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCachedInitialData, jsonEncode(data));
    } catch (_) {}
  }

  /// Ambil cached initial data saat offline
  Future<Map<String, dynamic>?> getCachedInitialData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCachedInitialData);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Simpan transaksi offline ke antrean lokal
  Future<InvoiceModel> saveOfflineTransaction({
    required Map<String, dynamic> payload,
    required List<CartItemModel> cartItems,
    String? branchName,
    String? warehouseName,
    String? paymentMethodName,
    String? promoName,
    String? cashierName,
    double discount = 0,
    double subTotal = 0,
    double grandTotal = 0,
    double cash = 0,
    double change = 0,
  }) async {
    final now = DateTime.now();
    final dateStr = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final randomSuffix = (now.millisecond % 1000).toString().padLeft(3, '0');
    final offlineCode = 'OFFLINE-$dateStr-$timeStr-$randomSuffix';
    final localId = 'local_${now.millisecondsSinceEpoch}';

    // Rangkai items InvoiceItemModel
    final invoiceItems = cartItems
        .map(
          (item) => InvoiceItemModel(
            itemId: item.product.itemId,
            itemName: item.product.name,
            qty: item.qty,
            price: item.price,
            discount: item.discount,
            subTotal: item.subTotal,
            qrcode: item.isKardus
                ? null
                : (item.qrcodes.isNotEmpty ? item.qrcodes.join(', ') : (item.qrcode.isNotEmpty ? item.qrcode : null)),
            wrapperQrcode: item.isKardus
                ? (item.wrapperQrcodes.isNotEmpty
                    ? item.wrapperQrcodes.join(', ')
                    : item.product.wrapperQrcode)
                : null,
            unit: item.product.unit,
            itemCode: item.product.code,
            isKardus: item.isKardus,
          ),
        )
        .toList();

    // Buat objek InvoiceModel lokal untuk dicetak nota fisiknya
    final localInvoice = InvoiceModel(
      id: localId,
      invoiceNo: offlineCode,
      createdAt: now.toIso8601String(),
      status: 1,
      branchName: branchName,
      warehouseName: warehouseName,
      paymentMethodName: paymentMethodName ?? 'Tunai',
      promoName: promoName,
      cashierName: cashierName ?? 'Kasir',
      subTotal: subTotal,
      discount: discount,
      ppn: 0,
      grandTotal: grandTotal,
      cash: cash >= grandTotal ? cash : grandTotal,
      change: change,
      items: invoiceItems,
    );

    // Siapkan payload dengan penanda offline
    final enrichedPayload = Map<String, dynamic>.from(payload);
    enrichedPayload['offline_code'] = offlineCode;
    enrichedPayload['date'] = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    enrichedPayload['created_at'] = now.toIso8601String();

    final itemRecord = OfflineTransactionItem(
      localId: localId,
      offlineCode: offlineCode,
      createdAt: now,
      payload: enrichedPayload,
      localInvoice: localInvoice,
    );

    final prefs = await SharedPreferences.getInstance();
    final existingRaw = prefs.getStringList(_keyPendingTransactions) ?? <String>[];
    existingRaw.add(jsonEncode(itemRecord.toJson()));
    await prefs.setStringList(_keyPendingTransactions, existingRaw);

    await updatePendingCount();
    return localInvoice;
  }

  /// Ambil daftar antrean transaksi offline
  Future<List<OfflineTransactionItem>> getPendingTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyPendingTransactions) ?? <String>[];
      final result = <OfflineTransactionItem>[];
      for (final raw in list) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            result.add(OfflineTransactionItem.fromJson(decoded));
          }
        } catch (_) {}
      }
      return result;
    } catch (_) {
      return <OfflineTransactionItem>[];
    }
  }

  /// Hapus satu transaksi dari antrean
  Future<void> removePendingTransaction(String localId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyPendingTransactions) ?? <String>[];
      final updatedList = <String>[];
      for (final raw in list) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic> && decoded['local_id'] == localId) {
            continue; // Hapus
          }
          updatedList.add(raw);
        } catch (_) {}
      }
      await prefs.setStringList(_keyPendingTransactions, updatedList);
      await updatePendingCount();
    } catch (_) {}
  }

  /// Eksekusi sinkronisasi seluruh antrean transaksi offline ke server backend
  Future<({int total, int success, int failed, List<String> messages})> syncPendingTransactions() async {
    if (_isSyncing) {
      return (total: 0, success: 0, failed: 0, messages: ['Sinkronisasi sedang berjalan...']);
    }

    _isSyncing = true;
    final items = await getPendingTransactions();
    if (items.isEmpty) {
      _isSyncing = false;
      await updatePendingCount();
      return (total: 0, success: 0, failed: 0, messages: ['Tidak ada antrean transaksi offline.']);
    }

    int successCount = 0;
    int failedCount = 0;
    final messages = <String>[];

    for (final item in items) {
      try {
        final res = await ApiService.saveInvoice(item.payload);
        if (res.isSuccess) {
          successCount++;
          await removePendingTransaction(item.localId);
          final serverCode = res.data?.invoiceNo ?? item.offlineCode;
          messages.add('Berhasil sinkron: ${item.offlineCode} -> $serverCode');
        } else {
          failedCount++;
          messages.add('Gagal (${item.offlineCode}): ${res.message}');
          // Jika gagal karena masalah koneksi (offline lagi), hentikan iterasi
          if (res.statusCode == 503 || res.statusCode == 408) {
            messages.add('Koneksi internet terputus, sinkronisasi ditunda.');
            break;
          }
        }
      } catch (e) {
        failedCount++;
        messages.add('Error (${item.offlineCode}): $e');
        break;
      }
    }

    _isSyncing = false;
    await updatePendingCount();

    return (
      total: items.length,
      success: successCount,
      failed: failedCount,
      messages: messages,
    );
  }
}

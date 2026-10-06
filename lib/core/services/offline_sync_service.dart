import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
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

class OfflineSyncService with WidgetsBindingObserver {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  static const String _keyPendingTransactions = 'offline_pending_transactions';
  static const String _keyCachedInitialData = 'offline_cached_initial_data';
  static const String _keyCachedProducts = 'offline_cached_products';

  /// ValueNotifier untuk memantau jumlah antrean offline secara reaktif di AppBar
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  /// ValueNotifier untuk memantau status koneksi online/offline secara live
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);

  Timer? _heartbeatTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Penanda apakah aplikasi sedang diminimize / di background
  bool _isAppInBackground = false;
  bool get isAppInBackground => _isAppInBackground;

  /// ValueNotifier untuk memantau status sedang proses sinkronisasi atau tidak
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  /// ValueNotifier untuk memantau pesan status sinkronisasi terkini
  final ValueNotifier<String?> syncStatusMessageNotifier =
      ValueNotifier<String?>(null);

  bool get isSyncing => isSyncingNotifier.value;

  /// Inisialisasi awal saat aplikasi dibuka
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await updatePendingCount();
    await getCachedProducts(); // Pre-warm cache produk ke RAM
    startConnectivityMonitoring();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopConnectivityMonitoring();
  }

  /// Menangani perubahan siklus hidup aplikasi (minimize / buka kembali)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInBackground = false;
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _isAppInBackground = true;
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _isAppInBackground = true;
        break;
    }
  }

  /// Saat aplikasi diminimize ke background:
  /// Hentikan timer heartbeat agar tidak memicu kegagalan socket tiruan saat OS membatasi network
  void _onAppPaused() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Saat aplikasi dibuka kembali dari background:
  /// Aktifkan kembali heartbeat dan segera verifikasi koneksi dengan retry otomatis
  void _onAppResumed() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!_isAppInBackground) {
          checkConnectivity();
        }
      },
    );

    // Beri sedikit jeda (250ms) agar network interface OS selesai unfreeze, lalu cek koneksi
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!_isAppInBackground) {
        checkConnectivity(retryOnFail: true);
      }
    });
  }

  /// Mulai monitoring koneksi secara hybrid (connectivity_plus + Socket.connect)
  void startConnectivityMonitoring(
      {Duration interval = const Duration(seconds: 30)}) {
    _heartbeatTimer?.cancel();
    _connectivitySubscription?.cancel();

    // 1. Cek konektivitas awal
    checkConnectivity();

    // 2. Event-driven listener dari connectivity_plus (respon instan saat WiFi/Data hidup atau mati)
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      // Abaikan event saat aplikasi di background / minimize
      if (_isAppInBackground) return;

      if (results.contains(ConnectivityResult.none)) {
        // Konfirmasi dengan socket check sebelum menyimpulkan offline (mencegah false alarm)
        checkConnectivity();
      } else {
        // Jaringan HP baru saja tersambung -> Langsung uji reachability server tanpa tunggu timer
        checkConnectivity(retryOnFail: true);
      }
    });

    // 3. Heartbeat berkala sebagai fallback verifikasi reachability server backend
    _heartbeatTimer = Timer.periodic(interval, (_) {
      if (!_isAppInBackground) {
        checkConnectivity();
      }
    });
  }

  /// Hentikan monitoring koneksi
  void stopConnectivityMonitoring() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Cek konektivitas riil ke API server
  /// [retryOnFail]: Jika true, coba lagi 1x setelah delay singkat (sangat berguna saat baru resume)
  Future<bool> checkConnectivity({bool retryOnFail = false}) async {
    // Jangan ubah status jika aplikasi sedang di background / minimize
    if (_isAppInBackground) {
      return isOnlineNotifier.value;
    }

    bool success = await _testSocketConnect();

    // Jika gagal dan retryOnFail aktif (misal radio OS baru bangun dari sleep),
    // tunggu sebentar lalu coba sekali lagi sebelum memutuskan offline
    if (!success && retryOnFail && !_isAppInBackground) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!_isAppInBackground) {
        success = await _testSocketConnect();
      }
    }

    if (_isAppInBackground) {
      return isOnlineNotifier.value;
    }

    if (success) {
      final wasOffline = !isOnlineNotifier.value;
      isOnlineNotifier.value = true;

      // Jika jaringan baru saja pulih dan ada antrean transaksi, picu auto-sync
      if (wasOffline && pendingCountNotifier.value > 0 && !isSyncing) {
        syncPendingTransactions();
      }

      return true;
    } else {
      isOnlineNotifier.value = false;
      return false;
    }
  }

  Future<bool> _testSocketConnect() async {
    try {
      final uri = Uri.parse(ApiConfig.baseUrl);
      final socket = await Socket.connect(
        uri.host,
        uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80),
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update status online secara instan saat ada panggilan API yang berhasil / gagal
  void setOnlineStatus(bool online) {
    // Abaikan error koneksi jika aplikasi sedang di background / minimize
    if (_isAppInBackground && !online) {
      return;
    }

    final wasOffline = !isOnlineNotifier.value;
    isOnlineNotifier.value = online;
    if (online && wasOffline && pendingCountNotifier.value > 0 && !isSyncing) {
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

  List<ProductModel>? _memoryCachedProducts;

  /// Menghapus seluruh data stok & produk yang tersimpan di cache lokal (RAM + Disk)
  Future<void> clearCachedProducts() async {
    _memoryCachedProducts = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCachedProducts);
    } catch (_) {}
  }

  /// Menyimpan daftar produk ke penyimpanan lokal perangkat (RAM + Disk).
  /// Jika [clearPrevious] bernilai true, data stok sebelumnya akan dihapus terlebih dahulu
  /// dari RAM dan Disk sebelum memasang stok yang baru.
  Future<void> cacheProducts(
    List<ProductModel> products, {
    bool clearPrevious = false,
  }) async {
    try {
      final productMap = <String, ProductModel>{};

      if (clearPrevious) {
        // Hapus data stok sebelumnya terlebih dahulu sebelum memasang stok baru
        _memoryCachedProducts = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyCachedProducts);
      } else {
        final existingProducts = await getCachedProducts();
        for (final p in existingProducts) {
          final key = '${p.id}_${p.itemId}_${p.qrcode ?? ''}_${p.isKardus}';
          productMap[key] = p;
        }
      }

      for (final p in products) {
        final key = '${p.id}_${p.itemId}_${p.qrcode ?? ''}_${p.isKardus}';
        productMap[key] = p;
      }

      // Update RAM cache seketika agar pencarian offline secepat kilat (0 ms)
      _memoryCachedProducts = productMap.values.toList();

      // Tulis ke disk (SharedPreferences) di latar belakang
      final prefs = await SharedPreferences.getInstance();
      final jsonList = productMap.values.map((p) => p.toJson()).toList();
      await prefs.setString(_keyCachedProducts, jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Simpan atau perbarui 1 produk ke dalam cache offline tanpa menghapus stok lainnya
  Future<void> saveOrUpdateProductInCache(ProductModel product) async {
    await cacheProducts([product], clearPrevious: false);
  }

  /// Mengambil seluruh data produk (Mengutamakan RAM Cache instan)
  Future<List<ProductModel>> getCachedProducts() async {
    // 1. Jika sudah ada di RAM, kembalikan instan tanpa baca disk
    if (_memoryCachedProducts != null && _memoryCachedProducts!.isNotEmpty) {
      return _memoryCachedProducts!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCachedProducts);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final list = decoded
              .whereType<Map>()
              .map((item) =>
                  ProductModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
          _memoryCachedProducts = list;
          return list;
        }
      }
    } catch (_) {}
    return [];
  }

  /// Mencari produk di penyimpanan lokal berdasarkan QR Code, Barcode, SKU, atau akhiran digit
  Future<ProductModel?> findProductOffline(String queryCode) async {
    final cleanCode = queryCode.trim().toLowerCase();
    if (cleanCode.isEmpty || cleanCode == 'null') return null;

    final products = await getCachedProducts();
    if (products.isEmpty) return null;

    // 1. PRIORITAS UTAMA (Sama persis seperti Backend Online):
    // Cek apakah kode yang discan adalah QR KARDUS (wrapper_qrcode)
    for (final p in products) {
      if (p.isKardus) {
        final qr = p.qrcode?.trim().toLowerCase();
        final wrapper = p.wrapperQrcode?.trim().toLowerCase();
        if (qr == cleanCode || wrapper == cleanCode) {
          return p;
        }
      }
    }

    // 2. PRIORITAS KEDUA: Cocok persis pada QR Code SATUAN (kemasan fisik)
    for (final p in products) {
      if (!p.isKardus) {
        final qr = p.qrcode?.trim().toLowerCase();
        if (qr == cleanCode) {
          return p;
        }
      }
    }

    // 3. PRIORITAS KETIGA: Cocok pada daftar child QR (contained_qrcodes di dalam kardus)
    for (final p in products) {
      if (p.containedQrcodes.any((c) => c.trim().toLowerCase() == cleanCode)) {
        return p;
      }
    }

    // 4. PRIORITAS KEEMPAT: Cocok persis pada Barcode fisik barang (EAN-13)
    for (final p in products) {
      final barcode = p.barcode?.trim().toLowerCase();
      if (barcode == cleanCode) {
        return p;
      }
    }

    // 5. PRIORITAS KELIMA: Cocok persis pada Kode Barang (Item Code / SKU)
    for (final p in products) {
      final code = p.code?.trim().toLowerCase();
      if (code == cleanCode) {
        return p;
      }
    }

    // 6. PRIORITAS KEENAM: Suffix matching (pencocokan 3-4 digit terakhir kode)
    // Utamakan Kardus terlebih dahulu jika berakhiran kode tersebut
    for (final p in products) {
      if (p.isKardus) {
        final qr = p.qrcode?.trim().toLowerCase() ?? '';
        final wrapper = p.wrapperQrcode?.trim().toLowerCase() ?? '';
        if ((qr.isNotEmpty && qr.endsWith(cleanCode)) ||
            (wrapper.isNotEmpty && wrapper.endsWith(cleanCode))) {
          return p;
        }
      }
    }
    for (final p in products) {
      if (!p.isKardus) {
        final qr = p.qrcode?.trim().toLowerCase() ?? '';
        final barcode = p.barcode?.trim().toLowerCase() ?? '';
        if ((qr.isNotEmpty && qr.endsWith(cleanCode)) ||
            (barcode.isNotEmpty && barcode.endsWith(cleanCode))) {
          return p;
        }
      }
    }

    return null;
  }

  /// Mencari daftar produk di penyimpanan lokal berdasarkan QR Code, Barcode, SKU, atau akhiran digit
  Future<List<ProductModel>> searchProductsOffline(String queryCode) async {
    final cleanCode = queryCode.trim().toLowerCase();
    if (cleanCode.isEmpty || cleanCode == 'null') return [];

    final products = await getCachedProducts();
    if (products.isEmpty) return [];

    final results = <ProductModel>[];
    final seenKeys = <String>{};

    void addMatch(ProductModel p) {
      final key = '${p.id}_${p.itemId}_${p.qrcode ?? ''}_${p.isKardus}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        results.add(p);
      }
    }

    // 1. Prioritas 1: Cocok persis sebagai QR Kardus
    for (final p in products) {
      if (p.isKardus) {
        final qr = p.qrcode?.trim().toLowerCase();
        final wrapper = p.wrapperQrcode?.trim().toLowerCase();
        if (qr == cleanCode || wrapper == cleanCode) {
          addMatch(p);
        }
      }
    }

    // 2. Prioritas 2: Cocok persis pada QR Code Satuan
    for (final p in products) {
      if (!p.isKardus) {
        final qr = p.qrcode?.trim().toLowerCase();
        if (qr == cleanCode) {
          addMatch(p);
        }
      }
    }

    // 3. Prioritas 3: Cocok pada child QR (contained_qrcodes)
    for (final p in products) {
      if (p.containedQrcodes.any((c) => c.trim().toLowerCase() == cleanCode)) {
        addMatch(p);
      }
    }

    // 4. Prioritas 4: Cocok persis pada Barcode fisik atau SKU
    for (final p in products) {
      final barcode = p.barcode?.trim().toLowerCase();
      final code = p.code?.trim().toLowerCase();
      if (barcode == cleanCode || code == cleanCode) {
        addMatch(p);
      }
    }

    // 5. Prioritas 5: Suffix / partial matching (3-4 digit terakhir)
    for (final p in products) {
      if (p.isKardus) {
        final qr = p.qrcode?.trim().toLowerCase() ?? '';
        final wrapper = p.wrapperQrcode?.trim().toLowerCase() ?? '';
        if ((qr.isNotEmpty && qr.endsWith(cleanCode)) ||
            (wrapper.isNotEmpty && wrapper.endsWith(cleanCode))) {
          addMatch(p);
        }
      }
    }
    for (final p in products) {
      if (!p.isKardus) {
        final qr = p.qrcode?.trim().toLowerCase() ?? '';
        final barcode = p.barcode?.trim().toLowerCase() ?? '';
        final code = p.code?.trim().toLowerCase() ?? '';
        final name = p.name.trim().toLowerCase();
        if ((qr.isNotEmpty && qr.endsWith(cleanCode)) ||
            (barcode.isNotEmpty && barcode.endsWith(cleanCode)) ||
            (code.isNotEmpty && code.endsWith(cleanCode)) ||
            (cleanCode.length >= 3 && name.contains(cleanCode))) {
          addMatch(p);
        }
      }
    }

    return results;
  }

  /// Background sync untuk mengunduh katalog produk & seluruh lembar QR stok saat online (Solusi 2)
  Future<void> syncProductsCatalog({int? warehouseId, int? branchId}) async {
    if (isSyncingNotifier.value) return;
    try {
      isSyncingNotifier.value = true;
      syncStatusMessageNotifier.value =
          'Memperbarui katalog produk & stok QR...';

      // 1. Unduh katalog visual per master produk (autoCache: false agar tidak disimpan sebagian)
      final catalogRes = await ApiService.getProducts(
        warehouseId: warehouseId,
        branchId: branchId,
        limit: 1000,
        autoCache: false,
      );

      // 2. Unduh seluruh lembar QR Code fisik stok yang aktif di gudang
      final stockRes = await ApiService.getAllStockQrcodes(
        warehouseId: warehouseId,
        branchId: branchId,
      );

      final allItems = <ProductModel>[];
      if (catalogRes.isSuccess && catalogRes.data != null) {
        allItems.addAll(catalogRes.data!);
      }
      if (stockRes.isSuccess && stockRes.data != null) {
        allItems.addAll(stockRes.data!);
      }

      if (allItems.isNotEmpty) {
        // Pastikan data stok sebelumnya dihapus dulu sebelum memasang stok baru
        await clearCachedProducts();
        await cacheProducts(allItems, clearPrevious: true);

        final catalogCount = catalogRes.data?.length ?? 0;
        final qrCount = stockRes.data?.length ?? 0;
        final msg = qrCount > 0
            ? '$catalogCount Produk & $qrCount QR Stok siap offline'
            : 'Katalog ($catalogCount produk) siap offline';
        syncStatusMessageNotifier.value = msg;

        Future.delayed(const Duration(seconds: 4), () {
          if (!isSyncingNotifier.value &&
              syncStatusMessageNotifier.value?.contains('siap offline') ==
                  true) {
            syncStatusMessageNotifier.value = null;
          }
        });
      } else if (catalogRes.isSuccess && stockRes.isSuccess) {
        // Server berhasil dihubungi namun tidak ada produk/stok di cabang/gudang ini
        await clearCachedProducts();
        syncStatusMessageNotifier.value = 'Tidak ada data stok di gudang ini.';
        Future.delayed(const Duration(seconds: 3), () {
          if (!isSyncingNotifier.value) {
            syncStatusMessageNotifier.value = null;
          }
        });
      } else {
        syncStatusMessageNotifier.value = null;
      }
    } catch (_) {
      syncStatusMessageNotifier.value = null;
    } finally {
      isSyncingNotifier.value = false;
    }
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
    final dateStr =
        '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
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
                : (item.qrcodes.isNotEmpty
                    ? item.qrcodes.join(', ')
                    : (item.qrcode.isNotEmpty ? item.qrcode : null)),
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
    enrichedPayload['date'] =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    enrichedPayload['created_at'] = now.toIso8601String();

    final itemRecord = OfflineTransactionItem(
      localId: localId,
      offlineCode: offlineCode,
      createdAt: now,
      payload: enrichedPayload,
      localInvoice: localInvoice,
    );

    final prefs = await SharedPreferences.getInstance();
    final existingRaw =
        prefs.getStringList(_keyPendingTransactions) ?? <String>[];
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
          if (decoded is Map<String, dynamic> &&
              decoded['local_id'] == localId) {
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
  Future<({int total, int success, int failed, List<String> messages})>
      syncPendingTransactions() async {
    if (isSyncingNotifier.value) {
      return (
        total: 0,
        success: 0,
        failed: 0,
        messages: ['Sinkronisasi sedang berjalan...']
      );
    }

    final items = await getPendingTransactions();
    if (items.isEmpty) {
      await updatePendingCount();
      return (
        total: 0,
        success: 0,
        failed: 0,
        messages: ['Tidak ada antrean transaksi offline.']
      );
    }

    isSyncingNotifier.value = true;
    syncStatusMessageNotifier.value =
        'Menyinkronkan ${items.length} transaksi offline...';

    int successCount = 0;
    int failedCount = 0;
    final messages = <String>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      syncStatusMessageNotifier.value =
          'Menyinkronkan transaksi (${i + 1}/${items.length})...';
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

    isSyncingNotifier.value = false;
    await updatePendingCount();

    if (successCount > 0) {
      syncStatusMessageNotifier.value =
          '$successCount transaksi berhasil disinkronkan!';
      Future.delayed(const Duration(seconds: 3), () {
        if (!isSyncingNotifier.value &&
            syncStatusMessageNotifier.value?.contains('berhasil') == true) {
          syncStatusMessageNotifier.value = null;
        }
      });
    } else {
      syncStatusMessageNotifier.value = null;
    }

    return (
      total: items.length,
      success: successCount,
      failed: failedCount,
      messages: messages,
    );
  }
}

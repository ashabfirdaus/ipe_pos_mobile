import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pos_models.dart';
import '../utils/currency_formatter.dart';

class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  static const String _prefKeyMac = 'printer_mac_address';
  static const String _prefKeyName = 'printer_device_name';
  static const String _prefKeyPaperSize = 'printer_paper_size'; // '58' or '80'

  BluetoothInfo? _connectedDevice;
  bool _isConnected = false;
  String _paperSize = '58';

  img.Image? _cachedLogo58;
  img.Image? _cachedLogo80;

  BluetoothInfo? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;
  String get paperSize => _paperSize;

  /// Inisialisasi awal: Muat preferensi dan auto-connect jika ada printer tersimpan
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _paperSize = prefs.getString(_prefKeyPaperSize) ?? '58';
    final savedMac = prefs.getString(_prefKeyMac);
    final savedName = prefs.getString(_prefKeyName);

    if (savedMac != null && savedMac.isNotEmpty) {
      _connectedDevice = BluetoothInfo(
        name: savedName ?? 'Printer Bluetooth',
        macAdress: savedMac,
      );
      // Cek apakah bluetooth aktif lalu coba koneksi di background
      final isBtOn = await isBluetoothEnabled();
      if (isBtOn) {
        await connect(savedMac, deviceName: savedName, savePreference: false);
      }
    }
  }

  /// Memeriksa status izin Bluetooth tanpa memicu prompt dialog
  Future<bool> isPermissionGranted() async {
    if (Platform.isAndroid) {
      final isPluginGranted =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      final connectGranted = await Permission.bluetoothConnect.isGranted;
      return isPluginGranted || connectGranted;
    } else if (Platform.isIOS) {
      return await Permission.bluetooth.isGranted;
    }
    return true;
  }

  /// Memeriksa & meminta izin Bluetooth pada runtime (Android 12+ / iOS)
  Future<bool> checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      // 1. Cek dulu apakah sudah diizinkan
      final isAlreadyGranted = await isPermissionGranted();
      if (isAlreadyGranted) return true;

      // 2. Minta izin Bluetooth Connect dan Bluetooth Scan (Android 12+)
      final statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();

      final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final isPluginGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;

      // 3. Fallback untuk Android 11 ke bawah atau perangkat OEM khusus
      if (!connectGranted && !isPluginGranted) {
        final loc = await Permission.locationWhenInUse.request();
        if (loc.isGranted) return true;
      }

      return connectGranted || isPluginGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }
    return true;
  }

  /// Cek apakah Bluetooth pada perangkat aktif
  Future<bool> isBluetoothEnabled() async {
    try {
      // Pastikan izin telah diminta/diperiksa
      await checkAndRequestPermissions();

      final bool isBtOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (isBtOn) return true;

      // Fallback: Jika bluetoothEnabled mengembalikan false karena proteksi OEM (misal Vivo/Oppo),
      // kita periksa apakah daftar paired devices bisa diakses.
      final paired = await PrintBluetoothThermal.pairedBluetooths;
      if (paired.isNotEmpty) {
        return true;
      }

      return isBtOn;
    } catch (e) {
      debugPrint('Error checking bluetooth enabled: $e');
      return false;
    }
  }

  /// Dapatkan daftar printer Bluetooth yang sudah dipasangkan (Paired Devices)
  Future<List<BluetoothInfo>> getPairedDevices() async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) {
      debugPrint('Bluetooth permission not granted');
      return [];
    }

    try {
      final List<BluetoothInfo> devices =
          await PrintBluetoothThermal.pairedBluetooths;
      return devices;
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
      return [];
    }
  }

  /// Simpan pengaturan ukuran kertas (58 atau 80)
  Future<void> setPaperSize(String size) async {
    _paperSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyPaperSize, size);
  }

  /// Hubungkan ke printer menggunakan MAC address
  Future<bool> connect(
    String macAddress, {
    String? deviceName,
    bool savePreference = true,
  }) async {
    try {
      // Disconnect perangkat lama terlebih dahulu jika ada
      final status = await PrintBluetoothThermal.connectionStatus;
      if (status) {
        await PrintBluetoothThermal.disconnect;
      }

      final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );

      _isConnected = result;
      if (result) {
        _connectedDevice = BluetoothInfo(
          name: deviceName ?? 'Printer Bluetooth',
          macAdress: macAddress,
        );

        if (savePreference) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyMac, macAddress);
          if (deviceName != null) {
            await prefs.setString(_prefKeyName, deviceName);
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Putuskan koneksi printer
  Future<bool> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _isConnected = false;
      return result;
    } catch (e) {
      debugPrint('Error disconnecting printer: $e');
      return false;
    }
  }

  /// Cek status koneksi realtime
  Future<bool> checkConnectionStatus() async {
    try {
      final bool result = await PrintBluetoothThermal.connectionStatus;
      _isConnected = result;
      return result;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  /// Helper untuk memuat dan menyiapkan gambar logo Inti Pangan untuk printer thermal
  Future<List<int>> _getLogoBytes(Generator generator, bool is80mm) async {
    try {
      img.Image? prepared = is80mm ? _cachedLogo80 : _cachedLogo58;
      if (prepared == null) {
        final ByteData data = await rootBundle.load('assets/icon/intipangan_logo.png');
        final Uint8List rawBytes = data.buffer.asUint8List();
        final img.Image? decoded = img.decodeImage(rawBytes);
        if (decoded == null) return [];

        // Target lebar disesuaikan dengan kapasitas dot printer thermal
        // 58mm: 384 dot max (lebar ideal ~ 260 - 280px)
        // 80mm: 576 dot max (lebar ideal ~ 380 - 400px)
        final targetWidth = is80mm ? 380 : 280;
        final resized = img.copyResize(decoded, width: targetWidth);

        // Buat kanvas putih solid agar background transparan tidak berubah jadi hitam di printer thermal
        final whiteCanvas = img.Image(
          width: resized.width,
          height: resized.height,
          numChannels: 4,
        );
        img.fill(whiteCanvas, color: img.ColorRgba8(255, 255, 255, 255));
        img.compositeImage(whiteCanvas, resized);

        if (is80mm) {
          _cachedLogo80 = whiteCanvas;
        } else {
          _cachedLogo58 = whiteCanvas;
        }
        prepared = whiteCanvas;
      }

      return generator.imageRaster(prepared, align: PosAlign.center);
    } catch (e) {
      debugPrint('Gagal memuat logo Inti Pangan untuk cetak nota: $e');
      return [];
    }
  }

  /// Cetak tes nota printer untuk memastikan konfigurasi sudah benar
  Future<({bool success, String message})> testPrint() async {
    final status = await checkConnectionStatus();
    if (!status) {
      if (_connectedDevice != null) {
        final reconnected = await connect(
          _connectedDevice!.macAdress,
          deviceName: _connectedDevice!.name,
          savePreference: false,
        );
        if (!reconnected) {
          return (
            success: false,
            message: 'Gagal terhubung ke printer. Pastikan printer menyala & dekat dengan HP.',
          );
        }
      } else {
        return (
          success: false,
          message: 'Belum ada printer Bluetooth yang terhubung.',
        );
      }
    }

    try {
      final profile = await CapabilityProfile.load();
      final size = _paperSize == '80' ? PaperSize.mm80 : PaperSize.mm58;
      final generator = Generator(size, profile);
      List<int> bytes = [];

      bytes += generator.reset();

      // 1. Logo Inti Pangan
      final is80mm = _paperSize == '80';
      final logoBytes = await _getLogoBytes(generator, is80mm);
      if (logoBytes.isNotEmpty) {
        bytes += logoBytes;
        bytes += generator.feed(1);
      } else {
        bytes += generator.text(
          'INTI PANGAN EKSPOR',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            fontType: PosFontType.fontB,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        );
      }
      bytes += generator.text(
        'Sistem POS Mobile',
        styles: const PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontB),
      );
      bytes += generator.text(
        'TES CETAK PRINTER THERMAL',
        styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
      );
      bytes += generator.feed(1);

      bytes += generator.hr();
      bytes += generator.text(
        'Waktu: ${DateTime.now().toString().split('.').first}',
        styles: const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB),
      );
      bytes += generator.text(
        'Tipe Kertas: ${_paperSize}mm',
        styles: const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB),
      );
      bytes += generator.text(
        'Perangkat: ${_connectedDevice?.name ?? "-"}',
        styles: const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB),
      );
      bytes += generator.hr();

      bytes += generator.text(
        'Printer thermal Bluetooth siap digunakan!',
        styles: const PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontB),
      );
      bytes += generator.feed(2);
      bytes += generator.cut();

      final printResult = await PrintBluetoothThermal.writeBytes(bytes);
      return (
        success: printResult,
        message: printResult
            ? 'Berhasil mengirim data cetak ke printer!'
            : 'Gagal mencetak, printer tidak merespon.',
      );
    } catch (e) {
      return (
        success: false,
        message: 'Terjadi kesalahan saat mencetak: $e',
      );
    }
  }

  /// Cetak nota invoice transaksi POS
  Future<({bool success, String message})> printReceipt(
    InvoiceModel invoice, {
    String? cashierName,
  }) async {
    final status = await checkConnectionStatus();
    if (!status) {
      if (_connectedDevice != null) {
        final reconnected = await connect(
          _connectedDevice!.macAdress,
          deviceName: _connectedDevice!.name,
          savePreference: false,
        );
        if (!reconnected) {
          return (
            success: false,
            message: 'Printer belum terhubung. Silakan sambungkan printer di menu Pengaturan Printer.',
          );
        }
      } else {
        return (
          success: false,
          message: 'Printer belum dikonfigurasi. Buka Pengaturan Printer untuk menghubungkan.',
        );
      }
    }

    try {
      final profile = await CapabilityProfile.load();
      final is80mm = _paperSize == '80';
      final size = is80mm ? PaperSize.mm80 : PaperSize.mm58;
      final generator = Generator(size, profile);
      List<int> bytes = [];

      bytes += generator.reset();

      // 1. Header Toko / Perusahaan (Logo Inti Pangan)
      final logoBytes = await _getLogoBytes(generator, is80mm);
      if (logoBytes.isNotEmpty) {
        bytes += logoBytes;
        bytes += generator.feed(1);
      } else {
        bytes += generator.text(
          'INTI PANGAN EKSPOR',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            fontType: PosFontType.fontB,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        );
      }

      if (invoice.branchName != null && invoice.branchName!.isNotEmpty) {
        bytes += generator.text(
          'Cabang: ${invoice.branchName}',
          styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
        );
      }
      if (invoice.warehouseName != null && invoice.warehouseName!.isNotEmpty) {
        bytes += generator.text(
          'Gudang: ${invoice.warehouseName}',
          styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
        );
      }

      bytes += generator.hr();

      // 2. Info Transaksi (Font B - Kecil & Ringkas)
      bytes += generator.text(
        'No. Inv : ${invoice.invoiceNo}',
        styles: const PosStyles(fontType: PosFontType.fontB),
      );
      bytes += generator.text(
        'Waktu   : ${CurrencyFormatter.formatDate(invoice.createdAt)}',
        styles: const PosStyles(fontType: PosFontType.fontB),
      );
      if (cashierName != null && cashierName.isNotEmpty) {
        bytes += generator.text(
          'Kasir   : $cashierName',
          styles: const PosStyles(fontType: PosFontType.fontB),
        );
      }
      if (invoice.paymentMethodName != null && invoice.paymentMethodName!.isNotEmpty) {
        bytes += generator.text(
          'Metode  : ${invoice.paymentMethodName}',
          styles: const PosStyles(fontType: PosFontType.fontB),
        );
      }

      bytes += generator.hr();

      // 3. Daftar Produk (Detail Barang: Nama, QR/SN, Qty x Harga, Subtotal)
      for (final item in invoice.items) {
        // Nama Produk
        bytes += generator.text(
          item.itemName,
          styles: const PosStyles(bold: true, fontType: PosFontType.fontB),
        );

        // Detail QR Code Stok jika ada
        if (item.qrcode != null && item.qrcode!.isNotEmpty) {
          bytes += generator.text(
            '  [QR: ${item.qrcode}]',
            styles: const PosStyles(fontType: PosFontType.fontB),
          );
        }

        // Qty x Harga di kiri, Subtotal di kanan
        final unitStr = item.unit != null && item.unit!.isNotEmpty ? ' ${item.unit}' : '';
        final qtyStr = '  ${item.qty}$unitStr x ${CurrencyFormatter.format(item.price)}';
        final subTotalStr = CurrencyFormatter.format(item.subTotal);

        bytes += generator.row([
          PosColumn(
            text: qtyStr,
            width: is80mm ? 8 : 7,
            styles: const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB),
          ),
          PosColumn(
            text: subTotalStr,
            width: is80mm ? 4 : 5,
            styles: const PosStyles(align: PosAlign.right, fontType: PosFontType.fontB),
          ),
        ]);

        // Diskon item jika ada
        if (item.discount > 0) {
          bytes += generator.text(
            '    (Diskon: -${CurrencyFormatter.format(item.discount)})',
            styles: const PosStyles(fontType: PosFontType.fontB),
          );
        }
      }

      bytes += generator.hr();

      // 4. Rekap Finansial (Font B)
      _addSummaryRow(generator, bytes, 'Sub Total', CurrencyFormatter.format(invoice.subTotal), is80mm);
      if (invoice.discount > 0) {
        final promoLabel = invoice.promoName != null && invoice.promoName!.isNotEmpty
            ? 'Diskon (${invoice.promoName})'
            : 'Diskon Promo';
        _addSummaryRow(generator, bytes, promoLabel, '-${CurrencyFormatter.format(invoice.discount)}', is80mm, isBold: true);
      }
      if (invoice.ppn > 0) {
        _addSummaryRow(generator, bytes, 'PPN', '+${CurrencyFormatter.format(invoice.ppn)}', is80mm);
      }

      bytes += generator.hr();
      _addSummaryRow(generator, bytes, 'GRAND TOTAL', CurrencyFormatter.format(invoice.grandTotal), is80mm, isBold: true);
      _addSummaryRow(generator, bytes, 'Tunai (Diterima)', CurrencyFormatter.format(invoice.cash), is80mm);
      _addSummaryRow(generator, bytes, 'Kembalian', CurrencyFormatter.format(invoice.change), is80mm, isBold: true);

      // Pesan hemat jika mendapatkan promo
      if (invoice.discount > 0) {
        bytes += generator.feed(1);
        bytes += generator.text(
          '* Anda hemat ${CurrencyFormatter.format(invoice.discount)} pada transaksi ini',
          styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB, bold: true),
        );
      }

      bytes += generator.feed(1);

      // 5. Footer (Font B)
      bytes += generator.text(
        'Terima Kasih atas Kunjungan Anda!',
        styles: const PosStyles(align: PosAlign.center, bold: true, fontType: PosFontType.fontB),
      );
      bytes += generator.text(
        'Barang yang sudah dibeli\ntidak dapat ditukar/dikembalikan',
        styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
      );

      bytes += generator.feed(2);
      bytes += generator.cut();

      final printResult = await PrintBluetoothThermal.writeBytes(bytes);
      return (
        success: printResult,
        message: printResult ? 'Nota berhasil dicetak!' : 'Gagal mengirim data ke printer.',
      );
    } catch (e) {
      return (
        success: false,
        message: 'Gagal mencetak struk: $e',
      );
    }
  }

  void _addSummaryRow(
    Generator generator,
    List<int> bytes,
    String label,
    String value,
    bool is80mm, {
    bool isBold = false,
  }) {
    bytes.addAll(generator.row([
      PosColumn(
        text: label,
        width: is80mm ? 8 : 7,
        styles: PosStyles(align: PosAlign.left, bold: isBold, fontType: PosFontType.fontB),
      ),
      PosColumn(
        text: value,
        width: is80mm ? 4 : 5,
        styles: PosStyles(align: PosAlign.right, bold: isBold, fontType: PosFontType.fontB),
      ),
    ]));
  }
}

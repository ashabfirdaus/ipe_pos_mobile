import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/printer_service.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final PrinterService _printerService = PrinterService.instance;

  bool _hasPermission = true;
  bool _isBluetoothOn = false;
  bool _isLoading = false;
  bool _isTestingPrint = false;
  List<BluetoothInfo> _devices = [];
  String? _connectingMac;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);

    // 1. Periksa dan minta izin Bluetooth runtime
    final hasPermission = await _printerService.checkAndRequestPermissions();

    // 2. Periksa status aktif Bluetooth
    bool isBtOn = await _printerService.isBluetoothEnabled();
    await _printerService.checkConnectionStatus();

    // 3. Selalu coba ambil daftar perangkat Bluetooth yang terpasang (paired)
    List<BluetoothInfo> devices = [];
    try {
      devices = await _printerService.getPairedDevices();
      // Jika daftar perangkat berhasil diambil dan ada isinya, Bluetooth dipastikan aktif
      if (devices.isNotEmpty) {
        isBtOn = true;
      }
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
    }

    if (!mounted) return;
    setState(() {
      _hasPermission = hasPermission;
      _isBluetoothOn = isBtOn;
      _devices = devices;
      _isLoading = false;
    });
  }

  Future<void> _handleConnect(BluetoothInfo device) async {
    setState(() => _connectingMac = device.macAdress);

    final success = await _printerService.connect(
      device.macAdress,
      deviceName: device.name,
      savePreference: true,
    );

    if (!mounted) return;
    setState(() => _connectingMac = null);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil terhubung ke ${device.name}!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal terhubung ke ${device.name}. Pastikan printer menyala.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleDisconnect() async {
    final success = await _printerService.disconnect();
    if (!mounted) return;
    setState(() {});

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koneksi printer telah diputus')),
      );
    }
  }

  Future<void> _handleTestPrint() async {
    setState(() => _isTestingPrint = true);
    final result = await _printerService.testPrint();
    if (!mounted) return;
    setState(() => _isTestingPrint = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _printerService.isConnected;
    final currentDevice = _printerService.connectedDevice;
    final currentPaperSize = _printerService.paperSize;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Printer Thermal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Perangkat',
            onPressed: _isLoading ? null : _loadState,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadState,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSizes.paddingPage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Status Koneksi Card
              _buildStatusCard(isConnected, currentDevice),
              AppSizes.gapH20,

              // 2. Pengaturan Ukuran Kertas
              _buildPaperSizeCard(currentPaperSize),
              AppSizes.gapH20,

              // 3. Header Daftar Perangkat
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Perangkat Tersambung (Paired)',
                    style: AppTextStyles.h3,
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              AppSizes.gapH12,

              // 4. Banner Peringatan Izin atau Bluetooth Mati (jika ada)
              if (!_hasPermission) ...[
                _buildPermissionWarning(),
                AppSizes.gapH12,
              ] else if (!_isBluetoothOn && _devices.isEmpty) ...[
                _buildBluetoothOffWarning(),
                AppSizes.gapH12,
              ],

              // 5. Daftar Perangkat Bluetooth
              if (_devices.isEmpty && !_isLoading)
                _buildEmptyDevices()
              else
                _buildDeviceList(currentDevice),

              AppSizes.gapH24,

              // 6. Panduan Singkat
              _buildHelpCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isConnected, BluetoothInfo? currentDevice) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (isConnected ? AppColors.success : Colors.grey.shade400)
                            .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    color: isConnected
                        ? AppColors.success
                        : Colors.grey.shade700,
                    size: 28,
                  ),
                ),
                AppSizes.gapW12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? 'Printer Terhubung' : 'Printer Terputus',
                        style: AppTextStyles.h3.copyWith(
                          color: isConnected
                              ? AppColors.success
                              : AppColors.textPrimary,
                        ),
                      ),
                      AppSizes.gapH4,
                      Text(
                        isConnected && currentDevice != null
                            ? '${currentDevice.name} (${currentDevice.macAdress})'
                            : 'Belum terhubung ke printer thermal',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppColors.success.withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isConnected ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isConnected
                          ? AppColors.success
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTestingPrint ? null : _handleTestPrint,
                    icon: _isTestingPrint
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.receipt_long_rounded),
                    label: const Text('Test Print Nota'),
                  ),
                ),
                if (isConnected) ...[
                  AppSizes.gapW12,
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: _handleDisconnect,
                    child: const Text('Putuskan'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperSizeCard(String currentPaperSize) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ukuran Kertas Struk',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            AppSizes.gapH4,
            const Text(
              'Pilih sesuai lebar kertas rol printer thermal Anda:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            AppSizes.gapH12,
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: '58',
                  label: Text('58 mm (Standar Portable)'),
                  icon: Icon(Icons.receipt_rounded),
                ),
                ButtonSegment<String>(
                  value: '80',
                  label: Text('80 mm (Printer Besar)'),
                  icon: Icon(Icons.receipt_long_rounded),
                ),
              ],
              selected: {currentPaperSize},
              onSelectionChanged: (newSelection) async {
                final selected = newSelection.first;
                await _printerService.setPaperSize(selected);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: Colors.orange.shade800,
                size: 28,
              ),
              AppSizes.gapW12,
              Expanded(
                child: Text(
                  'Izin Perangkat Sekitar (Bluetooth) Diperlukan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Android memerlukan izin "Perangkat Sekitar" (Nearby Devices) agar aplikasi dapat mendeteksi printer thermal.',
            style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await _printerService.checkAndRequestPermissions();
                  await _loadState();
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Izinkan Sekarang'),
              ),
              AppSizes.gapW8,
              OutlinedButton(
                onPressed: () => openAppSettings(),
                child: const Text('Buka Pengaturan HP'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothOffWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bluetooth_disabled_rounded,
                color: Colors.amber,
                size: 32,
              ),
              AppSizes.gapW12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bluetooth Tidak Terdeteksi Aktif',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pastikan Bluetooth aktif dan izin "Perangkat Sekitar" telah diizinkan pada pengaturan aplikasi di HP Anda.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => openAppSettings(),
                child: const Text('Buka Pengaturan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDevices() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          children: [
            Icon(
              Icons.bluetooth_searching_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            AppSizes.gapH8,
            const Text(
              'Tidak ada printer Bluetooth yang terpasang (paired)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            AppSizes.gapH4,
            const Text(
              'Buka Pengaturan Bluetooth HP Anda, sambungkan/pairing ke printer thermal terlebih dahulu (PIN biasanya 0000 atau 1234), lalu tekan Pindai Ulang.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            AppSizes.gapH12,
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadState,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Pindai Ulang'),
                ),
                OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Pengaturan HP'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(BluetoothInfo? currentDevice) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _devices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isThisConnected =
            _printerService.isConnected &&
            currentDevice?.macAdress == device.macAdress;
        final isConnectingThis = _connectingMac == device.macAdress;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            side: BorderSide(
              color: isThisConnected ? AppColors.primary : Colors.grey.shade200,
              width: isThisConnected ? 1.5 : 1,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isThisConnected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
              child: Icon(
                Icons.print_rounded,
                color: isThisConnected
                    ? AppColors.primary
                    : Colors.grey.shade700,
              ),
            ),
            title: Text(
              device.name.isNotEmpty ? device.name : 'Unknown Device',
              style: TextStyle(
                fontWeight: isThisConnected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              device.macAdress,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: isConnectingThis
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : isThisConnected
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: null,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Terhubung',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  )
                : OutlinedButton(
                    onPressed: () => _handleConnect(device),
                    child: const Text('Hubungkan'),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.blue.shade700,
            size: 20,
          ),
          AppSizes.gapW8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Petunjuk Penggunaan:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '1. Nyalakan printer thermal Bluetooth.\n'
                  '2. Buka menu Bluetooth di HP Anda, lakukan pairing (PIN biasanya 0000 atau 1234).\n'
                  '3. Kembali ke aplikasi ini, pilih nama printer lalu tekan "Hubungkan".\n'
                  '4. Gunakan "Test Print Nota" untuk memastikan kertas dan cetakan normal.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade900,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

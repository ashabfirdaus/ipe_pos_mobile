import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class CameraScannerPage extends StatefulWidget {
  const CameraScannerPage({super.key});

  @override
  State<CameraScannerPage> createState() => _CameraScannerPageState();
}

class _CameraScannerPageState extends State<CameraScannerPage> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  bool _isScanned = false;
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null && barcode.rawValue!.trim().isNotEmpty) {
      setState(() {
        _isScanned = true;
      });
      final code = barcode.rawValue!.trim();
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR / Barcode Kamera', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                final isTorchOn = state.torchState == TorchState.on;
                return Icon(
                  isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: isTorchOn ? Colors.amber : Colors.white,
                );
              },
            ),
            tooltip: 'Senter',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            tooltip: 'Ganti Kamera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 64),
                      AppSizes.gapH16,
                      const Text(
                        'Kamera tidak dapat diakses atau izin belum diberikan.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      AppSizes.gapH16,
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Kembali ke Input Manual'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Scanner Overlay with Laser & Target Area
          LayoutBuilder(
            builder: (context, constraints) {
              final scanAreaSize = constraints.maxWidth * 0.72;
              final topOffset = (constraints.maxHeight - scanAreaSize) / 2 - 40;
              final leftOffset = (constraints.maxWidth - scanAreaSize) / 2;

              return Stack(
                children: [
                  // Darkened background cutout
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.65),
                      BlendMode.srcOut,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                            backgroundBlendMode: BlendMode.dstOut,
                          ),
                        ),
                        Positioned(
                          top: topOffset,
                          left: leftOffset,
                          width: scanAreaSize,
                          height: scanAreaSize,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Viewfinder Frame
                  Positioned(
                    top: topOffset,
                    left: leftOffset,
                    width: scanAreaSize,
                    height: scanAreaSize,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryLight, width: 2.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _LaserPainter(progress: _animation.value),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Bottom Instructions Text
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Arahkan kamera ke QR Code atau Barcode Produk',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Pemindaian akan diproses secara otomatis',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LaserPainter extends CustomPainter {
  final double progress;

  _LaserPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.0),
          AppColors.primaryLight,
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, y, size.width, 3))
      ..strokeWidth = 3;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _LaserPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

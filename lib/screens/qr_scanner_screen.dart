import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// QR Scanner — scans QR codes with the device camera and lets the user
/// copy, open (for links), or share whatever the code contains.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _torchOn = false;
  bool _resultOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_resultOpen) return;
    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        code = value;
        break;
      }
    }
    if (code == null) return;

    _resultOpen = true;
    unawaited(_controller.pause());
    _showResultSheet(code);
  }

  /// Launchable URI for the scanned content, if it is a web link.
  Uri? _linkUriOf(String code) {
    final parsed = Uri.tryParse(code);
    if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https') && parsed.host.isNotEmpty) {
      return parsed;
    }
    if (!code.contains('\n') && !code.contains(' ') && code.contains('.') && code.length > 3) {
      return Uri.tryParse('https://$code');
    }
    return null;
  }

  Future<void> _showResultSheet(String code) async {
    final link = _linkUriOf(code);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.orange,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'QR code scanned',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      code,
                      style: const TextStyle(fontSize: 15, color: AppColors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('Copied to clipboard'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(sheetContext);
                          Navigator.pop(sheetContext);
                          await Share.share(code);
                          messenger.clearSnackBars();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.orange,
                          side: const BorderSide(color: AppColors.orange, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                if (link != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      try {
                        await launchUrl(link, mode: LaunchMode.externalApplication);
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Could not open link'),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.charcoal,
                      side: BorderSide(color: AppColors.gray.withValues(alpha: 0.8), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open link in browser'),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text(
                    'Scan another code',
                    style: TextStyle(color: AppColors.darkGray),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _resultOpen = false;
      if (mounted) unawaited(_controller.start());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _buildErrorView(error),
            placeholderBuilder: (context) => const ColoredBox(color: Colors.black),
          ),
          _buildScanOverlay(),
          _buildTorchButton(),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: _buildHintBanner(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide * 0.7;
          final rect = Rect.fromCenter(
            center: constraints.biggest.center(Offset.zero),
            width: side,
            height: side,
          );
          return CustomPaint(
            painter: _ScannerOverlayPainter(
              frame: rect,
              borderColor: AppColors.orange,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }

  Widget _buildTorchButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _controller,
        builder: (context, state, _) {
          final torchAvailable = state.torchState != TorchState.unavailable;
          return CircleAvatar(
            radius: 22,
            backgroundColor: _torchOn ? AppColors.orange : Colors.black54,
            foregroundColor: Colors.white,
            child: IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                size: 20,
              ),
              tooltip: torchAvailable ? 'Toggle torch' : 'Torch unavailable',
              onPressed: torchAvailable
                  ? () async {
                      await _controller.toggleTorch();
                      if (mounted) setState(() => _torchOn = !_torchOn);
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHintBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Point the camera at a QR code — it is detected automatically.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(MobileScannerException error) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.no_photography_rounded,
                  color: AppColors.orange,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Camera unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check that the camera permission is granted and no other app is using the camera.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => unawaited(_controller.start()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: const BorderSide(color: AppColors.orange, width: 1.5),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims everything outside the scan frame and draws orange corner brackets.
class _ScannerOverlayPainter extends CustomPainter {
  final Rect frame;
  final Color borderColor;
  static const double _bracketLength = 28;
  static const double _bracketWidth = 5;
  static const double _bracketRadius = 12;

  _ScannerOverlayPainter({required this.frame, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Dim outside the frame.
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()
          ..addRRect(RRect.fromRectAndRadius(
            frame.inflate(6),
            const Radius.circular(20),
          )),
      ),
      dimPaint,
    );

    // Corner brackets.
    final bracketPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _bracketWidth;

    final outer = frame.inflate(6);
    final r = _bracketRadius;
    final x0 = outer.left;
    final y0 = outer.top;
    final x1 = outer.right;
    final y1 = outer.bottom;
    final l = _bracketLength;

    final path = Path()
      ..moveTo(x0, y0 + l)
      ..lineTo(x0, y0 + r)
      ..quadraticBezierTo(x0, y0, x0 + r, y0)
      ..lineTo(x0 + l, y0)
      ..moveTo(x1 - l, y0)
      ..lineTo(x1 - r, y0)
      ..quadraticBezierTo(x1, y0, x1, y0 + r)
      ..lineTo(x1, y0 + l)
      ..moveTo(x1, y1 - l)
      ..lineTo(x1, y1 - r)
      ..quadraticBezierTo(x1, y1, x1 - r, y1)
      ..lineTo(x1 - l, y1)
      ..moveTo(x0 + l, y1)
      ..lineTo(x0 + r, y1)
      ..quadraticBezierTo(x0, y1, x0, y1 - r)
      ..lineTo(x0, y1 - l);
    canvas.drawPath(path, bracketPaint);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter oldDelegate) =>
      frame != oldDelegate.frame || borderColor != oldDelegate.borderColor;
}

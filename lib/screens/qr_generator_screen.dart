import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// QR Generator — lets the user turn any text or link into a scannable QR
/// code with a live preview, then share it as a PNG, copy the content, or
/// open detected links directly in the browser.
class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  static const int _maxChars = 800;

  final TextEditingController _textController = TextEditingController();

  QrEyeShape _eyeShape = QrEyeShape.square;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String get _content => _textController.text.trim();

  bool get _canGenerate => _content.isNotEmpty;

  /// True when the current content looks like a web link we can open.
  bool get _isLink {
    final uri = _launchUri;
    return uri != null && uri.host.isNotEmpty;
  }

  /// Parses the content into a launchable URI. Plain domains without a scheme
  /// get an https:// prefix (only used for the Open action — the QR itself
  /// always encodes exactly what the user typed).
  Uri? get _launchUri {
    if (!_canGenerate) return null;
    final parsed = Uri.tryParse(_content);
    if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return parsed;
    }
    if (!_content.contains(' ') && _content.contains('.')) {
      return Uri.tryParse('https://$_content');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'QR Generator',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildInputCard(),
            const SizedBox(height: 16),
            _buildPreviewCard(),
            if (_canGenerate) ...[
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.qr_code_2_rounded,
            color: AppColors.orange,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a QR code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black),
              ),
              SizedBox(height: 2),
              Text(
                'Paste any text or link — the code updates as you type.',
                style: TextStyle(fontSize: 13, color: AppColors.darkGray),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textController,
            maxLines: 3,
            minLines: 1,
            maxLength: _maxChars,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 15, color: AppColors.black),
            decoration: InputDecoration(
              hintText: 'Enter text or a link (https://…)',
              counterText: '',
              prefixIcon: Icon(
                _isLink ? Icons.link_rounded : Icons.text_fields_rounded,
                color: AppColors.orange,
              ),
              suffixIcon: _canGenerate
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.darkGray,
                      onPressed: () {
                        _textController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.lightGray,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.orange, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_content.length}/$_maxChars characters',
            style: const TextStyle(fontSize: 12, color: AppColors.darkGray),
          ),
          if (_isLink) ...[
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.link_rounded, size: 14, color: AppColors.orange),
                SizedBox(width: 4),
                Text('Link detected — you can open it below after generating.',
                    style: TextStyle(fontSize: 12, color: AppColors.orange)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gray.withValues(alpha: 0.4)),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          _buildQrPreview(),
          const SizedBox(height: 16),
          _buildEyeShapeSelector(),
        ],
      ),
    );
  }

  Widget _buildQrPreview() {
    if (!_canGenerate) {
      return Container(
        width: 240,
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner_rounded, size: 56, color: AppColors.darkGray.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Your QR code will appear here',
              style: TextStyle(fontSize: 13, color: AppColors.darkGray.withValues(alpha: 0.8)),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 240,
      height: 240,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray.withValues(alpha: 0.4)),
      ),
      child: QrImageView(
        key: ValueKey('qr_$_content'),
        data: _content,
        version: QrVersions.auto,
        size: 200,
        gapless: true,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        eyeStyle: QrEyeStyle(eyeShape: _eyeShape, color: AppColors.black),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.black,
        ),
      ),
    );
  }

  Widget _buildEyeShapeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Corner style', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
        const SizedBox(width: 12),
        _eyeShapeButton(QrEyeShape.square, Icons.crop_square_rounded, 'Square'),
        const SizedBox(width: 8),
        _eyeShapeButton(QrEyeShape.circle, Icons.circle_outlined, 'Round'),
      ],
    );
  }

  Widget _eyeShapeButton(QrEyeShape shape, IconData icon, String label) {
    final selected = _eyeShape == shape;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _eyeShape = shape),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.gray,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.orange : AppColors.darkGray),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.orange : AppColors.darkGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareQr,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                label: const Text('Share QR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyContent,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: const BorderSide(color: AppColors.orange, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        if (_isLink) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openLink,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.charcoal,
              side: BorderSide(color: AppColors.gray.withValues(alpha: 0.8), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open link in browser', style: TextStyle(fontSize: 15)),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saveToGallery,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.charcoal,
            side: BorderSide(color: AppColors.gray.withValues(alpha: 0.8), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.photo_library_rounded, size: 18),
          label: const Text('Save to gallery', style: TextStyle(fontSize: 15)),
        ),
      ],
    );
  }

  /// Renders the current QR as a 1024px PNG. Shared by the share and
  /// save-to-gallery actions so both always match the on-screen preview
  /// (same eye style, error correction level, and content).
  Future<Uint8List> _renderQrBytes() async {
    final painter = QrPainter(
      data: _content,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
      eyeStyle: QrEyeStyle(eyeShape: _eyeShape, color: AppColors.black),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.black,
      ),
    );
    final byteData = await painter.toImageData(1024, format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Could not render QR image');
    return byteData.buffer.asUint8List();
  }

  /// Saves the QR PNG straight into the phone gallery (Photos / Google Photos).
  Future<void> _saveToGallery() async {
    if (!_canGenerate) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _renderQrBytes();
      await Gal.putImageBytes(
        bytes,
        album: 'SwiftDrop',
        name: 'swiftdrop_qr_${DateTime.now().millisecondsSinceEpoch}',
      );
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('QR code saved to your gallery (SwiftDrop album)'),
        ),
      );
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        await Gal.requestAccess();
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save QR code: ${e.type.message}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save QR code: $e')),
      );
    }
  }

  Future<void> _shareQr() async {
    if (!_canGenerate) return;
    try {
      final bytes = await _renderQrBytes();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/swiftdrop_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _content,
        subject: 'QR code',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share QR code: $e')),
      );
    }
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: _content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Copied to clipboard'),
      ),
    );
  }

  Future<void> _openLink() async {
    final uri = _launchUri;
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $e')),
      );
    }
  }
}

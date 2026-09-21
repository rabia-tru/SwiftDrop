import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';

/// SwiftDrop New Order — Orange & White Only
class UserNewOrderScreen extends StatefulWidget {
  const UserNewOrderScreen({super.key});

  @override
  State<UserNewOrderScreen> createState() => _UserNewOrderScreenState();
}

class _UserNewOrderScreenState extends State<UserNewOrderScreen> {
  final _pickupAddressController = TextEditingController();
  final _dropAddressController = TextEditingController();
  final _notesController = TextEditingController();
  final _pickupLatController = TextEditingController();
  final _pickupLngController = TextEditingController();
  final _dropLatController = TextEditingController();
  final _dropLngController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _dropAddressController.dispose();
    _notesController.dispose();
    _pickupLatController.dispose();
    _pickupLngController.dispose();
    _dropLatController.dispose();
    _dropLngController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_pickupAddressController.text.trim().isEmpty ||
        _dropAddressController.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in pickup and drop addresses');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await ApiService.customerCreateOrder(
        pickupAddress: _pickupAddressController.text.trim(),
        pickupLat: double.tryParse(_pickupLatController.text) ?? 31.5204,
        pickupLng: double.tryParse(_pickupLngController.text) ?? 74.3587,
        dropAddress: _dropAddressController.text.trim(),
        dropLat: double.tryParse(_dropLatController.text) ?? 31.47,
        dropLng: double.tryParse(_dropLngController.text) ?? 74.42,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 12), Text('Order placed!')]),
          backgroundColor: AppColors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;

    AppColors.setLightStatusBar();
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('New Order'),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Pickup Location'),
            const SizedBox(height: 12),
            _buildAddressField(controller: _pickupAddressController, label: 'Pickup Address', icon: Icons.circle),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildCoordField(controller: _pickupLatController, label: 'Latitude')),
                const SizedBox(width: 12),
                Expanded(child: _buildCoordField(controller: _pickupLngController, label: 'Longitude')),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Drop Location'),
            const SizedBox(height: 12),
            _buildAddressField(controller: _dropAddressController, label: 'Drop Address', icon: Icons.location_on),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildCoordField(controller: _dropLatController, label: 'Latitude')),
                const SizedBox(width: 12),
                Expanded(child: _buildCoordField(controller: _dropLngController, label: 'Longitude')),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Additional Notes'),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(fontSize: 16, color: AppColors.black),
              decoration: InputDecoration(
                hintText: 'Any special instructions?',
                hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.6)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                filled: true,
                fillColor: AppColors.lightGray,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.orangeDark, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.orangeDark, fontSize: 13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Text('Place Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.black;
    return Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor));
  }

  Widget _buildAddressField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 16, color: AppColors.black),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.orange, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
        filled: true,
        fillColor: AppColors.lightGray,
      ),
    );
  }

  Widget _buildCoordField({required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14, color: AppColors.black),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0.0',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
        filled: true,
        fillColor: AppColors.lightGray,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
    );
  }
}

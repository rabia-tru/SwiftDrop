import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

/// Saved address model
class SavedAddress {
  final String id;
  final String label; // Home, Work, Other
  final String address;
  final String? details;
  final double? lat;
  final double? lng;

  SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.details,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'address': address,
    'details': details,
    'lat': lat,
    'lng': lng,
  };

  factory SavedAddress.fromMap(Map<String, dynamic> map) => SavedAddress(
    id: map['id'] ?? '',
    label: map['label'] ?? 'Other',
    address: map['address'] ?? '',
    details: map['details'],
    lat: map['lat'],
    lng: map['lng'],
  );
}

/// Address Management Screen — FoodPanda-style saved addresses
class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  List<SavedAddress> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? rawList = prefs.getStringList('saved_addresses_raw');
      if (rawList != null) {
        for (final raw in rawList) {
          try {
            final parts = raw.split('|||');
            if (parts.length >= 3) {
              _addresses.add(SavedAddress(
                id: parts[0],
                label: parts[1],
                address: parts[2],
                details: parts.length > 3 ? parts[3] : null,
              ));
            }
          } catch (e) {
            // Skip invalid entries
          }
        }
      }
    } catch (e) {
      // Empty
    }
    setState(() => _loading = false);
  }

  Future<void> _saveAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = _addresses.map((a) => '${a.id}|||${a.label}|||${a.address}|||${a.details ?? ''}').toList();
    await prefs.setStringList('saved_addresses_raw', rawList);
  }

  void _addAddress({SavedAddress? existing}) {
    final addressController = TextEditingController(text: existing?.address ?? '');
    final detailsController = TextEditingController(text: existing?.details ?? '');
    String selectedLabel = existing?.label ?? 'Home';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.gray, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(existing != null ? 'Edit Address' : 'Add New Address',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.black)),
              const SizedBox(height: 20),

              // Label chips (Home, Work, Other)
              Row(
                children: ['Home', 'Work', 'Other'].map((label) {
                  final isSelected = selectedLabel == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setModalState(() => selectedLabel = label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.orange : AppColors.lightGray,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              label == 'Home' ? Icons.home : label == 'Work' ? Icons.work : Icons.location_on,
                              size: 16,
                              color: isSelected ? Colors.white : AppColors.darkGray,
                            ),
                            const SizedBox(width: 6),
                            Text(label, style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.darkGray,
                            )),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Address field
              TextField(
                controller: addressController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter full address',
                  hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                  filled: true,
                  fillColor: AppColors.lightGray,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.location_on, color: AppColors.orange, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              // Details field
              TextField(
                controller: detailsController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Apartment, floor, landmark (optional)',
                  hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                  filled: true,
                  fillColor: AppColors.lightGray,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.info_outline, color: AppColors.orange, size: 20),
                ),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (addressController.text.trim().isEmpty) return;
                    setState(() {
                      if (existing != null) {
                        final idx = _addresses.indexWhere((a) => a.id == existing.id);
                        if (idx != -1) {
                          _addresses[idx] = SavedAddress(
                            id: existing.id,
                            label: selectedLabel,
                            address: addressController.text.trim(),
                            details: detailsController.text.trim().isNotEmpty ? detailsController.text.trim() : null,
                          );
                        }
                      } else {
                        _addresses.add(SavedAddress(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          label: selectedLabel,
                          address: addressController.text.trim(),
                          details: detailsController.text.trim().isNotEmpty ? detailsController.text.trim() : null,
                        ));
                      }
                    });
                    _saveAddresses();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existing != null ? 'Address updated!' : 'Address saved!'),
                        backgroundColor: AppColors.statusDelivered,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(existing != null ? 'Update Address' : 'Save Address',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteAddress(String id) {
    setState(() => _addresses.removeWhere((a) => a.id == id));
    _saveAddresses();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Address deleted'),
        backgroundColor: AppColors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  IconData _getLabelIcon(String label) {
    switch (label) {
      case 'Home': return Icons.home;
      case 'Work': return Icons.work;
      default: return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setLightStatusBar();
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.orange, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Saved Addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.orange)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
        : _addresses.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _addresses.length,
              itemBuilder: (context, index) => _buildAddressCard(_addresses[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAddress(),
        backgroundColor: AppColors.orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
            child: const Icon(Icons.location_off, size: 48, color: AppColors.orange),
          ),
          const SizedBox(height: 20),
          const Text('No saved addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Add your delivery addresses for quick checkout', style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addAddress(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Address'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(SavedAddress address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(10)),
            child: Icon(_getLabelIcon(address.label), color: AppColors.orange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.black)),
                const SizedBox(height: 3),
                Text(address.address, style: const TextStyle(fontSize: 13, color: AppColors.darkGray), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (address.details != null && address.details!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(address.details!, style: TextStyle(fontSize: 12, color: AppColors.darkGray.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.darkGray, size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'edit') _addAddress(existing: address);
              if (value == 'delete') _deleteAddress(address.id);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: AppColors.orange), SizedBox(width: 10), Text('Edit')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 10), Text('Delete', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';

/// Full-screen map picker for delivery addresses.
///
/// The pin stays fixed at the screen center while the user pans/zooms the
/// map. The address under the pin is resolved live via Nominatim reverse
/// geocoding, and "Confirm Location" returns `{address, lat, lng}` to the
/// caller (cart checkout / address screen).
class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  /// Result keys returned via Navigator.pop.
  static const String kAddress = 'address';
  static const String kLat = 'lat';
  static const String kLng = 'lng';

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Fallback center (Lahore) until the device position resolves.
  LatLng _center = const LatLng(31.5204, 74.3587);
  bool _ready = false;

  String _address = 'Resolving address…';
  bool _geocoding = false;
  bool _locating = false;
  Timer? _debounce;

  /// Fetches the device's current GPS position and flies the map (and the
  /// center pin) onto it, re-resolving the address.
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
        _address = 'Resolving address…';
      });
      _reverseGeocode();
    } catch (_) {
      // GPS unavailable — leave the map where it is.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _resolveInitialCenter();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _resolveInitialCenter() async {
    // Explicit initial coordinates (already-picked address) win.
    if (widget.initialLat != null && widget.initialLng != null) {
      if (mounted) {
        setState(() {
          _center = LatLng(widget.initialLat!, widget.initialLng!);
          _ready = true;
        });
        _reverseGeocode();
      }
      return;
    }

    // Otherwise start at the device's current GPS position.
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        if (mounted) {
          setState(() {
            _center = LatLng(pos.latitude, pos.longitude);
            _ready = true;
          });
        }
      } else if (mounted) {
        setState(() => _ready = true);
      }
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
    _reverseGeocode();
  }

  Future<void> _reverseGeocode() async {
    if (!mounted) return;
    setState(() => _geocoding = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${_center.latitude}&lon=${_center.longitude}'
        '&format=json&zoom=18&addressdetails=1',
      );
      final resp = await http.get(
        url,
        headers: {'User-Agent': 'SwiftDrop/1.0 (delivery app)'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final name = (data['display_name'] ?? '').toString();
        if (mounted) {
          setState(() {
            _address = name.isNotEmpty ? name : _coordsFallback();
            _geocoding = false;
          });
        }
        return;
      }
    } catch (_) {
      // Offline / blocked — fall through to coordinates.
    }
    if (mounted) {
      setState(() {
        _address = _coordsFallback();
        _geocoding = false;
      });
    }
  }

  String _coordsFallback() =>
      '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}';

  void _confirm() {
    Navigator.of(context).pop({
      MapPickerScreen.kAddress: _address,
      MapPickerScreen.kLat: _center.latitude,
      MapPickerScreen.kLng: _center.longitude,
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
        title: const Text('Pick Delivery Location',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: !_ready
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange))
          : Stack(
              children: [
                // ─── Map ───
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 16.5,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onPositionChanged: (pos, hasGesture) {
                      if (hasGesture) {
                        _center = pos.center;
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 700),
                          _reverseGeocode,
                        );
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.swiftdrop.app',
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),

                // ─── Fixed center pin (points at map center) ───
                const IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 56,
                            color: AppColors.orange,
                            shadows: [
                              Shadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 3)),
                            ]),
                        SizedBox(height: 34), // pin tip sits on the center
                      ],
                    ),
                  ),
                ),

                // ─── My Location button (right side, above panel) ───
                Positioned(
                  right: 16,
                  bottom: 210,
                  child: FloatingActionButton.small(
                    heroTag: 'mapPickerLocateMe',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.orange,
                    elevation: 3,
                    onPressed: _locateMe,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.orange))
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),

                // ─── Bottom panel: resolved address + confirm ───
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, -4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: AppColors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _geocoding && _address.startsWith('Resolving')
                                    ? 'Resolving address…'
                                    : _address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black),
                              ),
                            ),
                            if (_geocoding)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.orange),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Drag the map to move the pin to your exact door',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _geocoding ? null : _confirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.orange.withValues(alpha: 0.6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Confirm Location',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

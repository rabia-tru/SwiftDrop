import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../services/websocket_service.dart';
import '../services/eta_calculator.dart';
import 'chat_screen.dart';

/// SwiftDrop Map Screen — Premium modern design with live tracking
class MapScreen extends StatefulWidget {
  final String? orderId;
  final double? riderLat;
  final double? riderLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final String? riderName;
  final String? riderPhone;
  final String? estimatedTime;

  const MapScreen({
    super.key,
    this.orderId,
    this.riderLat,
    this.riderLng,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.riderName,
    this.riderPhone,
    this.estimatedTime,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late bool _showRiderInfo = widget.riderName != null;
  bool _showRouteDetails = false;
  late AnimationController _pulseController;

  LatLng? _liveRiderPosition;
  StreamSubscription? _riderLocationSub;

  LatLng? _defaultLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    if (widget.riderLat != null && widget.riderLng != null) {
      _liveRiderPosition = LatLng(widget.riderLat!, widget.riderLng!);
    }

    _getCurrentLocation();
    _setupWebSocketListener();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationDialog(
            'Location Services Disabled',
            'Enable location services to see your current location on the map.',
            true,
          );
        }
        return;
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationDialog(
            'Location Permission Required',
            'Enable location permission in settings to see your location on the map.',
            false,
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _defaultLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (_) {
      // Use null — will fallback to widget positions
      _defaultLocation = null;
    }
  }

  void _showLocationDialog(String title, String message, bool isServiceDisabled) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
              child: const Icon(Icons.location_off, color: AppColors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.darkGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (isServiceDisabled) {
                await Geolocator.openLocationSettings();
              } else {
                await Geolocator.openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _riderLocationSub?.cancel();
    super.dispose();
  }

  void _setupWebSocketListener() {
    final ws = WebSocketService.instance;
    if (widget.orderId != null) {
      ws.watchOrder(widget.orderId!);
    }

    _riderLocationSub = ws.riderLocationStream.listen((data) {
      if (!mounted) return;
      // Compare as strings — the server may send orderId as a non-String
      // (e.g. a number), and a strict `!=` would then silently drop every
      // single location update, which looks exactly like "the map never
      // moves".
      if (widget.orderId != null && data['orderId']?.toString() != widget.orderId) return;

      final lat = data['latitude'] as num?;
      final lng = data['longitude'] as num?;
      if (lat != null && lng != null) {
        final newPos = LatLng(lat.toDouble(), lng.toDouble());
        setState(() => _liveRiderPosition = newPos);
        _mapController.move(newPos, _mapController.camera.zoom);
      }
    });
  }

  LatLng get _riderPosition {
    return _liveRiderPosition ?? (widget.riderLat != null && widget.riderLng != null
        ? LatLng(widget.riderLat!, widget.riderLng!)
        : _defaultLocation ?? const LatLng(0, 0));
  }

  LatLng get _pickupPosition {
    if (widget.pickupLat != null && widget.pickupLng != null) {
      return LatLng(widget.pickupLat!, widget.pickupLng!);
    }
    return _defaultLocation ?? const LatLng(0, 0);
  }

  LatLng get _dropPosition {
    if (widget.dropLat != null && widget.dropLng != null) {
      return LatLng(widget.dropLat!, widget.dropLng!);
    }
    return _defaultLocation ?? const LatLng(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    AppColors.setLightStatusBar();
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite,
      body: Stack(
        children: [
          _buildMap(),
          // Top bar
          Positioned(
            top: statusBarHeight + 8,
            left: 16,
            right: 16,
            child: _buildTopBar(isDark),
          ),
          // ETA + Route summary
          Positioned(
            top: statusBarHeight + 72,
            left: 16,
            child: _buildETABadge(),
          ),
          // Zoom controls
          Positioned(
            top: statusBarHeight + 130,
            right: 16,
            child: _buildZoomControls(isDark),
          ),
          // Route details toggle
          Positioned(
            top: statusBarHeight + 72,
            right: 16,
            child: _buildRouteToggle(isDark),
          ),
          // Bottom rider card — only when there's an actual rider assigned
          if (_showRiderInfo && widget.riderName != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildRiderInfoCard(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _riderPosition,
        initialZoom: 14,
        onTap: (tapPosition, latLng) {
          if (widget.riderName != null) {
            setState(() => _showRiderInfo = !_showRiderInfo);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.swiftdrop.app',
        ),
        if (widget.pickupLat != null && widget.dropLat != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [_pickupPosition, _riderPosition, _dropPosition],
                color: AppColors.orange,
                strokeWidth: 5,
                borderStrokeWidth: 7,
                borderColor: Colors.white,
              ),
            ],
          ),
        MarkerLayer(markers: _buildMarkers()),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // ─── Customer (my) location marker — Google Maps style blue dot ──
    if (_defaultLocation != null) {
      markers.add(
        Marker(
          point: _defaultLocation!,
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft halo
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2196F3).withValues(alpha: 0.18),
                ),
              ),
              // Blue dot with white ring
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2196F3),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF2196F3).withValues(alpha: 0.4), blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Pickup marker (green)
    markers.add(
      Marker(
        point: _pickupPosition,
        width: 44,
        height: 44,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4CAF50).withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.store, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
              ),
              child: const Text('PICKUP', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF4CAF50))),
            ),
          ],
        ),
      ),
    );

    // Drop marker (orange pin)
    markers.add(
      Marker(
        point: _dropPosition,
        width: 48,
        height: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(color: AppColors.orange.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
            ),
            CustomPaint(size: const Size(16, 10), painter: _TrianglePainter(color: AppColors.orange)),
          ],
        ),
      ),
    );

    // Rider marker (animated pulse)
    if (widget.riderLat != null) {
      markers.add(
        Marker(
          point: _riderPosition,
          width: 70,
          height: 90,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulseSize = 30.0 + (_pulseController.value * 10);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse ring
                      Container(
                        width: pulseSize,
                        height: pulseSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.orange.withValues(alpha: 0.15 - (_pulseController.value * 0.1)),
                          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3), width: 1),
                        ),
                      ),
                      // Rider icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF7043), AppColors.orange],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(color: AppColors.orange.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 2),
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                          ],
                        ),
                        child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 6)],
                    ),
                    child: Text(
                      widget.riderName ?? 'Rider',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Tracking',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.black),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Connected • Real-time',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF909090) : AppColors.darkGray),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _mapController.move(_riderPosition, 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.orangePale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.my_location_rounded, color: AppColors.orange, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildETABadge() {
    final liveEta = EtaCalculator.getEtaString(
      riderLat: _riderPosition.latitude,
      riderLng: _riderPosition.longitude,
      destinationLat: _dropPosition.latitude,
      destinationLng: _dropPosition.longitude,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.orange, AppColors.orangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: AppColors.orange.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_filled, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            liveEta,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          Text(
            'remaining',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteToggle(bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _showRouteDetails = !_showRouteDetails),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
        ),
        child: Icon(
          _showRouteDetails ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
          color: AppColors.orange,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildZoomControls(bool isDark) {
    return Column(
      children: [
        _buildZoomButton(
          icon: Icons.add,
          onTap: () => _mapController.move(_riderPosition, _mapController.camera.zoom + 1),
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _buildZoomButton(
          icon: Icons.remove,
          onTap: () => _mapController.move(_riderPosition, _mapController.camera.zoom - 1),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildZoomButton({required IconData icon, required VoidCallback onTap, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
        ),
        child: Icon(icon, color: AppColors.orange, size: 22),
      ),
    );
  }

  Widget _buildRiderInfoCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, -8)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Rider row
              Row(
                children: [
                  // Rider avatar
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.riderName ?? 'Rider',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.black),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.circle, color: Color(0xFF4CAF50), size: 8),
                            const SizedBox(width: 4),
                            Text(
                              'On the way to you',
                              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF909090) : AppColors.darkGray),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // ETA badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.orangePale,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.estimatedTime ?? '5 min',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.orange),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.message_rounded,
                      label: 'Message',
                      isPrimary: false,
                      isDark: isDark,
                      onTap: _messageRider,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.phone_rounded,
                      label: 'Call Rider',
                      isPrimary: true,
                      isDark: isDark,
                      onTap: _callRider,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _callRider() async {
    final phone = widget.riderPhone?.trim();
    if (phone == null || phone.isEmpty) {
      _showToast('Rider\'s phone number is not available yet');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched) _showToast('Could not open the dialer');
  }

  void _messageRider() {
    final orderId = widget.orderId;
    if (orderId == null || orderId.isEmpty) {
      _showToast('Chat is only available once an order is placed');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        orderId: orderId,
        otherUserName: widget.riderName ?? 'Rider',
        otherUserRole: 'rider',
        currentUserRole: 'customer',
      ),
    ));
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isPrimary ? const LinearGradient(colors: [AppColors.orange, AppColors.orangeDark]) : null,
          color: isPrimary ? null : (isDark ? const Color(0xFF252525) : AppColors.lightGray),
          borderRadius: BorderRadius.circular(14),
          border: isPrimary ? null : Border.all(color: AppColors.gray.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : AppColors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : (isDark ? Colors.white : AppColors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
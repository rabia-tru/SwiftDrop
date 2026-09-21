import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Wrap any HTTP call with timeout and friendly error re-throwing.
Future<http.Response> _post(String url, Map<String, String> headers, String body) async {
  try {
    final res = await http.post(Uri.parse(url), headers: headers, body: body).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ApiException('Connection timed out. Please try again.'),
    );
    return res;
  } on ApiException {
    rethrow;
  } on SocketException catch (e) {
    if (e.message.contains('Connection refused')) {
      throw ApiException('Server is not running. Please try again later.');
    }
    if (e.message.contains('No route to host') || e.message.contains('Network is unreachable')) {
      throw ApiException('Cannot reach the server. Please check your WiFi connection.');
    }
    throw ApiException('No internet connection. Please check your WiFi or mobile data.');
  } on HttpException catch (e) {
    throw ApiException('Unable to reach the server: ${e.message}');
  } catch (e) {
    final raw = e.toString();
    if (raw.contains('SocketException') || raw.contains('OS Error')) {
      throw ApiException('No internet connection. Please check your WiFi or mobile data.');
    }
    if (raw.contains('TimeoutException') || raw.contains('timed out')) {
      throw ApiException('Connection timed out. Please try again.');
    }
    rethrow;
  }
}

Future<http.Response> _get(String url, Map<String, String> headers) async {
  try {
    final res = await http.get(Uri.parse(url), headers: headers).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ApiException('Connection timed out. Please try again.'),
    );
    return res;
  } on ApiException {
    rethrow;
  } on SocketException catch (e) {
    if (e.message.contains('Connection refused')) {
      throw ApiException('Server is not running. Please try again later.');
    }
    throw ApiException('No internet connection. Please check your WiFi or mobile data.');
  } catch (e) {
    final raw = e.toString();
    if (raw.contains('SocketException')) {
      throw ApiException('No internet connection. Please check your WiFi or mobile data.');
    }
    if (raw.contains('TimeoutException')) {
      throw ApiException('Connection timed out. Please try again.');
    }
    rethrow;
  }
}

Future<http.Response> _patch(String url, Map<String, String> headers, [String? body]) async {
  try {
    final res = await http.patch(Uri.parse(url), headers: headers, body: body).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ApiException('Connection timed out. Please try again.'),
    );
    return res;
  } on ApiException {
    rethrow;
  } on SocketException catch (e) {
    if (e.message.contains('Connection refused')) {
      throw ApiException('Server is not running. Please try again later.');
    }
    throw ApiException('No internet connection. Please check your WiFi or mobile data.');
  } catch (e) {
    final raw = e.toString();
    if (raw.contains('SocketException')) {
      throw ApiException('No internet connection. Please check your WiFi or mobile data.');
    }
    if (raw.contains('TimeoutException')) {
      throw ApiException('Connection timed out. Please try again.');
    }
    rethrow;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static const _tokenKey = 'auth_token';
  static const _riderIdKey = 'rider_id';
  static const _keepSignedInKey = 'keep_signed_in';
  static const _lastLoginRoleKey = 'last_login_role';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRiderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_riderIdKey);
  }

  static Future<bool> isKeepSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepSignedInKey) ?? false;
  }

  static Future<String?> getLastLoginRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastLoginRoleKey);
  }

  static Future<void> _saveSession(String token, String riderId, {String? role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_riderIdKey, riderId);
    if (role != null) await prefs.setString(_lastLoginRoleKey, role);
  }

  static Future<void> setKeepSignedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepSignedInKey, value);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_riderIdKey);
    await prefs.remove(_keepSignedInKey);
    await prefs.remove(_lastLoginRoleKey);
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _post(
      '${AppConfig.apiBaseUrl}/auth/rider/login',
      {'Content-Type': 'application/json'},
      jsonEncode({'email': email, 'password': password}),
    );
    final data = _handleResponse(res);
    await _saveSession(data['accessToken'], data['rider']['id'], role: 'rider');
    return data;
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String? vehicleType,
  }) async {
    final res = await _post(
      '${AppConfig.apiBaseUrl}/auth/rider/register',
      {'Content-Type': 'application/json'},
      jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
        if (vehicleType != null) 'vehicleType': vehicleType,
      }),
    );
    final data = _handleResponse(res);
    await _saveSession(data['accessToken'], data['rider']['id']);
    return data;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/riders/me',
      await _authHeaders(),
    );
    return _handleResponse(res);
  }

  /// Rider: update own profile (name, phone, vehicle info).
  static Future<Map<String, dynamic>> riderUpdateProfile(Map<String, dynamic> updates) async {
    final res = await _patch(
      '${AppConfig.apiBaseUrl}/riders/me/profile',
      await _authHeaders(),
      jsonEncode(updates),
    );
    return _handleResponse(res);
  }

  /// Customer: update own profile (name, phone, address).
  static Future<Map<String, dynamic>> customerUpdateProfile(Map<String, dynamic> updates) async {
    final res = await _patch(
      '${AppConfig.apiBaseUrl}/customers/me',
      await _authHeaders(),
      jsonEncode(updates),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateStatus(String status) async {
    final res = await _patch(
      '${AppConfig.apiBaseUrl}/riders/me/status',
      await _authHeaders(),
      jsonEncode({'status': status}),
    );
    return _handleResponse(res);
  }

  static Future<List<dynamic>> getMyOrders() async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/orders/mine',
      await _authHeaders(),
    );
    return _handleResponse(res) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getOrderById(String orderId) async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/orders/$orderId',
      await _authHeaders(),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status,
  ) async {
    final res = await _patch(
      '${AppConfig.apiBaseUrl}/orders/$orderId/status',
      await _authHeaders(),
      jsonEncode({'status': status}),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    final res = await _patch(
      '${AppConfig.apiBaseUrl}/orders/$orderId/accept',
      await _authHeaders(),
    );
    return _handleResponse(res);
  }

  /// Business confirms it will prepare this order. Separate from
  /// acceptOrder() above — that's the rider accepting the delivery,
  /// this is the restaurant/store confirming the order itself.
  static Future<Map<String, dynamic>> businessAcceptOrder(String orderId) async {
    final res = await _patch(
      '${AppConfig.apiBaseUrl}/orders/$orderId/business-accept',
      await _authHeaders(),
    );
    return _handleResponse(res);
  }

  /// Update the delivery address of an active order (customer-side edit).
  static Future<Map<String, dynamic>> updateOrderAddress(
    String orderId,
    String dropAddress,
  ) async {
    final res = await _patch(
      '${AppConfig.apiBaseUrl}/orders/$orderId/address',
      await _authHeaders(),
      jsonEncode({'dropAddress': dropAddress}),
    );
    return _handleResponse(res);
  }

  /// Called by the background service with a batch of queued pings.
  /// Static + no BuildContext dependency so it's safe to call from the
  /// background isolate.
  static Future<int> syncLocationBatch(List<Map<String, dynamic>> pings) async {
    final headers = await _authHeaders();
    final res = await _post(
      '${AppConfig.apiBaseUrl}/location/sync',
      headers,
      jsonEncode({'pings': pings}),
    );
    final data = _handleResponse(res);
    return data['saved'] as int;
  }

  /// Fetch persisted chat history for an order (oldest first).
  static Future<List<Map<String, dynamic>>> getChatHistory(String orderId) async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/chat/order/$orderId',
      await _authHeaders(),
    );
    final data = _handleResponse(res);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Send a chat message via REST — fallback when WebSocket is down.
  static Future<void> sendChatMessage({
    required String orderId,
    required String message,
    required String senderRole,
    String? senderName,
    String? imageUrl,
  }) async {
    final res = await _post(
      '${AppConfig.apiBaseUrl}/chat/send',
      {'Content-Type': 'application/json'},
      jsonEncode({
        'orderId': orderId,
        'message': message,
        'senderRole': senderRole,
        if (senderName != null && senderName.isNotEmpty) 'senderName': senderName,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      }),
    );
    _handleResponse(res);
  }

  // ─── Customer Auth ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> customerLogin(String email, String password) async {
    final res = await _post(
      '${AppConfig.apiBaseUrl}/customers/login',
      {'Content-Type': 'application/json'},
      jsonEncode({'email': email, 'password': password}),
    );
    final data = _handleResponse(res);
    await _saveSession(data['accessToken'], data['customer']['id'], role: 'customer');
    return data;
  }

  static Future<Map<String, dynamic>> customerRegister({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final res = await _post(
      '${AppConfig.apiBaseUrl}/customers/register',
      {'Content-Type': 'application/json'},
      jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
      }),
    );
    final data = _handleResponse(res);
    await _saveSession(data['accessToken'], data['customer']['id'], role: 'customer');
    return data;
  }

  static Future<Map<String, dynamic>> customerGetMe() async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/customers/me',
      await _authHeaders(),
    );
    return _handleResponse(res);
  }

  static Future<List<dynamic>> customerGetOrders() async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/orders/customer/mine',
      await _authHeaders(),
    );
    return _handleResponse(res) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> customerCreateOrder({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropAddress,
    required double dropLat,
    required double dropLng,
    double? fare,
    String? notes,
    String? businessId,
    String? businessName,
    List<Map<String, dynamic>>? items,
    String? paymentMethod,
  }) async {
    final me = await customerGetMe();
    final res = await _post(
      '${AppConfig.apiBaseUrl}/orders/customer',
      await _authHeaders(),
      jsonEncode({
        'customerName': me['name'] ?? 'Customer',
        'customerPhone': me['phone'] ?? '',
        'pickupAddress': pickupAddress,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropAddress': dropAddress,
        'dropLat': dropLat,
        'dropLng': dropLng,
        if (fare != null) 'fare': fare,
        if (notes != null) 'notes': notes,
        if (businessId != null) 'businessId': businessId,
        if (businessName != null) 'businessName': businessName,
        if (items != null) 'items': items,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
      }),
    );
    return _handleResponse(res);
  }

  // ─── Public Business List (for customers) ────────────────────

  static Future<List<dynamic>> getAllBusinesses() async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/business/list',
      await _authHeaders(),
    );
    return _asMenuList(_handleResponse(res));
  }

  /// Public menu of one business (used by the customer app).
  ///
  /// Two bugs used to hide newly added items here:
  ///  1. the call went out with no Authorization header, so a guarded
  ///     backend route answered 401 and the customer saw an empty menu;
  ///  2. the response was blind-cast with `as List<dynamic>`, which throws
  ///     a CastError whenever the backend wraps the array (e.g.
  ///     `{ "menu": [...] }`) — and the caller was swallowing that error.
  /// Both are handled below.
  static Future<List<dynamic>> getBusinessMenu(String businessId) async {
    if (businessId.trim().isEmpty) {
      throw ApiException('Missing business id — cannot load this menu.');
    }
    final res = await _get(
      '${AppConfig.apiBaseUrl}/business/$businessId/menu',
      await _authHeaders(),
    );
    return _asMenuList(_handleResponse(res));
  }

  /// Accepts every shape a backend might return a menu in.
  static List<dynamic> _asMenuList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in ['menu', 'menuItems', 'items', 'data', 'results']) {
        final value = decoded[key];
        if (value is List) return value;
      }
    }
    return const <dynamic>[];
  }

  // ─── Business Auth ──────────────────────────────────────────

  static Future<Map<String, dynamic>> businessLogin(String email, String password) async {
    final res = await _post(
      '${AppConfig.apiBaseUrl}/business/login',
      {'Content-Type': 'application/json'},
      jsonEncode({'email': email, 'password': password}),
    );
    final data = _handleResponse(res);
    await _saveSession(data['accessToken'], data['business']['id'], role: 'business');
    return data;
  }

  static Future<Map<String, dynamic>> businessRegister({
    required String name,
    required String phone,
    required String email,
    required String password,
    String? category,
    String? address,
  }) async {
    final res = await _post(
      '${AppConfig.apiBaseUrl}/business/register',
      {'Content-Type': 'application/json'},
      jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
        if (category != null) 'category': category,
        if (address != null) 'address': address,
      }),
    );
    final data = _handleResponse(res);
    await _saveSession(data['accessToken'], data['business']['id'], role: 'business');
    return data;
  }

  static Future<Map<String, dynamic>> businessGetMe() async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/business/me',
      await _authHeaders(),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> businessGetStats() async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/business/me/stats',
      await _authHeaders(),
    );
    return _handleResponse(res);
  }

  /// All orders in the system (admin/debug use).
  static Future<List<dynamic>> getAllOrders() async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/orders',
      await _authHeaders(),
    );
    return _handleResponse(res) as List<dynamic>;
  }

  /// Orders belonging ONLY to the logged-in business.
  static Future<List<dynamic>> businessGetMyOrders() async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/orders/business/mine',
      await _authHeaders(),
    );
    return _handleResponse(res) as List<dynamic>;
  }

  /// Update business profile (name, phone, address, isOpen...).
  static Future<Map<String, dynamic>> businessUpdateMe(Map<String, dynamic> updates) async {
    final res = await _patch(
      '${AppConfig.apiBaseUrl}/business/me',
      await _authHeaders(),
      jsonEncode(updates),
    );
    return _handleResponse(res);
  }

  static Future<List<dynamic>> businessGetMenu() async {
    final res = await _get(
      '${AppConfig.apiBaseUrl}/business/me/menu',
      await _authHeaders(),
    );
    return _asMenuList(_handleResponse(res));
  }

  /// Uploads a local image file (gallery/camera) to the backend.
  /// Returns the server URL that can be used as [imageUrl].
  static Future<String> uploadImage(String filePath, {String type = 'menu'}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Image file not found on device');
    }
    final fileSize = await file.length();
    if (fileSize > 8 * 1024 * 1024) {
      throw Exception('Image is too large (max 8MB). Try a smaller image.');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/upload/image');
    final req = http.MultipartRequest('POST', uri)
      ..fields['type'] = type
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final token = await getToken();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    try {
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return '${AppConfig.wsBaseUrl}${data['url']}';
      }
      // Try to parse error message from backend
      String detail = '';
      try {
        final body = jsonDecode(res.body);
        detail = body['message']?.toString() ?? body['error']?.toString() ?? '';
      } catch (_) {}
      if (res.statusCode == 400) {
        throw Exception(detail.isNotEmpty ? detail : 'This image format is not supported. Try JPG or PNG.');
      } else if (res.statusCode == 413) {
        throw Exception('Image is too large. Max size is 8MB.');
      } else if (res.statusCode >= 500) {
        throw Exception('Server error while uploading. Please try again.');
      }
      throw Exception(detail.isNotEmpty ? detail : 'Upload failed (error ${res.statusCode})');
    } on TimeoutException {
      throw Exception('Upload timed out. Check your internet connection.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Could not upload image — check your internet connection.');
    }
  }

  static Future<Map<String, dynamic>> businessAddMenuItem({
    required String name,
    required double price,
    String? description,
    String? category,
    int? preparationTime,
    List<String>? tags,
    String? imageUrl,
  }) async {
    final res = await _post(
      '${AppConfig.apiBaseUrl}/business/me/menu',
      await _authHeaders(),
      jsonEncode({
        'name': name,
        'price': price,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (preparationTime != null) 'preparationTime': preparationTime,
        if (tags != null) 'tags': tags,
        if (imageUrl != null) 'imageUrl': imageUrl,
      }),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> businessUpdateMenuItem(
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    final res = await _patch(
      '${AppConfig.apiBaseUrl}/business/me/menu/$itemId',
      await _authHeaders(),
      jsonEncode(updates),
    );
    return _handleResponse(res);
  }

  static Future<void> businessDeleteMenuItem(String itemId) async {
    final res = await _delete(
      '${AppConfig.apiBaseUrl}/business/me/menu/$itemId',
      await _authHeaders(),
    );
    _handleResponse(res);
  }

  static Future<Map<String, dynamic>> businessToggleAvailability(String itemId) async {
    final res = await _patch(
      '${AppConfig.apiBaseUrl}/business/me/menu/$itemId/toggle',
      await _authHeaders(),
    );
    return _handleResponse(res);
  }

  // ─── Forgot Password ───────────────────────────────────────

  static Future<Map<String, dynamic>> forgotPassword(String email, {String? role}) async {
    final res = await _post(
      '${AppConfig.apiBaseUrl}/auth/forgot-password',
      {'Content-Type': 'application/json'},
      jsonEncode({'email': email, 'role': role}),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String token, String newPassword, {String? role}) async {
    final res = await _post(
      '${AppConfig.apiBaseUrl}/auth/reset-password',
      {'Content-Type': 'application/json'},
      jsonEncode({'email': email, 'token': token, 'newPassword': newPassword, 'role': role}),
    );
    return _handleResponse(res);
  }

  // ─── HTTP Helpers ──────────────────────────────────────────────

  static Future<http.Response> _delete(String url, Map<String, String> headers) async {
    try {
      final res = await http.delete(Uri.parse(url), headers: headers).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw ApiException('Connection timed out. Please try again.'),
      );
      return res;
    } on ApiException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        throw ApiException('No internet connection. Please check your WiFi or mobile data.');
      }
      rethrow;
    }
  }

  static dynamic _handleResponse(http.Response res) {
    final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }
    String message;
    if (decoded is Map && decoded['message'] != null) {
      final msg = decoded['message'];
      if (msg is List) {
        message = msg.map((e) => e.toString()).join('. ');
      } else {
        message = msg.toString();
      }
    } else if (decoded is Map && decoded['error'] != null) {
      message = decoded['error'].toString();
    } else if (decoded is Map && decoded['statusCode'] != null) {
      message = decoded.toString();
    } else {
      message = 'Request failed (${res.statusCode}). Please try again.';
    }
    throw ApiException(message);
  }
}
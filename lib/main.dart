import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/realtime_order_tracker.dart';
import 'services/customer_background_service.dart';
import 'services/rider_background_service.dart';
import 'services/background_location_service.dart';
import 'services/push_notification_service.dart';
import 'services/websocket_service.dart';
import 'services/notification_tap_handler.dart';
import 'services/chat_unread_service.dart';
import 'services/network_binding_service.dart';
import 'services/rider_notification_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global image cache: once a dish photo is downloaded it stays in memory —
  // scrolling the menu back up or reopening a restaurant no longer
  // re-downloads anything (big perceived-speed win together with the CDN
  // crop params added to every Unsplash URL).
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

  // Enable edge-to-edge display and remove white borders
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const SwiftDropApp());

  // Pin app sockets to WiFi (mobile-data-on no longer breaks LAN backend
  // access) and re-assert on every app resume.
  NetworkBindingService.instance.init();

  // Unread chat badge tracking (persisted + live via WebSocket stream)
  ChatUnreadService.instance.init();

  // Wire the notification tap handler with the app's navigator key
  NotificationTapHandler.init(SwiftDropApp.swiftDropNavigatorKey);
  
  // Initialize background services AFTER the app starts (non-blocking)
  // This prevents ANR on slow devices
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await PushNotificationService.initialize();
      // Android 13+ silently drops ALL notifications until the POST_NOTIFICATIONS
      // permission is granted — this is why notifications "were not coming".
      // Ask right at startup instead of only when a rider goes online.
      await PushNotificationService.requestPermissionIfNeeded();
    } catch (_) {}
    
    try {
      await BackgroundLocationService.initialize();
      // Restore tracking state if rider was tracking before app was killed
      await BackgroundLocationService.restoreTrackingState();
    } catch (_) {}
    
    try {
      await CustomerBackgroundService.initialize();
      await CustomerBackgroundService.restoreTrackingState();
    } catch (_) {}
    
    try {
      await RiderBackgroundService.initialize();
      await RiderBackgroundService.restoreTrackingState();
    } catch (_) {}
    
    try {
      WebSocketService.instance.connect();
    } catch (_) {}

    // Global rider notifications: order assignments, "food is ready for
    // pickup" pings and business confirmations become system notifications
    // + in-app snackbars on ANY screen (not just rider Home).
    try {
      RiderNotificationService.instance.start();
    } catch (_) {}
  });
}

class SwiftDropApp extends StatelessWidget {
  const SwiftDropApp({super.key});

  /// Global navigator key — used by the notification tap handler to push
  /// the live-tracking screen regardless of where in the app the user is.
  static final GlobalKey<NavigatorState> swiftDropNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RealtimeOrderTracker()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: themeProvider.isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: themeProvider.isDark ? Brightness.light : Brightness.dark,
          ));

          return MaterialApp(
            title: 'SwiftDrop',
            debugShowCheckedModeBanner: false,
            navigatorKey: SwiftDropApp.swiftDropNavigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            // Improve text rendering - remove blur and ensure crisp text
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.0), // Prevent text scaling issues
                  boldText: false, // Disable bold text accessibility
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    decoration: TextDecoration.none,
                    // Optimized text rendering
                    textBaseline: TextBaseline.alphabetic,
                  ),
                  child: child!,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

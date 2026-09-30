import Flutter
import UIKit
import CoreLocation
import BackgroundTasks
import UserNotifications

// ───────────────────────────────────────────────────────────────────────
// Native iOS background location tracking.
//
// `flutter_background_service` cannot keep a Dart isolate alive once iOS
// suspends the app, so rider GPS tracking on iOS is implemented here in
// native code instead — mirroring the Android pipeline:
//
//   CLLocationManager (allowsBackgroundLocationUpdates)
//        ↓  every fix
//   local JSON queue (Library/Application Support/location_queue.json)
//        ↓  opportunistically + on BGAppRefreshTask
//   background URLSession upload → POST {base}/api/location/sync
//
// A background URLSession keeps uploading even while the app is
// suspended, and iOS relaunches the app in the background to finish
// session events (didFinishDownloading etc.), which is why upload state
// is persisted in UserDefaults rather than held in memory.
//
// Dart talks to this over the `app/native_location` method channel (see
// lib/services/ios_native_location_service.dart).
// ───────────────────────────────────────────────────────────────────────

private struct QueuedPing: Codable {
  let latitude: Double
  let longitude: Double
  let speed: Double
  let accuracy: Double
  let orderId: String
  let recordedAt: String
}

private struct QueueFile: Codable {
  var pings: [QueuedPing] = []
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let locationManager = CLLocationManager()
  private let notificationCenter = UNUserNotificationCenter.current()

  /// Method channel to Dart. Created in didInitializeImplicitFlutterEngine
  /// once the implicit engine exists (creating it earlier crashes on the
  /// UIScene lifecycle — the messenger isn't valid yet).
  private var channel: FlutterMethodChannel?

  // Native tracking state
  private var trackingOrderId: String = ""
  private var trackingActive = false
  private var lastSyncAttempt: Date?
  private var sessionInFlight = false
  private var pendingUploadFilePath: String?
  private var backgroundSession: URLSession?

  // Motion-adaptive tracking (mirrors lib/services/adaptive_tracking_policy.dart)
  private enum TrackingMode {
    case idle
    case walking
    case active
  }

  private static let walkingSpeedThreshold: Double = 1.5 // m/s (~5.4 km/h)
  private static let activeSpeedThreshold: Double = 2.5 // m/s (~9 km/h)
  private static let activeFilter: Double = 10 // m
  private static let walkingFilter: Double = 50 // m
  private static let activeHoldSeconds: TimeInterval = 45
  private static let stationaryAfterSeconds: TimeInterval = 90

  private var mode: TrackingMode = .active
  private var lastFastFix: Date?
  private var slowSince: Date?

  private static let queueFileName = "location_queue.json"
  private static let defaultApiBase = "http://192.168.54.240:3000" // matches AppConfig fallback
  private static let uploadTaskId = "app.swiftdrop.locationupload"
  private static let refreshTaskId = "com.swiftdrop.locationrefresh"
  private static let processingTaskId = "com.swiftdrop.processing"
  private static let defaultsOrderIdKey = "native_tracking_order_id"
  private static let defaultsActiveKey = "native_tracking_active"
  private static let defaultsApiBaseKey = "native_tracking_api_base"
  private static let minSyncInterval: TimeInterval = 30 // mirrors AppConfig.locationSyncIntervalSeconds

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Notification permission (persistent tracking notice etc.)
    notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      print("[NativeLocation] Notification permission: \(granted)")
    }
    application.registerForRemoteNotifications()

    // CLLocationManager configuration. Note: we do NOT call
    // requestAlwaysAuthorization() unconditionally at launch — Dart asks
    // for it at the moment the rider goes online (requestPermissions),
    // which matches Apple's guidance of prompting in context.
    locationManager.delegate = self
    locationManager.activityType = .otherNavigation
    locationManager.pausesLocationUpdatesAutomatically = false
    applyModeToLocationManager()
    if Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") != nil {
      // Only allow background updates if the app has the background mode;
      // otherwise iOS throws an NSInvalidArgumentException on
      // startUpdatingLocation with allowsBackgroundLocationUpdates = true.
      let hasBackgroundMode = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil
      locationManager.allowsBackgroundLocationUpdates = hasBackgroundMode
    }

    // Restore tracking state across process relaunches. iOS relaunches the
    // app in the background to deliver URLSession/bgtask events — the app
    // must re-arm CLLocationManager itself here, exactly like Android's
    // restoreTrackingState() path does after a process kill.
    let d = UserDefaults.standard
    trackingActive = d.bool(forKey: Self.defaultsActiveKey)
    trackingOrderId = d.string(forKey: Self.defaultsOrderIdKey) ?? ""
    if trackingActive {
      // SLC relaunch: if we were woken by a significant location change
      // while idle, this is the movement wake-up — re-evaluate the mode
      // and restart continuous updates when the rider is moving.
      applyModeToLocationManager()
      if mode != .idle {
        locationManager.startUpdatingLocation()
      } else {
        // Idle + relaunched by SLC → treat as movement, re-arm GPS.
        transition(to: .active, at: Date())
      }
      print("[NativeLocation] Restored active tracking (order \(trackingOrderId)) after relaunch")
    }

    // BGTaskScheduler registration (iOS 13+). Identifiers must be declared
    // under BGTaskSchedulerPermittedIdentifiers in Info.plist.
    if #available(iOS 13.0, *) {
      BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskId, using: nil) { task in
        self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
      }
      BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.processingTaskId, using: nil) { task in
        self.handleBackgroundProcessing(task: task as! BGProcessingTask)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Implicit engine delegate (UIScene lifecycle)

  /// Called when the implicit Flutter engine is initialized. This is the
  /// earliest safe point to create method channels for the default
  /// FlutterViewController under the UIScene lifecycle.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    channel = FlutterMethodChannel(name: "app/native_location", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }
    print("[NativeLocation] Method channel ready")
  }

  // MARK: - Method channel handlers

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startTracking":
      if let args = call.arguments as? [String: Any] {
        trackingOrderId = args["orderId"] as? String ?? ""
        if let base = args["apiBaseUrl"] as? String, !base.isEmpty {
          UserDefaults.standard.set(base, forKey: Self.defaultsApiBaseKey)
        }
      }
      trackingActive = true
      let d = UserDefaults.standard
      d.set(true, forKey: Self.defaultsActiveKey)
      d.set(trackingOrderId, forKey: Self.defaultsOrderIdKey)

      switch CLLocationManager.authorizationStatus() {
      case .authorizedAlways:
        locationManager.startUpdatingLocation()
        result(true)
      case .notDetermined:
        locationManager.requestAlwaysAuthorization()
        // didChangeAuthorization will start updates once granted; report
        // optimistic success so Dart keeps its "online" state in sync.
        result(true)
      case .authorizedWhenInUse:
        // Prompt the upgrade dialog once; tracking continues while the
        // app is usable and upgrades if the user allows "Always".
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        result(true)
      default:
        // Denied / restricted — Dart handles messaging the user.
        result(false)
      }

    case "stopTracking":
      trackingActive = false
      trackingOrderId = ""
      let d = UserDefaults.standard
      d.set(false, forKey: Self.defaultsActiveKey)
      d.set("", forKey: Self.defaultsOrderIdKey)
      locationManager.stopUpdatingLocation()
      flushQueue(reason: "stop") // deliver whatever is still queued
      result(true)

    case "setAdaptiveMode":
      // Reserved for Dart-driven overrides; the policy adapts natively
      // from fix speeds, so Dart does not need to push modes down.
      result(true)

    case "isTracking":
      result(trackingActive && CLLocationManager.locationServicesEnabled())

    case "requestPermissions":
      switch CLLocationManager.authorizationStatus() {
      case .notDetermined:
        locationManager.requestAlwaysAuthorization()
        result("notDetermined")
      case .authorizedAlways:
        result("always")
      case .authorizedWhenInUse:
        locationManager.requestAlwaysAuthorization()
        result("whenInUse")
      case .denied:
        result("denied")
      case .restricted:
        result("restricted")
      @unknown default:
        result("unknown")
      }

    case "flushQueue":
      flushQueue(reason: "manual")
      result(true)

    case "pendingCount":
      result(loadQueue().pings.count)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Motion-adaptive mode (mirrors AdaptiveTrackingPolicy in Dart)

  /// Applies the current mode's radio settings to CLLocationManager.
  private func applyModeToLocationManager() {
    switch mode {
    case .active:
      locationManager.desiredAccuracy = kCLLocationAccuracyBest
      locationManager.distanceFilter = Self.activeFilter
    case .walking:
      locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
      locationManager.distanceFilter = Self.walkingFilter
    case .idle:
      // No live updates; GPS duty cycle collapses to one fix per 2 min.
      locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
      locationManager.distanceFilter = 150
    }
  }

  /// Speed-based mode transitions with the same hysteresis as Dart.
  private func policyOnFix(speed: Double, at date: Date) {
    let isFast = speed >= Self.activeSpeedThreshold
    let isWalking = speed >= Self.walkingSpeedThreshold && speed < Self.activeSpeedThreshold
    let isSlow = speed < Self.walkingSpeedThreshold

    switch mode {
    case .active:
      if isFast || isWalking {
        slowSince = nil
        lastFastFix = date
      } else {
        if slowSince == nil { slowSince = date }
        if let s = slowSince, date.timeIntervalSince(s) >= Self.stationaryAfterSeconds {
          transition(to: .idle, at: date)
        } else if let l = lastFastFix,
                  date.timeIntervalSince(l) > Self.activeHoldSeconds,
                  !isWalking {
          transition(to: .walking, at: date)
        }
      }
    case .walking:
      if isFast {
        slowSince = nil
        lastFastFix = date
        transition(to: .active, at: date)
      } else if isWalking {
        slowSince = nil
        lastFastFix = date
      } else {
        if slowSince == nil { slowSince = date }
        if let s = slowSince, date.timeIntervalSince(s) >= Self.stationaryAfterSeconds {
          transition(to: .idle, at: date)
        }
      }
    case .idle:
      if isFast {
        transition(to: .active, at: date)
        slowSince = nil
        lastFastFix = date
      } else if isWalking {
        transition(to: .walking, at: date)
        slowSince = nil
        lastFastFix = date
      }
    }
  }

  private func transition(to next: TrackingMode, at date: Date) {
    guard next != mode else { return }
    print("[NativeLocation] 🔋 Mode \(mode) → \(next)")
    mode = next
    if next != .active { lastFastFix = nil }
    if next != .idle { slowSince = nil }
    if next == .active { lastFastFix = date }
    applyModeToLocationManager()

    // Entering idle: stop the radio; iOS will still deliver a wake-up fix
    // through the significant-change service (near-zero battery). Leaving
    // idle (movement) restarts continuous updates.
    if next == .idle {
      locationManager.stopUpdatingLocation()
      if CLLocationManager.significantLocationChangeMonitoringAvailable() {
        locationManager.startMonitoringSignificantLocationChanges()
      }
    } else {
      locationManager.stopMonitoringSignificantLocationChanges()
      if trackingActive {
        locationManager.startUpdatingLocation()
      }
    }
  }

  // MARK: - Location queue

  private func queueFileURL() -> URL {
    let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
    return docs.appendingPathComponent(Self.queueFileName)
  }

  private func loadQueue() -> QueueFile {
    let url = queueFileURL()
    guard let data = try? Data(contentsOf: url) else { return QueueFile() }
    return (try? JSONDecoder().decode(QueueFile.self, from: data)) ?? QueueFile()
  }

  private func saveQueue(_ queue: QueueFile) {
    let url = queueFileURL()
    if let data = try? JSONEncoder().encode(queue) {
      try? data.write(to: url, options: .atomic)
    }
  }

  /// Called for every CLLocationManager fix while tracking is active.
  private func enqueuePing(_ location: CLLocation) {
    var queue = loadQueue()
    queue.pings.append(QueuedPing(
      latitude: location.coordinate.latitude,
      longitude: location.coordinate.longitude,
      speed: max(0, location.speed),
      accuracy: location.horizontalAccuracy,
      orderId: trackingOrderId,
      recordedAt: ISO8601DateFormatter().string(from: location.timestamp)
    ))
    // Safety valve: never let the queue grow unbounded if the backend is
    // unreachable for a very long time (mirrors the Android 100-cap per
    // batch, but here caps the whole offline backlog).
    if queue.pings.count > 2000 {
      queue.pings.removeFirst(queue.pings.count - 2000)
    }
    saveQueue(queue)

    maybeSync()
  }

  /// Upload at most every minSyncInterval seconds, and only while no
  /// background upload is already running.
  private func maybeSync() {
    if let last = lastSyncAttempt, Date().timeIntervalSince(last) < Self.minSyncInterval {
      return
    }
    if sessionInFlight { return }
    flushQueue(reason: "interval")
  }

  /// Write the current queue to a temp file and hand it to a background
  /// URLSession upload task. The upload continues even if iOS suspends us
  /// right after; results arrive in the session events below.
  private func flushQueue(reason: String) {
    let queue = loadQueue()
    guard !queue.pings.isEmpty, !sessionInFlight else { return }
    guard let base = UserDefaults.standard.string(forKey: Self.defaultsApiBaseKey), !base.isEmpty else {
      print("[NativeLocation] No apiBaseUrl saved yet — skipping sync")
      return
    }

    let payload: [String: Any] = ["pings": queue.pings.map { ping -> [String: Any] in
      var p: [String: Any] = [
        "latitude": ping.latitude,
        "longitude": ping.longitude,
        "speed": ping.speed,
        "accuracy": ping.accuracy,
        "recordedAt": ping.recordedAt,
      ]
      if !ping.orderId.isEmpty { p["orderId"] = ping.orderId }
      return p
    }]

    guard JSONSerialization.isValidJSONObject(payload),
          let body = try? JSONSerialization.data(withJSONObject: payload) else {
      print("[NativeLocation] Failed to serialize upload payload")
      return
    }

    // Persist body to a temp file: background uploads REQUIRE a file URL,
    // and it also gives us a durable copy to delete on success.
    let tmpUrl = FileManager.default.temporaryDirectory
      .appendingPathComponent("loc_upload_\(Int(Date().timeIntervalSince1970 * 1000)).json")
    do {
      try body.write(to: tmpUrl, options: .atomic)
    } catch {
      print("[NativeLocation] Failed to write upload temp file: \(error)")
      return
    }

    var request = URLRequest(url: URL(string: "\(base)/api/location/sync")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let token = UserDefaults.standard.string(forKey: "flutter.auth_token")
    if let token = token, !token.isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let config = URLSessionConfiguration.background(withIdentifier: Self.uploadTaskId)
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true // iOS relaunches the app to finish the upload
    let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    backgroundSession = session
    sessionInFlight = true
    lastSyncAttempt = Date()
    pendingUploadFilePath = tmpUrl.path

    let task = session.uploadTask(with: request, fromFile: tmpUrl)
    task.resume()
    print("[NativeLocation] 📤 Upload started (\(queue.pings.count) pings) reason=\(reason)")
  }

  // MARK: - BGTaskScheduler handlers (iOS 13+)

  private func scheduleBackgroundRefresh() {
    if #available(iOS 13.0, *) {
      let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskId)
      request.earliestBeginDate = Date(timeIntervalSinceNow: 30)
      do {
        try BGTaskScheduler.shared.submit(request)
      } catch {
        print("[NativeLocation] Failed to schedule refresh: \(error)")
      }
    }
  }

  private func handleBackgroundRefresh(task: BGAppRefreshTask) {
    scheduleBackgroundRefresh() // keep the chain alive
    // Catch-up flush: normally uploads happen from CLLocationManager
    // callbacks, but if the queue has leftovers (backend was down, app
    // suspended mid-upload) this is the chance to clear them.
    flushQueue(reason: "bgrefresh")
    // Give the upload a head start before marking completion; the
    // background session itself keeps running beyond the task window.
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
      task.setTaskCompleted(success: true)
    }
  }

  private func scheduleBackgroundProcessing() {
    if #available(iOS 13.0, *) {
      let request = BGProcessingTaskRequest(identifier: Self.processingTaskId)
      request.requiresNetworkConnectivity = true
      request.requiresExternalPower = false
      do {
        try BGTaskScheduler.shared.submit(request)
      } catch {
        print("[NativeLocation] Failed to schedule processing: \(error)")
      }
    }
  }

  private func handleBackgroundProcessing(task: BGProcessingTask) {
    scheduleBackgroundProcessing()
    flushQueue(reason: "bgprocessing")
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
      task.setTaskCompleted(success: true)
    }
  }

  // MARK: - App lifecycle

  override func applicationDidEnterBackground(_ application: UIApplication) {
    if trackingActive && mode != .idle {
      locationManager.startUpdatingLocation() // re-arm in case iOS paused us
    }
    scheduleBackgroundRefresh()
    scheduleBackgroundProcessing()
    flushQueue(reason: "backgrounded")
  }
}

// MARK: - CLLocationManagerDelegate

extension AppDelegate: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard trackingActive, let location = locations.last else { return }
    // Skip stale/very inaccurate fixes.
    guard abs(location.timestamp.timeIntervalSinceNow) < 30,
          location.horizontalAccuracy >= 0,
          location.horizontalAccuracy < 100 else { return }

    policyOnFix(speed: max(0, location.speed), at: location.timestamp)
    enqueuePing(location)
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .authorizedAlways:
      print("[NativeLocation] Always authorized ✓")
      if trackingActive {
        applyModeToLocationManager()
        manager.startUpdatingLocation()
      }
    case .authorizedWhenInUse:
      print("[NativeLocation] When-in-use — requesting Always upgrade")
      if trackingActive { manager.startUpdatingLocation() }
      manager.requestAlwaysAuthorization()
    case .denied, .restricted:
      print("[NativeLocation] Location denied/restricted — tracking cannot continue")
      if trackingActive {
        manager.stopUpdatingLocation()
        // Tell Dart so the UI can reflect reality.
        channel?.invokeMethod("onPermissionLost", arguments: nil)
      }
    case .notDetermined:
      break
    @unknown default:
      break
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("[NativeLocation] Location error: \(error.localizedDescription)")
  }
}

// MARK: - URLSessionDataDelegate (background upload results)

extension AppDelegate: URLSessionDataDelegate {
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    sessionInFlight = false
    if let error = error {
      print("[NativeLocation] ❌ Upload failed: \(error.localizedDescription) — pings stay queued")
      // Queue is untouched; next flush retries. Clean up the temp file.
      if let path = pendingUploadFilePath {
        try? FileManager.default.removeItem(atPath: path)
      }
      pendingUploadFilePath = nil
      return
    }

    guard let httpResp = task.response as? HTTPURLResponse else { return }
    if (200..<300).contains(httpResp.statusCode) {
      // Success: remove exactly what we uploaded.
      var queue = loadQueue()
      guard let path = pendingUploadFilePath,
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let pings = body["pings"] as? [[String: Any]] else {
        pendingUploadFilePath = nil
        return
      }
      let uploadedCount = pings.count
      if queue.pings.count >= uploadedCount {
        queue.pings.removeFirst(uploadedCount)
      } else {
        queue.pings.removeAll()
      }
      saveQueue(queue)
      print("[NativeLocation] ✅ Synced \(uploadedCount) pings (HTTP \(httpResp.statusCode))")
    } else {
      print("[NativeLocation] ⚠️ Upload got HTTP \(httpResp.statusCode) — pings stay queued")
    }
    if let path = pendingUploadFilePath {
      try? FileManager.default.removeItem(atPath: path)
    }
    pendingUploadFilePath = nil
    backgroundSession?.finishTasksAndInvalidate()
    backgroundSession = nil
  }
}

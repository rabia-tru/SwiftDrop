import Flutter
import UIKit
import CoreLocation
import BackgroundTasks
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterApplicationDelegate {
  private let locationManager = CLLocationManager()
  private let notificationCenter = UNUserNotificationCenter.current()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Request notification permission first
    notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      print("[AppDelegate] Notification permission: \(granted)")
    }
    application.registerForRemoteNotifications()
    
    // Request location authorization
    locationManager.delegate = self
    locationManager.requestAlwaysAuthorization()
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.activityType = .otherNavigation
    
    // Register BGTaskScheduler for background refresh (iOS 13+)
    if #available(iOS 13.0, *) {
      BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.swiftdrop.locationrefresh",
        using: nil
      ) { task in
        self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
      }
      
      BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.swiftdrop.processing",
        using: nil
      ) { task in
        self.handleBackgroundProcessing(task: task as! BGProcessingTask)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Background Refresh (iOS 13+)
  
  @available(iOS 13.0, *)
  func scheduleBackgroundRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.swiftdrop.locationrefresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30 seconds minimum
    do {
      try BGTaskScheduler.shared.submit(request)
      print("[AppDelegate] Background refresh scheduled")
    } catch {
      print("[AppDelegate] Failed to schedule background refresh: \(error)")
    }
  }
  
  @available(iOS 13.0, *)
  func handleBackgroundRefresh(task: BGAppRefreshTask) {
    // Schedule next refresh immediately to keep the chain going
    scheduleBackgroundRefresh()
    
    // The actual location sync happens in the flutter_background_service
    // This just ensures iOS keeps the app eligible for background execution
    task.setTaskCompleted(success: true)
  }
  
  // MARK: - Background Processing (iOS 13+)
  
  @available(iOS 13.0, *)
  func scheduleBackgroundProcessing() {
    let request = BGProcessingTaskRequest(identifier: "com.swiftdrop.processing")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    do {
      try BGTaskScheduler.shared.submit(request)
      print("[AppDelegate] Background processing scheduled")
    } catch {
      print("[AppDelegate] Failed to schedule background processing: \(error)")
    }
  }
  
  @available(iOS 13.0, *)
  func handleBackgroundProcessing(task: BGProcessingTask) {
    scheduleBackgroundProcessing()
    // Used for syncing location data to server
    task.setTaskCompleted(success: true)
  }
  
  // MARK: - App Lifecycle
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    if #available(iOS 13.0, *) {
      scheduleBackgroundRefresh()
      scheduleBackgroundProcessing()
    }
    
    // Start location updates in background
    locationManager.startUpdatingLocation()
    print("[AppDelegate] App entered background, location updates started")
  }
  
  override func applicationWillEnterForeground(_ application: UIApplication) {
    print("[AppDelegate] App entering foreground")
  }
  
  // MARK: - Remote Notifications
  
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("[AppDelegate] Push token: \(token)")
  }
  
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[AppDelegate] Failed to register for remote notifications: \(error)")
  }
}

// MARK: - CLLocationManagerDelegate

extension AppDelegate: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // Forward location updates to Flutter via method channel
    guard let location = locations.last else { return }
    print("[AppDelegate] Background location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
  }
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .notDetermined:
      print("[AppDelegate] Location: not determined")
    case .restricted:
      print("[AppDelegate] Location: restricted")
    case .denied:
      print("[AppDelegate] Location: denied - please enable in Settings")
    case .authorizedAlways:
      print("[AppDelegate] Location: always authorized ✓")
      manager.startUpdatingLocation()
    case .authorizedWhenInUse:
      print("[AppDelegate] Location: when in use - requesting always")
      manager.requestAlwaysAuthorization()
    @unknown default:
      break
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("[AppDelegate] Location error: \(error.localizedDescription)")
  }
}

# Watchdog & Boot-Resume QA — Manual Test Checklist (Real Device)

**Feature:** Kill-survival watchdog — auto-restarts the background tracking service when Android or an OEM task manager kills it mid-delivery — **and** boot-resume receiver, which restarts tracking after a device reboot or app update when tracking flags were active.

**Applies to:** Android only (`com.example.rider_app`). iOS kill-survival is handled natively (SLC relaunch) and is out of scope for this checklist.

**Prereqs:** Backend reachable from the device (PC LAN IP), rider account with an active order in `in_transit`, `adb` on PATH, device connected via USB debugging.

---

## 0. Setup (run once)

```bash
# Confirm device + app
adb devices
adb shell pm list packages | findstr rider_app      # Windows
# adb shell pm list packages | grep rider_app       # macOS/Linux

# Install a debug/release build with the watchdog
flutter run --release          # or flutter build apk --release && adb install -r build/app/outputs/flutter-apk/app-release.apk

# Start a clean logcat capture for the whole session (separate terminal)
adb logcat -c
adb logcat | findstr /i "Watchdog UnifiedBG FlutterBackgroundService BackgroundService Killing am_kill"
# macOS/Linux: adb logcat | grep -iE "watchdog|unifiedbg|backgroundservice|killing|am_kill"
```

**Success:** device listed, app installs and launches, logcat stream is live.

---

## 1. Watchdog arms when tracking starts

1. Log in as the rider, go online, accept/have an active delivery (or just toggle tracking on).
2. Watch logcat for:

```
[UnifiedBG] ✅ Configured — one onStart handles GPS + ETA jobs
[Watchdog] ✅ Armed — restart alarm chain active
```

3. Verify the heartbeat is being written:

```bash
adb shell run-as com.example.rider_app cat /data/data/com.example.rider_app/shared_prefs/FlutterSharedPreferences.xml | findstr watchdog
# Expect: watchdog_armed = true, watchdog_heartbeat_ms ≈ current epoch ms
# (repeat after ~30s: heartbeat value must have advanced)
```

**Pass criteria:** both lines appear; heartbeat advances every ~30 s.
**Fail if:** `[Watchdog] ⚠️ Native side unreachable` repeats — the method channel isn't reaching MainActivity.

---

## 2. Kill the app mid-delivery → watchdog restarts the service

1. With an active order + tracking on, force-stop via ADB (worst-case OEM kill simulation):

```bash
adb shell am force-stop com.example.rider_app
```

> `am force-stop` is *harsher* than real-world OEM kills (it also cancels alarms for some Android versions). If after ~3 min no restart happened, also try the gentler, more realistic kill:

```bash
adb shell am kill com.example.rider_app        # kills background process, alarms survive
```

2. Note the kill time (`T0`). Do **not** touch the device.
3. Wait up to ~2.5 min (stale window 90 s + tick 120 s worst-case alignment).
4. Watch logcat for (tag is `Watchdog`, level W/I):

```
W/Watchdog: Service dead (heartbeat age XXXXXms) — restarting
```

followed by the plugin's cold-start sequence:

```
[UnifiedBG] ✅ Configured ...
flutter_background_service: Starting service
```

5. Confirm state resumed (not a blank restart):
   - Rider still shows "online / tracking" in-app after reopening.
   - Customer side (second device or emulator with a customer account) sees the rider's marker resume moving after ≤ 2.5 min of freeze.
   - Backend `/location/sync` receives fresh pings (check backend console or `location_logs` table).

```bash
# Confirm the service process is alive again:
adb shell pidof com.example.rider_app
```

**Pass criteria:**
- `Service dead — restarting` appears **within 2.5 min** of T0.
- Service restarts with the SAME order context (no re-login, no lost tracking flag).
- Pings flow to the backend again; customer map unfreezes.

**Fail if:** nothing appears after 3 min → also verify the `Watchdog` tag isn't filtered out of your logcat stream, then see §6 triage.

---

## 3. Timing characterization (document the actual numbers)

Run §2 three times and record what you observe — the worst case is (90 s staleness + up to 120 s to next tick), typical is ~1.5–2 min:

| Run | Kill (T0) | "Service dead" seen | Restart confirmed | Heartbeat age at restart |
|-----|-----------|---------------------|-------------------|--------------------------|
| 1   |           |                     |                   |                          |
| 2   |           |                     |                   |                          |
| 3   |           |                     |                   |                           |

**Acceptance:** restart signal consistently ≤ 150 s; no run where the service stays dead.

---

## 4. No zombie resurrection (watchdog disarms itself)

1. Rider goes **offline** / delivers the order (all tracking flags off).
2. Verify logcat shows the disarm path when the service stops:

```
[Watchdog] ⏹️ Disarmed
```

3. Kill the app (`adb shell am kill com.example.rider_app`).
4. Wait 3+ minutes.

**Pass criteria:** NO `Service dead — restarting` line, no service restart, no stray foreground notification. The watchdog must not resurrect an ended session.

---

## 5. Boot resume: tracking continues after a device reboot

1. With an active order + tracking on, note the current order id.
2. Reboot the device:

```bash
adb reboot
```

3. Wait for the lock screen. **Unlock the device** (on FBE devices the plain `BOOT_COMPLETED` broadcast only fires after unlock), then leave it alone — do not open the app.
4. Watch logcat (it reattaches automatically once USB re-enumerates; if not, rerun the §0 filter):

```
I/BootReceiver: Boot: tracking was active — resuming service
```

followed by the plugin cold-start sequence, then within ~2.5 min:

```
W/Watchdog: Service healthy (heartbeat age ...)
```

(the resumed service's heartbeat makes the watchdog report HEALTHY, not "dead" — that line proves both features work together)
5. Verify the rider's marker resumes on the customer device / backend `location_logs` without ever opening the rider app.

```bash
adb shell pidof com.example.rider_app     # service process alive
adb shell dumpsys activity services com.example.rider_app | findstr /i foreground
```

**Pass criteria:**
- `Boot: tracking was active — resuming service` appears after unlock WITHOUT opening the app.
- Heartbeat advances; watchdog reports healthy; pings flow to backend.
- Order context identical to pre-reboot (same order id being tracked).

**Variants:**
- [ ] **5a. No-job boot:** tracking OFF → reboot → expect `Boot: no active tracking jobs — not resuming` and NO service start, NO foreground notification.
- [ ] **5b. App update resume:** tracking ON → `flutter build apk --release && adb install -r app-release.apk` → expect `MY_PACKAGE_REPLACED` resume path (`I/BootReceiver: ... resuming service`) without a reboot.
- [ ] **5c. Android 12+ cold-start denial (record only):** on Android 12+ the OS may block background FGS start if the app hasn't shown a notification recently — logcat shows `E/BootReceiver: Service start from boot failed: ...`. If seen, note it: the rider recovers by opening the app once; consider a resume notification in a future release. Device observed: ______

**Fail if:** nothing in logcat after unlock, or service starts but heartbeat never advances (watchdog will restart it once — if that also fails, see §6).

---

## 6. Watchdog survives its own alarm being missed (Doze / battery saver)

1. Enable Battery Saver (or unplug + leave screen off for 15 min to sink into Doze).
2. Repeat §2 kill.

**Pass criteria:** restart eventually occurs (may be delayed past 2.5 min — inexact-alarm fallback is acceptable here; logcat should show `Exact alarms not permitted — using inexact watchdog tick` on Android 12+ if exact alarms are denied).
**Record:** actual recovery time in battery-saver mode: ______

---

## 7. Triage when a step fails

| Symptom | Likely cause | Fix / check |
|---|---|---|
| No `[Watchdog] ✅ Armed` at all | Method channel blocked | Confirm `MainActivity.kt` registered `service_watchdog` channel; only one `MainActivity` variant in the manifest |
| Armed but no `W/Watchdog:` ticks in logcat | Alarm scheduling blocked | `adb shell dumpsys alarm \| findstr rider_app` — expect a `com.example.rider_app.WATCHDOG_TICK` entry; Android 12+: check `Settings → Apps → Special app access → Alarms & reminders` |
| `Service dead — restarting` but service never comes up | Plugin service not starting | Check for `BackgroundService` crash in logcat (`FATAL EXCEPTION`); confirm manifest still declares the service with `foregroundServiceType="location"` |
| Restarts then immediately dies again (restart loop) | `onStart` crashing during cold start (e.g. missing token, notification permission) | Look for the first exception AFTER the restart line — that's the real bug, watchdog is just the messenger |
| Boot: `resuming service` never appears after reboot | Receiver not firing | `adb shell dumpsys deviceidle \| findstr rider_app` and confirm `RECEIVE_BOOT_COMPLETED` granted; on some OEMs boot receivers are blocked until the app is opened once after install |
| Boot: service starts but dies before heartbeat | Same cold-start crash class as the watchdog loop row above | Check logcat right after `resuming service`; also confirm `POST_NOTIFICATIONS` was granted pre-reboot (Android 13+ FGS needs it) |
| Restart works but tracking context lost | Flags not persisted before kill | Verify `kRiderActive`/`kRiderOrderId` are written at `start()` time (they are — SharedPreferences is synchronous), not only in-memory |
| OEM device (Xiaomi/Oppo/Vivo) kills every ~1 min even with watchdog | OEM "deep kill" clears alarms too | Use the existing battery-optimization exemption flow (app settings) — watchdog is a safety net, not a substitute |

---

## 8. Regression sanity (after watchdog + boot-resume pass)

- [ ] Toggle tracking off/on rapidly ×5 — no duplicate services, no restart storm in logcat.
- [ ] Customer-side order tracking still unfreezes after a kill (flags shared across both roles).
- [ ] Chat notifications still arrive with app killed (chat-watch flags also protected by watchdog + boot receiver).
- [ ] Battery: leave tracking on 30 min stationary — GPS idles (see battery work) and no watchdog restart storm occurs.
- [ ] Reboot with tracking OFF — no service, no notification, no watchdog alarms scheduled (`dumpsys alarm` shows no WATCHDOG_TICK).

---

**Result:** PASS / FAIL (circle) — Device model & Android version: ____________ • Build: ____________ • Date/Tester: ____________

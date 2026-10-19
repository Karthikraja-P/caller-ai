# Android background / permission audit (Task C3)

Read-only source audit, 2026-10-08. No code, permission, migration, Twilio, Supabase or device action was taken. No `AGENTS.md` exists in the repo. Paths below are relative to `caller_ai_frontend/` unless noted.

Legend: **[V]** verified from source. **[D]** device fact, needs a real phone. **[A]** from Android documentation (not re-fetched; see References).

## 1. Component inventory [V]

| Piece | Source | Behaviour |
|---|---|---|
| Manifest | `android/app/src/main/AndroidManifest.xml` | Declares INTERNET, READ_PHONE_STATE, RECORD_AUDIO, SYSTEM_ALERT_WINDOW. `CallReceiver` is exported and filters `PHONE_STATE`. `OverlayService` is not exported. |
| SDK | `android/app/build.gradle.kts:9-22` | minSdk, targetSdk and compileSdk come from `flutter.*`. The local Flutter at `/home/pkr/development/flutter` pins minSdk 24, compileSdk 36, targetSdk 36 (`FlutterExtension.kt`). A different Flutter install changes these. |
| `CallReceiver.kt` | `.../CallReceiver.kt` | Maps RINGING/OFFHOOK/IDLE transitions to `incoming`, `answered`, `missed`, `ended`. It reads the previous state from `CallEventQueue` (SharedPreferences). The number is `EXTRA_INCOMING_NUMBER`, or the string `"Unknown"` if absent. |
| `CallEventQueue.kt` | `.../CallEventQueue.kt` | Delivers to the live `EventSink`, otherwise persists. Cap is 16 events, max age 2 minutes, and writes use `commit()`. Replay on attach is at-most-once. A stale RINGING (over 2 min) reads as IDLE. |
| `MainActivity.kt` | `.../MainActivity.kt` | EventChannel `com.callerai/calls` attaches and detaches the queue. MethodChannel `com.callerai/overlay` has `showOverlay`, `hideOverlay` and `getPermissions`. `onCreate` does `startService` and `bindService` for `OverlayService`. |
| `OverlayService.kt` | `.../OverlayService.kt` | Native `TYPE_APPLICATION_OVERLAY` TextView via `WindowManager`. It is a plain bound/started service, not a foreground service, and it does not check `Settings.canDrawOverlays`. |
| Dart | `lib/main.dart:55-100` | Listens to the EventChannel only on Android. On `incoming` it pushes `CallOverlayScreen(previewOnly: true)`. This is an in-app Flutter route, not a system overlay. `answered`, `missed` and `ended` remove the route. |
| Permission UI | `lib/presentation/screens/permission_setup_screen.dart` | Uses `permission_handler` for phone, mic, overlay (required), contacts and notifications (optional). It is reached from `ai_agent_setup_screen.dart:75,282`. |
| Tests | `test/native_call_events_test.dart`, `test/call_overlay_screen_test.dart`, `android/app/src/test/.../CallEventQueueTest.kt` | Cover EventChannel to route behaviour, preview-only UI and queue logic. Nothing tests the receiver, the service, permissions or the manifest. |

Not present [V]: no `RoleManager`, `CallScreeningService`, `InCallService`, `ConnectionService`, foreground service, `READ_CALL_LOG`, `READ_CONTACTS` or `POST_NOTIFICATIONS`. `OverlayService` is reachable only through the MethodChannel, and no Dart code calls `showOverlay` (grep of `lib/` finds none). The native system overlay is therefore currently dead code.

## 2. Actual behaviour by state

### Foreground (activity visible, Flutter listening)
- [V] RINGING with `READ_PHONE_STATE` granted reaches the live sink. Dart pushes the preview route with a number and "Unknown caller".
- [V] The preview is display-only. It makes no backend call, no AI handoff and does not answer the call.
- [D] Whether the app's UI is shown over the system incoming-call UI, and the timing of the preview, depend on the phone.

### Background (process alive, activity not visible)
- [V] The manifest receiver fires. If the Flutter sink is still attached, the event goes to Dart and `navigator.push` runs while the app is not visible. Nothing is brought to the foreground.
- [V] Nothing in the app launches an activity or overlay for a background call. The user sees the preview only after returning to the app, by which point `answered`/`missed`/`ended` may already have removed it. A removed route is not recreated.
- [D] If the sink was cancelled (activity destroyed, `detach()`), events are queued instead, with the same outcome as the killed case below.

### Killed process
- [A][D] Android starts the process to run the manifest receiver for `PHONE_STATE`. This depends on the permission being granted and the app not being force-stopped (see section 4).
- [V] With no sink, events are persisted. When the app is next opened, `attach` replays events younger than 2 minutes. An old `incoming` replayed after the call has ended will push a preview, then the replayed `missed`/`ended` removes it in the same replay. Net visible effect is nil or a flash.
- [V] Process death mid-replay loses events (documented in `CallEventQueue.kt`).
- [V] No user-visible alert is produced for a call received while the app was not running. There is no notification and no overlay.

### Permission denied
- [V] Without `READ_PHONE_STATE`, the app gets no usable PHONE_STATE broadcasts [A], so no events and no preview. The app shows no error for this; the receiver is silent.
- [V] Without `SYSTEM_ALERT_WINDOW`, the Dart preview is unaffected because it does not use it. The native `showOverlay` would call `addView` with no `canDrawOverlays` check and can throw `BadTokenException`. This is not reachable today because Dart never calls it, but it would crash if wired up.
- [V] `RECORD_AUDIO` is marked required in the UI, but no on-device code uses the microphone (the Twilio path is server side). It blocks setup without a functional reason.
- [V] The UI requests `Permission.contacts` and `Permission.notification`, but the manifest declares neither `READ_CONTACTS` nor `POST_NOTIFICATIONS`. `permission_handler` can only grant what the manifest declares, so these will likely always report denied. They are optional, so setup still continues, but the UI misleads. Confirm on device [D].
- [V] `_requestPermission` opens app settings on permanent denial of any required permission. It is the only recovery path.

### Unknown number
- [V] The receiver substitutes `"Unknown"` when the extra is missing, and Dart treats blank as `"Unknown"`.
- [A] On API 28 and later, the `PHONE_STATE` number extra is only included if the app holds `READ_CALL_LOG`, which is not declared (and must not be added under this task). **Expect the number to be "Unknown" for every call on target 36**, not only for private/hidden numbers. Spam scoring by number cannot work from this path. [D] Confirm on a phone.
- [A] Android 10+ may send two RINGING broadcasts (with and without number). Dedupe on `lastState == RINGING` would keep the first and drop the second.

### Default role state
- [V] The app holds no dialer, call-screening or other role and never requests one.
- Consequence: it can observe call state only passively. It cannot reject, silence, screen or answer carrier calls. Call-screening APIs need the call-screening role (`ROLE_CALL_SCREENING`) and a `CallScreeningService`, none of which exist here [A].

## 3. Android restrictions that apply

- **Broadcasts:** `PHONE_STATE` is one of the implicit broadcasts that can still be received by manifest-declared receivers on API 26+ [A]. Receivers get only a short execution window, so slow work must not run in `onReceive`. The current receiver does only SharedPreferences writes, which fits.
- **Background activity starts:** since API 29, apps in the background generally cannot start activities [A]. A killed/background app therefore cannot pop the Flutter UI for a call.
- **Overlays:** `TYPE_APPLICATION_OVERLAY` requires the user to grant "Display over other apps" in Settings (`SYSTEM_ALERT_WINDOW`; `Settings.canDrawOverlays`) [A]. Overlays from background services are limited, and a foreground service or visible window is normally expected. Overlay windows cannot receive touches that pass through to the dialer on recent versions [A].
- **Services:** a plain started service is subject to background-execution limits on API 26+ [A]. `OverlayService` is started only from `MainActivity.onCreate`, so it is not alive for a background call unless the app was launched, and it may be stopped by the system.
- **Force stop and OEM battery managers:** a force-stopped app receives no broadcasts until launched again. Some OEMs also block background starts [D].
- **Android 13+/14+:** notification permission, restricted-settings sideloading prompts and foreground-service type rules may apply to any future change [A][D].

## 4. Twilio versus on-device boundary

- **Supported path (server side):** `POST /ai/call/handle` in `caller_ai_backend/app/api/v1/endpoints/ai_agent.py:87` validates the Twilio signature, then checks an active `ai_routing_numbers` row for the dialed Twilio number. It accepts only `call_type` of `spam` or `busy`, otherwise it returns `<Reject/>`. The media stream is `/ai/call/stream/{call_sid}`. This applies to calls that reach a provisioned Twilio number, typically via carrier call forwarding/diversion. See `caller_ai_backend/CALL_ROUTING.md`. (The audit did not run any of this.)
- **On-device path:** passive state detection and an in-app preview only (section 1). The app does not answer, reject or forward a carrier call. A preview screen with answer/AI buttons would not control the underlying call.
- **Do not claim:** that the overlay or preview answers carrier calls, or that on-device code hands a ringing carrier call to Twilio. The Dart `CallOverlayScreen` default mode has action buttons that call the backend, but `previewOnly: true` hides them for native events (`test/call_overlay_screen_test.dart`). Any handoff relies on the user's carrier forwarding the call to Twilio. Forwarding setup (USSD/MMI) is not implemented in the Android code [V: no code found], and `whatsapp.py` `/divert` only writes a DB row.
- Outside the scope here and untested: whether forwarded calls arrive at the Twilio number with the original caller as `From`.

## 5. Findings, ranked by impact

1. **High: caller number will be unavailable.** No `READ_CALL_LOG`, so on API 28+ every `incoming` carries `"Unknown"`. Number lookup, spam score and the caller preview are effectively non-functional. Needs a product decision (the permission is Play-restricted) or a different mechanism such as the call-screening role. [A][D]
2. **High: no visible alert in background or killed state.** The only UI is an in-app route. No notification, no working overlay, no foreground service. Preview is invisible for calls received outside the app. [V]
3. **Medium: native overlay is unreachable and unsafe if wired up.** No Dart caller of `showOverlay`, no `canDrawOverlays` check (can throw `BadTokenException`), not a foreground service. `hideOverlay` and `onDestroy` call `removeView` without handling a detached view. [V]
4. **Medium: setup screen asks for permissions the manifest cannot grant.** Contacts and notifications are requested but not declared, so they will probably show denied permanently. Mic is "required" with no on-device use. Overlay is "required" although the active path does not use it. [V]/[D]
5. **Medium: stale-event replay.** After a kill, a late app launch replays up to 2-minute-old events. The incoming preview and its dismissal replay together, so the result is a flash or nothing, and events can be lost mid-replay. [V]
6. **Low: no denied-permission feedback.** The receiver is silent when `READ_PHONE_STATE` is missing, and the dashboard does not show that detection is off. The `getPermissions` MethodChannel is unused by Dart. [V]
7. **Low: untested layers.** No tests for the receiver, service, manifest, or permission screen. `CallReceiver` state machine is only exercised indirectly. [V]
8. **Info: no narrowly provable crash was found in reachable code**, so no source was changed. The `BadTokenException` risk in finding 3 is not reachable today.

## 6. Next test matrix (real phone; do not run until approved)

| # | State | Permissions | Caller | Expected from source | Record |
|---|---|---|---|---|---|
| 1 | Foreground | Phone granted | Saved number | Preview appears, number "Unknown"? | Number extra present or not, API level |
| 2 | Foreground | Phone granted | Hidden number | Preview, "Unknown" | Same as 1 |
| 3 | Foreground | Phone denied | Any | No preview, no error | Confirm silent |
| 4 | Background (home) | Phone granted | Any | No visible UI; preview present or removed when returning | Sink still attached? |
| 5 | Swiped from recents | Phone granted | Any | Receiver starts process; no UI; queued events | Replay at next launch |
| 6 | Force-stopped | Phone granted | Any | No broadcast at all | Confirm |
| 7 | Answer then end | Phone granted | Any | `incoming`, `answered`, `ended` in order | Event ids, duplicates |
| 8 | Missed | Phone granted | Any | `incoming`, `missed` | Same |
| 9 | Overlay denied vs granted | Overlay toggled | Any | No change in behaviour (unused) | Confirm no native overlay |
| 10 | Contacts and notifications | Request on setup screen | n/a | Probably denied (undeclared) | Actual status |
| 11 | OEM battery saver on | Phone granted | Any | May suppress background delivery | Per device |
| 12 | Default role | None | Any | No role; app cannot screen/reject | Check Settings > Default apps |
| 13 | Forwarded to Twilio | n/a | Real carrier forward | Server-side only, needs provisioned number (separate approved task) | Caller `From` value |

Suggested devices: one stock Android 14/15/16 phone and one aggressive-OEM phone. Capture `adb logcat` for `CallReceiver` and the SharedPreferences queue contents.

## References

- Implicit broadcast exceptions: https://developer.android.com/develop/background-work/background-tasks/broadcasts/broadcast-exceptions
- Broadcasts overview: https://developer.android.com/develop/background-work/background-tasks/broadcasts
- `TelephonyManager.ACTION_PHONE_STATE_CHANGED` (number requires READ_CALL_LOG): https://developer.android.com/reference/android/telephony/TelephonyManager#ACTION_PHONE_STATE_CHANGED
- Background activity start restrictions: https://developer.android.com/guide/components/activities/background-starts
- `Settings.canDrawOverlays`, `SYSTEM_ALERT_WINDOW`: https://developer.android.com/reference/android/provider/Settings#canDrawOverlays(android.content.Context)
- Background execution limits: https://developer.android.com/about/versions/oreo/background
- Call screening role: https://developer.android.com/reference/android/app/role/RoleManager#ROLE_CALL_SCREENING

These URLs were cited from knowledge and were not re-fetched during this audit. Verify before relying on them.

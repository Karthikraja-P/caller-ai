package com.app.callerai

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CALL_CHANNEL = "com.callerai/calls"
        const val OVERLAY_CHANNEL = "com.callerai/overlay"
    }

    private var callEventSink: EventChannel.EventSink? = null
    private var overlayService: OverlayService? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val localBinder = binder as? OverlayService.LocalBinder
            overlayService = localBinder?.getService()
        }
        override fun onServiceDisconnected(name: ComponentName?) {
            overlayService = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method channel for overlay and blocklist control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOverlay" -> {
                        val callerNumber = call.argument<String>("callerNumber") ?: ""
                        val callerName = call.argument<String>("callerName") ?: "Unknown"
                        val spamScore = call.argument<Int>("spamScore") ?: 0
                        overlayService?.showOverlay(callerNumber, callerName, spamScore)
                        result.success(true)
                    }
                    "hideOverlay" -> {
                        overlayService?.hideOverlay()
                        result.success(true)
                    }
                    "getPermissions" -> {
                        val hasPhone = checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) ==
                            android.content.pm.PackageManager.PERMISSION_GRANTED
                        val hasMic = checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) ==
                            android.content.pm.PackageManager.PERMISSION_GRANTED
                        result.success(mapOf("phone" to hasPhone, "microphone" to hasMic))
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel for incoming call events -> Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    callEventSink = events
                    // Pass event sink to receiver
                    CallReceiver.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    callEventSink = null
                    CallReceiver.eventSink = null
                }
            })
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Start and bind OverlayService
        val intent = Intent(this, OverlayService::class.java)
        startService(intent)
        bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    override fun onDestroy() {
        unbindService(serviceConnection)
        super.onDestroy()
    }
}

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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method channel for overlay and permission queries
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOverlay", "hideOverlay" -> {
                        result.success(true)
                    }
                    "getPermissions" -> {
                        result.success(mapOf("phone" to false, "microphone" to false))
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel for incoming call events -> Flutter (dormant in v1 voicemail)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    // No background call events in voicemail-only v1
                }
                override fun onCancel(arguments: Any?) {}
            })
    }
}

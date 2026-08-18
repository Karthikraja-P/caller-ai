package com.app.callerai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import io.flutter.plugin.common.EventChannel

class CallReceiver : BroadcastReceiver() {
    companion object {
        var eventSink: EventChannel.EventSink? = null
        private var lastState: String = TelephonyManager.EXTRA_STATE_IDLE
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.intent.action.PHONE_STATE") return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: "Unknown"

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (lastState != TelephonyManager.EXTRA_STATE_RINGING) {
                    // New incoming call
                    eventSink?.success(mapOf(
                        "event" to "incoming",
                        "number" to incomingNumber,
                        "timestamp" to System.currentTimeMillis(),
                    ))
                }
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                if (lastState == TelephonyManager.EXTRA_STATE_RINGING) {
                    // Call answered
                    eventSink?.success(mapOf(
                        "event" to "answered",
                        "number" to incomingNumber,
                    ))
                }
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                if (lastState == TelephonyManager.EXTRA_STATE_RINGING) {
                    // Call missed/rejected
                    eventSink?.success(mapOf(
                        "event" to "missed",
                        "number" to incomingNumber,
                    ))
                } else if (lastState == TelephonyManager.EXTRA_STATE_OFFHOOK) {
                    // Call ended
                    eventSink?.success(mapOf(
                        "event" to "ended",
                        "number" to incomingNumber,
                    ))
                }
            }
        }
        lastState = state
    }
}

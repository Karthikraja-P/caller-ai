package com.app.callerai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager

class CallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.intent.action.PHONE_STATE") return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val lastState = CallEventQueue.lastState(context, TelephonyManager.EXTRA_STATE_IDLE)
        val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: "Unknown"

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (lastState != TelephonyManager.EXTRA_STATE_RINGING) {
                    // New incoming call
                    CallEventQueue.publish(context, mapOf(
                        "event" to "incoming",
                        "number" to incomingNumber,
                        "timestamp" to System.currentTimeMillis(),
                    ))
                }
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                if (lastState == TelephonyManager.EXTRA_STATE_RINGING) {
                    // Call answered
                    CallEventQueue.publish(context, mapOf(
                        "event" to "answered",
                        "number" to incomingNumber,
                    ))
                }
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                if (lastState == TelephonyManager.EXTRA_STATE_RINGING) {
                    // Call missed/rejected
                    CallEventQueue.publish(context, mapOf(
                        "event" to "missed",
                        "number" to incomingNumber,
                    ))
                } else if (lastState == TelephonyManager.EXTRA_STATE_OFFHOOK) {
                    // Call ended
                    CallEventQueue.publish(context, mapOf(
                        "event" to "ended",
                        "number" to incomingNumber,
                    ))
                }
            }
        }
        CallEventQueue.setLastState(context, state)
    }
}

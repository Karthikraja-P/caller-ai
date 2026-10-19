package com.app.callerai

import android.content.Context
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Small durable FIFO for call events that arrive while Flutter is not listening.
 *
 * Privacy/bounds: stored only in app-private SharedPreferences and capped at
 * [MAX_EVENTS]. Events older than [MAX_AGE_MS] are not physically deleted on a
 * timer; they are purged the next time the queue is accessed (publish/attach).
 * Pending events are cleared from storage before replay, so delivery is
 * at-most-once: a process death mid-replay can lose events. Each event carries
 * an increasing "id" so Dart can detect duplicates.
 *
 * Writes made from the BroadcastReceiver use commit() because the process may be
 * killed as soon as onReceive returns, which would drop a pending apply().
 */
object CallEventQueue {
    const val MAX_EVENTS = 16
    const val MAX_AGE_MS = 2 * 60 * 1000L

    /** A persisted RINGING older than this is treated as IDLE (ringing is short-lived). */
    const val RINGING_STATE_MAX_AGE_MS = 2 * 60 * 1000L

    /** Upper bound for a persisted OFFHOOK, so a killed process can't leave it forever. */
    const val OFFHOOK_STATE_MAX_AGE_MS = 6 * 60 * 60 * 1000L

    private const val RINGING = "RINGING"
    private const val OFFHOOK = "OFFHOOK"

    private const val PREFS = "call_event_queue"
    private const val KEY_EVENTS = "events"
    private const val KEY_NEXT_ID = "next_id"
    private const val KEY_LAST_STATE = "last_state"
    private const val KEY_LAST_STATE_AT = "last_state_at"

    private var sink: EventChannel.EventSink? = null

    /**
     * Last observed phone state, persisted so a fresh receiver process keeps
     * transitions. A stale state (see the max-age constants) or a missing
     * timestamp reads as [default] so an old RINGING can't suppress a new call.
     */
    @Synchronized
    fun lastState(context: Context, default: String): String {
        val p = prefs(context)
        val state = p.getString(KEY_LAST_STATE, null) ?: return default
        val age = System.currentTimeMillis() - p.getLong(KEY_LAST_STATE_AT, 0L)
        val maxAge = when (state) {
            RINGING -> RINGING_STATE_MAX_AGE_MS
            OFFHOOK -> OFFHOOK_STATE_MAX_AGE_MS
            else -> return state
        }
        // age < 0 means the clock moved backwards; don't trust the state.
        return if (age in 0..maxAge) state else default
    }

    /** Synchronous commit: the receiver may be killed right after onReceive. */
    @Synchronized
    fun setLastState(context: Context, state: String) {
        prefs(context).edit()
            .putString(KEY_LAST_STATE, state)
            .putLong(KEY_LAST_STATE_AT, System.currentTimeMillis())
            .commit()
    }

    /** Delivers to the live sink if one is attached, otherwise persists (synchronously). */
    @Synchronized
    fun publish(context: Context, event: Map<String, Any>) {
        val p = prefs(context)
        val id = p.getLong(KEY_NEXT_ID, 1L)
        val withMeta = event + mapOf(
            "id" to id,
            "timestamp" to (event["timestamp"] ?: System.currentTimeMillis()),
        )
        val live = sink
        if (live != null && read(p).length() == 0) {
            p.edit().putLong(KEY_NEXT_ID, id + 1).commit()
            live.success(withMeta)
            return
        }
        val list = prune(read(p), System.currentTimeMillis())
        list.put(JSONObject(withMeta))
        p.edit()
            .putLong(KEY_NEXT_ID, id + 1)
            .putString(KEY_EVENTS, trim(list).toString())
            .commit()
    }

    /** Attaches the Flutter sink and replays pending events in order, clearing them first (at-most-once). */
    @Synchronized
    fun attach(context: Context, events: EventChannel.EventSink) {
        val p = prefs(context)
        val pending = prune(read(p), System.currentTimeMillis())
        p.edit().remove(KEY_EVENTS).commit()
        sink = events
        for (i in 0 until pending.length()) {
            events.success(toMap(pending.getJSONObject(i)))
        }
    }

    @Synchronized
    fun detach() {
        sink = null
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun read(p: android.content.SharedPreferences): JSONArray =
        try {
            JSONArray(p.getString(KEY_EVENTS, null) ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }

    private fun prune(src: JSONArray, now: Long): JSONArray {
        val out = JSONArray()
        for (i in 0 until src.length()) {
            val o = src.optJSONObject(i) ?: continue
            if (now - o.optLong("timestamp", 0L) <= MAX_AGE_MS) out.put(o)
        }
        return out
    }

    private fun trim(src: JSONArray): JSONArray {
        if (src.length() <= MAX_EVENTS) return src
        val out = JSONArray()
        for (i in src.length() - MAX_EVENTS until src.length()) out.put(src.get(i))
        return out
    }

    private fun toMap(o: JSONObject): Map<String, Any> {
        val m = HashMap<String, Any>()
        for (k in o.keys()) m[k] = o.get(k)
        return m
    }
}

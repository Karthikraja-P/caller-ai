package com.app.callerai

import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import android.telephony.TelephonyManager
import io.flutter.plugin.common.EventChannel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

private class RecordingSink : EventChannel.EventSink {
    val events = ArrayList<Map<*, *>>()
    override fun success(event: Any?) { events.add(event as Map<*, *>) }
    override fun error(code: String?, message: String?, details: Any?) {}
    override fun endOfStream() {}
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CallEventQueueTest {
    private val prefs get() = context.getSharedPreferences("call_event_queue", Context.MODE_PRIVATE)
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        prefs.edit().clear().commit()
        CallEventQueue.detach()
    }

    @After
    fun tearDown() = CallEventQueue.detach()

    private fun incoming(n: Int) = mapOf<String, Any>("event" to "incoming", "number" to "n$n")

    private fun phoneState(state: String?, number: String? = null) =
        Intent("android.intent.action.PHONE_STATE").apply {
            if (state != null) putExtra(TelephonyManager.EXTRA_STATE, state)
            if (number != null) putExtra(TelephonyManager.EXTRA_INCOMING_NUMBER, number)
        }

    private fun receive(state: String) = CallReceiver().onReceive(context, phoneState(state, "+10000000000"))

    private fun attachSink(): RecordingSink = RecordingSink().also { CallEventQueue.attach(context, it) }

    @Test
    fun queuedEventsReplayInOrderWithIncreasingIds() {
        for (n in 1..3) CallEventQueue.publish(context, incoming(n))
        val sink = attachSink()
        assertEquals(listOf("n1", "n2", "n3"), sink.events.map { it["number"] })
        assertEquals(listOf(1L, 2L, 3L), sink.events.map { (it["id"] as Number).toLong() })
    }

    @Test
    fun replayClearsStorageSoReattachDoesNotRedeliver() {
        CallEventQueue.publish(context, incoming(1))
        attachSink()
        CallEventQueue.detach()
        assertEquals(0, attachSink().events.size)
    }

    @Test
    fun capKeepsNewestSixteenInOrder() {
        for (n in 1..20) CallEventQueue.publish(context, incoming(n))
        val sink = attachSink()
        assertEquals(CallEventQueue.MAX_EVENTS, sink.events.size)
        assertEquals((5..20).map { "n$it" }, sink.events.map { it["number"] })
    }

    @Test
    fun liveSinkReceivesDirectlyAndLaterEventsStayOrdered() {
        val sink = attachSink()
        CallEventQueue.publish(context, incoming(1))
        CallEventQueue.publish(context, incoming(2))
        assertEquals(listOf("n1", "n2"), sink.events.map { it["number"] })
        assertEquals(null, prefs.getString("events", null))
    }

    @Test
    fun eventsOlderThanTwoMinutesAreDroppedOnReplay() {
        val now = System.currentTimeMillis()
        CallEventQueue.publish(context, incoming(1) + ("timestamp" to now - CallEventQueue.MAX_AGE_MS - 5_000))
        CallEventQueue.publish(context, incoming(2) + ("timestamp" to now - CallEventQueue.MAX_AGE_MS + 30_000))
        CallEventQueue.publish(context, incoming(3))
        assertEquals(listOf("n2", "n3"), attachSink().events.map { it["number"] })
    }

    @Test
    fun staleEventsArePrunedOnPublishToo() {
        val old = System.currentTimeMillis() - CallEventQueue.MAX_AGE_MS - 5_000
        CallEventQueue.publish(context, incoming(1) + ("timestamp" to old))
        CallEventQueue.publish(context, incoming(2))
        assertEquals(listOf("n2"), attachSink().events.map { it["number"] })
    }

    @Test
    fun corruptPersistedQueueIsIgnored() {
        prefs.edit().putString("events", "{not json").commit()
        CallEventQueue.publish(context, incoming(1))
        assertEquals(listOf("n1"), attachSink().events.map { it["number"] })
    }

    @Test
    fun staleRingingAfterProcessRestartReadsAsIdle() {
        prefs.edit().putString("last_state", "RINGING").commit()
        prefs.edit().putLong("last_state_at", System.currentTimeMillis() - CallEventQueue.RINGING_STATE_MAX_AGE_MS - 5_000).commit()
        assertEquals("IDLE", CallEventQueue.lastState(context, "IDLE"))
        // A new ring must announce itself instead of being suppressed as a duplicate.
        receive(TelephonyManager.EXTRA_STATE_RINGING)
        assertEquals(listOf("incoming"), attachSink().events.map { it["event"] })
    }

    @Test
    fun staleRingingIdleDoesNotEmitPhantomMissed() {
        prefs.edit().putString("last_state", "RINGING").commit()
        prefs.edit().putLong("last_state_at", System.currentTimeMillis() - CallEventQueue.RINGING_STATE_MAX_AGE_MS - 5_000).commit()
        receive(TelephonyManager.EXTRA_STATE_IDLE)
        assertEquals(0, attachSink().events.size)
    }

    @Test
    fun freshRingingSurvivesProcessRestart() {
        receive(TelephonyManager.EXTRA_STATE_RINGING)
        // A fresh process only has the persisted prefs; the sink is gone.
        CallEventQueue.detach()
        receive(TelephonyManager.EXTRA_STATE_IDLE)
        assertEquals(listOf("incoming", "missed"), attachSink().events.map { it["event"] })
    }

    @Test
    fun missingOrFutureTimestampRingingIsNotTrusted() {
        prefs.edit().putString("last_state", "RINGING").commit()
        assertEquals("IDLE", CallEventQueue.lastState(context, "IDLE"))
        prefs.edit().putLong("last_state_at", System.currentTimeMillis() + 60_000).commit()
        assertEquals("IDLE", CallEventQueue.lastState(context, "IDLE"))
    }

    @Test
    fun duplicatePhoneStateBroadcastsEmitOnce() {
        repeat(3) { receive(TelephonyManager.EXTRA_STATE_RINGING) }
        repeat(2) { receive(TelephonyManager.EXTRA_STATE_OFFHOOK) }
        repeat(2) { receive(TelephonyManager.EXTRA_STATE_IDLE) }
        repeat(2) { receive(TelephonyManager.EXTRA_STATE_IDLE) }
        assertEquals(listOf("incoming", "answered", "ended"), attachSink().events.map { it["event"] })
    }

    @Test
    fun nonPhoneStateAndStatelessBroadcastsAreIgnored() {
        CallReceiver().onReceive(context, Intent("android.intent.action.BOOT_COMPLETED"))
        CallReceiver().onReceive(context, phoneState(null))
        assertTrue(attachSink().events.isEmpty())
    }

    @Test
    fun missingNumberDefaultsToUnknown() {
        CallReceiver().onReceive(context, phoneState(TelephonyManager.EXTRA_STATE_RINGING, null))
        assertEquals("Unknown", attachSink().events.single()["number"])
    }
}
